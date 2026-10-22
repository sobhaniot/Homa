import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:homa_control/core/mqtt/legacy_mqtt_service.dart';
import 'package:homa_control/core/storage/telemetry_database.dart';
import 'package:homa_control/app/homa_app.dart';
import 'package:homa_control/modules/refrigerator/refrigerator_snapshot.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('پاسخ JSON قدیمی یخچال به مقادیر قابل‌نمایش تبدیل می‌شود', () {
    final snapshot = RefrigeratorSnapshot.fromPayload(
      '{"TempIn":4.5,"TempOut":22,"Temp":8,"Hyster":1.5}',
    );

    expect(snapshot.number('TempIn'), 4.5);
    expect(snapshot.value('TempOut', suffix: ' °C'), '22 °C');
    expect(snapshot.number('Hyster'), 1.5);
    expect(snapshot.value('Missing'), '—');
  });

  test('پیام JSON غیرشیء رد می‌شود', () {
    expect(
      () => RefrigeratorSnapshot.fromPayload('[1,2,3]'),
      throwsFormatException,
    );
  });

  testWidgets('داشبورد فارسی ماژول یخچال و بروکر را نمایش می‌دهد', (
    tester,
  ) async {
    final service = LegacyMqttService(
      database: TelemetryDatabase(path: inMemoryDatabasePath),
    );
    await tester.pumpWidget(HomaApp(mqttService: service));
    await tester.pumpAndSettle();

    expect(find.text('پایش و کنترل خانه'), findsOneWidget);
    expect(find.text('اتصال به بروکر'), findsOneWidget);
    expect(find.text('نمایشگر یخچال'), findsOneWidget);
    expect(find.text('test.mosquitto.org'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('پایگاه دادهٔ محلی نمونه و تنظیمات را نگه می‌دارد', () async {
    final folder = await Directory.systemTemp.createTemp('homa-sqlite-test-');
    final path = '${folder.path}${Platform.pathSeparator}telemetry.db';
    final receivedAt = DateTime.utc(2026, 10, 18, 9, 30);
    try {
      final firstOpen = TelemetryDatabase(path: path);
      await firstOpen.open();
      await firstOpen.save(
        TelemetryRecord(
          moduleId: LegacyMqttService.refrigeratorModuleId,
          receivedAt: receivedAt,
          payload: '{"TempIn":4.5,"TempOut":22}',
        ),
      );
      await firstOpen.saveSetting('refrigerator_poll_seconds', '15');
      await firstOpen.close();

      // بازشدن دوباره از همان فایل باید تاریخچه و تنظیمات را حفظ کرده باشد.
      final reopened = TelemetryDatabase(path: path);
      final records = await reopened.readRange(
        moduleId: LegacyMqttService.refrigeratorModuleId,
        from: receivedAt.subtract(const Duration(seconds: 1)),
        to: receivedAt.add(const Duration(seconds: 1)),
      );
      expect(records, hasLength(1));
      expect(
        records.single.receivedAt.millisecondsSinceEpoch,
        receivedAt.millisecondsSinceEpoch,
      );
      expect(
        (await reopened.latestTime(LegacyMqttService.refrigeratorModuleId))
            ?.millisecondsSinceEpoch,
        receivedAt.millisecondsSinceEpoch,
      );
      expect(await reopened.getSetting('refrigerator_poll_seconds'), '15');
      await reopened.close();
    } finally {
      await folder.delete(recursive: true);
    }
  });

  test('بازهٔ نمودار از جدیدترین رکوردهای همان بازه انتخاب می‌شود', () async {
    final database = TelemetryDatabase(path: inMemoryDatabasePath);
    final base = DateTime.utc(2026, 10, 18, 9);
    for (var index = 0; index < 3; index++) {
      await database.save(
        TelemetryRecord(
          moduleId: LegacyMqttService.refrigeratorModuleId,
          receivedAt: base.add(Duration(minutes: index)),
          payload: '{"TempIn":$index}',
        ),
      );
    }

    final records = await database.readRange(
      moduleId: LegacyMqttService.refrigeratorModuleId,
      from: base,
      to: base.add(const Duration(minutes: 3)),
      limit: 2,
    );
    expect(records, hasLength(2));
    expect(records.first.payload, '{"TempIn":1}');
    expect(records.last.payload, '{"TempIn":2}');
    await database.close();
  });
}
