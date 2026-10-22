import 'dart:convert';
import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../core/storage/telemetry_database.dart';

class ArchiveFilter {
  const ArchiveFilter({
    this.module = '',
    this.metric = '',
    this.search = '',
    this.from,
    this.to,
    this.minimum,
    this.maximum,
    this.ascending = false,
    this.sortByValue = false,
  });
  final String module, metric, search;
  final DateTime? from, to;
  final double? minimum, maximum;
  final bool ascending, sortByValue;
}

/// اتصال واقعاً readOnly است؛ فیلترهای کاربر فقط پارامتر SQL هستند.
class ArchiveRepository {
  ArchiveRepository(this.database);
  final TelemetryDatabase database;
  Future<Database> reader() async {
    final info = await database.archiveStatus();
    return databaseFactoryFfi.openDatabase(
      info['database_path'] as String,
      options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
    );
  }

  static const records = '''WITH records AS (
    SELECT 'archive' AS source,stream_id,remote_id,module_id,received_at,payload FROM archive_records
    UNION ALL SELECT 'legacy','',id,module_id,received_at_ms/1000.0,payload FROM telemetry
    ),selected AS (SELECT *,CASE WHEN json_valid(payload) THEN json_extract(payload,?) END AS value FROM records)''';
  (String, List<Object?>) clause(ArchiveFilter f) {
    if (f.metric.isNotEmpty &&
        !RegExp(r'^[A-Za-z0-9_]{1,80}$').hasMatch(f.metric)) {
      throw const FormatException('پارامتر نامعتبر');
    }
    if (f.from != null && f.to != null && !f.from!.isBefore(f.to!)) {
      throw const FormatException('بازهٔ تاریخ نامعتبر');
    }
    if ((f.minimum != null && !f.minimum!.isFinite) ||
        (f.maximum != null && !f.maximum!.isFinite) ||
        (f.minimum != null && f.maximum != null && f.minimum! > f.maximum!)) {
      throw const FormatException('بازهٔ عددی نامعتبر');
    }
    if ((f.minimum != null || f.maximum != null) && f.metric.isEmpty) {
      throw const FormatException('پارامتر را انتخاب کنید');
    }
    final c = <String>[],
        a = <Object?>['\$.${f.metric.isEmpty ? 'TempIn' : f.metric}'];
    if (f.module.isNotEmpty) {
      c.add('module_id=?');
      a.add(f.module);
    }
    if (f.metric.isNotEmpty) c.add('value IS NOT NULL');
    if (f.from != null) {
      c.add('received_at>=?');
      a.add(f.from!.millisecondsSinceEpoch / 1000);
    }
    if (f.to != null) {
      c.add('received_at<?');
      a.add(f.to!.millisecondsSinceEpoch / 1000);
    }
    if (f.minimum != null) {
      c.add("typeof(value) IN ('integer','real') AND value>=?");
      a.add(f.minimum);
    }
    if (f.maximum != null) {
      c.add("typeof(value) IN ('integer','real') AND value<=?");
      a.add(f.maximum);
    }
    if (f.search.isNotEmpty) {
      c.add("payload LIKE ? ESCAPE '\\'");
      a.add(
        '%${f.search.replaceAll('\\', '\\\\').replaceAll('%', '\\%').replaceAll('_', '\\_')}%',
      );
    }
    return (c.isEmpty ? '' : ' WHERE ${c.join(' AND ')}', a);
  }

  String order(ArchiveFilter f) =>
      ' ORDER BY ${f.sortByValue && f.metric.isNotEmpty ? 'value' : 'received_at'} ${f.ascending ? 'ASC' : 'DESC'},source,stream_id,remote_id';
  Future<Map<String, dynamic>> search(
    ArchiveFilter f, {
    int offset = 0,
    int limit = 50,
  }) async {
    if (offset < 0 || limit < 1 || limit > 600) {
      throw const FormatException('صفحه نامعتبر');
    }
    final db = await reader();
    try {
      final (w, a) = clause(f);
      await db.execute('BEGIN');
      final n =
          (await db.rawQuery(
                '$records SELECT COUNT(*) FROM selected$w',
                a,
              )).single.values.first
              as int;
      final rows = await db.rawQuery(
        '$records SELECT * FROM selected$w${order(f)} LIMIT ? OFFSET ?',
        [...a, limit, offset],
      );
      await db.execute('COMMIT');
      return {'total': n, 'items': rows};
    } finally {
      await db.close();
    }
  }

  Future<Map<String, List<String>>> options() async {
    final db = await reader();
    try {
      final m = await db.rawQuery(
        'SELECT DISTINCT module_id FROM archive_records UNION SELECT DISTINCT module_id FROM telemetry ORDER BY module_id',
      );
      final v = await db.rawQuery(
        "SELECT DISTINCT metric FROM archive_values UNION SELECT DISTINCT j.key FROM telemetry t,json_each(CASE WHEN json_valid(t.payload) THEN t.payload ELSE '{}' END) j ORDER BY 1",
      );
      return {
        'modules': m.map((r) => r.values.first as String).toList(),
        'metrics': v
            .map((r) => r.values.first.toString())
            .where((s) => RegExp(r'^[A-Za-z0-9_]{1,80}$').hasMatch(s))
            .toList(),
      };
    } finally {
      await db.close();
    }
  }

  static String csvCell(Object? v) {
    var s = v?.toString() ?? '';
    if (RegExp(r'^\s*[=+@-]').hasMatch(s)) s = "'$s";
    return '"${s.replaceAll('"', '""')}"';
  }

  Future<String> exportCsv(ArchiveFilter f, String directory) async {
    final db = await reader();
    await Directory(directory).create(recursive: true);
    final file = File(
          '$directory/archive-${DateTime.now().microsecondsSinceEpoch}.csv',
        ),
        sink = StringBuffer();
    // خروجی صفحه‌ای و snapshot ثابت است تا ثبت هم‌زمان، رکورد تکراری نسازد.
    final output = file.openWrite(encoding: utf8);
    try {
      final (w, a) = clause(f);
      await db.execute('BEGIN');
      output.write(
        '\uFEFFsource,stream_id,remote_id,module_id,received_at_utc,metric,value,payload\r\n',
      );
      var offset = 0;
      while (true) {
        final rows = await db.rawQuery(
          '$records SELECT * FROM selected$w${order(f)} LIMIT 500 OFFSET ?',
          [...a, offset],
        );
        sink.clear();
        for (final r in rows) {
          final d = DateTime.fromMillisecondsSinceEpoch(
            ((r['received_at'] as num) * 1000).round(),
            isUtc: true,
          );
          sink.write(
            '${[r['source'], r['stream_id'], r['remote_id'], r['module_id'], d.toIso8601String(), f.metric, r['value'], r['payload']].map(csvCell).join(',')}\r\n',
          );
        }
        output.write(sink);
        offset += rows.length;
        if (rows.length < 500) break;
      }
      await db.execute('COMMIT');
      await output.flush();
      return file.path;
    } finally {
      await output.close();
      await db.close();
    }
  }
}
