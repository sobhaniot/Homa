import 'package:flutter/material.dart';

import '../core/raspberry_service.dart';

/// نام، فیلدها، ترتیب و نوع فرم از رزبری می‌آیند؛ فیلد ثابت مخصوص یخچال نداریم.
class ServerModuleCards extends StatelessWidget {
  final RaspberryService service;
  const ServerModuleCards({super.key, required this.service});
  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final module in service.moduleDefinitions)
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Builder(
                builder: (context) {
                  final ui = module['ui'] as Map?;
                  final fields = (ui?['fields'] as List? ?? [])
                      .where((f) => f['visible'] == true)
                      .toList();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${module['name']}',
                              style: const TextStyle(
                                fontSize: 23,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'تنظیمات دستگاه',
                            onPressed: () => edit(context, module),
                            icon: const Icon(Icons.settings),
                          ),
                        ],
                      ),
                      Text(
                        module['online'] == true
                            ? 'دادهٔ تازه موجود است'
                            : 'بدون پاسخ تازه',
                        style: const TextStyle(color: Colors.white60),
                      ),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, c) {
                          final columns = c.maxWidth < 300
                              ? 1
                              : ((ui?['columns'] as num?)?.toInt() ?? 2).clamp(
                                  1,
                                  2,
                                );
                          return Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: fields
                                .map(
                                  (f) => SizedBox(
                                    width:
                                        (c.maxWidth - 12 * (columns - 1)) /
                                        columns,
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: .04,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              '${f['label']}',
                                              style: const TextStyle(
                                                fontSize: 18,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Flexible(
                                            child: Text(
                                              '${f['value'] ?? '—'} ${f['unit'] ?? ''}',
                                              textDirection: TextDirection.ltr,
                                              style: const TextStyle(
                                                fontSize: 22,
                                                color: Color(0xff60e0cd),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          );
                        },
                      ),
                      if (fields.isEmpty)
                        const Text('تعریف فیلدها را در پنل رزبری تکمیل کنید.'),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      if (service.moduleDefinitions.isEmpty)
        const Text('در انتظار فهرست ماژول‌ها از رزبری…'),
    ],
  );

  Future<void> edit(BuildContext context, Map<String, dynamic> module) async {
    final fields = ((module['ui'] as Map?)?['fields'] as List? ?? [])
        .where((f) => f['editable'] == true)
        .toList();
    if (fields.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('فیلد قابل تنظیمی در رزبری تعریف نشده است'),
        ),
      );
      return;
    }
    final inputs = <String, TextEditingController>{}, flags = <String, bool>{};
    for (final f in fields) {
      if (f['type'] == 'boolean') {
        flags[f['key']] = f['value'] == true;
      } else {
        inputs[f['key']] = TextEditingController(
          text: f['value'] == null ? '' : '${f['value']}',
        );
      }
    }
    final messenger = ScaffoldMessenger.of(context);
    String? error;
    bool busy = false;
    await showDialog<void>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, update) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text('تنظیمات ${module['name']}'),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final f in fields)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: f['type'] == 'boolean'
                            ? SwitchListTile(
                                title: Text('${f['label']}'),
                                value: flags[f['key']]!,
                                onChanged: busy
                                    ? null
                                    : (v) => update(() => flags[f['key']] = v),
                              )
                            : TextField(
                                controller: inputs[f['key']],
                                enabled: !busy,
                                keyboardType: f['type'] == 'text'
                                    ? TextInputType.text
                                    : const TextInputType.numberWithOptions(
                                        decimal: true,
                                        signed: true,
                                      ),
                                decoration: InputDecoration(
                                  labelText: '${f['label']}',
                                  suffixText: '${f['unit'] ?? ''}',
                                ),
                              ),
                      ),
                    if (error != null)
                      Text(error!, style: const TextStyle(color: Colors.amber)),
                    const Text(
                      'ارسال، تنظیم واقعی دستگاه را تغییر می‌دهد؛ پذیرش سرور به معنی تأیید دستگاه نیست.',
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
                onPressed: busy
                    ? null
                    : () async {
                        final values = <String, dynamic>{};
                        for (final f in fields) {
                          dynamic v;
                          final key = f['key'] as String;
                          if (f['type'] == 'boolean') {
                            v = flags[key];
                          } else if (f['type'] == 'text') {
                            v = inputs[key]!.text;
                          } else {
                            v = num.tryParse(inputs[key]!.text.trim());
                            if (v == null ||
                                !v.isFinite ||
                                (f['type'] == 'integer' && v.toInt() != v) ||
                                (f['min'] != null && v < f['min']) ||
                                (f['max'] != null && v > f['max'])) {
                              update(
                                () => error = 'مقدار ${f['label']} نامعتبر است',
                              );
                              return;
                            }
                          }
                          if (v !=
                              (f['type'] == 'boolean'
                                  ? f['value'] == true
                                  : f['value'])) {
                            values[key] = v;
                          }
                        }
                        if (values.isEmpty) {
                          update(() => error = 'مقداری تغییر نکرده است');
                          return;
                        }
                        update(() {
                          busy = true;
                          error = null;
                        });
                        try {
                          await service.saveModuleValues(module, values);
                          if (dialog.mounted) {
                            Navigator.pop(dialog);
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'در صف ارسال قرار گرفت؛ منتظر گزارش دستگاه باشید.',
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          if (dialog.mounted) {
                            update(() {
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
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    for (final input in inputs.values) {
      input.dispose();
    }
  }
}
