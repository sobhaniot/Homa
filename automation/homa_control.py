"""کنترل اپ باز ویندوز از خط فرمان؛ بدون وابستگی خارجی یا کنترل دسکتاپ."""
import argparse
import json
import os
import sys
from pathlib import Path
import urllib.error
import urllib.parse
import urllib.request


def main():
    # خروجی فارسی حتی در ترمینال ویندوز با کدپیج قدیمی درست چاپ می‌شود.
    if hasattr(sys.stdout, 'reconfigure'):
        sys.stdout.reconfigure(encoding='utf-8')
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('method', choices=['GET', 'POST', 'PUT'])
    parser.add_argument('path', help='Example: /v1/status')
    parser.add_argument('--data', help='JSON object; parameters require confirm:true')
    parser.add_argument('--discovery', default=str(Path(os.environ.get('APPDATA', '.'))/'Homa'/'control-api.json'))
    args = parser.parse_args()
    try:
        config = json.loads(Path(args.discovery).read_text())
        url = urllib.parse.urlsplit(config['url'])
        if url.scheme != 'http' or url.hostname != '127.0.0.1' or not args.path.startswith('/v1/'):
            raise ValueError('Invalid local API address')
        data = json.loads(args.data) if args.data else None
        if data is not None and not isinstance(data, dict):
            raise ValueError('JSON object required')
        request = urllib.request.Request(config['url']+args.path, method=args.method,
            data=json.dumps(data).encode() if data is not None else None,
            headers={'Authorization': 'Bearer '+config['token'], 'Content-Type': 'application/json'})
        # اتصال محلی نباید از پروکسی سیستم عبور کند.
        opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
        with opener.open(request, timeout=20) as response:
            print(json.dumps(json.load(response), ensure_ascii=False, indent=2))
    except urllib.error.HTTPError as error:
        print(error.read().decode('utf-8'))
        raise SystemExit(1)
    except (OSError, ValueError, KeyError):
        raise SystemExit('Control API unavailable. Start the new Homa Windows app first.')


if __name__ == '__main__':
    main()
