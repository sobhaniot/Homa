"""آزمون فرمان‌های API اپ با بروکر ساختگی روی خود کامپیوتر؛ بدون تماس با تجهیزات خانه."""
import importlib.util
from pathlib import Path
import socket
import threading
import time
import json

# ابزار آزمون خواندنی را نیز پیش از آزمون اتصال اجرا می‌کنیم.
spec = importlib.util.spec_from_file_location('control_smoke', Path(__file__).with_name('test_windows_control.py'))
control = importlib.util.module_from_spec(spec)
spec.loader.exec_module(control)
call = control.call
original = call('GET', '/v1/status')
if original.get('broker_port') == 8080:
    raise SystemExit('This historical test is for the retired direct-MQTT app. Use Flutter raspberry_archive_test.dart for the current Raspberry HTTP architecture.')
assert not original['connected'], 'Disconnect manually before this isolated test'
listener = socket.socket()
listener.bind(('127.0.0.1', 0))
listener.listen(1)
listener.settimeout(15)
port = listener.getsockname()[1]
messages = []
errors = []


def receive_exact(connection, count):
    result = b''
    while len(result) < count:
        chunk = connection.recv(count-len(result))
        if not chunk:
            raise EOFError()
        result += chunk
    return result


def broker():
    try:
        connection, _ = listener.accept()
        with connection:
            connection.settimeout(15)
            while True:
                kind = receive_exact(connection, 1)[0] >> 4
                length, multiplier = 0, 1
                while True:
                    digit = receive_exact(connection, 1)[0]
                    length += (digit & 127)*multiplier
                    if not digit & 128:
                        break
                    multiplier *= 128
                data = receive_exact(connection, length)
                if kind == 1:
                    connection.sendall(b'\x20\x02\x00\x00')
                elif kind == 8:
                    connection.sendall(b'\x90\x03'+data[:2]+b'\x00')
                elif kind == 3:
                    size = int.from_bytes(data[:2], 'big')
                    messages.append(json.loads(data[2+size:]))
                elif kind == 12:
                    connection.sendall(b'\xd0\x00')
                elif kind == 14:
                    return
    except EOFError:
        pass
    except Exception as error:
        errors.append(type(error).__name__)


worker = threading.Thread(target=broker, daemon=True)
worker.start()
try:
    call('PUT', '/v1/settings', {'broker_host': '127.0.0.1', 'broker_port': port, 'poll_seconds': 86400})
    assert call('GET', '/v1/status')['broker_port'] == port
    call('POST', '/v1/connect', {})
    assert call('GET', '/v1/status')['connected']
    call('POST', '/v1/modules/refrigerator/request', {})
    call('POST', '/v1/modules/refrigerator/parameters', {
        'temperature': original['temperature'], 'hysteresis': original['hysteresis'], 'confirm': True,
    })
    for _ in range(30):
        if any(row.get('type') == 'Param' for row in messages):
            break
        time.sleep(0.1)
    assert any(row.get('type') == 'Info' for row in messages)
    assert any(row.get('type') == 'Param' for row in messages)
finally:
    call('POST', '/v1/disconnect', {})
    call('PUT', '/v1/settings', {key: original[key] for key in ['broker_host', 'broker_port', 'poll_seconds']})
    listener.close()
    worker.join(timeout=5)
assert not errors, errors
restored = call('GET', '/v1/status')
assert not restored['connected']
assert all(restored[key] == original[key] for key in ['broker_host', 'broker_port', 'poll_seconds'])
print('PASS: settings, live connect/disconnect, Info and Param verified on isolated fake broker; original settings restored.')
print('No request reached the Raspberry Pi, public broker, or real refrigerator.')
