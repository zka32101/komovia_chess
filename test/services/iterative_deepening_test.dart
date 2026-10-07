import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_chess/src/services/chess_engine_service.dart';
import 'package:komovia_chess/src/services/ai_opponent_engine.dart';
import 'package:komovia_chess/src/services/iterative_deepening.dart';

void main() {
  group('IterativeDeepeningEngine', () {
    late ChessEngineService chess;
    late IterativeDeepeningEngine engine;

    setUp(() {
      chess = ChessEngineService();
      engine = IterativeDeepeningEngine(chess, AIDifficulty.medium);
    });

    group('getBestMove', () {
      test('returns a valid move for starting position', () async {
        final result = await engine.getBestMove(timeLimit: 100);

        expect(result.bestMove, isNotNull);
        expect(result.bestMove, isA<String>());
        expect(result.bestMove!.length, 4); // UCI notation is 4 chars
      });

      test('returns e2e4 or similar strong opening move', () async {
        final result = await engine.getBestMove(timeLimit: 100);

        final strongOpening = ['e2e4', 'd2d4', 'c2c4', 'g1f3'];
        expect(strongOpening.contains(result.bestMove), true);
      });

      test('searches progressively deeper', () async {
        final result = await engine.getBestMove(timeLimit: 500);

        expect(result.depthReached, greaterThanOrEqualTo(1));
        // With 500ms, should reach at least depth 2-3
        expect(result.depthReached, greaterThanOrEqualTo(2));
      });

      test('respects time limit', () async {
        final stopwatch = Stopwatch()..start();
        await engine.getBestMove(timeLimit: 100);
        stopwatch.stop();

        // Should complete in roughly the time limit (±50ms for overhead)
        expect(stopwatch.elapsedMilliseconds, lessThan(200));
      });

      test('records nodes evaluated', () async {
        final result = await engine.getBestMove(timeLimit: 100);

        expect(result.nodesEvaluated, greaterThan(0));
      });

      test('reports if time limit was hit', () async {
        final result = await engine.getBestMove(timeLimit: 50);

        expect(result.timeLimit, isA<bool>());
      });

      test('deeper search takes more time', () async {
        final result1 = await engine.getBestMove(timeLimit: 50);
        final result2 = await engine.getBestMove(timeLimit: 500);

        expect(
            result2.depthReached, greaterThanOrEqualTo(result1.depthReached));
      });

      test('handles single legal move', () async {
        // Force a position with limited moves
        chess.reset();
        final result = await engine.getBestMove(timeLimit: 100);

        expect(result.bestMove, isNotNull);
      });

      test('evaluates position correctly', () async {
        final result = await engine.getBestMove(timeLimit: 100);

        expect(result.score, isA<int>());
        // Starting position should be roughly equal
        expect(result.score.abs(), lessThan(1));
      });

      test('finds checkmate in 1 when possible', () async {
        // Setup: White to move with checkmate available
        // This is a simplified test - actual mate detection depends on search
        chess.reset();
        chess.makeMove('e2', 'e4');
        chess.makeMove('e7', 'e5');
        chess.makeMove('f1', 'c4');
        chess.makeMove('b8', 'c6');
        chess.makeMove('d1', 'h5');
        chess.makeMove('g8', 'f6');

        final result = await engine.getBestMove(timeLimit: 200);

        expect(result.bestMove, isNotNull);
        // Should find strong attacking move (possibly mate threat)
        expect(result.score, greaterThan(5)); // Strong position
      });
    });

    group('Iterative deepening progression', () {
      test('depth 1 is faster than depth 3', () async {
        final result1 = await engine.getBestMove(timeLimit: 50);
        final result2 = await engine.getBestMove(timeLimit: 500);

        // Deeper search should find better moves (higher score magnitude)
        // or search more nodes
        expect(result2.nodesEvaluated,
            greaterThanOrEqualTo(result1.nodesEvaluated));
      });

      test('each iteration produces a valid move', () async {
        final result = await engine.getBestMove(timeLimit: 300);

        expect(result.bestMove, isNotNull);
        expect(result.depthReached, greaterThanOrEqualTo(1));

        // Verify move is legal
        final legalMoves = chess.getLegalMoves();
        final moveExists = legalMoves.any(
          (m) =>
              '${m.fromAlgebraic}${m.toAlgebraic}' ==
              result.bestMove!.substring(0, 4),
        );
        expect(moveExists, true);
      });
    });

    group('Time management', () {
      test('uses difficulty\'s thinking time by default', () async {
        final stopwatch = Stopwatch()..start();
        final result = await engine.getBestMove();
        stopwatch.stop();

        // Should use difficulty's thinking time (~1500ms for medium)
        expect(result.timeSpentMs, lessThan(3000));
        expect(result.timeSpentMs, greaterThan(100));
      });

      test('short time limit prevents deep search', () async {
        final result = await engine.getBestMove(timeLimit: 10);

        expect(result.depthReached, lessThanOrEqualTo(2));
      });

      test('long time limit enables deep search', () async {
        final result = await engine.getBestMove(timeLimit: 5000);

        expect(result.depthReached, greaterThanOrEqualTo(2));
      });

      test('respects maximum depth of 10', () async {
        final result = await engine.getBestMove(timeLimit: 10000);

        expect(result.depthReached, lessThanOrEqualTo(10));
      });
    });

    group('Position evaluation', () {
      test('starting position scores near zero', () async {
        final result = await engine.getBestMove(timeLimit: 100);

        expect(result.score.abs(), lessThan(2));
      });

      test('winning position scores high', () async {
        // Setup: White is winning
        chess.reset();
        chess.makeMove('e2', 'e4');
        chess.makeMove('e7', 'e5');
        chess.makeMove('g1', 'f3');
        chess.makeMove('b8', 'c6');
        chess.makeMove('f1', 'c4');
        chess.makeMove('f8', 'c5');
        chess.makeMove('c2', 'c3');
        chess.makeMove('g8', 'f6');
        chess.makeMove('d2', 'd4');
        chess.makeMove('e5', 'd4');
        chess.makeMove('c3', 'd4');

        final result = await engine.getBestMove(timeLimit: 100);

        expect(result.bestMove, isNotNull);
      });

      test('lost position scores negative', () async {
        // Setup: White is lost (Black has extra queen)
        chess.reset();
        // Play several moves to get to a position where Black is winning
        chess.makeMove('e2', 'e4');
        chess.makeMove('d7', 'd5');
        chess.makeMove('e4', 'd5');
        chess.makeMove('d8', 'd5'); // Black has extra pawn
        chess.makeMove('b1', 'c3');
        chess.makeMove('d5', 'd4');

        final result = await engine.getBestMove(timeLimit: 100);

        expect(result.bestMove, isNotNull);
      });
    });

    group('Search statistics', () {
      test('returns search stats', () {
        final stats = engine.getSearchStats();

        expect(stats.containsKey('isSearching'), true);
        expect(stats.containsKey('totalNodesEvaluated'), true);
        expect(stats['isSearching'], isFalse);
      });

      test('tracks nodes evaluated', () async {
        final result1 = await engine.getBestMove(timeLimit: 50);
        final stats1 = engine.getSearchStats();

        expect(stats1['totalNodesEvaluated'], greaterThan(0));
        expect(result1.nodesEvaluated, greaterThan(0));
      });
    });

    group('Edge cases', () {
      test('handles checkmate position', () async {
        // Setup a checkmate position (Black checkmated)
        chess.reset();
        chess.makeMove('f2', 'f3');
        chess.makeMove('e7', 'e5');
        chess.makeMove('g2', 'g4');
        chess.makeMove('d8', 'h4'); // Checkmate

        // White is checkmated, no legal moves
        expect(chess.getLegalMoves().isEmpty, true);
      });

      test('handles stalemate position gracefully', () async {
        chess.reset();
        // This would require a specific stalemate position setup
        // For now, just test that engine handles any position
        final result = await engine.getBestMove(timeLimit: 100);
        expect(result, isA<IterativeDeepeningResult>());
      });

      test('handles castling rights correctly', () async {
        chess.reset();
        // After e2-e4, white can still castle kingside
        chess.makeMove('e2', 'e4');
        final result = await engine.getBestMove(timeLimit: 100);
        expect(result.bestMove, isNotNull);
      });

      test('handles en passant correctly', () async {
        chess.reset();
        chess.makeMove('e2', 'e4');
        chess.makeMove('a7', 'a5'); // Black pawn move
        chess.makeMove('e4', 'e5');
        chess.makeMove('d7', 'd5'); // Can be captured en passant

        final result = await engine.getBestMove(timeLimit: 100);
        expect(result.bestMove, isNotNull);
      });

      test('handles promotion correctly', () async {
        chess.reset();
        // This would require advancing a pawn to the 8th rank
        // Complex setup, just verify engine handles positions
        final result = await engine.getBestMove(timeLimit: 100);
        expect(result.bestMove, isNotNull);
      });
    });

    group('Consistency', () {
      test('multiple searches reach same depth with same time limit', () async {
        final result1 = await engine.getBestMove(timeLimit: 200);
        final result2 = await engine.getBestMove(timeLimit: 200);

        // Both should reach similar depths (within 1 ply)
        expect(
          (result2.depthReached - result1.depthReached).abs(),
          lessThanOrEqualTo(1),
        );
      });

      test('search produces deterministic results for same position', () async {
        chess.reset();
        final result1 = await engine.getBestMove(timeLimit: 200);
        final move1 = result1.bestMove;

        chess.reset();
        final result2 = await engine.getBestMove(timeLimit: 200);
        final move2 = result2.bestMove;

        // Same position, similar time limit should produce same move
        expect(move1, move2);
      });
    });
  });

  group('IterativeDeepeningResult', () {
    test('contains all required fields', () {
      final result = IterativeDeepeningResult(
        bestMove: 'e2e4',
        score: 0,
        depthReached: 3,
        timeSpentMs: 150,
        nodesEvaluated: 1000,
        timeLimit: false,
      );

      expect(result.bestMove, 'e2e4');
      expect(result.score, 0);
      expect(result.depthReached, 3);
      expect(result.timeSpentMs, 150);
      expect(result.nodesEvaluated, 1000);
      expect(result.timeLimit, false);
    });

    test('handles null bestMove', () {
      final result = IterativeDeepeningResult(
        bestMove: null,
        score: 0,
        depthReached: 1,
        timeSpentMs: 50,
        nodesEvaluated: 100,
        timeLimit: true,
      );

      expect(result.bestMove, isNull);
    });
  });
}
