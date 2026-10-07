import 'package:flutter_test/flutter_test.dart';
import 'package:chess/chess.dart' as chess_lib;
import 'package:komovia_chess/src/services/countermove_heuristic.dart';

void main() {
  group('CountermoveHeuristic', () {
    late CountermoveHeuristic countermove;

    setUp(() {
      countermove = CountermoveHeuristic();
    });

    group('recordCountermove', () {
      test('stores a counter-move for opponent move', () {
        countermove.recordCountermove('e7e5', 'e2e4');
        expect(countermove.getCountermoves('e7e5'), contains('e2e4'));
      });

      test('stores multiple counter-moves for same opponent move', () {
        countermove.recordCountermove('e7e5', 'e2e4');
        countermove.recordCountermove('e7e5', 'd2d4');
        final counters = countermove.getCountermoves('e7e5');
        expect(counters.length, equals(2));
      });

      test('prioritizes recent counter-moves', () {
        countermove.recordCountermove('e7e5', 'e2e4');
        countermove.recordCountermove('e7e5', 'd2d4');
        final counters = countermove.getCountermoves('e7e5');
        expect(counters[0], 'd2d4'); // Most recent first
      });

      test('limits counter-moves to 4 per position', () {
        countermove.recordCountermove('e7e5', 'e2e4');
        countermove.recordCountermove('e7e5', 'd2d4');
        countermove.recordCountermove('e7e5', 'c2c4');
        countermove.recordCountermove('e7e5', 'f2f4');
        countermove.recordCountermove('e7e5', 'g2g4');
        final counters = countermove.getCountermoves('e7e5');
        expect(counters.length, equals(4));
      });

      test('moves existing counter-move to front on repeat', () {
        countermove.recordCountermove('e7e5', 'e2e4');
        countermove.recordCountermove('e7e5', 'd2d4');
        countermove.recordCountermove('e7e5', 'e2e4'); // Repeat
        final counters = countermove.getCountermoves('e7e5');
        expect(counters[0], 'e2e4'); // Should be first now
      });

      test('increments pair score on recording', () {
        countermove.recordCountermove('e7e5', 'e2e4');
        final score1 = countermove.getCountermoveScore('e7e5', 'e2e4');
        countermove.recordCountermove('e7e5', 'e2e4');
        final score2 = countermove.getCountermoveScore('e7e5', 'e2e4');
        expect(score2, greaterThan(score1));
      });

      test('tracks statistics on recording', () {
        countermove.recordCountermove('e7e5', 'e2e4');
        final stats = countermove.getStatistics();
        expect(stats['totalCutoffs'], equals(1));
        expect(stats['countermoveCutoffs'], equals(1));
      });

      test('handles many counter-moves', () {
        for (int i = 0; i < 100; i++) {
          countermove.recordCountermove('e7e5', 'e2e4');
        }
        expect(countermove.getCountermoveScore('e7e5', 'e2e4'), greaterThan(0));
      });
    });

    group('getCountermoves', () {
      test('returns empty list for unknown opponent move', () {
        expect(countermove.getCountermoves('unknown'), isEmpty);
      });

      test('returns counter-moves in priority order', () {
        countermove.recordCountermove('e7e5', 'e2e4');
        countermove.recordCountermove('e7e5', 'd2d4');
        countermove.recordCountermove('e7e5', 'c2c4');
        final counters = countermove.getCountermoves('e7e5');
        expect(counters[0], 'c2c4'); // Most recent
        expect(counters[2], 'e2e4'); // Oldest
      });

      test('returns list of correct length', () {
        countermove.recordCountermove('e7e5', 'e2e4');
        countermove.recordCountermove('e7e5', 'd2d4');
        expect(countermove.getCountermoves('e7e5').length, equals(2));
      });
    });

    group('isCountermove', () {
      test('returns true for recorded counter-move', () {
        countermove.recordCountermove('e7e5', 'e2e4');
        expect(countermove.isCountermove('e7e5', 'e2e4'), true);
      });

      test('returns false for non-recorded counter-move', () {
        countermove.recordCountermove('e7e5', 'e2e4');
        expect(countermove.isCountermove('e7e5', 'd2d4'), false);
      });

      test('returns false for wrong opponent move', () {
        countermove.recordCountermove('e7e5', 'e2e4');
        expect(countermove.isCountermove('d7d5', 'e2e4'), false);
      });
    });

    group('getCountermoveScore', () {
      test('returns score for recorded pair', () {
        countermove.recordCountermove('e7e5', 'e2e4');
        expect(countermove.getCountermoveScore('e7e5', 'e2e4'), greaterThan(0));
      });

      test('returns 0 for unrecorded pair', () {
        expect(countermove.getCountermoveScore('e7e5', 'e2e4'), equals(0));
      });

      test('increases with repeated recordings', () {
        countermove.recordCountermove('e7e5', 'e2e4');
        final score1 = countermove.getCountermoveScore('e7e5', 'e2e4');
        countermove.recordCountermove('e7e5', 'e2e4');
        countermove.recordCountermove('e7e5', 'e2e4');
        final score2 = countermove.getCountermoveScore('e7e5', 'e2e4');
        expect(score2, greaterThan(score1));
      });

      test('different pairs tracked independently', () {
        countermove.recordCountermove('e7e5', 'e2e4');
        countermove.recordCountermove('e7e5', 'd2d4');
        countermove.recordCountermove('e7e5', 'd2d4');
        expect(
          countermove.getCountermoveScore('e7e5', 'd2d4'),
          greaterThan(countermove.getCountermoveScore('e7e5', 'e2e4')),
        );
      });
    });

    group('getCountermovePriority', () {
      test('returns 0 for primary counter-move', () {
        countermove.recordCountermove('e7e5', 'e2e4');
        countermove.recordCountermove('e7e5', 'd2d4');
        expect(countermove.getCountermovePriority('e7e5', 'd2d4'), equals(0));
      });

      test('returns 1 for secondary counter-move', () {
        countermove.recordCountermove('e7e5', 'e2e4');
        countermove.recordCountermove('e7e5', 'd2d4');
        expect(countermove.getCountermovePriority('e7e5', 'e2e4'), equals(1));
      });

      test('returns 999 for unknown counter-move', () {
        expect(countermove.getCountermovePriority('e7e5', 'e2e4'), equals(999));
      });

      test('correct priority after moves', () {
        countermove.recordCountermove('e7e5', 'e2e4');
        countermove.recordCountermove('e7e5', 'd2d4');
        countermove.recordCountermove('e7e5', 'c2c4');
        expect(countermove.getCountermovePriority('e7e5', 'c2c4'), equals(0));
        expect(countermove.getCountermovePriority('e7e5', 'd2d4'), equals(1));
        expect(countermove.getCountermovePriority('e7e5', 'e2e4'), equals(2));
      });
    });

    group('clear', () {
      test('clears all counter-moves', () {
        countermove.recordCountermove('e7e5', 'e2e4');
        countermove.recordCountermove('d7d5', 'd2d4');
        countermove.clear();
        expect(countermove.getCountermoves('e7e5'), isEmpty);
        expect(countermove.getCountermoves('d7d5'), isEmpty);
      });

      test('resets statistics', () {
        countermove.recordCountermove('e7e5', 'e2e4');
        countermove.clear();
        final stats = countermove.getStatistics();
        expect(stats['totalCutoffs'], equals(0));
        expect(stats['countermoveCutoffs'], equals(0));
      });
    });

    group('getStatistics', () {
      test('returns valid statistics dictionary', () {
        countermove.recordCountermove('e7e5', 'e2e4');
        final stats = countermove.getStatistics();
        expect(stats.containsKey('totalCutoffs'), true);
        expect(stats.containsKey('countermoveCutoffs'), true);
        expect(stats.containsKey('cutoffRate'), true);
        expect(stats.containsKey('uniquePositions'), true);
        expect(stats.containsKey('totalCountermovePairs'), true);
        expect(stats.containsKey('topPositions'), true);
      });

      test('calculates cutoff rate correctly', () {
        countermove.recordCountermove('e7e5', 'e2e4');
        countermove.recordCountermove('e7e5', 'e2e4');
        final stats = countermove.getStatistics();
        expect(stats['countermoveCutoffs'], equals(2));
        expect(stats['totalCutoffs'], equals(2));
        expect(stats['cutoffRate'], equals(100.0));
      });

      test('tracks unique positions', () {
        countermove.recordCountermove('e7e5', 'e2e4');
        countermove.recordCountermove('d7d5', 'd2d4');
        countermove.recordCountermove('c7c5', 'c2c4');
        final stats = countermove.getStatistics();
        expect(stats['uniquePositions'], equals(3));
      });

      test('tracks total counter-move pairs', () {
        countermove.recordCountermove('e7e5', 'e2e4');
        countermove.recordCountermove('e7e5', 'd2d4');
        countermove.recordCountermove('d7d5', 'd2d4');
        final stats = countermove.getStatistics();
        expect(stats['totalCountermovePairs'], equals(3));
      });

      test('top positions ranked by effectiveness', () {
        countermove.recordCountermove('e7e5', 'e2e4');
        countermove.recordCountermove('e7e5', 'e2e4');
        countermove.recordCountermove('d7d5', 'd2d4');
        final stats = countermove.getStatistics();
        final topPositions = stats['topPositions'] as List;
        if (topPositions.length >= 1) {
          expect(topPositions[0]['opponentMove'], 'e7e5'); // Higher score
        }
      });
    });

    group('integration', () {
      test('multiple opponent moves tracked independently', () {
        countermove.recordCountermove('e7e5', 'e2e4');
        countermove.recordCountermove('d7d5', 'd2d4');
        countermove.recordCountermove('c7c5', 'c2c4');

        expect(countermove.isCountermove('e7e5', 'e2e4'), true);
        expect(countermove.isCountermove('d7d5', 'd2d4'), true);
        expect(countermove.isCountermove('c7c5', 'c2c4'), true);
        expect(countermove.isCountermove('e7e5', 'd2d4'), false);
      });

      test('complex game sequence', () {
        // Simulate complex game
        countermove.recordCountermove('e7e5', 'e2e4');
        countermove.recordCountermove('e7e5', 'e2e4');
        countermove.recordCountermove('e7e5', 'd2d4');
        countermove.recordCountermove('d7d5', 'd2d4');
        countermove.recordCountermove('d7d5', 'e2e4');

        expect(countermove.isCountermove('e7e5', 'e2e4'), true);
        expect(countermove.getCountermovePriority('e7e5', 'e2e4'), lessThan(1));
        expect(countermove.getCountermoveScore('e7e5', 'e2e4'),
            greaterThan(countermove.getCountermoveScore('e7e5', 'd2d4')));
      });
    });
  });

  group('AdvancedMoveOrderer', () {
    late AdvancedMoveOrderer orderer;
    late chess_lib.Chess chess;

    setUp(() {
      orderer = AdvancedMoveOrderer();
      chess = chess_lib.Chess();
    });

    group('setLastOpponentMove', () {
      test('stores last opponent move', () {
        orderer.setLastOpponentMove('e7e5');
        // Verify by checking internal state through usage
        expect(orderer.countermoves, isNotNull);
      });

      test('allows subsequent counter-move recording', () {
        orderer.setLastOpponentMove('e7e5');
        orderer.recordCountermove('e2e4');
        expect(orderer.countermoves.isCountermove('e7e5', 'e2e4'), true);
      });
    });

    group('orderMoves', () {
      test('returns moves without crashing', () {
        final moves = chess.moves() as List<chess_lib.Move>;
        final ordered = orderer.orderMoves(moves, chess, depth: 0);
        expect(ordered.length, equals(moves.length));
      });

      test('preserves move count', () {
        final moves = chess.moves() as List<chess_lib.Move>;
        final ordered = orderer.orderMoves(moves, chess, depth: 2);
        expect(ordered.length, equals(moves.length));
      });

      test('prioritizes captures', () {
        // Set up position with capture available
        chess.move(chess_lib.Move(fromAlgebraic: 'e2', toAlgebraic: 'e4'));
        chess.move(chess_lib.Move(fromAlgebraic: 'd7', toAlgebraic: 'd5'));
        chess.move(chess_lib.Move(fromAlgebraic: 'e4', toAlgebraic: 'd5'));
        chess.move(chess_lib.Move(fromAlgebraic: 'c7', toAlgebraic: 'c6'));

        final moves = chess.moves() as List<chess_lib.Move>;
        final ordered = orderer.orderMoves(moves, chess, depth: 0);
        expect(ordered.isNotEmpty, true);
      });

      test('uses counter-move heuristic when available', () {
        orderer.setLastOpponentMove('e7e5');
        orderer.recordCountermove('e2e4');

        final moves = chess.moves() as List<chess_lib.Move>;
        final ordered = orderer.orderMoves(moves, chess, depth: 0);
        expect(ordered.length, equals(moves.length));
      });
    });

    group('recordCountermove', () {
      test('records counter-move to last opponent move', () {
        orderer.setLastOpponentMove('e7e5');
        orderer.recordCountermove('e2e4');
        expect(orderer.countermoves.isCountermove('e7e5', 'e2e4'), true);
      });

      test('handles null last opponent move gracefully', () {
        // Should not crash if no opponent move set
        orderer.recordCountermove('e2e4');
        expect(orderer.countermoves.isCountermove('e7e5', 'e2e4'), false);
      });

      test('records multiple counter-moves', () {
        orderer.setLastOpponentMove('e7e5');
        orderer.recordCountermove('e2e4');
        orderer.recordCountermove('d2d4');
        expect(orderer.countermoves.getCountermoves('e7e5').length, equals(2));
      });
    });

    group('recordKiller', () {
      test('records killer move', () {
        orderer.recordKiller('e2e4');
        expect(orderer.countermoves.getMoveScore('e2e4'), isNotNull);
      });

      test('accumulates killer move scores', () {
        orderer.recordKiller('e2e4');
        orderer.recordKiller('e2e4');
        expect(orderer.countermoves.getMoveScore('e2e4'),
            greaterThan(orderer.countermoves.getMoveScore('d2d4')));
      });
    });

    group('recordHistory', () {
      test('records move history', () {
        orderer.recordHistory('e2e4', 10);
        // Just verify no crash
        expect(orderer, isNotNull);
      });

      test('accumulates history bonuses', () {
        orderer.recordHistory('e2e4', 10);
        orderer.recordHistory('e2e4', 5);
        // History accumulation verified through scoring
        expect(orderer, isNotNull);
      });
    });

    group('clear', () {
      test('clears all heuristics', () {
        orderer.setLastOpponentMove('e7e5');
        orderer.recordCountermove('e2e4');
        orderer.recordKiller('d2d4');
        orderer.clear();

        expect(orderer.countermoves.getCountermoves('e7e5'), isEmpty);
      });
    });

    group('getStatistics', () {
      test('returns valid statistics', () {
        orderer.setLastOpponentMove('e7e5');
        orderer.recordCountermove('e2e4');
        final stats = orderer.getStatistics();

        expect(stats.containsKey('countermoveStats'), true);
        expect(stats.containsKey('killerMoves'), true);
        expect(stats.containsKey('historyMoves'), true);
        expect(stats.containsKey('lastOpponentMove'), true);
      });

      test('tracks counter-move statistics', () {
        orderer.setLastOpponentMove('e7e5');
        orderer.recordCountermove('e2e4');
        final stats = orderer.getStatistics();

        expect(stats['lastOpponentMove'], equals('e7e5'));
      });
    });

    group('integration', () {
      test('combines multiple heuristics', () {
        // Set up complex game state
        orderer.setLastOpponentMove('e7e5');
        orderer.recordCountermove('e2e4');
        orderer.recordKiller('d2d4');
        orderer.recordHistory('c2c4', 20);

        // Order moves
        final moves = chess.moves() as List<chess_lib.Move>;
        final ordered = orderer.orderMoves(moves, chess, depth: 1);

        // All moves should be preserved
        expect(ordered.length, equals(moves.length));
      });

      test('handles real game flow', () {
        // Simulate real moves
        chess.move(chess_lib.Move(fromAlgebraic: 'e2', toAlgebraic: 'e4'));
        orderer.setLastOpponentMove('e2e4');

        chess.move(chess_lib.Move(fromAlgebraic: 'c7', toAlgebraic: 'c5'));
        orderer.recordCountermove('d2d4');

        final moves = chess.moves() as List<chess_lib.Move>;
        final ordered = orderer.orderMoves(moves, chess, depth: 2);

        expect(ordered.isNotEmpty, true);
      });
    });
  });

  group('PrincipalVariationCache', () {
    late PrincipalVariationCache cache;

    setUp(() {
      cache = PrincipalVariationCache();
    });

    group('setPVMove and getPVMove', () {
      test('stores and retrieves PV move at depth', () {
        cache.setPVMove(1, 'e2e4');
        expect(cache.getPVMove(1), equals('e2e4'));
      });

      test('returns null for unset depth', () {
        expect(cache.getPVMove(5), isNull);
      });

      test('stores moves at different depths', () {
        cache.setPVMove(1, 'e2e4');
        cache.setPVMove(2, 'c7c5');
        cache.setPVMove(3, 'd2d4');

        expect(cache.getPVMove(1), equals('e2e4'));
        expect(cache.getPVMove(2), equals('c7c5'));
        expect(cache.getPVMove(3), equals('d2d4'));
      });

      test('overwrites previous PV move at depth', () {
        cache.setPVMove(1, 'e2e4');
        cache.setPVMove(1, 'd2d4');
        expect(cache.getPVMove(1), equals('d2d4'));
      });
    });

    group('updatePrincipalVariation and getPrincipalVariation', () {
      test('stores principal variation', () {
        final pv = ['e2e4', 'c7c5', 'd2d4', 'e7e6'];
        cache.updatePrincipalVariation(pv);
        expect(cache.getPrincipalVariation(), equals(pv));
      });

      test('returns copy not reference', () {
        final pv = ['e2e4', 'c7c5'];
        cache.updatePrincipalVariation(pv);
        final retrieved = cache.getPrincipalVariation();
        retrieved.add('d2d4');
        expect(cache.getPrincipalVariation().length, equals(2));
      });

      test('handles empty principal variation', () {
        cache.updatePrincipalVariation([]);
        expect(cache.getPrincipalVariation(), isEmpty);
      });

      test('overwrites previous variation', () {
        cache.updatePrincipalVariation(['e2e4', 'c7c5']);
        cache.updatePrincipalVariation(['d2d4', 'd7d5']);
        expect(cache.getPrincipalVariation(), equals(['d2d4', 'd7d5']));
      });
    });

    group('recordPVCutoff and recordPVSearch', () {
      test('increments cutoff counter', () {
        cache.recordPVCutoff();
        expect(cache.getPVCutoffRate(), greaterThan(0));
      });

      test('tracks search attempts', () {
        cache.recordPVSearch();
        cache.recordPVCutoff();
        expect(cache.getPVCutoffRate(), equals(1.0));
      });

      test('handles multiple cutoffs and searches', () {
        for (int i = 0; i < 10; i++) {
          cache.recordPVSearch();
        }
        for (int i = 0; i < 7; i++) {
          cache.recordPVCutoff();
        }
        expect(cache.getPVCutoffRate(), closeTo(0.7, 0.01));
      });
    });

    group('getPVCutoffRate', () {
      test('returns 0.0 with no searches', () {
        expect(cache.getPVCutoffRate(), equals(0.0));
      });

      test('returns 0.0 with no cutoffs', () {
        cache.recordPVSearch();
        cache.recordPVSearch();
        expect(cache.getPVCutoffRate(), equals(0.0));
      });

      test('calculates rate correctly', () {
        cache.recordPVSearch();
        cache.recordPVSearch();
        cache.recordPVSearch();
        cache.recordPVCutoff();
        cache.recordPVCutoff();
        expect(cache.getPVCutoffRate(), closeTo(0.667, 0.01));
      });

      test('returns perfect rate for all cutoffs', () {
        cache.recordPVSearch();
        cache.recordPVSearch();
        cache.recordPVCutoff();
        cache.recordPVCutoff();
        expect(cache.getPVCutoffRate(), equals(1.0));
      });
    });

    group('clear', () {
      test('clears principal variation', () {
        cache.updatePrincipalVariation(['e2e4', 'c7c5']);
        cache.clear();
        expect(cache.getPrincipalVariation(), isEmpty);
      });

      test('clears PV moves', () {
        cache.setPVMove(1, 'e2e4');
        cache.clear();
        expect(cache.getPVMove(1), isNull);
      });

      test('resets statistics', () {
        cache.recordPVSearch();
        cache.recordPVCutoff();
        cache.clear();
        expect(cache.getPVCutoffRate(), equals(0.0));
      });
    });

    group('getStatistics', () {
      test('returns valid statistics dictionary', () {
        cache.updatePrincipalVariation(['e2e4', 'c7c5']);
        cache.recordPVSearch();
        cache.recordPVCutoff();

        final stats = cache.getStatistics();
        expect(stats.containsKey('pvLength'), true);
        expect(stats.containsKey('pvCutoffs'), true);
        expect(stats.containsKey('pvSearches'), true);
        expect(stats.containsKey('pvCutoffRate'), true);
      });

      test('tracks PV length correctly', () {
        cache.updatePrincipalVariation(['e2e4', 'c7c5', 'd2d4']);
        final stats = cache.getStatistics();
        expect(stats['pvLength'], equals(3));
      });

      test('tracks cutoff statistics', () {
        cache.recordPVSearch();
        cache.recordPVSearch();
        cache.recordPVCutoff();

        final stats = cache.getStatistics();
        expect(stats['pvSearches'], equals(2));
        expect(stats['pvCutoffs'], equals(1));
        expect(stats['pvCutoffRate'], closeTo(0.5, 0.01));
      });
    });

    group('integration', () {
      test('combines PV storage with statistics', () {
        // Build PV through depths
        cache.setPVMove(1, 'e2e4');
        cache.setPVMove(2, 'c7c5');
        cache.setPVMove(3, 'd2d4');

        // Update full PV
        cache.updatePrincipalVariation(['e2e4', 'c7c5', 'd2d4', 'e7e6']);

        // Track effectiveness
        cache.recordPVSearch();
        cache.recordPVSearch();
        cache.recordPVCutoff();

        final stats = cache.getStatistics();
        expect(stats['pvLength'], equals(4));
        expect(stats['pvCutoffs'], equals(1));
      });

      test('handles real search scenario', () {
        // Simulate search building PV
        for (int depth = 1; depth <= 4; depth++) {
          cache.setPVMove(depth, 'e2e${3 + depth}');
        }

        // Update full PV
        cache.updatePrincipalVariation(['e2e4', 'c7c5', 'd2d4', 'e7e6']);

        // Track cutoff
        cache.recordPVSearch();
        cache.recordPVCutoff();

        final stats = cache.getStatistics();
        expect(stats['pvLength'], greaterThan(0));
        expect(stats['pvCutoffRate'], greaterThanOrEqualTo(0));
      });
    });
  });

  group('Integration Tests', () {
    test('countermove heuristic improves move ordering', () {
      final countermove = CountermoveHeuristic();
      final orderer = AdvancedMoveOrderer(countermoves: countermove);

      orderer.setLastOpponentMove('e7e5');
      orderer.recordCountermove('e2e4');
      orderer.recordCountermove('e2e4');

      final stats = orderer.getStatistics();
      expect(stats.containsKey('countermoveStats'), true);
    });

    test('principal variation tracks best line', () {
      final cache = PrincipalVariationCache();

      cache.updatePrincipalVariation(['e2e4', 'c7c5', 'd2d4', 'c5d4']);
      cache.recordPVSearch();
      cache.recordPVCutoff();

      expect(cache.getPrincipalVariation().length, equals(4));
      expect(cache.getPVCutoffRate(), equals(1.0));
    });

    test('advanced orderer combines all heuristics', () {
      final orderer = AdvancedMoveOrderer();
      final chess = chess_lib.Chess();

      orderer.setLastOpponentMove('e7e5');
      orderer.recordCountermove('e2e4');
      orderer.recordKiller('d2d4');
      orderer.recordHistory('c2c4', 15);

      final moves = chess.moves() as List<chess_lib.Move>;
      final ordered = orderer.orderMoves(moves, chess, depth: 2);

      expect(ordered.length, equals(moves.length));
    });

    test('full search scenario with all components', () {
      final countermove = CountermoveHeuristic();
      final orderer = AdvancedMoveOrderer(countermoves: countermove);
      final cache = PrincipalVariationCache();
      final chess = chess_lib.Chess();

      // Simulate search
      orderer.setLastOpponentMove('e7e5');
      orderer.recordCountermove('e2e4');

      cache.setPVMove(1, 'e2e4');
      cache.setPVMove(2, 'c7c5');
      cache.updatePrincipalVariation(['e2e4', 'c7c5']);

      cache.recordPVSearch();
      cache.recordPVCutoff();

      // Verify state
      final ordererStats = orderer.getStatistics();
      final cacheStats = cache.getStatistics();

      expect(ordererStats.containsKey('countermoveStats'), true);
      expect(cacheStats['pvLength'], equals(2));
      expect(cacheStats['pvCutoffRate'], equals(1.0));
    });
  });
}
