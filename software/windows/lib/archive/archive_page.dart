import 'dart:convert';

import 'package:flutter/material.dart';

import '../charts/temperature_chart.dart';
import '../core/storage/telemetry_database.dart';
import 'archive_repository.dart';
import 'persian_date.dart';

class ArchivePage extends StatefulWidget {
  const ArchivePage({required this.database, super.key});
  final TelemetryDatabase database;
  @override
  State<ArchivePage> createState() => _ArchivePageState();
}

class _ArchivePageState extends State<ArchivePage> {
  late final repo = ArchiveRepository(widget.database);
  final from = TextEditingController(),
      to = TextEditingController(),
      text = TextEditingController(),
      low = TextEditingController(),
      high = TextEditingController();
  String module = '', metric = '', sort = 'new', error = '', message = '';
  List<String> modules = [], metrics = [];
  List<Map<String, Object?>> rows = [];
  int total = 0, offset = 0;
  bool busy = false;
  ArchiveFilter applied = const ArchiveFilter();
  @override
  void initState() {
    super.initState();
    final now = PersianDate.tehran(DateTime.now());
    from.text = PersianDate.format(now.subtract(const Duration(days: 7)));
    to.text = PersianDate.format(now);
    load();
  }

  Future<void> load() async {
    try {
      final o = await repo.options();
      if (!mounted) return;
      setState(() {
        modules = o['modules']!;
        metrics = o['metrics']!;
      });
      await run();
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  ArchiveFilter filter() => ArchiveFilter(
    module: module,
    metric: metric,
    search: text.text,
    from: from.text.trim().isEmpty ? null : PersianDate.boundary(from.text),
    to: to.text.trim().isEmpty
        ? null
        : PersianDate.boundary(to.text, end: true),
    minimum: number(low.text),
    maximum: number(high.text),
    ascending: sort == 'old' || sort == 'valueLow',
    sortByValue: sort.startsWith('value'),
  );
  double? number(String s) {
    if (s.trim().isEmpty) return null;
    final n = double.tryParse(PersianDate.latin(s));
    if (n == null || !n.isFinite) {
      throw const FormatException('عدد معتبر وارد کنید');
    }
    return n;
  }

  Future<void> run({bool reset = true}) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      if (reset) {
        applied = filter();
        offset = 0;
      }
      final result = await repo.search(applied, offset: offset);
      if (!mounted) return;
      setState(() {
        rows = (result['items'] as List).cast<Map<String, Object?>>();
        total = result['total'] as int;
        error = '';
      });
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> pick(TextEditingController target) async {
    var date = DateTime.now().toUtc();
    try {
      date = PersianDate.parse(target.text);
    } catch (_) {}
    final p = PersianDate.parts(date);
    var y = p[0], m = p[1];
    final selected = await showDialog<DateTime>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) {
          final first = PersianDate.parse('$y/$m/1');
          final next = m == 12
              ? PersianDate.start(y + 1)
              : PersianDate.parse('$y/${m + 1}/1');
          final count = next.difference(first).inDays,
              blank = (first.weekday + 1) % 7;
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: const Text('انتخاب تاریخ شمسی'),
              content: SizedBox(
                width: 350,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed: () => set(() {
                            m--;
                            if (m == 0) {
                              m = 12;
                              y--;
                            }
                          }),
                          icon: const Icon(Icons.chevron_right),
                        ),
                        Text('$y / $m'),
                        IconButton(
                          onPressed: () => set(() {
                            m++;
                            if (m == 13) {
                              m = 1;
                              y++;
                            }
                          }),
                          icon: const Icon(Icons.chevron_left),
                        ),
                      ],
                    ),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Text('ش'),
                        Text('ی'),
                        Text('د'),
                        Text('س'),
                        Text('چ'),
                        Text('پ'),
                        Text('ج'),
                      ],
                    ),
                    GridView.count(
                      crossAxisCount: 7,
                      shrinkWrap: true,
                      children: List.generate(
                        blank + count,
                        (i) => i < blank
                            ? const SizedBox()
                            : TextButton(
                                onPressed: () => Navigator.pop(
                                  ctx,
                                  first.add(Duration(days: i - blank)),
                                ),
                                child: Text('${i - blank + 1}'),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('انصراف'),
                ),
              ],
            ),
          );
        },
      ),
    );
    if (selected != null && mounted) target.text = PersianDate.format(selected);
  }

  Future<void> details(Map<String, Object?> row) async {
    var payload = row['payload'].toString();
    try {
      payload = const JsonEncoder.withIndent('  ').convert(jsonDecode(payload));
    } catch (_) {}
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('رکورد ${row['remote_id']} · ${row['module_id']}'),
        content: SizedBox(
          width: 650,
          child: SingleChildScrollView(
            child: SelectableText(payload, textDirection: TextDirection.ltr),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('بستن'),
          ),
        ],
      ),
    );
  }

  Future<void> chart() async {
    setState(() => busy = true);
    try {
      final f = ArchiveFilter(
        module: applied.module,
        metric: applied.metric,
        search: applied.search,
        from: applied.from,
        to: applied.to,
        minimum: applied.minimum,
        maximum: applied.maximum,
      );
      final result = await repo.search(f, limit: 600);
      // خروجی SQLite فقط‌خواندنی است؛ مرتب‌سازی نمودار روی یک کپی انجام می‌شود.
      final items = (result['items'] as List)
          .cast<Map<String, Object?>>()
          .toList();
      items.sort(
        (a, b) => (a['received_at'] as num).compareTo(b['received_at'] as num),
      );
      final points = items
          .where((r) => r['value'] is num)
          .map(
            (r) => TemperaturePoint(
              DateTime.fromMillisecondsSinceEpoch(
                ((r['received_at'] as num) * 1000).round(),
              ),
              (r['value'] as num).toDouble(),
              null,
            ),
          )
          .toList();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            'نمودار ${applied.metric.isEmpty ? 'TempIn' : applied.metric} · حداکثر ۶۰۰ نمونهٔ آخر نتایج',
          ),
          content: SizedBox(
            width: 900,
            height: 380,
            child: TemperatureChart(
              points: points,
              axisLabel: applied.metric.isEmpty ? 'TempIn' : applied.metric,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('بستن'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> export() async {
    setState(() => busy = true);
    try {
      final path = await repo.exportCsv(applied, r'F:\_HomaData\exports');
      if (mounted) setState(() => message = 'خروجی همهٔ نتایج: $path');
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String date(Object? timestamp) {
    final d = PersianDate.tehran(
      DateTime.fromMillisecondsSinceEpoch(
        ((timestamp as num) * 1000).round(),
        isUtc: true,
      ),
    );
    return '${PersianDate.format(d)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:${d.second.toString().padLeft(2, '0')}';
  }

  Widget field(
    String label,
    TextEditingController c, {
    bool calendar = false,
  }) => SizedBox(
    width: 220,
    child: TextField(
      controller: c,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: calendar
            ? IconButton(
                onPressed: () => pick(c),
                icon: const Icon(Icons.calendar_month),
              )
            : null,
      ),
    ),
  );
  Widget dropdown(
    String label,
    String value,
    List<String> options,
    void Function(String) change,
  ) => SizedBox(
    width: 220,
    child: DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: [
        const DropdownMenuItem(value: '', child: Text('همه')),
        for (final item in options)
          DropdownMenuItem(value: item, child: Text(item)),
      ],
      onChanged: (v) => setState(() => change(v ?? '')),
    ),
  );
  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(title: const Text('آرشیو داده‌ها · فقط خواندنی')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'جستجو در آرشیو رزبری و سوابق قدیمی کامپیوتر؛ تاریخ‌ها و ساعت به وقت تهران.',
          ),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              dropdown('ماژول', module, modules, (v) => module = v),
              dropdown('پارامتر', metric, metrics, (v) => metric = v),
              field('از تاریخ شمسی', from, calendar: true),
              field('تا پایان روز شمسی', to, calendar: true),
              field('حداقل مقدار (شامل)', low),
              field('حداکثر مقدار (شامل)', high),
              field('جستجو در متن پیام', text),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  initialValue: sort,
                  decoration: const InputDecoration(labelText: 'مرتب‌سازی'),
                  items: const [
                    DropdownMenuItem(value: 'new', child: Text('جدیدترین')),
                    DropdownMenuItem(value: 'old', child: Text('قدیمی‌ترین')),
                    DropdownMenuItem(
                      value: 'valueLow',
                      child: Text('مقدار صعودی'),
                    ),
                    DropdownMenuItem(
                      value: 'valueHigh',
                      child: Text('مقدار نزولی'),
                    ),
                  ],
                  onChanged: (v) => setState(() => sort = v!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            children: [
              FilledButton.icon(
                onPressed: busy ? null : () => run(),
                icon: const Icon(Icons.search),
                label: const Text('جستجو'),
              ),
              OutlinedButton(
                onPressed: busy || total == 0 ? null : chart,
                child: const Text('نمودار نتایج'),
              ),
              OutlinedButton(
                onPressed: busy || total == 0 ? null : export,
                child: const Text('خروجی CSV همهٔ نتایج'),
              ),
            ],
          ),
          if (busy) const LinearProgressIndicator(),
          if (error.isNotEmpty)
            Text(error, style: const TextStyle(color: Colors.redAccent)),
          if (message.isNotEmpty) SelectableText(message),
          Text(
            '$total نتیجه · صفحهٔ ${offset ~/ 50 + 1} · برای جزئیات روی ردیف بزنید',
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              showCheckboxColumn: false,
              columns: const [
                DataColumn(label: Text('شناسه')),
                DataColumn(label: Text('ماژول')),
                DataColumn(label: Text('زمان شمسی / تهران')),
                DataColumn(label: Text('مقدار')),
                DataColumn(label: Text('منبع')),
              ],
              rows: rows
                  .map(
                    (r) => DataRow(
                      onSelectChanged: (_) => details(r),
                      cells: [
                        DataCell(Text('${r['remote_id']}')),
                        DataCell(Text('${r['module_id']}')),
                        DataCell(Text(date(r['received_at']))),
                        DataCell(Text('${r['value'] ?? '—'}')),
                        DataCell(
                          Text(
                            r['source'] == 'legacy'
                                ? 'سوابق قدیمی'
                                : 'آرشیو رزبری',
                          ),
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),
          Row(
            children: [
              TextButton(
                onPressed: busy || offset == 0
                    ? null
                    : () {
                        offset -= 50;
                        run(reset: false);
                      },
                child: const Text('صفحهٔ قبل'),
              ),
              TextButton(
                onPressed: busy || offset + 50 >= total
                    ? null
                    : () {
                        offset += 50;
                        run(reset: false);
                      },
                child: const Text('صفحهٔ بعد'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  @override
  void dispose() {
    for (final c in [from, to, text, low, high]) {
      c.dispose();
    }
    super.dispose();
  }
}
