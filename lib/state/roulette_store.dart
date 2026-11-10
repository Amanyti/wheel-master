import 'dart:math';
import 'package:mobx/mobx.dart';
import '../data/database.dart';
import '../domain/session.dart';

class RouletteStore {
  RouletteStore(this.database);
  final AppDatabase database;
  bool admin = false;
  final engine = DrawEngine();
  final sessions = ObservableList<RouletteSession>();
  final _current = Observable<RouletteSession?>(null);
  final _busy = Observable(false);
  final _spinning = Observable(false);
  RouletteSession get current => _current.value!;
  bool get busy => _busy.value;
  bool get spinning => _spinning.value;
  void setSpinning(bool value) => runInAction(() => _spinning.value = value);
  Future<void> initialize() async {
    final saved = await database.sessions();
    runInAction(() => sessions.addAll(saved));
    if (saved.isEmpty) {
      await createSession('Minha primeira sessão');
    } else {
      final id = await database.setting('current');
      runInAction(
        () => _current.value = saved.firstWhere(
          (s) => s.id == id,
          orElse: () => saved.first,
        ),
      );
      engine.validate(current, requireMinimum: false);
    }
  }

  Future<void> _commit(RouletteSession next) async {
    if (busy) throw StateError('Aguarde a operação atual.');
    runInAction(() => _busy.value = true);
    try {
      await database.save(next);
      runInAction(() {
        final index = sessions.indexWhere((s) => s.id == next.id);
        if (index < 0) {
          sessions.insert(0, next);
        } else {
          sessions[index] = next;
        }
        _current.value = next;
      });
    } finally {
      runInAction(() => _busy.value = false);
    }
  }

  Future<void> createSession(String name) async {
    if (spinning) throw StateError('Aguarde o giro.');
    if (name.trim().isEmpty) throw StateError('Informe o nome da sessão.');
    final now = DateTime.now();
    await _commit(
      RouletteSession(
        id: '${now.microsecondsSinceEpoch}_${Random.secure().nextInt(1 << 30)}',
        name: name.trim(),
        created: now,
      ),
    );
  }

  Future<void> selectSession(String id) async {
    if (spinning) throw StateError('Aguarde o giro.');
    await _commit(sessions.firstWhere((s) => s.id == id));
  }

  Future<void> configure(
    List<String> names,
    bool rigged,
    List<PairRule> rules,
  ) async {
    if (spinning || current.history.isNotEmpty) {
      throw StateError(
        'Esta sessão já começou. Crie outra para alterar os participantes ou regras.',
      );
    }
    final next = current.copy(
      names: names.map((n) => n.trim()).toList(),
      rigged: rigged,
      rules: rules,
      clearPlayer: true,
    );
    engine.validate(next, requireMinimum: false);
    await _commit(next);
  }

  Future<void> setPlayer(String player) async {
    if (spinning || !current.names.contains(player)) {
      throw StateError('Selecione um participante válido.');
    }
    await _commit(current.copy(player: player));
  }

  Future<DrawRecord> draw() async {
    if (spinning) throw StateError('A roleta já está girando.');
    final s = current;
    final player = s.player;
    if (player == null) {
      throw StateError('Identifique o participante antes de girar.');
    }
    final target = engine.draw(s, player, Random.secure());
    final now = DateTime.now();
    final record = DrawRecord(
      id: '${now.microsecondsSinceEpoch}',
      player: player,
      target: target,
      date: now,
    );
    await _commit(s.copy(history: [...s.history, record]));
    return record;
  }

  Future<void> cancel(String id) async {
    if (spinning) throw StateError('Aguarde o giro terminar.');
    final records = current.history
        .map((d) => d.id == id ? d.cancel() : d)
        .toList();
    final next = current.copy(history: records);
    engine.validate(next);
    await _commit(next);
  }
}
