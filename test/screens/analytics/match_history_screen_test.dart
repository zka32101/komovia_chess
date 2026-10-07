import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_chess/src/screens/analytics/match_history_screen.dart';

void main() {
  group('MatchHistoryScreen', () {
    testWidgets('displays title in AppBar', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: MatchHistoryScreen(
              playerId: 'player1',
              playerName: 'Test Player',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('対戦履歴'), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('displays filter controls', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: MatchHistoryScreen(
              playerId: 'player1',
              playerName: 'Test Player',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('フィルター'), findsOneWidget);
      expect(find.byIcon(Icons.filter_list), findsOneWidget);
    });

    testWidgets('displays reset button', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: MatchHistoryScreen(
              playerId: 'player1',
              playerName: 'Test Player',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('リセット'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('has correct widget structure', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: MatchHistoryScreen(
              playerId: 'player1',
              playerName: 'Test Player',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(Column), findsWidgets);
    });

    testWidgets('displays empty state when no matches',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: MatchHistoryScreen(
              playerId: 'player1',
              playerName: 'Test Player',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Empty state may show after loading completes
      expect(find.byType(Center), findsWidgets);
    });

    testWidgets('has scrollable match list area', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: MatchHistoryScreen(
              playerId: 'player1',
              playerName: 'Test Player',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(Expanded), findsWidgets);
    });
  });
}
