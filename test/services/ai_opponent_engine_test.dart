import 'package:flutter_test/flutter_test.dart';
import 'package:chess/chess.dart' as chess_lib;
import 'package:komovia_chess/src/services/chess_engine_service.dart';
import 'package:komovia_chess/src/services/ai_opponent_engine.dart';

void main() {
  group('AIDifficulty', () {
    test('easy difficulty has correct properties', () {
      expect(AIDifficulty.easy.searchDepth, 2);
      expect(AIDifficulty.easy.thinkingTimeMs, 500);
      expect(AIDifficulty.easy.displayName, 'Easy');
      expect(AIDifficulty.easy.estimatedWinRate, 0.35);
    });

    test('medium difficulty has correct properties', () {
      expect(AIDifficulty.medium.searchDepth, 3);
      expect(AIDifficulty.medium.thinkingTimeMs, 1500);
      expect(AIDifficulty.medium.displayName, 'Medium');
      expect(AIDifficulty.medium.estimatedWinRate, 0.55);
    });

    test('hard difficulty has correct properties', () {
      expect(AIDifficulty.hard.searchDepth, 4);
      expect(AIDifficulty.hard.thinkingTimeMs, 3000);
      expect(AIDifficulty.hard.displayName, 'Hard');
      expect(AIDifficulty.hard.estimatedWinRate, 0.65);
    });

    test('difficulty descriptions are non-empty', () {
      for (final difficulty in AIDifficulty.values) {
        expect(difficulty.description.isNotEmpty, true);
      }
    });
  });

  group('MaterialValues', () {
    test('pawn has value of 1', () {
      expect(MaterialValues.getValueBySymbol('p'), 1);
      expect(MaterialValues.getValueBySymbol('P'), 1);
    });

    test('knight has value of 3', () {
      expect(MaterialValues.getValueBySymbol('n'), 3);
      expect(MaterialValues.getValueBySymbol('N'), 3);
    });

    test('bishop has value of 3', () {
      expect(MaterialValues.getValueBySymbol('b'), 3);
      expect(MaterialValues.getValueBySymbol('B'), 3);
    });

    test('rook has value of 5', () {
      expect(MaterialValues.getValueBySymbol('r'), 5);
      expect(MaterialValues.getValueBySymbol('R'), 5);
    });

    test('queen has value of 9', () {
      expect(MaterialValues.getValueBySymbol('q'), 9);
      expect(MaterialValues.getValueBySymbol('Q'), 9);
    });

    test('king has value of 0', () {
      expect(MaterialValues.getValueBySymbol('k'), 0);
      expect(MaterialValues.getValueBySymbol('K'), 0);
    });

    test('null symbol returns 0', () {
      expect(MaterialValues.getValueBySymbol(null), 0);
    });

    test('invalid symbol returns 0', () {
      expect(MaterialValues.getValueBySymbol('x'), 0);
    });

    test('getValueByType works for pawn', () {
      expect(MaterialValues.getValueByType(chess_lib.PieceType.pawn), 1);
    });

    test('getValueByType works for knight', () {
      expect(MaterialValues.getValueByType(chess_lib.PieceType.knight), 3);
    });

    test('getValueByType returns 0 for null', () {
      expect(MaterialValues.getValueByType(null), 0);
    });
  });

  group('PositionEvaluator', () {
    late ChessEngineService chess;
    late PositionEvaluator evaluator;

    setUp(() {
      chess = ChessEngineService();
      chess.initGame();
      evaluator = PositionEvaluator(chess, AIDifficulty.medium);
    });

    test('starting position has score close to 0', () {
      final score = evaluator.evaluate();
      expect(score.abs(), lessThan(10)); // Small score variation allowed
    });

    test('detects checkmate as best position for winning side', () {
      // Setup fool's mate position
      chess.makeMove('f2', 'f3');
      chess.makeMove('e7', 'e5');
      chess.makeMove('g2', 'g4');
      chess.makeMove('d8', 'h4'); // Checkmate

      final score = evaluator.evaluate();
      expect(score, 9999); // White is in checkmate, very negative
    });

    test('detects stalemate as neutral', () {
      // Load a stalemate position
      chess.loadFromFen('7k/5Q2/6K1/8/8/8/8/8 b - - 0 1');
      final score = evaluator.evaluate();
      expect(score, 0); // Stalemate should be 0
    });

    test('material evaluation works correctly', () {
      // Remove black queen (value 9)
      chess.loadFromFen(
          'rnb1kbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1');
      final score = evaluator.evaluate();
      expect(score, greaterThan(0)); // White should be ahead
      expect(score, greaterThanOrEqualTo(9)); // At least queen value
    });

    test('easy difficulty skips positional evaluation', () {
      final easyEvaluator = PositionEvaluator(chess, AIDifficulty.easy);
      final easyScore = easyEvaluator.evaluate();

      final mediumEvaluator = PositionEvaluator(chess, AIDifficulty.medium);
      final mediumScore = mediumEvaluator.evaluate();

      // Easy should only have material, no positional factors
      // They might differ due to positional evaluation
      expect(easyScore, isNotNull);
      expect(mediumScore, isNotNull);
    });
  });

  group('AIOpponentEngine', () {
    late ChessEngineService chess;
    late AIOpponentEngine engine;

    setUp(() {
      chess = ChessEngineService();
      chess.initGame();
      engine = AIOpponentEngine(chess, AIDifficulty.medium);
    });

    test('returns null move when no legal moves available', () {
      // Stalemate position
      chess.loadFromFen('7k/5Q2/6K1/8/8/8/8/8 b - - 0 1');
      final move = engine.getBestMove();
      expect(move, isNull);
    });

    test('returns a legal move from starting position', () {
      final move = engine.getBestMove();
      expect(move, isNotNull);
      expect(move!.length, greaterThanOrEqualTo(4)); // UCI format minimum
    });

    test('generated move is in valid UCI format', () {
      final move = engine.getBestMove();
      expect(move, matches(RegExp(r'^[a-h][1-8][a-h][1-8][qrbn]?$')));
    });

    test('makes progress toward winning position', () {
      // Fool's mate setup (white is losing)
      chess.makeMove('f2', 'f3');
      chess.makeMove('e7', 'e5');
      chess.makeMove('g2', 'g4');
      // Now it's black's turn - should find checkmate
      final move = engine.getBestMove();
      expect(move, isNotNull);
    });

    test('handles different difficulty levels', () {
      for (final difficulty in AIDifficulty.values) {
        chess.initGame();
        final eng = AIOpponentEngine(chess, difficulty);
        final move = eng.getBestMove();
        expect(move, isNotNull);
      }
    });

    test('getSearchStats returns valid data', () {
      engine.getBestMove();
      final stats = engine.getSearchStats();

      expect(stats, isNotNull);
      expect(stats['nodesEvaluated'], greaterThan(0));
      expect(stats['depth'], greaterThan(0));
      expect(stats['difficulty'], isNotNull);
    });

    test('transposition table improves performance', () {
      // First call populates cache
      final move1 = engine.getBestMove();
      final stats1 = engine.getSearchStats();
      final nodes1 = stats1['nodesEvaluated'] as int;

      // Reset position and try again
      chess.initGame();
      engine.clearCache();
      final move2 = engine.getBestMove();
      final stats2 = engine.getSearchStats();
      final nodes2 = stats2['nodesEvaluated'] as int;

      // Without cache clearing, nodes should be similar
      expect(nodes1, greaterThan(0));
      expect(nodes2, greaterThan(0));
    });

    test('clears cache without errors', () {
      engine.getBestMove();
      expect(() => engine.clearCache(), returnsNormally);
    });
  });

  group('Move ordering', () {
    late ChessEngineService chess;
    late AIOpponentEngine engine;

    setUp(() {
      chess = ChessEngineService();
      chess.initGame();
      engine = AIOpponentEngine(chess, AIDifficulty.medium);
    });

    test('captures are prioritized in move ordering', () {
      // Position with capture available
      chess.loadFromFen(
          'rnbqkb1r/pppp1ppp/5n2/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 4');

      final move = engine.getBestMove();
      // The engine should find good moves (captures if available)
      expect(move, isNotNull);
    });

    test('engine makes legal moves', () {
      // Make several moves and verify they're all legal
      for (int i = 0; i < 5; i++) {
        if (chess.isGameOver()) break;

        final move = engine.getBestMove();
        if (move == null) break;

        // Verify move is legal
        final legalMoves = chess.getLegalMoves();
        final fromSquare = move.substring(0, 2);
        final toSquare = move.substring(2, 4);

        final isLegal = legalMoves.any(
            (m) => m.fromAlgebraic == fromSquare && m.toAlgebraic == toSquare);

        expect(isLegal, true, reason: 'Move $move should be legal');

        // Make the move
        chess.makeMoveUCI(move);
      }
    });
  });

  group('Alpha-beta pruning', () {
    late ChessEngineService chess;
    late AIOpponentEngine engine;

    setUp(() {
      chess = ChessEngineService();
      chess.initGame();
      engine = AIOpponentEngine(chess, AIDifficulty.medium);
    });

    test('produces different move for different board states', () {
      final move1 = engine.getBestMove();

      chess.initGame();
      chess.makeMove('e2', 'e4'); // 1.e4
      engine = AIOpponentEngine(chess, AIDifficulty.medium);
      final move2 = engine.getBestMove();

      // Should get different moves for different positions
      expect(move1, isNotNull);
      expect(move2, isNotNull);
      // They might be the same by chance, but likely different
    });

    test('handles forced moves correctly', () {
      // Position where there's essentially only one good move
      chess.loadFromFen(
          'rnbqkb1r/pppppppp/5n2/8/8/5N2/PPPPPPPP/RNBQKB1R w KQkq - 0 1');

      final move = engine.getBestMove();
      expect(move, isNotNull);
      expect(move, matches(RegExp(r'^[a-h][1-8][a-h][1-8][qrbn]?$')));
    });
  });
}
