import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../lib/src/screens/ranking/leaderboard_screen.dart';
import '../../../lib/src/services/ranking_service.dart';
import '../../../lib/src/providers/leaderboard_provider.dart';

// Mock classes
class MockRankingService extends Mock implements RankingService {}

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

void main() {
  late MockRankingService mockRankingService;

  setUp(() {
    mockRankingService = MockRankingService();
  });

  /// Helper to build widget with Riverpod provider
  Widget buildTestWidget(Widget child) {
    return ProviderContainer(
      child: MaterialApp(
        home: child,
      ),
    ).listen;
  }

  group('LeaderboardScreen', () {
    testWidgets('displays loading state initially', (WidgetTester tester) async {
      when(mockRankingService.getGlobalRanking(
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
      )).thenAnswer((_) async => []);

      when(mockRankingService.getRankingStats())
          .thenAnswer((_) async => null);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: LeaderboardScreen(),
            ),
          ),
        ),
      );

      // Initially should show app bar
      expect(find.byType(AppBar), findsWidgets);
    });

    testWidgets('displays filter tabs', (WidgetTester tester) async {
      when(mockRankingService.getGlobalRanking(
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
      )).thenAnswer((_) async => []);

      when(mockRankingService.getRankingStats())
          .thenAnswer((_) async => null);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: LeaderboardScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check for filter chips
      expect(find.byType(FilterChip), findsWidgets);
      expect(find.text('グローバル'), findsOneWidget);
      expect(find.text('月間'), findsOneWidget);
    });

    testWidgets('displays ranking entries', (WidgetTester tester) async {
      final mockEntries = [
        RankingEntry(
          uid: 'uid1',
          displayName: 'Player 1',
          photoUrl: null,
          rating: 1600,
          shogiRankString: '5級',
          gamesPlayed: 10,
          winRate: 0.6,
          rank: 1,
          lastGameAt: DateTime.now(),
        ),
        RankingEntry(
          uid: 'uid2',
          displayName: 'Player 2',
          photoUrl: null,
          rating: 1500,
          shogiRankString: '6級',
          gamesPlayed: 8,
          winRate: 0.5,
          rank: 2,
          lastGameAt: DateTime.now(),
        ),
      ];

      when(mockRankingService.getGlobalRanking(
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
      )).thenAnswer((_) async => mockEntries);

      when(mockRankingService.getRankingStats())
          .thenAnswer((_) async => RankingStats(
            totalPlayers: 2,
            averageRating: 1550,
            topRating: 1600,
            lastUpdated: DateTime.now(),
          ));

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: LeaderboardScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check for player names
      expect(find.text('Player 1'), findsWidgets);
      expect(find.text('Player 2'), findsWidgets);
    });

    testWidgets('displays stats section', (WidgetTester tester) async {
      when(mockRankingService.getGlobalRanking(
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
      )).thenAnswer((_) async => []);

      when(mockRankingService.getRankingStats())
          .thenAnswer((_) async => RankingStats(
            totalPlayers: 100,
            averageRating: 1550,
            topRating: 1900,
            lastUpdated: DateTime.now(),
          ));

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: LeaderboardScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check for stats
      expect(find.text('プレイヤー数'), findsOneWidget);
      expect(find.text('平均レート'), findsOneWidget);
      expect(find.text('最高レート'), findsOneWidget);
    });

    testWidgets('displays error message on failure', (WidgetTester tester) async {
      when(mockRankingService.getGlobalRanking(
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
      )).thenThrow(Exception('Network error'));

      when(mockRankingService.getRankingStats())
          .thenThrow(Exception('Network error'));

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: LeaderboardScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Error should be displayed eventually after retry
      expect(find.byIcon(Icons.refresh), findsWidgets);
    });

    testWidgets('pagination controls are displayed', (WidgetTester tester) async {
      final mockEntries = List.generate(50, (i) => RankingEntry(
        uid: 'uid$i',
        displayName: 'Player $i',
        photoUrl: null,
        rating: 1600 - i * 10,
        shogiRankString: '5級',
        gamesPlayed: 10 + i,
        winRate: 0.5,
        rank: i + 1,
        lastGameAt: DateTime.now(),
      ));

      when(mockRankingService.getGlobalRanking(
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
      )).thenAnswer((_) async => mockEntries);

      when(mockRankingService.getRankingStats())
          .thenAnswer((_) async => RankingStats(
            totalPlayers: 500,
            averageRating: 1550,
            topRating: 1900,
            lastUpdated: DateTime.now(),
          ));

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: LeaderboardScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check for pagination controls
      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      expect(find.text('ページ 1'), findsOneWidget);
    });
  });

  group('RankCard', () {
    testWidgets('displays rank badge', (WidgetTester tester) async {
      final entry = RankingEntry(
        uid: 'uid1',
        displayName: 'Test Player',
        photoUrl: null,
        rating: 1600,
        shogiRankString: '5級',
        gamesPlayed: 10,
        winRate: 0.6,
        rank: 1,
        lastGameAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: RankCard(entry: entry, index: 0),
            ),
          ),
        ),
      );

      expect(find.text('#1'), findsWidgets);
    });

    testWidgets('displays player name', (WidgetTester tester) async {
      final entry = RankingEntry(
        uid: 'uid1',
        displayName: 'Test Player',
        photoUrl: null,
        rating: 1600,
        shogiRankString: '5級',
        gamesPlayed: 10,
        winRate: 0.6,
        rank: 1,
        lastGameAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: RankCard(entry: entry, index: 0),
            ),
          ),
        ),
      );

      expect(find.text('Test Player'), findsOneWidget);
    });

    testWidgets('displays rating', (WidgetTester tester) async {
      final entry = RankingEntry(
        uid: 'uid1',
        displayName: 'Test Player',
        photoUrl: null,
        rating: 1750,
        shogiRankString: '5級',
        gamesPlayed: 10,
        winRate: 0.6,
        rank: 1,
        lastGameAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: RankCard(entry: entry, index: 0),
            ),
          ),
        ),
      );

      expect(find.text('1750'), findsOneWidget);
    });

    testWidgets('displays game stats', (WidgetTester tester) async {
      final entry = RankingEntry(
        uid: 'uid1',
        displayName: 'Test Player',
        photoUrl: null,
        rating: 1600,
        shogiRankString: '5級',
        gamesPlayed: 20,
        winRate: 0.65,
        rank: 1,
        lastGameAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: RankCard(entry: entry, index: 0),
            ),
          ),
        ),
      );

      expect(find.text('20 試合'), findsOneWidget);
      expect(find.textContaining('65.0%'), findsOneWidget);
    });

    testWidgets('displays time since last game', (WidgetTester tester) async {
      final now = DateTime.now();
      final anHourAgo = now.subtract(const Duration(hours: 1));

      final entry = RankingEntry(
        uid: 'uid1',
        displayName: 'Test Player',
        photoUrl: null,
        rating: 1600,
        shogiRankString: '5級',
        gamesPlayed: 10,
        winRate: 0.6,
        rank: 1,
        lastGameAt: anHourAgo,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: RankCard(entry: entry, index: 0),
            ),
          ),
        ),
      );

      expect(find.text('1時間前'), findsOneWidget);
    });
  });
}
