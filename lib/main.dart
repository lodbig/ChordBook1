import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import 'app/router.dart';
import 'app/theme.dart';
import 'data/database/database_manager.dart';
import 'ui/shared/theme_toggle.dart';
import 'ui/shared/global_keyboard_handler.dart';

// Window manager - Windows only
import 'window_helper_stub.dart'
    if (dart.library.io) 'window_helper_io.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseManager.initialize();
  await initWindow();
  runApp(const ProviderScope(child: ChordBookApp()));
}

class ChordBookApp extends ConsumerWidget {
  const ChordBookApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final fontScale = ref.watch(fontScaleProvider);

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): () => onEscPressed(),
        const SingleActivator(LogicalKeyboardKey.f11): () => onF11Pressed(),
        const SingleActivator(LogicalKeyboardKey.keyQ, control: true): () =>
            confirmAndExit(context),
      },
      child: MaterialApp.router(
        title: 'ChordBook',
        debugShowCheckedModeBanner: false,
        locale: const Locale('he'),
        supportedLocales: const [Locale('he'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => Directionality(
          textDirection: TextDirection.rtl,
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(fontScale),
            ),
            child: GlobalKeyboardHandler(
              child: child!,
            ),
          ),
        ),
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        routerConfig: appRouter,
      ),
    );
  }
}
