#!/usr/bin/env python3
"""پشتیبان سازگار SQLite در حال اجرا؛ فایل اصلی و WAL دست‌کاری نمی‌شوند."""
from datetime import datetime, timezone
from pathlib import Path
import os
import sqlite3

os.umask(0o077)
folder=Path('/var/backups/homa')
folder.mkdir(parents=True, exist_ok=True)
destination=folder / ('homa-'+datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')+'.sqlite3')
with sqlite3.connect('file:/var/lib/homa/homa.sqlite3?mode=ro',uri=True) as source:
    with sqlite3.connect(destination) as backup:
        source.backup(backup)
        assert backup.execute('PRAGMA integrity_check').fetchone()[0]=='ok'
print(destination)
