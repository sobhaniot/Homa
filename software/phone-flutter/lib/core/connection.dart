import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import 'settings.dart';

abstract class BrokerLink {
  Future<void> open(
    Endpoint endpoint,
    List<String> topics,
    void Function(String, String) onMessage,
    VoidCallback onLost,
  );
  void send(String topic, String payload);
  void close();
}

class MqttLink implements BrokerLink {
  MqttServerClient? _client;
  StreamSubscription<dynamic>? _stream;
  bool _closed = false;
  @override
  Future<void> open(
    Endpoint endpoint,
    List<String> topics,
    void Function(String, String) onMessage,
    VoidCallback onLost,
  ) async {
    final id =
        'homa-phone-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(999999)}';
    final client = MqttServerClient.withPort(endpoint.host, id, endpoint.port)
      ..logging(on: false)
      ..keepAlivePeriod = 20
      ..connectTimeoutPeriod = 4000
      ..autoReconnect = false;
    _client = client;
    client.setProtocolV311();
    client.connectionMessage = MqttConnectMessage()
        .withClientIdentifier(id)
        .startClean();
    client.onDisconnected = () {
      if (!_closed) onLost();
    };
    try {
      await client.connect().timeout(const Duration(seconds: 6));
      if (_closed ||
          client.connectionStatus?.state != MqttConnectionState.connected) {
        throw StateError('اتصال برقرار نشد');
      }
      _stream = client.updates!.listen((messages) {
        for (final message in messages) {
          final packet = message.payload as MqttPublishMessage;
          onMessage(
            message.topic,
            MqttPublishPayload.bytesToStringAsString(packet.payload.message),
          );
        }
      });
      // اتصال فقط پس از تأیید اشتراک همهٔ کارت‌ها آماده محسوب می‌شود.
      final pending = topics.toSet();
      final ready = Completer<void>();
      client.onSubscribed = (topic) {
        pending.remove(topic);
        if (pending.isEmpty && !ready.isCompleted) ready.complete();
      };
      for (final topic in topics) {
        client.subscribe(topic, MqttQos.atMostOnce);
      }
      if (topics.isNotEmpty) {
        await ready.future.timeout(const Duration(seconds: 5));
      }
      if (_closed ||
          client.connectionStatus?.state != MqttConnectionState.connected) {
        throw StateError('اتصال قطع شد');
      }
    } catch (_) {
      close();
      rethrow;
    }
  }

  @override
  void send(String topic, String payload) {
    final builder = MqttClientPayloadBuilder()..addUTF8String(payload);
    _client!.publishMessage(topic, MqttQos.atMostOnce, builder.payload!);
  }

  @override
  void close() {
    _closed = true;
    _stream?.cancel();
    _client?.disconnect();
  }
}

class Sample {
  final DateTime receivedAt;
  final Map<String, dynamic> values;
  const Sample(this.receivedAt, this.values);
  static Sample? parse(String raw) {
    try {
      final envelope = jsonDecode(raw) as Map<String, dynamic>;
      final timestamp = envelope['received_at'];
      if (timestamp is! num || !timestamp.isFinite || timestamp <= 0) {
        return null;
      }
      final payload = envelope['payload'];
      final values = payload is String ? jsonDecode(payload) : payload;
      if (values is! Map<String, dynamic>) return null;
      return Sample(
        DateTime.fromMillisecondsSinceEpoch((timestamp * 1000).round()),
        values,
      );
    } catch (_) {
      return null;
    }
  }
}

class PhoneController extends ChangeNotifier {
  final SettingsStore store;
  final BrokerLink Function() linkFactory;
  final Duration retryDelay, probeInterval;
  PhoneSettings settings = const PhoneSettings();
  String status = 'آمادهٔ اتصال', route = '';
  bool busy = false, _disposed = false;
  int _generation = 0;
  BrokerLink? _active, _candidate;
  Timer? _retry, _probe;
  final List<Timer> _polls = [];
  final Map<String, Sample> samples = {};
  final List<String> messages = [];
  List<ModuleProfile> modules = [];
  bool catalogLoaded = false, settingsAllowed = false;
  final String clientId =
      'phone_${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(999999)}';
  final Map<String, Completer<Map<String, dynamic>>> _commands = {};
  String _pollSignature = '';
  PhoneController({
    required this.store,
    BrokerLink Function()? linkFactory,
    this.retryDelay = const Duration(seconds: 4),
    this.probeInterval = const Duration(seconds: 45),
  }) : linkFactory = linkFactory ?? MqttLink.new;
  bool get connected => _active != null;
  void _update(String text) {
    if (_disposed) return;
    status = text;
    messages.insert(
      0,
      '${DateTime.now().toIso8601String().substring(11, 19)}  $text',
    );
    if (messages.length > 60) messages.removeLast();
    notifyListeners();
  }

  Future<void> start() async {
    try {
      settings = await store.load();
    } catch (_) {
      _update('خواندن تنظیمات ناموفق؛ تنظیمات پیش‌فرض استفاده شد');
    }
    if (!_disposed) await reconnect();
  }

  Future<void> save(PhoneSettings value) async {
    final error = value.validate();
    if (error != null) throw FormatException(error);
    await store.save(value);
    settings = value;
    samples.clear();
    await reconnect();
  }

  void _clearTimers() {
    _retry?.cancel();
    _probe?.cancel();
    for (final t in _polls) {
      t.cancel();
    }
    _polls.clear();
    for (final timer in _moduleTimers) {
      timer.cancel();
    }
    _moduleTimers.clear();
    _pollSignature = '';
  }

  Future<void> reconnect() async {
    if (_disposed) return;
    final generation = ++_generation;
    _clearTimers();
    _active?.close();
    _active = null;
    _candidate?.close();
    route = '';
    busy = true;
    for (final target in ['local', 'external']) {
      if (_disposed || generation != _generation) return;
      _update(
        target == 'local'
            ? 'در حال اتصال به بروکر داخلی…'
            : 'داخلی در دسترس نیست؛ اتصال بیرونی…',
      );
      if (await _attempt(target, generation)) return;
    }
    if (_disposed || generation != _generation) return;
    busy = false;
    _update('آفلاین؛ تلاش مجدد خودکار');
    _retry = Timer(retryDelay, reconnect);
  }

  Future<bool> _attempt(String target, int generation) async {
    final link = linkFactory();
    _candidate = link;
    try {
      await link.open(
        target == 'local' ? settings.local : settings.external,
        [
          'homa/${settings.installation}/catalog/state',
          'homa/${settings.installation}/modules/+/state',
          'homa/${settings.installation}/clients/$clientId/result',
        ],
        (topic, raw) {
          if (_disposed || generation != _generation || _active != link) return;
          final root = 'homa/${settings.installation}';
          if (topic == '$root/catalog/state') {
            try {
              final data = jsonDecode(raw) as Map<String, dynamic>;
              if (data['installation'] != settings.installation ||
                  data['version'] != 1) {
                return;
              }
              final entries = (data['modules'] as List)
                  .cast<Map<String, dynamic>>();
              final found = entries.map(ModuleProfile.fromCatalog).toList();
              if (found.any(
                (m) =>
                    m.refreshSeconds < 5 ||
                    m.refreshSeconds > 86400 ||
                    !RegExp(r'^[a-z0-9_-]{1,40}$').hasMatch(m.id),
              )) {
                return;
              }
              modules = found;
              catalogLoaded = true;
              settingsAllowed =
                  data['settings_allowed'] == true && route == 'local';
              for (final entry in entries) {
                final latest = entry['latest'];
                if (latest is Map) {
                  _acceptSample(
                    entry['id'],
                    jsonEncode({
                      'received_at': latest['ts'],
                      'payload': latest['payload'],
                    }),
                  );
                }
              }
              _scheduleModules();
              _update('فهرست و تعریف کارت‌ها از رزبری دریافت شد');
            } catch (_) {
              _update('تعریف کارت نامعتبر از سرور دریافت شد');
            }
            return;
          }
          if (topic == '$root/clients/$clientId/result') {
            if (route != 'local') return;
            try {
              final result = jsonDecode(raw) as Map<String, dynamic>;
              final pending = _commands.remove(result['request_id']);
              if (pending != null && !pending.isCompleted) {
                pending.complete(result);
              }
            } catch (_) {
              /* پاسخ نامرتبط وارد فرم نمی‌شود. */
            }
            return;
          }
          for (final module in modules) {
            if (topic != '${settings.root(module.id)}/state') continue;
            _acceptSample(module.id, raw);
            _update('دادهٔ ${module.title} دریافت شد');
          }
        },
        () {
          if (!_disposed && generation == _generation && _active == link) {
            link.close();
            _active = null;
            route = '';
            _clearTimers();
            _update('ارتباط قطع شد؛ تلاش از مسیر داخلی');
            _retry = Timer(retryDelay, reconnect);
          }
        },
      );
      if (_disposed || generation != _generation) {
        link.close();
        return false;
      }
      final previous = _active;
      _active = link;
      _candidate = null;
      route = target;
      busy = false;
      catalogLoaded = settingsAllowed = false;
      modules = [];
      _pollSignature = '';
      previous?.close();
      _clearTimers();
      _update(
        target == 'local' ? 'متصل به بروکر داخلی' : 'متصل به بروکر خارجی',
      );
      requestCatalog();
      _polls.add(
        Timer.periodic(const Duration(seconds: 10), (_) => requestCatalog()),
      );
      if (target == 'external') {
        _probe = Timer.periodic(probeInterval, (_) => probeLocal());
      }
      return true;
    } catch (_) {
      link.close();
      if (_candidate == link) _candidate = null;
      return false;
    }
  }

  Future<void> probeLocal() async {
    if (_disposed || route != 'external' || _candidate != null) return;
    // هنگام بررسی شبکهٔ خانه، ارتباط بیرونی تا موفقیت اشتراک محلی حفظ می‌شود.
    await _attempt('local', _generation);
  }

  void request(ModuleProfile module) {
    try {
      _active?.send('${settings.root(module.id)}/request', '{"type":"Info"}');
    } catch (_) {
      _update('ارسال درخواست ناموفق');
    }
  }

  void _acceptSample(String id, String raw) {
    final sample = Sample.parse(raw);
    if (sample != null &&
        (samples[id] == null ||
            !sample.receivedAt.isBefore(samples[id]!.receivedAt))) {
      samples[id] = sample;
    }
  }

  final List<Timer> _moduleTimers = [];
  void _scheduleModules() {
    final signature = modules
        .map((m) => '${m.id}:${m.refreshSeconds}')
        .join('|');
    if (signature == _pollSignature) return;
    _pollSignature = signature;
    for (final timer in _moduleTimers) {
      timer.cancel();
    }
    _moduleTimers.clear();
    for (final module in modules) {
      request(module);
      _moduleTimers.add(
        Timer.periodic(
          Duration(seconds: module.refreshSeconds),
          (_) => request(module),
        ),
      );
    }
  }

  void requestCatalog() {
    try {
      _active?.send(
        'homa/${settings.installation}/catalog/request',
        '{"type":"Info"}',
      );
    } catch (_) {
      _update('درخواست فهرست ناموفق');
    }
  }

  Future<Map<String, dynamic>> saveValues(
    ModuleProfile module,
    Map<String, dynamic> values,
  ) async {
    if (!connected || route != 'local' || !settingsAllowed) {
      throw StateError('تغییر تنظیمات فقط با اتصال داخلی مجاز است');
    }
    final requestId =
        'cmd_${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(999999)}';
    final pending = Completer<Map<String, dynamic>>();
    _commands[requestId] = pending;
    try {
      _active!.send(
        '${settings.root(module.id)}/settings',
        jsonEncode({
          'client_id': clientId,
          'request_id': requestId,
          'schema_revision': module.revision,
          'confirm': true,
          'values': values,
        }),
      );
      final result = await pending.future.timeout(const Duration(seconds: 10));
      if (result['error'] != null) throw StateError('${result['error']}');
      return result;
    } on TimeoutException {
      throw StateError(
        'پاسخ سرور نرسید؛ نتیجهٔ ارسال نامشخص است و خودکار تکرار نشد',
      );
    } finally {
      _commands.remove(requestId);
    }
  }

  void suspend() {
    // در پس‌زمینه درخواست دوره‌ای تولید نمی‌کنیم؛ بازگشت اپ اتصال تازه می‌سازد.
    _generation++;
    _clearTimers();
    _candidate?.close();
    _candidate = null;
    _active?.close();
    _active = null;
    route = '';
    busy = false;
    _update('متوقف در پس‌زمینه');
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _clearTimers();
    _candidate?.close();
    _active?.close();
    super.dispose();
  }
}
