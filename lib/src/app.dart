import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_localizations.dart';
import 'screens/auth/auth_wrapper.dart';
import 'theme/chess_theme.dart';
import 'providers/user_preferences_provider.dart';

class ChessTacticsMasterApp extends ConsumerWidget {
  const ChessTacticsMasterApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // MaterialApp already resolves ThemeMode.system against the platform
    // brightness on its own, so no manual dark-mode detection is needed here.
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'Chess Tactics Master',
      theme: ChessTheme.getLightTheme(),
      darkTheme: ChessTheme.getDarkTheme(),
      themeMode: themeMode,
      home: const AuthWrapper(),
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}
