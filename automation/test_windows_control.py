"""آزمون اپ واقعی: فقط خواندن، تغییر موقت نمودار و درخواست‌های نامعتبر؛ بدون فرمان یخچال."""
import datetime
import json
import os
from pathlib import Path
import urllib.error
import urllib.request

config = json.loads((Path(os.environ['APPDATA'])/'Homa'/'control-api.json').read_text())
opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))


def call(method, path, data=None, authenticated=True, expected=200):
    headers = {'Content-Type': 'application/json'}
    if authenticated:
        headers['Authorization'] = 'Bearer '+config['token']
    request = urllib.request.Request(config['url']+path, method=method, headers=headers,
        data=json.dumps(data).encode() if data is not None else None)
    try:
        response = opener.open(request, timeout=15)
    except urllib.error.HTTPError as error:
        response = error
    with response:
        assert response.code == expected, (path, response.code)
        return json.load(response)


state = call('GET', '/v1/status')
assert state['api_version'] == 1
call('GET', '/v1/status', authenticated=False, expected=401)
call('GET', '/v1/messages')
now = datetime.datetime.now(datetime.timezone.utc)
history = call('GET', '/v1/history?from='+now.date().isoformat()+'T00:00:00Z&to='+now.isoformat().replace('+00:00','Z')+'&limit=10')
assert history['source'] == 'windows_database'
call('GET', '/v1/history?from=wrong&to=wrong', expected=400)
call('POST', '/v1/modules/refrigerator/parameters', {'temperature': 9, 'hysteresis': 1, 'confirm': False}, expected=400)
call('GET', '/v1/not-existing', expected=404)
original = state['chart_period']
try:
    call('PUT', '/v1/chart', {'period': '7d' if original != '7d' else '1h'})
    assert call('GET', '/v1/status')['chart_period'] != original
finally:
    call('PUT', '/v1/chart', {'period': original})
assert call('GET', '/v1/status')['chart_period'] == original
print('PASS: running Windows app API, authentication, history, messages, validation, live chart control and restore.')
print('No MQTT connection or device parameter command was sent.')
