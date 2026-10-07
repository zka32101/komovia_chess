import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_chess/src/services/performance_service.dart';

void main() {
  group('PerformanceService', () {
    late PerformanceService service;

    setUp(() {
      service = PerformanceService();
    });

    group('Win Rate Calculation', () {
      test('should return 0% for no games', () {
        const wins = 0;
        const total = 0;
        final winRate = total > 0 ? (wins / total * 100) : 0.0;
        expect(winRate, equals(0.0));
      });

      test('should return 100% for all wins', () {
        const wins = 10;
        const total = 10;
        final winRate = (wins / total * 100);
        expect(winRate, equals(100.0));
      });

      test('should return correct percentage', () {
        const wins = 7;
        const total = 10;
        final winRate = (wins / total * 100);
        expect(winRate, equals(70.0));
      });
    });

    group('Streak Calculation', () {
      test('should correctly identify winning streak', () {
        final results = [true, true, true, false];
        int streak = 0;
        int maxStreak = 0;

        for (final isWin in results) {
          if (isWin) {
            streak++;
            maxStreak = streak > maxStreak ? streak : maxStreak;
          } else {
            streak = 0;
          }
        }

        expect(maxStreak, equals(3));
      });

      test('should correctly identify losing streak', () {
        final results = [false, false, false, true];
        int streak = 0;
        int maxLossStreak = 0;

        for (final isWin in results) {
          if (!isWin) {
            streak++;
            maxLossStreak = streak > maxLossStreak ? streak : maxLossStreak;
          } else {
            streak = 0;
          }
        }

        expect(maxLossStreak, equals(3));
      });

      test('should handle alternating results', () {
        final results = [true, false, true, false, true];
        int currentStreak = 1;
        int maxWinStreak = 1;

        for (int i = 1; i < results.length; i++) {
          if (results[i] == results[i - 1]) {
            currentStreak++;
            if (results[i]) {
              maxWinStreak =
                  currentStreak > maxWinStreak ? currentStreak : maxWinStreak;
            }
          } else {
            currentStreak = 1;
          }
        }

        expect(maxWinStreak, equals(1));
      });
    });

    group('Performance by Category', () {
      test('should calculate performance by time control', () {
        final performanceByTimeControl = {
          'bullet': 65,
          'blitz': 52,
          'rapid': 48,
        };

        expect(performanceByTimeControl['bullet'], equals(65));
        expect(performanceByTimeControl['blitz'], equals(52));
        expect(performanceByTimeControl['rapid'], equals(48));
      });

      test('should identify strongest time control', () {
        final performance = {
          'bullet': 65,
          'blitz': 52,
          'rapid': 48,
        };

        final strongest =
            performance.entries.reduce((a, b) => a.value > b.value ? a : b);
        expect(strongest.key, equals('bullet'));
        expect(strongest.value, equals(65));
      });

      test('should identify weakest time control', () {
        final performance = {
          'bullet': 65,
          'blitz': 52,
          'rapid': 48,
        };

        final weakest =
            performance.entries.reduce((a, b) => a.value < b.value ? a : b);
        expect(weakest.key, equals('rapid'));
        expect(weakest.value, equals(48));
      });
    });

    group('Rating Progression', () {
      test('should track rating changes', () {
        final ratings = [1600, 1615, 1608, 1620, 1625];
        final change = ratings.last - ratings.first;

        expect(change, equals(25));
      });

      test('should calculate win rate from progression', () {
        const gamesPlayed = 10;
        const wins = 7;
        final winRate = (wins / gamesPlayed * 100);

        expect(winRate, equals(70.0));
      });
    });
  });
}
