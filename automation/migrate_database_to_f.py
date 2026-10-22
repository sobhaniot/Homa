"""انتقال ایمن با SQLite backup؛ اپ باید بسته باشد؛ فایل قبلی برای بازگشت حفظ می‌شود."""
import datetime
import json
import os
from pathlib import Path
import sqlite3

source = Path(os.environ['APPDATA'])/'Homa'/'homa_telemetry.db'
target = Path('F:/_HomaData/database/homa_telemetry.db')
if not source.is_file() or target.exists():
    raise SystemExit('Source missing or destination already exists; nothing overwritten')
target.parent.mkdir(parents=True, exist_ok=True)
(target.parent.parent/'backups').mkdir(exist_ok=True)
with sqlite3.connect(source.as_uri()+'?mode=ro', uri=True) as old:
    with sqlite3.connect(target) as new:
        old.backup(new)
        assert new.execute('PRAGMA integrity_check').fetchone()[0] == 'ok'
        tables = [row[0] for row in old.execute("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'")]
        counts = {}
        for table in tables:
            quoted = '"'+table.replace('"','""')+'"'
            left = old.execute('SELECT * FROM '+quoted+' ORDER BY rowid').fetchall()
            right = new.execute('SELECT * FROM '+quoted+' ORDER BY rowid').fetchall()
            assert left == right, 'Table mismatch: '+table
            counts[table] = len(right)
        print(json.dumps({'destination':str(target),'integrity':'ok','verified_tables':counts,'old_copy_preserved':True}))
