// lib/src/hybrid_battle/hybrid_battle_engine.dart
//
// Rules engine for the "将棋駒 vs チェス駒" (shogi pieces vs chess pieces)
// time-limited event mode: one side plays a chess army with chess movement,
// the other a shogi army with shogi movement, on ONE shared 8x8 board (this
// app hosts the mode, so the board is the chess side's native size).
//
// The rules are deliberately ASYMMETRIC (confirmed product decision - the
// sibling komovia_shogi app hosts the mirror image on 9x9 with reversed
// polarity). Do not "fix" them to be symmetric:
//
//  * Movement / promotion: each army uses its own native rules.
//    - Chess pawns promote on the far rank (row 0) to Q/R/B/N. Castling is
//      supported. En passant is supported by the rules but can never
//      actually arise: only a chess pawn's double step creates an en-passant
//      target, and the only pawns able to capture it would be the
//      opponent's - which are shogi 歩, which never capture diagonally.
//      So there is no en-passant code at all.
//    - Shogi pieces move exactly as in shogi. PROMOTION ZONE (judgment
//      call, no canonical answer since an 8x8 shogi board never occurs in
//      real shogi): the far TWO ranks (rows 6-7, i.e. the chess army's
//      starting ranks). Native shogi uses 3 of 9 ranks (1/3); 3 of 8 would
//      put the zone only 3 steps from the shogi pawns' starting rank, and
//      2 of 8 (1/4) keeps promotion a reward for real penetration. Forced
//      promotion follows from the native "piece must still be able to move"
//      rule: 歩/香 on row 7, 桂 on rows 6-7.
//
//  * Mochigoma (captured-piece reuse): ONLY the shogi side. A chess piece
//    captured by the shogi side goes to the shogi hand converted to its
//    nearest shogi counterpart and can then be dropped as a shogi piece:
//      P->歩, N->桂, B->角, R->飛, Q->飛 (no shogi piece moves like a queen;
//      飛 is the strongest unpromoted equivalent). (Kings are never
//      captured.) Because a captured chess pawn becomes a real 歩, the
//      standard drop restrictions apply unchanged: no drop on an occupied
//      square, no 歩/香 on the last rank, no 桂 on the last two ranks, 二歩
//      (no second unpromoted 歩 on a file), and 打ち歩詰め (a 歩 drop may
//      not deliver mate). The chess side's captures are removed from play
//      permanently, exactly like standard chess.
//
//  * Win condition - each king is judged by the OTHER army's native logic:
//    - The SHOGI king (玉) is judged by CHESS logic: shogi side to move,
//      no legal move (board moves AND drops), in check -> checkmate, chess
//      wins; not in check -> STALEMATE, a draw.
//    - The CHESS king is judged by SHOGI (詰み) logic, which has no
//      stalemate-as-draw concept. In shogi, a side that has no legal move
//      loses, whether or not it is in check (shogi rules simply have no
//      draw for it; in practice it's always a 詰み position). So: chess side
//      to move with no legal move -> SHOGI WINS, in check (詰み) or not
//      (no-legal-move loss). This is the trickiest asymmetric interaction:
//      the exact same "no legal move, not in check" position is a draw when
//      it's the shogi king's side to move and a loss when it's the chess
//      king's side to move. It is reported with a distinct
//      [HybridEndReason.noLegalMoves] so the UI can explain it.
//
// Out of scope (local pass-and-play novelty, same as the existing shogi
// mode): AI, online play, 50-move / repetition / insufficient-material /
// 千日手 / 持将棋 draws.

import '../shogi/shogi_engine.dart' show ShogiPiece, ShogiPieceType;

export '../shogi/shogi_engine.dart' show ShogiPieceType, shogiPieceLabel;

const int hybridBoardSize = 8;

enum HybridArmy { chess, shogi }

enum ChessKind { king, queen, rook, bishop, knight, pawn }

/// The `k q r b n p` letter used by [PieceGlyph].
String chessKindLetter(ChessKind k) => switch (k) {
      ChessKind.king => 'k',
      ChessKind.queen => 'q',
      ChessKind.rook => 'r',
      ChessKind.bishop => 'b',
      ChessKind.knight => 'n',
      ChessKind.pawn => 'p',
    };

/// A piece on the hybrid board: either a chess piece (chess army) or a
/// shogi piece (shogi army). Exactly one of [chess]/[shogi] is non-null.
class HybridPiece {
  const HybridPiece.chess(ChessKind kind)
      : army = HybridArmy.chess,
        chess = kind,
        shogi = null;
  const HybridPiece.shogi(ShogiPieceType type)
      : army = HybridArmy.shogi,
        chess = null,
        shogi = type;

  final HybridArmy army;
  final ChessKind? chess;
  final ShogiPieceType? shogi;

  bool get isChess => army == HybridArmy.chess;
  bool get isKing =>
      chess == ChessKind.king || shogi == ShogiPieceType.king;

  /// Shogi helpers reuse the existing engine's ShogiPiece logic. The shogi
  /// army plays "gote-style" (moving toward higher row numbers).
  ShogiPiece get _asShogi => ShogiPiece(shogi!, false);

  @override
  bool operator ==(Object other) =>
      other is HybridPiece && other.chess == chess && other.shogi == shogi;

  @override
  int get hashCode => Object.hash(chess, shogi);

  @override
  String toString() => isChess ? 'Chess($chess)' : 'Shogi($shogi)';
}

typedef HSquare = (int, int);

/// A fully-specified move. Board move: [from] != null. Drop: [drop] != null
/// (shogi side only).
class HybridMove {
  const HybridMove({
    this.from,
    required this.to,
    this.drop,
    this.shogiPromote = false,
    this.chessPromotion,
    this.isCastle = false,
  });

  final HSquare? from;
  final HSquare to;
  final ShogiPieceType? drop;
  final bool shogiPromote;
  final ChessKind? chessPromotion;
  final bool isCastle;

  bool get isDrop => drop != null;

  @override
  bool operator ==(Object other) =>
      other is HybridMove &&
      other.from == from &&
      other.to == to &&
      other.drop == drop &&
      other.shogiPromote == shogiPromote &&
      other.chessPromotion == chessPromotion &&
      other.isCastle == isCastle;

  @override
  int get hashCode =>
      Object.hash(from, to, drop, shogiPromote, chessPromotion, isCastle);

  @override
  String toString() => 'HybridMove($from->$to drop=$drop '
      'sp=$shogiPromote cp=$chessPromotion castle=$isCastle)';
}

enum HybridOutcome { none, chessWins, shogiWins, draw }

enum HybridEndReason {
  none,

  /// Shogi king mated under chess logic, or chess king 詰み under shogi logic.
  checkmate,

  /// Shogi side to move, no legal move, not in check (chess stalemate).
  stalemate,

  /// Chess side to move, no legal move, not in check: a loss under shogi
  /// logic (no stalemate-as-draw). See the file header.
  noLegalMoves,
  resignation,
}

/// Converts a chess piece captured by the shogi side into the shogi piece
/// type it becomes in the shogi hand. See the file header.
ShogiPieceType capturedChessToShogi(ChessKind k) => switch (k) {
      ChessKind.pawn => ShogiPieceType.pawn,
      ChessKind.knight => ShogiPieceType.knight,
      ChessKind.bishop => ShogiPieceType.bishop,
      ChessKind.rook => ShogiPieceType.rook,
      ChessKind.queen => ShogiPieceType.rook,
      // Never captured (would require a king capture, impossible in legal
      // play); mapped only for exhaustiveness.
      ChessKind.king => ShogiPieceType.gold,
    };

typedef HBoard = List<List<HybridPiece?>>;

class HybridBattleGame {
  HybridBattleGame({
    required this.board,
    Map<ShogiPieceType, int>? shogiHand,
    this.chessToMove = true,
    this.chessKingMoved = false,
    this.chessRookAMoved = false,
    this.chessRookHMoved = false,
  }) : shogiHand = shogiHand ?? {};

  /// Starting position (judgment call, documented in the PR):
  ///  - Chess army (moves first, like white) on rows 6-7: the standard chess
  ///    back two ranks, unchanged.
  ///  - Shogi army on rows 0-2, scaled from shogi's 3-rank setup to 8 files:
  ///      row 0: 香 桂 銀 金 玉 銀 桂 香   (one 金 dropped to fit 8 files)
  ///      row 1: .  角 .  .  .  .  飛 .
  ///      row 2: 歩 x8
  ///    leaving rows 3-5 empty between the armies.
  factory HybridBattleGame.initial() {
    final b = emptyBoard();
    const back = [
      ShogiPieceType.lance,
      ShogiPieceType.knight,
      ShogiPieceType.silver,
      ShogiPieceType.gold,
      ShogiPieceType.king,
      ShogiPieceType.silver,
      ShogiPieceType.knight,
      ShogiPieceType.lance,
    ];
    for (int c = 0; c < 8; c++) {
      b[0][c] = HybridPiece.shogi(back[c]);
      b[2][c] = const HybridPiece.shogi(ShogiPieceType.pawn);
      b[6][c] = const HybridPiece.chess(ChessKind.pawn);
    }
    b[1][1] = const HybridPiece.shogi(ShogiPieceType.bishop);
    b[1][6] = const HybridPiece.shogi(ShogiPieceType.rook);
    const chessBack = [
      ChessKind.rook,
      ChessKind.knight,
      ChessKind.bishop,
      ChessKind.queen,
      ChessKind.king,
      ChessKind.bishop,
      ChessKind.knight,
      ChessKind.rook,
    ];
    for (int c = 0; c < 8; c++) {
      b[7][c] = HybridPiece.chess(chessBack[c]);
    }
    return HybridBattleGame(board: b);
  }

  HBoard board;
  final Map<ShogiPieceType, int> shogiHand;
  bool chessToMove;
  bool chessKingMoved;
  bool chessRookAMoved;
  bool chessRookHMoved;
  HybridOutcome outcome = HybridOutcome.none;
  HybridEndReason endReason = HybridEndReason.none;

  bool get isGameOver => outcome != HybridOutcome.none;
  HybridArmy get sideToMove => chessToMove ? HybridArmy.chess : HybridArmy.shogi;

  static HBoard emptyBoard() =>
      List.generate(8, (_) => List<HybridPiece?>.filled(8, null));

  static HBoard copyBoard(HBoard b) =>
      List.generate(8, (r) => List<HybridPiece?>.from(b[r]));

  static bool onBoard(int r, int c) => r >= 0 && r < 8 && c >= 0 && c < 8;

  /// Shogi promotion zone: the far two ranks from the shogi side.
  static bool inShogiPromotionZone(int row) => row >= 6;

  static bool shogiMustPromote(ShogiPieceType t, int toRow) {
    if (t == ShogiPieceType.pawn || t == ShogiPieceType.lance) return toRow == 7;
    if (t == ShogiPieceType.knight) return toRow >= 6;
    return false;
  }

  // -----------------------------------------------------------------------
  // Pseudo-legal movement (ignores own-king safety).
  // -----------------------------------------------------------------------

  /// Destination squares by movement pattern. For chess pawns this includes
  /// forward pushes (non-capturing) and diagonal captures. Castling is NOT
  /// included (see [legalMoves]).
  static List<HSquare> pseudoTargets(HBoard b, int row, int col) {
    final p = b[row][col];
    if (p == null) return [];
    final out = <HSquare>[];
    bool friendly(int r, int c) => b[r][c] != null && b[r][c]!.army == p.army;
    void step(int dr, int dc) {
      final r = row + dr, c = col + dc;
      if (onBoard(r, c) && !friendly(r, c)) out.add((r, c));
    }

    void slide(int dr, int dc) {
      int r = row + dr, c = col + dc;
      while (onBoard(r, c) && !friendly(r, c)) {
        out.add((r, c));
        if (b[r][c] != null) break;
        r += dr;
        c += dc;
      }
    }

    const orth = [(-1, 0), (1, 0), (0, -1), (0, 1)];
    const diag = [(-1, -1), (-1, 1), (1, -1), (1, 1)];

    if (p.isChess) {
      switch (p.chess!) {
        case ChessKind.king:
          for (final d in [...orth, ...diag]) {
            step(d.$1, d.$2);
          }
        case ChessKind.queen:
          for (final d in [...orth, ...diag]) {
            slide(d.$1, d.$2);
          }
        case ChessKind.rook:
          for (final d in orth) {
            slide(d.$1, d.$2);
          }
        case ChessKind.bishop:
          for (final d in diag) {
            slide(d.$1, d.$2);
          }
        case ChessKind.knight:
          for (final d in const [
            (-2, -1), (-2, 1), (2, -1), (2, 1),
            (-1, -2), (-1, 2), (1, -2), (1, 2),
          ]) {
            step(d.$1, d.$2);
          }
        case ChessKind.pawn:
          // Chess army moves toward row 0.
          if (onBoard(row - 1, col) && b[row - 1][col] == null) {
            out.add((row - 1, col));
            if (row == 6 && b[row - 2][col] == null) out.add((row - 2, col));
          }
          for (final dc in const [-1, 1]) {
            final r = row - 1, c = col + dc;
            if (onBoard(r, c) && b[r][c] != null && b[r][c]!.army != p.army) {
              out.add((r, c));
            }
          }
      }
      return out;
    }

    // Shogi army moves toward row 7 (fwd = +1).
    const fwd = 1;
    void gold() {
      step(fwd, -1);
      step(fwd, 0);
      step(fwd, 1);
      step(0, -1);
      step(0, 1);
      step(-fwd, 0);
    }

    switch (p.shogi!) {
      case ShogiPieceType.king:
        for (final d in [...orth, ...diag]) {
          step(d.$1, d.$2);
        }
      case ShogiPieceType.rook:
        for (final d in orth) {
          slide(d.$1, d.$2);
        }
      case ShogiPieceType.bishop:
        for (final d in diag) {
          slide(d.$1, d.$2);
        }
      case ShogiPieceType.gold:
      case ShogiPieceType.promotedSilver:
      case ShogiPieceType.promotedKnight:
      case ShogiPieceType.promotedLance:
      case ShogiPieceType.promotedPawn:
        gold();
      case ShogiPieceType.silver:
        step(fwd, -1);
        step(fwd, 0);
        step(fwd, 1);
        step(-fwd, -1);
        step(-fwd, 1);
      case ShogiPieceType.knight:
        step(fwd * 2, -1);
        step(fwd * 2, 1);
      case ShogiPieceType.lance:
        slide(fwd, 0);
      case ShogiPieceType.pawn:
        step(fwd, 0);
      case ShogiPieceType.promotedRook:
        for (final d in orth) {
          slide(d.$1, d.$2);
        }
        for (final d in diag) {
          step(d.$1, d.$2);
        }
      case ShogiPieceType.promotedBishop:
        for (final d in diag) {
          slide(d.$1, d.$2);
        }
        for (final d in orth) {
          step(d.$1, d.$2);
        }
    }
    return out;
  }

  /// Whether a piece of [army] attacks [target]. Chess pawns only attack
  /// diagonally (their forward push never captures).
  static bool isAttackedBy(HBoard b, HSquare target, HybridArmy army) {
    for (int r = 0; r < 8; r++) {
      for (int c = 0; c < 8; c++) {
        final p = b[r][c];
        if (p == null || p.army != army) continue;
        if (p.chess == ChessKind.pawn) {
          if (target.$1 == r - 1 && (target.$2 - c).abs() == 1) return true;
          continue;
        }
        for (final t in pseudoTargets(b, r, c)) {
          if (t == target) return true;
        }
      }
    }
    return false;
  }

  static HSquare? kingSquare(HBoard b, HybridArmy army) {
    for (int r = 0; r < 8; r++) {
      for (int c = 0; c < 8; c++) {
        final p = b[r][c];
        if (p != null && p.army == army && p.isKing) return (r, c);
      }
    }
    return null;
  }

  static bool isInCheck(HBoard b, HybridArmy army) {
    final k = kingSquare(b, army);
    if (k == null) return false;
    return isAttackedBy(b, k, army == HybridArmy.chess ? HybridArmy.shogi : HybridArmy.chess);
  }

  // -----------------------------------------------------------------------
  // Legal moves.
  // -----------------------------------------------------------------------

  /// Applies [m] to a copy of [b] (board only; no hand/flag bookkeeping).
  static HBoard boardAfter(HBoard b, HybridMove m) {
    final nb = copyBoard(b);
    if (m.isDrop) {
      nb[m.to.$1][m.to.$2] = HybridPiece.shogi(m.drop!);
      return nb;
    }
    final from = m.from!;
    var piece = nb[from.$1][from.$2]!;
    nb[from.$1][from.$2] = null;
    if (m.chessPromotion != null) piece = HybridPiece.chess(m.chessPromotion!);
    if (m.shogiPromote) piece = HybridPiece.shogi(piece._asShogi.promotedType);
    nb[m.to.$1][m.to.$2] = piece;
    if (m.isCastle) {
      final row = from.$1;
      if (m.to.$2 == 6) {
        nb[row][5] = nb[row][7];
        nb[row][7] = null;
      } else {
        nb[row][3] = nb[row][0];
        nb[row][0] = null;
      }
    }
    return nb;
  }

  /// All fully legal board moves for the piece at (row, col), regardless of
  /// whose turn it is. Promotion variants are expanded into separate moves.
  List<HybridMove> legalMovesFromSquare(int row, int col) {
    final p = board[row][col];
    if (p == null) return [];
    final candidates = <HybridMove>[];
    for (final t in pseudoTargets(board, row, col)) {
      if (p.chess == ChessKind.pawn && t.$1 == 0) {
        for (final k in const [ChessKind.queen, ChessKind.rook, ChessKind.bishop, ChessKind.knight]) {
          candidates.add(HybridMove(from: (row, col), to: t, chessPromotion: k));
        }
      } else if (!p.isChess) {
        final sp = p._asShogi;
        final must = shogiMustPromote(p.shogi!, t.$1);
        final zone = inShogiPromotionZone(row) || inShogiPromotionZone(t.$1);
        if (!must) candidates.add(HybridMove(from: (row, col), to: t));
        if (sp.canPromote && (must || zone)) {
          candidates.add(HybridMove(from: (row, col), to: t, shogiPromote: true));
        }
      } else {
        candidates.add(HybridMove(from: (row, col), to: t));
      }
    }
    if (p.chess == ChessKind.king) candidates.addAll(_castlingMoves(row, col));
    return candidates
        .where((m) => !isInCheck(boardAfter(board, m), p.army))
        .toList();
  }

  List<HybridMove> _castlingMoves(int row, int col) {
    if (chessKingMoved || row != 7 || col != 4) return [];
    if (isInCheck(board, HybridArmy.chess)) return [];
    final out = <HybridMove>[];
    bool rookAt(int c) => board[7][c] == const HybridPiece.chess(ChessKind.rook);
    bool safe(int c) => !isAttackedBy(board, (7, c), HybridArmy.shogi);
    if (!chessRookHMoved && rookAt(7) && board[7][5] == null && board[7][6] == null &&
        safe(5) && safe(6)) {
      out.add(const HybridMove(from: (7, 4), to: (7, 6), isCastle: true));
    }
    if (!chessRookAMoved && rookAt(0) && board[7][1] == null && board[7][2] == null &&
        board[7][3] == null && safe(3) && safe(2)) {
      out.add(const HybridMove(from: (7, 4), to: (7, 2), isCastle: true));
    }
    return out;
  }

  /// Legal drop squares for [type] from the shogi hand. Applies the native
  /// shogi drop restrictions (see the file header), including 打ち歩詰め
  /// judged with the same "chess side has no legal move" logic used for
  /// game end.
  List<HSquare> legalDropSquares(ShogiPieceType type) {
    if ((shogiHand[type] ?? 0) <= 0) return [];
    final out = <HSquare>[];
    for (int r = 0; r < 8; r++) {
      for (int c = 0; c < 8; c++) {
        if (board[r][c] != null) continue;
        if (shogiMustPromote(type, r)) continue; // would be immobile.
        if (type == ShogiPieceType.pawn) {
          var nifu = false;
          for (int rr = 0; rr < 8; rr++) {
            if (board[rr][c] == const HybridPiece.shogi(ShogiPieceType.pawn)) {
              nifu = true;
              break;
            }
          }
          if (nifu) continue;
        }
        final m = HybridMove(to: (r, c), drop: type);
        final nb = boardAfter(board, m);
        if (isInCheck(nb, HybridArmy.shogi)) continue;
        if (type == ShogiPieceType.pawn &&
            isInCheck(nb, HybridArmy.chess) &&
            !_hasAnyLegalMoveOn(nb, HybridArmy.chess)) {
          continue; // 打ち歩詰め
        }
        out.add((r, c));
      }
    }
    return out;
  }

  /// Whether [army] has any legal move on [b] (board moves; plus drops for
  /// the shogi side). Uses this game's castling flags/hand.
  bool _hasAnyLegalMoveOn(HBoard b, HybridArmy army) {
    final probe = HybridBattleGame(
      board: b,
      shogiHand: Map.of(shogiHand),
      chessToMove: army == HybridArmy.chess,
      chessKingMoved: chessKingMoved,
      chessRookAMoved: chessRookAMoved,
      chessRookHMoved: chessRookHMoved,
    );
    return probe.hasAnyLegalMove(army);
  }

  bool hasAnyLegalMove(HybridArmy army) {
    for (int r = 0; r < 8; r++) {
      for (int c = 0; c < 8; c++) {
        final p = board[r][c];
        if (p == null || p.army != army) continue;
        if (legalMovesFromSquare(r, c).isNotEmpty) return true;
      }
    }
    if (army == HybridArmy.shogi) {
      for (final t in shogiHand.keys.toList()) {
        if (legalDropSquares(t).isNotEmpty) return true;
      }
    }
    return false;
  }

  // -----------------------------------------------------------------------
  // UI-facing API.
  // -----------------------------------------------------------------------

  /// Legal moves for the side to move from (row, col); empty if it's not
  /// that piece's turn or the game is over.
  List<HybridMove> legalMovesFrom(int row, int col) {
    final p = board[row][col];
    if (isGameOver || p == null || p.army != sideToMove) return [];
    return legalMovesFromSquare(row, col);
  }

  List<HSquare> legalDropSquaresFor(ShogiPieceType type) {
    if (isGameOver || chessToMove) return [];
    return legalDropSquares(type);
  }

  bool get sideToMoveInCheck => isInCheck(board, sideToMove);

  /// Applies [m] (assumed legal - obtain it from [legalMovesFrom] or build a
  /// drop from [legalDropSquaresFor]) and updates the outcome.
  void applyMove(HybridMove m) {
    if (isGameOver) return;
    if (m.isDrop) {
      final n = (shogiHand[m.drop!] ?? 0) - 1;
      if (n < 0) return;
      if (n == 0) {
        shogiHand.remove(m.drop!);
      } else {
        shogiHand[m.drop!] = n;
      }
    } else {
      final from = m.from!;
      final mover = board[from.$1][from.$2];
      final captured = board[m.to.$1][m.to.$2];
      if (mover == null) return;
      // Asymmetric mochigoma: only the shogi side keeps captures.
      if (!mover.isChess && captured != null && captured.isChess) {
        final t = capturedChessToShogi(captured.chess!);
        shogiHand[t] = (shogiHand[t] ?? 0) + 1;
      }
      if (mover.chess == ChessKind.king) chessKingMoved = true;
      if (mover.chess == ChessKind.rook && from == (7, 0)) chessRookAMoved = true;
      if (mover.chess == ChessKind.rook && from == (7, 7)) chessRookHMoved = true;
      if (m.to == (7, 0)) chessRookAMoved = true;
      if (m.to == (7, 7)) chessRookHMoved = true;
    }
    board = boardAfter(board, m);
    chessToMove = !chessToMove;
    _evaluateEnd();
  }

  void resign(HybridArmy loser) {
    if (isGameOver) return;
    outcome = loser == HybridArmy.chess ? HybridOutcome.shogiWins : HybridOutcome.chessWins;
    endReason = HybridEndReason.resignation;
  }

  void _evaluateEnd() {
    final side = sideToMove;
    if (hasAnyLegalMove(side)) return;
    final inCheck = isInCheck(board, side);
    if (side == HybridArmy.shogi) {
      // Shogi king judged by CHESS logic.
      if (inCheck) {
        outcome = HybridOutcome.chessWins;
        endReason = HybridEndReason.checkmate;
      } else {
        outcome = HybridOutcome.draw;
        endReason = HybridEndReason.stalemate;
      }
    } else {
      // Chess king judged by SHOGI logic: no legal move is always a loss.
      outcome = HybridOutcome.shogiWins;
      endReason = inCheck ? HybridEndReason.checkmate : HybridEndReason.noLegalMoves;
    }
  }
}
