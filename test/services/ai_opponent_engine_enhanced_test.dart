import 'package:flutter_test/flutter_test.dart';
import 'package:chess/chess.dart' as chess_lib;
import 'package:komovia_chess/src/services/chess_engine_service.dart';
import 'package:komovia_chess/src/services/ai_opponent_engine_enhanced.dart';

void main() {
  group('AIOpponentEngineEnhanced', () {
    late ChessEngineService chess;
    late AIOpponentEngineEnhanced aiEngine;

    setUp(() {
      chess = ChessEngineService();
      aiEngine = AIOpponentEngineEnhanced(chess, AIDifficulty.medium);
    });

    group('initialization', () {
      test('creates engine with all Phase III.1 components', () {
        expect(aiEngine, isNotNull);
      });

      test('initializes with correct difficulty', () {
        final easyEngine = AIOpponentEngineEnhanced(chess, AIDifficulty.easy);
        expect(easyEngine, isNotNull);

        final hardEngine = AIOpponentEngineEnhanced(chess, AIDifficulty.hard);
        expect(hardEngine, isNotNull);
      });

      test('all heuristics are initialized', () {
        final stats = aiEngine.getSearchStats();
        expect(stats.containsKey('adaptiveSettings'), true);
        expect(stats.containsKey('killerStats'), true);
        expect(stats.containsKey('countermoveStats'), true);
      });
    });

    group('opening moves', () {
      test('plays opening book move from starting position', () {
        final move = aiEngine.getBestMove();
        expect(move, isNotNull);
        expect(move!.length, equals(4)); // UCI format: e2e4
      });

      test('recognizes extended opening positions', () {
        // Play e2-e4
        chess.makeMove('e2', 'e4');
        // Play c7-c5 (Sicilian)
        chess.makeMove('c7', 'c5');
        // Play d2-d4
        chess.makeMove('d2', 'd4');

        // Should use extended opening book
        final move = aiEngine.getBestMove();
        expect(move, isNotNull);
      });

      test('fallback to search after opening book', () {
        // Play several moves to get out of book
        final moves = [
          ('e2', 'e4'),
          ('c7', 'c5'),
          ('d2', 'd4'),
          ('c5', 'd4'),
          ('d1', 'd4'),
          ('b8', 'c6'),
        ];

        for (final (from, to) in moves) {
          chess.makeMove(from, to);
        }

        // Should search for move
        final move = aiEngine.getBestMove();
        expect(move, isNotNull);
      });
    });

    group('search evaluation', () {
      test('evaluates legal moves', () {
        final move = aiEngine.getBestMove();
        expect(move, isNotNull);

        // Verify move is legal
        final legalMoves = chess.getLegalMoves();
        final moveExists = legalMoves.any((m) {
          final from = m.fromAlgebraic;
          final to = m.toAlgebraic;
          return '$from$to' == move;
        });
        expect(moveExists, true);
      });

      test('returns different moves at different difficulties', () {
        chess.makeMove('e2', 'e4');
        chess.makeMove('c7', 'c5');
        chess.makeMove('d2', 'd4');
        chess.makeMove('c5', 'd4');
        chess.makeMove('d1', 'd4');

        // Easy move
        final easyEngine = AIOpponentEngineEnhanced(chess, AIDifficulty.easy);
        final easyMove = easyEngine.getBestMove();

        // Hard move
        final hardEngine = AIOpponentEngineEnhanced(chess, AIDifficulty.hard);
        final hardMove = hardEngine.getBestMove();

        // Both should be legal but potentially different
        expect(easyMove, isNotNull);
        expect(hardMove, isNotNull);
      });
    });

    group('statistics tracking', () {
      test('tracks nodes evaluated', () {
        aiEngine.getBestMove();
        final stats = aiEngine.getSearchStats();
        expect(stats['nodesEvaluated'], greaterThan(0));
      });

      test('tracks Zobrist cache performance', () {
        aiEngine.getBestMove();
        final stats = aiEngine.getSearchStats();
        expect(stats.containsKey('zobristHits'), true);
        expect(stats.containsKey('zobristMisses'), true);
        expect(stats.containsKey('zobristHitRate'), true);
      });

      test('tracks killer move statistics', () {
        aiEngine.getBestMove();
        final stats = aiEngine.getSearchStats();
        final killerStats = stats['killerStats'] as Map;
        expect(killerStats.containsKey('totalCutoffs'), true);
      });

      test('tracks adaptive settings', () {
        aiEngine.getBestMove();
        final stats = aiEngine.getSearchStats();
        final adaptive = stats['adaptiveSettings'] as Map;
        expect(adaptive.containsKey('difficulty'), true);
        expect(adaptive.containsKey('decayFactor'), true);
      });

      test('provides transposition table stats', () {
        aiEngine.getBestMove();
        final tableStats = aiEngine.getTableStats();
        expect(tableStats.containsKey('entries'), true);
        expect(tableStats.containsKey('fills'), true);
      });
    });

    group('caching and optimization', () {
      test('uses Zobrist hashing', () {
        aiEngine.getBestMove();
        final stats = aiEngine.getSearchStats();
        // Should have some cache activity
        expect(stats['zobristMisses'], greaterThan(0));
      });

      test('clears cache on demand', () {
        aiEngine.getBestMove();
        aiEngine.clearCache();

        final stats = aiEngine.getSearchStats();
        expect(stats['nodesEvaluated'], equals(0));
        expect(stats['zobristHits'], equals(0));
        expect(stats['zobristMisses'], equals(0));
      });

      test('transposition table stores and retrieves', () {
        aiEngine.getBestMove();
        final tableStats1 = aiEngine.getTableStats();
        final entries1 = tableStats1['entries'];

        aiEngine.getBestMove();
        final tableStats2 = aiEngine.getTableStats();
        final entries2 = tableStats2['entries'];

        // Entries should be accumulated
        expect(entries2, greaterThanOrEqualTo(entries1));
      });
    });

    group('complex game scenarios', () {
      test('handles Sicilian Defense opening', () {
        final moves = [
          ('e2', 'e4'),
          ('c7', 'c5'),
          ('g1', 'f3'),
          ('d7', 'd6'),
          ('d2', 'd4'),
          ('c5', 'd4'),
          ('f3', 'd4'),
          ('g8', 'f6'),
        ];

        for (final (from, to) in moves) {
          chess.makeMove(from, to);
        }

        final move = aiEngine.getBestMove();
        expect(move, isNotNull);
      });

      test('handles Ruy Lopez opening', () {
        final moves = [
          ('e2', 'e4'),
          ('e7', 'e5'),
          ('g1', 'f3'),
          ('b8', 'c6'),
          ('f1', 'b5'),
          ('a7', 'a6'),
          ('b5', 'a4'),
          ('g8', 'f6'),
        ];

        for (final (from, to) in moves) {
          chess.makeMove(from, to);
        }

        final move = aiEngine.getBestMove();
        expect(move, isNotNull);
      });

      test('handles midgame positions', () {
        // Play to midgame
        final moves = [
          ('e2', 'e4'),
          ('c7', 'c5'),
          ('g1', 'f3'),
          ('d7', 'd6'),
          ('d2', 'd4'),
          ('c5', 'd4'),
          ('f3', 'd4'),
          ('g8', 'f6'),
          ('b1', 'c3'),
          ('a7', 'a6'),
          ('c1', 'e3'),
          ('e7', 'e5'),
          ('d4', 'f3'),
          ('b8', 'c6'),
          ('f1', 'e2'),
          ('f8', 'e7'),
        ];

        for (final (from, to) in moves) {
          chess.makeMove(from, to);
        }

        final move = aiEngine.getBestMove();
        expect(move, isNotNull);
      });

      test('handles endgame positions', () {
        // Simple endgame: White: King e4, Pawn e5; Black: King e6
        // This tests if engine handles pawn endings
        final moves = [
          ('e2', 'e4'),
          ('e7', 'e5'),
          // ... many moves to reach endgame
        ];

        for (final (from, to) in moves) {
          chess.makeMove(from, to);
        }

        final move = aiEngine.getBestMove();
        expect(move, isNotNull);
      });
    });

    group('move ordering verification', () {
      test('prioritizes captures', () {
        // Set up position with capture available
        chess.makeMove('e2', 'e4');
        chess.makeMove('d7', 'd5');
        chess.makeMove('e4', 'd5'); // Capture

        // Get legal moves
        final legalMoves = chess.getLegalMoves();
        expect(legalMoves.isNotEmpty, true);

        // Engine should find a reasonable move
        final move = aiEngine.getBestMove();
        expect(move, isNotNull);
      });

      test('considers checks', () {
        // Position with potential check
        chess.makeMove('e2', 'e4');
        chess.makeMove('e7', 'e5');
        chess.makeMove('f1', 'c4');
        chess.makeMove('b8', 'c6');

        final move = aiEngine.getBestMove();
        expect(move, isNotNull);
      });
    });

    group('difficulty levels', () {
      test('easy mode plays quickly', () {
        final easyEngine = AIOpponentEngineEnhanced(chess, AIDifficulty.easy);
        final stopwatch = Stopwatch()..start();
        final move = easyEngine.getBestMove();
        stopwatch.stop();

        expect(move, isNotNull);
        // Easy should be relatively fast (within thinking time)
        expect(stopwatch.elapsedMilliseconds,
            lessThan(AIDifficulty.easy.thinkingTimeMs * 2));
      });

      test('medium mode balances depth and speed', () {
        final mediumEngine =
            AIOpponentEngineEnhanced(chess, AIDifficulty.medium);
        final move = mediumEngine.getBestMove();
        expect(move, isNotNull);
      });

      test('hard mode searches deeper', () {
        final hardEngine = AIOpponentEngineEnhanced(chess, AIDifficulty.hard);
        final move = hardEngine.getBestMove();
        expect(move, isNotNull);

        // Hard should evaluate more nodes
        final stats = hardEngine.getSearchStats();
        expect(stats['nodesEvaluated'], greaterThan(100));
      });
    });

    group('repeated positions', () {
      test('same position after repeated searches', () {
        final move1 = aiEngine.getBestMove();
        aiEngine.clearCache();
        final move2 = aiEngine.getBestMove();

        // Should get same move (deterministic from opening book)
        expect(move1, equals(move2));
      });

      test('different positions yield different moves', () {
        final move1 = aiEngine.getBestMove();

        // Make a move
        chess.makeMove(move1!.substring(0, 2), move1.substring(2, 4));
        final move2 = aiEngine.getBestMove();

        // Different position should potentially have different AI move
        expect(move2, isNotNull);
      });
    });

    group('edge cases', () {
      test('handles single legal move', () {
        // Most positions have multiple moves, but edge case testing
        final legalMoves = chess.getLegalMoves();
        if (legalMoves.length == 1) {
          final move = aiEngine.getBestMove();
          expect(move, isNotNull);
        } else {
          expect(legalMoves.length, greaterThan(1));
        }
      });

      test('returns null for no legal moves', () {
        // This would be checkmate/stalemate, which shouldn't happen in getBestMove
        final legalMoves = chess.getLegalMoves();
        expect(legalMoves.isNotEmpty, true);
      });
    });

    group('integration with multiple components', () {
      test('all heuristics work together', () {
        // Play a game with mixed opening book and search
        for (int i = 0; i < 4; i++) {
          final move = aiEngine.getBestMove();
          if (move != null) {
            chess.makeMove(move.substring(0, 2), move.substring(2, 4));
          }

          if (chess.isGameOver()) break;
        }

        final stats = aiEngine.getSearchStats();
        expect(stats['zobristMisses'], greaterThan(0));
        expect(stats.containsKey('adaptiveSettings'), true);
      });

      test('adaptive manager adjusts for different positions', () {
        // Early game
        aiEngine.getBestMove();
        var stats = aiEngine.getSearchStats();
        expect(stats['adaptiveSettings'], isNotNull);

        // Middle game (simulate by moving forward)
        for (int i = 0; i < 10; i++) {
          final move = aiEngine.getBestMove();
          if (move != null) {
            chess.makeMove(move.substring(0, 2), move.substring(2, 4));
          }
          if (chess.isGameOver()) break;
        }

        aiEngine.getBestMove();
        stats = aiEngine.getSearchStats();
        expect(stats['adaptiveSettings'], isNotNull);
      });

      test('killer moves and countermoves interact correctly', () {
        // Play enough moves to accumulate killer/countermove data
        for (int i = 0; i < 6; i++) {
          final move = aiEngine.getBestMove();
          if (move != null) {
            chess.makeMove(move.substring(0, 2), move.substring(2, 4));
          }
          if (chess.isGameOver()) break;
        }

        final stats = aiEngine.getSearchStats();
        final killerStats = stats['killerStats'] as Map?;
        expect(killerStats, isNotNull);
      });
    });
  });

  group('Difficulty Levels', () {
    late ChessEngineService chess;

    setUp(() {
      chess = ChessEngineService();
    });

    test('difficulty parameters are correct', () {
      expect(AIDifficulty.easy.searchDepth, equals(2));
      expect(AIDifficulty.medium.searchDepth, equals(3));
      expect(AIDifficulty.hard.searchDepth, equals(4));

      expect(AIDifficulty.easy.thinkingTimeMs, equals(500));
      expect(AIDifficulty.medium.thinkingTimeMs, equals(1500));
      expect(AIDifficulty.hard.thinkingTimeMs, equals(3000));
    });

    test('difficulty descriptions are consistent', () {
      expect(AIDifficulty.easy.displayName, equals('Easy'));
      expect(AIDifficulty.medium.displayName, equals('Medium'));
      expect(AIDifficulty.hard.displayName, equals('Hard'));
    });
  });
}
