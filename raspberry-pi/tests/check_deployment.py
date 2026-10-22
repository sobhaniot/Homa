"""بررسی سرویس واقعی و ماندگاری داده پس از restart؛ فقط Info خواندنی مجاز است."""
import json
from pathlib import Path
import sqlite3
import subprocess
import time
import urllib.error
import urllib.request

BASE = 'http://127.0.0.1:8080'
secret = json.loads(Path('/etc/homa/credentials.json').read_text())['admin']


def request(path, data=None, token=''):
    headers={'Content-Type':'application/json'}
    if token:
        headers['Authorization']='Bearer '+token
    req=urllib.request.Request(BASE+path, data=json.dumps(data).encode() if data is not None else None, headers=headers)
    with urllib.request.urlopen(req,timeout=5) as response:
        return json.load(response)


def login():
    return request('/api/login',dict(username='admin',password=secret))['token']


for attempt in range(30):
    try:
        token=login()
        status=request('/api/status',token=token)
        if status['brokers']['local']['connected']:
            break
    except (urllib.error.URLError, ConnectionError):
        pass
    time.sleep(1)
else:
    raise AssertionError('Local service/broker did not become ready')
assert status['brokers']['local']['connected'], status
config=request('/api/config',token=token)
assert 'password' not in config['external']
modules=request('/api/modules',token=token)
fridge=next(m for m in modules if m['id']=='refrigerator')
assert fridge['share']=='off'
# بازخوانی تاریخچهٔ واقعی؛ دادهٔ مصنوعی وارد پایگاه دادهٔ اصلی نمی‌شود.
history=request('/api/history?module=refrigerator&limit=500',token=token)['items']
if not history:
    request('/api/modules/refrigerator/request',{},token)
    for attempt in range(20):
        time.sleep(1)
        history=request('/api/history?module=refrigerator&limit=500',token=token)['items']
        if history:
            break
assert history, 'No real refrigerator history received'
first_id=history[0]['id']
subprocess.run(['systemctl','restart','homa'],check=True)
for attempt in range(20):
    try:
        token=login()
        break
    except (urllib.error.URLError, ConnectionError):
        time.sleep(1)
else:
    raise AssertionError('Service did not restart')
again=request('/api/history?module=refrigerator&limit=500',token=token)['items']
assert any(row['id']==first_id for row in again), 'History missing after restart'
with sqlite3.connect('/var/lib/homa/homa.sqlite3') as database:
    assert database.execute('PRAGMA integrity_check').fetchone()[0]=='ok'
    rows=database.execute("SELECT payload FROM messages WHERE direction='tx' AND module_id='refrigerator' AND broker=? AND topic=?",
                          (fridge['route'],fridge['request_topic'])).fetchall()
    assert all(json.loads(row[0])=={'type':'Info'} for row in rows), 'Unexpected operational command'
print(json.dumps(dict(real_fridge_records=len(again),history_survives_restart=True,database_integrity='ok',
                      only_info_sent_to_fridge=True,local_broker=True,external_broker=status['brokers']['external']['connected']),indent=2))
