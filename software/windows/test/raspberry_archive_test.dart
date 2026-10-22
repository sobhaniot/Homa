import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:homa_control/core/raspberry_service.dart';
import 'package:homa_control/core/storage/telemetry_database.dart';

Map<String, dynamic> record(int id, {String module = 'refrigerator'}) => {
  'id': id,
  'module_id': module,
  'ts': 1792620000.125,
  'payload': '{"TempIn":8.5,"TempOut":25,"type":"Info"}',
  'parsed': null,
};

void main() {
  setUpAll(sqfliteFfiInit);
  test('ارتقای دیتابیس قبلی بدون حذف تاریخچه و تنظیمات', () async {
    final folder = await Directory.systemTemp.createTemp('homa-v1-migration-');
    final path = '${folder.path}/old.sqlite';
    final old = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE telemetry(id INTEGER PRIMARY KEY,module_id TEXT,received_at_ms INTEGER,payload TEXT)',
          );
          await db.execute(
            'CREATE TABLE app_settings(setting_key TEXT PRIMARY KEY,setting_value TEXT)',
          );
        },
      ),
    );
    await old.insert('telemetry', {
      'module_id': 'refrigerator',
      'received_at_ms': 1000,
      'payload': '{"TempIn":5}',
    });
    await old.insert('app_settings', {
      'setting_key': 'test',
      'setting_value': 'keep',
    });
    await old.close();
    final upgraded = TelemetryDatabase(path: path);
    try {
      expect(await upgraded.getSetting('test'), 'keep');
      expect((await upgraded.readRecent(moduleId: 'refrigerator')).length, 1);
      await upgraded.commitArchivePage('new-source', [record(1)], 1);
      expect((await upgraded.archiveStatus())['archive_records'], 1);
      final sql = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
      );
      try {
        expect(
          (await sql.rawQuery(
            "SELECT numeric_value FROM archive_measurements WHERE metric='TempIn'",
          )).single['numeric_value'],
          8.5,
        );
      } finally {
        await sql.close();
      }
    } finally {
      await upgraded.close();
      await folder.delete(recursive: true);
    }
  });
  test('آرشیو اتمیک، تکرارپذیر و قابل تحلیل؛ حفظ نمونه‌های هم‌زمان و ماژول‌های مختلف', () async {
    final db = TelemetryDatabase(path: inMemoryDatabasePath);
    try {
      await db.commitArchivePage('pi-one', [
        record(1),
        record(2),
        record(3, module: 'temperature'),
      ], 3);
      await db.commitArchivePage('pi-one', [
        record(1),
        record(2),
        record(3, module: 'temperature'),
      ], 3);
      expect((await db.archiveStatus())['archive_records'], 3);
      expect(await db.archiveCheckpoint('pi-one'), 3);
      // صفحهٔ خراب نباید نصفه ثبت شود یا نقطهٔ ادامه را جلو ببرد.
      await expectLater(
        db.commitArchivePage('pi-one', [
          record(4),
          {...record(5), 'ts': 'wrong'},
        ], 5),
        throwsFormatException,
      );
      expect((await db.archiveStatus())['archive_records'], 3);
      expect(await db.archiveCheckpoint('pi-one'), 3);
      await db.commitArchivePage('pi-two', [record(1)], 1);
      expect((await db.archiveStatus())['archive_records'], 4);
      final values = await db.readRecent(moduleId: 'temperature');
      expect(values.length, 1);
    } finally {
      await db.close();
    }
  });

  test(
    'شکست ACK، ادامه پس از بسته‌شدن ویندوز و دریافت دادهٔ زمان خاموشی',
    () async {
      final folder = await Directory.systemTemp.createTemp('homa-pi-test-');
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final rows = [record(1), record(2)];
      var failAck = true, ack = 0, pageCalls = 0;
      server.listen((req) async {
        if (req.method != 'GET') expect(req.contentLength, greaterThan(0));
        dynamic result;
        final data = req.method == 'GET'
            ? <String, dynamic>{}
            : jsonDecode(await utf8.decoder.bind(req).join());
        if (req.uri.path == '/api/login') {
          expect(data['password'], 'test-secret');
          result = {'token': 'test-session'};
        } else if (req.uri.path == '/api/auth-mode') {
          result = {'required': true};
        } else if (req.headers.value('authorization') !=
            'Bearer test-session') {
          req.response.statusCode = 401;
          result = {'error': 'unauthorized'};
        } else if (req.uri.path == '/api/archive/register') {
          result = {
            'stream_id': 'test-pi',
            'through': rows.last['id'],
            'acknowledged': ack,
          };
        } else if (req.uri.path == '/api/archive/page') {
          pageCalls++;
          final after = int.parse(req.uri.queryParameters['after']!);
          final items = rows.where((r) => (r['id'] as int) > after).toList();
          result = {
            'stream_id': 'test-pi',
            'items': items,
            'next_after': items.isEmpty ? after : items.last['id'],
          };
        } else if (req.uri.path == '/api/archive/ack') {
          if (failAck) {
            req.response.statusCode = 500;
            result = {'error': 'simulated ACK failure'};
          } else {
            ack = data['after'] as int;
            result = {'ok': true};
          }
        } else if (req.uri.path == '/api/modules') {
          result = [
            {'id': 'refrigerator', 'interval': 300, 'latest': rows.last},
          ];
        } else {
          throw StateError('Unexpected endpoint: ${req.uri.path}');
        }
        req.response.headers.contentType = ContentType.json;
        req.response.write(jsonEncode(result));
        await req.response.close();
      });
      final path = '${folder.path}/archive.sqlite';
      final sessionPath = '${folder.path}/session.json';
      var service = RaspberryService(
        database: TelemetryDatabase(path: path),
        sessionPath: sessionPath,
        syncInterval: const Duration(days: 1),
      );
      try {
        await service.loginAndConnect(
          '127.0.0.1',
          server.port,
          'test-user',
          'test-secret',
        );
        expect((await service.database.archiveStatus())['archive_records'], 2);
        expect(ack, 0);
        failAck = false;
        await service.syncNow();
        expect(service.isConnected, true);
        expect(ack, 2);
        expect((await service.database.archiveStatus())['archive_records'], 2);
        expect(
          await File(sessionPath).readAsString(),
          isNot(contains('test-secret')),
        );
        await service.dispose();
        rows.add(record(3)); // این داده وقتی ویندوز خاموش است روی رزبری می‌آید.
        service = RaspberryService(
          database: TelemetryDatabase(path: path),
          sessionPath: sessionPath,
          syncInterval: const Duration(days: 1),
        );
        await service.connect('127.0.0.1', server.port);
        expect((await service.database.archiveStatus())['archive_records'], 3);
        expect(ack, 3);
        expect(pageCalls, 3);
      } finally {
        await service.dispose();
        await server.close(force: true);
        await folder.delete(recursive: true);
      }
    },
  );
}
