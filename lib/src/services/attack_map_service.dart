import 'package:chess/chess.dart' as chess_lib;

/// How many of each side's pieces currently attack/defend a single square,
/// independent of whether that square is occupied, by whom, or whose turn
/// it is. A piece "attacks" a square it could capture on right now if an
/// enemy piece stood there, and "defends" a square occupied by its own
/// color the same way - both are the same geometric relationship, so one
/// count per color covers both ("defended by 2" and "attacked by 2" are
/// the same [white]/[black] number, just read differently depending on
/// who occupies the square).
class SquareAttackers {
  const SquareAttackers({this.white = 0, this.black = 0});

  final int white;
  final int black;

  /// True once at least one side attacks this square at all - callers use
  /// this to skip drawing anything on quiet squares.
  bool get isEmpty => white == 0 && black == 0;

  /// True when both sides attack the same square - the "contested"
  /// squares a tactics-focused overlay is most useful for highlighting.
  bool get isContested => white > 0 && black > 0;

  @override
  bool operator ==(Object other) =>
      other is SquareAttackers && other.white == white && other.black == black;

  @override
  int get hashCode => Object.hash(white, black);
}

/// Computes, for every occupied-or-reachable square on the board, how many
/// white pieces and how many black pieces attack/defend it right now.
///
/// `package:chess` (this app's existing move-generation dependency) has no
/// public per-square attacker-count API: its `Chess.attacked(color, square)`
/// is a private-board-internals boolean ("is this square attacked by this
/// color at all"), not exposed per-piece, and `Chess.generate_moves()`
/// filters to only the moves legal in the current position (e.g. it won't
/// report a pinned piece's "attack" on a square it can't actually move to
/// without exposing its own king) - which is the wrong semantics for a
/// tactical-tension overlay that should show every square a piece's
/// movement pattern reaches regardless of whose turn it is or whether
/// playing there would be legal this move. So this is computed directly
/// from the board via `package:chess`'s public `Chess.get(square)`, using
/// chess's own attack rules rather than reusing shogi's piece-movement
/// model: pawns attack diagonally (not where they move), knights jump
/// over anything, and bishops/rooks/queens slide until blocked by ANY
/// piece - including one of their own color, which still "defends" the
/// blocking square but can't see past it.
class AttackMapService {
  AttackMapService._();

  static const _files = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];

  static const _knightOffsets = [
    (1, 2),
    (2, 1),
    (2, -1),
    (1, -2),
    (-1, -2),
    (-2, -1),
    (-2, 1),
    (-1, 2),
  ];

  static const _diagonalDirs = [(1, 1), (1, -1), (-1, 1), (-1, -1)];
  static const _orthogonalDirs = [(1, 0), (-1, 0), (0, 1), (0, -1)];
  static const _allDirs = [..._diagonalDirs, ..._orthogonalDirs];

  /// Returns attacker counts for every square the current position has
  /// at least one attacker/defender on. Squares with no attacker at all
  /// from either side are omitted rather than included with a zero count,
  /// so callers can just check `map.containsKey(square)` / iterate the
  /// map instead of every square on the board.
  static Map<String, SquareAttackers> compute(chess_lib.Chess chess) {
    final whiteCounts = <String, int>{};
    final blackCounts = <String, int>{};

    for (final file in _files) {
      for (var rank = 1; rank <= 8; rank++) {
        final square = '$file$rank';
        final piece = chess.get(square);
        if (piece == null) continue;

        final counts =
            piece.color == chess_lib.Color.WHITE ? whiteCounts : blackCounts;
        for (final target in _squaresAttackedFrom(chess, square, piece)) {
          counts[target] = (counts[target] ?? 0) + 1;
        }
      }
    }

    final result = <String, SquareAttackers>{};
    final allTargets = {...whiteCounts.keys, ...blackCounts.keys};
    for (final square in allTargets) {
      result[square] = SquareAttackers(
        white: whiteCounts[square] ?? 0,
        black: blackCounts[square] ?? 0,
      );
    }
    return result;
  }

  /// Every square [piece], standing on [square], geometrically
  /// attacks/defends right now - ignoring whose turn it is, pins, and
  /// check legality (see the class doc comment for why).
  static List<String> _squaresAttackedFrom(
    chess_lib.Chess chess,
    String square,
    chess_lib.Piece piece,
  ) {
    final file = _files.indexOf(square[0]);
    final rank = int.parse(square.substring(1));

    switch (piece.type) {
      case chess_lib.PieceType.PAWN:
        // Pawns attack diagonally one square forward, never straight
        // ahead where they move - the one chess rule with no shogi
        // analogue at all (shogi pawns move and capture the same way).
        final dir = piece.color == chess_lib.Color.WHITE ? 1 : -1;
        return _onBoard([(file - 1, rank + dir), (file + 1, rank + dir)]);

      case chess_lib.PieceType.KNIGHT:
        return _onBoard(
          _knightOffsets.map((d) => (file + d.$1, rank + d.$2)),
        );

      case chess_lib.PieceType.KING:
        return _onBoard([
          for (var df = -1; df <= 1; df++)
            for (var dr = -1; dr <= 1; dr++)
              if (df != 0 || dr != 0) (file + df, rank + dr),
        ]);

      case chess_lib.PieceType.BISHOP:
        return _slide(chess, file, rank, _diagonalDirs);

      case chess_lib.PieceType.ROOK:
        return _slide(chess, file, rank, _orthogonalDirs);

      case chess_lib.PieceType.QUEEN:
        return _slide(chess, file, rank, _allDirs);
    }

    return const [];
  }

  /// Walks each direction in [dirs] from (file, rank) until it runs off
  /// the board or hits an occupied square - the occupied square itself IS
  /// included (a sliding piece attacks/defends whatever sits there,
  /// friend or foe) but nothing further along that ray is, since any
  /// piece - same color or not - fully blocks the line.
  static List<String> _slide(
    chess_lib.Chess chess,
    int file,
    int rank,
    List<(int, int)> dirs,
  ) {
    final out = <String>[];
    for (final d in dirs) {
      var f = file + d.$1;
      var r = rank + d.$2;
      while (f >= 0 && f <= 7 && r >= 1 && r <= 8) {
        final square = '${_files[f]}$r';
        out.add(square);
        if (chess.get(square) != null) break;
        f += d.$1;
        r += d.$2;
      }
    }
    return out;
  }

  static List<String> _onBoard(Iterable<(int, int)> coords) => coords
      .where((c) => c.$1 >= 0 && c.$1 <= 7 && c.$2 >= 1 && c.$2 <= 8)
      .map((c) => '${_files[c.$1]}${c.$2}')
      .toList();
}
