import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:homa_control/archive/archive_repository.dart';
import 'package:homa_control/archive/persian_date.dart';
import 'package:homa_control/core/storage/telemetry_database.dart';

void main() {
  setUpAll(sqfliteFfiInit);
  test('تقویم شمسی، کبیسه و مرز روز تهران', () {
    expect(PersianDate.format(DateTime.utc(2026, 10, 22)), '1405/07/30');
    expect(PersianDate.format(DateTime.utc(2024, 3, 20)), '1403/01/01');
    expect(PersianDate.parse('۱۴۰۳/۱۲/۳۰'), DateTime.utc(2025, 3, 20));
    expect(() => PersianDate.parse('1404/12/30'), throwsFormatException);
    expect(
      PersianDate.boundary('1405/07/30'),
      DateTime.utc(2026, 10, 21, 20, 30),
    );
    expect(
      PersianDate.boundary('1405/07/30', end: true),
      DateTime.utc(2026, 10, 22, 20, 30),
    );
  });
  test('جستجو فقط خواندنی: فیلتر عددی، متن، تاریخ، صفحه و CSV', () async {
    final folder = await Directory.systemTemp.createTemp('homa-search-');
    final db = TelemetryDatabase(path: '${folder.path}/data.sqlite');
    final repo = ArchiveRepository(db);
    final ts = DateTime.utc(2026, 10, 22, 8).millisecondsSinceEpoch / 1000;
    try {
      await db.commitArchivePage('source', [
        {
          'id': 1,
          'module_id': 'refrigerator',
          'ts': ts,
          'payload': '{"TempIn":9,"name":"100%"}',
        },
        {
          'id': 2,
          'module_id': 'refrigerator',
          'ts': ts + 1,
          'payload': '{"TempIn":12}',
        },
        {
          'id': 3,
          'module_id': 'cooler',
          'ts': ts + 2,
          'payload': '{"TempIn":20}',
        },
      ], 3);
      await db.save(
        TelemetryRecord(
          moduleId: 'refrigerator',
          receivedAt: DateTime.utc(2026, 10, 21),
          payload: 'not JSON',
        ),
      );
      expect((await repo.search(const ArchiveFilter()))['total'], 4);
      expect(
        (await repo.search(
          const ArchiveFilter(
            module: 'refrigerator',
            metric: 'TempIn',
            minimum: 10,
          ),
        ))['total'],
        1,
      );
      expect((await repo.search(const ArchiveFilter(search: '%')))['total'], 1);
      expect(
        (await repo.search(
          ArchiveFilter(
            from: PersianDate.boundary('1405/07/30'),
            to: PersianDate.boundary('1405/07/30', end: true),
          ),
        ))['total'],
        3,
      );
      final p1 = await repo.search(const ArchiveFilter(), limit: 1),
          p2 = await repo.search(const ArchiveFilter(), limit: 1, offset: 1);
      expect(p1['items'], isNot(p2['items']));
      final options = await repo.options();
      expect(options['modules'], contains('cooler'));
      expect(options['metrics'], contains('TempIn'));
      await expectLater(
        repo.search(const ArchiveFilter(metric: "x');DROP TABLE telemetry;--")),
        throwsFormatException,
      );
      final readonly = await repo.reader();
      try {
        await expectLater(
          readonly.execute('DELETE FROM archive_records'),
          throwsA(isA<DatabaseException>()),
        );
      } finally {
        await readonly.close();
      }
      final csv = await repo.exportCsv(
        const ArchiveFilter(metric: 'TempIn'),
        folder.path,
      );
      final content = await File(csv).readAsString();
      expect(content, contains('TempIn'));
      expect(content, contains('cooler'));
      expect(content.split('\r\n').length, 5);
      expect(ArchiveRepository.csvCell('=1+2'), contains("'=1+2"));
      expect((await db.archiveStatus())['archive_records'], 3);
    } finally {
      await db.close();
      await folder.delete(recursive: true);
    }
  });
}
