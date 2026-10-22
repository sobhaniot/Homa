import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

class Endpoint {
  final String host;
  final int port;
  const Endpoint(this.host, this.port);
  Map<String, dynamic> toJson() => {'host': host, 'port': port};
  factory Endpoint.fromJson(Map<String, dynamic> j) =>
      Endpoint(j['host'] as String, j['port'] as int);
}

class ModuleProfile {
  final String id, title;
  final int refreshSeconds;
  final List<Map<String, dynamic>> fields;
  final int columns;
  final bool online;
  final String revision;
  const ModuleProfile(
    this.id,
    this.title,
    this.refreshSeconds, {
    this.fields = const [],
    this.columns = 2,
    this.online = false,
    this.revision = '',
  });
  factory ModuleProfile.fromCatalog(Map<String, dynamic> j) {
    final ui = j['ui'] as Map<String, dynamic>;
    return ModuleProfile(
      j['id'],
      j['name'],
      (ui['refresh_seconds'] as num).toInt(),
      columns: (ui['columns'] as num).toInt(),
      online: j['online'] == true,
      revision: ui['revision'] ?? '',
      fields: (ui['fields'] as List)
          .map((f) => Map<String, dynamic>.from(f as Map))
          .toList(),
    );
  }
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'refresh': refreshSeconds,
  };
  factory ModuleProfile.fromJson(Map<String, dynamic> j) => ModuleProfile(
    j['id'] as String,
    j['title'] as String,
    j['refresh'] as int,
  );
}

class PhoneSettings {
  final Endpoint local, external;
  final String installation;
  const PhoneSettings({
    this.local = const Endpoint('192.168.1.55', 1883),
    this.external = const Endpoint('test.mosquitto.org', 1883),
    this.installation = '64da274cb2a1',
  });
  String root(String id) => 'homa/$installation/modules/$id';
  String? validate() {
    for (final e in [local, external]) {
      if (!RegExp(r'^[a-zA-Z0-9.:-]{1,253}$').hasMatch(e.host) ||
          e.port < 1 ||
          e.port > 65535) {
        return 'آدرس را بدون tcp:// و پورت را بین ۱ تا ۶۵۵۳۵ وارد کنید';
      }
    }
    if (!RegExp(r'^[a-zA-Z0-9_-]{1,80}$').hasMatch(installation)) {
      return 'شناسهٔ خانه نامعتبر است';
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    'local': local.toJson(),
    'external': external.toJson(),
    'installation': installation,
  };
  factory PhoneSettings.fromJson(Map<String, dynamic> j) => PhoneSettings(
    local: Endpoint.fromJson(j['local']),
    external: Endpoint.fromJson(j['external']),
    installation: j['installation'],
  );
}

abstract class SettingsStore {
  Future<PhoneSettings> load();
  Future<void> save(PhoneSettings value);
}

class DeviceSettingsStore implements SettingsStore {
  static const _channel = MethodChannel('homa/config');
  File get _file => File(
    '${Platform.environment['APPDATA'] ?? Directory.systemTemp.path}/HomaPhone/settings.json',
  );
  @override
  Future<PhoneSettings> load() async {
    final String? raw;
    if (Platform.isAndroid) {
      raw = await _channel.invokeMethod<String>('load');
    } else {
      raw = await _file.exists() ? await _file.readAsString() : null;
    }
    if (raw == null) return const PhoneSettings();
    final settings = PhoneSettings.fromJson(jsonDecode(raw));
    if (settings.validate() != null) {
      throw const FormatException('تنظیمات ذخیره‌شده معتبر نیست');
    }
    return settings;
  }

  @override
  Future<void> save(PhoneSettings value) async {
    final raw = jsonEncode(value.toJson());
    if (Platform.isAndroid) {
      await _channel.invokeMethod<void>('save', raw);
    } else {
      await _file.parent.create(recursive: true);
      final temporary = File('${_file.path}.tmp');
      await temporary.writeAsString(raw, flush: true);
      await temporary.rename(_file.path);
    }
  }
}
