"""حذف درخواست رمز پنل و نمایش دسکتاپ؛ SSH کلیدی و رمز مدیریتی حفظ می‌شوند."""
import json
from pathlib import Path
import shutil
import sqlite3
import subprocess
import time

path = Path('/etc/wayvnc/config')
backup = Path(str(path)+'.auth-backup-'+str(int(time.time())))
shutil.copy2(path, backup)
lines = [line for line in path.read_text().splitlines() if not line.strip().startswith('enable_auth=')]
path.write_text('\n'.join(lines)+'\nenable_auth=false\n')
try:
    subprocess.run(['systemctl','restart','wayvnc'],check=True)
except Exception:
    shutil.copy2(backup,path)
    subprocess.run(['systemctl','restart','wayvnc'],check=True)
    raise
with sqlite3.connect('/var/lib/homa/homa.sqlite3') as db:
    db.execute('INSERT OR REPLACE INTO settings VALUES (?,?)',('web_auth_required',json.dumps(False)))
print('Web panel and VNC no longer require login; desktop autologin already enabled; SSH keys and sudo password unchanged.')
