import 'package:komovia_core/komovia_core.dart' show MoveQuality, classifyMoveQuality;

export 'package:komovia_core/komovia_core.dart' show MoveQuality, classifyMoveQuality;

/// Engine-based post-game analysis. "AI" here means Stockfish's own
/// evaluation (already wired into this app via StockfishEngineService for
/// the live eval bar) classifying how much each move cost the player who
/// made it - not a generative/LLM feature, since this app has no LLM
/// backend. Named to match the family's "Phase J" vocabulary
/// (game analysis, move classification) without claiming more than what's
/// actually computed.
///
/// [MoveQuality]/[classifyMoveQuality] now live in komovia_core (generalized
/// from this app's own original scheme, same 300/100/50/15 centipawn-loss
/// thresholds) so komovia_shogi's review feature can share it instead of
/// reimplementing it - see komovia_core's review.dart doc comment.
extension MoveQualityLabel on MoveQuality {
  String get label {
    switch (this) {
      case MoveQuality.best:
        return 'Best';
      case MoveQuality.good:
        return 'Good';
      case MoveQuality.inaccuracy:
        return 'Inaccuracy';
      case MoveQuality.mistake:
        return 'Mistake';
      case MoveQuality.blunder:
        return 'Blunder';
    }
  }
}

class MoveAnalysis {
  const MoveAnalysis({
    required this.moveIndex,
    required this.notation,
    required this.isWhiteMove,
    required this.evalBeforeCp,
    required this.evalAfterCp,
    required this.centipawnLoss,
    required this.quality,
    this.san,
    this.isCapture = false,
    this.isCheck = false,
    this.isCheckmate = false,
    this.capturedPieceType,
    this.legalMoveCountBefore,
    this.fenAfter,
  });

  /// 0-based index into the game's move list.
  final int moveIndex;
  final String notation;
  final bool isWhiteMove;

  /// Position evaluation in centipawns from White's perspective, before
  /// and after this move.
  final int evalBeforeCp;
  final int evalAfterCp;

  /// How much the move cost the side who played it (always >= 0).
  final int centipawnLoss;
  final MoveQuality quality;

  /// Standard algebraic notation for this move (e.g. "Nxf7+", "O-O"),
  /// including package:chess's own capture/check/checkmate suffixes -
  /// kept here (rather than re-derived from [notation]'s plain
  /// "e2-e4"-style squares) so MoveCommentaryService doesn't need to
  /// re-run move classification that ChessAnalysisService's loop already
  /// did while applying the move. Nullable so a MoveAnalysis built
  /// without this extra context (e.g. in existing tests/call sites) still
  /// compiles; MoveCommentaryService falls back to [notation] when null.
  final String? san;

  /// Whether this move captured a piece, gave check, or delivered
  /// checkmate - from the same chess_lib move history entry [san] comes
  /// from.
  final bool isCapture;
  final bool isCheck;
  final bool isCheckmate;

  /// Single lowercase chess_lib.PieceType letter ('p'/'n'/'b'/'r'/'q'/'k')
  /// for the piece this move captured, or null when [isCapture] is false.
  /// A plain String (not chess_lib's own PieceType) so this model doesn't
  /// need to depend on package:chess itself.
  final String? capturedPieceType;

  /// Number of legal moves the mover had available *before* playing this
  /// move - used to tell a forced/only move apart from one good option
  /// among several (see MoveCommentaryService). Null when not computed.
  final int? legalMoveCountBefore;

  /// FEN of the position immediately after this move (opponent to move)
  /// - lets MoveCommentaryService cheaply check whether the move left one
  /// of the mover's own pieces hanging, without replaying the whole game
  /// again. Null when not computed.
  final String? fenAfter;
}

class GameAnalysis {
  const GameAnalysis({
    required this.moves,
    required this.whiteAccuracy,
    required this.blackAccuracy,
  });

  final List<MoveAnalysis> moves;

  /// Share of each side's own moves classified best/good (0-100) - a
  /// simple proxy for "accuracy", not the win-probability-based model
  /// chess.com's own Accuracy score uses.
  final double whiteAccuracy;
  final double blackAccuracy;

  List<MoveAnalysis> movesBy(bool isWhite) =>
      moves.where((m) => m.isWhiteMove == isWhite).toList();

  List<MoveAnalysis> get blunders =>
      moves.where((m) => m.quality == MoveQuality.blunder).toList();

  List<MoveAnalysis> get mistakes =>
      moves.where((m) => m.quality == MoveQuality.mistake).toList();
}
