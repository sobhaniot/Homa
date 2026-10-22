import 'package:flutter/material.dart';

import 'core/connection.dart';
import 'core/settings.dart';
import 'ui.dart';

String numericLatin(String value) {
  const fa = '۰۱۲۳۴۵۶۷۸۹', ar = '٠١٢٣٤٥٦٧٨٩';
  for (var i = 0; i < 10; i++) {
    value = value.replaceAll(fa[i], '$i').replaceAll(ar[i], '$i');
  }
  return value.replaceAll('٫', '.').replaceAll('−', '-').trim();
}

class ModuleDetails extends StatelessWidget {
  final String id;
  final PhoneController controller;
  const ModuleDetails({super.key, required this.id, required this.controller});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final found = controller.modules.where((m) => m.id == id);
      if (found.isEmpty) {
        return Scaffold(
          appBar: AppBar(title: const Text('ماژول')),
          body: const Center(child: Text('ماژول در فهرست فعلی سرور نیست')),
        );
      }
      final module = found.first, sample = controller.samples[id];
      final fields = module.fields.where((f) => f['visible'] == true).toList();
      return Scaffold(
        appBar: AppBar(
          title: Text(module.title),
          actions: [
            IconButton(
              tooltip: 'تنظیمات دستگاه',
              onPressed: () => showModuleSettings(context, controller, module),
              icon: const Icon(Icons.settings),
            ),
            IconButton(
              tooltip: 'تازه‌خوانی',
              onPressed: () => controller.request(module),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Glass(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    module.online
                        ? 'پاسخ تازه از ماژول موجود است'
                        : 'دادهٔ ماژول تازه نیست',
                    style: TextStyle(
                      color: module.online ? mint : Colors.amber,
                    ),
                  ),
                  const SizedBox(height: 20),
                  LayoutBuilder(
                    builder: (context, c) {
                      final columns = c.maxWidth < 280
                          ? 1
                          : module.columns.clamp(1, 2);
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: fields.map((f) {
                          final value = sample?.values[f['key']] ?? f['value'];
                          return SizedBox(
                            width: (c.maxWidth - 12 * (columns - 1)) / columns,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: .04),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${f['label']}',
                                      style: const TextStyle(fontSize: 18),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      '${value is bool ? (value ? 'روشن' : 'خاموش') : value ?? '—'} ${f['unit'] ?? ''}',
                                      textDirection: TextDirection.ltr,
                                      style: const TextStyle(
                                        fontSize: 22,
                                        color: mint,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  Text(
                    sample == null
                        ? 'در انتظار داده…'
                        : 'زمان داده: ${sample.receivedAt.toLocal().toString().substring(0, 19)}',
                    style: const TextStyle(color: Colors.white54),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () =>
                        showModuleSettings(context, controller, module),
                    icon: const Icon(Icons.tune),
                    label: const Text('تنظیمات دستگاه'),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'فیلدها، ترتیب و نوع ورودی توسط رزبری تعریف شده‌اند.',
                    style: TextStyle(color: Colors.white54),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

Future<void> showModuleSettings(
  BuildContext context,
  PhoneController controller,
  ModuleProfile module,
) async {
  final definitions = module.fields
      .where((f) => f['editable'] == true)
      .toList();
  if (definitions.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('رزبری برای این ماژول فیلد قابل تنظیمی تعریف نکرده است'),
      ),
    );
    return;
  }
  final inputs = <String, TextEditingController>{},
      flags = <String, bool>{},
      initial = <String, dynamic>{};
  for (final f in definitions) {
    final key = f['key'] as String;
    final value = controller.samples[module.id]?.values[key] ?? f['value'];
    initial[key] = f['type']=='boolean' ? value==true : value;
    if (f['type'] == 'boolean') {
      flags[key] = value == true;
    } else {
      inputs[key] = TextEditingController(text: value == null ? '' : '$value');
    }
  }
  String? error;
  bool busy = false;
  await showDialog<void>(
    context: context,
    builder: (dialog) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text('تنظیمات ${module.title}'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (controller.route != 'local')
                  const Text(
                    'ارسال تنظیمات از بروکر عمومی غیرفعال است؛ به شبکهٔ خانه وصل شوید.',
                    style: TextStyle(color: Colors.amber),
                  ),
                for (final f in definitions)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: f['type'] == 'boolean'
                        ? SwitchListTile(
                            title: Text('${f['label']}'),
                            value: flags[f['key']]!,
                            onChanged: busy
                                ? null
                                : (v) => setState(() => flags[f['key']] = v),
                          )
                        : TextField(
                            controller: inputs[f['key']],
                            enabled: !busy,
                            scrollPadding: const EdgeInsets.only(bottom: 180),
                            keyboardType: f['type'] == 'text'
                                ? TextInputType.text
                                : TextInputType.numberWithOptions(
                                    decimal: f['type'] != 'integer',
                                    signed: (f['min'] as num? ?? -1) < 0,
                                  ),
                            textDirection: f['type'] == 'text'
                                ? TextDirection.rtl
                                : TextDirection.ltr,
                            decoration: InputDecoration(
                              labelText: '${f['label']}',
                              suffixText: '${f['unit'] ?? ''}',
                              floatingLabelBehavior:
                                  FloatingLabelBehavior.always,
                              helperText: f['min'] != null || f['max'] != null
                                  ? 'بازه: ${f['min'] ?? '…'} تا ${f['max'] ?? '…'}'
                                  : null,
                            ),
                          ),
                  ),
                if (error != null)
                  Text(error!, style: const TextStyle(color: Colors.amber)),
                const Text(
                  'با ارسال، تنظیم واقعی دستگاه تغییر می‌کند. پاسخ سرور فقط پذیرش در صف است، نه تأیید دستگاه.',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(dialog),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed:
                busy ||
                    controller.route != 'local' ||
                    !controller.settingsAllowed
                ? null
                : () async {
                    final values = <String, dynamic>{};
                    for (final f in definitions) {
                      final key = f['key'] as String;
                      dynamic value;
                      if (f['type'] == 'boolean') {
                        value = flags[key];
                      } else if (f['type'] == 'text') {
                        value = inputs[key]!.text;
                      } else {
                        value = num.tryParse(numericLatin(inputs[key]!.text));
                        if (value == null ||
                            !value.isFinite ||
                            (f['type'] == 'integer' &&
                                value.toInt() != value) ||
                            (f['min'] != null && value < f['min']) ||
                            (f['max'] != null && value > f['max'])) {
                          setState(
                            () => error = 'مقدار ${f['label']} معتبر نیست',
                          );
                          return;
                        }
                      }
                      if (value != initial[key]) values[key] = value;
                    }
                    if (values.isEmpty) {
                      setState(() => error = 'مقداری تغییر نکرده است');
                      return;
                    }
                    setState(() {
                      busy = true;
                      error = null;
                    });
                    try {
                      await controller.saveValues(module, values);
                      if (dialog.mounted) {
                        Navigator.pop(dialog);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'در صف ارسال قرار گرفت؛ منتظر گزارش دستگاه باشید.',
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      if (dialog.mounted) {
                        setState(() {
                          busy = false;
                          error = '$e';
                        });
                      }
                    }
                  },
            child: Text(busy ? 'در حال ارسال…' : 'ارسال به دستگاه'),
          ),
        ],
      ),
    ),
  );
  await Future<void>.delayed(const Duration(milliseconds: 300));
  for (final input in inputs.values) {
    input.dispose();
  }
}
