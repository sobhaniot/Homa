"""آزمون‌های قرارداد، حفظ تاریخچه و کنترل دسترسی؛ بدون تماس با یخچال واقعی."""
import json
from pathlib import Path
import sys
import tempfile
import threading
import time
import unittest
import urllib.error
import urllib.request

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from server import Application, Handler, Store, WebServer, validate_module


def module(**changes):
    result = dict(id='test', name='آزمایش', route='local', request_topic='test/info', response_topic='test/result', polling=False)
    result.update(changes)
    return result


class StorageTests(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory()
        self.store = Store(Path(self.folder.name) / 'test.sqlite3')

    def tearDown(self):
        self.store.db.close()
        self.folder.cleanup()

    def test_readonly_polling(self):
        for payload in ['{"type":"Param","Temp":4}', 'info', '{"type":"Info","Temp":5}']:
            with self.assertRaises(ValueError):
                validate_module(module(request_payload=payload))
        self.assertEqual(validate_module(module())['request_payload'], '{"type":"Info"}')

    def test_validation(self):
        for changes in [dict(id='../x'), dict(response_topic='#'), dict(interval=0), dict(interval=float('nan')),
                        dict(request_topic='test/result'), dict(route='wrong'), dict(request_topic='homa/foo'), dict(temperature=True)]:
            with self.assertRaises(ValueError):
                validate_module(module(**changes))

    def test_duplicate_topics(self):
        self.store.save_module(module())
        with self.assertRaises(ValueError):
            self.store.save_module(module(id='other'))

    def test_retained_and_pagination(self):
        m = self.store.save_module(module())
        self.store.receive(m, 'local', 'test/result', '{"Temp":4}', True)
        self.assertIsNone(self.store.latest('test'))
        for value in range(5):
            self.store.receive(m, 'local', 'test/result', json.dumps(dict(Temp=value)))
        first = self.store.rows('telemetry', 'test', limit=2)
        second = self.store.rows('telemetry', 'test', after=first[-1]['id'], limit=2)
        self.assertEqual([r['id'] for r in first + second], [1, 2, 3, 4])
        self.store.delete_module('test')
        self.assertEqual(len(self.store.rows('telemetry', 'test')), 5)

    def test_retention(self):
        m = self.store.save_module(module())
        self.store.receive(m, 'local', 'test/result', '{}')
        with self.store.lock:
            self.store.db.execute('UPDATE telemetry SET ts=?', (time.time()-40*86400,))
            self.store.db.commit()
        self.store.cleanup()
        self.assertEqual(self.store.rows('telemetry'), [])

    def test_fridge_connection_is_not_measurement(self):
        m = self.store.save_module(module(kind='refrigerator'))
        self.assertFalse(self.store.receive(m,'local','test/result','{"type":"Refrigerator connect to mqtt"}'))
        self.assertIsNone(self.store.latest('test'))
        self.assertEqual(len(self.store.rows('messages')),1)
        self.assertTrue(self.store.receive(m,'local','test/result','{"type":"Info","TempIn":4.5}'))
        self.assertEqual(len(self.store.rows('telemetry')),1)


class HTTPTests(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory()
        self.app = Application(self.folder.name, 'test-password', 'mqtt-test')
        self.auth_token = self.app.new_session()['token']
        self.http = WebServer(('127.0.0.1', 0), Handler)
        self.http.app, self.http.started = self.app, time.monotonic()
        self.worker = threading.Thread(target=self.http.serve_forever)
        self.worker.start()
        self.url = 'http://127.0.0.1:' + str(self.http.server_port)

    def tearDown(self):
        self.http.shutdown(); self.http.server_close(); self.worker.join()
        self.app.store.db.close(); self.folder.cleanup()

    def request(self, method, path, data=None, authorized=True):
        headers = {'Content-Type': 'application/json'}
        if authorized:
            headers['Authorization'] = 'Bearer ' + self.auth_token
        request = urllib.request.Request(self.url+path, data=json.dumps(data).encode() if data is not None else None, headers=headers, method=method)
        try:
            with urllib.request.urlopen(request) as response:
                return response.status, json.load(response)
        except urllib.error.HTTPError as error:
            return error.code, json.load(error)

    def test_optional_panel_login(self):
        self.assertTrue(self.request('GET', '/api/auth-mode', authorized=False)[1]['required'])
        self.app.store.set_setting('web_auth_required', False)
        self.assertFalse(self.request('GET', '/api/auth-mode', authorized=False)[1]['required'])
        self.assertEqual(self.request('GET', '/api/config', authorized=False)[0], 200)

    def test_account_change(self):
        change = dict(current_password='wrong', username='sobhan-test', password='new-test-password')
        self.assertEqual(self.request('POST', '/api/account', change)[0], 403)
        change['current_password'] = 'test-password'
        self.assertEqual(self.request('POST', '/api/account', change)[0], 200)
        self.assertFalse(self.app.valid_session(self.auth_token))
        self.assertFalse(self.app.check_account('admin', 'test-password'))
        self.assertTrue(self.app.check_account('sobhan-test', 'new-test-password'))
        second = Application(self.folder.name, 'test-password', 'mqtt-test')
        try:
            self.assertTrue(second.check_account('sobhan-test', 'new-test-password'))
            self.assertNotIn('new-test-password', json.dumps(second.store.setting('panel_account')))
        finally:
            second.store.db.close()

    def test_archive_pages_ack_and_buffer_protection(self):
        self.app.store.save_module(module())
        m = self.app.store.modules()[-1]
        self.app.store.receive(m, 'local', 'test/result', '{"Temp":4}')
        self.app.store.receive(m, 'local', 'test/result', '{"Temp":5}')
        self.app.store.db.execute('UPDATE telemetry SET ts=0')
        self.app.store.db.commit()
        status, registration = self.request('POST', '/api/archive/register', dict(consumer='windows-test'))
        self.assertEqual(status, 200)
        self.app.store.cleanup()
        self.assertEqual(len(self.app.store.rows('telemetry')), 2)
        status, page = self.request('GET', '/api/archive/page?consumer=windows-test&after=0&through=2&limit=1')
        self.assertEqual(status, 200)
        self.assertEqual(page['next_after'], 1)
        ack = dict(consumer='windows-test', stream_id=registration['stream_id'], after=2)
        self.assertEqual(self.request('POST', '/api/archive/ack', ack)[0], 400)
        ack['after'] = 1
        self.assertEqual(self.request('POST', '/api/archive/ack', ack)[0], 200)
        self.app.store.cleanup()
        self.assertEqual([r['id'] for r in self.app.store.rows('telemetry')], [2])
        ack['stream_id'] = 'wrong'
        self.assertEqual(self.request('POST', '/api/archive/ack', ack)[0], 400)

    def test_save_and_send_parameters(self):
        jobs = []
        self.app.collector.queue = lambda ident, params: jobs.append((ident, params))
        data = module(kind='refrigerator', temperature=4, hysteresis=2)
        self.assertEqual(self.request('PUT', '/api/modules', data)[0], 200)
        self.assertEqual(jobs, [])
        data['apply_parameters'] = True
        status, result = self.request('PUT', '/api/modules', data)
        self.assertEqual(status, 200)
        self.assertTrue(result['parameters_queued'])
        self.assertFalse(result['device_acknowledged'])
        self.assertEqual(jobs, [('test', dict(type='Param', Temp=4, Hyster=2))])
        def offline(*args):
            raise ValueError('offline')
        self.app.collector.queue = offline
        self.assertEqual(self.request('PUT', '/api/modules', data)[1]['parameters_error'], 'offline')

    def test_auth(self):
        self.assertEqual(self.request('GET', '/api/config', authorized=False)[0], 401)
        self.assertEqual(self.request('POST', '/api/login', dict(username='admin', password='wrong'), False)[0], 401)
        self.assertEqual(self.request('POST', '/api/login', dict(username='admin', password='رمز اشتباه'), False)[0], 401)
        status, data = self.request('POST', '/api/login', dict(username='admin', password='test-password'), False)
        self.assertEqual(status, 200)
        self.assertTrue(self.app.valid_session(data['token']))

    def test_remember_survives_restart_and_is_hashed(self):
        status, session = self.request('POST', '/api/login', dict(username='admin',password='test-password',remember=True),False)
        self.assertEqual(status,200)
        self.assertGreater(session['expires']-time.time(),29*86400)
        second=Application(self.folder.name,'test-password','mqtt-test')
        try:
            self.assertTrue(second.valid_session(session['token']))
            hashes=[row[0] for row in second.store.db.execute('SELECT digest FROM sessions')]
            self.assertNotIn(session['token'],hashes)
            second.revoke_session(session['token'])
            self.assertFalse(self.app.valid_session(session['token']))
        finally:
            second.store.db.close()

    def test_logout_and_expired_sessions(self):
        self.assertEqual(self.request('POST','/api/logout',{})[0],200)
        self.assertEqual(self.request('GET','/api/config')[0],401)
        self.auth_token=self.app.new_session()['token']
        self.app.store.db.execute('UPDATE sessions SET expires=0')
        self.app.store.db.commit()
        self.assertEqual(self.request('GET','/api/config')[0],401)

    def test_tehran_day_range(self):
        m=self.app.store.save_module(module())
        for timestamp in (1792528199,1792528200,1792614599,1792614600):
            self.app.store.receive(m,'local','test/result','{}')
            self.app.store.db.execute('UPDATE telemetry SET ts=? WHERE id=(SELECT MAX(id) FROM telemetry)',(timestamp,))
            self.app.store.db.commit()
        status, result=self.request('GET','/api/history?from_date=2026-10-21&to_date=2026-10-21')
        self.assertEqual(status,200)
        self.assertEqual([row['ts'] for row in result['items']],[1792528200,1792614599])
        self.assertEqual(self.request('GET','/api/history?from_date=2026-10-22&to_date=2026-10-21')[0],400)
        self.assertEqual(self.request('GET','/api/history?from_date=bad')[0],400)

    def test_config_masks_preserves_password(self):
        self.request('PUT', '/api/config', dict(external=dict(password='secret', host='localhost', enabled=False)))
        status, data = self.request('PUT', '/api/config', dict(external=dict(port=1884)))
        self.assertEqual(status, 200)
        self.assertNotIn('password', data['external'])
        self.assertTrue(data['external']['has_password'])
        self.assertEqual(self.app.collector.external()['password'], 'secret')

    def test_save_never_sends_parameters(self):
        status, _ = self.request('PUT', '/api/modules', module(temperature=4, hysteresis=2, kind='refrigerator'))
        self.assertEqual(status, 200)
        self.assertEqual(len(self.app.collector.jobs), 0)
        self.assertEqual(self.request('POST', '/api/modules/test/parameters', dict(temperature=4,hysteresis=2))[0], 400)

    def test_sql_and_invalid_requests(self):
        self.assertEqual(self.request('GET', '/api/history?module=%27%20OR%201=1')[0], 200)
        self.assertEqual(self.request('PUT', '/api/modules', module(request_topic='#'))[0], 400)
        self.assertEqual(self.request('GET', '/api/history?after=bad')[0], 400)

    def test_static(self):
        with urllib.request.urlopen(self.url+'/') as response:
            html=response.read().decode()
            self.assertIn('lang="fa"', html)
            self.assertIn('frame-ancestors', response.headers['Content-Security-Policy'])
        for asset in ('calendar.js','jalaali.js'):
            with urllib.request.urlopen(self.url+'/'+asset) as response:
                self.assertEqual(response.status,200)


if __name__ == '__main__':
    unittest.main(verbosity=2)
