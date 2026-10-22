import 'package:flutter_test/flutter_test.dart';
import 'package:homa_mobile/core/settings.dart';
import 'package:homa_mobile/core/connection.dart';

class LiveStore implements SettingsStore {
  final PhoneSettings settings;
  LiveStore(this.settings);
  @override
  Future<PhoneSettings> load() async => settings;
  @override
  Future<void> save(PhoneSettings value) async {}
}

void main() {
  const live = bool.fromEnvironment('HOMA_LIVE');
  for (final external in [false, true]) {
    test(
      'real MQTT ${external ? 'external fallback' : 'local cache'}',
      () async {
        final settings = PhoneSettings(
          local: Endpoint('192.168.1.55', external ? 1 : 1883),
        );
        final controller = PhoneController(store: LiveStore(settings));
        addTearDown(controller.dispose);
        await controller.start();
        expect(controller.route, external ? 'external' : 'local');
        final until = DateTime.now().add(const Duration(seconds: 20));
        while (controller.samples.isEmpty && DateTime.now().isBefore(until)) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
        expect(controller.samples['refrigerator'], isNotNull);
        expect(
          controller.samples['refrigerator']!.values['TempIn'],
          isA<num>(),
        );
        // تنها درخواست Info به کش سرور؛ هیچ Param به یخچال فرستاده نمی‌شود.
      },
      skip: !live,
      timeout: const Timeout(Duration(seconds: 50)),
    );
  }
}
