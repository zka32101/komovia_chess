import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_chess/src/services/rating_calculation_service.dart';

void main() {
  group('RatingCalculationService', () {
    group('calculateNewRating', () {
      test('win against equal opponent increases rating', () {
        const playerRating = 1600;
        const opponentRating = 1600;
        const result = 1.0; // Win

        final newRating = RatingCalculationService.calculateNewRating(
          playerRating,
          opponentRating,
          result,
        );

        expect(newRating, greaterThan(playerRating));
        expect(newRating, 1616); // +16 with K=32
      });

      test('loss against equal opponent decreases rating', () {
        const playerRating = 1600;
        const opponentRating = 1600;
        const result = 0.0; // Loss

        final newRating = RatingCalculationService.calculateNewRating(
          playerRating,
          opponentRating,
          result,
        );

        expect(newRating, lessThan(playerRating));
        expect(newRating, 1584); // -16 with K=32
      });

      test('draw against equal opponent minimal change', () {
        const playerRating = 1600;
        const opponentRating = 1600;
        const result = 0.5; // Draw

        final newRating = RatingCalculationService.calculateNewRating(
          playerRating,
          opponentRating,
          result,
        );

        expect(newRating, equals(playerRating)); // No change for equal players
      });

      test('win against stronger opponent large rating gain', () {
        const playerRating = 1600;
        const opponentRating = 1800;
        const result = 1.0; // Win

        final newRating = RatingCalculationService.calculateNewRating(
          playerRating,
          opponentRating,
          result,
        );

        expect(newRating, greaterThan(playerRating));
        expect(newRating, greaterThan(1616)); // More than typical win
      });

      test('loss against weaker opponent large rating loss', () {
        const playerRating = 1600;
        const opponentRating = 1400;
        const result = 0.0; // Loss

        final newRating = RatingCalculationService.calculateNewRating(
          playerRating,
          opponentRating,
          result,
        );

        expect(newRating, lessThan(playerRating));
        expect(newRating, lessThan(1584)); // More loss than typical
      });

      test('rating clamped to minimum value', () {
        const playerRating = 101;
        const opponentRating = 3000;
        const result = 0.0; // Loss

        final newRating = RatingCalculationService.calculateNewRating(
          playerRating,
          opponentRating,
          result,
        );

        expect(newRating, greaterThanOrEqualTo(100));
      });

      test('rating clamped to maximum value', () {
        const playerRating = 2999;
        const opponentRating = 100;
        const result = 1.0; // Win

        final newRating = RatingCalculationService.calculateNewRating(
          playerRating,
          opponentRating,
          result,
        );

        expect(newRating, lessThanOrEqualTo(3000));
      });

      test('rejects invalid player rating', () {
        expect(
          () => RatingCalculationService.calculateNewRating(99, 1600, 1.0),
          throwsA(isA<RatingCalculationException>()),
        );
        expect(
          () => RatingCalculationService.calculateNewRating(3001, 1600, 1.0),
          throwsA(isA<RatingCalculationException>()),
        );
      });

      test('rejects invalid opponent rating', () {
        expect(
          () => RatingCalculationService.calculateNewRating(1600, 99, 1.0),
          throwsA(isA<RatingCalculationException>()),
        );
        expect(
          () => RatingCalculationService.calculateNewRating(1600, 3001, 1.0),
          throwsA(isA<RatingCalculationException>()),
        );
      });

      test('rejects invalid result', () {
        expect(
          () => RatingCalculationService.calculateNewRating(1600, 1600, -0.1),
          throwsA(isA<RatingCalculationException>()),
        );
        expect(
          () => RatingCalculationService.calculateNewRating(1600, 1600, 1.1),
          throwsA(isA<RatingCalculationException>()),
        );
      });
    });

    group('calculateExpectedScore', () {
      test('equal players have 0.5 expected score', () {
        const playerRating = 1600;
        const opponentRating = 1600;

        final expectedScore =
            RatingCalculationService.calculateExpectedScore(playerRating, opponentRating);

        expect(expectedScore, closeTo(0.5, 0.01));
      });

      test('stronger player has higher expected score', () {
        const playerRating = 1800;
        const opponentRating = 1600;

        final expectedScore =
            RatingCalculationService.calculateExpectedScore(playerRating, opponentRating);

        expect(expectedScore, greaterThan(0.5));
      });

      test('weaker player has lower expected score', () {
        const playerRating = 1400;
        const opponentRating = 1600;

        final expectedScore =
            RatingCalculationService.calculateExpectedScore(playerRating, opponentRating);

        expect(expectedScore, lessThan(0.5));
      });

      test('large rating difference gives extreme expectations', () {
        const playerRating = 2200;
        const opponentRating = 1200;

        final expectedScore =
            RatingCalculationService.calculateExpectedScore(playerRating, opponentRating);

        expect(expectedScore, greaterThan(0.9)); // Expected to win heavily
      });
    });

    group('getKFactor', () {
      test('developing player (<1400) has K=40', () {
        expect(RatingCalculationService.getKFactor(1000), equals(40));
        expect(RatingCalculationService.getKFactor(1399), equals(40));
      });

      test('standard player (1400-1800) has K=32', () {
        expect(RatingCalculationService.getKFactor(1400), equals(32));
        expect(RatingCalculationService.getKFactor(1600), equals(32));
        expect(RatingCalculationService.getKFactor(1800), equals(32));
      });

      test('expert player (>1800) has K=24', () {
        expect(RatingCalculationService.getKFactor(1801), equals(24));
        expect(RatingCalculationService.getKFactor(2200), equals(24));
      });
    });

    group('getRatingTier', () {
      test('Beginner tier (<1000)', () {
        expect(RatingCalculationService.getRatingTier(500), equals('Beginner'));
        expect(RatingCalculationService.getRatingTier(999), equals('Beginner'));
      });

      test('Intermediate tier (1000-1399)', () {
        expect(RatingCalculationService.getRatingTier(1000), equals('Intermediate'));
        expect(RatingCalculationService.getRatingTier(1200), equals('Intermediate'));
        expect(RatingCalculationService.getRatingTier(1399), equals('Intermediate'));
      });

      test('Advanced tier (1400-1799)', () {
        expect(RatingCalculationService.getRatingTier(1400), equals('Advanced'));
        expect(RatingCalculationService.getRatingTier(1600), equals('Advanced'));
        expect(RatingCalculationService.getRatingTier(1799), equals('Advanced'));
      });

      test('Expert tier (1800-1999)', () {
        expect(RatingCalculationService.getRatingTier(1800), equals('Expert'));
        expect(RatingCalculationService.getRatingTier(1900), equals('Expert'));
        expect(RatingCalculationService.getRatingTier(1999), equals('Expert'));
      });

      test('Master tier (2000-2199)', () {
        expect(RatingCalculationService.getRatingTier(2000), equals('Master'));
        expect(RatingCalculationService.getRatingTier(2100), equals('Master'));
        expect(RatingCalculationService.getRatingTier(2199), equals('Master'));
      });

      test('Grandmaster tier (2200+)', () {
        expect(RatingCalculationService.getRatingTier(2200), equals('Grandmaster'));
        expect(RatingCalculationService.getRatingTier(2500), equals('Grandmaster'));
      });
    });

    group('getRatingTierEmoji', () {
      test('Beginner has bronze emoji', () {
        expect(RatingCalculationService.getRatingTierEmoji(999), equals('🥉'));
      });

      test('Intermediate has silver emoji', () {
        expect(RatingCalculationService.getRatingTierEmoji(1200), equals('🥈'));
      });

      test('Advanced has gold emoji', () {
        expect(RatingCalculationService.getRatingTierEmoji(1600), equals('🥇'));
      });

      test('Expert has trophy emoji', () {
        expect(RatingCalculationService.getRatingTierEmoji(1900), equals('🏆'));
      });

      test('Master has crown emoji', () {
        expect(RatingCalculationService.getRatingTierEmoji(2100), equals('👑'));
      });

      test('Grandmaster has king emoji', () {
        expect(RatingCalculationService.getRatingTierEmoji(2300), equals('♔'));
      });
    });

    group('isValidRating', () {
      test('valid ratings return true', () {
        expect(RatingCalculationService.isValidRating(100), isTrue);
        expect(RatingCalculationService.isValidRating(1600), isTrue);
        expect(RatingCalculationService.isValidRating(3000), isTrue);
      });

      test('invalid ratings return false', () {
        expect(RatingCalculationService.isValidRating(99), isFalse);
        expect(RatingCalculationService.isValidRating(3001), isFalse);
      });
    });

    group('calculateRatingDelta', () {
      test('delta is correct for win against equal opponent', () {
        const playerRating = 1600;
        const opponentRating = 1600;
        const result = 1.0; // Win

        final delta = RatingCalculationService.calculateRatingDelta(
          playerRating,
          opponentRating,
          result,
        );

        expect(delta, equals(16)); // +16 with K=32
      });

      test('delta is correct for loss against equal opponent', () {
        const playerRating = 1600;
        const opponentRating = 1600;
        const result = 0.0; // Loss

        final delta = RatingCalculationService.calculateRatingDelta(
          playerRating,
          opponentRating,
          result,
        );

        expect(delta, equals(-16)); // -16 with K=32
      });

      test('delta is zero for draw against equal opponent', () {
        const playerRating = 1600;
        const opponentRating = 1600;
        const result = 0.5; // Draw

        final delta = RatingCalculationService.calculateRatingDelta(
          playerRating,
          opponentRating,
          result,
        );

        expect(delta, equals(0));
      });
    });

    group('calculateBothPlayersRatingDelta', () {
      test('white win results correct for both players', () {
        const whiteRating = 1600;
        const blackRating = 1600;

        final deltas =
            RatingCalculationService.calculateBothPlayersRatingDelta(
          whiteRating,
          blackRating,
          'white_win',
        );

        expect(deltas['whiteRatingDelta'], equals(16));
        expect(deltas['blackRatingDelta'], equals(-16));
      });

      test('black win results correct for both players', () {
        const whiteRating = 1600;
        const blackRating = 1600;

        final deltas =
            RatingCalculationService.calculateBothPlayersRatingDelta(
          whiteRating,
          blackRating,
          'black_win',
        );

        expect(deltas['whiteRatingDelta'], equals(-16));
        expect(deltas['blackRatingDelta'], equals(16));
      });

      test('draw results zero delta for both players', () {
        const whiteRating = 1600;
        const blackRating = 1600;

        final deltas =
            RatingCalculationService.calculateBothPlayersRatingDelta(
          whiteRating,
          blackRating,
          'draw',
        );

        expect(deltas['whiteRatingDelta'], equals(0));
        expect(deltas['blackRatingDelta'], equals(0));
      });

      test('rejects invalid result', () {
        expect(
          () => RatingCalculationService.calculateBothPlayersRatingDelta(
            1600,
            1600,
            'invalid',
          ),
          throwsA(isA<RatingCalculationException>()),
        );
      });
    });

    group('Integration: K-factor effect on rating volatility', () {
      test('developing players have larger rating swings', () {
        const developerRating = 1200; // Developing (K=40)
        const opponentRating = 1600;

        final winDelta = RatingCalculationService.calculateRatingDelta(
          developerRating,
          opponentRating,
          1.0,
        );
        final lossDelta = RatingCalculationService.calculateRatingDelta(
          developerRating,
          opponentRating,
          0.0,
        );

        expect((winDelta - lossDelta).abs(), greaterThan(32)); // Larger swing
      });

      test('expert players have smaller rating swings', () {
        const expertRating = 2000; // Expert (K=24)
        const opponentRating = 1600;

        final winDelta = RatingCalculationService.calculateRatingDelta(
          expertRating,
          opponentRating,
          1.0,
        );
        final lossDelta = RatingCalculationService.calculateRatingDelta(
          expertRating,
          opponentRating,
          0.0,
        );

        expect((winDelta - lossDelta).abs(), lessThan(40)); // Smaller swing
      });
    });

    group('Edge cases and special scenarios', () {
      test('minimum rating player beating maximum rating player', () {
        const playerRating = 100; // Minimum
        const opponentRating = 3000; // Maximum

        final newRating = RatingCalculationService.calculateNewRating(
          playerRating,
          opponentRating,
          1.0, // Win (highly unlikely but possible)
        );

        expect(newRating, greaterThan(playerRating));
        expect(newRating, lessThanOrEqualTo(3000));
      });

      test('maximum rating player losing to minimum rating player', () {
        const playerRating = 3000; // Maximum
        const opponentRating = 100; // Minimum

        final newRating = RatingCalculationService.calculateNewRating(
          playerRating,
          opponentRating,
          0.0, // Loss (highly unlikely but possible)
        );

        expect(newRating, lessThan(playerRating));
        expect(newRating, greaterThanOrEqualTo(100));
      });

      test('multiple consecutive wins show rating growth', () {
        var currentRating = 1600;
        const opponentRating = 1600;

        for (int i = 0; i < 5; i++) {
          currentRating = RatingCalculationService.calculateNewRating(
            currentRating,
            opponentRating,
            1.0, // Win
          );
        }

        expect(currentRating, greaterThan(1680)); // At least 80+ points gained
      });

      test('multiple consecutive losses show rating decline', () {
        var currentRating = 1600;
        const opponentRating = 1600;

        for (int i = 0; i < 5; i++) {
          currentRating = RatingCalculationService.calculateNewRating(
            currentRating,
            opponentRating,
            0.0, // Loss
          );
        }

        expect(currentRating, lessThan(1520)); // At least 80+ points lost
      });
    });
  });
}
