import 'dart:convert';
import 'dart:math';
import 'dart:isolate';
import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../domain/session.dart';

class AppDatabase {
  AppDatabase(this.db);
  final Database db;
  static Future<AppDatabase> open({String? path}) async {
    sqfliteFfiInit();
    path ??= p.join(
      (await getApplicationSupportDirectory()).path,
      'roleta.sqlite',
    );
    final db = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE sessions (id TEXT PRIMARY KEY, payload TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
          );
        },
      ),
    );
    return AppDatabase(db);
  }

  Future<List<RouletteSession>> sessions() async =>
      (await db.query('sessions'))
          .map(
            (row) =>
                RouletteSession.fromMap(jsonDecode(row['payload'] as String)),
          )
          .toList()
        ..sort((a, b) => b.created.compareTo(a.created));
  Future<String?> setting(String key) async {
    final rows = await db.query('settings', where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<void> setSetting(String key, String value) => db
      .insert('settings', {
        'key': key,
        'value': value,
      }, conflictAlgorithm: ConflictAlgorithm.replace)
      .then((_) {});
  Future<void> save(RouletteSession session) async {
    await db.transaction((txn) async {
      await txn.insert('sessions', {
        'id': session.id,
        'payload': jsonEncode(session.toMap()),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.insert('settings', {
        'key': 'current',
        'value': session.id,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<bool> get hasPassword async => await setting('password') != null;
  static Future<List<int>> _derive(String password, List<int> salt) =>
      Isolate.run(() async {
        final key = await Pbkdf2(
          macAlgorithm: Hmac.sha256(),
          iterations: 120000,
          bits: 256,
        ).deriveKey(secretKey: SecretKey(utf8.encode(password)), nonce: salt);
        return key.extractBytes();
      });
  Future<void> createPassword(String password) async {
    if (await hasPassword) throw StateError('A senha já foi definida.');
    if (password.length < 6) throw StateError('Use pelo menos 6 caracteres.');
    final random = Random.secure();
    final salt = List.generate(24, (_) => random.nextInt(256));
    final hash = await _derive(password, salt);
    await setSetting(
      'password',
      jsonEncode({'salt': base64Encode(salt), 'hash': base64Encode(hash)}),
    );
  }

  Future<bool> verifyPassword(String password) async {
    final value = await setting('password');
    if (value == null) return false;
    final stored = jsonDecode(value);
    final actual = await _derive(password, base64Decode(stored['salt']));
    final expected = base64Decode(stored['hash']);
    var diff = actual.length ^ expected.length;
    for (var i = 0; i < actual.length && i < expected.length; i++) {
      diff |= actual[i] ^ expected[i];
    }
    return diff == 0;
  }
}
