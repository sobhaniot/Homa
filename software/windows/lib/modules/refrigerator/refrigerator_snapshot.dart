import 'dart:convert';

/// پیام قدیمی یخچال را بدون تغییر قرارداد فریم‌ور به مدل قابل‌نمایش تبدیل می‌کند.
class RefrigeratorSnapshot {
  const RefrigeratorSnapshot({required this.values, required this.rawPayload});

  final Map<String, dynamic> values;
  final String rawPayload;

  factory RefrigeratorSnapshot.fromPayload(String payload) {
    final decoded = jsonDecode(payload);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('پیام یخچال باید یک شیء JSON باشد.');
    }
    return RefrigeratorSnapshot(values: decoded, rawPayload: payload);
  }

  String value(String key, {String fallback = '—', String suffix = ''}) {
    final item = values[key];
    if (item == null || item.toString().isEmpty) return fallback;
    return '${item.toString()}$suffix';
  }

  double? number(String key) {
    final item = values[key];
    if (item is num) return item.toDouble();
    return double.tryParse(item?.toString() ?? '');
  }
}
