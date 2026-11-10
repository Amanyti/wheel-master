import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';
import '../domain/session.dart';
import '../state/roulette_store.dart';
import 'wheel.dart';

RouletteStore get store => Modular.get<RouletteStore>();
void message(BuildContext context, Object error) =>
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.toString().replaceFirst('Bad state: ', ''))),
    );
Future<void> attempt(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } catch (e) {
    if (context.mounted) message(context, e);
  }
}

Widget panel(Widget child) => Card(
  child: Padding(padding: const EdgeInsets.all(24), child: child),
);
Future<String?> textDialog(
  BuildContext context,
  String title, {
  String initial = '',
  String label = 'Nome',
  bool multiline = false,
}) async {
  final input = TextEditingController(text: initial);
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 460,
        child: TextField(
          controller: input,
          autofocus: true,
          maxLines: multiline ? 10 : 1,
          decoration: InputDecoration(labelText: label),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, input.text),
          child: const Text('Salvar'),
        ),
      ],
    ),
  );
  // Aguarda o fechamento para não descartar o controller durante a animação do diálogo.
  await Future<void>.delayed(const Duration(milliseconds: 250));
  input.dispose();
  return result;
}

Future<bool> unlock(BuildContext context) async {
  final existing = await store.database.hasPassword;
  if (!context.mounted) return false;
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => PasswordDialog(create: !existing),
      ) ??
      false;
}

class PasswordDialog extends StatefulWidget {
  const PasswordDialog({super.key, required this.create});
  final bool create;
  @override
  State<PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<PasswordDialog> {
  final password = TextEditingController();
  final confirmation = TextEditingController();
  bool busy = false;
  String? error;
  @override
  void dispose() {
    password.dispose();
    confirmation.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (widget.create) {
        if (password.text != confirmation.text) {
          throw StateError('As senhas não coincidem.');
        }
        await store.database.createPassword(password.text);
      } else if (!await store.database.verifyPassword(password.text)) {
        throw StateError('Senha incorreta.');
      }
      store.admin = true;
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Bad state: ', ''));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AlertDialog(
      title: Text(
        widget.create
            ? 'Defina a senha das configurações'
            : 'Acesso às configurações',
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: password,
              obscureText: true,
              enabled: !busy,
              autofocus: true,
              onSubmitted: (_) {
                if (!widget.create) submit();
              },
              decoration: const InputDecoration(
                labelText: 'Senha',
                helperText: 'Pelo menos 6 caracteres no primeiro acesso',
              ),
            ),
            if (widget.create) ...[
              const SizedBox(height: 18),
              TextField(
                controller: confirmation,
                obscureText: true,
                enabled: !busy,
                onSubmitted: (_) => submit(),
                decoration: const InputDecoration(
                  labelText: 'Confirme a senha',
                ),
              ),
            ],
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  error!,
                  style: const TextStyle(color: Colors.orangeAccent),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: busy ? null : submit,
          child: Text(busy ? 'Aguarde…' : 'Entrar'),
        ),
      ],
    ),
  );
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});
  Future<void> names(BuildContext context) async {
    if (store.current.history.isNotEmpty) {
      message(
        context,
        'Esta sessão já começou. Crie outra nas configurações para alterar os nomes.',
      );
      return;
    }
    final result = await textDialog(
      context,
      'Participantes da roleta',
      initial: store.current.names.join('\n'),
      label: 'Um nome por linha',
      multiline: true,
    );
    if (result == null || !context.mounted) return;
    await attempt(
      context,
      () => store.configure(
        result
            .split('\n')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
        store.current.rigged,
        store.current.rules,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-.5, -.7),
                radius: 1.5,
                colors: [
                  const Color(0xff342054),
                  Theme.of(context).scaffoldBackgroundColor,
                ],
              ),
            ),
          ),
        ),
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: Observer(
                builder: (_) {
                  final s = store.current;
                  final busy = store.busy;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.auto_awesome,
                        size: 52,
                        color: Color(0xffffd58a),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'O GRANDE ENCONTRO',
                        style: TextStyle(
                          fontSize: 13,
                          letterSpacing: 5,
                          color: Color(0xffc4b5fd),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Deixe a roleta\nfazer as conexões.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 52,
                          height: 1.1,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        s.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 28),
                      panel(
                        Column(
                          children: [
                            Wrap(
                              spacing: 24,
                              runSpacing: 12,
                              alignment: WrapAlignment.center,
                              children: [
                                Text('${s.names.length} participantes'),
                                Text(
                                  '${s.active.length} encontros confirmados',
                                ),
                                Text('${s.waiting.length} aguardando'),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Text(
                              s.names.isEmpty
                                  ? 'Adicione pelo menos três nomes para começar.'
                                  : s.names.join('  •  '),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Wrap(
                        spacing: 16,
                        runSpacing: 12,
                        alignment: WrapAlignment.center,
                        children: [
                          OutlinedButton.icon(
                            onPressed: busy ? null : () => names(context),
                            icon: const Icon(Icons.group_add_outlined),
                            label: const Text('Participantes'),
                          ),
                          FilledButton.icon(
                            onPressed: busy || s.names.length < 3
                                ? null
                                : () => Modular.to.pushNamed('/wheel'),
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: const Text('IR PARA A ROLETA'),
                          ),
                          TextButton(
                            onPressed: () => Modular.to.pushNamed('/results'),
                            child: const Text('Ver resultados'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Os nomes e resultados são salvos automaticamente neste computador.',
                        style: TextStyle(color: Colors.white54),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: Semantics(
            label: 'Abrir configurações',
            child: IconButton(
              icon: Icon(
                Icons.settings_outlined,
                color: Colors.white.withValues(alpha: .06),
              ),
              onPressed: () async {
                if (await unlock(context) && context.mounted) {
                  await Modular.to.pushNamed('/settings');
                }
              },
            ),
          ),
        ),
      ],
    ),
  );
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late bool rigged;
  late List<PairRule> rules;
  void load() {
    rigged = store.current.rigged;
    rules = List.of(store.current.rules);
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    store.admin = false;
    super.dispose();
  }

  Future<void> addRule() async {
    if (store.current.names.length < 3) {
      message(
        context,
        'Cadastre pelo menos três participantes na tela principal.',
      );
      return;
    }
    String? source;
    String? target;
    final rule = await showDialog<PairRule>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: const Text('Definir uma combinação'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: source,
                  decoration: const InputDecoration(
                    labelText: 'Quem vai jogar?',
                  ),
                  items: store.current.names
                      .map((n) => DropdownMenuItem(value: n, child: Text(n)))
                      .toList(),
                  onChanged: (v) => update(() => source = v),
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  initialValue: target,
                  decoration: const InputDecoration(
                    labelText: 'Deve tirar quem?',
                  ),
                  items: store.current.names
                      .map((n) => DropdownMenuItem(value: n, child: Text(n)))
                      .toList(),
                  onChanged: (v) => update(() => target = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: source == null || target == null
                  ? null
                  : () => Navigator.pop(ctx, PairRule(source!, target!)),
              child: const Text('Adicionar'),
            ),
          ],
        ),
      ),
    );
    if (rule != null) setState(() => rules.add(rule));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Configurações')),
    body: Observer(
      builder: (_) {
        final s = store.current;
        final locked = s.history.isNotEmpty || store.busy;
        return ListView(
          padding: const EdgeInsets.all(32),
          children: [
            panel(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sessões',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    key: ValueKey(s.id),
                    initialValue: s.id,
                    items: store.sessions
                        .map(
                          (v) => DropdownMenuItem(
                            value: v.id,
                            child: Text(v.name),
                          ),
                        )
                        .toList(),
                    onChanged: store.busy
                        ? null
                        : (v) => attempt(context, () async {
                            await store.selectSession(v!);
                            setState(load);
                          }),
                  ),
                  const SizedBox(height: 18),
                  OutlinedButton.icon(
                    onPressed: store.busy
                        ? null
                        : () async {
                            final name = await textDialog(
                              context,
                              'Nova sessão',
                            );
                            if (name != null && context.mounted) {
                              await attempt(context, () async {
                                await store.createSession(name);
                                setState(load);
                              });
                            }
                          },
                    icon: const Icon(Icons.add),
                    label: const Text('Criar sessão independente'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            panel(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Modo e combinações',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  if (s.history.isNotEmpty)
                    const Text(
                      'Esta sessão já começou. Crie uma nova para mudar as regras.',
                    ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Modo viciado'),
                    subtitle: const Text(
                      'Desligado: sorteio normal. Ligado: respeita as combinações e sorteia os demais.',
                    ),
                    value: rigged,
                    onChanged: locked
                        ? null
                        : (value) => setState(() => rigged = value),
                  ),
                  if (rigged) ...[
                    for (var i = 0; i < rules.length; i++)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('${rules[i].player} → ${rules[i].target}'),
                        trailing: IconButton(
                          onPressed: locked
                              ? null
                              : () => setState(() => rules.removeAt(i)),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ),
                    OutlinedButton(
                      onPressed: locked ? null : addRule,
                      child: const Text('Adicionar combinação'),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: locked
                        ? null
                        : () => attempt(context, () async {
                            await store.configure(s.names, rigged, rules);
                            if (context.mounted) {
                              message(
                                context,
                                'Configuração validada e salva.',
                              );
                            }
                          }),
                    child: const Text('Validar e salvar'),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );
}

class WheelPage extends StatefulWidget {
  const WheelPage({super.key});
  @override
  State<WheelPage> createState() => _WheelPageState();
}

class _WheelPageState extends State<WheelPage> with TickerProviderStateMixin {
  late final AnimationController spin;
  late final AnimationController lights;
  double angle = 0;
  double start = 0;
  double end = 0;
  bool running = false;
  String? winner;
  @override
  void initState() {
    super.initState();
    spin =
        AnimationController(vsync: this, duration: const Duration(seconds: 5))
          ..addListener(() {
            setState(
              () => angle =
                  start +
                  (end - start) * Curves.easeOutCubic.transform(spin.value),
            );
          });
    lights = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (store.current.player == null) pickPlayer();
    });
  }

  @override
  void dispose() {
    spin.dispose();
    lights.dispose();
    store.setSpinning(false);
    super.dispose();
  }

  Future<void> pickPlayer() async {
    final waiting = store.current.waiting;
    if (waiting.isEmpty) {
      message(context, 'Todos os participantes já jogaram.');
      return;
    }
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Quem vai girar a roleta?'),
        children: waiting
            .map(
              (n) => SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, n),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(n),
                ),
              ),
            )
            .toList(),
      ),
    );
    if (selected != null && mounted) {
      await attempt(context, () async {
        await store.setPlayer(selected);
        if (mounted) setState(() => winner = null);
      });
    }
  }

  Future<void> draw() async {
    if (running || store.busy) return;
    setState(() {
      running = true;
      winner = null;
    });
    try {
      final record = await store.draw();
      if (!mounted) return;
      store.setSpinning(true);
      final index = store.current.names.indexOf(record.target);
      final twoPi = math.pi * 2;
      start = angle;
      final landing =
          ((-index * twoPi / store.current.names.length) % twoPi + twoPi) %
          twoPi;
      end =
          angle +
          7 * twoPi +
          ((landing - angle % twoPi) % twoPi + twoPi) % twoPi;
      await spin.forward(from: 0).orCancel;
      if (mounted) setState(() => winner = record.target);
    } catch (e) {
      if (mounted) message(context, e);
    } finally {
      store.setSpinning(false);
      if (mounted) setState(() => running = false);
    }
  }

  Widget history() => panel(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Histórico da sessão',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Observer(
            builder: (_) {
              final history = store.current.history.reversed.toList();
              if (history.isEmpty) {
                return const Center(
                  child: Text('Os encontros vão aparecer aqui.'),
                );
              }
              return SingleChildScrollView(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columnSpacing: 20,
                    columns: const [
                      DataColumn(label: Text('Jogador')),
                      DataColumn(label: Text('Sorteado')),
                      DataColumn(label: Text('Situação')),
                      DataColumn(label: Text('Cancelar')),
                    ],
                    rows: [
                      for (var i = 0; i < history.length; i++)
                        DataRow(
                          cells: [
                            DataCell(Text(history[i].player)),
                            DataCell(
                              Text(
                                running && i == 0
                                    ? 'Girando…'
                                    : history[i].target,
                              ),
                            ),
                            DataCell(
                              Tooltip(
                                message: history[i].date.toLocal().toString(),
                                child: Text(
                                  history[i].cancelled
                                      ? 'Cancelada'
                                      : 'Confirmada',
                                  style: TextStyle(
                                    color: history[i].cancelled
                                        ? Colors.white38
                                        : Colors.greenAccent,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              IconButton(
                                tooltip: 'Devolver o nome ao sorteio',
                                onPressed:
                                    running ||
                                        store.busy ||
                                        history[i].cancelled
                                    ? null
                                    : () => attempt(context, () async {
                                        await store.cancel(history[i].id);
                                        if (mounted) {
                                          setState(() => winner = null);
                                        }
                                      }),
                                icon: const Icon(Icons.undo_rounded),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !running,
    child: Scaffold(
      appBar: AppBar(
        title: Text(store.current.name),
        actions: [
          TextButton.icon(
            onPressed: running ? null : () => Modular.to.pushNamed('/results'),
            icon: const Icon(Icons.table_chart_outlined),
            label: const Text('Só resultados'),
          ),
        ],
      ),
      body: Observer(
        builder: (_) {
          final s = store.current;
          final player = s.player;
          final alreadyPlayed = s.active.any((d) => d.player == player);
          final wheel = Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      player == null
                          ? 'Identifique-se para jogar'
                          : 'Jogador: $player',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: running || store.busy ? null : pickPlayer,
                    child: const Text('Trocar usuário'),
                  ),
                ],
              ),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: AnimatedBuilder(
                      animation: lights,
                      builder: (_, _) => PartyWheel(
                        names: s.names,
                        angle: angle,
                        glow: lights.value,
                      ),
                    ),
                  ),
                ),
              ),
              Text(
                winner == null
                    ? (alreadyPlayed
                          ? 'Esta pessoa já jogou. Troque o usuário ou cancele sua jogada.'
                          : 'Quem será o próximo encontro?')
                    : '$player tirou $winner!',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xffffd58a),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed:
                    running || store.busy || player == null || alreadyPlayed
                    ? null
                    : draw,
                icon: const Icon(Icons.casino_outlined),
                label: Text(running ? 'GIRANDO…' : 'GIRAR ROLETA'),
              ),
              const SizedBox(height: 20),
            ],
          );
          return LayoutBuilder(
            builder: (_, box) => Padding(
              padding: const EdgeInsets.all(20),
              child: box.maxWidth >= 1000
                  ? Row(
                      children: [
                        Expanded(flex: 3, child: wheel),
                        const SizedBox(width: 20),
                        Expanded(flex: 2, child: history()),
                      ],
                    )
                  : SingleChildScrollView(
                      child: Column(
                        children: [
                          SizedBox(height: 600, child: wheel),
                          SizedBox(height: 360, child: history()),
                        ],
                      ),
                    ),
            ),
          );
        },
      ),
    ),
  );
}

class ResultsPage extends StatelessWidget {
  const ResultsPage({super.key});
  Future<void> export(BuildContext context) async {
    final s = store.current;
    await attempt(context, () async {
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Exportar resultados',
        fileName: 'resultados.csv',
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );
      if (path == null) return;
      String field(String value) {
        if (RegExp(r'^[=+@\-\t\r]').hasMatch(value)) value = "'$value";
        return '"${value.replaceAll('"', '""')}"';
      }

      final rows = <List<String>>[
        ['Sessão', 'Jogador', 'Sorteado', 'Data'],
        ...s.active.map(
          (d) => [s.name, d.player, d.target, d.date.toIso8601String()],
        ),
      ];
      await File(
        path.toLowerCase().endsWith('.csv') ? path : '$path.csv',
      ).writeAsString(
        '\uFEFF${rows.map((r) => r.map(field).join(';')).join('\r\n')}',
        encoding: utf8,
        flush: true,
      );
      if (context.mounted) message(context, 'Resultados exportados.');
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Resultados'),
      actions: [
        TextButton.icon(
          onPressed: () => export(context),
          icon: const Icon(Icons.download_outlined),
          label: const Text('Exportar CSV'),
        ),
      ],
    ),
    body: Observer(
      builder: (_) {
        final s = store.current;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(40),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Column(
                children: [
                  const Icon(
                    Icons.celebration_outlined,
                    size: 48,
                    color: Color(0xffffd58a),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    s.name,
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  Text(
                    '${s.active.length} de ${s.names.length} resultados confirmados',
                  ),
                  const SizedBox(height: 24),
                  if (s.active.isEmpty)
                    const Text('Ainda não há resultados confirmados.'),
                  for (final d in s.active)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.arrow_forward_rounded),
                        title: Text(d.player),
                        trailing: Text(
                          d.target,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}
