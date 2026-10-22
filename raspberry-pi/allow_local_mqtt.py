"""حذف احراز هویت بروکر محلی با نسخهٔ پشتیبان؛ حساب پنل حفظ می‌شود."""
from pathlib import Path
import shutil
import subprocess
import time

config = Path('/etc/mosquitto/conf.d/homa.conf')
backup = Path(str(config)+'.backup-'+str(int(time.time())))
shutil.copy2(config, backup)
text = config.read_text()
lines = [line for line in text.splitlines() if not line.strip().startswith(('allow_anonymous ', 'password_file '))]
config.write_text('\n'.join(lines)+'\nallow_anonymous true\n')
try:
    subprocess.run(['systemctl', 'restart', 'mosquitto'], check=True)
except Exception:
    shutil.copy2(backup, config)
    subprocess.run(['systemctl', 'restart', 'mosquitto'], check=True)
    raise
# فقط بخش بروکر یادداشت‌ها عوض می‌شود؛ رمز حساب پنل تغییر نمی‌کند.
for name in ['/home/sobhan/Homa-access.txt', '/home/sobhan/Desktop/Homa-access.txt']:
    path = Path(name)
    if path.exists():
        old = path.read_text()
        if 'Local MQTT:' in old:
            path.write_text(old.split('Local MQTT:')[0]+'Local MQTT: 192.168.1.12:1883\nAuthentication: none (trusted LAN only)\n')
print('Local MQTT anonymous access enabled; panel account unchanged.')
