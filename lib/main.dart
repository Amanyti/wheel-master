import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'data/database.dart';
import 'state/roulette_store.dart';
import 'ui/pages.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final store = RouletteStore(await AppDatabase.open());
    await store.initialize();
    runApp(
      ModularApp(module: RouletteModule(store), child: const RouletteApp()),
    );
  } catch (error) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: SelectableText(
                'Não foi possível abrir os dados locais.\n$error',
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RouletteModule extends Module {
  RouletteModule(this.store);
  final RouletteStore store;
  @override
  void binds(Injector i) {
    i.addInstance<RouletteStore>(store);
  }

  @override
  void routes(RouteManager r) {
    r.child('/', child: (_) => const HomePage());
    r.child('/wheel', child: (_) => const WheelPage());
    r.child(
      '/settings',
      child: (_) => const SettingsPage(),
      guards: [AdminGuard(store)],
    );
    r.child('/results', child: (_) => const ResultsPage());
  }
}

class AdminGuard extends RouteGuard {
  AdminGuard(this.store) : super(redirectTo: '/');
  final RouletteStore store;
  @override
  Future<bool> canActivate(String path, ParallelRoute route) async =>
      store.admin;
}

class RouletteApp extends StatelessWidget {
  const RouletteApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'Roleta • O grande encontro',
    debugShowCheckedModeBanner: false,
    routerConfig: Modular.routerConfig,
    theme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xff101222),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xffa78bfa),
        brightness: Brightness.dark,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
      cardTheme: const CardThemeData(color: Color(0xff1c2036), elevation: 0),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
        ),
      ),
    ),
  );
}
