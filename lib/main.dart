import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'db.dart';
import 'l10n.dart';
import 'notifications.dart';
import 'ui/budget.dart';
import 'ui/dashboard.dart';
import 'ui/loans.dart';
import 'ui/more.dart';
import 'ui/tasks.dart';

final ValueNotifier<ThemeMode> themeMode = ValueNotifier<ThemeMode>(ThemeMode.light);

/// Remembers which tab is open so changing the language does not reset it.
int shellIndex = 0;

Future<void> loadTheme() async {
  final v = await AppDb.instance.getSetting('dark');
  themeMode.value = v == '1' ? ThemeMode.dark : ThemeMode.light;
  final lang = await AppDb.instance.getSetting('lang');
  if ((lang ?? 'en') != appLang.value) applyLanguage(lang ?? 'en');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('en');
  await initializeDateFormatting('ur');
  final db = AppDb.instance;
  await db.open();
  await loadTheme();
  await Notifier.init();
  db.version.addListener(() {
    loadTheme();
    Notifier.rescheduleAll(db);
  });
  Notifier.rescheduleAll(db);
  runApp(const PdmApp());
}

class PdmApp extends StatefulWidget {
  const PdmApp({super.key});
  @override
  State<PdmApp> createState() => _PdmAppState();
}

class _PdmAppState extends State<PdmApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      Notifier.rescheduleAll(AppDb.instance);
    }
  }

  ThemeData _theme(Brightness b) => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00897B), brightness: b),
        inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
      );

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: appLang,
      builder: (context, lang, _) => ValueListenableBuilder<ThemeMode>(
        valueListenable: themeMode,
        builder: (context, mode, _) => MaterialApp(
          // New key on language change rebuilds every screen in the new language.
          key: ValueKey(lang),
          title: tr('Personal Daily Manager'),
          debugShowCheckedModeBanner: false,
          themeMode: mode,
          theme: _theme(Brightness.light),
          darkTheme: _theme(Brightness.dark),
          locale: Locale(lang),
          supportedLocales: const [Locale('en'), Locale('ur')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: const Shell(),
        ),
      ),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _i = shellIndex;
  static const _pages = <Widget>[
    DashboardPage(),
    TasksPage(),
    BudgetPage(),
    LoansPage(),
    MorePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _i, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _i,
        onDestinationSelected: (i) => setState(() => _i = shellIndex = i),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home), label: tr('Home')),
          NavigationDestination(icon: const Icon(Icons.checklist_outlined), selectedIcon: const Icon(Icons.checklist), label: tr('Tasks')),
          NavigationDestination(icon: const Icon(Icons.account_balance_wallet_outlined), selectedIcon: const Icon(Icons.account_balance_wallet), label: tr('Budget')),
          NavigationDestination(icon: const Icon(Icons.handshake_outlined), selectedIcon: const Icon(Icons.handshake), label: tr('Udhaar')),
          NavigationDestination(icon: const Icon(Icons.more_horiz), selectedIcon: const Icon(Icons.more_horiz), label: tr('More')),
        ],
      ),
    );
  }
}
