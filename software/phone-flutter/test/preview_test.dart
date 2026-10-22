import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homa_mobile/core/connection.dart';
import 'package:homa_mobile/main.dart';
import 'package:homa_mobile/core/settings.dart';

import 'connection_test.dart' show MemoryStore, catalog;

void main() {
  testWidgets('dashboard visual preview', (tester) async {
    final font = File('C:/Windows/Fonts/tahoma.ttf');
    if (!font.existsSync()) return;
    final loader = FontLoader('Roboto')
      ..addFont(Future.value(ByteData.sublistView(font.readAsBytesSync())));
    await loader.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = PhoneController(store: MemoryStore());
    addTearDown(c.dispose);
    c.status = 'پیش‌نمایش • دادهٔ نمونه';
    c.modules = [
      ModuleProfile.fromCatalog((catalog(c)['modules'] as List).single),
    ];
    c.catalogLoaded = true;
    c.samples['refrigerator'] = Sample(DateTime(2026, 10, 22, 12, 30), {
      'TempIn': 4.5,
      'TempOut': 28,
      'Temp': 5,
      'Hyster': 1,
      'OnTime': 35,
      'OffTime': 39,
    });
    await tester.pumpWidget(
      RepaintBoundary(child: HomaApp(controller: c, autoStart: false)),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(HomaApp),
      matchesGoldenFile('preview-phone.png'),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
