#!/usr/bin/env python3
"""سرور سبک هما؛ تنظیمات، پیام‌ها و تاریخچه مستقل از نمایشگرها هستند."""
import collections
import hashlib
import hmac
import json
import math
import os
import re
import secrets
import shutil
import signal
import sqlite3
import threading
import time
from datetime import date as calendar_date, datetime, time as clock_time, timedelta
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlsplit
from zoneinfo import ZoneInfo

import paho.mqtt.client as mqtt

ROOT = Path(__file__).parent
MAX_PAYLOAD = 16384
TEHRAN = ZoneInfo('Asia/Tehran')


def encode(value):
    return json.dumps(value, ensure_ascii=False, separators=(',', ':'), allow_nan=False)


def number(value, minimum, maximum, name):
    if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value) or not minimum <= value <= maximum:
        raise ValueError('مقدار نامعتبر: ' + name)
    return value


def topic(value):
    if not isinstance(value, str) or not value or len(value.encode()) > 512 or any(x in value for x in ('#', '+', '\x00')):
        raise ValueError('تاپیک باید مشخص و بدون wildcard باشد')
    return value


def measurement(module, payload):
    if module.get('kind') != 'refrigerator':
        return True
    # پیام اتصالِ یخچال، نمونهٔ دما نیست و نباید آخرین سنجش را جایگزین کند.
    try:
        obj = json.loads(payload)
        if not isinstance(obj, dict) or obj.get('type') != 'Info':
            return False
        value = obj.get('TempIn')
        return not isinstance(value, bool) and value is not None and math.isfinite(float(value))
    except (ValueError, TypeError):
        return False


FIELD_LABELS = dict(TempIn='دمای داخل', TempOut='دمای بیرون', Temp='دما', Hyster='هیسترسیس',
                    MinTemp='کمینهٔ دما', MaxTemp='بیشینهٔ دما', OnTime='زمان روشن', OffTime='زمان خاموش', IP='آدرس شبکه')


def field_type(value):
    # تشخیص نوع فقط پیشنهاد است؛ اجازهٔ نوشتن هرگز از روی مقدار حدس زده نمی‌شود.
    if isinstance(value, bool):
        return 'boolean'
    if isinstance(value, int):
        return 'integer'
    if isinstance(value, float) and math.isfinite(value):
        return 'number'
    if isinstance(value, str) and re.fullmatch(r'-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?', value):
        return 'number' if '.' in value else 'integer'
    return 'text'


def validate_fields(fields):
    if not isinstance(fields, list) or len(fields) > 64:
        raise ValueError('حداکثر ۶۴ فیلد برای کارت مجاز است')
    result, seen = [], set()
    for src in fields:
        if not isinstance(src, dict):
            raise ValueError('تعریف فیلد نامعتبر')
        key, label = src.get('key'), src.get('label')
        if not isinstance(key, str) or not re.fullmatch('[A-Za-z_][A-Za-z0-9_]{0,63}', key) or key in seen:
            raise ValueError('کلید فیلد نامعتبر یا تکراری')
        if not isinstance(label, str) or not 1 <= len(label) <= 80:
            raise ValueError('عنوان فیلد نامعتبر')
        seen.add(key)
        kind = src.get('type', 'auto')
        if kind not in ('auto', 'number', 'integer', 'text', 'boolean'):
            raise ValueError('نوع فیلد نامعتبر')
        field = dict(key=key, label=label, type=kind, visible=src.get('visible', True) is True,
                     editable=src.get('editable', False) is True and key != 'type', unit=str(src.get('unit', ''))[:24])
        for bound in ('min', 'max', 'step'):
            if src.get(bound) is not None:
                field[bound] = number(src[bound], -1e12 if bound != 'step' else 0.000001, 1e12, bound)
        if field.get('min', -1e12) > field.get('max', 1e12):
            raise ValueError('کمینه از بیشینه بزرگ‌تر است')
        result.append(field)
    return result


def module_ui(module, row):
    try:
        values = json.loads(row['payload']) if row else {}
        if not isinstance(values, dict):
            values = {}
    except (ValueError, TypeError):
        values = {}
    fields = module.get('fields')
    if fields is None:
        keys = list(values)
        if module['kind'] == 'refrigerator':
            keys = list(dict.fromkeys(['TempIn', 'TempOut', 'Temp', 'Hyster', 'OnTime', 'OffTime'] + keys))
        fields = []
        for key in keys:
            if not re.fullmatch('[A-Za-z_][A-Za-z0-9_]{0,63}', key) or isinstance(values.get(key), (dict, list)):
                continue
            field = dict(key=key, label=FIELD_LABELS.get(key, key), type='auto', visible=key != 'type',
                         editable=module['kind'] == 'refrigerator' and key in ('Temp', 'Hyster'), unit='')
            if field['editable']:
                field.update(type='number', min=-50 if key == 'Temp' else 0.1, max=80 if key == 'Temp' else 30, step=0.1)
            fields.append(field)
    resolved = []
    for src in fields:
        field = dict(src)
        key = field['key']
        value = values.get(key)
        if value is None:
            value = module.get('parameter_values', {}).get(key)
        if value is None and module['kind'] == 'refrigerator':
            value = module.get({'Temp':'temperature', 'Hyster':'hysteresis'}.get(key, ''))
        field['value'] = value
        field['inferred'] = field['type'] == 'auto'
        field['type'] = field_type(value) if field['type'] == 'auto' else field['type']
        resolved.append(field)
    revision = hashlib.sha256(encode([module['id'], module['kind'], module['route'], module['request_topic'],
        [{k:v for k,v in f.items() if k != 'value'} for f in resolved if f['editable']]]).encode()).hexdigest()[:24]
    return dict(version=1, revision=revision, columns=module.get('columns', 2), order=module.get('order', 0),
                refresh_seconds=module.get('client_interval', 30), fields=resolved)


def parameter_command(module, row, data):
    if data.get('schema_revision') != module_ui(module, row)['revision']:
        raise ValueError('تعریف فرم تغییر کرده؛ فرم را دوباره باز کنید')
    if data.get('confirm') is not True or not isinstance(data.get('values'), dict) or not data['values']:
        raise ValueError('مقادیر و تأیید صریح ارسال لازم است')
    fields = {f['key']:f for f in module_ui(module, row)['fields'] if f['editable']}
    payload = {'type':'Param'}
    for key, value in data['values'].items():
        if key not in fields:
            raise ValueError('فیلد قابل تنظیم نیست: '+key)
        field = fields[key]
        kind = field['type']
        if kind in ('number', 'integer'):
            value = number(value, field.get('min', -1e12), field.get('max', 1e12), field['label'])
            if kind == 'integer' and int(value) != value:
                raise ValueError('مقدار باید عدد صحیح باشد')
        elif kind == 'boolean':
            if not isinstance(value, bool):
                raise ValueError('مقدار باید روشن/خاموش باشد')
        elif not isinstance(value, str) or len(value) > 256:
            raise ValueError('متن نامعتبر')
        payload[key] = value
    if module['kind'] == 'refrigerator':
        # فریم‌ور قدیمی هر دو مقدار را در یک Param انتظار دارد.
        all_fields = {f['key']: f for f in module_ui(module, row)['fields']}
        for key, low, high in [('Temp', -50, 80), ('Hyster', 0.1, 30)]:
            payload[key] = number(payload.get(key, all_fields.get(key, {}).get('value')), low, high, key)
    return payload


def validate_module(data):
    # تنها فیلدهای شناخته‌شده پذیرفته می‌شوند تا رمز یا تنظیم اضافی وارد لاگ نشود.
    ident = data.get('id', '')
    if not isinstance(ident, str) or not re.fullmatch('[a-z0-9_-]{1,40}', ident):
        raise ValueError('شناسه باید انگلیسی کوچک، عدد، خط تیره یا زیرخط باشد')
    name = data.get('name', '')
    if not isinstance(name, str) or not 1 <= len(name) <= 80:
        raise ValueError('نام ماژول لازم است')
    route = data.get('route', 'local')
    if route not in ('local', 'external'):
        raise ValueError('مسیر بروکر نامعتبر است')
    kind = data.get('kind', 'generic')
    if kind not in ('generic', 'refrigerator'):
        raise ValueError('نوع ماژول نامعتبر است')
    request, response = topic(data.get('request_topic')), topic(data.get('response_topic'))
    if request == response or request.startswith('homa/') or response.startswith('homa/'):
        raise ValueError('تاپیک درخواست و پاسخ باید جدا و خارج از homa/ باشند')
    payload = data.get('request_payload', '{"type":"Info"}')
    # درخواست دوره‌ای فقط خواندنی است؛ تنظیمات عملیاتی مسیر جداگانه دارند.
    if not isinstance(payload, str) or len(payload) > 1024:
        raise ValueError('متن درخواست نامعتبر است')
    try:
        request_object = json.loads(payload)
    except (ValueError, TypeError):
        raise ValueError('درخواست باید JSON باشد')
    if request_object != {'type': 'Info'}:
        raise ValueError('فعلاً درخواست دوره‌ای فقط {"type":"Info"} است')
    share = data.get('share', 'off')
    if share not in ('off', 'on_demand', 'continuous'):
        raise ValueError('حالت اشتراک نامعتبر است')
    result = dict(id=ident, name=name, kind=kind, route=route, request_topic=request,
                  response_topic=response, request_payload=payload,
                  interval=int(number(data.get('interval', 30), 5, 86400, 'فاصله دریافت')),
                  timeout=int(number(data.get('timeout', 90), 10, 604800, 'مهلت پاسخ')),
                  enabled=data.get('enabled', True) is True,
                  polling=data.get('polling', True) is True, share=share)
    for key, low, high in [('temperature', -50, 80), ('hysteresis', 0.1, 30)]:
        if data.get(key) is not None:
            result[key] = number(data[key], low, high, key)
    if 'fields' in data:
        result['fields'] = validate_fields(data['fields'])
    result['columns'] = int(number(data.get('columns', 2), 1, 2, 'ستون'))
    result['order'] = int(number(data.get('order', 0), 0, 10000, 'ترتیب'))
    result['client_interval'] = int(number(data.get('client_interval', 30), 5, 86400, 'فاصله تازه‌خوانی کارت'))
    if 'parameter_values' in data:
        values=data['parameter_values']
        if not isinstance(values,dict) or len(values)>64:
            raise ValueError('مقادیر ذخیره‌شده نامعتبر است')
        for key,value in values.items():
            if not isinstance(key,str) or not re.fullmatch('[A-Za-z_][A-Za-z0-9_]{0,63}',key) or key=='type':
                raise ValueError('کلید تنظیم نامعتبر است')
            if isinstance(value,(int,float)) and not isinstance(value,bool):
                number(value,-1e12,1e12,key)
            elif not isinstance(value,(str,bool)) or (isinstance(value,str) and len(value)>256):
                raise ValueError('مقدار ذخیره‌شده نامعتبر است')
        result['parameter_values']=dict(values)
    return result


class Store:
    def __init__(self, path):
        self.lock = threading.RLock()
        self.db = sqlite3.connect(str(path), check_same_thread=False)
        self.db.row_factory = sqlite3.Row
        self.db.executescript('''
          PRAGMA journal_mode=WAL;
          PRAGMA busy_timeout=5000;
          CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY, value TEXT NOT NULL);
          CREATE TABLE IF NOT EXISTS modules (id TEXT PRIMARY KEY, config TEXT NOT NULL);
          CREATE TABLE IF NOT EXISTS messages (
            id INTEGER PRIMARY KEY AUTOINCREMENT, ts REAL NOT NULL, module_id TEXT,
            direction TEXT NOT NULL, broker TEXT NOT NULL, topic TEXT NOT NULL, payload TEXT NOT NULL);
          CREATE INDEX IF NOT EXISTS messages_module ON messages(module_id,id);
          CREATE TABLE IF NOT EXISTS telemetry (
            id INTEGER PRIMARY KEY AUTOINCREMENT, ts REAL NOT NULL, module_id TEXT NOT NULL,
            payload TEXT NOT NULL, parsed TEXT);
          CREATE INDEX IF NOT EXISTS telemetry_module ON telemetry(module_id,id);
          CREATE TABLE IF NOT EXISTS sessions (digest TEXT PRIMARY KEY, expires REAL NOT NULL);
          CREATE TABLE IF NOT EXISTS archive_clients (
            id TEXT PRIMARY KEY, acknowledged INTEGER NOT NULL DEFAULT 0,
            offered INTEGER NOT NULL DEFAULT 0, updated REAL NOT NULL);
        ''')
        if 'is_sample' not in [row[1] for row in self.db.execute('PRAGMA table_info(telemetry)')]:
            # ارتقای غیرحذفی: رکوردهای قبلی با همان شناسه و متن باقی می‌مانند.
            self.db.execute('ALTER TABLE telemetry ADD COLUMN is_sample INTEGER NOT NULL DEFAULT 1')
        self.db.commit()

    def setting(self, key, default=None):
        with self.lock:
            row = self.db.execute('SELECT value FROM settings WHERE key=?', (key,)).fetchone()
            return json.loads(row[0]) if row else default

    def set_setting(self, key, value):
        with self.lock:
            self.db.execute('INSERT OR REPLACE INTO settings VALUES (?,?)', (key, encode(value)))
            self.db.commit()

    def modules(self):
        with self.lock:
            return [json.loads(row[0]) for row in self.db.execute('SELECT config FROM modules ORDER BY id')]

    def save_module(self, data):
        # کلاینت قدیمی که تعریف فرم را نمی‌شناسد، نباید آن را پاک کند.
        with self.lock:
            previous=self.db.execute('SELECT config FROM modules WHERE id=?',(data.get('id',''),)).fetchone()
            if previous:
                data=dict(json.loads(previous[0]),**data)
        module = validate_module(data)
        with self.lock:
            for other in self.modules():
                if other['id'] != module['id'] and other['route'] == module['route']:
                    if set((module['request_topic'], module['response_topic'])) & set((other['request_topic'], other['response_topic'])):
                        raise ValueError('تاپیک این مسیر قبلاً برای ماژول دیگری استفاده شده است')
            self.db.execute('INSERT OR REPLACE INTO modules VALUES (?,?)', (module['id'], encode(module)))
            self.db.commit()
        return module

    def delete_module(self, ident):
        with self.lock:
            self.db.execute('DELETE FROM modules WHERE id=?', (ident,))
            self.db.commit()

    def message(self, ident, direction, broker, channel, payload):
        with self.lock:
            self.db.execute('INSERT INTO messages(ts,module_id,direction,broker,topic,payload) VALUES (?,?,?,?,?,?)',
                            (time.time(), ident, direction, broker, channel, payload[:MAX_PAYLOAD]))
            self.db.commit()

    def receive(self, module, broker, channel, payload, retained=False):
        parsed = None
        try:
            obj = json.loads(payload)
            if isinstance(obj, dict):
                parsed = encode(obj)
        except (ValueError, TypeError):
            pass
        with self.lock:
            # retained در پیام خام ثبت می‌شود ولی به‌عنوان اندازه‌گیری تازه ذخیره نمی‌شود.
            self.message(module['id'], 'rx-retained' if retained else 'rx', broker, channel, payload)
            accepted = not retained and measurement(module, payload)
            if accepted:
                self.db.execute('INSERT INTO telemetry(ts,module_id,payload,parsed) VALUES (?,?,?,?)',
                                (time.time(), module['id'], payload, parsed))
                self.db.commit()
            return accepted

    def rows(self, table, ident='', after=0, limit=200, start=None, end=None, before=None):
        if table not in ('messages', 'telemetry'):
            raise ValueError('جدول نامعتبر')
        conditions, args = ['id>?'], [max(0, int(after))]
        if table == 'telemetry':
            conditions.append('is_sample=1')
        if ident:
            conditions.append('module_id=?'); args.append(ident)
        if start is not None:
            conditions.append('ts>=?'); args.append(float(start))
        if end is not None:
            conditions.append('ts<=?'); args.append(float(end))
        if before is not None:
            conditions.append('id<=?'); args.append(int(before))
        with self.lock:
            sql = 'SELECT * FROM ' + table + ' WHERE ' + ' AND '.join(conditions)
            rows = self.db.execute(sql + ' ORDER BY id LIMIT ?', args + [min(max(int(limit), 1), 500)]).fetchall()
            return [dict(row) for row in rows]

    def latest(self, ident):
        with self.lock:
            row = self.db.execute('SELECT * FROM telemetry WHERE module_id=? AND is_sample=1 ORDER BY id DESC LIMIT 1', (ident,)).fetchone()
            return dict(row) if row else None

    def cleanup(self):
        # نگهداری محدود مانع پرشدن کارت حافظه در کار شبانه‌روزی می‌شود.
        days = self.setting('retention_days', 30)
        with self.lock:
            # تا وقتی ویندوز ثبت قطعی را تأیید نکرده، سقف سنی/تعدادی داده را حذف نمی‌کند.
            archive = self.db.execute('SELECT MIN(acknowledged) FROM archive_clients').fetchone()[0]
            for table, age, cap in [('messages', min(days, 7), 50000), ('telemetry', days, 200000)]:
                guard = ' AND id<=' + str(int(archive)) if table == 'telemetry' and archive is not None else ''
                self.db.execute('DELETE FROM ' + table + ' WHERE ts<?' + guard, (time.time() - age * 86400,))
                self.db.execute('DELETE FROM ' + table + ' WHERE id < COALESCE((SELECT id FROM ' + table + ' ORDER BY id DESC LIMIT 1 OFFSET ?),0)' + guard, (cap - 1,))
            self.db.commit()
            self.db.execute('PRAGMA wal_checkpoint(PASSIVE)')
            self.db.execute('DELETE FROM sessions WHERE expires<=?', (time.time(),))
            self.db.commit()


class Collector:
    def __init__(self, store, local_password):
        self.store = store
        self.local_password = local_password
        self.clients = {}
        self.states = {'local': {'connected': False, 'error': ''}, 'external': {'connected': False, 'error': ''}}
        self.wake = threading.Event()
        self.stop = threading.Event()
        self.jobs = collections.deque(maxlen=100)
        self.lock = threading.RLock()
        self.due = {}
        self.pending_share = {}
        self.last_remote = {}
        self.last_catalog = {}
        self.thread = threading.Thread(target=self.run, name='collector', daemon=True)

    def external(self, public=False):
        config = self.store.setting('external', dict(enabled=True, host='test.mosquitto.org', port=1883,
                         username='', password='', tls=False, client_id='homa-' + self.store.setting('installation')))
        if public:
            config = dict(config)
            config['has_password'] = bool(config.pop('password', ''))
        return config

    def reconfigure(self):
        self.wake.set()

    def publish(self, route, ident, channel, payload):
        client = self.clients.get(route)
        if not client or not client.is_connected():
            raise ValueError('بروکر ' + route + ' متصل نیست')
        # QoS صفر: فرمان عملیاتی در صف اتصال مجدد باقی نمی‌ماند و تکرار نمی‌شود.
        info = client.publish(channel, payload, qos=0, retain=False)
        if info.rc != mqtt.MQTT_ERR_SUCCESS:
            raise ValueError('ارسال به بروکر پذیرفته نشد')
        self.store.message(ident, 'tx', route, channel, payload)

    def queue(self, ident, parameters=None):
        module = next((m for m in self.store.modules() if m['id'] == ident), None)
        if not module or not module['enabled']:
            raise ValueError('ماژول فعال پیدا نشد')
        if not self.states[module['route']]['connected']:
            raise ValueError('بروکر متصل نیست')
        with self.lock:
            if len(self.jobs) >= 100:
                raise ValueError('صف درخواست پر است')
            self.jobs.append((ident, parameters))

    def share(self, module, row):
        if module['share'] == 'off' or not row:
            return
        root = 'homa/' + self.store.setting('installation') + '/modules/' + module['id']
        payload = encode(dict(module_id=module['id'], received_at=row['ts'], payload=row['payload']))
        self.publish('external', module['id'], root + '/state', payload)

    def local_state(self, module, row):
        # گوشی از حافظهٔ سرور می‌خواند؛ درخواست کارت به ESP منتقل نمی‌شود.
        if row and self.states['local']['connected']:
            root = 'homa/' + self.store.setting('installation') + '/modules/' + module['id']
            payload = encode(dict(module_id=module['id'], received_at=row['ts'], payload=row['payload']))
            self.publish('local', module['id'], root + '/state', payload)

    def catalog(self, route='local'):
        items = []
        for module in self.store.modules():
            if not module['enabled'] or (route == 'external' and module['share'] == 'off'):
                continue
            latest = self.store.latest(module['id'])
            items.append(dict(id=module['id'], name=module['name'], kind=module['kind'],
                ui=module_ui(module, latest), latest=latest,
                online=bool(latest and time.time()-latest['ts'] < module['timeout'])))
        items.sort(key=lambda m:(m['ui']['order'], m['name']))
        return dict(version=1, installation=self.store.setting('installation'), settings_allowed=route == 'local', modules=items)

    def apply_values(self, ident, data):
        module = next((m for m in self.store.modules() if m['id'] == ident), None)
        if not module or not module['enabled']:
            raise ValueError('ماژول فعال پیدا نشد')
        command = parameter_command(module, self.store.latest(ident), data)
        self.queue(ident, command)
        module['parameter_values']=dict(module.get('parameter_values',{}),**{k:v for k,v in command.items() if k!='type'})
        if module['kind'] == 'refrigerator':
            module.update(temperature=command['Temp'], hysteresis=command['Hyster'])
        self.store.save_module(module)
        return dict(queued=True, device_acknowledged=False)

    def on_message(self, route, message):
        if len(message.payload) > MAX_PAYLOAD:
            return
        payload = message.payload.decode('utf-8', errors='replace')
        root = 'homa/' + self.store.setting('installation')
        if message.topic == root+'/catalog/request' and not message.retain:
            try:
                if json.loads(payload) == {'type':'Info'} and time.time()-self.last_catalog.get(route, 0) >= 2:
                    self.last_catalog[route] = time.time()
                    self.publish(route, '', root+'/catalog/state', encode(self.catalog(route)))
            except (ValueError, TypeError):
                pass
            return
        if route == 'local' and message.topic.startswith(root+'/modules/') and message.topic.endswith('/settings') and not message.retain:
            try:
                data = json.loads(payload)
                if not isinstance(data, dict) or not re.fullmatch('[A-Za-z0-9_-]{8,64}', str(data.get('client_id', ''))) or not re.fullmatch('[A-Za-z0-9_-]{8,64}', str(data.get('request_id', ''))):
                    return
                ident = message.topic[len(root+'/modules/'):-len('/settings')]
                try:
                    result = self.apply_values(ident, data)
                except (ValueError, TypeError) as error:
                    result = dict(error=str(error))
                result['request_id'] = data['request_id']
                self.publish('local', ident, root+'/clients/'+data['client_id']+'/result', encode(result))
            except (ValueError, TypeError):
                pass
            return
        for module in self.store.modules():
            if not module['enabled']:
                continue
            if module['route'] == route and message.topic == module['response_topic']:
                accepted = self.store.receive(module, route, message.topic, payload, message.retain)
                if not accepted:
                    continue
                row = self.store.latest(module['id'])
                try:
                    self.local_state(module, row)
                except ValueError:
                    pass
                if route == 'external' and self.states['local']['connected']:
                    try:
                        self.publish('local', module['id'], 'homa/modules/' + module['id'] + '/state', encode(row))
                    except ValueError:
                        pass
                if module['share'] == 'continuous' or self.pending_share.pop(module['id'], 0) > time.time():
                    try:
                        self.share(module, row)
                    except ValueError:
                        pass
            request = 'homa/' + self.store.setting('installation') + '/modules/' + module['id'] + '/request'
            if route == 'local' and message.topic == request and not message.retain:
                try:
                    if json.loads(payload) == {'type': 'Info'}:
                        self.local_state(module, self.store.latest(module['id']))
                except ValueError:
                    pass
            if route == 'external' and module['share'] != 'off' and message.topic == request and not message.retain:
                # درخواست بیرونی فقط خواندن اطلاعات است؛ هیچ Param از اینترنت عبور نمی‌کند.
                try:
                    if json.loads(payload) != {'type': 'Info'}:
                        continue
                except ValueError:
                    continue
                now = time.time()
                if now - self.last_remote.get(module['id'], 0) < 5:
                    continue
                self.last_remote[module['id']] = now
                self.store.message(module['id'], 'rx-request', route, message.topic, payload)
                row = self.store.latest(module['id'])
                if row:
                    try:
                        self.share(module, row)
                    except ValueError:
                        pass
                if not row or now - row['ts'] > module['interval']:
                    self.pending_share[module['id']] = now + module['timeout']
                    try:
                        self.queue(module['id'])
                    except ValueError:
                        pass

    def connect_clients(self):
        for client in list(self.clients.values()):
            client.disconnect(); client.loop_stop()
        self.clients.clear()
        configs = {'local': dict(enabled=True, host='127.0.0.1', port=1883, username='', password='', tls=False,
                                client_id='homa-local-' + self.store.setting('installation')), 'external': self.external()}
        for route, config in configs.items():
            self.states[route] = dict(connected=False, error='')
            if not config['enabled']:
                continue
            client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, client_id=config['client_id'], protocol=mqtt.MQTTv311)
            client.max_queued_messages_set(100)
            client.reconnect_delay_set(2, 60)
            if config.get('username'):
                client.username_pw_set(config['username'], config.get('password', ''))
            if config['tls']:
                client.tls_set()

            def connected(c, userdata, flags, reason, properties, route=route):
                self.states[route] = dict(connected=not reason.is_failure, error=str(reason) if reason.is_failure else '')
                if reason.is_failure:
                    return
                root = 'homa/' + self.store.setting('installation')
                c.subscribe(root+'/catalog/request', qos=0)
                if route == 'local':
                    c.subscribe(root+'/modules/+/settings', qos=0)
                for module in self.store.modules():
                    if module['enabled'] and module['route'] == route:
                        c.subscribe(module['response_topic'], qos=0)
                    if module['enabled'] and (route == 'local' or module['share'] != 'off'):
                        c.subscribe('homa/' + self.store.setting('installation') + '/modules/' + module['id'] + '/request', qos=0)

            def disconnected(c, userdata, flags, reason, properties, route=route):
                self.states[route]['connected'] = False
                self.states[route]['error'] = str(reason)

            def failed(c, userdata, route=route):
                self.states[route] = dict(connected=False, error='اتصال ناموفق؛ تلاش مجدد خودکار')

            client.on_connect = connected
            client.on_disconnect = disconnected
            client.on_connect_fail = failed
            client.on_message = lambda c, u, msg, route=route: self.on_message(route, msg)
            self.clients[route] = client
            client.connect_async(config['host'], config['port'], keepalive=30)
            client.loop_start()

    def run(self):
        self.wake.set()
        cleanup_at = 0
        while not self.stop.is_set():
            try:
                if self.wake.is_set():
                    self.wake.clear()
                    self.connect_clients()
                    self.due.clear()
                now = time.time()
                modules = self.store.modules()
                with self.lock:
                    jobs = list(self.jobs); self.jobs.clear()
                for module in modules:
                    if module['enabled'] and module['polling'] and now >= self.due.get(module['id'], 0) and self.states[module['route']]['connected']:
                        jobs.append((module['id'], None))
                sent = set()
                for ident, parameters in jobs:
                    module = next((m for m in modules if m['id'] == ident and m['enabled']), None)
                    if not module or (parameters is None and ident in sent):
                        continue
                    payload = encode(parameters) if parameters else module['request_payload']
                    try:
                        self.publish(module['route'], ident, module['request_topic'], payload)
                        self.due[ident] = now + (2 if parameters else module['interval'])
                        sent.add(ident)
                    except ValueError as error:
                        self.states[module['route']]['error'] = str(error)
                if now >= cleanup_at:
                    self.store.cleanup(); cleanup_at = now + 3600
            except Exception as error:
                # شکست یک چرخه، سرویس مانیتورینگ را متوقف نمی‌کند.
                print('Collector:', type(error).__name__, str(error), flush=True)
            self.stop.wait(0.5)
        for client in list(self.clients.values()):
            client.disconnect(); client.loop_stop()


class Application:
    def __init__(self, directory, password, mqtt_password):
        self.directory = Path(directory)
        self.directory.mkdir(parents=True, exist_ok=True)
        self.store = Store(self.directory / 'homa.sqlite3')
        # حساب در پایگاه داده نگه‌داری می‌شود تا تغییر آن با راه‌اندازی مجدد از بین نرود.
        if not self.store.setting('panel_account'):
            self.set_account(os.environ.get('HOMA_ADMIN_USERNAME', 'admin'), password)
        self.login_attempts = {}
        self.auth_lock = threading.Lock()
        if not self.store.setting('installation'):
            self.store.set_setting('installation', secrets.token_hex(6))
        if not self.store.setting('initialized'):
            self.store.save_module(dict(id='refrigerator', name='یخچال', kind='refrigerator', route='external',
                request_topic='/eleknow.com/nahbos5672730/home/refrigerator',
                response_topic='/eleknow.com/nahbos5672730/home/refrigeratorResult', interval=30, timeout=120))
            self.store.set_setting('initialized', True)
        if not self.store.setting('measurement_schema_v1'):
            # اصلاح رکورد مشتق‌شدهٔ نسخهٔ نخست؛ پیام خام اتصال همیشه باقی می‌ماند.
            with self.store.lock:
                for module in self.store.modules():
                    if module['kind'] == 'refrigerator':
                        invalid = [(r['id'],) for r in self.store.db.execute('SELECT id,payload FROM telemetry WHERE module_id=?', (module['id'],)) if not measurement(module, r['payload'])]
                        self.store.db.executemany('UPDATE telemetry SET is_sample=0 WHERE id=?', invalid)
                self.store.db.commit()
            self.store.set_setting('measurement_schema_v1', True)
        self.collector = Collector(self.store, mqtt_password)

    def set_account(self, username, password):
        if not isinstance(username, str) or not username.strip() or len(username) > 128:
            raise ValueError('نام کاربری نامعتبر است')
        if not isinstance(password, str) or not password or len(password) > 1024:
            raise ValueError('رمز نامعتبر است')
        salt = secrets.token_hex(16)
        digest = hashlib.pbkdf2_hmac('sha256', password.encode(), bytes.fromhex(salt), 210000).hex()
        self.store.set_setting('panel_account', dict(username=username.strip(), salt=salt, digest=digest))
        # همهٔ نشست‌های قبلی، از جمله مرا به خاطر بسپار، لغو می‌شوند.
        with self.store.lock:
            self.store.db.execute('DELETE FROM sessions')
            self.store.db.commit()

    def check_account(self, username, password):
        if not isinstance(password, str) or len(password) > 1024:
            return False
        account = self.store.setting('panel_account')
        digest = hashlib.pbkdf2_hmac('sha256', password.encode(), bytes.fromhex(account['salt']), 210000).hex()
        return hmac.compare_digest(digest, account['digest']) and username == account['username']

    def new_session(self, remember=False):
        # فقط اثرانگشت توکن ذخیره می‌شود؛ رمز کاربر در مرورگر نگه‌داری نمی‌شود.
        token = secrets.token_urlsafe(40)
        expires = time.time() + (30 * 86400 if remember else 12 * 3600)
        digest = hashlib.sha256(token.encode()).hexdigest()
        with self.store.lock:
            self.store.db.execute('INSERT INTO sessions VALUES (?,?)', (digest, expires))
            self.store.db.commit()
        return dict(token=token, expires=expires, remember=remember)

    def valid_session(self, token):
        if not token or len(token) > 256:
            return False
        digest = hashlib.sha256(token.encode()).hexdigest()
        with self.store.lock:
            row = self.store.db.execute('SELECT expires FROM sessions WHERE digest=?', (digest,)).fetchone()
            return bool(row and row[0] > time.time())

    def revoke_session(self, token):
        with self.store.lock:
            self.store.db.execute('DELETE FROM sessions WHERE digest=?', (hashlib.sha256(token.encode()).hexdigest(),))
            self.store.db.commit()

    def config(self):
        return dict(external=self.collector.external(public=True), installation=self.store.setting('installation'),
                    retention_days=self.store.setting('retention_days', 30),
                    local=dict(port=1883, username='', password_configured=False, anonymous=True),
                    api_version=1)


class Handler(BaseHTTPRequestHandler):
    server_version = 'Homa/1'

    @property
    def app(self):
        return self.server.app

    def log_message(self, *args):
        # توکن، رمز و بدنهٔ درخواست‌ها هرگز در لاگ HTTP چاپ نمی‌شوند.
        pass

    def reply(self, status, body, content_type='application/json; charset=utf-8'):
        raw = body if isinstance(body, bytes) else encode(body).encode()
        self.send_response(status)
        self.send_header('Content-Type', content_type)
        self.send_header('Content-Length', str(len(raw)))
        self.send_header('Cache-Control', 'no-store')
        self.send_header('X-Content-Type-Options', 'nosniff')
        self.send_header('X-Frame-Options', 'DENY')
        self.send_header('Content-Security-Policy', "default-src 'self'; script-src 'self'; style-src 'self'; frame-ancestors 'none'; base-uri 'none'")
        self.end_headers()
        self.wfile.write(raw)

    def body(self):
        length = int(self.headers.get('Content-Length', '0'))
        if not 0 < length <= MAX_PAYLOAD:
            raise ValueError('اندازه درخواست نامعتبر است')
        value = json.loads(self.rfile.read(length))
        if not isinstance(value, dict):
            raise ValueError('درخواست باید شیء JSON باشد')
        return value

    def authorized(self):
        if not self.app.store.setting('web_auth_required', True):
            return True
        candidate = self.headers.get('Authorization', '').removeprefix('Bearer ')
        return self.app.valid_session(candidate)

    def dispatch(self):
        path = urlsplit(self.path).path
        query = parse_qs(urlsplit(self.path).query)
        # در حالت بدون رمز، درخواست تغییر از وب‌سایت دیگری پذیرفته نمی‌شود.
        if self.command != 'GET' and self.headers.get('Origin'):
            if urlsplit(self.headers['Origin']).netloc != self.headers.get('Host'):
                return self.reply(403, dict(error='درخواست از مبدأ دیگر مجاز نیست'))
        if self.command == 'GET' and path == '/api/auth-mode':
            return self.reply(200, dict(required=self.app.store.setting('web_auth_required', True)))
        if self.command == 'GET' and path in ('/', '/app.js', '/style.css', '/schema.js', '/calendar.js', '/jalaali.js'):
            filename = 'index.html' if path == '/' else path[1:]
            mime = 'text/html; charset=utf-8' if path == '/' else ('text/css; charset=utf-8' if path.endswith('.css') else 'application/javascript; charset=utf-8')
            return self.reply(200, (ROOT / 'web' / filename).read_bytes(), mime)
        if self.command == 'GET' and path == '/api/health':
            return self.reply(200, dict(ok=True, api_version=1))
        if self.command == 'POST' and path == '/api/login':
            data = self.body()
            with self.app.auth_lock:
                ip = self.client_address[0]
                now = time.time()
                attempts = [t for t in self.app.login_attempts.get(ip, []) if now - t < 60]
                if len(attempts) >= 10:
                    return self.reply(429, dict(error='یک دقیقه صبر کنید'))
                if not self.app.check_account(data.get('username'), data.get('password')):
                    attempts.append(now)
                    # فقط تلاش‌های دقیقهٔ جاری نگه‌داری می‌شوند.
                    self.app.login_attempts = {k: v for k, v in self.app.login_attempts.items() if v and now - v[-1] < 60}
                    self.app.login_attempts[ip] = attempts
                    return self.reply(401, dict(error='نام کاربری یا رمز اشتباه است'))
            return self.reply(200, self.app.new_session(data.get('remember') is True))
        if not self.authorized():
            return self.reply(401, dict(error='ابتدا وارد پنل شوید'))
        if self.command == 'POST' and path == '/api/logout':
            self.app.revoke_session(self.headers.get('Authorization', '').removeprefix('Bearer '))
            return self.reply(200, dict(ok=True))
        if self.command == 'POST' and path == '/api/account':
            data = self.body()
            with self.app.auth_lock:
                account = self.app.store.setting('panel_account')
                if not self.app.check_account(account['username'], data.get('current_password')):
                    return self.reply(403, dict(error='رمز فعلی اشتباه است'))
                self.app.set_account(data.get('username'), data.get('password'))
            return self.reply(200, dict(ok=True))
        if self.command == 'GET' and path == '/api/config':
            return self.reply(200, self.app.config())
        if self.command == 'POST' and path == '/api/archive/register':
            data = self.body()
            consumer = data.get('consumer', '')
            if not isinstance(consumer, str) or not re.fullmatch('[a-zA-Z0-9_-]{1,80}', consumer):
                raise ValueError('شناسهٔ آرشیو نامعتبر است')
            with self.app.store.lock:
                self.app.store.db.execute('INSERT OR IGNORE INTO archive_clients(id,updated) VALUES (?,?)', (consumer, time.time()))
                self.app.store.db.commit()
                high = self.app.store.db.execute("SELECT COALESCE((SELECT seq FROM sqlite_sequence WHERE name='telemetry'),0)").fetchone()[0]
                low = self.app.store.db.execute('SELECT MIN(id) FROM telemetry WHERE is_sample=1').fetchone()[0]
                ack = self.app.store.db.execute('SELECT acknowledged FROM archive_clients WHERE id=?', (consumer,)).fetchone()[0]
            return self.reply(200, dict(stream_id=self.app.store.setting('installation'), through=high,
                first_available=low, acknowledged=ack, unacknowledged_protected=True))
        if self.command == 'GET' and path == '/api/archive/page':
            consumer = query.get('consumer', [''])[0]
            after = int(query.get('after', ['0'])[0])
            through = int(query.get('through', ['0'])[0])
            if after < 0 or through < after:
                raise ValueError('بازهٔ آرشیو نامعتبر است')
            with self.app.store.lock:
                if not self.app.store.db.execute('SELECT 1 FROM archive_clients WHERE id=?', (consumer,)).fetchone():
                    raise ValueError('ابتدا آرشیو را ثبت کنید')
                rows = self.app.store.rows('telemetry', after=after, limit=int(query.get('limit', ['200'])[0]), before=through)
                cursor = rows[-1]['id'] if rows else after
                self.app.store.db.execute('UPDATE archive_clients SET offered=MAX(offered,?),updated=? WHERE id=?', (cursor, time.time(), consumer))
                self.app.store.db.commit()
            return self.reply(200, dict(stream_id=self.app.store.setting('installation'), items=rows, next_after=cursor))
        if self.command == 'POST' and path == '/api/archive/ack':
            data = self.body()
            consumer, cursor = data.get('consumer'), data.get('after')
            if not isinstance(cursor, int) or isinstance(cursor, bool) or cursor < 0:
                raise ValueError('نقطهٔ دریافت نامعتبر است')
            if data.get('stream_id') != self.app.store.setting('installation'):
                raise ValueError('شناسهٔ پایگاه منبع تغییر کرده است')
            with self.app.store.lock:
                row = self.app.store.db.execute('SELECT offered FROM archive_clients WHERE id=?', (consumer,)).fetchone()
                if not row or cursor > row[0]:
                    raise ValueError('تأیید بالاتر از دادهٔ عرضه‌شده مجاز نیست')
                self.app.store.db.execute('UPDATE archive_clients SET acknowledged=MAX(acknowledged,?),updated=? WHERE id=?', (cursor, time.time(), consumer))
                self.app.store.db.commit()
            return self.reply(200, dict(ok=True, deletion='only acknowledged data subject to retention policy'))
        if self.command == 'GET' and path == '/api/status':
            disk = shutil.disk_usage(self.app.directory)
            return self.reply(200, dict(brokers=self.app.collector.states, server_time=time.time(),
                disk_free=disk.free, disk_total=disk.total,
                database_bytes=sum(p.stat().st_size for p in self.app.directory.glob('homa.sqlite3*')),
                uptime=int(time.monotonic() - self.server.started)))
        if self.command == 'GET' and path == '/api/modules':
            result = []
            for module in self.app.store.modules():
                latest = self.app.store.latest(module['id'])
                result.append(dict(module, ui=module_ui(module, latest), latest=latest, online=bool(latest and time.time() - latest['ts'] < module['timeout'])))
            result.sort(key=lambda m:(m['ui']['order'], m['name']))
            return self.reply(200, result)
        if self.command == 'GET' and path == '/api/catalog':
            return self.reply(200, self.app.collector.catalog())
        settings_match = re.fullmatch('/api/modules/([a-z0-9_-]{1,40})/settings', path)
        if self.command == 'POST' and settings_match:
            return self.reply(202, self.app.collector.apply_values(settings_match[1], self.body()))
        if self.command == 'GET' and path in ('/api/messages', '/api/history'):
            get = lambda name, default=None: query.get(name, [default])[0]
            table = 'messages' if path.endswith('messages') else 'telemetry'
            # در اولین بازکردن لاگ، فقط آخرین ۲۰۰ پیام خوانده می‌شود.
            after = int(get('after', '0'))
            if table == 'messages' and 'after' not in query:
                with self.app.store.lock:
                    last = self.app.store.db.execute('SELECT COALESCE(MAX(id),0) FROM messages').fetchone()[0]
                after = max(0, last - 200)
            start, end = get('from'), get('to')
            # مرورگر قدیمی فقط تاریخ میلادیِ تبدیل‌شده از شمسی می‌فرستد؛
            # مرز روز در سرور با منطقهٔ زمانی تهران محاسبه می‌شود.
            if get('from_date'):
                start = datetime.combine(calendar_date.fromisoformat(get('from_date')), clock_time(), TEHRAN).timestamp()
            if get('to_date'):
                following = calendar_date.fromisoformat(get('to_date')) + timedelta(days=1)
                end = datetime.combine(following, clock_time(), TEHRAN).timestamp() - 0.000001
            if start is not None and end is not None and float(start) > float(end):
                raise ValueError('تاریخ شروع باید قبل از پایان باشد')
            rows = self.app.store.rows(table, get('module', ''), after, int(get('limit', '200')),
                                       start, end, get('through'))
            return self.reply(200, dict(items=rows, next_after=rows[-1]['id'] if rows else after,
                                       retention_days=self.app.store.setting('retention_days', 30)))
        if self.command == 'PUT' and path == '/api/config':
            data = self.body()
            old = self.app.collector.external()
            src = data.get('external', {})
            host = src.get('host', old['host'])
            if not isinstance(host, str) or not re.fullmatch('[A-Za-z0-9.:-]{1,253}', host):
                raise ValueError('آدرس بروکر را بدون mqtt:// وارد کنید')
            client_id = src.get('client_id', old['client_id'])
            if not isinstance(client_id, str) or not re.fullmatch('[A-Za-z0-9_-]{1,80}', client_id):
                raise ValueError('شناسه کلاینت نامعتبر')
            username = src.get('username', old['username'])
            password = src.get('password', old['password'])
            if not isinstance(username, str) or not isinstance(password, str) or len(username) > 256 or len(password) > 1024:
                raise ValueError('نام کاربری یا رمز بروکر نامعتبر')
            config = dict(enabled=src.get('enabled', old['enabled']) is True, host=host,
                port=int(number(src.get('port', old['port']), 1, 65535, 'پورت')),
                tls=src.get('tls', old['tls']) is True, username=username, password=password, client_id=client_id)
            days = int(number(data.get('retention_days', 30), 1, 365, 'روز نگهداری'))
            self.app.store.set_setting('external', config)
            self.app.store.set_setting('retention_days', days)
            self.app.collector.reconfigure()
            return self.reply(200, self.app.config())
        if self.command == 'PUT' and path == '/api/modules':
            data = self.body()
            validated = validate_module(data)
            parameters = None
            if data.get('apply_parameters') is True:
                if validated['kind'] != 'refrigerator':
                    raise ValueError('ارسال تنظیمات فقط برای یخچال است')
                parameters = dict(type='Param', Temp=number(data.get('temperature'), -50, 80, 'دما'),
                                  Hyster=number(data.get('hysteresis'), 0.1, 30, 'هیسترسیس'))
            module = self.app.store.save_module(data)
            result = dict(module)
            # ذخیره و ارسال یک عملیات کاربری است؛ خطای ارسال جدا از ذخیره گزارش می‌شود.
            if parameters:
                try:
                    self.app.collector.queue(module['id'], parameters)
                    result['parameters_queued'] = True
                    result['device_acknowledged'] = False
                except ValueError as error:
                    result['parameters_error'] = str(error)
            self.app.collector.reconfigure()
            return self.reply(200, result)
        match = re.fullmatch('/api/modules/([a-z0-9_-]{1,40})(?:/(request|parameters))?', path)
        if match:
            ident, action = match.groups()
            if self.command == 'DELETE' and not action:
                self.app.store.delete_module(ident)
                self.app.collector.reconfigure()
                return self.reply(200, dict(ok=True, history_preserved=True))
            if self.command == 'POST' and action == 'request':
                self.app.collector.queue(ident)
                return self.reply(202, dict(queued=True))
            if self.command == 'POST' and action == 'parameters':
                data = self.body()
                module = next((m for m in self.app.store.modules() if m['id'] == ident), None)
                if not module or module['kind'] != 'refrigerator' or data.get('confirm') is not True:
                    raise ValueError('نوع ماژول یا تأیید ارسال تنظیمات معتبر نیست')
                parameters = dict(type='Param', Temp=number(data.get('temperature'), -50, 80, 'دما'),
                                  Hyster=number(data.get('hysteresis'), 0.1, 30, 'هیسترسیس'))
                self.app.collector.queue(ident, parameters)
                return self.reply(202, dict(queued=True, device_acknowledged=False))
        return self.reply(404, dict(error='مسیر پیدا نشد'))

    def handle_request(self):
        try:
            self.dispatch()
        except (ValueError, TypeError, KeyError) as error:
            self.reply(400, dict(error=str(error)))
        except (BrokenPipeError, ConnectionResetError):
            pass
        except Exception as error:
            print('HTTP:', type(error).__name__, flush=True)
            self.reply(500, dict(error='خطای داخلی سرور'))

    do_GET = do_POST = do_PUT = do_DELETE = handle_request


class WebServer(ThreadingHTTPServer):
    daemon_threads = True

    def get_request(self):
        connection, address = super().get_request()
        connection.settimeout(10)
        return connection, address


def main():
    os.umask(0o077)
    app = Application(os.environ.get('HOMA_DATA', '/var/lib/homa'), os.environ['HOMA_ADMIN_PASSWORD'], os.environ['HOMA_MQTT_PASSWORD'])
    server = WebServer((os.environ.get('HOMA_BIND', '0.0.0.0'), int(os.environ.get('HOMA_PORT', '8080'))), Handler)
    server.app, server.started = app, time.monotonic()
    app.collector.thread.start()
    def shutdown(signum, frame):
        app.collector.stop.set()
        threading.Thread(target=server.shutdown, daemon=True).start()
    signal.signal(signal.SIGTERM, shutdown)
    signal.signal(signal.SIGINT, shutdown)
    print('Homa server ready', flush=True)
    server.serve_forever()
    app.collector.thread.join(timeout=5)
    server.server_close()


if __name__ == '__main__':
    main()
