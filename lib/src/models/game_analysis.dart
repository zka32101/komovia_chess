/// Engine-based post-game analysis. "AI" here means Stockfish's own
/// evaluation (already wired into this app via StockfishEngineService for
/// the live eval bar) classifying how much each move cost the player who
/// made it - not a generative/LLM feature, since this app has no LLM
/// backend. Named to match the family's "Phase J" vocabulary
/// (game analysis, move classification) without claiming more than what's
/// actually computed.
enum MoveQuality {
  best,
  good,
  inaccuracy,
  mistake,
  blunder;

  /// Centipawn-loss thresholds a move's quality is classified by -
  /// loosely modeled on how most chess apps bucket this (chess.com,
  /// lichess), not an exact match to either.
  static MoveQuality fromCentipawnLoss(int loss) {
    if (loss >= 300) return MoveQuality.blunder;
    if (loss >= 100) return MoveQuality.mistake;
    if (loss >= 50) return MoveQuality.inaccuracy;
    if (loss >= 15) return MoveQuality.good;
    return MoveQuality.best;
  }

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
