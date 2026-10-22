import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'mqtt/legacy_mqtt_service.dart';
import '../modules/refrigerator/refrigerator_snapshot.dart';

/// ویندوز هیچ MQTT مستقیمی ندارد؛ رزبری جمع‌کننده و بافر است، SQLite ویندوز آرشیو اصلی.
class RaspberryService extends LegacyMqttService {
  RaspberryService({
    super.database,
    this.sessionPath,
    this.syncInterval = const Duration(seconds: 10),
  });
  final String? sessionPath;
  final Duration syncInterval;
  HttpClient _http = HttpClient()
    ..connectionTimeout = const Duration(seconds: 8);
  Uri? _base;
  String? _token;
  Timer? _timer;
  bool _active = false, _connected = false;
  Future<void>? _inFlight;
  Map<String, dynamic>? module;
  List<Map<String, dynamic>> moduleDefinitions = [];
  bool supportsServerUi = false;
  String? streamId;
  String? _consumer;
  String? syncError;
  bool needsLogin = false;
  bool authRequired = true;
  @override
  bool get isConnected => _connected;

  File get _session => File(
    sessionPath ??
        '${Platform.environment['APPDATA'] ?? Directory.current.path}/Homa/raspberry-session.json',
  );
  Uri _address(String host, int port) =>
      Uri(scheme: 'http', host: host, port: port);

  Future<dynamic> _request(
    String method,
    String path, [
    Map<String, dynamic>? data,
  ]) async {
    final req = await _http
        .openUrl(method, _base!.resolve(path))
        .timeout(const Duration(seconds: 10));
    req.followRedirects = false;
    req.headers.contentType = ContentType.json;
    if (_token != null) req.headers.set('Authorization', 'Bearer $_token');
    if (data != null) {
      // سرور سبک رزبری Content-Length لازم دارد و بدنهٔ chunked را نمی‌خواند.
      final bytes = utf8.encode(jsonEncode(data));
      req.contentLength = bytes.length;
      req.add(bytes);
    }
    final response = await req.close().timeout(const Duration(seconds: 15));
    final text = await utf8.decoder
        .bind(response)
        .join()
        .timeout(const Duration(seconds: 15));
    final body = jsonDecode(text);
    if (response.statusCode == 401) {
      needsLogin = true;
      throw StateError(
        'ورود به رزبری لازم است؛ نام کاربری و رمز پنل را وارد کنید.',
      );
    }
    if (response.statusCode >= 300) {
      throw StateError(body is Map ? '${body['error']}' : 'خطای API رزبری');
    }
    return body;
  }

  Future<void> loginAndConnect(
    String host,
    int port,
    String username,
    String password,
  ) async {
    await disconnect();
    _http = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    _base = _address(host, port);
    _token = null;
    final result = await _request('POST', '/api/login', {
      'username': username,
      'password': password,
      'remember': true,
    });
    _token = result['token'] as String;
    needsLogin = false;
    await _session.parent.create(recursive: true);
    // فقط توکن نشست ذخیره می‌شود؛ رمز عبور هرگز نوشته نمی‌شود.
    await _session.writeAsString(
      jsonEncode({'url': _base.toString(), 'token': _token}),
      flush: true,
    );
    await connect(host, port);
  }

  @override
  Future<void> connect(String host, int port) async {
    await disconnect();
    _http = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    _base = _address(host, port);
    _token = null;
    if (await _session.exists()) {
      final saved = jsonDecode(await _session.readAsString());
      if (saved['url'] == _base.toString()) _token = saved['token'] as String?;
    }
    final auth = await _request('GET', '/api/auth-mode');
    authRequired = auth['required'] != false;
    if (_token == null && authRequired) {
      needsLogin = true;
      throw StateError('نام کاربری و رمز پنل رزبری را وارد کنید.');
    }
    needsLogin = false;
    _consumer = await database.getSetting('archive_consumer');
    if (_consumer == null) {
      _consumer =
          'win-${List.generate(16, (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
      await database.saveSetting('archive_consumer', _consumer!);
    }
    _active = true;
    _timer = Timer.periodic(syncInterval, (_) {
      unawaited(syncNow());
    });
    await syncNow();
  }

  Future<void> syncNow() {
    if (!_active) return Future.value();
    return _inFlight ??= _synchronize().whenComplete(() => _inFlight = null);
  }

  Future<void> _synchronize() async {
    try {
      final registration = await _request('POST', '/api/archive/register', {
        'consumer': _consumer,
      });
      final stream = registration['stream_id'] as String;
      final through = registration['through'] as int;
      streamId = stream;
      var cursor = await database.archiveCheckpoint(stream);
      if (cursor > through) {
        throw StateError(
          'شناسه‌های منبع عقب رفته‌اند؛ بررسی بازیابی دیتابیس رزبری لازم است.',
        );
      }
      var added = 0;
      while (_active) {
        final page = await _request(
          'GET',
          '/api/archive/page?consumer=$_consumer&after=$cursor&through=$through&limit=200',
        );
        if (!_active) return;
        if (page['stream_id'] != stream) {
          throw StateError('منبع حین انتقال تغییر کرد');
        }
        final rows = (page['items'] as List)
            .map((r) => Map<String, dynamic>.from(r as Map))
            .toList();
        final next = page['next_after'] as int;
        if (rows.isNotEmpty && next <= cursor) {
          throw const FormatException('Archive did not advance');
        }
        await database.commitArchivePage(stream, rows, next);
        // ACK تنها بعد از COMMIT SQLite ارسال می‌شود. شکست ACK به معنای از دست رفتن داده نیست.
        await _request('POST', '/api/archive/ack', {
          'consumer': _consumer,
          'stream_id': stream,
          'after': next,
        });
        cursor = next;
        added += rows.length;
        if (rows.length < 200 || cursor >= through) break;
      }
      if (!_active) return;
      final modules = await _request('GET', '/api/modules') as List;
      supportsServerUi = modules.every((m) => m['ui'] is Map);
      moduleDefinitions = modules
          .map((m) => Map<String, dynamic>.from(m as Map))
          .where((m) => m['enabled'] == true)
          .toList();
      await database.saveArchiveModules(stream, modules);
      module = null;
      for (final item in modules) {
        if (item['id'] == 'refrigerator') {
          module = Map<String, dynamic>.from(item as Map);
        }
      }
      final latest = module?['latest'];
      if (latest is Map && latest['payload'] is String) {
        reportSnapshot(
          RefrigeratorSnapshot.fromPayload(latest['payload'] as String),
        );
      }
      reportHistory(await loadRecentHistory());
      _connected = true;
      syncError = null;
      reportStatus(
        'متصل به رزبری؛ آرشیو کامپیوتر به‌روز شد ($added رکورد تازه).',
      );
    } catch (error) {
      if (!_active) return;
      _connected = false;
      syncError = '$error';
      if (needsLogin) {
        _timer?.cancel();
        _active = false;
      }
      reportStatus(
        'همگام‌سازی متوقف شد: $error${needsLogin ? '' : '؛ تلاش مجدد خودکار انجام می‌شود.'}',
      );
    }
  }

  @override
  Future<void> syncTabletHistory() => syncNow();

  Future<void> updatePolling(int seconds) async {
    if (seconds < 5 || seconds > 86400) {
      throw ArgumentError('بازهٔ مجاز ۵ تا ۸۶۴۰۰ ثانیه است');
    }
    if (!_connected || module == null) {
      throw StateError('ابتدا به رزبری وصل شوید');
    }
    final data = Map<String, dynamic>.from(module!)..['interval'] = seconds;
    module = Map<String, dynamic>.from(
      await _request('PUT', '/api/modules', data) as Map,
    );
  }

  Future<void> saveModuleValues(
    Map<String, dynamic> definition,
    Map<String, dynamic> values,
  ) async {
    if (!_connected) throw StateError('رزبری در دسترس نیست');
    final ui = definition['ui'] as Map;
    await _request('POST', '/api/modules/${definition['id']}/settings', {
      'confirm': true,
      'schema_revision': ui['revision'],
      'values': values,
    });
    reportStatus('مقادیر در صف ارسال قرار گرفت؛ هنوز تأیید دستگاه نیست.');
  }

  @override
  Future<void> requestInfo() async {
    if (!_connected) throw StateError('رزبری در دسترس نیست');
    await _request('POST', '/api/modules/refrigerator/request', {});
    reportStatus('درخواست Info از طریق رزبری در صف قرار گرفت.');
  }

  @override
  Future<void> publishParameters({
    required double temperature,
    required double hysteresis,
  }) async {
    if (!_connected) throw StateError('رزبری در دسترس نیست');
    await _request('POST', '/api/modules/refrigerator/parameters', {
      'temperature': temperature,
      'hysteresis': hysteresis,
      'confirm': true,
    });
    reportStatus(
      'تنظیمات از طریق رزبری در صف قرار گرفت؛ هنوز تأیید دستگاه نیست.',
    );
  }

  @override
  Future<void> disconnect() async {
    _active = _connected = false;
    _timer?.cancel();
    _timer = null;
    _http.close(force: true);
    await _inFlight;
  }
}
