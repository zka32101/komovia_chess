import 'package:chess/chess.dart' as chess_lib;
import 'package:komovia_core/komovia_core.dart';

/// Chess's [Position]: a FEN string (board + side to move + castling
/// rights + en passant target + halfmove clock + fullmove number — the
/// `chess` pub package's `Chess.fen`/`Chess.fromFEN` already round-trip
/// this exactly), plus [resignedBy] for the one piece of end-of-game state
/// a FEN snapshot can't carry — mirroring `GoPosition`/`ShogiPosition`'s
/// own bolted-on `resignedBy` field.
///
/// Side mapping: white moves first in standard chess, so [Side.first] =
/// white, [Side.second] = black — the opposite of go/shogi's
/// black/先手-moves-first convention (see `side.dart`'s own doc comment,
/// which lists "chess (white/black)" as one of the three vocabularies
/// [Side.first]/[Side.second] stand in for, without picking an order).
/// `sideToMove` reads straight off FEN field 2 ('w'/'b').
///
/// Deliberately stores only the FEN string rather than holding a live
/// `chess_lib.Chess` instance: `chess_lib.Chess` is a mutable object (its
/// own `move()`/`make_move()`/`undo_move()` mutate in place), while
/// [Position] must be immutable (see that class's own doc comment) and
/// `Game.apply` must leave its input untouched. Reconstructing a fresh
/// `chess_lib.Chess.fromFEN(fen)` on demand (see [toChess]) is cheap and
/// guarantees no [ChessPosition] is ever accidentally mutated out from
/// under a caller.
class ChessPosition extends Position {
  final String fen;

  /// Set once a side resigns; null while the game continues normally.
  final Side? resignedBy;

  const ChessPosition({required this.fen, this.resignedBy});

  @override
  Side get sideToMove => _turnToken == 'w' ? Side.first : Side.second;

  String get _turnToken => fen.split(' ')[1];

  ChessPosition copyWith({String? fen, Side? resignedBy}) => ChessPosition(
        fen: fen ?? this.fen,
        resignedBy: resignedBy ?? this.resignedBy,
      );

  /// A fresh `chess_lib.Chess` loaded from [fen], for callers that need to
  /// query/generate moves on the real rules engine. Always a new instance
  /// — see the class comment on why [ChessPosition] never holds one of
  /// its own.
  chess_lib.Chess toChess() => chess_lib.Chess.fromFEN(fen);

  @override
  String toString() =>
      'ChessPosition(fen: $fen, sideToMove: $sideToMove, resignedBy: $resignedBy)';
}
