"""آزمون سرتاسری با ماژول شبیه‌سازی‌شده و بروکر محلی؛ بدون دست‌زدن به ماژول واقعی."""
import json
from pathlib import Path
import secrets
import sys
import tempfile
import threading
import time
import unittest

import paho.mqtt.client as mqtt
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from server import Application


def wait_for(check, timeout=15):
    until = time.time()+timeout
    while time.time() < until:
        if check():
            return
        time.sleep(0.1)
    raise AssertionError('Timed out waiting for MQTT result')


class Integration(unittest.TestCase):
    def test_roundtrip_polling_sharing_and_retained(self):
        password = json.loads(Path('/etc/homa/credentials.json').read_text())['mqtt']
        folder = tempfile.TemporaryDirectory()
        app = Application(folder.name, 'test-only-password', password)
        app.store.delete_module('refrigerator')
        app.store.set_setting('external', dict(enabled=True,host='127.0.0.1',port=1883,username='homa',password=password,tls=False,client_id='homa-test-ext-'+secrets.token_hex(4)))
        ident = 'test_' + secrets.token_hex(4)
        request, response = 'integration/'+ident+'/info', 'integration/'+ident+'/result'
        module = app.store.save_module(dict(id=ident,name='آزمون مستقل',route='local',request_topic=request,response_topic=response,
                                           polling=False,interval=5,timeout=30,share='off'))
        remote_root = 'homa/'+app.store.setting('installation')+'/modules/'+ident
        requests, shared, parameters = [], [], []
        simulated = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, client_id='sim-'+ident)
        simulated.username_pw_set('homa', password)
        ready = threading.Event()
        def connected(client, userdata, flags, reason, props):
            self.assertFalse(reason.is_failure)
            client.subscribe([(request,0),(remote_root+'/state',0)])
        simulated.on_connect = connected
        simulated.on_subscribe = lambda *args: ready.set()
        def incoming(client, userdata, message):
            data=json.loads(message.payload)
            if message.topic == request:
                requests.append(data)
                if data == {'type':'Info'}:
                    client.publish(response, json.dumps(dict(TempIn=4.5,TempOut=25,type='Info')))
                else:
                    parameters.append(data)
            elif message.topic == remote_root+'/state':
                shared.append(data)
        simulated.on_message = incoming
        simulated.connect('127.0.0.1',1883); simulated.loop_start()
        app.collector.thread.start()
        try:
            self.assertTrue(ready.wait(10))
            wait_for(lambda: all(s['connected'] for s in app.collector.states.values()))
            time.sleep(0.5)
            app.collector.queue(ident)
            wait_for(lambda: app.store.latest(ident) is not None)
            self.assertEqual(json.loads(app.store.latest(ident)['payload'])['TempIn'],4.5)
            rows=app.store.rows('messages',ident)
            self.assertTrue(any(r['direction']=='tx' for r in rows))
            self.assertTrue(any(r['direction']=='rx' for r in rows))
            self.assertEqual(shared,[])
            module['share']='on_demand'; app.store.save_module(module); app.collector.reconfigure()
            wait_for(lambda: not app.collector.wake.is_set())
            wait_for(lambda: all(s['connected'] for s in app.collector.states.values()))
            time.sleep(1)
            simulated.publish(remote_root+'/request','{"type":"Info"}')
            wait_for(lambda: len(shared)>0)
            self.assertEqual(shared[-1]['module_id'],ident)
            count=len(requests)
            simulated.publish(remote_root+'/request','{"type":"Param","Temp":-5}')
            time.sleep(0.7)
            self.assertEqual(len(requests),count)
            self.assertEqual(parameters,[])
            # retained قدیمی نباید سنجش جدید یا آنلاین‌بودن جعلی بسازد.
            count=len(app.store.rows('telemetry',ident))
            simulated.publish(response,'{"TempIn":99}',retain=True)
            time.sleep(0.5)
            # انتشار زنده با retain=true در MQTT به مشترک جاری retain=false می‌رسد؛
            # پس پس از اتصال مجدد، پیام retained نباید رکورد دیگری اضافه کند.
            wait_for(lambda: len(app.store.rows('telemetry',ident))>count)
            count=len(app.store.rows('telemetry',ident))
            app.collector.reconfigure()
            wait_for(lambda: not app.collector.wake.is_set())
            wait_for(lambda: all(s['connected'] for s in app.collector.states.values()))
            time.sleep(1)
            self.assertEqual(len(app.store.rows('telemetry',ident)),count)
            simulated.publish(response,b'',retain=True)
            module['polling']=True;module['share']='off';app.store.save_module(module);app.collector.reconfigure()
            previous=len(requests)
            wait_for(lambda: len(requests)>=previous+2,timeout=15)
            self.assertTrue(all(r=={'type':'Info'} for r in requests))
        finally:
            app.collector.stop.set();app.collector.thread.join(10)
            simulated.disconnect();simulated.loop_stop()
            app.store.db.close();folder.cleanup()


if __name__ == '__main__':
    unittest.main(verbosity=2)
