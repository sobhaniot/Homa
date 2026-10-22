#!/usr/bin/env python3
"""دریافت مستقیم بسته‌ها با تطبیق SHA256 فهرست معتبر apt؛ جایگزین اختلال دانلود apt."""
import concurrent.futures
import hashlib
from pathlib import Path
import subprocess

PACKAGES = ['libmosquitto1', 'libdlt2', 'libwebsockets19t64', 'mosquitto', 'mosquitto-clients', 'python3-paho-mqtt']


def download(name):
    metadata = subprocess.check_output(['apt-cache', 'show', '--no-all-versions', name], text=True)
    fields = dict(line.split(': ', 1) for line in metadata.splitlines() if ': ' in line)
    relative = fields['Filename']
    base = 'https://deb.debian.org/debian-security/' if relative.startswith('pool/updates/') else 'https://deb.debian.org/debian/'
    destination = Path(__file__).parent / 'packages' / Path(relative).name
    destination.parent.mkdir(exist_ok=True)
    subprocess.run(['curl', '-4', '--fail', '--silent', '--show-error', '--location', '--connect-timeout', '10', '--max-time', '90', '--retry', '1', '--output', str(destination), base+relative], check=True)
    if hashlib.sha256(destination.read_bytes()).hexdigest() != fields['SHA256']:
        raise RuntimeError('Package checksum mismatch: ' + name)
    print(name + ': SHA256 verified', flush=True)


if __name__ == '__main__':
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as executor:
        list(executor.map(download, PACKAGES))
