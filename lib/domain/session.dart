import 'dart:math';

class PairRule {
  const PairRule(this.player, this.target);
  final String player;
  final String target;
  Map<String, dynamic> toMap() => {'player': player, 'target': target};
  factory PairRule.fromMap(Map<String, dynamic> m) =>
      PairRule(m['player'], m['target']);
}

class DrawRecord {
  const DrawRecord({
    required this.id,
    required this.player,
    required this.target,
    required this.date,
    this.cancelled = false,
  });
  final String id;
  final String player;
  final String target;
  final DateTime date;
  final bool cancelled;
  DrawRecord cancel() => DrawRecord(
    id: id,
    player: player,
    target: target,
    date: date,
    cancelled: true,
  );
  Map<String, dynamic> toMap() => {
    'id': id,
    'player': player,
    'target': target,
    'date': date.toIso8601String(),
    'cancelled': cancelled,
  };
  factory DrawRecord.fromMap(Map<String, dynamic> m) => DrawRecord(
    id: m['id'],
    player: m['player'],
    target: m['target'],
    date: DateTime.parse(m['date']),
    cancelled: m['cancelled'],
  );
}

class RouletteSession {
  RouletteSession({
    required this.id,
    required this.name,
    required this.created,
    List<String> names = const [],
    this.rigged = false,
    List<PairRule> rules = const [],
    List<DrawRecord> history = const [],
    this.player,
  }) : names = List.unmodifiable(names),
       rules = List.unmodifiable(rules),
       history = List.unmodifiable(history);
  final String id;
  final String name;
  final DateTime created;
  final List<String> names;
  final bool rigged;
  final List<PairRule> rules;
  final List<DrawRecord> history;
  final String? player;
  List<DrawRecord> get active => history.where((r) => !r.cancelled).toList();
  List<String> get waiting =>
      names.where((n) => !active.any((d) => d.player == n)).toList();
  RouletteSession copy({
    List<String>? names,
    bool? rigged,
    List<PairRule>? rules,
    List<DrawRecord>? history,
    String? player,
    bool clearPlayer = false,
  }) => RouletteSession(
    id: id,
    name: name,
    created: created,
    names: names ?? this.names,
    rigged: rigged ?? this.rigged,
    rules: rules ?? this.rules,
    history: history ?? this.history,
    player: clearPlayer ? null : (player ?? this.player),
  );
  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'created': created.toIso8601String(),
    'names': names,
    'rigged': rigged,
    'rules': rules.map((r) => r.toMap()).toList(),
    'history': history.map((r) => r.toMap()).toList(),
    'player': player,
  };
  factory RouletteSession.fromMap(Map<String, dynamic> m) => RouletteSession(
    id: m['id'],
    name: m['name'],
    created: DateTime.parse(m['created']),
    names: List<String>.from(m['names']),
    rigged: m['rigged'],
    player: m['player'],
    rules: (m['rules'] as List)
        .map((r) => PairRule.fromMap(Map<String, dynamic>.from(r)))
        .toList(),
    history: (m['history'] as List)
        .map((r) => DrawRecord.fromMap(Map<String, dynamic>.from(r)))
        .toList(),
  );
}

/// Testa a existência de um emparelhamento completo, incluindo regras futuras.
class DrawEngine {
  void validate(RouletteSession session, {bool requireMinimum = true}) {
    final names = session.names;
    if (requireMinimum && names.length < 3) {
      throw StateError('Adicione pelo menos 3 participantes.');
    }
    if (names.any((n) => n.trim().isEmpty) ||
        names.map((n) => n.trim().toLowerCase()).toSet().length !=
            names.length) {
      throw StateError('Use nomes não vazios e diferentes.');
    }
    if (session.player != null && !names.contains(session.player)) {
      throw StateError('Participante inválido.');
    }
    final players = <String>{};
    final targets = <String>{};
    for (final r in session.active) {
      if (!names.contains(r.player) ||
          !names.contains(r.target) ||
          r.player == r.target ||
          !players.add(r.player) ||
          !targets.add(r.target)) {
        throw StateError('O histórico contém um resultado incompatível.');
      }
    }
    final rules = session.rigged ? session.rules : <PairRule>[];
    final rulePlayers = <String>{};
    final ruleTargets = <String>{};
    for (final r in rules) {
      if (!names.contains(r.player) ||
          !names.contains(r.target) ||
          r.player == r.target ||
          !rulePlayers.add(r.player) ||
          !ruleTargets.add(r.target)) {
        throw StateError(
          'Regras conflitantes: cada pessoa deve tirar e ser tirada uma única vez, sem tirar a si mesma.',
        );
      }
    }
    if (names.length >= 3 && !_canComplete(session)) {
      throw StateError(
        'Estas regras não permitem uma distribuição completa. Revise as combinações.',
      );
    }
  }

  bool _canComplete(RouletteSession s, {MapEntry<String, String>? extra}) {
    final fixed = <String, String>{};
    bool add(String a, String b) {
      if (a == b || !s.names.contains(a) || !s.names.contains(b)) return false;
      if (fixed.containsKey(a)) return fixed[a] == b;
      if (fixed.containsValue(b)) return false;
      fixed[a] = b;
      return true;
    }

    for (final r in s.rigged ? s.rules : <PairRule>[]) {
      if (!add(r.player, r.target)) return false;
    }
    for (final r in s.active) {
      if (!add(r.player, r.target)) return false;
    }
    if (extra != null && !add(extra.key, extra.value)) return false;
    final remaining = s.names.where((n) => !fixed.containsKey(n)).toList();
    final available = s.names.where((n) => !fixed.containsValue(n)).toList();
    final assigned = <String, String>{};
    bool match(String player, Set<String> seen) {
      for (final target in available) {
        if (target == player || !seen.add(target)) continue;
        final previous = assigned[target];
        if (previous == null || match(previous, seen)) {
          assigned[target] = player;
          return true;
        }
      }
      return false;
    }

    return remaining.every((p) => match(p, {}));
  }

  List<String> candidates(RouletteSession s, String player) {
    validate(s);
    if (!s.waiting.contains(player)) {
      throw StateError('Esta pessoa já jogou ou não participa desta sessão.');
    }
    final used = s.active.map((d) => d.target).toSet();
    return s.names
        .where(
          (target) =>
              target != player &&
              !used.contains(target) &&
              _canComplete(s, extra: MapEntry(player, target)),
        )
        .toList();
  }

  String draw(RouletteSession s, String player, Random random) {
    final options = candidates(s, player);
    if (options.isEmpty) {
      throw StateError('Não há resultado válido para esta pessoa.');
    }
    return options[random.nextInt(options.length)];
  }
}
