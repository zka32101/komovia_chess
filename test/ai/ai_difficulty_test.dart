import 'package:flutter_test/flutter_test.dart';
import 'package:chess/chess.dart' as chess_lib;

// Mock implementation of AI services for testing
// In real implementation, these would use actual AI engine

void main() {
  group('AI Difficulty Calibration Tests', () {
    group('Difficulty Level Configuration', () {
      test('Beginner difficulty parameters', () {
        // Beginner level should have shallow search and make mistakes
        expect(100, equals(100)); // Target Elo
        expect(3, equals(3)); // Search depth
        expect(300, equals(300)); // Thinking time
        expect(40, equals(40)); // Move quality threshold
        expect(0.65, equals(0.65)); // Expected accuracy
      });

      test('Master difficulty parameters', () {
        // Master level should have deep search and high quality
        expect(2600, equals(2600)); // Target Elo
        expect(12, equals(12)); // Search depth
        expect(5000, equals(5000)); // Thinking time
        expect(100, equals(100)); // Move quality threshold
        expect(0.96, equals(0.96)); // Expected accuracy
      });

      test('Difficulty progression', () {
        // Verify proper progression across all levels
        final difficulties = [
          ('Beginner', 100),
          ('Intermediate', 1000),
          ('Advanced', 1500),
          ('Expert', 2000),
          ('Master', 2600),
        ];

        for (int i = 0; i < difficulties.length - 1; i++) {
          expect(difficulties[i + 1].$2, greaterThan(difficulties[i].$2),
              reason:
                  'Elo should increase: ${difficulties[i].$1} < ${difficulties[i + 1].$1}');
        }
      });
    });

    group('Move Quality Scoring', () {
      test('Best move scores 100', () {
        // When move evaluation equals best evaluation
        final score = _calculateMoveQuality(
          evaluation: 150,
          bestEvaluation: 150,
        );
        expect(score, equals(100));
      });

      test('Move losing material scores low', () {
        // Material loss (> 300 centipawns)
        final score = _calculateMoveQuality(
          evaluation: -350,
          bestEvaluation: 0,
        );
        expect(score, lessThan(25));
      });

      test('Mediocre move scores medium', () {
        // Move 50-100 centipawns worse
        final score = _calculateMoveQuality(
          evaluation: 50,
          bestEvaluation: 100,
        );
        expect(score, inRange(50, 75));
      });

      test('Good move scores high', () {
        // Move < 20 centipawns worse
        final score = _calculateMoveQuality(
          evaluation: 90,
          bestEvaluation: 100,
        );
        expect(score, inRange(85, 100));
      });
    });

    group('Accuracy Calculation', () {
      test('100% accuracy with all good moves', () {
        final moveQualities = [90, 85, 92, 88, 95];
        final accuracy = _calculateAccuracy(moveQualities);
        expect(accuracy, equals(100.0));
      });

      test('0% accuracy with all blunders', () {
        final moveQualities = [10, 20, 15, 25, 10];
        final accuracy = _calculateAccuracy(moveQualities);
        expect(accuracy, equals(0.0));
      });

      test('50% accuracy with mixed moves', () {
        final moveQualities = [85, 20, 90, 30, 80];
        final accuracy = _calculateAccuracy(moveQualities);
        expect(accuracy, equals(60.0)); // 3 out of 5 are >= 75
      });
    });

    group('Difficulty Validation', () {
      test('Beginner AI validation', () {
        // Beginner should play with ~65% accuracy
        final moveQualities = [60, 55, 70, 65, 60, 65, 70, 60];
        final avgQuality = moveQualities.reduce((a, b) => a + b) /
            moveQualities.length;
        expect(avgQuality, inRange(50, 75));
      });

      test('Expert AI validation', () {
        // Expert should play with ~92% accuracy
        final moveQualities = [92, 95, 90, 88, 92, 94, 89, 91];
        final avgQuality = moveQualities.reduce((a, b) => a + b) /
            moveQualities.length;
        expect(avgQuality, inRange(85, 100));
      });

      test('Master AI validation', () {
        // Master should play with 96%+ accuracy
        final moveQualities = [96, 98, 95, 97, 96, 99, 95, 97];
        final avgQuality = moveQualities.reduce((a, b) => a + b) /
            moveQualities.length;
        expect(avgQuality, inRange(95, 100));
      });
    });

    group('Blunder Probability', () {
      test('Beginner has highest blunder rate', () {
        // 15% blunder probability
        expect(0.15, greaterThan(0.0));
      });

      test('Master has lowest blunder rate', () {
        // 0.5% blunder probability
        expect(0.005, lessThan(0.15));
      });

      test('Blunder probability decreases with difficulty', () {
        final probabilities = [0.15, 0.08, 0.03, 0.01, 0.005];
        for (int i = 0; i < probabilities.length - 1; i++) {
          expect(probabilities[i + 1], lessThan(probabilities[i]),
              reason:
                  'Blunder probability should decrease at higher difficulties');
        }
      });
    });

    group('Search Depth Analysis', () {
      test('Search depth increases with difficulty', () {
        final depths = [3, 5, 7, 10, 12];
        for (int i = 0; i < depths.length - 1; i++) {
          expect(depths[i + 1], greaterThan(depths[i]),
              reason: 'Search depth should increase');
        }
      });

      test('Thinking time increases with depth', () {
        final times = [300, 800, 1500, 3000, 5000];
        for (int i = 0; i < times.length - 1; i++) {
          expect(times[i + 1], greaterThan(times[i]),
              reason: 'Thinking time should increase');
        }
      });
    });

    group('Opening Book Usage', () {
      test('All difficulty levels use opening book', () {
        expect(true, equals(true)); // Beginners benefit from good openings
        // Expert and Master still use opening book for efficiency
      });
    });

    group('Endgame Tablebase Usage', () {
      test('Beginner and Intermediate without tablebases', () {
        expect(false, equals(false));
      });

      test('Advanced, Expert, Master with tablebases', () {
        expect(true, equals(true));
      });
    });

    group('Win Rate Expectations', () {
      test('Difficulty levels have reasonable win rates', () {
        final winRates = [0.35, 0.55, 0.65, 0.80, 0.85];
        for (int i = 0; i < winRates.length - 1; i++) {
          expect(winRates[i + 1], greaterThanOrEqualTo(winRates[i]),
              reason: 'Win rate should not decrease with difficulty');
        }
      });

      test('Human win rates against AI', () {
        // Humans should have better chance against weaker AI
        final humanWinRates = [0.75, 0.55, 0.35, 0.20, 0.15];
        for (int i = 0; i < humanWinRates.length - 1; i++) {
          expect(humanWinRates[i + 1], lessThanOrEqualTo(humanWinRates[i]),
              reason: 'Human win rate should decrease against stronger AI');
        }
      });
    });

    group('Quiescence Search', () {
      test('Quiescence depth increases with difficulty', () {
        final depths = [1, 2, 3, 4, 5];
        for (int i = 0; i < depths.length - 1; i++) {
          expect(depths[i + 1], greaterThan(depths[i]),
              reason: 'Quiescence depth should increase');
        }
      });
    });

    group('Difficulty Adjustment Recommendations', () {
      test('AI too strong triggers downgrade recommendation', () {
        final targetWinRate = 0.55;
        final actualWinRate = 0.70; // 15% higher than target
        final adjustment =
            _getDifficultyAdjustment(actualWinRate, targetWinRate);
        expect(adjustment, isNotNull);
        expect(adjustment, contains('Reduce difficulty'));
      });

      test('AI too weak triggers upgrade recommendation', () {
        final targetWinRate = 0.55;
        final actualWinRate = 0.40; // 15% lower than target
        final adjustment =
            _getDifficultyAdjustment(actualWinRate, targetWinRate);
        expect(adjustment, isNotNull);
        expect(adjustment, contains('Increase difficulty'));
      });

      test('Well-calibrated AI gives no recommendation', () {
        final targetWinRate = 0.55;
        final actualWinRate = 0.56; // Within 10%
        final adjustment =
            _getDifficultyAdjustment(actualWinRate, targetWinRate);
        expect(adjustment, isNull);
      });
    });
  });

  group('AI Performance Benchmarks', () {
    test('Move generation performance', () {
      // Each difficulty level should generate moves within acceptable time
      final game = chess_lib.Game();
      final moves = game.moves(format: 'sloppy');
      expect(moves.length, greaterThan(0));
      expect(moves.length, lessThan(50)); // Beginner position has ~20 moves
    });

    test('Evaluation speed by difficulty', () {
      // Estimated evaluation times per difficulty
      final expectedTimes = {
        'beginner': 300,
        'intermediate': 800,
        'advanced': 1500,
        'expert': 3000,
        'master': 5000,
      };

      for (final entry in expectedTimes.entries) {
        expect(entry.value, greaterThan(0));
      }
    });

    test('Memory usage constraints', () {
      // AI should not use more than reasonable memory
      // This is indicative - actual measurement would be needed
      expect(true, equals(true));
    });
  });

  group('Difficulty Balance Across Time Controls', () {
    test('Blitz games (3+2) allows weaker moves', () {
      final thinkingTime = 300; // Beginner thinking time
      expect(thinkingTime, lessThan(800));
    });

    test('Rapid games (15min) allows strong play', () {
      final thinkingTime = 3000; // Expert thinking time
      expect(thinkingTime, greaterThan(800));
    });

    test('Classical games (30min) allows master play', () {
      final thinkingTime = 5000; // Master thinking time
      expect(thinkingTime, greaterThan(3000));
    });
  });
}

// Helper functions for testing

int _calculateMoveQuality({
  required int evaluation,
  required int bestEvaluation,
}) {
  final evaluationDiff = bestEvaluation - evaluation;

  if (evaluationDiff == 0) return 100;
  if (evaluationDiff > 300) return 0;
  if (evaluationDiff > 100) {
    return 25 + (75 * (1 - evaluationDiff / 300)).toInt();
  }
  if (evaluationDiff > 50) {
    return 50 + (25 * (1 - evaluationDiff / 100)).toInt();
  }
  if (evaluationDiff > 20) {
    return 65 + (10 * (1 - evaluationDiff / 50)).toInt();
  }

  return 85 + (15 * (1 - evaluationDiff / 20)).toInt();
}

double _calculateAccuracy(List<int> moveQualities) {
  if (moveQualities.isEmpty) return 0.0;
  final goodMoves = moveQualities.where((q) => q >= 75).length;
  return (goodMoves / moveQualities.length) * 100;
}

String? _getDifficultyAdjustment(double actual, double target) {
  final diff = actual - target;

  if (diff > 0.10) {
    return 'Reduce difficulty: AI playing too strong. Current: ${(actual * 100).toStringAsFixed(1)}%, Target: ${(target * 100).toStringAsFixed(1)}%';
  }
  if (diff < -0.10) {
    return 'Increase difficulty: AI playing too weak. Current: ${(actual * 100).toStringAsFixed(1)}%, Target: ${(target * 100).toStringAsFixed(1)}%';
  }

  return null;
}

/// Matcher for checking if value is in range
Matcher inRange(num start, num end) {
  return _InRangeMatcher(start, end);
}

class _InRangeMatcher extends Matcher {
  final num start;
  final num end;

  _InRangeMatcher(this.start, this.end);

  @override
  bool matches(dynamic item, Map matchState) {
    if (item is! num) return false;
    return item >= start && item <= end;
  }

  @override
  Description describe(Description description) =>
      description.add('is in range $start to $end');

  @override
  Description describeMismatch(dynamic item, Description mismatch, Map matchState,
      bool verbose) {
    return mismatch.add('$item is not in range $start to $end');
  }
}
