import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:roleta_viciada_windows/data/database.dart';
import 'package:roleta_viciada_windows/domain/session.dart';
import 'package:roleta_viciada_windows/state/roulette_store.dart';

void main() {
  test('sessões, modo, resultados e jogador sobrevivem ao reinício', () async {
    final directory = await Directory.systemTemp.createTemp('roleta_test_');
    final path = '${directory.path}/test.sqlite';
    AppDatabase? db;
    try {
      db = await AppDatabase.open(path: path);
      final store = RouletteStore(db);
      await store.initialize();
      final first = store.current.id;
      await store.configure(
        ['Ana', 'Beto', 'Caio'],
        true,
        [const PairRule('Ana', 'Beto')],
      );
      await store.setPlayer('Ana');
      final draw = await store.draw();
      expect(draw.target, 'Beto');
      await db.db.close();
      db = await AppDatabase.open(path: path);
      final restored = RouletteStore(db);
      await restored.initialize();
      expect(restored.current.active.single.target, 'Beto');
      expect(restored.current.player, 'Ana');
      await restored.cancel(draw.id);
      expect(restored.current.player, 'Ana');
      expect(restored.current.waiting, contains('Ana'));
      expect((await restored.draw()).target, 'Beto');
      await restored.createSession('Outra sessão');
      expect(restored.current.history, isEmpty);
      await restored.selectSession(first);
      expect(restored.current.active, hasLength(1));
      expect(restored.current.history, hasLength(2));
      expect(
        () => restored.configure(['X', 'Y', 'Z'], false, []),
        throwsStateError,
      );
    } finally {
      await db?.db.close();
      await directory.delete(recursive: true);
    }
  });
  test('senha é persistida como derivação e rejeita senha incorreta', () async {
    final db = await AppDatabase.open(path: ':memory:');
    try {
      expect(await db.hasPassword, isFalse);
      await db.createPassword('minha-senha');
      expect(await db.hasPassword, isTrue);
      expect(await db.verifyPassword('minha-senha'), isTrue);
      expect(await db.verifyPassword('outra-senha'), isFalse);
      expect(await db.setting('password'), isNot(contains('minha-senha')));
      await expectLater(db.createPassword('nova-senha'), throwsStateError);
    } finally {
      await db.db.close();
    }
  });
}
