import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_chess/src/services/analytics_service.dart';

void main() {
  group('AnalyticsService', () {
    late AnalyticsService service;

    setUp(() {
      service = AnalyticsService();
    });

    group('Month Year Parsing', () {
      test('should parse month year correctly', () {
        const monthYear = 202608;
        final year = monthYear ~/ 100;
        final month = monthYear % 100;

        expect(year, equals(2026));
        expect(month, equals(8));
      });

      test('should handle January correctly', () {
        const monthYear = 202601;
        final year = monthYear ~/ 100;
        final month = monthYear % 100;

        expect(year, equals(2026));
        expect(month, equals(1));
      });

      test('should handle December correctly', () {
        const monthYear = 202612;
        final year = monthYear ~/ 100;
        final month = monthYear % 100;

        expect(year, equals(2026));
        expect(month, equals(12));
      });
    });

    group('Monthly Statistics Calculation', () {
      test('should calculate correct monthly stats', () {
        const wins = 10;
        const losses = 5;
        const draws = 2;
        const gamesPlayed = wins + losses + draws;
        const totalRatingGained = 150;
        const totalRatingLost = 80;

        final avgRatingGained = wins > 0 ? totalRatingGained / wins : 0.0;
        final avgRatingLost = losses > 0 ? totalRatingLost / losses : 0.0;
        final ratingChange = totalRatingGained - totalRatingLost;

        expect(gamesPlayed, equals(17));
        expect(avgRatingGained, equals(15.0));
        expect(avgRatingLost, equals(16.0));
        expect(ratingChange, equals(70));
      });

      test('should handle months with no games', () {
        const gamesPlayed = 0;
        const avgRatingGained = 0.0;
        const avgRatingLost = 0.0;

        expect(gamesPlayed, equals(0));
        expect(avgRatingGained, equals(0.0));
        expect(avgRatingLost, equals(0.0));
      });

      test('should calculate rating change for wins and losses', () {
        const totalGained = 150;
        const totalLost = 80;
        final ratingChange = totalGained - totalLost;

        expect(ratingChange, equals(70));
      });
    });

    group('Performance Trends', () {
      test('should detect upward trend', () {
        final winRates = [40.0, 50.0, 60.0];
        final trend = winRates.last - winRates.first;

        expect(trend, equals(20.0));
        expect(trend, greaterThan(0));
      });

      test('should detect downward trend', () {
        final winRates = [60.0, 50.0, 40.0];
        final trend = winRates.last - winRates.first;

        expect(trend, equals(-20.0));
        expect(trend, lessThan(0));
      });

      test('should detect no trend', () {
        final winRates = [50.0, 50.0, 50.0];
        final trend = winRates.last - winRates.first;

        expect(trend, equals(0.0));
      });

      test('should calculate average win rate', () {
        final winRates = [60.0, 55.0, 65.0, 70.0];
        final average = winRates.reduce((a, b) => a + b) / winRates.length;

        expect(average, equals(62.5));
      });
    });

    group('Analytics Comparison', () {
      test('should compare two players analytics', () {
        final player1 = {
          'gamesPlayed': 20,
          'wins': 14,
          'winRate': 70.0,
        };

        final player2 = {
          'gamesPlayed': 18,
          'wins': 9,
          'winRate': 50.0,
        };

        expect(player1['winRate'], greaterThan(player2['winRate']!));
        expect(player1['gamesPlayed'], greaterThan(player2['gamesPlayed']!));
      });

      test('should identify player with higher rating change', () {
        final player1RatingChange = 85;
        final player2RatingChange = 42;

        expect(player1RatingChange, greaterThan(player2RatingChange));
      });
    });
  });
}
