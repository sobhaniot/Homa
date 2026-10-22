# پروتکل محصول Homa ـ نسخهٔ ۱

**شناسه سند:** `HOMA-PROTOCOL-1`  
**نسخه:** `1.0.0-draft.1`  
**وضعیت:** پیش‌نویس برای بررسی و تأیید مالک پروژه  
**دامنه:** Firmware، MQTT Broker، Backend، اپ موبایل و Node-RED

> این سند قرارداد مشترک اجزای Homa را تعریف می‌کند. تا پیش از تأیید مالک پروژه، مفاد آن نباید در کدها اجرا یا جایگزین پروتکل فعلی شوند.

## ۱. اهداف

- تمام ماژول‌ها از یک روش مشترک برای شناسایی، راه‌اندازی و ارتباط استفاده کنند.
- پارامترهایی مانند Wi-Fi، مالک دستگاه و اعتبارنامه‌ها برای هر دستگاه قابل تنظیم و یکتا باشند.
- اپ بتواند قابلیت‌ها و کنترل‌های هر دستگاه را به‌صورت پویا ایجاد کند.
- دستگاه در قطع اینترنت بتواند وظایف ضروری محلی خود را ادامه دهد.
- توسعهٔ Firmware، اپ و Backend مستقل باشد، اما همه از یک قرارداد نسخه‌بندی‌شده پیروی کنند.
- امنیت، OTA و عیب‌یابی از ابتدا بخشی از محصول باشند.

## ۲. اصول پایه

1. MQTT کانال اصلی فرمان، وضعیت و Telemetry است.
2. HTTPS برای ثبت‌نام، مالکیت دستگاه، دریافت Firmware و عملیات مدیریتی استفاده می‌شود.
3. BLE روش ترجیحی راه‌اندازی اولیه است و SoftAP روش جایگزین خواهد بود.
4. هیچ دستگاهی نباید Topic، رمز عمومی، شناسه کاربر یا اطلاعات خانه را به‌صورت ثابت در Firmware داشته باشد.
5. هر دستگاه دارای شناسه، راز راه‌اندازی و اعتبارنامهٔ ارتباطی یکتا است.
6. تمام زمان‌ها بر اساس UTC ارسال می‌شوند.
7. هر Payload دارای نسخهٔ Schema است.
8. دستگاه باید بدون اتصال Cloud، منطق ایمنی و برنامه‌های محلی ذخیره‌شده را اجرا کند.

## ۳. واژه‌ها

| واژه | تعریف |
|---|---|
| Product | نوع محصول، مانند کنترل آکواریوم یا سنسور گاز |
| Device | یک نمونهٔ فیزیکی فروخته‌شده با شناسهٔ یکتا |
| Capability | یک قابلیت قابل نمایش یا کنترل، مانند دما، رله یا زمان‌بندی |
| Telemetry | دادهٔ پیوسته و تاریخچه‌ای مانند دما |
| State | آخرین وضعیت واقعی گزارش‌شده توسط دستگاه |
| Desired State | وضعیت مورد درخواست اپ یا Backend |
| Manifest | توصیف مدل دستگاه و قابلیت‌های آن برای ساخت رابط پویا |
| Provisioning | فرایند اتصال اولیه، ثبت مالکیت و دریافت اعتبارنامه |

## ۴. شناسه‌ها

### ۴.۱ شناسه محصول

شناسه محصول ثابت، انگلیسی، حروف کوچک و بدون فاصله است:

```text
aqua-controller
gas-monitor
refrigerator-controller
ups-flasher
master-controller
```

### ۴.۲ شناسه دستگاه

هر برد در زمان تولید یک `deviceId` یکتا دریافت می‌کند:

```text
aq-01-7c9e4a21
```

قالب پیشنهادی:

```text
{productPrefix}-{hardwareRevision}-{randomOrChipId}
```

`deviceId` پس از فروش یا Factory Reset تغییر نمی‌کند.

### ۴.۳ شناسه قابلیت

شناسه قابلیت در محدودهٔ هر دستگاه یکتا و پایدار است:

```text
water_temperature
filter
air_pump
gas_level
door
```

عنوان قابل نمایش، جایگزین شناسه نیست و می‌تواند توسط کاربر تغییر کند.

## ۵. فضای Topicهای MQTT

Topic پایه:

```text
homa/v1/devices/{deviceId}
```

Topicهای استاندارد:

```text
homa/v1/devices/{deviceId}/manifest
homa/v1/devices/{deviceId}/availability
homa/v1/devices/{deviceId}/state
homa/v1/devices/{deviceId}/telemetry
homa/v1/devices/{deviceId}/command
homa/v1/devices/{deviceId}/command/result
homa/v1/devices/{deviceId}/config/desired
homa/v1/devices/{deviceId}/config/reported
homa/v1/devices/{deviceId}/event
homa/v1/devices/{deviceId}/ota/desired
homa/v1/devices/{deviceId}/ota/reported
```

### ۵.۱ قواعد Topic

- Topicها فقط از حروف کوچک انگلیسی، عدد، خط تیره و `/` تشکیل شوند.
- `deviceId` بخشی از تمام Topicهای اختصاصی دستگاه باشد.
- دستگاه فقط اجازهٔ Subscribe و Publish در محدودهٔ مجاز خودش را دارد.
- فرمان و Telemetry روی یک Topic مشترک ارسال نشوند.
- اطلاعات کاربر، نام خانه یا شماره تلفن داخل Topic قرار نگیرد.

## ۶. قالب مشترک پیام

تمام پیام‌های JSON، در صورت مرتبط‌بودن، از قالب زیر استفاده می‌کنند:

```json
{
  "schemaVersion": 1,
  "messageId": "01J8M6Y7X38JQ4A2P0N7",
  "deviceId": "aq-01-7c9e4a21",
  "timestamp": "2026-09-28T10:15:30Z",
  "data": {}
}
```

قواعد:

- `schemaVersion` عدد صحیح و اجباری است.
- `messageId` برای فرمان، نتیجه، رخداد و عملیات OTA اجباری است.
- `timestamp` با قالب ISO 8601 و UTC ارسال می‌شود.
- گیرنده باید فیلدهای ناشناخته را نادیده بگیرد تا سازگاری رو به جلو حفظ شود.
- اندازهٔ Payload باید متناسب با حافظهٔ دستگاه محدود شود.

## ۷. Manifest و رابط پویا

دستگاه یا Device Registry باید Manifest زیر را فراهم کند:

```json
{
  "schemaVersion": 1,
  "deviceId": "aq-01-7c9e4a21",
  "productId": "aqua-controller",
  "name": "آکواریوم",
  "manufacturer": "Homa",
  "hardwareVersion": "1.0",
  "firmwareVersion": "1.0.0",
  "capabilities": [
    {
      "id": "water_temperature",
      "type": "sensor",
      "title": "دمای آب",
      "dataType": "number",
      "unit": "°C",
      "readOnly": true,
      "minimum": -20,
      "maximum": 80
    },
    {
      "id": "filter",
      "type": "switch",
      "title": "فیلتر",
      "dataType": "boolean",
      "readOnly": false
    },
    {
      "id": "air_pump_schedule",
      "type": "schedule",
      "title": "برنامه پمپ هوا",
      "dataType": "schedule",
      "readOnly": false
    }
  ]
}
```

انواع اولیهٔ Capability در نسخهٔ ۱:

| type | کاربرد |
|---|---|
| `sensor` | نمایش مقدار سنسور |
| `binary_sensor` | نمایش وضعیت دوحالته |
| `switch` | روشن و خاموش‌کردن |
| `button` | اجرای فرمان لحظه‌ای |
| `number` | تنظیم مقدار عددی |
| `select` | انتخاب یکی از گزینه‌ها |
| `schedule` | تنظیم برنامهٔ زمانی |
| `alarm_limit` | تنظیم حد پایین و بالا |

افزودن نوع جدید نیازمند افزایش نسخهٔ Schema یا تعریف سازگاری است.

## ۸. State، Desired و Reported

وضعیت واقعی فقط توسط دستگاه منتشر می‌شود:

```json
{
  "schemaVersion": 1,
  "deviceId": "aq-01-7c9e4a21",
  "timestamp": "2026-09-28T10:15:30Z",
  "data": {
    "water_temperature": 24.6,
    "filter": true,
    "air_pump": false
  }
}
```

- اپ نباید با ارسال فرمان، وضعیت موفق را فرض کند.
- اپ پس از دریافت `state` یا `command/result` رابط را قطعی به‌روزرسانی می‌کند.
- `config/desired` خواستهٔ Backend است.
- `config/reported` تنظیم واقعی و پذیرفته‌شدهٔ دستگاه است.
- دستگاه تنظیم نامعتبر را رد کرده و خطای مشخص ارسال می‌کند.

## ۹. فرمان و پاسخ

نمونه فرمان:

```json
{
  "schemaVersion": 1,
  "messageId": "cmd-01J8M6Y7",
  "deviceId": "aq-01-7c9e4a21",
  "timestamp": "2026-09-28T10:16:00Z",
  "expiresAt": "2026-09-28T10:16:30Z",
  "data": {
    "action": "set",
    "capability": "filter",
    "value": true
  }
}
```

نمونه نتیجه:

```json
{
  "schemaVersion": 1,
  "messageId": "cmd-01J8M6Y7",
  "deviceId": "aq-01-7c9e4a21",
  "timestamp": "2026-09-28T10:16:01Z",
  "data": {
    "success": true,
    "capability": "filter",
    "value": true
  }
}
```

قواعد فرمان:

- فرمان منقضی‌شده اجرا نشود.
- اجرای مجدد `messageId` تکراری نباید اثر دوم ایجاد کند.
- پس از اجرا، نتیجه و State جدید منتشر شود.
- فرمان‌های خطرناک باید شرط ایمنی محلی داشته باشند.

## ۱۰. خطاها

قالب خطا:

```json
{
  "schemaVersion": 1,
  "messageId": "cmd-01J8M6Y7",
  "deviceId": "aq-01-7c9e4a21",
  "timestamp": "2026-09-28T10:16:01Z",
  "data": {
    "success": false,
    "error": {
      "code": "VALUE_OUT_OF_RANGE",
      "message": "مقدار خارج از محدوده مجاز است"
    }
  }
}
```

کدهای پایه:

```text
INVALID_PAYLOAD
UNSUPPORTED_SCHEMA
UNKNOWN_CAPABILITY
INVALID_ACTION
VALUE_OUT_OF_RANGE
COMMAND_EXPIRED
DEVICE_BUSY
SAFETY_LOCKED
INTERNAL_ERROR
```

## ۱۱. QoS و Retain

| Topic | QoS | Retain | توضیح |
|---|---:|---:|---|
| `manifest` | 1 | بله | آخرین تعریف دستگاه |
| `availability` | 1 | بله | Online/Offline و Last Will |
| `state` | 1 | بله | آخرین وضعیت واقعی |
| `telemetry` | 0 | خیر | دادهٔ پرتکرار |
| `command` | 1 | خیر | جلوگیری از اجرای فرمان قدیمی |
| `command/result` | 1 | خیر | نتیجهٔ فرمان |
| `config/desired` | 1 | بله | تنظیم مورد انتظار |
| `config/reported` | 1 | بله | تنظیم واقعی |
| `event` | 1 | خیر | هشدار و رخداد |
| `ota/*` | 1 | متناسب | فرمان و گزارش OTA |

## ۱۲. Availability و اتصال مجدد

- دستگاه هنگام اتصال، پیام `online` منتشر می‌کند.
- Last Will دستگاه، پیام `offline` با Retain است.
- Payload وضعیت اتصال شامل دلیل راه‌اندازی و Firmware است.
- فاصلهٔ تلاش مجدد با Exponential Backoff و کمی Jitter افزایش می‌یابد.
- پس از اتصال مجدد، Manifest، State و Config Reported دوباره منتشر می‌شوند.

## ۱۳. Provisioning و مالکیت

اطلاعات تولیدی هر دستگاه:

```text
deviceId
productId
hardwareVersion
setupSecret یا Proof of Possession
bootstrapCredential
```

جریان استاندارد:

1. کاربر QR دستگاه را در اپ اسکن می‌کند.
2. اپ از طریق BLE و یک نشست رمزنگاری‌شده به دستگاه متصل می‌شود.
3. اپ SSID و رمز Wi-Fi را ارسال می‌کند.
4. دستگاه با Bootstrap Credential به سرویس ثبت دستگاه متصل می‌شود.
5. Backend مالکیت دستگاه را به حساب کاربر متصل می‌کند.
6. دستگاه اعتبارنامهٔ MQTT اختصاصی و محدود دریافت می‌کند.
7. Bootstrap Credential غیرفعال یا محدود می‌شود.
8. دستگاه Manifest و State اولیه را منتشر می‌کند.

SoftAP فقط روش جایگزین است و باید رمز یکتای هر دستگاه داشته باشد.

## ۱۴. امنیت الزامی

- MQTT فقط از TLS در محیط تولید استفاده کند.
- هر دستگاه Client ID و Credential یکتا داشته باشد.
- ACL دستگاه فقط Topicهای مورد نیاز همان `deviceId` را مجاز کند.
- رمز Broker مدیریتی داخل Firmware یا اپ قرار نگیرد.
- Wi-Fi Password، Token و کلیدها در Log یا Serial چاپ نشوند.
- اطلاعات حساس در فضای امن و رمزگذاری‌شده ذخیره شوند.
- Firmware تولیدی امضاشده باشد.
- Secure Boot، Flash Encryption و OTA Rollback در سخت‌افزار پشتیبانی‌شده فعال شوند.
- کلید Push Notification سمت Backend باقی بماند و داخل دستگاه یا اپ قرار نگیرد.
- Factory Reset مالکیت محلی و Wi-Fi را پاک کند، اما هویت تولیدی دستگاه را حذف نکند.

## ۱۵. OTA

فرمان OTA شامل اطلاعات زیر است:

```json
{
  "schemaVersion": 1,
  "messageId": "ota-01J8M7A1",
  "deviceId": "aq-01-7c9e4a21",
  "timestamp": "2026-09-28T11:00:00Z",
  "data": {
    "version": "1.2.0",
    "url": "https://firmware.example/devices/aqua-controller/1.2.0.bin",
    "sha256": "HEX_SHA256",
    "mandatory": false
  }
}
```

دستگاه باید این مراحل را گزارش دهد:

```text
accepted
downloading
verifying
installing
rebooting
success
failed
rolled_back
```

نسخهٔ جدید فقط پس از بررسی سلامت اولیه قطعی شود؛ در صورت شکست، دستگاه به نسخهٔ سالم قبل برگردد.

## ۱۶. رفتار آفلاین و کنترل محلی

- کنترل‌های ایمنی و Scheduleها روی خود دستگاه ذخیره و اجرا شوند.
- قطع Broker نباید سنسور، کنترل دما یا حفاظت تجهیزات را متوقف کند.
- وضعیت‌های آفلاین مهم در صف محدود نگهداری شوند.
- Telemetry پرتعداد هنگام بازگشت اتصال به‌صورت کنترل‌شده ارسال شود.
- کنترل محلی آینده باید همان مدل Capability و همان قواعد مجوز را استفاده کند.

## ۱۷. نسخه‌بندی

- نسخه سند از Semantic Versioning پیروی می‌کند.
- تغییر سازگار: افزایش Minor، مانند افزودن فیلد اختیاری.
- تغییر ناسازگار: افزایش Major، مانند تغییر نام Topic یا معنی یک فیلد.
- Firmware باید حداقل یک نسخهٔ قبلی Schema را در دورهٔ مهاجرت بپذیرد.
- اپ باید Capability ناشناخته را بدون Crash نادیده بگیرد و پیام مناسب نمایش دهد.

## ۱۸. الزامات حداقلی هر محصول

هر محصول پیش از عرضه باید موارد زیر را داشته باشد:

- `deviceId` و Credential یکتا؛
- Manifest معتبر؛
- Topicهای استاندارد؛
- Availability و Last Will؛
- State واقعی و نتیجهٔ فرمان؛
- Provisioning امن؛
- Factory Reset فیزیکی؛
- OTA امضاشده و Rollback؛
- Watchdog و گزارش دلیل Restart؛
- ثبت نسخهٔ Firmware و Hardware؛
- تست قطع Wi-Fi، قطع Broker و خاموشی برق؛
- محدودیت‌های ایمنی مستقل از Cloud.

## ۱۹. موارد نیازمند تصمیم مالک پروژه

موارد زیر در این Draft عمداً نهایی نشده‌اند:

1. انتخاب Broker و محل استقرار Cloud؛
2. استفاده از Certificate یا Username/Password یکتا برای MQTT؛
3. انتخاب دقیق خانواده ESP32 برای نسل جدید؛
4. نیاز یا عدم نیاز به Gateway محلی؛
5. سطح سازگاری با Matter و Home Assistant؛
6. مدت نگهداری Telemetry؛
7. نحوهٔ اشتراک‌گذاری دستگاه با اعضای خانواده؛
8. سیاست اجباری یا اختیاری‌بودن OTA؛
9. تعریف نهایی ظاهر و Componentهای رابط شیشه‌ای اپ.

## ۲۰. معیار تأیید نسخهٔ ۱

این سند زمانی از Draft خارج می‌شود که:

- مالک پروژه ساختار Topicها را تأیید کند؛
- مدل Manifest و Capability تأیید شود؛
- روش Provisioning انتخاب شود؛
- مدل هویت و مالکیت دستگاه مشخص شود؛
- سیاست امنیت و OTA تأیید شود؛
- یک ماژول آزمایشی و یک صفحهٔ آزمایشی اپ با این قرارداد تست شوند.

