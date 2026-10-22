import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homa_mobile/core/settings.dart';
import 'package:homa_mobile/core/connection.dart';

class MemoryStore implements SettingsStore {
  PhoneSettings value = const PhoneSettings();
  @override
  Future<PhoneSettings> load() async => value;
  @override
  Future<void> save(PhoneSettings value) async {
    this.value = value;
  }
}

class FakeLink implements BrokerLink {
  final bool succeeds;
  final Completer<void>? gate;
  final List<String> attempts;
  bool closed = false;
  VoidCallback? lost;
  void Function(String, String)? receive;
  final List<String> sent = [];
  FakeLink(this.succeeds, this.attempts, {this.gate});
  @override
  Future<void> open(
    Endpoint endpoint,
    List<String> topics,
    void Function(String, String) onMessage,
    VoidCallback onLost,
  ) async {
    attempts.add(endpoint.host);
    lost = onLost;
    receive = onMessage;
    if (gate != null) await gate!.future;
    if (!succeeds) throw StateError('offline');
  }

  @override
  void close() {
    closed = true;
  }

  @override
  void send(String topic, String payload) {
    sent.add('$topic $payload');
  }
}

Map<String, dynamic> catalog(
  PhoneController c, {
  List<Map<String, dynamic>>? modules,
}) => {
  'version': 1,
  'installation': c.settings.installation,
  'settings_allowed': true,
  'modules':
      modules ??
      [
        {
          'id': 'refrigerator',
          'name': 'یخچال',
          'kind': 'refrigerator',
          'online': true,
          'ui': {
            'revision': 'testrevision',
            'columns': 2,
            'refresh_seconds': 30,
            'fields': [
              {
                'key': 'TempIn',
                'label': 'دمای داخل',
                'type': 'number',
                'visible': true,
                'editable': false,
                'value': 4,
              },
              {
                'key': 'Temp',
                'label': 'دما',
                'type': 'number',
                'visible': true,
                'editable': true,
                'value': 9,
                'min': -50,
                'max': 80,
              },
              {
                'key': 'Hyster',
                'label': 'هیسترسیس',
                'type': 'number',
                'visible': true,
                'editable': true,
                'value': 1,
                'min': 0.1,
                'max': 30,
              },
            ],
          },
          'latest': null,
        },
      ],
};
void deliverCatalog(
  PhoneController c,
  FakeLink link, {
  List<Map<String, dynamic>>? modules,
}) => link.receive!(
  'homa/${c.settings.installation}/catalog/state',
  jsonEncode(catalog(c, modules: modules)),
);

void main() {
  late List<String> attempts;
  late List<FakeLink> links;
  PhoneController create(
    List<bool> outcomes, {
    Duration retry = const Duration(days: 1),
  }) {
    var index = 0;
    return PhoneController(
      store: MemoryStore(),
      retryDelay: retry,
      linkFactory: () {
        final link = FakeLink(outcomes[index++], attempts);
        links.add(link);
        return link;
      },
    );
  }

  setUp(() {
    attempts = [];
    links = [];
  });
  test('local success never opens external', () async {
    final c = create([true]);
    addTearDown(c.dispose);
    await c.start();
    expect(attempts, ['192.168.1.55']);
    expect(c.route, 'local');
    expect(links.single.sent.single, contains('/catalog/request'));
    expect(c.modules, isEmpty);
    deliverCatalog(c, links.single);
    expect(c.modules.single.id, 'refrigerator');
    expect(
      links.single.sent.last,
      contains(
        'homa/64da274cb2a1/modules/refrigerator/request {"type":"Info"}',
      ),
    );
    expect(links.single.sent.last, isNot(contains('/eleknow.com/')));
  });
  test('local failure falls back to external', () async {
    final c = create([false, true]);
    addTearDown(c.dispose);
    await c.start();
    expect(attempts, ['192.168.1.55', 'test.mosquitto.org']);
    expect(c.route, 'external');
    expect(links.first.closed, true);
  });
  test('both fail remains offline', () async {
    final c = create([false, false]);
    addTearDown(c.dispose);
    await c.start();
    expect(c.connected, false);
    expect(c.busy, false);
  });
  test(
    'failed local probe keeps external, successful probe switches',
    () async {
      final c = create([false, true, false, true]);
      addTearDown(c.dispose);
      await c.start();
      await c.probeLocal();
      expect(c.route, 'external');
      expect(links[1].closed, false);
      await c.probeLocal();
      expect(c.route, 'local');
      expect(links[1].closed, true);
      links[1].lost!();
      expect(c.route, 'local');
    },
  );
  test('disconnect retries local first', () async {
    final c = create([
      false,
      true,
      true,
    ], retry: const Duration(milliseconds: 1));
    addTearDown(c.dispose);
    await c.start();
    links[1].lost!();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(attempts.last, '192.168.1.55');
    expect(c.route, 'local');
  });
  test('dispose cancels a late successful connection', () async {
    final gate = Completer<void>();
    final link = FakeLink(true, attempts, gate: gate);
    final c = PhoneController(store: MemoryStore(), linkFactory: () => link);
    final pending = c.start();
    await Future<void>.delayed(Duration.zero);
    c.dispose();
    gate.complete();
    await pending;
    expect(link.closed, true);
    expect(link.sent, isEmpty);
  });
  test(
    'message timestamp is original and old responses cannot replace newer',
    () async {
      final c = create([true]);
      addTearDown(c.dispose);
      await c.start();
      deliverCatalog(c, links.single);
      void receive(int ts) => links.single.receive!(
        '${c.settings.root('refrigerator')}/state',
        jsonEncode({'received_at': ts, 'payload': '{"TempIn":4}'}),
      );
      receive(1000);
      receive(900);
      expect(
        c.samples['refrigerator']!.receivedAt.millisecondsSinceEpoch,
        1000000,
      );
      expect(Sample.parse('{"TempIn":4}'), isNull);
    },
  );
  test('settings round trip and validation', () {
    final s = PhoneSettings.fromJson(
      jsonDecode(jsonEncode(const PhoneSettings().toJson())),
    );
    expect(s.validate(), isNull);
    expect(s.installation, '64da274cb2a1');
    expect(
      const PhoneSettings(local: Endpoint('tcp://host', 1883)).validate(),
      isNotNull,
    );
    expect(
      const PhoneSettings(local: Endpoint('localhost', 0)).validate(),
      isNotNull,
    );
  });
  test('background stops requests and resume starts local first', () async {
    final c = create([true, true]);
    addTearDown(c.dispose);
    await c.start();
    c.suspend();
    expect(c.connected, false);
    expect(links.first.closed, true);
    c.request(const ModuleProfile('refrigerator', 'یخچال', 30));
    expect(links.first.sent.length, 1);
    await c.reconnect();
    expect(c.route, 'local');
    expect(attempts, ['192.168.1.55', '192.168.1.55']);
  });
  test('catalog replaces list and removes modules centrally', () async {
    final c = create([true]);
    addTearDown(c.dispose);
    await c.start();
    deliverCatalog(c, links.single);
    expect(c.catalogLoaded, true);
    deliverCatalog(c, links.single, modules: []);
    expect(c.modules, isEmpty);
  });
  test('settings use revision and correlated local acknowledgement', () async {
    final c = create([true]);
    addTearDown(c.dispose);
    await c.start();
    deliverCatalog(c, links.single);
    final pending = c.saveValues(c.modules.single, {'Temp': 8});
    final raw = links.single.sent.last;
    final data = jsonDecode(raw.substring(raw.indexOf(' ') + 1));
    expect(data['schema_revision'], 'testrevision');
    expect(data['values'], {'Temp': 8});
    links.single.receive!(
      'homa/${c.settings.installation}/clients/${c.clientId}/result',
      jsonEncode({
        'request_id': data['request_id'],
        'queued': true,
        'device_acknowledged': false,
      }),
    );
    expect((await pending)['device_acknowledged'], false);
  });
  test(
    'public broker cannot send settings even if catalog claims permission',
    () async {
      final c = create([false, true]);
      addTearDown(c.dispose);
      await c.start();
      deliverCatalog(c, links.last);
      expect(c.settingsAllowed, false);
      await expectLater(
        c.saveValues(c.modules.single, {'Temp': 8}),
        throwsStateError,
      );
    },
  );
}
