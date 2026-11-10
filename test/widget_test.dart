import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:roleta_viciada_windows/domain/session.dart';

RouletteSession session(
  List<String> names, {
  bool rigged = false,
  List<PairRule> rules = const [],
}) => RouletteSession(
  id: 'test',
  name: 'Teste',
  created: DateTime(2026),
  names: names,
  rigged: rigged,
  rules: rules,
);
DrawRecord record(String player, String target) => DrawRecord(
  id: '$player-$target',
  player: player,
  target: target,
  date: DateTime(2026),
);

void main() {
  final engine = DrawEngine();
  test('exige três nomes, rejeita nomes repetidos e autorregras', () {
    expect(() => engine.validate(session(['Ana', 'Beto'])), throwsStateError);
    expect(
      () => engine.validate(session(['Ana', 'ana', 'Caio'])),
      throwsStateError,
    );
    expect(
      () => engine.validate(
        session(
          ['Ana', 'Beto', 'Caio'],
          rigged: true,
          rules: [const PairRule('Ana', 'Ana')],
        ),
      ),
      throwsStateError,
    );
  });
  test('rejeita duplicidade de destino, de jogador e conflitos globais', () {
    final names = ['Ana', 'Beto', 'Caio'];
    for (final rules in [
      [const PairRule('Ana', 'Caio'), const PairRule('Beto', 'Caio')],
      [const PairRule('Ana', 'Beto'), const PairRule('Ana', 'Caio')],
      [const PairRule('Ana', 'Beto'), const PairRule('Beto', 'Ana')],
    ]) {
      expect(
        () => engine.validate(session(names, rigged: true, rules: rules)),
        throwsStateError,
      );
    }
  });
  test(
    'regra parcial reserva o destino mesmo que o jogador jogue por último',
    () {
      var s = session(
        ['Ana', 'Beto', 'Caio', 'Duda', 'Eva', 'Fábio'],
        rigged: true,
        rules: [const PairRule('Ana', 'Beto')],
      );
      for (final player in ['Caio', 'Duda', 'Eva', 'Fábio', 'Beto', 'Ana']) {
        final target = engine.draw(s, player, Random(42));
        if (player == 'Ana') {
          expect(target, 'Beto');
        } else {
          expect(target, isNot('Beto'));
        }
        expect(target, isNot(player));
        s = s.copy(history: [...s.history, record(player, target)]);
      }
      expect(s.active.map((d) => d.target).toSet(), s.names.toSet());
    },
  );
  test('sorteios normais completam sem repetição nem pessoa sem opção', () {
    for (var count = 3; count <= 12; count++) {
      for (var seed = 0; seed < 40; seed++) {
        final random = Random(seed);
        var s = session(List.generate(count, (i) => 'Pessoa $i'));
        final order = List.of(s.names)..shuffle(random);
        for (final player in order) {
          final target = engine.draw(s, player, random);
          expect(target, isNot(player));
          expect(s.active.any((d) => d.target == target), isFalse);
          s = s.copy(history: [...s.history, record(player, target)]);
        }
        expect(s.active.length, count);
        expect(s.waiting, isEmpty);
      }
    }
  });
  test('cancelamento devolve resultado e preserva regra e jogador', () {
    var s = session(
      ['Ana', 'Beto', 'Caio'],
      rigged: true,
      rules: [const PairRule('Ana', 'Beto')],
    );
    s = s.copy(player: 'Ana', history: [record('Ana', 'Beto')]);
    expect(() => engine.draw(s, 'Ana', Random()), throwsStateError);
    s = s.copy(history: [s.history.single.cancel()]);
    expect(s.player, 'Ana');
    expect(engine.draw(s, 'Ana', Random()), 'Beto');
    expect(s.history.single.cancelled, isTrue);
  });
}
