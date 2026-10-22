"""نسخهٔ موقت و مجزا برای بازبینی رابط؛ هیچ درخواست دوره‌ای بیرونی ندارد."""
import json
import os
from pathlib import Path
import sys
import tempfile
import urllib.request

root=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root))
from server import Application

passwords=[line.split(': ',1)[1] for line in Path('/home/sobhan/Homa-access.txt').read_text().splitlines() if line.startswith('Password: ')]
def call(path,body=None,token=''):
    req=urllib.request.Request('http://127.0.0.1:8080'+path,data=json.dumps(body).encode() if body is not None else None,
        headers={'Content-Type':'application/json','Authorization':'Bearer '+token})
    with urllib.request.urlopen(req,timeout=5) as response:
        return json.load(response)
token=call('/api/login',dict(username='admin',password=passwords[0]))['token']
directory=tempfile.mkdtemp(prefix='homa-ui-preview-')
app=Application(directory,passwords[0],passwords[1])
app.store.delete_module('refrigerator')
for module in call('/api/modules',token=token):
    module['polling']=False
    app.store.save_module(module)
    for row in call('/api/history?module='+module['id']+'&limit=200',token=token)['items']:
        accepted=app.store.receive(module,module['route'],module['response_topic'],row['payload'])
        if accepted:
            app.store.db.execute('UPDATE telemetry SET ts=? WHERE id=(SELECT MAX(id) FROM telemetry)',(row['ts'],))
    app.store.db.commit()
external=app.collector.external()
external['enabled']=False
app.store.set_setting('external',external)
app.store.db.close()
os.environ.update(HOMA_PORT='8081',HOMA_DATA=directory,HOMA_ADMIN_PASSWORD=passwords[0],HOMA_MQTT_PASSWORD=passwords[1])
os.execv(sys.executable,[sys.executable,str(root/'server.py')])
