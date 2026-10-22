import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

typedef ControlHandler = Future<Object?> Function(
  String method,
  String path,
  Map<String, dynamic> data,
  Map<String, String> query,
);

/// رابط فقط روی همین کامپیوتر باز است؛ وب‌سایت‌ها و شبکه اجازهٔ کنترل ندارند.
class ControlApi {
  ControlApi(this.handler);
  final ControlHandler handler;
  HttpServer? _server;
  bool _busy = false;
  final String token = base64UrlEncode(
    List<int>.generate(32, (_) => Random.secure().nextInt(256)),
  );
  int get port => _server!.port;

  Future<void> start({int port = 17863, File? discovery}) async {
    _server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      port,
      shared: false,
    );
    _server!.idleTimeout = const Duration(seconds: 10);
    _server!.listen(_handle);
    if (discovery != null) {
      await discovery.parent.create(recursive: true);
      await discovery.writeAsString(
        jsonEncode({
          'url': 'http://127.0.0.1:${this.port}',
          'token': token,
          'pid': pid,
          'api_version': 1,
        }),
        flush: true,
      );
    }
  }

  Future<void> _handle(HttpRequest request) async {
    var locked = false;
    Future<void> reply(int status, Object? value) async {
      request.response.statusCode = status;
      request.response.headers.contentType = ContentType.json;
      request.response.headers.set('Cache-Control', 'no-store');
      request.response.write(jsonEncode(value));
      await request.response.close();
    }

    try {
      // درخواست مرورگر و DNS rebinding پذیرفته نمی‌شود؛ CORS هم فعال نیست.
      final host = request.headers.value('host');
      if (request.headers.value('origin') != null ||
          (host != '127.0.0.1:$port' && host != 'localhost:$port')) {
        return await reply(403, {'error': 'local clients only'});
      }
      if (request.headers.value('authorization') != 'Bearer $token') {
        return await reply(401, {'error': 'unauthorized'});
      }
      if (request.method != 'GET' &&
          request.method != 'POST' &&
          request.method != 'PUT') {
        return await reply(405, {'error': 'method not allowed'});
      }
      if (request.method != 'GET') {
        if (_busy) {
          return await reply(409, {'error': 'another command is running'});
        }
        _busy = locked = true;
      }
      final bytes = <int>[];
      await for (final chunk in request.timeout(const Duration(seconds: 5))) {
        bytes.addAll(chunk);
        if (bytes.length > 16384) {
          return await reply(413, {'error': 'body too large'});
        }
      }
      final body = bytes.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(utf8.decode(bytes));
      if (body is! Map<String, dynamic>) {
        throw const FormatException('JSON object required');
      }
      final result = await handler(
        request.method,
        request.uri.path,
        body,
        request.uri.queryParameters,
      );
      await reply(200, result);
    } on UnsupportedError {
      await reply(404, {'error': 'unknown route'});
    } on FormatException catch (error) {
      await reply(400, {'error': error.message});
    } on ArgumentError catch (error) {
      await reply(400, {'error': error.message.toString()});
    } on StateError catch (error) {
      await reply(409, {'error': error.message});
    } catch (_) {
      await reply(500, {'error': 'control operation failed'});
    } finally {
      if (locked) _busy = false;
    }
  }

  Future<void> close() async => _server?.close(force: true);
}
