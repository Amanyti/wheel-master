import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roleta_viciada_windows/main.dart';
import 'package:roleta_viciada_windows/data/database.dart';
import 'package:roleta_viciada_windows/state/roulette_store.dart';
import 'package:roleta_viciada_windows/ui/pages.dart';

void main() {
  late AppDatabase db;
  late RouletteStore store;
  setUp(() async {
    db = await AppDatabase.open(path: ':memory:');
    store = RouletteStore(db);
    await store.initialize();
    Modular.setInitialRoute('/');
  });
  tearDown(() async {
    await db.db.close();
  });
  testWidgets(
    'tela principal exige pelo menos três pessoas e exibe popup de nomes',
    (tester) async {
      await tester.pumpWidget(
        ModularApp(module: RouletteModule(store), child: const RouletteApp()),
      );
      await tester.pumpAndSettle();
      final button = find.widgetWithText(FilledButton, 'IR PARA A ROLETA');
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      await tester.runAsync(
        () => store.configure(['Ana', 'Beto', 'Caio'], false, []),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
      await tester.ensureVisible(find.text('Participantes'));
      await tester.tap(find.text('Participantes'));
      await tester.pumpAndSettle();
      expect(find.text('Participantes da roleta'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'roleta apresenta jogador, histórico tabular e botão de resultados',
    (tester) async {
      await tester.runAsync(() async {
        await store.configure(['Ana', 'Beto', 'Caio'], false, []);
        await store.setPlayer('Ana');
        await store.draw();
      });
      await tester.pumpWidget(
        ModularApp(module: RouletteModule(store), child: const RouletteApp()),
      );
      await tester.pumpAndSettle();
      Modular.to.navigate('/wheel');
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(find.text('Jogador: Ana'), findsOneWidget);
      expect(find.text('Só resultados'), findsOneWidget);
      expect(find.byType(DataTable), findsOneWidget);
      expect(find.text('Confirmada'), findsOneWidget);
      expect(find.text('Trocar usuário'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('senha inicial exige confirmação igual', (tester) async {
    await tester.pumpWidget(
      ModularApp(
        module: RouletteModule(store),
        child: MaterialApp(home: PasswordDialog(create: true)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'abcdef');
    await tester.enterText(find.byType(TextField).at(1), 'diferente');
    await tester.tap(find.text('Entrar'));
    await tester.pump();
    expect(find.text('As senhas não coincidem.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
