import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_chess/src/services/analytics_service.dart';

void main() {
  group('AnalyticsService', () {
    late AnalyticsService analytics;

    setUp(() {
      analytics = AnalyticsService();
    });

    group('Event Logging', () {
      test('logs custom event with no parameters', () async {
        final result = await analytics.logEvent('test_event');
        expect(result, isNotNull);
      });

      test('logs custom event with parameters', () async {
        final params = {'level': 'expert', 'duration': 300};
        final result = await analytics.logEvent('puzzle_solved', parameters: params);
        expect(result, isNotNull);
      });

      test('logs event with string parameters', () async {
        final params = {'puzzle_id': 'p123', 'difficulty': 'advanced'};
        final result = await analytics.logEvent('puzzle_started', parameters: params);
        expect(result, isNotNull);
      });

      test('logs event with numeric parameters', () async {
        final params = {'score': 950, 'time_spent': 120.5};
        final result = await analytics.logEvent('game_completed', parameters: params);
        expect(result, isNotNull);
      });

      test('logs event with boolean parameters', () async {
        final params = {'won': true, 'is_ranked': false};
        final result = await analytics.logEvent('multiplayer_game', parameters: params);
        expect(result, isNotNull);
      });

      test('handles event with null parameters', () async {
        final result = await analytics.logEvent('app_opened', parameters: null);
        expect(result, isNotNull);
      });

      test('handles event with empty parameter map', () async {
        final result = await analytics.logEvent('app_closed', parameters: {});
        expect(result, isNotNull);
      });
    });

    group('Screen View Logging', () {
      test('logs screen view', () async {
        final result = await analytics.logScreenView('home_screen', 'HomeScreen');
        expect(result, isNotNull);
      });

      test('logs puzzle screen view', () async {
        final result = await analytics.logScreenView('puzzle_board', 'PuzzleBoard');
        expect(result, isNotNull);
      });

      test('logs game screen view', () async {
        final result = await analytics.logScreenView('game_screen', 'GameScreen');
        expect(result, isNotNull);
      });

      test('logs premium screen view', () async {
        final result = await analytics.logScreenView('premium_paywall', 'PremiumPaywall');
        expect(result, isNotNull);
      });

      test('logs settings screen view', () async {
        final result = await analytics.logScreenView('settings', 'SettingsScreen');
        expect(result, isNotNull);
      });
    });

    group('Game Completion Logging', () {
      test('logs game completed event', () async {
        final result = await analytics.logGameCompleted(
          gameId: 'game_123',
          gameType: 'online_pvp',
          duration: 1200000,
          won: true,
          moveCount: 45,
          ratingBefore: 1500,
          ratingAfter: 1550,
          result: 'checkmate',
        );
        expect(result, isNotNull);
      });

      test('logs game loss', () async {
        final result = await analytics.logGameCompleted(
          gameId: 'game_124',
          gameType: 'cpu',
          duration: 900000,
          won: false,
          moveCount: 32,
          ratingBefore: 1500,
          ratingAfter: 1480,
          result: 'resigned',
        );
        expect(result, isNotNull);
      });

      test('logs draw game', () async {
        final result = await analytics.logGameCompleted(
          gameId: 'game_125',
          gameType: 'online_pvp',
          duration: 1500000,
          won: false,
          moveCount: 60,
          ratingBefore: 1500,
          ratingAfter: 1500,
          result: 'draw',
        );
        expect(result, isNotNull);
      });

      test('logs game with different time controls', () async {
        final result = await analytics.logGameCompleted(
          gameId: 'game_126',
          gameType: '3min_blitz',
          duration: 180000,
          won: true,
          moveCount: 25,
          ratingBefore: 1400,
          ratingAfter: 1420,
          result: 'checkmate',
        );
        expect(result, isNotNull);
      });

      test('logs game with rating gain', () async {
        final result = await analytics.logGameCompleted(
          gameId: 'game_127',
          gameType: 'online_pvp',
          duration: 1200000,
          won: true,
          moveCount: 50,
          ratingBefore: 1500,
          ratingAfter: 1600,
          result: 'checkmate',
        );
        expect(result, isNotNull);
      });

      test('logs game with rating loss', () async {
        final result = await analytics.logGameCompleted(
          gameId: 'game_128',
          gameType: 'online_pvp',
          duration: 1200000,
          won: false,
          moveCount: 30,
          ratingBefore: 1600,
          ratingAfter: 1500,
          result: 'checkmate',
        );
        expect(result, isNotNull);
      });

      test('logs game with no rating change', () async {
        final result = await analytics.logGameCompleted(
          gameId: 'game_129',
          gameType: 'online_pvp',
          duration: 1200000,
          won: false,
          moveCount: 40,
          ratingBefore: 1500,
          ratingAfter: 1500,
          result: 'draw',
        );
        expect(result, isNotNull);
      });
    });

    group('Puzzle Logging', () {
      test('logs puzzle solved event', () async {
        final result = await analytics.logPuzzleSolved(
          puzzleId: 'puzzle_001',
          difficulty: 'intermediate',
          timeSpent: 45000,
        );
        expect(result, isNotNull);
      });

      test('logs puzzle solved - beginner level', () async {
        final result = await analytics.logPuzzleSolved(
          puzzleId: 'puzzle_002',
          difficulty: 'beginner',
          timeSpent: 15000,
        );
        expect(result, isNotNull);
      });

      test('logs puzzle solved - advanced level', () async {
        final result = await analytics.logPuzzleSolved(
          puzzleId: 'puzzle_003',
          difficulty: 'advanced',
          timeSpent: 120000,
        );
        expect(result, isNotNull);
      });

      test('logs puzzle solved - expert level', () async {
        final result = await analytics.logPuzzleSolved(
          puzzleId: 'puzzle_004',
          difficulty: 'expert',
          timeSpent: 180000,
        );
        expect(result, isNotNull);
      });

      test('logs quick puzzle solve', () async {
        final result = await analytics.logPuzzleSolved(
          puzzleId: 'puzzle_005',
          difficulty: 'beginner',
          timeSpent: 5000,
        );
        expect(result, isNotNull);
      });

      test('logs slow puzzle solve', () async {
        final result = await analytics.logPuzzleSolved(
          puzzleId: 'puzzle_006',
          difficulty: 'expert',
          timeSpent: 600000,
        );
        expect(result, isNotNull);
      });
    });

    group('User Preference Logging', () {
      test('logs preference change - theme', () async {
        final result = await analytics.logUserPreferenceChanged('theme', 'dark');
        expect(result, isNotNull);
      });

      test('logs preference change - language', () async {
        final result = await analytics.logUserPreferenceChanged('language', 'es');
        expect(result, isNotNull);
      });

      test('logs preference change - sound', () async {
        final result = await analytics.logUserPreferenceChanged('sound_enabled', true);
        expect(result, isNotNull);
      });

      test('logs preference change - notifications', () async {
        final result = await analytics.logUserPreferenceChanged('notifications_enabled', false);
        expect(result, isNotNull);
      });

      test('logs preference change - board style', () async {
        final result = await analytics.logUserPreferenceChanged('board_style', 'wood');
        expect(result, isNotNull);
      });

      test('logs preference change - piece set', () async {
        final result = await analytics.logUserPreferenceChanged('piece_set', 'merida');
        expect(result, isNotNull);
      });
    });

    group('Puzzle Selection Logging', () {
      test('logs puzzle selected - beginner', () async {
        final result = await analytics.logPuzzleSelected('puzzle_010', 'beginner');
        expect(result, isNotNull);
      });

      test('logs puzzle selected - intermediate', () async {
        final result = await analytics.logPuzzleSelected('puzzle_011', 'intermediate');
        expect(result, isNotNull);
      });

      test('logs puzzle selected - advanced', () async {
        final result = await analytics.logPuzzleSelected('puzzle_012', 'advanced');
        expect(result, isNotNull);
      });

      test('logs puzzle selected - expert', () async {
        final result = await analytics.logPuzzleSelected('puzzle_013', 'expert');
        expect(result, isNotNull);
      });
    });

    group('Event Parameter Validation', () {
      test('handles parameters with special characters', () async {
        final params = {'message': 'Game over! You won! 🎉'};
        final result = await analytics.logEvent('game_won', parameters: params);
        expect(result, isNotNull);
      });

      test('handles parameters with very long strings', () async {
        final longString = 'a' * 1000;
        final params = {'description': longString};
        final result = await analytics.logEvent('long_text', parameters: params);
        expect(result, isNotNull);
      });

      test('handles parameters with negative numbers', () async {
        final params = {'temperature': -5, 'depth': -2};
        final result = await analytics.logEvent('ai_analysis', parameters: params);
        expect(result, isNotNull);
      });

      test('handles parameters with decimal numbers', () async {
        final params = {'accuracy': 95.5, 'time': 12.34};
        final result = await analytics.logEvent('performance', parameters: params);
        expect(result, isNotNull);
      });

      test('handles parameters with lists', () async {
        final params = {
          'moves': [1, 2, 3, 4, 5],
          'tags': ['tactical', 'endgame']
        };
        final result = await analytics.logEvent('complex_event', parameters: params);
        expect(result, isNotNull);
      });
    });

    group('Event Naming Conventions', () {
      test('logs events with underscore naming', () async {
        final result = await analytics.logEvent('puzzle_solved_expert');
        expect(result, isNotNull);
      });

      test('logs events with camelCase naming', () async {
        final result = await analytics.logEvent('premiumUserSubscribed');
        expect(result, isNotNull);
      });

      test('logs standard Firebase event names', () async {
        final result = await analytics.logEvent('purchase');
        expect(result, isNotNull);
      });

      test('logs custom event names', () async {
        final result = await analytics.logEvent('custom_app_event_123');
        expect(result, isNotNull);
      });
    });

    group('Screen View Naming', () {
      test('logs screen with standard naming', () async {
        final result = await analytics.logScreenView('main_screen', 'MainScreen');
        expect(result, isNotNull);
      });

      test('logs screen with feature naming', () async {
        final result = await analytics.logScreenView('puzzle_library', 'PuzzleLibrary');
        expect(result, isNotNull);
      });

      test('logs modal/dialog as screen', () async {
        final result = await analytics.logScreenView('settings_dialog', 'SettingsDialog');
        expect(result, isNotNull);
      });
    });

    group('Integration - User Journey', () {
      test('logs complete user session', () async {
        // User opens app
        await analytics.logScreenView('splash_screen', 'SplashScreen');

        // User navigates to home
        await analytics.logScreenView('home_screen', 'HomeScreen');

        // User plays a puzzle
        await analytics.logPuzzleSelected('puzzle_100', 'intermediate');
        await analytics.logPuzzleSolved('puzzle_100', 'intermediate', 45000);

        // User plays a game
        await analytics.logGameCompleted(
          gameId: 'game_001',
          gameType: 'online_pvp',
          duration: 1200000,
          won: true,
          moveCount: 50,
          ratingBefore: 1500,
          ratingAfter: 1550,
          result: 'checkmate',
        );

        // User navigates to settings
        await analytics.logScreenView('settings_screen', 'SettingsScreen');
        await analytics.logUserPreferenceChanged('theme', 'dark');
      });

      test('logs premium conversion flow', () async {
        // User views home
        await analytics.logScreenView('home_screen', 'HomeScreen');

        // User attempts premium feature
        await analytics.logEvent('premium_feature_attempted', parameters: {
          'feature': 'unlimited_puzzles'
        });

        // User views paywall
        await analytics.logScreenView('premium_paywall', 'PremiumPaywall');

        // User makes purchase
        await analytics.logEvent('purchase', parameters: {
          'item_id': 'premium_monthly',
          'value': 4.99,
          'currency': 'USD'
        });

        // User accesses premium feature
        await analytics.logEvent('premium_feature_accessed', parameters: {
          'feature': 'unlimited_puzzles',
          'subscription_type': 'premium'
        });
      });

      test('logs game progression', () async {
        for (int i = 1; i <= 5; i++) {
          await analytics.logGameCompleted(
            gameId: 'game_$i',
            gameType: 'online_pvp',
            duration: 1200000,
            won: i % 2 == 0, // Every other game is a win
            moveCount: 30 + (i * 5),
            ratingBefore: 1500 + (i * 10),
            ratingAfter: 1505 + (i * 10),
            result: i % 2 == 0 ? 'checkmate' : 'resigned',
          );
        }
      });

      test('logs learning path', () async {
        final difficulties = ['beginner', 'intermediate', 'advanced', 'expert'];

        for (int i = 1; i <= 4; i++) {
          final difficulty = difficulties[i - 1];
          await analytics.logPuzzleSelected('puzzle_$i', difficulty);
          await analytics.logPuzzleSolved('puzzle_$i', difficulty, 30000 + (i * 15000));
        }
      });
    });
  });
}
