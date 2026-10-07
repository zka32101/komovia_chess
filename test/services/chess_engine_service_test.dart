import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_chess/src/services/chess_engine_service.dart';

void main() {
  group('ChessEngineService', () {
    late ChessEngineService chess;

    setUp(() {
      chess = ChessEngineService();
      chess.initGame();
    });

    group('initGame', () {
      test('initializes game with starting position', () {
        chess.initGame();
        expect(chess.getCurrentFen(), startsWith('rnbqkbnr'));
        expect(chess.isGameOver(), false);
      });

      test('initializes game with custom FEN', () {
        const customFen =
            'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1';
        chess.initGame(fen: customFen);
        expect(chess.getCurrentFen(), customFen);
      });

      test('resets game state on reinit', () {
        chess.makeMove('e2', 'e4');
        final firstFen = chess.getCurrentFen();

        chess.initGame();
        final resetFen = chess.getCurrentFen();

        expect(firstFen, isNot(resetFen));
        expect(resetFen, startsWith('rnbqkbnr'));
      });
    });

    group('makeMove', () {
      test('executes legal opening move', () {
        final result = chess.makeMove('e2', 'e4');
        expect(result, true);
        expect(chess.getCurrentFen(), contains('4P3'));
      });

      test('rejects illegal move', () {
        final result = chess.makeMove('e2', 'e5');
        expect(result, false);
      });

      test('handles pawn promotion', () {
        chess.initGame(fen: '8/P7/8/8/8/8/8/k6K w - - 0 1');
        final result = chess.makeMove('a7', 'a8', promotion: 'q');
        expect(result, true);
      });

      test('tracks move history', () {
        chess.makeMove('e2', 'e4');
        chess.makeMove('e7', 'e5');

        expect(chess.getCurrentMoveNumber(), 2);
      });
    });

    group('isLegalMove', () {
      test('recognizes legal pawn move', () {
        expect(chess.isLegalMove('e2', 'e4'), true);
        expect(chess.isLegalMove('e2', 'e3'), true);
      });

      test('recognizes illegal pawn move', () {
        expect(chess.isLegalMove('e2', 'e5'), false);
        expect(chess.isLegalMove('e2', 'd3'), false);
      });

      test('recognizes legal knight move', () {
        expect(chess.isLegalMove('g1', 'f3'), true);
        expect(chess.isLegalMove('g1', 'h3'), true);
      });
    });

    group('getLegalMoves', () {
      test('returns legal moves for starting position', () {
        final moves = chess.getLegalMoves();
        expect(moves, isNotEmpty);
        expect(moves.length, 20);
      });

      test('includes only legal moves', () {
        final moves = chess.getLegalMoves();
        for (final moveStr in moves) {
          expect(moveStr, matches(RegExp(r'^[a-h][1-8][a-h][1-8]')));
        }
      });
    });

    group('getCurrentFen', () {
      test('returns valid FEN string', () {
        final fen = chess.getCurrentFen();
        expect(fen, isNotEmpty);
        expect(fen.split(' ').length, 6);
      });

      test('updates FEN after move', () {
        final fenBefore = chess.getCurrentFen();
        chess.makeMove('e2', 'e4');
        final fenAfter = chess.getCurrentFen();

        expect(fenBefore, isNot(fenAfter));
      });
    });

    group('isGameOver', () {
      test('game not over at start', () {
        expect(chess.isGameOver(), false);
      });

      test('game continues with legal moves available', () {
        chess.makeMove('e2', 'e4');
        expect(chess.isGameOver(), false);
      });
    });

    group('getGameResult', () {
      test('returns null for ongoing game', () {
        expect(chess.getGameResult(), isNull);
      });
    });

    group('undoMove', () {
      test('reverts to previous position', () {
        final fenBefore = chess.getCurrentFen();
        chess.makeMove('e2', 'e4');
        chess.undoMove();
        final fenAfter = chess.getCurrentFen();

        expect(fenBefore, fenAfter);
      });

      test('does nothing when no moves made', () {
        final fen = chess.getCurrentFen();
        chess.undoMove();
        expect(chess.getCurrentFen(), fen);
      });
    });

    group('analyzePosition', () {
      test('returns position analysis for current board', () {
        final analysis = chess.analyzePosition();
        expect(analysis, isNotNull);
        expect(analysis.legalMovesCount, 20);
      });

      test('calculates material count', () {
        final analysis = chess.analyzePosition();
        expect(analysis.whiteMaterial, greaterThan(0));
        expect(analysis.blackMaterial, greaterThan(0));
        expect(analysis.whiteMaterial, analysis.blackMaterial);
      });
    });

    group('Performance', () {
      test('handles rapid moves efficiently', () {
        final stopwatch = Stopwatch()..start();

        for (int i = 0; i < 50; i++) {
          chess.makeMove('e2', 'e4');
          chess.undoMove();
        }

        stopwatch.stop();

        expect(stopwatch.elapsedMilliseconds, lessThan(500));
      });
    });
  });
}
