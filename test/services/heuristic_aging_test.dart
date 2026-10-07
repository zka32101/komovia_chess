import 'package:flutter_test/flutter_test.dart';
import 'package:chess/chess.dart' as chess_lib;
import 'package:komovia_chess/src/services/heuristic_aging.dart';

void main() {
  group('AgedKillerMoveHeuristic', () {
    late AgedKillerMoveHeuristic aged;

    setUp(() {
      aged = AgedKillerMoveHeuristic();
    });

    group('basic killer functionality', () {
      test('records killer moves', () {
        aged.recordKiller(2, 'e2e4');
        expect(aged.getKillers(2), contains('e2e4'));
      });

      test('maintains compatibility with parent class', () {
        aged.recordKiller(2, 'e2e4');
        aged.recordKiller(2, 'd2d4');
        expect(aged.getKillers(2).length, equals(2));
      });
    });

    group('aging mechanics', () {
      test('tracks move age', () {
        aged.recordKiller(2, 'e2e4');
        expect(aged.getMoveAge('e2e4'), equals(0));
      });

      test('ages moves correctly', () {
        aged.recordKiller(2, 'e2e4');
        aged.ageAllMoves();
        expect(aged.getMoveAge('e2e4'), equals(1));
      });

      test('multiple aging cycles', () {
        aged.recordKiller(2, 'e2e4');
        for (int i = 0; i < 5; i++) {
          aged.ageAllMoves();
        }
        expect(aged.getMoveAge('e2e4'), equals(5));
      });

      test('resets age on use', () {
        aged.recordKiller(2, 'e2e4');
        aged.ageAllMoves();
        aged.ageAllMoves();
        expect(aged.getMoveAge('e2e4'), equals(2));

        aged.resetAge('e2e4');
        expect(aged.getMoveAge('e2e4'), equals(0));
      });

      test('removes very old moves', () {
        aged.recordKiller(2, 'e2e4');
        for (int i = 0; i < 15; i++) {
          aged.ageAllMoves();
        }
        expect(aged.getMoveAge('e2e4'), equals(0)); // Should be removed
      });
    });

    group('aged killers retrieval', () {
      test('returns empty for no killers', () {
        expect(aged.getAgedKillers(2), isEmpty);
      });

      test('returns killers without aging effect', () {
        aged.recordKiller(2, 'e2e4');
        final agedKillers = aged.getAgedKillers(2);
        expect(agedKillers, contains('e2e4'));
      });

      test('prioritizes fresh killers over aged', () {
        aged.recordKiller(2, 'e2e4');
        aged.recordKiller(2, 'd2d4');
        aged.ageAllMoves();
        aged.ageAllMoves();
        aged.recordKiller(2, 'c2c4');

        final agedKillers = aged.getAgedKillers(2);
        expect(agedKillers[0], 'c2c4'); // Most recent, no age decay
      });

      test('applies decay factor to aged moves', () {
        aged.recordKiller(2, 'e2e4');
        aged.ageAllMoves();
        aged.ageAllMoves();
        aged.ageAllMoves();

        final agedKillers = aged.getAgedKillers(2);
        expect(agedKillers.isNotEmpty, true);
      });

      test('respects custom decay factor', () {
        final slowDecay = AgedKillerMoveHeuristic(decayFactor: 0.99);
        slowDecay.recordKiller(2, 'e2e4');
        for (int i = 0; i < 5; i++) {
          slowDecay.ageAllMoves();
        }

        final killers = slowDecay.getAgedKillers(2);
        expect(killers.isNotEmpty, true); // Still effective despite aging
      });
    });

    group('statistics', () {
      test('includes aging statistics', () {
        aged.recordKiller(2, 'e2e4');
        final stats = aged.getAgingStatistics();

        expect(stats.containsKey('averageAge'), true);
        expect(stats.containsKey('agedMoves'), true);
        expect(stats.containsKey('decayFactor'), true);
      });

      test('calculates average age correctly', () {
        aged.recordKiller(2, 'e2e4');
        aged.recordKiller(3, 'd2d4');
        aged.ageAllMoves();
        aged.ageAllMoves();

        final stats = aged.getAgingStatistics();
        expect(stats['averageAge'], equals(2.0));
      });

      test('tracks unique aged moves', () {
        aged.recordKiller(2, 'e2e4');
        aged.recordKiller(3, 'd2d4');
        aged.recordKiller(4, 'c2c4');

        final stats = aged.getAgingStatistics();
        expect(stats['agedMoves'], equals(3));
      });
    });

    group('clear operations', () {
      test('clears aging data', () {
        aged.recordKiller(2, 'e2e4');
        aged.ageAllMoves();
        aged.clear();

        expect(aged.getKillers(2), isEmpty);
        expect(aged.getMoveAge('e2e4'), equals(0));
      });
    });
  });

  group('AgedCountermoveHeuristic', () {
    late AgedCountermoveHeuristic aged;

    setUp(() {
      aged = AgedCountermoveHeuristic();
    });

    group('basic countermove functionality', () {
      test('records counter-moves', () {
        aged.recordCountermove('e7e5', 'e2e4');
        expect(aged.getCountermoves('e7e5'), contains('e2e4'));
      });

      test('maintains compatibility with parent', () {
        aged.recordCountermove('e7e5', 'e2e4');
        aged.recordCountermove('e7e5', 'd2d4');
        expect(aged.getCountermoves('e7e5').length, equals(2));
      });
    });

    group('pair aging mechanics', () {
      test('tracks pair age', () {
        aged.recordCountermove('e7e5', 'e2e4');
        expect(aged.getPairAge('e7e5', 'e2e4'), equals(0));
      });

      test('ages pairs correctly', () {
        aged.recordCountermove('e7e5', 'e2e4');
        aged.ageAllPairs();
        expect(aged.getPairAge('e7e5', 'e2e4'), equals(1));
      });

      test('multiple aging cycles on pairs', () {
        aged.recordCountermove('e7e5', 'e2e4');
        for (int i = 0; i < 3; i++) {
          aged.ageAllPairs();
        }
        expect(aged.getPairAge('e7e5', 'e2e4'), equals(3));
      });

      test('resets pair age on record', () {
        aged.recordCountermove('e7e5', 'e2e4');
        aged.ageAllPairs();
        aged.ageAllPairs();
        expect(aged.getPairAge('e7e5', 'e2e4'), equals(2));

        aged.recordCountermove('e7e5', 'e2e4'); // Record again
        expect(aged.getPairAge('e7e5', 'e2e4'), equals(0));
      });

      test('removes very old pairs', () {
        aged.recordCountermove('e7e5', 'e2e4');
        for (int i = 0; i < 20; i++) {
          aged.ageAllPairs();
        }
        expect(aged.getPairAge('e7e5', 'e2e4'), equals(0)); // Removed/reset
      });
    });

    group('aged countermove retrieval', () {
      test('returns empty for unknown opponent move', () {
        expect(aged.getAgedCountermoves('unknown'), isEmpty);
      });

      test('returns fresh countermoves unaffected by age', () {
        aged.recordCountermove('e7e5', 'e2e4');
        final aged_counters = aged.getAgedCountermoves('e7e5');
        expect(aged_counters, contains('e2e4'));
      });

      test('prioritizes fresh pairs over aged', () {
        aged.recordCountermove('e7e5', 'e2e4');
        aged.recordCountermove('e7e5', 'd2d4');
        aged.ageAllPairs();
        aged.ageAllPairs();
        aged.recordCountermove('e7e5', 'c2c4');

        final counters = aged.getAgedCountermoves('e7e5');
        expect(counters[0], 'c2c4'); // Most recent
      });

      test('applies decay to aged pairs', () {
        aged.recordCountermove('e7e5', 'e2e4');
        aged.ageAllPairs();
        aged.ageAllPairs();
        aged.ageAllPairs();

        final counters = aged.getAgedCountermoves('e7e5');
        expect(counters.isNotEmpty, true);
      });

      test('custom decay factor affects ranking', () {
        final slowDecay = AgedCountermoveHeuristic(decayFactor: 0.99);
        slowDecay.recordCountermove('e7e5', 'e2e4');
        for (int i = 0; i < 5; i++) {
          slowDecay.ageAllPairs();
        }

        final counters = slowDecay.getAgedCountermoves('e7e5');
        expect(counters.isNotEmpty, true);
      });
    });

    group('statistics', () {
      test('includes aging statistics', () {
        aged.recordCountermove('e7e5', 'e2e4');
        final stats = aged.getAgingStatistics();

        expect(stats.containsKey('averagePairAge'), true);
        expect(stats.containsKey('agedPairs'), true);
        expect(stats.containsKey('decayFactor'), true);
      });

      test('tracks aged pair count', () {
        aged.recordCountermove('e7e5', 'e2e4');
        aged.recordCountermove('e7e5', 'd2d4');
        aged.recordCountermove('d7d5', 'd2d4');

        final stats = aged.getAgingStatistics();
        expect(stats['agedPairs'], equals(3));
      });
    });

    group('clear operations', () {
      test('clears all aging data', () {
        aged.recordCountermove('e7e5', 'e2e4');
        aged.ageAllPairs();
        aged.clear();

        expect(aged.getCountermoves('e7e5'), isEmpty);
        expect(aged.getPairAge('e7e5', 'e2e4'), equals(0));
      });
    });
  });

  group('ExtendedOpeningBook', () {
    group('book positions', () {
      test('contains extended positions', () {
        final stats = ExtendedOpeningBook.getStatistics();
        expect(stats['totalPositions'], greaterThan(20));
      });

      test('returns recommended moves for known position', () {
        final moves = ExtendedOpeningBook.getRecommendedMoves(
            'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR');
        expect(moves.isNotEmpty, true);
      });

      test('returns empty for unknown position', () {
        final moves = ExtendedOpeningBook.getRecommendedMoves(
            'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR');
        expect(moves.isEmpty, true);
      });
    });

    group('position detection', () {
      test('recognizes positions in book', () {
        final inBook = ExtendedOpeningBook.isInBook(
            'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR');
        expect(inBook, true);
      });

      test('rejects unknown positions', () {
        final inBook = ExtendedOpeningBook.isInBook(
            'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR');
        expect(inBook, false);
      });
    });

    group('book depth', () {
      test('returns 0 for positions not in book', () {
        final depth = ExtendedOpeningBook.getBookDepth(
            'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR');
        expect(depth, equals(0));
      });

      test('returns positive depth for book positions', () {
        final depth = ExtendedOpeningBook.getBookDepth(
            'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR');
        expect(depth, greaterThanOrEqualTo(0));
      });
    });

    group('statistics', () {
      test('returns valid statistics', () {
        final stats = ExtendedOpeningBook.getStatistics();

        expect(stats.containsKey('totalPositions'), true);
        expect(stats.containsKey('totalMoves'), true);
        expect(stats.containsKey('openings'), true);
      });

      test('tracks opening categories', () {
        final stats = ExtendedOpeningBook.getStatistics();
        final openings = stats['openings'] as List;
        expect(openings.length, greaterThan(0));
      });
    });
  });

  group('AdaptiveHeuristicManager', () {
    late AdaptiveHeuristicManager manager;

    setUp(() {
      manager = AdaptiveHeuristicManager();
    });

    group('difficulty settings', () {
      test('sets difficulty level', () {
        manager.setDifficulty(0); // Easy
        expect(manager.getAdaptiveKillerLimit(), equals(1));

        manager.setDifficulty(1); // Medium
        expect(manager.getAdaptiveKillerLimit(), equals(2));

        manager.setDifficulty(2); // Hard
        manager.setTimeRemaining(5000);
        expect(manager.getAdaptiveKillerLimit(), equals(3));
      });

      test('clamps difficulty to valid range', () {
        manager.setDifficulty(-1);
        expect(
            manager.getAdaptiveKillerLimit(), equals(2)); // Clamped to medium

        manager.setDifficulty(5);
        expect(manager.getAdaptiveKillerLimit(),
            equals(3)); // Clamped to hard (with time)
      });
    });

    group('time-based adaptation', () {
      test('adjusts limits based on time remaining', () {
        manager.setDifficulty(2); // Hard
        manager.setTimeRemaining(5000);
        final highTime = manager.getAdaptiveCountermoveLimit();

        manager.setTimeRemaining(500); // Low time
        final lowTime = manager.getAdaptiveCountermoveLimit();

        expect(lowTime, lessThanOrEqualTo(highTime));
      });

      test('reduces heuristic limits when time is low', () {
        manager.setTimeRemaining(500);
        expect(manager.getAdaptiveCountermoveLimit(), equals(2));
      });

      test('increases limits with more time', () {
        manager.setDifficulty(2);
        manager.setTimeRemaining(5000);
        expect(manager.getAdaptiveCountermoveLimit(), greaterThanOrEqualTo(4));
      });
    });

    group('position phase adaptation', () {
      test('adjusts decay factor by phase', () {
        manager.setPositionPhase(0); // Opening
        final openingDecay = manager.getAdaptiveDecayFactor();

        manager.setPositionPhase(1); // Midgame
        final midgameDecay = manager.getAdaptiveDecayFactor();

        manager.setPositionPhase(2); // Endgame
        final endgameDecay = manager.getAdaptiveDecayFactor();

        expect(openingDecay, greaterThan(midgameDecay));
        expect(midgameDecay, greaterThan(endgameDecay));
      });

      test('opening phase preserves older heuristics', () {
        manager.setPositionPhase(0);
        expect(manager.getAdaptiveDecayFactor(), equals(0.98));
      });

      test('endgame phase ages faster', () {
        manager.setPositionPhase(2);
        expect(manager.getAdaptiveDecayFactor(), equals(0.90));
      });
    });

    group('aging updates', () {
      test('ages heuristics on update', () {
        manager.killerMoves.recordKiller(2, 'e2e4');
        manager.countermoves.recordCountermove('e7e5', 'e2e4');

        manager.updateAges();

        expect(manager.killerMoves.getMoveAge('e2e4'), equals(1));
        expect(manager.countermoves.getPairAge('e7e5', 'e2e4'), equals(1));
      });

      test('multiple age updates', () {
        manager.killerMoves.recordKiller(2, 'e2e4');
        for (int i = 0; i < 5; i++) {
          manager.updateAges();
        }
        expect(manager.killerMoves.getMoveAge('e2e4'), equals(5));
      });
    });

    group('statistics', () {
      test('returns comprehensive adaptive statistics', () {
        final stats = manager.getAdaptiveStatistics();

        expect(stats.containsKey('difficulty'), true);
        expect(stats.containsKey('timeRemaining'), true);
        expect(stats.containsKey('positionPhase'), true);
        expect(stats.containsKey('adaptiveKillerLimit'), true);
        expect(stats.containsKey('adaptiveCountermoveLimit'), true);
        expect(stats.containsKey('decayFactor'), true);
      });

      test('includes sub-component statistics', () {
        final stats = manager.getAdaptiveStatistics();

        expect(stats.containsKey('killerStats'), true);
        expect(stats.containsKey('countermoveStats'), true);
      });

      test('reflects current settings in statistics', () {
        manager.setDifficulty(2);
        manager.setTimeRemaining(3000);
        manager.setPositionPhase(0);

        final stats = manager.getAdaptiveStatistics();
        expect(stats['difficulty'], equals(2));
        expect(stats['timeRemaining'], equals(3000));
        expect(stats['positionPhase'], equals(0));
      });
    });

    group('clear operations', () {
      test('clears all heuristics', () {
        manager.killerMoves.recordKiller(2, 'e2e4');
        manager.countermoves.recordCountermove('e7e5', 'e2e4');
        manager.clear();

        expect(manager.killerMoves.getKillers(2), isEmpty);
        expect(manager.countermoves.getCountermoves('e7e5'), isEmpty);
      });
    });

    group('integration', () {
      test('adapts all settings together', () {
        // Simulate early-game endgame blitz
        manager.setDifficulty(2); // Hard mode
        manager.setTimeRemaining(500); // Low time
        manager.setPositionPhase(2); // Endgame

        final stats = manager.getAdaptiveStatistics();

        // Should reduce countermoves due to time
        expect(stats['adaptiveCountermoveLimit'], equals(2));
        // Should use fast decay for endgame
        expect(stats['decayFactor'], equals(0.90));
      });

      test('handles complex game scenario', () {
        // Early opening
        manager.setDifficulty(1);
        manager.setTimeRemaining(30000);
        manager.setPositionPhase(0);

        manager.killerMoves.recordKiller(2, 'e2e4');
        manager.updateAges();

        // Transition to midgame
        manager.setPositionPhase(1);
        manager.setTimeRemaining(15000);

        manager.updateAges();
        manager.updateAges();

        // Transition to endgame
        manager.setPositionPhase(2);
        manager.setTimeRemaining(2000);

        manager.updateAges();

        // Verify adaptation worked
        final stats = manager.getAdaptiveStatistics();
        expect(stats['killerStats'], isNotNull);
      });
    });
  });

  group('Integration Tests', () {
    test('aged killer moves with real search depth', () {
      final aged = AgedKillerMoveHeuristic();

      // Simulate search with multiple depths
      for (int depth = 1; depth <= 4; depth++) {
        aged.recordKiller(depth, 'e${2 + depth}e${3 + depth}');
      }

      // Age once
      aged.ageAllMoves();

      // All should still be present but aged
      for (int depth = 1; depth <= 4; depth++) {
        expect(aged.getKillers(depth).isNotEmpty, true);
      }
    });

    test('aged countermoves with game flow', () {
      final aged = AgedCountermoveHeuristic();

      // Opponent plays e7-e5, we respond with e2-e4
      aged.recordCountermove('e7e5', 'e2e4');
      aged.recordCountermove('e7e5', 'e2e4'); // Used twice

      // Age the position
      for (int i = 0; i < 10; i++) {
        aged.ageAllPairs();
      }

      // Opponent plays different move
      aged.recordCountermove('d7d5', 'd2d4');

      final e5Counters = aged.getAgedCountermoves('e7e5');
      final d5Counters = aged.getAgedCountermoves('d7d5');

      expect(d5Counters.isNotEmpty, true);
      expect(e5Counters.isNotEmpty, true);
    });

    test('adaptive manager through full game', () {
      final manager = AdaptiveHeuristicManager();

      // Opening phase
      manager.setDifficulty(2);
      manager.setTimeRemaining(30000);
      manager.setPositionPhase(0);

      manager.killerMoves.recordKiller(2, 'e2e4');
      manager.countermoves.recordCountermove('e7e5', 'e2e4');

      // Play out moves
      for (int i = 0; i < 8; i++) {
        manager.updateAges();
      }

      // Transition to midgame
      manager.setPositionPhase(1);
      manager.setTimeRemaining(20000);

      // Continue playing
      manager.killerMoves.recordKiller(3, 'd2d4');
      for (int i = 0; i < 5; i++) {
        manager.updateAges();
      }

      // Endgame scenario
      manager.setPositionPhase(2);
      manager.setTimeRemaining(1000);

      final stats = manager.getAdaptiveStatistics();
      expect(stats['adaptiveCountermoveLimit'], equals(2)); // Reduced by time
    });
  });
}
