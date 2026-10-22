"""پشتیبان سازگار SQLite ویندوز؛ بدون بستن برنامه و بدون کپی ناقص WAL."""
import datetime
import os
from pathlib import Path
import sqlite3
import argparse

root = Path('F:/_HomaData')
source = root/'database'/'homa_telemetry.db'
if not source.exists():
    raise SystemExit('No existing Windows database to back up')
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--destination', default=str(root/'backups'))
args = parser.parse_args()
folder = Path(args.destination)
folder.mkdir(parents=True, exist_ok=True)
target = folder/('homa-'+datetime.datetime.now().strftime('%Y%m%d-%H%M%S-%f')+'.sqlite3')
with sqlite3.connect(source.as_uri()+'?mode=ro', uri=True) as current:
    with sqlite3.connect(target) as backup:
        current.backup(backup)
        assert backup.execute('PRAGMA integrity_check').fetchone()[0] == 'ok'
print('SQLite backup verified: '+str(target))
