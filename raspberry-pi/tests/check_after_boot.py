"""بررسی بدون sudo از طریق API و MQTT؛ بدون تغییر داده یا تنظیمات واقعی دستگاه."""
import json
from pathlib import Path
import secrets
import subprocess
import threading
import time
import urllib.request
import paho.mqtt.client as mqtt

password=next(line.split(': ',1)[1] for line in Path('/home/sobhan/Homa-access.txt').read_text().splitlines() if line.startswith('Password: '))

def call(path, data=None, token=''):
    headers={'Content-Type':'application/json','Authorization':'Bearer '+token}
    req=urllib.request.Request('http://127.0.0.1:8080'+path,data=json.dumps(data).encode() if data is not None else None,headers=headers)
    with urllib.request.urlopen(req,timeout=5) as response:
        return json.load(response)

token=call('/api/login',dict(username='admin',password=password))['token']
boot_time=time.time()-float(Path('/proc/uptime').read_text().split()[0])
for attempt in range(30):
    status=call('/api/status',token=token)
    modules=call('/api/modules',token=token)
    fridge=next(m for m in modules if m['id']=='refrigerator')
    if all(v['connected'] for v in status['brokers'].values()) and fridge['latest'] and fridge['latest']['ts']>boot_time:
        break
    time.sleep(1)
else:
    raise AssertionError('No fresh refrigerator measurement after boot')
history=call('/api/history?module=refrigerator&limit=500',token=token)['items']
assert any(row['ts']<boot_time for row in history),'Previous history not found'
assert all(json.loads(row['payload']).get('type')=='Info' for row in history)
event=threading.Event()
rejected=[]
anonymous=mqtt.Client(mqtt.CallbackAPIVersion.VERSION2,client_id='auth-check-'+secrets.token_hex(4))
def connected(client,userdata,flags,reason,props):
    rejected.append(reason.is_failure);event.set()
anonymous.on_connect=connected
anonymous.connect('127.0.0.1',1883);anonymous.loop_start()
try:
    assert event.wait(5) and rejected==[True],'Anonymous MQTT was not rejected'
finally:
    anonymous.disconnect();anonymous.loop_stop()
states=subprocess.check_output(['systemctl','is-active','homa','mosquitto','wayvnc'],text=True).splitlines()
assert states==['active','active','active']
print(json.dumps(dict(boot_services=states,history_records=len(history),previous_history_preserved=True,
                     fresh_fridge_after_boot=True,anonymous_mqtt_rejected=True,
                     external_connected=status['brokers']['external']['connected']),indent=2))
