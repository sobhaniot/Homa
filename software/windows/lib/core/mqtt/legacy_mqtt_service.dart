import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import '../../modules/refrigerator/refrigerator_snapshot.dart';
import '../storage/telemetry_database.dart';

/// MQTT ماژول‌های قدیمی را بدون تغییر قالب پیام فریم‌ور مدیریت می‌کند.
class LegacyMqttService {
  LegacyMqttService({TelemetryDatabase? database})
    : _database = database ?? TelemetryDatabase();

  static const defaultHost = 'test.mosquitto.org';
  static const defaultPort = 1883;
  static const requestTopic = '/eleknow.com/nahbos5672730/home/refrigerator';
  static const responseTopic =
      '/eleknow.com/nahbos5672730/home/refrigeratorResult';
  static const historyRequestTopic =
      '/eleknow.com/nahbos5672730/home/history/request';
  static const historyResponseTopic =
      '/eleknow.com/nahbos5672730/home/history/response';
  static const refrigeratorModuleId = 'refrigerator';
  static const _historyPageSize = 100;

  final TelemetryDatabase _database;
  TelemetryDatabase get database => _database;
  void reportStatus(String value) => _statusController.add(value);
  void reportSnapshot(RefrigeratorSnapshot value) =>
      _snapshotController.add(value);
  void reportHistory(List<TelemetryRecord> value) =>
      _historyController.add(value);
  final _snapshotController =
      StreamController<RefrigeratorSnapshot>.broadcast();
  final _historyController =
      StreamController<List<TelemetryRecord>>.broadcast();
  final _statusController = StreamController<String>.broadcast();
  MqttServerClient? _client;
  StreamSubscription<List<MqttReceivedMessage<MqttMessage>>>? _updates;
  Timer? _pollTimer;
  Timer? _historyTimeout;
  Timer? _historyRetryTimer;
  int _intervalSeconds = 10;
  bool _connected = false;
  bool _historySyncActive = false;
  String? _historyRequestId;
  int _historyOffset = 0;
  late DateTime _historyFrom;
  late DateTime _historyTo;

  Stream<RefrigeratorSnapshot> get snapshots => _snapshotController.stream;
  Stream<List<TelemetryRecord>> get history => _historyController.stream;
  Stream<String> get statuses => _statusController.stream;
  bool get isConnected => _connected;

  Future<String?> getSetting(String key) => _database.getSetting(key);

  Future<void> saveSetting(String key, String value) =>
      _database.saveSetting(key, value);

  Future<void> deleteSetting(String key) => _database.deleteSetting(key);

  Future<List<TelemetryRecord>> loadRecentHistory() async {
    await _database.open();
    return _database.readRecent(moduleId: refrigeratorModuleId);
  }

  Future<List<TelemetryRecord>> loadHistory({
    required DateTime from,
    required DateTime to,
    int limit = 600,
    String moduleId = refrigeratorModuleId,
  }) async {
    await _database.open();
    return _database.readRange(
      moduleId: moduleId,
      from: from,
      to: to,
      limit: limit,
    );
  }

  Future<void> connect(String host, int port) async {
    await disconnect();
    await _database.open();
    final clientId =
        'homa-win-${Random().nextInt(0x7fffffff).toRadixString(16)}';
    final client = MqttServerClient.withPort(host, clientId, port)
      ..logging(on: false)
      ..keepAlivePeriod = 30
      ..connectTimeoutPeriod = 10000
      ..autoReconnect = false
      ..setProtocolV311()
      ..connectionMessage = MqttConnectMessage()
          .withClientIdentifier(clientId)
          .startClean();

    client.onDisconnected = () {
      _connected = false;
      _pollTimer?.cancel();
      _stopHistorySync();
      _statusController.add('ارتباط با بروکر قطع شد');
    };
    _client = client;
    _statusController.add('در حال اتصال به $host:$port');

    try {
      await client.connect();
      if (client.connectionStatus?.state != MqttConnectionState.connected) {
        throw StateError('اتصال MQTT برقرار نشد.');
      }
      _connected = true;
      client.subscribe(responseTopic, MqttQos.atMostOnce);
      client.subscribe(historyResponseTopic, MqttQos.atMostOnce);
      _updates = client.updates?.listen(_handleMessages);
      _statusController.add('متصل به بروکر؛ دریافت اطلاعات یخچال آغاز شد');

      // ثبت تاریخچه روی ویندوز قبل از همگام‌سازی اولیه انجام می‌شود.
      _historyController.add(
        await _database.readRecent(moduleId: refrigeratorModuleId),
      );
      await Future<void>.delayed(const Duration(milliseconds: 500));
      _publishInfo();
      _startPolling(_intervalSeconds);
      await _startHistorySync();
    } catch (error) {
      _statusController.add('خطای اتصال MQTT: $error');
      await disconnect();
      rethrow;
    }
  }

  void setPollingInterval(int seconds) {
    if (seconds < 1 || seconds > 86400) {
      throw ArgumentError.value(
        seconds,
        'seconds',
        'بازهٔ مجاز ۱ تا ۸۶۴۰۰ است.',
      );
    }
    _intervalSeconds = seconds;
    if (_connected) _startPolling(seconds);
  }

  /// آخرین تاریخچهٔ تبلت را تا نقطهٔ دریافت‌شدهٔ ویندوز دوباره درخواست می‌کند.
  Future<void> syncTabletHistory() => _startHistorySync();

  Future<void> publishParameters({
    required double temperature,
    required double hysteresis,
  }) async {
    final client = _client;
    if (!_connected || client == null) {
      throw StateError('برای ارسال تنظیمات ابتدا به بروکر وصل شو.');
    }
    // قالب Param همان قالبی است که فریم‌ور قدیمی یخچال دریافت می‌کند.
    final payload = jsonEncode({
      'type': 'Param',
      'Temp': temperature,
      'Hyster': hysteresis,
    });
    _publish(requestTopic, payload);
    _statusController.add('تنظیمات یخچال ارسال شد');
  }

  void _startPolling(int seconds) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      Duration(seconds: seconds),
      (_) => _publishInfo(),
    );
  }

  void _publishInfo() {
    if (!_connected) return;
    _publish(requestTopic, '{"type":"Info"}');
    _statusController.add('درخواست Info ارسال شد؛ منتظر پاسخ…');
  }

  /// درخواست صریح رابط کنترل، مستقل از تایمر دریافت دوره‌ای است.
  Future<void> requestInfo() async {
    if (!_connected) throw StateError('MQTT is disconnected');
    _publishInfo();
  }

  void _publish(String topic, String payload) {
    final client = _client;
    if (client == null ||
        client.connectionStatus?.state != MqttConnectionState.connected) {
      return;
    }
    final builder = MqttClientPayloadBuilder()..addString(payload);
    client.publishMessage(topic, MqttQos.atMostOnce, builder.payload!);
  }

  void _handleMessages(List<MqttReceivedMessage<MqttMessage>> messages) {
    for (final message in messages) {
      final packet = message.payload;
      if (packet is! MqttPublishMessage) continue;
      final payload = MqttPublishPayload.bytesToStringAsString(
        packet.payload.message,
      );
      if (message.topic == historyResponseTopic) {
        unawaited(_handleHistoryPage(payload));
      } else if (message.topic == responseTopic) {
        unawaited(_saveLiveMessage(payload));
      }
    }
  }

  Future<void> _saveLiveMessage(String payload) async {
    try {
      final snapshot = RefrigeratorSnapshot.fromPayload(payload);
      await _database.save(
        TelemetryRecord(
          moduleId: refrigeratorModuleId,
          receivedAt: DateTime.now(),
          payload: payload,
        ),
      );
      _snapshotController.add(snapshot);
      _historyController.add(
        await _database.readRecent(moduleId: refrigeratorModuleId),
      );
      _statusController.add('اطلاعات یخچال دریافت و ذخیره شد');
    } on FormatException catch (error) {
      _statusController.add('قالب پاسخ یخچال معتبر نیست: $error');
    } catch (error) {
      _statusController.add('ذخیرهٔ محلی داده ناموفق بود: $error');
    }
  }

  Future<void> _startHistorySync() async {
    if (!_connected || _historySyncActive) return;
    _historyRetryTimer?.cancel();
    _historyRetryTimer = null;
    final now = DateTime.now();
    final pendingFrom = await _database.getSetting('history_pending_from');
    final pendingTo = await _database.getSetting('history_pending_to');
    final pendingOffset = await _database.getSetting('history_pending_offset');
    if (pendingFrom != null && pendingTo != null) {
      // اگر ویندوز هنگام همگام‌سازی بسته شد، همان بازه و صفحه ادامه پیدا می‌کند.
      _historyFrom = DateTime.fromMillisecondsSinceEpoch(
        int.tryParse(pendingFrom) ?? 0,
      );
      _historyTo = DateTime.fromMillisecondsSinceEpoch(
        int.tryParse(pendingTo) ?? now.millisecondsSinceEpoch,
      );
      _historyOffset = int.tryParse(pendingOffset ?? '') ?? 0;
    } else {
      final lastComplete = await _database.getSetting(
        'history_sync_through_ms',
      );
      final lastCompleteMs = int.tryParse(lastComplete ?? '') ?? 0;
      // اجرای نخست کل بایگانی را می‌گیرد؛ اجرای بعدی از هم‌پوشانی دوثانیه‌ای ادامه می‌دهد.
      _historyFrom = DateTime.fromMillisecondsSinceEpoch(
        max(0, lastCompleteMs - 2000),
      );
      _historyTo = now;
      _historyOffset = 0;
      await _database.saveSetting(
        'history_pending_from',
        '${_historyFrom.millisecondsSinceEpoch}',
      );
      await _database.saveSetting(
        'history_pending_to',
        '${_historyTo.millisecondsSinceEpoch}',
      );
      await _database.saveSetting('history_pending_offset', '0');
    }
    _historyRequestId =
        'homa-${now.microsecondsSinceEpoch}-${Random().nextInt(1 << 20)}';
    _historySyncActive = true;
    _statusController.add('درخواست همگام‌سازی تاریخچه از تبلت ارسال شد');
    _requestHistoryPage();
  }

  void _requestHistoryPage() {
    if (!_historySyncActive || !_connected) return;
    _historyTimeout?.cancel();
    // تبلت Android قدیمی و بروکر آزمایشی ممکن است برای پاسخ کمی تأخیر داشته باشند.
    _historyTimeout = Timer(const Duration(seconds: 30), () {
      if (!_historySyncActive) return;
      _stopHistorySync();
      _statusController.add(
        'تبلت پاسخ همگام‌سازی نداد؛ اتصال تبلت به همان بروکر را بررسی کن',
      );
      _scheduleHistoryRetry();
    });
    _publish(
      historyRequestTopic,
      jsonEncode({
        'type': 'HistoryRequest',
        'requestId': _historyRequestId,
        'from': _historyFrom.millisecondsSinceEpoch,
        'to': _historyTo.millisecondsSinceEpoch,
        'offset': _historyOffset,
        'limit': _historyPageSize,
      }),
    );
  }

  Future<void> _handleHistoryPage(String payload) async {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic> ||
          decoded['type'] != 'HistoryBatch' ||
          decoded['requestId'] != _historyRequestId ||
          !_historySyncActive) {
        return;
      }
      final items = decoded['items'];
      if (items is! List) {
        throw const FormatException('فهرست تاریخچه معتبر نیست.');
      }
      final records = <TelemetryRecord>[];
      for (final item in items) {
        if (item is! Map<String, dynamic>) continue;
        final receivedAt = item['receivedAt'];
        final data = item['payload'];
        if (receivedAt is! num || data is! Map<String, dynamic>) continue;
        records.add(
          TelemetryRecord(
            moduleId: refrigeratorModuleId,
            receivedAt: DateTime.fromMillisecondsSinceEpoch(receivedAt.toInt()),
            payload: jsonEncode(data),
          ),
        );
      }
      await _database.saveBatch(records);
      _historyTimeout?.cancel();
      final hasMore = decoded['hasMore'] == true;
      if (hasMore) {
        final nextOffset = decoded['nextOffset'];
        if (nextOffset is! num || nextOffset.toInt() <= _historyOffset) {
          throw const FormatException('صفحه‌بندی تاریخچه جلو نرفت.');
        }
        _historyOffset = nextOffset.toInt();
        await _database.saveSetting(
          'history_pending_offset',
          '$_historyOffset',
        );
        _requestHistoryPage();
        return;
      }

      await _database.saveSetting(
        'history_sync_through_ms',
        '${_historyTo.millisecondsSinceEpoch}',
      );
      await _database.deleteSetting('history_pending_from');
      await _database.deleteSetting('history_pending_to');
      await _database.deleteSetting('history_pending_offset');
      _stopHistorySync();
      _historyController.add(
        await _database.readRecent(moduleId: refrigeratorModuleId),
      );
      _statusController.add('تاریخچهٔ تبلت با پایگاه دادهٔ ویندوز همگام شد');
      _scheduleHistoryRetry();
    } on FormatException catch (error) {
      _stopHistorySync();
      _statusController.add('پاسخ همگام‌سازی معتبر نیست: $error');
      _scheduleHistoryRetry();
    } catch (error) {
      _stopHistorySync();
      _statusController.add('همگام‌سازی تاریخچه ناموفق بود: $error');
      _scheduleHistoryRetry();
    }
  }

  void _scheduleHistoryRetry() {
    _historyRetryTimer?.cancel();
    if (!_connected) return;
    // تا زمانی که ویندوز آنلاین است، آرشیو را هر دقیقه با داده‌های تازه تطبیق می‌دهیم.
    _historyRetryTimer = Timer(const Duration(minutes: 1), () {
      _historyRetryTimer = null;
      unawaited(_startHistorySync());
    });
  }

  void _stopHistorySync() {
    _historyTimeout?.cancel();
    _historyTimeout = null;
    _historySyncActive = false;
    _historyRequestId = null;
    _historyOffset = 0;
  }

  Future<void> disconnect() async {
    _pollTimer?.cancel();
    _pollTimer = null;
    _historyRetryTimer?.cancel();
    _historyRetryTimer = null;
    _stopHistorySync();
    await _updates?.cancel();
    _updates = null;
    final client = _client;
    _client = null;
    _connected = false;
    if (client != null) {
      try {
        client.disconnect();
      } catch (_) {
        // هنگام بسته‌شدن سوکت، خطای قطع اتصال نباید بستن برنامه را متوقف کند.
      }
    }
  }

  Future<void> dispose() async {
    await disconnect();
    await _database.close();
    await _snapshotController.close();
    await _historyController.close();
    await _statusController.close();
  }
}
