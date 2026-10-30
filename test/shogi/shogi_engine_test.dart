import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_chess/src/shogi/shogi_engine.dart';

List<List<ShogiPiece?>> _emptyBoard() =>
    List.generate(9, (_) => List<ShogiPiece?>.filled(9, null));

void main() {
  group('Initial position', () {
    test('has 40 pieces and sente to move', () {
      final game = ShogiGame.initial();
      int count = 0;
      for (final row in game.board) {
        for (final p in row) {
          if (p != null) count++;
        }
      }
      expect(count, 40);
      expect(game.senteTurn, isTrue);
      expect(game.isGameOver, isFalse);
    });

    test('pawns can move one step forward from the start', () {
      final game = ShogiGame.initial();
      // Sente pawn at row 6, col 4 (one of the row of pawns).
      final moves = game.legalMovesFrom(6, 4);
      expect(moves, equals([(5, 4)]));
    });
  });

  group('Piece movement patterns', () {
    test('gold general has the expected 6 limited moves, no diagonal-back', () {
      final b = _emptyBoard();
      b[4][4] = const ShogiPiece(ShogiPieceType.gold, true); // sente, fwd = -1
      final moves = ShogiGame.legalMoves(b, 4, 4).toSet();
      // fwd diag-left, fwd, fwd diag-right, left, right, straight-back.
      expect(
        moves,
        {(3, 3), (3, 4), (3, 5), (4, 3), (4, 5), (5, 4)},
      );
      // Gold may NOT move diagonally backward.
      expect(moves.contains((5, 3)), isFalse);
      expect(moves.contains((5, 5)), isFalse);
    });

    test('rook slides any distance orthogonally, blocked by own piece', () {
      final b = _emptyBoard();
      b[4][4] = const ShogiPiece(ShogiPieceType.rook, true);
      b[4][7] = const ShogiPiece(ShogiPieceType.pawn, true); // own piece blocks.
      final moves = ShogiGame.legalMoves(b, 4, 4).toSet();
      // Up/down the full column, and right only up to (but not through/onto)
      // the blocking own pawn at col 7, plus the full left direction.
      expect(moves.contains((0, 4)), isTrue);
      expect(moves.contains((8, 4)), isTrue);
      expect(moves.contains((4, 0)), isTrue);
      expect(moves.contains((4, 5)), isTrue);
      expect(moves.contains((4, 6)), isTrue);
      expect(moves.contains((4, 7)), isFalse); // own piece: can't land on it.
      expect(moves.contains((4, 8)), isFalse); // can't slide past it either.
    });

    test('rook can capture an enemy piece but not slide past it', () {
      final b = _emptyBoard();
      b[4][4] = const ShogiPiece(ShogiPieceType.rook, true);
      b[4][7] = const ShogiPiece(ShogiPieceType.pawn, false); // enemy piece.
      final moves = ShogiGame.legalMoves(b, 4, 4).toSet();
      expect(moves.contains((4, 7)), isTrue); // can capture.
      expect(moves.contains((4, 8)), isFalse); // can't slide past capture.
    });

    test('knight jumps exactly two rows forward, left or right, over pieces',
        () {
      final b = _emptyBoard();
      b[4][4] = const ShogiPiece(ShogiPieceType.knight, true); // fwd = -1
      b[3][4] = const ShogiPiece(ShogiPieceType.pawn, true); // sits in the way.
      final moves = ShogiGame.legalMoves(b, 4, 4).toSet();
      expect(moves, {(2, 3), (2, 5)});
    });
  });

  group('Promotion', () {
    test('a pawn entering the promotion zone offers a promotion choice', () {
      final game = ShogiGame.initial();
      // Manually set up a sente pawn one step from entering gote's camp
      // (rows 0-2 for sente).
      game.board = _emptyBoard();
      game.board[3][0] = const ShogiPiece(ShogiPieceType.pawn, true);
      game.board[8][4] = const ShogiPiece(ShogiPieceType.king, true);
      game.board[0][4] = const ShogiPiece(ShogiPieceType.king, false);
      expect(game.canChoosePromotion((3, 0), 2), isTrue);
      expect(game.mustPromote((3, 0), 2), isFalse);

      game.applyMove((3, 0), (2, 0), promote: true);
      final moved = game.board[2][0];
      expect(moved!.type, ShogiPieceType.promotedPawn);
      expect(moved.label, 'と');
    });

    test('a pawn/lance reaching the furthest rank must promote', () {
      final game = ShogiGame.initial();
      game.board = _emptyBoard();
      game.board[1][0] = const ShogiPiece(ShogiPieceType.pawn, true);
      game.board[8][4] = const ShogiPiece(ShogiPieceType.king, true);
      game.board[0][4] = const ShogiPiece(ShogiPieceType.king, false);
      expect(game.mustPromote((1, 0), 0), isTrue);

      // Even asking NOT to promote is overridden, since it's forced.
      game.applyMove((1, 0), (0, 0), promote: false);
      expect(game.board[0][0]!.type, ShogiPieceType.promotedPawn);
    });

    test('capturing a promoted piece returns it to hand as its base type',
        () {
      final game = ShogiGame.initial();
      game.board = _emptyBoard();
      game.board[8][4] = const ShogiPiece(ShogiPieceType.king, true);
      game.board[0][4] = const ShogiPiece(ShogiPieceType.king, false);
      game.board[4][4] = const ShogiPiece(ShogiPieceType.rook, true);
      game.board[3][4] = const ShogiPiece(ShogiPieceType.promotedPawn, false);
      game.applyMove((4, 4), (3, 4));
      expect(game.senteHand[ShogiPieceType.pawn], 1);
      expect(game.senteHand.containsKey(ShogiPieceType.promotedPawn), isFalse);
    });
  });

  group('Drop rules', () {
    test('double-pawn-on-file (nifu) drop is correctly rejected', () {
      final b = _emptyBoard();
      // Sente already has an un-promoted pawn on column 3.
      b[5][3] = const ShogiPiece(ShogiPieceType.pawn, true);
      b[8][4] = const ShogiPiece(ShogiPieceType.king, true);
      b[0][4] = const ShogiPiece(ShogiPieceType.king, false);
      final hand = {ShogiPieceType.pawn: 1};
      final squares =
          ShogiGame.legalDropSquares(b, ShogiPieceType.pawn, true, hand, {});
      // No square on column 3 should be a legal drop target.
      expect(squares.any((s) => s.$2 == 3), isFalse);
      // But column 2, say, should be fine.
      expect(squares.any((s) => s.$2 == 2), isTrue);
    });

    test('a promoted pawn on a file does not block a further pawn drop there',
        () {
      final b = _emptyBoard();
      b[5][3] = const ShogiPiece(ShogiPieceType.promotedPawn, true);
      b[8][4] = const ShogiPiece(ShogiPieceType.king, true);
      b[0][4] = const ShogiPiece(ShogiPieceType.king, false);
      final hand = {ShogiPieceType.pawn: 1};
      final squares =
          ShogiGame.legalDropSquares(b, ShogiPieceType.pawn, true, hand, {});
      expect(squares.any((s) => s.$2 == 3), isTrue);
    });

    test('pawn cannot be dropped on the player\'s furthest rank', () {
      final b = _emptyBoard();
      b[8][4] = const ShogiPiece(ShogiPieceType.king, true);
      b[0][4] = const ShogiPiece(ShogiPieceType.king, false);
      final hand = {ShogiPieceType.pawn: 1};
      final squares =
          ShogiGame.legalDropSquares(b, ShogiPieceType.pawn, true, hand, {});
      expect(squares.any((s) => s.$1 == 0), isFalse); // sente's furthest rank.
    });

    test('pawn-drop-checkmate (uchifuzume) is correctly rejected', () {
      // Construct a position where dropping a sente pawn directly in front
      // of gote's king would deliver checkmate - and confirm the engine
      // refuses to offer that square as a legal drop, while still allowing
      // the pawn drop in a position where it only gives check (not mate).
      final b = _emptyBoard();
      // Gote king cornered at (0,0), fully boxed in by its own pieces so it
      // has no escape square and no piece that can capture an intervening
      // pawn.
      b[0][0] = const ShogiPiece(ShogiPieceType.king, false);
      b[0][1] = const ShogiPiece(ShogiPieceType.gold, false); // blocks escape right.
      b[1][0] = const ShogiPiece(ShogiPieceType.gold, false); // blocks escape down.
      b[1][1] = const ShogiPiece(ShogiPieceType.gold, false); // blocks diagonal.
      // Sente king elsewhere, out of the way.
      b[8][8] = const ShogiPiece(ShogiPieceType.king, true);
      // Sente rook pins column 0 so the king has no vertical escape and
      // nothing can interpose - drop target square is (1,0)... but that is
      // occupied. Use row 1 as the drop square via a different shape:
      // actually re-derive a clean uchifuzume shape instead (see below).

      // Simpler, canonical-style shape: gote king at (0,0), gote's own pawn
      // nowhere on this file (nifu not a concern for sente's drop), gote
      // has no piece that can capture on (1,0), and (0,1)/(1,1) are
      // controlled by sente so the king can't flee there either.
      final b2 = _emptyBoard();
      b2[0][0] = const ShogiPiece(ShogiPieceType.king, false);
      b2[8][8] = const ShogiPiece(ShogiPieceType.king, true);
      // (0,1) is directly attacked by this rook along row 0.
      b2[0][2] = const ShogiPiece(ShogiPieceType.rook, true);
      // (1,1) is directly attacked by this rook's own slide; it also
      // defends (1,0) once a pawn is dropped there, because the capture
      // hypothesis is evaluated on a fresh board with the pawn replaced by
      // the king - at which point this rook's row-1 slide (through the now
      //-empty (1,1)) reaches and attacks (1,0) too.
      b2[1][2] = const ShogiPiece(ShogiPieceType.rook, true);

      final hand = {ShogiPieceType.pawn: 1};
      final squares =
          ShogiGame.legalDropSquares(b2, ShogiPieceType.pawn, true, hand, {});

      // Sanity: dropping on (1,0) does deliver check (king is boxed) -
      // confirm the *shape* actually produces mate before asserting it's
      // excluded, otherwise this test would pass for the wrong reason.
      final testBoard = List.generate(9, (r) => List<ShogiPiece?>.from(b2[r]));
      testBoard[1][0] = const ShogiPiece(ShogiPieceType.pawn, true);
      expect(ShogiGame.isInCheck(testBoard, false), isTrue);
      expect(ShogiGame.hasAnyLegalMove(testBoard, false, {}), isFalse);

      // The actual assertion: engine must exclude (1,0) as a legal drop.
      expect(squares.any((s) => s.$1 == 1 && s.$2 == 0), isFalse,
          reason: 'pawn drop must not deliver checkmate (uchifuzume)');
    });

    test('a non-mating check from a pawn drop IS allowed', () {
      // Same shape but gote has an escape square, so the pawn drop merely
      // checks (legal) rather than mates.
      final b = _emptyBoard();
      b[0][0] = const ShogiPiece(ShogiPieceType.king, false);
      b[8][8] = const ShogiPiece(ShogiPieceType.king, true);
      // Only attack (0,1); leave (1,1) open as an escape square so it's
      // check, not mate.
      b[0][2] = const ShogiPiece(ShogiPieceType.rook, true);
      final hand = {ShogiPieceType.pawn: 1};
      final squares =
          ShogiGame.legalDropSquares(b, ShogiPieceType.pawn, true, hand, {});
      expect(squares.any((s) => s.$1 == 1 && s.$2 == 0), isTrue);
    });
  });

  group('Check / checkmate / stalemate', () {
    test('isInCheck detects a simple rook check', () {
      final b = _emptyBoard();
      b[0][4] = const ShogiPiece(ShogiPieceType.king, false);
      b[4][4] = const ShogiPiece(ShogiPieceType.rook, true);
      expect(ShogiGame.isInCheck(b, false), isTrue);
      expect(ShogiGame.isInCheck(b, true), isFalse);
    });

    test('a constructed back-rank mate is detected via applyMove', () {
      // Gote king cornered at (0,0); sente has a gold ready to deliver mate
      // and a rook controlling the only other flight square.
      final game = ShogiGame.initial();
      game.board = _emptyBoard();
      game.board[0][0] = const ShogiPiece(ShogiPieceType.king, false);
      game.board[8][8] = const ShogiPiece(ShogiPieceType.king, true);
      // Gold at (2,0) walks to (1,0), delivering check: its gold-move
      // pattern from (1,0) (fwd=-1 for sente) directly covers (0,0) [the
      // king], (0,1) and (1,1) - i.e. the gold alone covers every flight
      // square. The rook at (3,0), behind it on the same file, becomes
      // free to defend (1,0) itself the instant the gold vacates (2,0), so
      // the king can't simply capture the checking gold.
      game.board[2][0] = const ShogiPiece(ShogiPieceType.gold, true);
      game.board[3][0] = const ShogiPiece(ShogiPieceType.rook, true);
      game.senteHand.clear();
      game.goteHand.clear();
      game.senteTurn = true;

      // Confirm the gold has a legal move onto (1,0), delivering check,
      // with gote having no legal reply.
      expect(ShogiGame.legalMoves(game.board, 2, 0).contains((1, 0)), isTrue);
      game.applyMove((2, 0), (1, 0));

      expect(game.senteTurn, isFalse); // turn passed to gote.
      expect(game.sideToMoveInCheck, isTrue);
      expect(game.isGameOver, isTrue);
      expect(game.outcome, ShogiOutcome.senteWins);
    });

    test('stalemate (no legal move, not in check) is detected as a draw', () {
      // A lone gote king at (0,0) whose three neighboring squares are each
      // covered by a (non-sliding) sente knight jump, with none of those
      // knights threatening (0,0) itself - so the king cannot move, is not
      // in check, and (with an empty hand) has no drop either.
      final game = ShogiGame.initial();
      game.board = _emptyBoard();
      game.board[0][0] = const ShogiPiece(ShogiPieceType.king, false);
      game.board[8][8] = const ShogiPiece(ShogiPieceType.king, true);
      game.board[2][2] = const ShogiPiece(ShogiPieceType.knight, true); // covers (0,1).
      game.board[3][1] = const ShogiPiece(ShogiPieceType.knight, true); // covers (1,0).
      game.board[3][2] = const ShogiPiece(ShogiPieceType.knight, true); // covers (1,1).
      // A sente piece far away to move, after which it's gote's turn with
      // literally no legal move and not in check.
      game.board[8][7] = const ShogiPiece(ShogiPieceType.pawn, true);
      game.board[7][7] = null;
      game.senteHand.clear();
      game.goteHand.clear();
      game.senteTurn = true;

      expect(ShogiGame.isInCheck(game.board, false), isFalse);
      expect(ShogiGame.hasAnyLegalMove(game.board, false, game.goteHand), isFalse);

      game.applyMove((8, 7), (7, 7));
      expect(game.outcome, ShogiOutcome.stalemateDraw);
    });
  });
}
