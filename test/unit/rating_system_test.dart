import 'package:flutter_test/flutter_test.dart';
import 'dart:math';

/// Rating System Unit Tests
void main() {
  group('Rating System Tests', () {
    // ELO Rating Calculation
    group('ELO Calculation', () {
      const kFactor = 32;
      const dConstant = 400;

      /// Calculate expected score (win probability)
      double calculateExpectedScore(int playerRating, int opponentRating) {
        final ratingDiff = opponentRating - playerRating;
        return 1 / (1 + pow(10, ratingDiff / dConstant) as num);
      }

      /// Calculate rating change
      int calculateRatingChange({
        required int playerRating,
        required int opponentRating,
        required double actualScore, // 1.0 for win, 0.5 for draw, 0.0 for loss
      }) {
        final expectedScore = calculateExpectedScore(playerRating, opponentRating);
        final change = (kFactor * (actualScore - expectedScore)).round();
        return change;
      }

      test('Win against equal-rated opponent', () {
        const playerRating = 1600;
        const opponentRating = 1600;

        final change = calculateRatingChange(
          playerRating: playerRating,
          opponentRating: opponentRating,
          actualScore: 1.0,
        );

        expect(change, inInclusiveRange(15, 17));
      });

      test('Loss against equal-rated opponent', () {
        const playerRating = 1600;
        const opponentRating = 1600;

        final change = calculateRatingChange(
          playerRating: playerRating,
          opponentRating: opponentRating,
          actualScore: 0.0,
        );

        expect(change, inInclusiveRange(-17, -15));
      });

      test('Draw against equal-rated opponent', () {
        const playerRating = 1600;
        const opponentRating = 1600;

        final change = calculateRatingChange(
          playerRating: playerRating,
          opponentRating: opponentRating,
          actualScore: 0.5,
        );

        expect(change, 0);
      });

      test('Upset bonus: Lower-rated player wins', () {
        const lowerRating = 1400;
        const higherRating = 1800;

        final lowerRatingChange = calculateRatingChange(
          playerRating: lowerRating,
          opponentRating: higherRating,
          actualScore: 1.0,
        );

        expect(lowerRatingChange, greaterThan(16));
      });

      test('Zero-sum property: Changes sum to zero', () {
        const rating1 = 1600;
        const rating2 = 1700;

        final change1 = calculateRatingChange(
          playerRating: rating1,
          opponentRating: rating2,
          actualScore: 1.0,
        );

        final change2 = calculateRatingChange(
          playerRating: rating2,
          opponentRating: rating1,
          actualScore: 0.0,
        );

        expect((change1 + change2).abs(), lessThan(2));
      });
    });

    // Rating Categories
    group('Rating Categories', () {
      String getRatingCategory(int rating) {
        if (rating < 1000) return 'Beginner';
        if (rating < 1200) return 'Novice';
        if (rating < 1400) return 'Intermediate';
        if (rating < 1600) return 'Advanced';
        if (rating < 1800) return 'Expert';
        if (rating < 2000) return 'Master';
        if (rating < 2200) return 'International Master';
        return 'Grandmaster';
      }

      test('Beginner category', () {
        expect(getRatingCategory(800), 'Beginner');
      });

      test('Novice category', () {
        expect(getRatingCategory(1000), 'Novice');
      });

      test('Expert category', () {
        expect(getRatingCategory(1600), 'Expert');
      });

      test('Grandmaster category', () {
        expect(getRatingCategory(2200), 'Grandmaster');
      });
    });

    // Win Rate Calculations
    group('Win Rate Calculations', () {
      test('100% win rate', () {
        const wins = 10;
        const total = 10;
        final winRate = (wins / total * 100);

        expect(winRate, 100.0);
      });

      test('50% win rate', () {
        const wins = 5;
        const total = 10;
        final winRate = (wins / total * 100);

        expect(winRate, 50.0);
      });

      test('0% win rate', () {
        const wins = 0;
        const total = 10;
        final winRate = (wins / total * 100);

        expect(winRate, 0.0);
      });
    });
  });
}
