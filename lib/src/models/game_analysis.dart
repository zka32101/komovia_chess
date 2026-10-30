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
