import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_chess/l10n/app_localizations.dart';
import 'package:komovia_chess/src/hybrid_battle/hybrid_battle_screen.dart';

void main() {
  testWidgets('renders board and lets the chess side move a pawn',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: const HybridBattleScreen(),
    ));
    expect(find.text('Chess side to move'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('hybrid-sq-6-4')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('hybrid-sq-4-4')));
    await tester.pump();
    expect(find.text('Shogi side to move'), findsOneWidget);
  });
}
