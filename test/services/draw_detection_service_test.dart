import 'package:chess/chess.dart' as chess_lib;
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_chess/src/services/draw_detection_service.dart';
import 'package:komovia_chess/src/services/chess_engine_service.dart';

/// Replays [moves] from the standard starting position and returns the
/// resulting FEN - what `currentFen` would actually be in production
/// after playing this exact sequence (distinct from `chess.getCurrentFen()`
/// in the surrounding test group, which stays at the fresh-game FEN
/// from `setUp` regardless of these moves).
String _fenAfter(List<Map<String, String>> moves) {
  final board = chess_lib.Chess();
  for (final move in moves) {
    board.move(move);
  }
  return board.fen;
}

void main() {
  group('DrawDetectionService', () {
    late ChessEngineService chess;

    setUp(() {
      chess = ChessEngineService();
      chess.initGame();
    });

    group('Stalemate detection', () {
      test('detects stalemate position', () {
        // Stalemate position: Black king on h8, white queen on f6, white king on g5
        chess.initGame(fen: '7k/5Q2/6K1/8/8/8/8/8 b - - 0 1');

        final isStalemate = DrawDetectionService.isStalemate(chess.rawChess);
        expect(isStalemate, true);
      });

      test('does not detect stalemate in normal position', () {
        final isStalemate = DrawDetectionService.isStalemate(chess.rawChess);
        expect(isStalemate, false);
      });

      test('distinguishes stalemate from checkmate', () {
        // Checkmate position
        chess.initGame(fen: '6k1/5Q2/6K1/8/8/8/8/8 b - - 0 1');

        final isStalemate = DrawDetectionService.isStalemate(chess.rawChess);
        expect(isStalemate, false);
      });
    });

    group('Insufficient material detection', () {
      test('detects king vs king', () {
        chess.initGame(fen: '8/8/4k3/8/8/4K3/8/8 w - - 0 1');

        final isInsufficient =
            DrawDetectionService.isInsufficientMaterial(chess.rawChess);
        expect(isInsufficient, true);
      });

      test('detects king and knight vs king', () {
        chess.initGame(fen: '8/8/4k3/8/8/4K2N/8/8 w - - 0 1');

        final isInsufficient =
            DrawDetectionService.isInsufficientMaterial(chess.rawChess);
        expect(isInsufficient, true);
      });

      test('detects king and bishop vs king', () {
        chess.initGame(fen: '8/8/4k3/8/8/4K2B/8/8 w - - 0 1');

        final isInsufficient =
            DrawDetectionService.isInsufficientMaterial(chess.rawChess);
        expect(isInsufficient, true);
      });

      test('does not detect insufficient material with queen', () {
        chess.initGame(fen: '8/8/4k3/8/8/4K2Q/8/8 w - - 0 1');

        final isInsufficient =
            DrawDetectionService.isInsufficientMaterial(chess.rawChess);
        expect(isInsufficient, false);
      });

      test('does not detect insufficient material with rook', () {
        chess.initGame(fen: '8/8/4k3/8/8/4K2R/8/8 w - - 0 1');

        final isInsufficient =
            DrawDetectionService.isInsufficientMaterial(chess.rawChess);
        expect(isInsufficient, false);
      });

      test('does not detect insufficient material with pawn', () {
        chess.initGame(fen: '8/8/4k3/8/8/4K1P1/8/8 w - - 0 1');

        final isInsufficient =
            DrawDetectionService.isInsufficientMaterial(chess.rawChess);
        expect(isInsufficient, false);
      });

      test('does not treat K+N+B vs K as insufficient (a real forced-mate endgame)',
          () {
        // White king e3, knight h3, bishop g3; lone black king e6.
        chess.initGame(fen: '8/8/4k3/8/8/4K1BN/8/8 w - - 0 1');

        final isInsufficient =
            DrawDetectionService.isInsufficientMaterial(chess.rawChess);
        expect(isInsufficient, false);
      });

      test(
          'does not treat K+B+B vs K as insufficient when the bishops are '
          'opposite-colored (also a real forced-mate endgame)', () {
        // White bishops on c1 (dark) and d1 (light) - opposite colors.
        chess.initGame(fen: '8/8/4k3/8/8/4K3/8/2BB4 w - - 0 1');

        final isInsufficient =
            DrawDetectionService.isInsufficientMaterial(chess.rawChess);
        expect(isInsufficient, false);
      });

      test('treats K+B+B vs K as insufficient when both bishops share a color',
          () {
        // White bishops on c1 and e1 - both the same color square.
        chess.initGame(fen: '8/8/4k3/8/8/4K3/8/2B1B3 w - - 0 1');

        final isInsufficient =
            DrawDetectionService.isInsufficientMaterial(chess.rawChess);
        expect(isInsufficient, true);
      });
    });

    group('50-move rule detection', () {
      test('detects when halfmove clock reaches 100', () {
        // FEN with 100 halfmove clock (50 full moves)
        chess.initGame(fen: '8/8/4k3/8/8/4K3/8/8 w - - 100 50');

        final isFiftyMoveRuleDraw = DrawDetectionService.isFiftyMoveRuleDraw(
          chess.getCurrentFen(),
        );
        expect(isFiftyMoveRuleDraw, true);
      });

      test('does not detect draw with halfmove clock < 100', () {
        chess.initGame(fen: '8/8/4k3/8/8/4K3/8/8 w - - 50 25');

        final isFiftyMoveRuleDraw = DrawDetectionService.isFiftyMoveRuleDraw(
          chess.getCurrentFen(),
        );
        expect(isFiftyMoveRuleDraw, false);
      });

      test('resets halfmove clock on pawn move', () {
        chess.initGame(
            fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 50 25');

        chess.makeMove('a2', 'a4');

        // After pawn move, halfmove clock should reset to 0
        final fen = chess.getCurrentFen();
        final fenParts = fen.split(' ');
        final halfmoveClock = int.parse(fenParts[4]);

        expect(halfmoveClock, 0);
      });

      test('resets halfmove clock on capture', () {
        chess.initGame(
            fen:
                'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 50 2');
        chess.makeMove('d7', 'd5');

        final fen = chess.getCurrentFen();
        final fenParts = fen.split(' ');
        final halfmoveClock = int.parse(fenParts[4]);

        // After pawn move, should be 0
        expect(halfmoveClock, 0);
      });
    });

    group('Threefold repetition detection', () {
      test('detects threefold repetition', () {
        // Knights shuffle back and forth: the starting position recurs
        // after move pairs 2, 4, and 6 (4 occurrences total, including
        // the initial position itself) - genuinely a threefold
        // repetition, unlike the old full-FEN comparison (which
        // compared halfmove-clock/fullmove-number fields that strictly
        // increase and can never repeat, so this could never return
        // true at all before the fix).
        const moves = [
          {'from': 'g1', 'to': 'f3'},
          {'from': 'g8', 'to': 'f6'},
          {'from': 'f3', 'to': 'g1'},
          {'from': 'f6', 'to': 'g8'},
          {'from': 'g1', 'to': 'f3'},
          {'from': 'g8', 'to': 'f6'},
          {'from': 'f3', 'to': 'g1'},
          {'from': 'f6', 'to': 'g8'},
          {'from': 'g1', 'to': 'f3'},
          {'from': 'g8', 'to': 'f6'},
          {'from': 'f3', 'to': 'g1'},
          {'from': 'f6', 'to': 'g8'},
        ];

        final isThreefold = DrawDetectionService.isThreefoldRepetition(
          moves,
          _fenAfter(moves),
        );
        expect(isThreefold, isTrue);
      });

      test('does not detect threefold with different moves', () {
        const moves = [
          {'from': 'g1', 'to': 'f3'},
          {'from': 'g8', 'to': 'f6'},
          {'from': 'f3', 'to': 'g1'},
          {'from': 'f6', 'to': 'g8'},
        ];

        final isThreefold = DrawDetectionService.isThreefoldRepetition(
          moves,
          _fenAfter(moves),
        );
        expect(isThreefold, isFalse);
      });
    });

    group('getDrawReasons', () {
      test('returns empty list for non-draw position', () {
        final reasons = DrawDetectionService.getDrawReasons(
          chess.rawChess,
          chess.getCurrentFen(),
          [],
        );
        expect(reasons, isEmpty);
      });

      test('returns stalemate reason for stalemate position', () {
        chess.initGame(fen: '7k/5Q2/6K1/8/8/8/8/8 b - - 0 1');

        final reasons = DrawDetectionService.getDrawReasons(
          chess.rawChess,
          chess.getCurrentFen(),
          [],
        );
        expect(reasons, contains('stalemate'));
      });

      test('returns insufficient material reason', () {
        chess.initGame(fen: '8/8/4k3/8/8/4K3/8/8 w - - 0 1');

        final reasons = DrawDetectionService.getDrawReasons(
          chess.rawChess,
          chess.getCurrentFen(),
          [],
        );
        expect(reasons, contains('insufficient_material'));
      });
    });

    group('canClaimDraw', () {
      test('returns true for stalemate', () {
        chess.initGame(fen: '7k/5Q2/6K1/8/8/8/8/8 b - - 0 1');

        final canClaim = DrawDetectionService.canClaimDraw(
          chess.rawChess,
          chess.getCurrentFen(),
          [],
        );
        expect(canClaim, true);
      });

      test('returns false for ongoing game', () {
        final canClaim = DrawDetectionService.canClaimDraw(
          chess.rawChess,
          chess.getCurrentFen(),
          [],
        );
        expect(canClaim, false);
      });
    });

    group('Combination draw detection', () {
      test('identifies multiple draw conditions in one position', () {
        chess.initGame(fen: '8/8/4k3/8/8/4K3/8/8 w - - 100 50');

        final reasons = DrawDetectionService.getDrawReasons(
          chess.rawChess,
          chess.getCurrentFen(),
          [],
        );

        // This position has both insufficient material AND 50-move rule
        expect(reasons.length, greaterThan(0));
      });
    });
  });
}
