import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_chess/src/hybrid_battle/hybrid_battle_engine.dart';

const _ck = HybridPiece.chess(ChessKind.king);
const _cq = HybridPiece.chess(ChessKind.queen);
const _cr = HybridPiece.chess(ChessKind.rook);
const _cp = HybridPiece.chess(ChessKind.pawn);
const _sk = HybridPiece.shogi(ShogiPieceType.king);
const _sr = HybridPiece.shogi(ShogiPieceType.rook);
const _sg = HybridPiece.shogi(ShogiPieceType.gold);
const _sp = HybridPiece.shogi(ShogiPieceType.pawn);

HybridBattleGame _game(
  Map<HSquare, HybridPiece> pieces, {
  bool chessToMove = true,
  Map<ShogiPieceType, int>? hand,
}) {
  final b = HybridBattleGame.emptyBoard();
  pieces.forEach((sq, p) => b[sq.$1][sq.$2] = p);
  return HybridBattleGame(
    board: b,
    shogiHand: hand,
    chessToMove: chessToMove,
    chessKingMoved: true,
  );
}

void main() {
  group('initial position & movement', () {
    test('8x8 armies are set up and chess moves first', () {
      final g = HybridBattleGame.initial();
      expect(g.board.length, 8);
      expect(g.board[7][4], _ck);
      expect(g.board[0][4], _sk);
      expect(g.chessToMove, isTrue);
      expect(g.legalMovesFrom(6, 4).map((m) => m.to), containsAll([(5, 4), (4, 4)]));
      // Shogi pieces can't move on chess's turn.
      expect(g.legalMovesFrom(2, 0), isEmpty);
    });

    test('shogi pawn moves one step forward, knight jumps shogi-style', () {
      final g = HybridBattleGame.initial()..chessToMove = false;
      expect(g.legalMovesFrom(2, 0).map((m) => m.to).toList(), [(3, 0)]);
      // 桂 at (0,1) is blocked by own pawns at (2,0)/(2,2).
      expect(g.legalMovesFrom(0, 1), isEmpty);
    });

    test('chess pawn promotion offers Q/R/B/N', () {
      final g = _game({(1, 0): _cp, (7, 7): _ck, (0, 7): _sk});
      final kinds = g.legalMovesFrom(1, 0).map((m) => m.chessPromotion).toSet();
      expect(kinds, {ChessKind.queen, ChessKind.rook, ChessKind.bishop, ChessKind.knight});
    });

    test('shogi promotion zone is the far two ranks; pawn forced on last rank', () {
      final g = _game({(5, 3): _sp, (6, 0): _sp, (0, 0): _sk, (7, 7): _ck},
          chessToMove: false);
      final into = g.legalMovesFrom(5, 3);
      expect(into.map((m) => m.shogiPromote).toSet(), {true, false});
      final last = g.legalMovesFrom(6, 0);
      expect(last.length, 1);
      expect(last.single.shogiPromote, isTrue);
    });

    test('castling kingside', () {
      final g = HybridBattleGame(board: HybridBattleGame.emptyBoard());
      g.board[7][4] = _ck;
      g.board[7][7] = _cr;
      g.board[0][0] = _sk;
      final castle = g.legalMovesFrom(7, 4).where((m) => m.isCastle).single;
      g.applyMove(castle);
      expect(g.board[7][6], _ck);
      expect(g.board[7][5], _cr);
    });
  });

  group('asymmetric mochigoma', () {
    test('shogi side keeps captured chess pieces and can drop them', () {
      final g = _game({(3, 3): _sp, (4, 3): _cq, (0, 0): _sk, (7, 7): _ck},
          chessToMove: false);
      g.applyMove(const HybridMove(from: (3, 3), to: (4, 3)));
      // Queen converts to 飛.
      expect(g.shogiHand, {ShogiPieceType.rook: 1});
      // Chess side can never drop.
      expect(g.legalDropSquaresFor(ShogiPieceType.rook), isEmpty);
      g.applyMove(const HybridMove(from: (7, 7), to: (7, 6)));
      final drops = g.legalDropSquaresFor(ShogiPieceType.rook);
      expect(drops, contains((5, 5)));
      expect(drops, isNot(contains((4, 3)))); // occupied by own pawn
      g.applyMove(const HybridMove(to: (5, 5), drop: ShogiPieceType.rook));
      expect(g.board[5][5], _sr);
      expect(g.shogiHand, isEmpty);
    });

    test('chess side captures are removed permanently', () {
      final g = _game({(4, 4): _cq, (2, 4): _sg, (0, 0): _sk, (7, 7): _ck});
      g.applyMove(const HybridMove(from: (4, 4), to: (2, 4)));
      expect(g.board[2][4], _cq);
      expect(g.shogiHand, isEmpty);
    });

    test('captured chess pawn drops obey 二歩 and last-rank rules', () {
      final g = _game({(3, 2): _sp, (0, 0): _sk, (7, 7): _ck},
          chessToMove: false, hand: {ShogiPieceType.pawn: 1});
      final drops = g.legalDropSquaresFor(ShogiPieceType.pawn);
      expect(drops.where((s) => s.$2 == 2), isEmpty); // 二歩
      expect(drops.where((s) => s.$1 == 7), isEmpty); // immobile
      expect(drops, contains((4, 4)));
    });

    test('打ち歩詰め: a pawn drop may not mate the chess king', () {
      final g = _game({
        (7, 7): _ck,
        (5, 6): _sg,
        (6, 5): HybridPiece.shogi(ShogiPieceType.silver),
        (0, 0): _sk,
      }, chessToMove: false, hand: {ShogiPieceType.pawn: 1});
      final drops = g.legalDropSquaresFor(ShogiPieceType.pawn);
      expect(drops, isNot(contains((6, 7))));
      expect(drops, contains((4, 0)));
    });
  });

  group('asymmetric win conditions', () {
    test('shogi king checkmated by CHESS logic -> chess wins', () {
      final g = _game({(0, 0): _sk, (1, 6): _cr, (2, 7): _cr, (7, 7): _ck});
      g.applyMove(const HybridMove(from: (2, 7), to: (0, 7)));
      expect(g.outcome, HybridOutcome.chessWins);
      expect(g.endReason, HybridEndReason.checkmate);
    });

    test('shogi king stalemated (chess logic) -> draw', () {
      final g = _game({(0, 0): _sk, (2, 5): _cq, (7, 7): _ck});
      g.applyMove(const HybridMove(from: (2, 5), to: (2, 1)));
      expect(g.outcome, HybridOutcome.draw);
      expect(g.endReason, HybridEndReason.stalemate);
    });

    test('a droppable hand piece prevents shogi stalemate', () {
      final g = _game({(0, 0): _sk, (2, 5): _cq, (7, 7): _ck},
          hand: {ShogiPieceType.gold: 1});
      g.applyMove(const HybridMove(from: (2, 5), to: (2, 1)));
      expect(g.outcome, HybridOutcome.none);
    });

    test('chess king 詰み by SHOGI logic -> shogi wins', () {
      final g = _game({(7, 7): _ck, (6, 0): _sr, (5, 1): _sr, (0, 0): _sk},
          chessToMove: false);
      g.applyMove(const HybridMove(from: (5, 1), to: (7, 1)));
      expect(g.outcome, HybridOutcome.shogiWins);
      expect(g.endReason, HybridEndReason.checkmate);
    });

    test('chess side with no legal move but not in check LOSES (no stalemate in shogi logic)', () {
      final g = _game({(7, 7): _ck, (6, 0): _sr, (0, 3): _sr, (0, 0): _sk},
          chessToMove: false);
      g.applyMove(const HybridMove(from: (0, 3), to: (0, 6)));
      expect(g.sideToMoveInCheck, isFalse);
      expect(g.outcome, HybridOutcome.shogiWins);
      expect(g.endReason, HybridEndReason.noLegalMoves);
    });

    test('a move leaving own king in check is illegal', () {
      final g = _game({(7, 4): _ck, (6, 4): _cr, (0, 4): _sr, (0, 0): _sk});
      // Pinned rook may only move along the file.
      expect(g.legalMovesFrom(6, 4).every((m) => m.to.$2 == 4), isTrue);
    });
  });
}
