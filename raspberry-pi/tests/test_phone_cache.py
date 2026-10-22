"""قرارداد کش گوشی؛ بدون بروکر و بدون ارسال به دستگاه واقعی."""
import json
from pathlib import Path
import sys
import tempfile
import unittest
from types import SimpleNamespace
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from server import Application


class PhoneCacheTests(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory()
        self.app = Application(self.folder.name, 'test-only', 'test-only')
        self.module = self.app.store.save_module(dict(id='cache-test', name='تست', route='local',
            request_topic='test/info', response_topic='test/result', polling=False, share='off'))
        self.collector = self.app.collector
        self.collector.states['local']['connected'] = True
        self.sent = []
        self.collector.publish = lambda *args, **kwargs: self.sent.append(args)
        self.root = 'homa/' + self.app.store.setting('installation') + '/modules/cache-test'

    def tearDown(self):
        self.app.store.db.close()
        self.folder.cleanup()

    def message(self, route, topic, data, retained=False):
        self.collector.on_message(route, SimpleNamespace(topic=topic, payload=json.dumps(data).encode(), retain=retained))

    def test_local_cache_request_does_not_queue_esp_or_share_external(self):
        self.app.store.receive(self.module, 'local', 'test/result', '{"TempIn":4}')
        self.message('local', self.root+'/request', {'type':'Info'})
        self.assertEqual(len(self.sent), 1)
        self.assertEqual(self.sent[0][:3], ('local', 'cache-test', self.root+'/state'))
        self.assertEqual(json.loads(self.sent[0][3])['payload'], '{"TempIn":4}')
        self.assertEqual(len(self.collector.jobs), 0)

    def test_new_sample_mirrors_locally_even_when_sharing_off(self):
        self.message('local', 'test/result', {'TempIn':5})
        self.assertTrue(any(x[0]=='local' and x[2]==self.root+'/state' for x in self.sent))
        self.assertFalse(any(x[0]=='external' for x in self.sent))

    def test_commands_retained_and_remote_disabled_are_ignored(self):
        self.app.store.receive(self.module, 'local', 'test/result', '{}')
        self.message('local', self.root+'/request', {'type':'Param','Temp':8})
        self.message('local', self.root+'/request', {'type':'Info'}, True)
        self.message('external', self.root+'/request', {'type':'Info'})
        self.assertEqual(self.sent, [])
        self.assertEqual(len(self.collector.jobs), 0)

if __name__ == '__main__':
    unittest.main()
