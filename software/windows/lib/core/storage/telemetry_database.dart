import 'dart:io';
import 'dart:convert';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// رکورد پایدار دادهٔ یک ماژول؛ زمان اصلی دریافت منبع حفظ می‌شود.
class TelemetryRecord {
  const TelemetryRecord({
    required this.moduleId,
    required this.receivedAt,
    required this.payload,
  });

  final String moduleId;
  final DateTime receivedAt;
  final String payload;

  factory TelemetryRecord.fromRow(Map<String, Object?> row) => TelemetryRecord(
    moduleId: row['module_id']! as String,
    receivedAt: DateTime.fromMillisecondsSinceEpoch(
      row['received_at_ms']! as int,
    ),
    payload: row['payload']! as String,
  );
}

/// ذخیره‌سازی SQLite اپ ویندوز برای نمودار تاریخی و دریافت دوبارهٔ بازه‌ها.
class TelemetryDatabase {
  TelemetryDatabase({DatabaseFactory? factory, this.path})
    : _factory = factory ?? databaseFactoryFfi;

  final DatabaseFactory _factory;
  final String? path;
  Database? _database;
  Future<Database>? _openingDatabase;

  Future<void> open() async {
    if (_database != null) return;
    final pendingOpen = _openingDatabase;
    if (pendingOpen != null) {
      _database = await pendingOpen;
      return;
    }
    final opening = _openDatabase();
    _openingDatabase = opening;
    try {
      _database = await opening;
    } finally {
      if (identical(_openingDatabase, opening)) _openingDatabase = null;
    }
  }

  Future<Database> _openDatabase() async {
    final dbPath = path ?? _defaultPath();
    await Directory(File(dbPath).parent.path).create(recursive: true);
    return _factory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 2,
        onUpgrade: (db, oldVersion, _) async {
          if (oldVersion < 2) await _createArchive(db);
        },
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE telemetry (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              module_id TEXT NOT NULL,
              received_at_ms INTEGER NOT NULL,
              payload TEXT NOT NULL,
              UNIQUE(module_id, received_at_ms, payload)
            )
          ''');
          await db.execute(
            'CREATE INDEX telemetry_module_time '
            'ON telemetry(module_id, received_at_ms)',
          );
          await db.execute('''
            CREATE TABLE app_settings (
              setting_key TEXT PRIMARY KEY,
              setting_value TEXT NOT NULL
            )
          ''');
          await _createArchive(db);
        },
      ),
    );
  }

  Future<void> _createArchive(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE archive_records (
      stream_id TEXT NOT NULL, remote_id INTEGER NOT NULL, module_id TEXT NOT NULL,
      received_at REAL NOT NULL, payload TEXT NOT NULL, parsed TEXT,
      archived_at_ms INTEGER NOT NULL, PRIMARY KEY(stream_id,remote_id))''');
    await db.execute(
      'CREATE INDEX archive_module_time ON archive_records(module_id,received_at)',
    );
    await db.execute(
      '''CREATE TABLE archive_checkpoints (
      stream_id TEXT PRIMARY KEY, remote_id INTEGER NOT NULL, synced_at_ms INTEGER NOT NULL)''',
    );
    await db.execute('''CREATE TABLE archive_modules (
      stream_id TEXT NOT NULL,module_id TEXT NOT NULL,config_json TEXT NOT NULL,
      saved_at_ms INTEGER NOT NULL,PRIMARY KEY(stream_id,module_id))''');
    await db.execute('''CREATE TABLE archive_values (
      stream_id TEXT NOT NULL, remote_id INTEGER NOT NULL, metric TEXT NOT NULL,
      numeric_value REAL, text_value TEXT,
      PRIMARY KEY(stream_id,remote_id,metric))''');
    await db.execute(
      '''CREATE VIEW archive_measurements AS
      SELECT r.stream_id,r.remote_id,r.module_id,r.received_at,v.metric,v.numeric_value,v.text_value
      FROM archive_records r JOIN archive_values v USING(stream_id,remote_id)''',
    );
  }

  Future<int> archiveCheckpoint(String stream) async {
    final db = await _requireDatabase();
    final rows = await db.query(
      'archive_checkpoints',
      where: 'stream_id=?',
      whereArgs: [stream],
    );
    return rows.isEmpty ? 0 : rows.single['remote_id'] as int;
  }

  /// رکوردها و نقطهٔ ادامه با یک تراکنش ذخیره می‌شوند؛ سپس اجازهٔ ACK داریم.
  Future<void> commitArchivePage(
    String stream,
    List<Map<String, dynamic>> rows,
    int cursor,
  ) async {
    final db = await _requireDatabase();
    await db.transaction((txn) async {
      final committed = await _checkpointIn(txn, stream);
      var previous = 0;
      for (final row in rows) {
        final id = row['id'];
        if (id is! int ||
            id <= previous ||
            row['module_id'] is! String ||
            row['ts'] is! num ||
            !(row['ts'] as num).isFinite ||
            row['payload'] is! String) {
          throw const FormatException('Invalid archive page');
        }
        previous = id;
        if (id <= committed) continue;
        await txn.insert('archive_records', {
          'stream_id': stream,
          'remote_id': id,
          'module_id': row['module_id'],
          'received_at': row['ts'],
          'payload': row['payload'],
          'parsed': row['parsed'],
          'archived_at_ms': DateTime.now().millisecondsSinceEpoch,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
        try {
          final decoded = jsonDecode(row['payload'] as String);
          if (decoded is Map<String, dynamic>) {
            for (final entry in decoded.entries) {
              final value = entry.value;
              await txn.insert('archive_values', {
                'stream_id': stream,
                'remote_id': id,
                'metric': entry.key,
                'numeric_value': value is num && value.isFinite ? value : null,
                'text_value': value is num ? null : jsonEncode(value),
              }, conflictAlgorithm: ConflictAlgorithm.ignore);
            }
          }
        } on FormatException {
          // متن اصلی حتی وقتی JSON قابل‌تجزیه نیست حفظ می‌شود.
        }
      }
      if ((rows.isNotEmpty && cursor != previous) || cursor < committed) {
        if (cursor <= committed &&
            rows.every((r) => (r['id'] as int) <= committed)) {
          return;
        }
        throw const FormatException('Archive cursor mismatch');
      }
      if (rows.isEmpty && cursor != committed) {
        throw const FormatException('Empty page advanced cursor');
      }
      await txn.insert('archive_checkpoints', {
        'stream_id': stream,
        'remote_id': cursor,
        'synced_at_ms': DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<int> _checkpointIn(DatabaseExecutor db, String stream) async {
    final rows = await db.query(
      'archive_checkpoints',
      where: 'stream_id=?',
      whereArgs: [stream],
    );
    return rows.isEmpty ? 0 : rows.single['remote_id'] as int;
  }

  Future<Map<String, Object?>> archiveStatus() async {
    final db = await _requireDatabase();
    return {
      'database_path': db.path,
      'archive_records': (await db.rawQuery(
        'SELECT COUNT(*) AS n FROM archive_records',
      )).single['n'],
      'checkpoints': await db.query('archive_checkpoints'),
      'retention': 'permanent_on_windows',
    };
  }

  Future<void> saveArchiveModules(String stream, List<dynamic> modules) async {
    final db = await _requireDatabase();
    await db.transaction((txn) async {
      for (final raw in modules) {
        final module = Map<String, dynamic>.from(raw as Map)..remove('latest');
        await txn.insert('archive_modules', {
          'stream_id': stream,
          'module_id': module['id'],
          'config_json': jsonEncode(module),
          'saved_at_ms': DateTime.now().millisecondsSinceEpoch,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<int> save(TelemetryRecord record) async {
    final db = await _requireDatabase();
    return db.insert('telemetry', {
      'module_id': record.moduleId,
      'received_at_ms': record.receivedAt.millisecondsSinceEpoch,
      'payload': record.payload,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<int> saveBatch(Iterable<TelemetryRecord> records) async {
    final db = await _requireDatabase();
    final batch = db.batch();
    for (final record in records) {
      batch.insert('telemetry', {
        'module_id': record.moduleId,
        'received_at_ms': record.receivedAt.millisecondsSinceEpoch,
        'payload': record.payload,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    final results = await batch.commit(noResult: false);
    return results.where((result) => result != null && result != 0).length;
  }

  Future<List<TelemetryRecord>> readRange({
    required String moduleId,
    required DateTime from,
    required DateTime to,
    int limit = 600,
  }) async {
    final db = await _requireDatabase();
    final rows = await db.rawQuery(
      '''SELECT * FROM (
      SELECT module_id,received_at_ms,payload FROM telemetry
      UNION SELECT module_id,CAST(ROUND(received_at*1000) AS INTEGER) AS received_at_ms,payload FROM archive_records
      ) WHERE module_id=? AND received_at_ms>=? AND received_at_ms<=?
      ORDER BY received_at_ms DESC LIMIT ?''',
      [moduleId, from.millisecondsSinceEpoch, to.millisecondsSinceEpoch, limit],
    );
    return rows
        .map(TelemetryRecord.fromRow)
        .toList()
        .reversed
        .toList(growable: false);
  }

  Future<List<TelemetryRecord>> readRecent({
    required String moduleId,
    int limit = 300,
  }) async {
    return readRange(
      moduleId: moduleId,
      from: DateTime.fromMillisecondsSinceEpoch(0),
      to: DateTime.now().add(const Duration(days: 1)),
      limit: limit,
    );
  }

  Future<DateTime?> latestTime(String moduleId) async {
    final db = await _requireDatabase();
    final rows = await db.rawQuery(
      'SELECT MAX(received_at_ms) AS latest FROM telemetry WHERE module_id = ?',
      [moduleId],
    );
    final value = rows.single['latest'];
    return value is int ? DateTime.fromMillisecondsSinceEpoch(value) : null;
  }

  Future<int> count(String moduleId) async {
    final db = await _requireDatabase();
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM telemetry WHERE module_id = ?',
      [moduleId],
    );
    return (rows.single['total'] as int?) ?? 0;
  }

  Future<String?> getSetting(String key) async {
    final db = await _requireDatabase();
    final rows = await db.query(
      'app_settings',
      columns: ['setting_value'],
      where: 'setting_key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.single['setting_value'] as String;
  }

  Future<void> saveSetting(String key, String value) async {
    final db = await _requireDatabase();
    await db.insert('app_settings', {
      'setting_key': key,
      'setting_value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteSetting(String key) async {
    final db = await _requireDatabase();
    await db.delete('app_settings', where: 'setting_key = ?', whereArgs: [key]);
  }

  Future<void> close() async {
    final db = _database;
    _database = null;
    await db?.close();
  }

  Future<Database> _requireDatabase() async {
    await open();
    return _database!;
  }

  String _defaultPath() {
    // داده‌ها جدا از سورس و ابزارها روی F هستند؛ به مسیر دیگری بی‌صدا برنمی‌گردیم.
    return r'F:\_HomaData\database\homa_telemetry.db';
  }
}
