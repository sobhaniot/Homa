#!/usr/bin/env python3
"""بازیابی حساب پنل از فایل خصوصی؛ فقط با دسترسی مدیر رزبری."""
import os
from pathlib import Path
import re
import subprocess
import sys
import time
import json
import urllib.request


def main():
    if os.geteuid() != 0 or len(sys.argv) != 2:
        raise SystemExit('Usage: sudo python3 /opt/homa/change_account.py /path/to/access.txt')
    text = Path(sys.argv[1]).read_text().split('Local MQTT:')[0]
    username = re.search(r'^Username:\s*(.+)$', text, re.M).group(1).strip()
    password = re.search(r'^Password:\s*(.+)$', text, re.M).group(1).strip()
    from server import Application
    # ابتدا اعتبارسنجی؛ هیچ تغییری در رمز بروکر ایجاد نمی‌شود.
    if not username or not password or len(username) > 128 or len(password) > 1024:
        raise SystemExit('Invalid account fields')
    subprocess.run(['systemctl', 'stop', 'homa'], check=True)
    try:
        app = Application('/var/lib/homa', password, '')
        app.set_account(username, password)
        app.store.db.close()
    finally:
        subprocess.run(['systemctl', 'start', 'homa'], check=True)
    for attempt in range(25):
        try:
            request = urllib.request.Request('http://127.0.0.1:8080/api/login',
                data=json.dumps(dict(username=username, password=password)).encode(),
                headers={'Content-Type': 'application/json'})
            with urllib.request.urlopen(request) as response:
                session = json.load(response)
            logout = urllib.request.Request('http://127.0.0.1:8080/api/logout', data=b'{}',
                headers={'Content-Type': 'application/json', 'Authorization': 'Bearer '+session['token']})
            urllib.request.urlopen(logout).close()
            print('Account updated; new login verified; test session revoked. MQTT unchanged.')
            return
        except OSError:
            time.sleep(1)
    raise SystemExit('Account saved but service login check failed')


if __name__ == '__main__':
    main()
