#!/usr/bin/env python3
"""نصب تکرارپذیر سرویس؛ رمزهای ساخته‌شده در اجرای بعدی حفظ می‌شوند."""
import json
import os
from pathlib import Path
import pwd
import secrets
import shutil
import subprocess


def run(*args):
    subprocess.run(args, check=True)


def main():
    if os.geteuid() != 0:
        raise SystemExit('Run with sudo')
    source = Path(__file__).resolve().parent
    try:
        pwd.getpwnam('homa')
    except KeyError:
        run('useradd', '--system', '--home', '/var/lib/homa', '--shell', '/usr/sbin/nologin', 'homa')
    root = Path('/opt/homa')
    root.mkdir(exist_ok=True)
    shutil.copy2(source / 'server.py', root / 'server.py')
    shutil.copytree(source / 'web', root / 'web', dirs_exist_ok=True)
    for path in root.rglob('*'):
        path.chmod(0o755 if path.is_dir() else 0o644)
    root.chmod(0o755)
    settings = Path('/etc/homa')
    settings.mkdir(mode=0o700, exist_ok=True)
    secret_file = settings / 'credentials.json'
    if secret_file.exists():
        credentials = json.loads(secret_file.read_text())
    else:
        credentials = dict(admin=secrets.token_urlsafe(18), mqtt=secrets.token_urlsafe(24))
        secret_file.write_text(json.dumps(credentials))
    secret_file.chmod(0o600)
    env = settings / 'server.env'
    env.write_text('HOMA_ADMIN_PASSWORD=' + credentials['admin'] + '\nHOMA_MQTT_PASSWORD=' + credentials['mqtt'] + '\n')
    env.chmod(0o600)
    passwd = Path('/etc/mosquitto/homa.passwd')
    # رمز از stdin عبور می‌کند؛ در آرگومان پردازش و لاگ قرار نمی‌گیرد.
    passwd.write_text('homa:' + credentials['mqtt'] + '\n')
    passwd.chmod(0o640)
    shutil.chown(passwd, 'root', 'mosquitto')
    run('mosquitto_passwd', '-U', str(passwd))
    shutil.chown(passwd, 'root', 'mosquitto')
    passwd.chmod(0o640)
    Path('/etc/mosquitto/conf.d/homa.conf').write_text('''# بروکر محلی هما؛ اتصال بدون احراز هویت فقط در شبکهٔ مورد اعتماد.
listener 1883 0.0.0.0
allow_anonymous true
max_packet_size 32768
max_inflight_messages 20
max_queued_messages 200
''')
    service = '''[Unit]
Description=Homa home MQTT collector and web panel
After=network-online.target mosquitto.service
Wants=network-online.target mosquitto.service

[Service]
Type=simple
User=homa
Group=homa
WorkingDirectory=/opt/homa
EnvironmentFile=/etc/homa/server.env
Environment=PYTHONDONTWRITEBYTECODE=1
ExecStart=/usr/bin/python3 -u /opt/homa/server.py
Restart=on-failure
RestartSec=5
StateDirectory=homa
StateDirectoryMode=0700
UMask=0077
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
PrivateTmp=true
ReadWritePaths=/var/lib/homa

[Install]
WantedBy=multi-user.target
'''
    Path('/etc/systemd/system/homa.service').write_text(service)
    access = ('Homa local server\n\nPanel: http://192.168.1.12:8080\nUsername: admin\nPassword: ' + credentials['admin']
              + '\n\nLocal MQTT: 192.168.1.12:1883\nAuthentication: none (trusted LAN only)'
              + '\n\nKeep this file private. Passwords are different from your Raspberry Pi login.\n')
    for filename in ('/home/sobhan/Homa-access.txt', '/home/sobhan/Desktop/Homa-access.txt'):
        path = Path(filename)
        if path.parent.exists():
            path.write_text(access)
            shutil.chown(path, 'sobhan', 'sobhan')
            path.chmod(0o600)
    run('systemctl', 'daemon-reload')
    run('systemctl', 'enable', 'mosquitto.service', 'homa.service')
    run('systemctl', 'restart', 'mosquitto.service')
    run('systemctl', 'restart', 'homa.service')
    print('Installed Homa. Credentials: /home/sobhan/Homa-access.txt')


if __name__ == '__main__':
    main()
