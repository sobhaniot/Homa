import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../charts/temperature_chart.dart';
import '../archive/archive_page.dart';
import '../core/control_api.dart';
import '../core/raspberry_service.dart';
import '../core/mqtt/legacy_mqtt_service.dart';
import '../core/storage/telemetry_database.dart';
import '../modules/refrigerator/refrigerator_snapshot.dart';
import '../modules/server_module_cards.dart';

class HomaApp extends StatelessWidget {
  const HomaApp({super.key, this.mqttService});

  final LegacyMqttService? mqttService;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF38D6C5);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Homa | پایش خانه',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: accent,
          brightness: Brightness.dark,
          surface: const Color(0xFF1A2B38),
        ),
        scaffoldBackgroundColor: const Color(0xFF101923),
        fontFamily: 'Segoe UI',
      ),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: DashboardPage(mqttService: mqttService),
      ),
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, this.mqttService});

  final LegacyMqttService? mqttService;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late final LegacyMqttService _mqtt;
  ControlApi? _control;
  final List<String> _controlMessages = [];
  final _hostController = TextEditingController(
    text: LegacyMqttService.defaultHost,
  );
  final _portController = TextEditingController(
    text: '${LegacyMqttService.defaultPort}',
  );
  final _temperatureController = TextEditingController(text: '9.0');
  final _hysteresisController = TextEditingController(text: '1.0');
  final _intervalController = TextEditingController(text: '10');
  final _serverUser = TextEditingController();
  final _serverPassword = TextEditingController();
  bool _showServerPassword = false;
  final List<TemperaturePoint> _points = [];
  StreamSubscription<RefrigeratorSnapshot>? _snapshotSubscription;
  StreamSubscription<List<TelemetryRecord>>? _historySubscription;
  StreamSubscription<String>? _statusSubscription;
  RefrigeratorSnapshot? _snapshot;
  String _status = 'آمادهٔ اتصال به بروکر آزمایشی';
  String? _rawError;
  DateTime? _lastReceived;
  bool _connected = false;
  bool _connecting = false;
  String _chartPeriod = '24h';
  int _pollInterval = 10;
  int _chartLoadGeneration = 0;
  double _targetTemperature = 9.0;
  double _targetHysteresis = 1.0;

  @override
  void initState() {
    super.initState();
    _mqtt = widget.mqttService ?? RaspberryService();
    if (_mqtt is RaspberryService) {
      _hostController.text = '192.168.1.55';
      _portController.text = '8080';
      _status = 'آرشیو اصلی روی کامپیوتر؛ آمادهٔ اتصال به رزبری';
    }
    _snapshotSubscription = _mqtt.snapshots.listen(_onSnapshot);
    _historySubscription = _mqtt.history.listen(_onHistory);
    _statusSubscription = _mqtt.statuses.listen((value) {
      _controlMessages.add(value);
      if (_controlMessages.length > 100) _controlMessages.removeAt(0);
      if (mounted) {
        setState(() {
          _status = value;
          _connected = _mqtt.isConnected;
          final service = _mqtt;
          if (service is RaspberryService && service.module != null) {
            _pollInterval = service.module!['interval'] as int;
          }
        });
      }
    });
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    await _loadSavedSettings();
    if (!mounted || widget.mqttService != null) return;
    final api = ControlApi(_controlRequest);
    _control = api;
    try {
      final root = Platform.environment['APPDATA'] ?? Directory.current.path;
      await api.start(discovery: File('$root/Homa/control-api.json'));
      if (!mounted) await api.close();
      if (mounted && _mqtt is RaspberryService) await _connect();
    } catch (_) {
      if (mounted) {
        setState(
          () => _rawError = 'رابط کنترل محلی اجرا نشد؛ احتمالاً نسخهٔ دیگری از برنامه باز است.',
        );
      }
    }
  }

  Future<Object?> _controlRequest(
    String method,
    String path,
    Map<String, dynamic> data,
    Map<String, String> query,
  ) async {
    if (!mounted) throw StateError('application is closing');
    if (method == 'GET' && path == '/v1/archive') {
      final status = await _mqtt.database.archiveStatus();
      final service = _mqtt;
      return {
        ...status,
        'sync_error': service is RaspberryService ? service.syncError : null,
        'source': 'raspberry',
        'automatic_sync_seconds': 10,
      };
    }
    if (method == 'PUT' &&
        path == '/v1/modules/refrigerator/settings' &&
        _mqtt is RaspberryService) {
      final seconds = data['poll_seconds'];
      if (seconds is! int) throw const FormatException('poll_seconds required');
      await (_mqtt).updatePolling(seconds);
      setState(() => _pollInterval = seconds);
      return {'ok': true, 'device_parameters_sent': false};
    }
    if (method == 'POST' && path == '/v1/sync') {
      await _mqtt.syncTabletHistory();
      return _mqtt.database.archiveStatus();
    }
    if (method == 'POST' &&
        path == '/v1/server/login' &&
        _mqtt is RaspberryService) {
      if (data['username'] is! String || data['password'] is! String) {
        throw const FormatException('username/password required');
      }
      _serverUser.text = data['username'] as String;
      _serverPassword.text = data['password'] as String;
      await _connect();
      if (!_mqtt.isConnected) throw StateError('Server connection failed');
      return {'connected': true};
    }
    if (method == 'GET' && path == '/v1/status') {
      return {
        'api_version': 1,
        'connected': _mqtt.isConnected,
        'status': _status,
        'error': _rawError,
        'snapshot': _snapshot?.values,
        'last_received': _lastReceived?.toIso8601String(),
        'chart_period': _chartPeriod,
        'broker_host': _hostController.text,
        'broker_port': int.tryParse(_portController.text),
        'poll_seconds': _pollInterval,
        'temperature': _targetTemperature,
        'hysteresis': _targetHysteresis,
      };
    }
    if (method == 'GET' && path == '/v1/messages') {
      return {'items': List<String>.of(_controlMessages)};
    }
    if (method == 'GET' && path == '/v1/history') {
      final from = DateTime.tryParse(query['from'] ?? '');
      final to = DateTime.tryParse(query['to'] ?? '');
      final limit = int.tryParse(query['limit'] ?? '600');
      if (from == null ||
          to == null ||
          from.isAfter(to) ||
          limit == null ||
          limit < 1 ||
          limit > 600) {
        throw const FormatException(
          'from/to ISO dates and limit 1..600 required',
        );
      }
      final rows = await _mqtt.loadHistory(
        from: from,
        to: to,
        limit: limit,
        moduleId: query['module'] ?? 'refrigerator',
      );
      return {
        'source': 'windows_database',
        'items': rows
            .map(
              (r) => {
                'module_id': r.moduleId,
                'received_at': r.receivedAt.toIso8601String(),
                'payload': r.payload,
              },
            )
            .toList(),
      };
    }
    if (method == 'PUT' && path == '/v1/chart') {
      if (!['1h', '24h', '7d', '30d'].contains(data['period'])) {
        throw const FormatException('invalid chart period');
      }
      _selectChartPeriod(data['period'] as String);
      return {'ok': true, 'period': _chartPeriod};
    }
    if (method == 'PUT' && path == '/v1/settings') {
      if (_connecting || _mqtt.isConnected) {
        throw StateError('disconnect before editing connection settings');
      }
      final host =
          data['server_host'] ?? data['broker_host'] ?? _hostController.text;
      final port =
          data['server_port'] ??
          data['broker_port'] ??
          int.tryParse(_portController.text);
      if (_mqtt is RaspberryService && data.containsKey('poll_seconds')) {
        throw const FormatException(
          'برای تغییر فاصلهٔ دریافت از /v1/modules/refrigerator/settings استفاده کنید',
        );
      }
      final interval = data['poll_seconds'] ?? _pollInterval;
      if (host is! String ||
          host.trim().isEmpty ||
          host.length > 253 ||
          host.contains(RegExp(r'[\s/:]')) ||
          port is! int ||
          port < 1 ||
          port > 65535 ||
          interval is! int ||
          interval < 1 ||
          interval > 86400) {
        throw const FormatException('invalid host, port or polling interval');
      }
      await _mqtt.saveSetting(
        _mqtt is RaspberryService ? 'pi_host' : 'broker_host',
        host,
      );
      await _mqtt.saveSetting(
        _mqtt is RaspberryService ? 'pi_port' : 'broker_port',
        '$port',
      );
      await _mqtt.saveSetting('refrigerator_poll_seconds', '$interval');
      if (_mqtt is! RaspberryService) _mqtt.setPollingInterval(interval);
      setState(() {
        _hostController.text = host;
        _portController.text = '$port';
        _pollInterval = interval;
        _intervalController.text = '$interval';
      });
      return {'ok': true, 'device_command_sent': false};
    }
    if (method == 'POST' && path == '/v1/connect') {
      if (_connecting) throw StateError('connection is in progress');
      await _connect();
      if (!_mqtt.isConnected) throw StateError('MQTT connection failed');
      return {'connected': true};
    }
    if (method == 'POST' && path == '/v1/disconnect') {
      await _disconnect();
      return {'connected': false};
    }
    if (method == 'POST' && path == '/v1/modules/refrigerator/request') {
      await _mqtt.requestInfo();
      return {'queued': true, 'device_acknowledged': false};
    }
    if (method == 'POST' && path == '/v1/modules/refrigerator/parameters') {
      // فرمان عملیاتی بدون تأیید صریح و محدودهٔ معتبر ارسال نمی‌شود.
      final t = data['temperature'], h = data['hysteresis'];
      if (data['confirm'] != true ||
          t is! num ||
          h is! num ||
          !t.isFinite ||
          !h.isFinite ||
          t < -50 ||
          t > 80 ||
          h < 0.1 ||
          h > 30) {
        throw const FormatException(
          'valid temperature/hysteresis and confirm:true required',
        );
      }
      await _mqtt.publishParameters(
        temperature: t.toDouble(),
        hysteresis: h.toDouble(),
      );
      setState(() {
        _targetTemperature = t.toDouble();
        _targetHysteresis = h.toDouble();
      });
      return {'queued': true, 'device_acknowledged': false};
    }
    throw UnsupportedError(path);
  }

  Future<void> _loadSavedSettings() async {
    try {
      final saved = await Future.wait([
        _mqtt.getSetting(_mqtt is RaspberryService ? 'pi_host' : 'broker_host'),
        _mqtt.getSetting(_mqtt is RaspberryService ? 'pi_port' : 'broker_port'),
        _mqtt.getSetting('refrigerator_poll_seconds'),
        _mqtt.getSetting('refrigerator_target_temperature'),
        _mqtt.getSetting('refrigerator_hysteresis'),
      ]);
      if (!mounted) return;
      setState(() {
        if (saved[0] != null && saved[0]!.isNotEmpty) {
          _hostController.text = saved[0]!;
        }
        if (saved[1] != null) _portController.text = saved[1]!;
        _pollInterval = int.tryParse(saved[2] ?? '') ?? _pollInterval;
        _intervalController.text = '$_pollInterval';
        _targetTemperature =
            double.tryParse(saved[3] ?? '') ?? _targetTemperature;
        _targetHysteresis =
            double.tryParse(saved[4] ?? '') ?? _targetHysteresis;
      });
      // هنگام بازشدن برنامه نمودار از تاریخچهٔ ذخیره‌شده پر می‌شود، حتی آفلاین.
      _onHistory(await _mqtt.loadRecentHistory());
      if (_mqtt is RaspberryService) {
        _serverUser.text = await _mqtt.getSetting('pi_username') ?? '';
      }
    } catch (error) {
      if (mounted) {
        setState(() => _status = 'خواندن تنظیمات محلی ناموفق بود: $error');
      }
    }
  }

  void _onSnapshot(RefrigeratorSnapshot snapshot) {
    if (!mounted) return;
    setState(() {
      _snapshot = snapshot;
      final source = _mqtt;
      final timestamp = source is RaspberryService
          ? source.module?['latest']?['ts']
          : null;
      _lastReceived = timestamp is num
          ? DateTime.fromMillisecondsSinceEpoch((timestamp * 1000).round())
          : DateTime.now();
      _rawError = null;
      _targetTemperature = snapshot.number('Temp') ?? _targetTemperature;
      _targetHysteresis = snapshot.number('Hyster') ?? _targetHysteresis;
    });
  }

  void _onHistory(List<TelemetryRecord> _) {
    unawaited(_reloadChartHistory());
  }

  Future<void> _reloadChartHistory() async {
    final generation = ++_chartLoadGeneration;
    final now = DateTime.now();
    final duration = switch (_chartPeriod) {
      '1h' => const Duration(hours: 1),
      '7d' => const Duration(days: 7),
      '30d' => const Duration(days: 30),
      _ => const Duration(hours: 24),
    };
    try {
      final records = await _mqtt.loadHistory(
        from: now.subtract(duration),
        to: now,
      );
      if (generation != _chartLoadGeneration) return;
      final points = <TemperaturePoint>[];
      for (final record in records) {
        try {
          final snapshot = RefrigeratorSnapshot.fromPayload(record.payload);
          points.add(
            TemperaturePoint(
              record.receivedAt,
              snapshot.number('TempIn'),
              snapshot.number('TempOut'),
            ),
          );
        } on FormatException {
          // پیام خراب در نمودار رسم نمی‌شود؛ نسخهٔ خام در پایگاه داده باقی می‌ماند.
        }
      }
      if (!mounted) return;
      setState(() {
        _points
          ..clear()
          ..addAll(points);
        _lastReceived = records.isEmpty
            ? _lastReceived
            : records.last.receivedAt;
      });
    } catch (error) {
      if (mounted && generation == _chartLoadGeneration) {
        setState(() => _rawError = 'خواندن تاریخچهٔ نمودار ناموفق بود: $error');
      }
    }
  }

  void _selectChartPeriod(String period) {
    if (_chartPeriod == period) return;
    setState(() => _chartPeriod = period);
    unawaited(_reloadChartHistory());
  }

  Future<void> _connect() async {
    final host = _hostController.text.trim();
    final port = int.tryParse(_portController.text.trim());
    if (host.isEmpty || port == null || port < 1 || port > 65535) {
      setState(() => _status = 'آدرس بروکر یا پورت معتبر نیست');
      return;
    }
    setState(() {
      _connecting = true;
      _rawError = null;
    });
    try {
      await _mqtt.saveSetting(
        _mqtt is RaspberryService ? 'pi_host' : 'broker_host',
        host,
      );
      await _mqtt.saveSetting(
        _mqtt is RaspberryService ? 'pi_port' : 'broker_port',
        '$port',
      );
      final service = _mqtt;
      if (service is RaspberryService && _serverPassword.text.isNotEmpty) {
        await service.loginAndConnect(
          host,
          port,
          _serverUser.text.trim(),
          _serverPassword.text,
        );
        await _mqtt.saveSetting('pi_username', _serverUser.text.trim());
      } else {
        await _mqtt.connect(host, port);
      }
      if (_mqtt is! RaspberryService) _mqtt.setPollingInterval(_pollInterval);
      if (mounted) setState(() => _connected = _mqtt.isConnected);
    } catch (error) {
      if (mounted) {
        setState(() {
          _connected = false;
          _rawError = '$error';
        });
      }
    } finally {
      _serverPassword.clear();
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _disconnect() async {
    await _mqtt.disconnect();
    if (mounted) setState(() => _connected = false);
  }

  Future<void> _syncTabletHistory() async {
    try {
      await _mqtt.syncTabletHistory();
    } catch (error) {
      if (mounted) setState(() => _rawError = '$error');
    }
  }

  Future<void> _showFridgeSettings() async {
    _intervalController.text = '$_pollInterval';
    _temperatureController.text = '$_targetTemperature';
    _hysteresisController.text = '$_targetHysteresis';
    final result = await showDialog<_FridgeSettings>(
      context: context,
      builder: (context) => _FridgeSettingsDialog(
        intervalController: _intervalController,
        temperatureController: _temperatureController,
        hysteresisController: _hysteresisController,
        initialTemperature: _targetTemperature,
        initialHysteresis: _targetHysteresis,
      ),
    );
    if (result == null) return;
    setState(() => _pollInterval = result.intervalSeconds);
    _targetTemperature = result.temperature;
    _targetHysteresis = result.hysteresis;
    await _mqtt.saveSetting(
      'refrigerator_poll_seconds',
      '${result.intervalSeconds}',
    );
    await _mqtt.saveSetting(
      'refrigerator_target_temperature',
      '${result.temperature}',
    );
    await _mqtt.saveSetting('refrigerator_hysteresis', '${result.hysteresis}');
    if (_mqtt is RaspberryService) {
      try {
        await (_mqtt).updatePolling(result.intervalSeconds);
      } catch (error) {
        if (mounted) setState(() => _rawError = '$error');
        return;
      }
    } else {
      _mqtt.setPollingInterval(result.intervalSeconds);
    }
    if (_connected && result.parametersChanged) {
      try {
        await _mqtt.publishParameters(
          temperature: result.temperature,
          hysteresis: result.hysteresis,
        );
      } catch (error) {
        setState(() => _rawError = '$error');
      }
    }
  }

  @override
  void dispose() {
    unawaited(_control?.close());
    _snapshotSubscription?.cancel();
    _historySubscription?.cancel();
    _statusSubscription?.cancel();
    _mqtt.dispose();
    _hostController.dispose();
    _portController.dispose();
    _temperatureController.dispose();
    _hysteresisController.dispose();
    _intervalController.dispose();
    _serverUser.dispose();
    _serverPassword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF122233), Color(0xFF152B34), Color(0xFF101923)],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 1040;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (wide) _buildSideRail(),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(wide ? 24 : 16, 22, 24, 28),
                      children: [
                        _buildHeader(),
                        Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    ArchivePage(database: _mqtt.database),
                              ),
                            ),
                            icon: const Icon(Icons.manage_search),
                            label: const Text('آرشیو داده‌ها و جستجو'),
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildBrokerCard(),
                        const SizedBox(height: 16),
                        if (wide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 6, child: _buildFridgeCard()),
                              const SizedBox(width: 16),
                              Expanded(flex: 5, child: _buildChartCard()),
                            ],
                          )
                        else ...[
                          _buildFridgeCard(),
                          const SizedBox(height: 16),
                          _buildChartCard(),
                        ],
                        const SizedBox(height: 16),
                        _buildFutureModulesCard(),
                        const SizedBox(height: 12),
                        _buildStorageNotice(),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSideRail() => Container(
    width: 76,
    margin: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xAA1B2D3A),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0x335E8191)),
    ),
    child: const Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        SizedBox(height: 22),
        Icon(Icons.home_rounded, color: Color(0xFF38D6C5), size: 30),
        SizedBox(height: 22),
        Icon(Icons.thermostat_rounded, color: Colors.white70),
        SizedBox(height: 22),
        Icon(Icons.show_chart_rounded, color: Colors.white70),
        Spacer(),
        Icon(Icons.settings_rounded, color: Colors.white54),
        SizedBox(height: 20),
      ],
    ),
  );

  Widget _buildHeader() {
    final time = _lastReceived == null
        ? 'هنوز داده‌ای دریافت نشده'
        : 'آخرین دریافت: ${_timeText(_lastReceived!)}';
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'HOMA  /  خانهٔ هوشمند',
                style: TextStyle(color: Colors.white.withValues(alpha: .62)),
              ),
              const SizedBox(height: 5),
              const Text(
                'پایش و کنترل خانه',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                time,
                style: TextStyle(color: Colors.white.withValues(alpha: .56)),
              ),
            ],
          ),
        ),
        _StatusPill(connected: _connected, connecting: _connecting),
      ],
    );
  }

  Widget _buildBrokerCard() => _GlassCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeading(
          icon: Icons.hub_outlined,
          title: _mqtt is RaspberryService
              ? 'اتصال به سرور رزبری'
              : 'اتصال به بروکر',
        ),
        const SizedBox(height: 13),
        Row(
          children: [
            Expanded(
              flex: 5,
              child: _InputField(
                controller: _hostController,
                label: _mqtt is RaspberryService ? 'آدرس رزبری' : 'آدرس بروکر',
                enabled: !_connected && !_connecting,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: _InputField(
                controller: _portController,
                label: 'پورت',
                numeric: true,
                enabled: !_connected && !_connecting,
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              height: 54,
              child: FilledButton.icon(
                onPressed: _connecting
                    ? null
                    : (_connected ? _disconnect : _connect),
                icon: Icon(_connected ? Icons.link_off : Icons.link),
                label: Text(
                  _connecting
                      ? 'در حال اتصال…'
                      : (_connected ? 'قطع اتصال' : 'اتصال'),
                ),
              ),
            ),
          ],
        ),
        if (_mqtt is RaspberryService && _mqtt.authRequired) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _serverUser,
                  enabled: !_connecting,
                  decoration: const InputDecoration(
                    labelText: 'نام کاربری پنل رزبری',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _serverPassword,
                  enabled: !_connecting,
                  obscureText: !_showServerPassword,
                  decoration: InputDecoration(
                    labelText: 'رمز پنل؛ فقط برای ورود اول یا تمدید نشست',
                    suffixIcon: IconButton(
                      onPressed: () => setState(
                        () => _showServerPassword = !_showServerPassword,
                      ),
                      icon: Icon(
                        _showServerPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 9),
        Text(
          _status,
          style: TextStyle(
            color: _connected
                ? const Color(0xFF72E4D2)
                : Colors.white.withValues(alpha: .68),
          ),
        ),
        if (_rawError != null) ...[
          const SizedBox(height: 5),
          Text(_rawError!, style: const TextStyle(color: Color(0xFFFFA7A7))),
        ],
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: _connected ? _syncTabletHistory : null,
            icon: const Icon(Icons.sync_rounded),
            label: Text(
              _mqtt is RaspberryService
                  ? 'همگام‌سازی اکنون از رزبری'
                  : 'همگام‌سازی تاریخچه از تبلت',
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildFridgeCard() {
    if (_mqtt is RaspberryService && _mqtt.supportsServerUi) {
      return ServerModuleCards(service: _mqtt);
    }
    final snapshot = _snapshot;
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: _SectionHeading(
                  icon: Icons.kitchen_rounded,
                  title: 'نمایشگر یخچال',
                ),
              ),
              IconButton(
                tooltip: 'تنظیمات یخچال و بازهٔ پایش',
                onPressed: _showFridgeSettings,
                icon: const Icon(Icons.settings_rounded),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _TemperatureTile(
                  label: 'دمای داخل',
                  value: snapshot?.value('TempIn', suffix: ' °C') ?? '—',
                  color: const Color(0xFF60E0CD),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TemperatureTile(
                  label: 'دمای بیرون',
                  value: snapshot?.value('TempOut', suffix: ' °C') ?? '—',
                  color: const Color(0xFFFFC97B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth > 620 ? 3 : 2;
              final fields = <(String, String)>[
                (
                  'دمای تنظیم‌شده',
                  snapshot?.value('Temp', suffix: ' °C') ?? '—',
                ),
                ('هیسترزیس', snapshot?.value('Hyster', suffix: ' °C') ?? '—'),
                ('حداقل دما', snapshot?.value('MinTemp', suffix: ' °C') ?? '—'),
                (
                  'حداکثر دما',
                  snapshot?.value('MaxTemp', suffix: ' °C') ?? '—',
                ),
                ('زمان روشن', snapshot?.value('OnTime') ?? '—'),
                ('زمان خاموش', snapshot?.value('OffTime') ?? '—'),
                ('آدرس IP دستگاه', snapshot?.value('IP') ?? '—'),
              ];
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: fields.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisExtent: 68,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemBuilder: (context, index) =>
                    _DataTile(label: fields[index].$1, value: fields[index].$2),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard() => _GlassCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeading(
          icon: Icons.show_chart_rounded,
          title: 'روند دما',
        ),
        const SizedBox(height: 5),
        Text(
          'تاریخچهٔ ذخیره‌شده؛ حداکثر ۶۰۰ نمونه در بازهٔ انتخابی',
          style: TextStyle(color: Colors.white.withValues(alpha: .56)),
        ),
        const SizedBox(height: 9),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _chartPeriodChip('1h', '۱ ساعت'),
            _chartPeriodChip('24h', '۲۴ ساعت'),
            _chartPeriodChip('7d', '۷ روز'),
            _chartPeriodChip('30d', '۳۰ روز'),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 230,
          child: TemperatureChart(points: List.unmodifiable(_points)),
        ),
        const SizedBox(height: 9),
        const Wrap(
          spacing: 18,
          children: [
            _LegendDot(color: Color(0xFF60E0CD), label: 'دمای داخل'),
            _LegendDot(color: Color(0xFFFFC97B), label: 'دمای بیرون'),
          ],
        ),
      ],
    ),
  );

  Widget _chartPeriodChip(String value, String label) => ChoiceChip(
    label: Text(label),
    selected: _chartPeriod == value,
    onSelected: (_) => _selectChartPeriod(value),
  );

  Widget _buildFutureModulesCard() => _GlassCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeading(
          icon: Icons.grid_view_rounded,
          title: 'ماژول‌های خانه',
        ),
        const SizedBox(height: 12),
        const Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _ModuleChip(
              icon: Icons.kitchen_rounded,
              label: 'یخچال',
              active: true,
            ),
            _ModuleChip(
              icon: Icons.ac_unit_rounded,
              label: 'کولر',
              active: false,
            ),
            _ModuleChip(
              icon: Icons.thermostat_rounded,
              label: 'کنترل دما',
              active: false,
            ),
          ],
        ),
      ],
    ),
  );

  Widget _buildStorageNotice() => Text(
    'آرشیو اصلی و دائمی در SQLite کامپیوتر ذخیره می‌شود؛ رزبری بافر زمان خاموشی است. همگام‌سازی هر ۱۰ ثانیه، بدون وابستگی به تبلت.',
    style: TextStyle(color: Colors.white.withValues(alpha: .48), fontSize: 12),
  );

  String _timeText(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:${value.second.toString().padLeft(2, '0')}';
}

class _FridgeSettings {
  const _FridgeSettings({
    required this.intervalSeconds,
    required this.temperature,
    required this.hysteresis,
    required this.parametersChanged,
  });

  final int intervalSeconds;
  final double temperature;
  final double hysteresis;
  final bool parametersChanged;
}

class _FridgeSettingsDialog extends StatefulWidget {
  const _FridgeSettingsDialog({
    required this.intervalController,
    required this.temperatureController,
    required this.hysteresisController,
    required this.initialTemperature,
    required this.initialHysteresis,
  });

  final TextEditingController intervalController;
  final TextEditingController temperatureController;
  final TextEditingController hysteresisController;
  final double initialTemperature;
  final double initialHysteresis;

  @override
  State<_FridgeSettingsDialog> createState() => _FridgeSettingsDialogState();
}

class _FridgeSettingsDialogState extends State<_FridgeSettingsDialog> {
  String? _error;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('تنظیمات یخچال'),
    content: SizedBox(
      width: 440,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _InputField(
              controller: widget.intervalController,
              label: 'بازهٔ درخواست Info (ثانیه)',
              numeric: true,
            ),
            const SizedBox(height: 12),
            _InputField(
              controller: widget.temperatureController,
              label: 'دمای هدف (°C)',
              numeric: true,
            ),
            const SizedBox(height: 12),
            _InputField(
              controller: widget.hysteresisController,
              label: 'هیسترزیس (°C)',
              numeric: true,
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: Color(0xFFFFA7A7))),
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('انصراف'),
      ),
      FilledButton(onPressed: _save, child: const Text('ذخیره و ارسال')),
    ],
  );

  void _save() {
    final interval = int.tryParse(widget.intervalController.text.trim());
    final temperature = double.tryParse(
      widget.temperatureController.text.trim(),
    );
    final hysteresis = double.tryParse(widget.hysteresisController.text.trim());
    if (interval == null || interval < 1 || interval > 86400) {
      setState(() => _error = 'بازه باید بین ۱ تا ۸۶۴۰۰ ثانیه باشد.');
      return;
    }
    if (temperature == null ||
        hysteresis == null ||
        !temperature.isFinite ||
        !hysteresis.isFinite ||
        hysteresis < 0) {
      setState(() => _error = 'دما و هیسترزیس را به‌صورت عدد معتبر وارد کن.');
      return;
    }
    Navigator.pop(
      context,
      _FridgeSettings(
        intervalSeconds: interval,
        temperature: temperature,
        hysteresis: hysteresis,
        parametersChanged:
            widget.initialTemperature != temperature ||
            widget.initialHysteresis != hysteresis,
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0xCC1D303D),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0x55658091)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x28000000),
          blurRadius: 22,
          offset: Offset(0, 10),
        ),
      ],
    ),
    child: child,
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: const Color(0xFF65DDCC), size: 21),
      const SizedBox(width: 8),
      Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
    ],
  );
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    required this.label,
    this.numeric = false,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String label;
  final bool numeric;
  final bool enabled;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    enabled: enabled,
    keyboardType: numeric ? TextInputType.number : TextInputType.text,
    textDirection: numeric ? TextDirection.ltr : TextDirection.rtl,
    decoration: InputDecoration(
      labelText: label,
      filled: true,
      fillColor: const Color(0x55303F4C),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: Color(0x556A8794)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
  );
}

class _TemperatureTile extends StatelessWidget {
  const _TemperatureTile({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .09),
      border: Border.all(color: color.withValues(alpha: .34)),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: Colors.white.withValues(alpha: .72)),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 23,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _DataTile extends StatelessWidget {
  const _DataTile({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(
      color: const Color(0x44203142),
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: const Color(0x334B7184)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: Colors.white.withValues(alpha: .63)),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.left,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.connected, required this.connecting});
  final bool connected;
  final bool connecting;

  @override
  Widget build(BuildContext context) {
    final color = connected
        ? const Color(0xFF60E0CD)
        : (connecting ? const Color(0xFFFFC97B) : const Color(0xFFFF8B8B));
    final label = connected ? 'متصل' : (connecting ? 'در حال اتصال' : 'قطع');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        border: Border.all(color: color.withValues(alpha: .45)),
        borderRadius: BorderRadius.circular(40),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 9, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(color: Colors.white.withValues(alpha: .66))),
    ],
  );
}

class _ModuleChip extends StatelessWidget {
  const _ModuleChip({
    required this.icon,
    required this.label,
    required this.active,
  });
  final IconData icon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) => Chip(
    avatar: Icon(
      icon,
      size: 18,
      color: active ? const Color(0xFF60E0CD) : Colors.white54,
    ),
    label: Text(label),
    side: BorderSide(
      color: active ? const Color(0x665EDCCC) : const Color(0x334D6370),
    ),
    backgroundColor: active ? const Color(0x3325CDB7) : const Color(0x33203142),
  );
}
