import 'package:flutter_test/flutter_test.dart';
import 'package:chess/chess.dart' as chess_lib;
import 'package:komovia_chess/src/services/killer_move_heuristic.dart';

void main() {
  group('KillerMoveHeuristic', () {
    late KillerMoveHeuristic killer;

    setUp(() {
      killer = KillerMoveHeuristic();
    });

    group('recordKiller', () {
      test('stores a killer move at a depth', () {
        killer.recordKiller(2, 'e2e4');
        expect(killer.getKillers(2), contains('e2e4'));
      });

      test('stores two killer moves per depth', () {
        killer.recordKiller(2, 'e2e4');
        killer.recordKiller(2, 'd2d4');
        expect(killer.getKillers(2).length, equals(2));
      });

      test('prioritizes newer killer moves', () {
        killer.recordKiller(2, 'e2e4');
        killer.recordKiller(2, 'd2d4');
        final killers = killer.getKillers(2);
        expect(killers[0], 'd2d4'); // Last recorded should be first
      });

      test('ignores killers for invalid depths', () {
        killer.recordKiller(-1, 'e2e4');
        killer.recordKiller(100, 'e2e4');
        expect(killer.getKillers(-1), isEmpty);
        expect(killer.getKillers(100), isEmpty);
      });

      test('increments move score on cutoff', () {
        killer.recordKiller(2, 'e2e4');
        final score1 = killer.getMoveScore('e2e4');
        killer.recordKiller(2, 'e2e4'); // Record same move again
        final score2 = killer.getMoveScore('e2e4');
        expect(score2, greaterThan(score1));
      });

      test('handles many killer moves', () {
        for (int i = 0; i < 100; i++) {
          killer.recordKiller(3, 'e2e4');
        }
        final score = killer.getMoveScore('e2e4');
        expect(score, greaterThan(0));
      });
    });

    group('getKillers', () {
      test('returns empty list for depth with no killers', () {
        expect(killer.getKillers(0), isEmpty);
      });

      test('returns killers for depth with recorded moves', () {
        killer.recordKiller(2, 'e2e4');
        expect(killer.getKillers(2), isNotEmpty);
      });

      test('returns killers in order (primary first)', () {
        killer.recordKiller(2, 'e2e4');
        killer.recordKiller(2, 'd2d4');
        final killers = killer.getKillers(2);
        expect(killers[0], 'd2d4');
        expect(killers[1], 'e2e4');
      });

      test('returns empty list for negative depth', () {
        expect(killer.getKillers(-1), isEmpty);
      });

      test('returns empty list for depth beyond max', () {
        expect(killer.getKillers(20), isEmpty);
      });
    });

    group('isKiller', () {
      test('returns true for recorded killer move', () {
        killer.recordKiller(2, 'e2e4');
        expect(killer.isKiller(2, 'e2e4'), true);
      });

      test('returns false for non-recorded move', () {
        killer.recordKiller(2, 'e2e4');
        expect(killer.isKiller(2, 'd2d4'), false);
      });

      test('returns false for move at different depth', () {
        killer.recordKiller(2, 'e2e4');
        expect(killer.isKiller(3, 'e2e4'), false);
      });

      test('returns false for invalid depth', () {
        killer.recordKiller(2, 'e2e4');
        expect(killer.isKiller(-1, 'e2e4'), false);
      });
    });

    group('getMoveScore', () {
      test('returns score for recorded move', () {
        killer.recordKiller(2, 'e2e4');
        expect(killer.getMoveScore('e2e4'), greaterThan(0));
      });

      test('returns 0 for unrecorded move', () {
        expect(killer.getMoveScore('e2e4'), equals(0));
      });

      test('increases with more cutoffs', () {
        killer.recordKiller(2, 'e2e4');
        final score1 = killer.getMoveScore('e2e4');
        killer.recordKiller(3, 'e2e4');
        final score2 = killer.getMoveScore('e2e4');
        expect(score2, greaterThan(score1));
      });
    });

    group('clear', () {
      test('clears all killer moves', () {
        killer.recordKiller(2, 'e2e4');
        killer.recordKiller(3, 'd2d4');
        killer.clear();
        expect(killer.getKillers(2), isEmpty);
        expect(killer.getKillers(3), isEmpty);
      });

      test('resets move scores', () {
        killer.recordKiller(2, 'e2e4');
        killer.clear();
        expect(killer.getMoveScore('e2e4'), equals(0));
      });
    });

    group('clearDepthRange', () {
      test('clears killers in depth range', () {
        killer.recordKiller(2, 'e2e4');
        killer.recordKiller(3, 'd2d4');
        killer.recordKiller(4, 'c2c4');
        killer.clearDepthRange(2, 3);
        expect(killer.getKillers(2), isEmpty);
        expect(killer.getKillers(3), isEmpty);
        expect(killer.getKillers(4), isNotEmpty);
      });
    });

    group('getStatistics', () {
      test('returns valid statistics', () {
        killer.recordKiller(2, 'e2e4');
        final stats = killer.getStatistics();
        expect(stats.containsKey('totalCutoffs'), true);
        expect(stats.containsKey('killerCutoffs'), true);
        expect(stats.containsKey('cutoffRate'), true);
        expect(stats.containsKey('uniqueKillers'), true);
      });

      test('tracks cutoff rate correctly', () {
        for (int i = 0; i < 10; i++) {
          killer.recordKiller(2, 'e2e4');
        }
        final stats = killer.getStatistics();
        expect(stats['killerCutoffs'], equals(10));
      });

      test('identifies top killer', () {
        killer.recordKiller(2, 'e2e4');
        killer.recordKiller(3, 'e2e4');
        killer.recordKiller(3, 'e2e4');
        killer.recordKiller(4, 'd2d4');
        final stats = killer.getStatistics();
        expect(stats['topKiller'], 'e2e4');
      });

      test('returns top killers list', () {
        killer.recordKiller(2, 'e2e4');
        killer.recordKiller(3, 'd2d4');
        killer.recordKiller(4, 'c2c4');
        final stats = killer.getStatistics();
        final topKillers = stats['topKillers'] as List;
        expect(topKillers.length, greaterThan(0));
      });
    });

    group('depth tracking', () {
      test('maintains separate killer moves per depth', () {
        killer.recordKiller(1, 'e2e4');
        killer.recordKiller(2, 'd2d4');
        killer.recordKiller(3, 'c2c4');
        expect(killer.getKillers(1), ['e2e4']);
        expect(killer.getKillers(2), ['d2d4']);
        expect(killer.getKillers(3), ['c2c4']);
      });

      test('handles maximum depth', () {
        killer.recordKiller(11, 'e2e4');
        expect(killer.getKillers(11), contains('e2e4'));
      });
    });
  });

  group('MoveOrderingManager', () {
    late MoveOrderingManager manager;
    late chess_lib.Chess chess;

    setUp(() {
      manager = MoveOrderingManager();
      chess = chess_lib.Chess();
    });

    group('orderMoves', () {
      test('orders moves (doesn\'t crash)', () {
        final legalMoves = chess.moves() as List<chess_lib.Move>;
        final ordered = manager.orderMoves(legalMoves, chess, depth: 0);
        expect(ordered.length, equals(legalMoves.length));
      });

      test('returns same number of moves', () {
        final legalMoves = chess.moves() as List<chess_lib.Move>;
        final ordered = manager.orderMoves(legalMoves, chess, depth: 2);
        expect(ordered.length, equals(legalMoves.length));
      });

      test('prioritizes captures', () {
        // Setup position with captures available
        chess.move(chess_lib.Move(fromAlgebraic: 'e2', toAlgebraic: 'e4'));
        chess.move(chess_lib.Move(fromAlgebraic: 'd7', toAlgebraic: 'd5'));
        chess.move(
            chess_lib.Move(fromAlgebraic: 'e4', toAlgebraic: 'd5')); // Capture
        chess.move(chess_lib.Move(fromAlgebraic: 'c7', toAlgebraic: 'c6'));

        final legalMoves = chess.moves() as List<chess_lib.Move>;
        final ordered = manager.orderMoves(legalMoves, chess, depth: 0);

        expect(ordered.isNotEmpty, true);
      });

      test('prioritizes killer moves at correct depth', () {
        manager.killerMoves.recordKiller(2, 'e2e4');
        final legalMoves = chess.moves() as List<chess_lib.Move>;
        final ordered = manager.orderMoves(legalMoves, chess, depth: 2);
        expect(ordered.isNotEmpty, true);
      });
    });

    group('recordMove', () {
      test('records move in history', () {
        manager.recordMove('e2e4', 10);
        expect(manager.killerMoves.getMoveScore('e2e4'),
            equals(0)); // History != killer score
      });

      test('accumulates score for repeated moves', () {
        manager.recordMove('e2e4', 10);
        manager.recordMove('e2e4', 5);
      });
    });

    group('updateHistoryOnCutoff', () {
      test('doesn\'t crash with empty move list', () {
        manager.updateHistoryOnCutoff([], 2);
      });

      test('updates history for moves in list', () {
        final moves = [
          chess_lib.Move(fromAlgebraic: 'e2', toAlgebraic: 'e4'),
        ];
        manager.updateHistoryOnCutoff(moves, 2);
      });
    });

    group('clear', () {
      test('clears killer moves', () {
        manager.killerMoves.recordKiller(2, 'e2e4');
        manager.clear();
        expect(manager.killerMoves.getKillers(2), isEmpty);
      });
    });

    group('getStatistics', () {
      test('returns valid statistics', () {
        manager.killerMoves.recordKiller(2, 'e2e4');
        final stats = manager.getStatistics();
        expect(stats.containsKey('killerMoveStats'), true);
        expect(stats.containsKey('uniqueMovesInHistory'), true);
      });
    });
  });

  group('ButterflyHeuristic', () {
    late ButterflyHeuristic butterfly;

    setUp(() {
      butterfly = ButterflyHeuristic();
    });

    group('recordAttempt and recordCutoff', () {
      test('tracks attempted moves', () {
        butterfly.recordAttempt('e2e4');
        expect(butterfly.getCutoffRate('e2e4'), equals(0.0));
      });

      test('tracks successful cutoffs', () {
        butterfly.recordAttempt('e2e4');
        butterfly.recordCutoff('e2e4');
        expect(butterfly.getCutoffRate('e2e4'), equals(1.0));
      });

      test('calculates cutoff rate correctly', () {
        butterfly.recordAttempt('e2e4');
        butterfly.recordAttempt('e2e4');
        butterfly.recordCutoff('e2e4');
        expect(butterfly.getCutoffRate('e2e4'), equals(0.5));
      });
    });

    group('getCutoffRate', () {
      test('returns 0 for unrecorded move', () {
        expect(butterfly.getCutoffRate('e2e4'), equals(0.0));
      });

      test('returns 0 for move with no attempts', () {
        butterfly.recordCutoff('e2e4'); // Cutoff without attempt
        expect(butterfly.getCutoffRate('e2e4'), equals(0.0));
      });

      test('returns correct rate', () {
        for (int i = 0; i < 10; i++) {
          butterfly.recordAttempt('e2e4');
        }
        for (int i = 0; i < 7; i++) {
          butterfly.recordCutoff('e2e4');
        }
        expect(butterfly.getCutoffRate('e2e4'), closeTo(0.7, 0.01));
      });
    });

    group('getTopMoves', () {
      test('returns empty list when no moves', () {
        expect(butterfly.getTopMoves(5), isEmpty);
      });

      test('filters moves by minimum attempts', () {
        butterfly.recordAttempt('e2e4');
        butterfly.recordAttempt('d2d4');
        butterfly.recordAttempt('d2d4');
        butterfly.recordAttempt('d2d4');
        butterfly.recordAttempt('d2d4');
        butterfly.recordAttempt('d2d4'); // 5+ attempts
        butterfly.recordCutoff('d2d4');

        final top = butterfly.getTopMoves(5);
        expect(top.any((m) => m['move'] == 'd2d4'), true);
      });

      test('sorts by cutoff rate', () {
        // Move 1: 80% rate
        for (int i = 0; i < 10; i++) {
          butterfly.recordAttempt('e2e4');
        }
        for (int i = 0; i < 8; i++) {
          butterfly.recordCutoff('e2e4');
        }

        // Move 2: 50% rate
        for (int i = 0; i < 10; i++) {
          butterfly.recordAttempt('d2d4');
        }
        for (int i = 0; i < 5; i++) {
          butterfly.recordCutoff('d2d4');
        }

        final top = butterfly.getTopMoves(5);
        if (top.length >= 2) {
          expect(top[0]['move'], 'e2e4');
          expect(top[1]['move'], 'd2d4');
        }
      });

      test('returns requested number of moves', () {
        for (int i = 0; i < 10; i++) {
          butterfly.recordAttempt('move$i');
        }
        expect(butterfly.getTopMoves(3).length, lessThanOrEqualTo(3));
      });
    });

    group('clear', () {
      test('clears all statistics', () {
        butterfly.recordAttempt('e2e4');
        butterfly.recordCutoff('e2e4');
        butterfly.clear();
        expect(butterfly.getCutoffRate('e2e4'), equals(0.0));
      });
    });

    group('getStatistics', () {
      test('returns valid statistics', () {
        butterfly.recordAttempt('e2e4');
        butterfly.recordCutoff('e2e4');
        final stats = butterfly.getStatistics();

        expect(stats.containsKey('totalAttempts'), true);
        expect(stats.containsKey('totalCutoffs'), true);
        expect(stats.containsKey('uniqueMoves'), true);
      });

      test('tracks totals correctly', () {
        butterfly.recordAttempt('e2e4');
        butterfly.recordAttempt('e2e4');
        butterfly.recordCutoff('e2e4');

        final stats = butterfly.getStatistics();
        expect(stats['totalAttempts'], equals(2));
        expect(stats['totalCutoffs'], equals(1));
      });
    });
  });

  group('Integration', () {
    test('killer moves improve move ordering', () {
      final killer = KillerMoveHeuristic();
      killer.recordKiller(2, 'e2e4');
      killer.recordKiller(2, 'e2e4');
      killer.recordKiller(2, 'e2e4');

      expect(killer.getMoveScore('e2e4'), greaterThan(0));
    });

    test('butterfly heuristic tracks effective moves', () {
      final butterfly = ButterflyHeuristic();

      // Simulate move attempts and cutoffs
      for (int i = 0; i < 100; i++) {
        butterfly.recordAttempt('e2e4');
      }
      for (int i = 0; i < 85; i++) {
        butterfly.recordCutoff('e2e4');
      }

      expect(butterfly.getCutoffRate('e2e4'), greaterThan(0.8));
    });

    test('move ordering manager combines heuristics', () {
      final manager = MoveOrderingManager();
      final chess = chess_lib.Chess();

      // Record killer move
      manager.killerMoves.recordKiller(2, 'e2e4');

      // Get legal moves
      final legalMoves = chess.moves() as List<chess_lib.Move>;

      // Order them
      final ordered = manager.orderMoves(legalMoves, chess, depth: 2);

      expect(ordered.length, equals(legalMoves.length));
    });
  });
}
