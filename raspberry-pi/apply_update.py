#!/usr/bin/env python3
"""به‌روزرسانی پنل با حفظ رمزها و داده و تهیهٔ نسخهٔ بازگشت پیش از نصب."""
import ast
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import shutil
import sqlite3
import subprocess
import time
import urllib.request


def main():
    if os.geteuid() != 0:
        raise SystemExit('برای نصب: sudo python3 '+str(Path(__file__).resolve()))
    source=Path(__file__).resolve().parent
    destination=Path('/opt/homa')
    ast.parse((source/'server.py').read_text())
    expected=['server.py','web/index.html','web/app.js','web/style.css','web/schema.js','web/calendar.js','web/jalaali.js','web/LICENSE.jalaali-js']
    for relative in expected:
        if not (source/relative).is_file():
            raise SystemExit('Missing file: '+relative)
    os.umask(0o077)
    backup=Path('/var/backups/homa')/('ui-'+datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ'))
    backup.mkdir(parents=True,mode=0o700)
    shutil.copy2(destination/'server.py',backup/'server.py')
    shutil.copytree(destination/'web',backup/'web')
    with sqlite3.connect('file:/var/lib/homa/homa.sqlite3?mode=ro',uri=True) as connection:
        with sqlite3.connect(backup/'homa.sqlite3') as snapshot:
            connection.backup(snapshot)
            assert snapshot.execute('PRAGMA integrity_check').fetchone()[0]=='ok'
    try:
        for relative in expected:
            shutil.copy2(source/relative,destination/relative)
            (destination/relative).chmod(0o644)
            shutil.chown(destination/relative,'root','root')
        subprocess.run(['systemctl','restart','homa'],check=True)
        for attempt in range(25):
            try:
                with urllib.request.urlopen('http://127.0.0.1:8080/api/health',timeout=2) as response:
                    if json.load(response)['ok']:
                        break
            except (OSError,ValueError):
                time.sleep(1)
        else:
            raise RuntimeError('Updated service did not become ready')
        with urllib.request.urlopen('http://127.0.0.1:8080/calendar.js',timeout=3) as response:
            assert response.status==200
    except Exception:
        shutil.copy2(backup/'server.py',destination/'server.py')
        shutil.copytree(backup/'web',destination/'web',dirs_exist_ok=True)
        subprocess.run(['systemctl','restart','homa'],check=True)
        raise
    result='Homa UI update installed.\nPanel: http://192.168.1.12:8080\nBackup: '+str(backup)+'\n'
    result_file=Path('/home/sobhan/Homa-update-result.txt')
    result_file.write_text(result)
    shutil.chown(result_file,'sobhan','sobhan')
    result_file.chmod(0o600)
    print(result)


if __name__=='__main__':
    main()
