// lib/src/shogi/shogi_engine.dart
//
// Self-contained, minimal shogi (Japanese chess) rules engine for the
// "bonus: play shogi" novelty mode.
//
// This is deliberately NOT a dependency on komovia_shogi (siblings in the
// Komovia family do not share game-logic packages, only the Flutter-free
// komovia_core package for social models) - it's a small, independent
// re-implementation of the standard rules, adapted from the structure of
// komovia_shogi's own `lib/src/logic.dart` (see that repo for reference).
//
// Scope deliberately kept to:
//  - standard 9x9 board, standard starting position
//  - standard piece movement + promotion rules
//  - drop rules, including the "two pawns on one file" (二歩) and
//    "pawn-drop checkmate" (打ち歩詰め) restrictions
//  - check / checkmate / stalemate (no legal moves) detection
//
// Explicitly OUT of scope for this novelty mode (see PR description):
//  - AI opponent
//  - repetition (千日手) / impasse (持将棋) draw detection
//  - any persistence, online play, or puzzle content

/// The 14 piece kinds that can exist on a shogi board (promoted pieces are
/// distinct kinds here, same approach as komovia_shogi's `PieceType`).
enum ShogiPieceType {
  king,
  rook,
  bishop,
  gold,
  silver,
  knight,
  lance,
  pawn,
  promotedRook,
  promotedBishop,
  promotedSilver,
  promotedKnight,
  promotedLance,
  promotedPawn,
}

const Set<ShogiPieceType> _promotedTypes = {
  ShogiPieceType.promotedRook,
  ShogiPieceType.promotedBishop,
  ShogiPieceType.promotedSilver,
  ShogiPieceType.promotedKnight,
  ShogiPieceType.promotedLance,
  ShogiPieceType.promotedPawn,
};

const Map<ShogiPieceType, ShogiPieceType> _toPromoted = {
  ShogiPieceType.rook: ShogiPieceType.promotedRook,
  ShogiPieceType.bishop: ShogiPieceType.promotedBishop,
  ShogiPieceType.silver: ShogiPieceType.promotedSilver,
  ShogiPieceType.knight: ShogiPieceType.promotedKnight,
  ShogiPieceType.lance: ShogiPieceType.promotedLance,
  ShogiPieceType.pawn: ShogiPieceType.promotedPawn,
};

const Map<ShogiPieceType, ShogiPieceType> _toBase = {
  ShogiPieceType.promotedRook: ShogiPieceType.rook,
  ShogiPieceType.promotedBishop: ShogiPieceType.bishop,
  ShogiPieceType.promotedSilver: ShogiPieceType.silver,
  ShogiPieceType.promotedKnight: ShogiPieceType.knight,
  ShogiPieceType.promotedLance: ShogiPieceType.lance,
  ShogiPieceType.promotedPawn: ShogiPieceType.pawn,
};

/// Single-character kanji label used by the (deliberately simple) piece
/// glyph rendering in the board widget.
String shogiPieceLabel(ShogiPieceType t) {
  switch (t) {
    case ShogiPieceType.king:
      return '王';
    case ShogiPieceType.rook:
      return '飛';
    case ShogiPieceType.bishop:
      return '角';
    case ShogiPieceType.gold:
      return '金';
    case ShogiPieceType.silver:
      return '銀';
    case ShogiPieceType.knight:
      return '桂';
    case ShogiPieceType.lance:
      return '香';
    case ShogiPieceType.pawn:
      return '歩';
    case ShogiPieceType.promotedRook:
      return '龍';
    case ShogiPieceType.promotedBishop:
      return '馬';
    case ShogiPieceType.promotedSilver:
      return '全';
    case ShogiPieceType.promotedKnight:
      return '圭';
    case ShogiPieceType.promotedLance:
      return '杏';
    case ShogiPieceType.promotedPawn:
      return 'と';
  }
}

/// A single piece on the board or in hand. [isSente] marks the first player
/// (先手, moves "up" the board visually / toward row 0); the second player
/// is 後手 (gote).
class ShogiPiece {
  final ShogiPieceType type;
  final bool isSente;
  const ShogiPiece(this.type, this.isSente);

  String get label =>
      type == ShogiPieceType.king ? (isSente ? '王' : '玉') : shogiPieceLabel(type);

  bool get isPromoted => _promotedTypes.contains(type);

  /// Whether this piece kind is ever eligible to promote.
  bool get canPromote =>
      !isPromoted && type != ShogiPieceType.king && type != ShogiPieceType.gold;

  ShogiPieceType get promotedType => _toPromoted[type] ?? type;

  /// The un-promoted kind a captured piece returns to the capturer's hand
  /// as (captured pieces always revert to their base form).
  ShogiPieceType get baseType => _toBase[type] ?? type;

  /// Whether a move ending at [toRow] (0-indexed, row 0 = gote's back rank,
  /// row 8 = sente's back rank) MUST promote (no choice allowed), per
  /// standard shogi rules: pawn/lance/knight that can no longer move at all
  /// if left un-promoted at that rank.
  bool mustPromote(int toRow) {
    if (!canPromote) return false;
    if (isSente) {
      if (type == ShogiPieceType.pawn || type == ShogiPieceType.lance) {
        return toRow == 0;
      }
      if (type == ShogiPieceType.knight) return toRow <= 1;
    } else {
      if (type == ShogiPieceType.pawn || type == ShogiPieceType.lance) {
        return toRow == 8;
      }
      if (type == ShogiPieceType.knight) return toRow >= 7;
    }
    return false;
  }
}

/// A board square coordinate, (row, col), each 0..8.
typedef Square = (int, int);

/// A fully-specified move: either a board move (from != null) or a drop
/// (from == null, drop != null).
class ShogiMove {
  final Square? from;
  final Square to;
  final ShogiPieceType? drop;
  final bool promote;
  const ShogiMove({this.from, required this.to, this.drop, this.promote = false})
      : assert(from != null || drop != null,
            'A move must either move a piece or drop one');

  bool get isDrop => drop != null;
}

/// Outcome of the game once no further moves should be made.
enum ShogiOutcome { none, senteWins, goteWins, stalemateDraw }

/// Mutable shogi game state: board + both hands + whose turn + outcome.
///
/// This is the whole engine surface the UI needs: construct with
/// [ShogiGame.initial], then query [legalMovesFrom]/[legalDropSquares] to
/// drive a tap-to-select-then-tap-to-move UI, and call [applyMove] /
/// [applyDrop] to mutate state and get back the new [outcome].
class ShogiGame {
  List<List<ShogiPiece?>> board;
  final Map<ShogiPieceType, int> senteHand;
  final Map<ShogiPieceType, int> goteHand;
  bool senteTurn;
  ShogiOutcome outcome;

  ShogiGame({
    required this.board,
    required this.senteHand,
    required this.goteHand,
    required this.senteTurn,
    this.outcome = ShogiOutcome.none,
  });

  factory ShogiGame.initial() => ShogiGame(
        board: _initialBoard(),
        senteHand: {},
        goteHand: {},
        senteTurn: true,
      );

  bool get isGameOver => outcome != ShogiOutcome.none;

  Map<ShogiPieceType, int> handFor(bool isSente) => isSente ? senteHand : goteHand;

  static bool _onBoard(int r, int c) => r >= 0 && r < 9 && c >= 0 && c < 9;

  static List<List<ShogiPiece?>> _copyBoard(List<List<ShogiPiece?>> b) =>
      List.generate(9, (r) => List<ShogiPiece?>.from(b[r]));

  static List<List<ShogiPiece?>> _initialBoard() {
    final b = List.generate(9, (_) => List<ShogiPiece?>.filled(9, null));
    // Gote (後手), back rows 0-2, visually at the top.
    b[0][0] = const ShogiPiece(ShogiPieceType.lance, false);
    b[0][1] = const ShogiPiece(ShogiPieceType.knight, false);
    b[0][2] = const ShogiPiece(ShogiPieceType.silver, false);
    b[0][3] = const ShogiPiece(ShogiPieceType.gold, false);
    b[0][4] = const ShogiPiece(ShogiPieceType.king, false);
    b[0][5] = const ShogiPiece(ShogiPieceType.gold, false);
    b[0][6] = const ShogiPiece(ShogiPieceType.silver, false);
    b[0][7] = const ShogiPiece(ShogiPieceType.knight, false);
    b[0][8] = const ShogiPiece(ShogiPieceType.lance, false);
    b[1][1] = const ShogiPiece(ShogiPieceType.rook, false);
    b[1][7] = const ShogiPiece(ShogiPieceType.bishop, false);
    for (int c = 0; c < 9; c++) {
      b[2][c] = const ShogiPiece(ShogiPieceType.pawn, false);
    }
    // Sente (先手), back rows 6-8, visually at the bottom.
    for (int c = 0; c < 9; c++) {
      b[6][c] = const ShogiPiece(ShogiPieceType.pawn, true);
    }
    b[7][1] = const ShogiPiece(ShogiPieceType.bishop, true);
    b[7][7] = const ShogiPiece(ShogiPieceType.rook, true);
    b[8][0] = const ShogiPiece(ShogiPieceType.lance, true);
    b[8][1] = const ShogiPiece(ShogiPieceType.knight, true);
    b[8][2] = const ShogiPiece(ShogiPieceType.silver, true);
    b[8][3] = const ShogiPiece(ShogiPieceType.gold, true);
    b[8][4] = const ShogiPiece(ShogiPieceType.king, true);
    b[8][5] = const ShogiPiece(ShogiPieceType.gold, true);
    b[8][6] = const ShogiPiece(ShogiPieceType.silver, true);
    b[8][7] = const ShogiPiece(ShogiPieceType.knight, true);
    b[8][8] = const ShogiPiece(ShogiPieceType.lance, true);
    return b;
  }

  // ---------------------------------------------------------------------
  // Pure move-generation helpers (static so they're trivially testable
  // against arbitrary constructed boards, not just via ShogiGame instances).
  // ---------------------------------------------------------------------

  /// Pseudo-legal destinations for the piece at (row, col) - i.e. legal by
  /// movement pattern alone, NOT yet filtered for leaving one's own king in
  /// check.
  static List<Square> pseudoLegalMoves(List<List<ShogiPiece?>> b, int row, int col) {
    final piece = b[row][col];
    if (piece == null) return [];
    final isSente = piece.isSente;
    final fwd = isSente ? -1 : 1; // sente moves toward row 0.
    final moves = <Square>[];

    bool canLandOn(int r, int c) =>
        _onBoard(r, c) && (b[r][c] == null || b[r][c]!.isSente != isSente);

    void step(int dr, int dc) {
      final r = row + dr, c = col + dc;
      if (canLandOn(r, c)) moves.add((r, c));
    }

    void slide(int dr, int dc) {
      int r = row + dr, c = col + dc;
      while (_onBoard(r, c)) {
        if (b[r][c] != null && b[r][c]!.isSente == isSente) break;
        moves.add((r, c));
        if (b[r][c] != null) break;
        r += dr;
        c += dc;
      }
    }

    void goldMoves() {
      step(fwd, -1);
      step(fwd, 0);
      step(fwd, 1);
      step(0, -1);
      step(0, 1);
      step(-fwd, 0);
    }

    switch (piece.type) {
      case ShogiPieceType.king:
        for (int dr = -1; dr <= 1; dr++) {
          for (int dc = -1; dc <= 1; dc++) {
            if (dr != 0 || dc != 0) step(dr, dc);
          }
        }
      case ShogiPieceType.rook:
        slide(-1, 0);
        slide(1, 0);
        slide(0, -1);
        slide(0, 1);
      case ShogiPieceType.bishop:
        slide(-1, -1);
        slide(-1, 1);
        slide(1, -1);
        slide(1, 1);
      case ShogiPieceType.gold:
        goldMoves();
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
        slide(-1, 0);
        slide(1, 0);
        slide(0, -1);
        slide(0, 1);
        step(-1, -1);
        step(-1, 1);
        step(1, -1);
        step(1, 1);
      case ShogiPieceType.promotedBishop:
        slide(-1, -1);
        slide(-1, 1);
        slide(1, -1);
        slide(1, 1);
        step(-1, 0);
        step(1, 0);
        step(0, -1);
        step(0, 1);
      // Promoted gold-rank pieces (promoted silver/knight/lance/pawn) all
      // move exactly like a gold general.
      case ShogiPieceType.promotedSilver:
      case ShogiPieceType.promotedKnight:
      case ShogiPieceType.promotedLance:
      case ShogiPieceType.promotedPawn:
        goldMoves();
    }
    return moves;
  }

  static Square? kingSquare(List<List<ShogiPiece?>> b, bool isSente) {
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        final p = b[r][c];
        if (p != null && p.type == ShogiPieceType.king && p.isSente == isSente) {
          return (r, c);
        }
      }
    }
    return null;
  }

  /// Whether [isSente]'s king is currently in check on board [b].
  static bool isInCheck(List<List<ShogiPiece?>> b, bool isSente) {
    final king = kingSquare(b, isSente);
    if (king == null) return false;
    return _squareAttackedBy(b, king, !isSente);
  }

  static bool _squareAttackedBy(
    List<List<ShogiPiece?>> b,
    Square target,
    bool byIsSente,
  ) {
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        final p = b[r][c];
        if (p == null || p.isSente != byIsSente) continue;
        for (final m in pseudoLegalMoves(b, r, c)) {
          if (m.$1 == target.$1 && m.$2 == target.$2) return true;
        }
      }
    }
    return false;
  }

  /// Fully-legal destinations for the piece at (row, col): pseudo-legal
  /// moves filtered to exclude any that would leave the mover's own king in
  /// check.
  static List<Square> legalMoves(List<List<ShogiPiece?>> b, int row, int col) {
    final piece = b[row][col];
    if (piece == null) return [];
    final movingKing = piece.type == ShogiPieceType.king;
    final staticKingSquare = movingKing ? null : kingSquare(b, piece.isSente);
    return pseudoLegalMoves(b, row, col).where((dest) {
      final nb = _copyBoard(b);
      nb[dest.$1][dest.$2] = piece;
      nb[row][col] = null;
      final kingSq = movingKing ? dest : staticKingSquare;
      if (kingSq == null) return true; // Should not happen in a real game.
      return !_squareAttackedBy(nb, kingSq, !piece.isSente);
    }).toList();
  }

  /// Legal squares to drop a piece of [type] for player [isSente], given
  /// their hand must actually contain one, and respecting:
  ///  - no dropping onto an occupied square
  ///  - pawn/lance can't be dropped on the player's own furthest rank where
  ///    they'd have no legal move ever again (mirrors [ShogiPiece.mustPromote]
  ///    non-promotable-drop restriction)
  ///  - knight can't be dropped on either of its two furthest ranks
  ///  - 二歩 (nifu): can't drop a second un-promoted pawn on a file that
  ///    already has one of the player's own un-promoted pawns
  ///  - 打ち歩詰め (pawn-drop checkmate): a pawn drop may never be the move
  ///    that checkmates the opponent (dropping into any other kind of check
  ///    is fine, including a non-mating check)
  static List<Square> legalDropSquares(
    List<List<ShogiPiece?>> b,
    ShogiPieceType type,
    bool isSente,
    Map<ShogiPieceType, int> hand,
    Map<ShogiPieceType, int> opponentHand,
  ) {
    if ((hand[type] ?? 0) <= 0) return [];
    final squares = <Square>[];
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        if (b[r][c] != null) continue;

        if (type == ShogiPieceType.pawn || type == ShogiPieceType.lance) {
          if (isSente && r == 0) continue;
          if (!isSente && r == 8) continue;
        }
        if (type == ShogiPieceType.knight) {
          if (isSente && r <= 1) continue;
          if (!isSente && r >= 7) continue;
        }

        if (type == ShogiPieceType.pawn) {
          bool nifu = false;
          for (int rr = 0; rr < 9; rr++) {
            final p = b[rr][c];
            if (p != null && p.type == ShogiPieceType.pawn && p.isSente == isSente) {
              nifu = true;
              break;
            }
          }
          if (nifu) continue;
        }

        final nb = _copyBoard(b);
        nb[r][c] = ShogiPiece(type, isSente);

        // Can never drop into a position where one's own king is in check
        // (this can only actually happen for a piece dropped adjacent to
        // one's own king blocking nothing relevant, but keep the check for
        // correctness/defensiveness - mirrors komovia_shogi's logic).
        if (isInCheck(nb, isSente)) continue;

        if (type == ShogiPieceType.pawn &&
            _isPawnDropCheckmate(nb, isSente, opponentHand)) {
          continue;
        }

        squares.add((r, c));
      }
    }
    return squares;
  }

  static bool _isPawnDropCheckmate(
    List<List<ShogiPiece?>> b,
    bool droppedBySente,
    Map<ShogiPieceType, int> opponentHand,
  ) {
    final opponent = !droppedBySente;
    if (!isInCheck(b, opponent)) return false;
    return !hasAnyLegalMove(b, opponent, opponentHand);
  }

  /// Whether [isSente] has any legal move at all (board move or drop),
  /// given their [hand]. Used for checkmate/stalemate detection.
  static bool hasAnyLegalMove(
    List<List<ShogiPiece?>> b,
    bool isSente,
    Map<ShogiPieceType, int> hand,
  ) {
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        final p = b[r][c];
        if (p == null || p.isSente != isSente) continue;
        if (legalMoves(b, r, c).isNotEmpty) return true;
      }
    }
    // A drop can never be a "way out" of check/stalemate check here without
    // knowing the opponent's hand (needed for the pawn-drop-checkmate rule),
    // but that rule only matters for pawns specifically, and a drop of any
    // OTHER piece type never need consult the opponent's hand. For
    // determining "do I have ANY legal move", checking drops of all types
    // the player actually holds (with an empty opponent hand treated as the
    // conservative default) is sufficient: this function is only ever used
    // to ask about the player who just moved/was dropped against, with
    // their own hand, independent of the opponent's hand contents for
    // anything except the pawn-drop-checkmate exclusion (which only removes
    // pawn-drop squares, never adds any).
    for (final type in hand.keys) {
      if ((hand[type] ?? 0) <= 0) continue;
      if (legalDropSquares(b, type, isSente, hand, const {}).isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  // ---------------------------------------------------------------------
  // Instance API used by the UI.
  // ---------------------------------------------------------------------

  List<Square> legalMovesFrom(int row, int col) {
    final piece = board[row][col];
    if (piece == null || piece.isSente != senteTurn || isGameOver) return [];
    return legalMoves(board, row, col);
  }

  List<Square> legalDropSquaresFor(ShogiPieceType type) {
    if (isGameOver) return [];
    final hand = handFor(senteTurn);
    final oppHand = handFor(!senteTurn);
    return legalDropSquares(board, type, senteTurn, hand, oppHand);
  }

  /// Whether a move landing at [toRow] for the piece currently at [from]
  /// offers a promotion choice (true) vs. must/can't promote. Callers
  /// should ask this before calling [applyMove] when it returns true and a
  /// human choice is needed; [applyMove]'s `promote` param is then set from
  /// that choice (or forced per [ShogiPiece.mustPromote]).
  bool canChoosePromotion(Square from, int toRow) {
    final piece = board[from.$1][from.$2];
    if (piece == null || !piece.canPromote) return false;
    if (piece.mustPromote(toRow)) return false; // forced, not a choice.
    final inZone = piece.isSente ? (from.$1 <= 2 || toRow <= 2) : (from.$1 >= 6 || toRow >= 6);
    return inZone;
  }

  bool mustPromote(Square from, int toRow) {
    final piece = board[from.$1][from.$2];
    if (piece == null) return false;
    return piece.mustPromote(toRow);
  }

  /// Applies a board move. Caller is responsible for having confirmed [to]
  /// is in [legalMovesFrom(from)]. [promote] is honored only if the piece
  /// is promotion-eligible for this move; a forced promotion
  /// ([ShogiPiece.mustPromote]) is applied regardless of [promote].
  void applyMove(Square from, Square to, {bool promote = false}) {
    final piece = board[from.$1][from.$2];
    if (piece == null) return;
    final captured = board[to.$1][to.$2];
    if (captured != null) {
      final hand = handFor(piece.isSente);
      final base = captured.baseType;
      hand[base] = (hand[base] ?? 0) + 1;
    }
    final forced = piece.mustPromote(to.$1);
    final willPromote = forced || (promote && piece.canPromote);
    board[to.$1][to.$2] =
        willPromote ? ShogiPiece(piece.promotedType, piece.isSente) : piece;
    board[from.$1][from.$2] = null;
    _finishTurn();
  }

  /// Applies a drop of [type] at [to]. Caller is responsible for having
  /// confirmed [to] is in [legalDropSquaresFor(type)].
  void applyDrop(ShogiPieceType type, Square to) {
    final hand = handFor(senteTurn);
    if ((hand[type] ?? 0) <= 0) return;
    board[to.$1][to.$2] = ShogiPiece(type, senteTurn);
    hand[type] = hand[type]! - 1;
    if (hand[type] == 0) hand.remove(type);
    _finishTurn();
  }

  void _finishTurn() {
    senteTurn = !senteTurn;
    final inCheck = isInCheck(board, senteTurn);
    final hasMove = hasAnyLegalMove(board, senteTurn, handFor(senteTurn));
    if (!hasMove) {
      outcome = inCheck
          ? (senteTurn ? ShogiOutcome.goteWins : ShogiOutcome.senteWins)
          : ShogiOutcome.stalemateDraw;
    } else {
      outcome = ShogiOutcome.none;
    }
  }

  bool get sideToMoveInCheck => isInCheck(board, senteTurn);
}
