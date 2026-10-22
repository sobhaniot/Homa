import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:homa_control/core/control_api.dart';

void main() {
  test('کنترل محلی: توکن، منع مرورگر، اعتبارسنجی و اجرای فرمان', () async {
    final calls = <String>[];
    final api = ControlApi((method, path, data, query) async {
      if (path == '/missing') throw UnsupportedError(path);
      calls.add('$method $path');
      return {'ok': true, 'value': data['value']};
    });
    final client = HttpClient();
    final dir = await Directory.systemTemp.createTemp('homa-control-');
    try {
      final discovery = File('${dir.path}/control-api.json');
      await api.start(port: 0, discovery: discovery);
      final details = jsonDecode(await discovery.readAsString()) as Map;
      expect(details['token'], api.token);
      expect(details['url'], 'http://127.0.0.1:${api.port}');
      Future<int> send(
        String method,
        String path, {
        bool auth = true,
        String? origin,
        String? body,
      }) async {
        final req = await client.openUrl(
          method,
          Uri.parse('${details['url']}$path'),
        );
        if (auth) req.headers.set('Authorization', 'Bearer ${api.token}');
        if (origin != null) req.headers.set('Origin', origin);
        if (body != null) req.write(body);
        final res = await req.close();
        await res.drain<void>();
        return res.statusCode;
      }

      expect(await send('GET', '/v1/status', auth: false), 401);
      expect(
        await send('GET', '/v1/status', origin: 'http://example.com'),
        403,
      );
      expect(await send('DELETE', '/v1/status'), 405);
      expect(await send('POST', '/v1/action', body: '[]'), 400);
      expect(await send('GET', '/missing'), 404);
      expect(await send('POST', '/v1/action', body: '{"value":4}'), 200);
      expect(calls, ['POST /v1/action']);
      expect(await send('POST', '/v1/action', body: 'x' * 16385), 413);
    } finally {
      client.close(force: true);
      await api.close();
      await dir.delete(recursive: true);
    }
  });
}
