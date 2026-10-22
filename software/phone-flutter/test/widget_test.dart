import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homa_mobile/main.dart';
import 'package:homa_mobile/core/connection.dart';
import 'package:homa_mobile/core/settings.dart';
import 'package:homa_mobile/module_details.dart';

import 'connection_test.dart' show MemoryStore, catalog;

void main() {
  testWidgets('home lists modules; tap opens details and typed settings', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = PhoneController(store: MemoryStore());
    addTearDown(c.dispose);
    c.modules = [
      ModuleProfile.fromCatalog((catalog(c)['modules'] as List).single),
    ];
    c.catalogLoaded = true;
    await tester.pumpWidget(HomaApp(controller: c, autoStart: false));
    expect(find.text('یخچال'), findsOneWidget);
    expect(find.text('دمای داخل'), findsNothing);
    expect(find.textContaining('شناسهٔ ماژول'), findsNothing);
    await tester.tap(find.text('یخچال'));
    await tester.pumpAndSettle();
    expect(find.text('دمای داخل'), findsOneWidget);
    await tester.tap(find.byTooltip('تنظیمات دستگاه'));
    await tester.pumpAndSettle();
    expect(find.text('دما'), findsWidgets);
    expect(find.text('هیسترسیس'), findsWidgets);
    final field = tester.widget<TextField>(find.byType(TextField).first);
    expect(
      field.keyboardType,
      const TextInputType.numberWithOptions(decimal: true, signed: true),
    );
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('انصراف'));
    await tester.pumpAndSettle();
    tester.view.resetViewInsets();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('ماژول‌های خانه'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('root exits only on second back within two seconds', (
    tester,
  ) async {
    final c = PhoneController(store: MemoryStore());
    addTearDown(c.dispose);
    var exits = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemNavigator.pop') exits++;
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(HomaApp(controller: c, autoStart: false));
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(exits, 0);
    expect(find.text('برای خروج دوباره Back را بزنید'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(exits, 1);
    await tester.pumpWidget(const SizedBox());
  });
  test('Persian and Arabic numeric input normalizes without losing sign', () {
    expect(numericLatin('−۱۲٫۵'), '-12.5');
    expect(numericLatin('٣.٢'), '3.2');
  });
}
