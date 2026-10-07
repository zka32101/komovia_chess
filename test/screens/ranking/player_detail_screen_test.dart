import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/src/screens/ranking/player_detail_screen.dart';
import '../../../lib/src/services/ranking_service.dart';

void main() {
  group('PlayerDetailScreen', () {
    testWidgets('displays player header with name and shogi rank', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: PlayerDetailScreen(
              uid: 'uid1',
              displayName: 'Test Player',
              shogiRankString: '5級',
              rating: 1600,
              gamesPlayed: 20,
              wins: 12,
              losses: 8,
              draws: 0,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Test Player'), findsWidgets);
      expect(find.text('5級'), findsWidgets);
    });

    testWidgets('displays rating prominently', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: PlayerDetailScreen(
              uid: 'uid1',
              displayName: 'Test Player',
              shogiRankString: '5級',
              rating: 1750,
              gamesPlayed: 20,
              wins: 12,
              losses: 8,
              draws: 0,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('1750'), findsWidgets);
      expect(find.text('レーティング'), findsOneWidget);
    });

    testWidgets('displays win rate', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: PlayerDetailScreen(
              uid: 'uid1',
              displayName: 'Test Player',
              shogiRankString: '5級',
              rating: 1600,
              gamesPlayed: 20,
              wins: 12,
              losses: 8,
              draws: 0,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('勝率'), findsOneWidget);
      expect(find.textContaining('60.0%'), findsOneWidget);
    });

    testWidgets('displays all game statistics', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: PlayerDetailScreen(
              uid: 'uid1',
              displayName: 'Test Player',
              shogiRankString: '5級',
              rating: 1600,
              gamesPlayed: 30,
              wins: 18,
              losses: 10,
              draws: 2,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check all stats cards
      expect(find.text('ゲーム数'), findsOneWidget);
      expect(find.text('30'), findsWidgets);

      expect(find.text('勝利'), findsOneWidget);
      expect(find.text('18'), findsWidgets);

      expect(find.text('敗北'), findsOneWidget);
      expect(find.text('10'), findsWidgets);

      expect(find.text('引き分け'), findsOneWidget);
      expect(find.text('2'), findsWidgets);
    });

    testWidgets('displays nearby rankings section', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: PlayerDetailScreen(
              uid: 'uid1',
              displayName: 'Test Player',
              shogiRankString: '5級',
              rating: 1600,
              gamesPlayed: 20,
              wins: 12,
              losses: 8,
              draws: 0,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('周辺のランキング'), findsOneWidget);
    });

    testWidgets('displays refresh button in app bar', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: PlayerDetailScreen(
              uid: 'uid1',
              displayName: 'Test Player',
              shogiRankString: '5級',
              rating: 1600,
              gamesPlayed: 20,
              wins: 12,
              losses: 8,
              draws: 0,
            ),
          ),
        ),
      );

      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('displays detailed view when rank is available', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: PlayerDetailScreen(
              uid: 'uid1',
              displayName: 'Test Player',
              shogiRankString: '5級',
              rating: 1600,
              gamesPlayed: 20,
              wins: 12,
              losses: 8,
              draws: 0,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should show rank position card eventually
      expect(find.text('現在のランク'), findsOneWidget);
    });
  });
}
