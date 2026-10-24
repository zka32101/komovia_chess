import '../models/game_analysis.dart';
import '../models/lesson.dart' show ContentType;

/// Which part of the game a move belongs to, by half-move index (0-based,
/// counting both sides' moves - matching [MoveAnalysis.moveIndex]).
/// A rough, move-count-based split (not position-aware - no castling/
/// piece-count heuristic), good enough to bucket where a player's
/// mistakes cluster without needing a second engine pass.
enum GamePhase {
  opening,
  middlegame,
  endgame;

  static GamePhase fromMoveIndex(int moveIndex) {
    if (moveIndex < 20) return GamePhase.opening; // first 10 move pairs
    if (moveIndex < 60) return GamePhase.middlegame; // through move 30
    return GamePhase.endgame;
  }

  String get label {
    switch (this) {
      case GamePhase.opening:
        return 'オープニング';
      case GamePhase.middlegame:
        return '中盤';
      case GamePhase.endgame:
        return '終盤';
    }
  }

  /// The curriculum content type most relevant to improving at this
  /// phase. Endgame has no dedicated ContentType in this app's
  /// curriculum (opening/tactic/strategy only) - strategy guides are the
  /// closest existing fit.
  ContentType get recommendedContentType {
    switch (this) {
      case GamePhase.opening:
        return ContentType.opening;
      case GamePhase.middlegame:
        return ContentType.tactic;
      case GamePhase.endgame:
        return ContentType.strategy;
    }
  }
}

/// Per-phase mistake counters for one player's moves in one analyzed
/// game (or summed across several).
class PhaseStats {
  const PhaseStats({
    this.movesPlayed = 0,
    this.mistakes = 0,
    this.blunders = 0,
  });

  factory PhaseStats.fromJson(Map<String, dynamic> json) => PhaseStats(
        movesPlayed: (json['movesPlayed'] as num?)?.toInt() ?? 0,
        mistakes: (json['mistakes'] as num?)?.toInt() ?? 0,
        blunders: (json['blunders'] as num?)?.toInt() ?? 0,
      );

  final int movesPlayed;
  final int mistakes;
  final int blunders;

  /// Mistakes and blunders both count as "errors" for ranking which
  /// phase is weakest - a blunder is worse per-move, but counting it
  /// twice here would double-penalize a single bad move; the raw counts
  /// are still kept separately for display.
  int get errorCount => mistakes + blunders;

  double get errorRate => movesPlayed == 0 ? 0 : errorCount / movesPlayed;

  PhaseStats operator +(PhaseStats other) => PhaseStats(
        movesPlayed: movesPlayed + other.movesPlayed,
        mistakes: mistakes + other.mistakes,
        blunders: blunders + other.blunders,
      );

  Map<String, dynamic> toJson() => {
        'movesPlayed': movesPlayed,
        'mistakes': mistakes,
        'blunders': blunders,
      };
}

/// One game's worth of per-phase stats for a single player, derived from
/// a [GameAnalysis] already computed by ChessAnalysisService. Persisted
/// to Firestore (one doc per analyzed game) so a player's weaknesses can
/// be aggregated across every game they've ever had analyzed, not just
/// the one currently open in GameAnalysisScreen.
class GameWeaknessSummary {
  const GameWeaknessSummary({
    required this.gameId,
    required this.analyzedAt,
    required this.byPhase,
  });

  factory GameWeaknessSummary.fromJson(String gameId, Map<String, dynamic> json) {
    final rawPhases = json['byPhase'] as Map<String, dynamic>? ?? const {};
    return GameWeaknessSummary(
      gameId: gameId,
      analyzedAt: json['analyzedAt'] is String
          ? DateTime.parse(json['analyzedAt'] as String)
          : DateTime.now(),
      byPhase: {
        for (final phase in GamePhase.values)
          phase: PhaseStats.fromJson(
            (rawPhases[phase.name] as Map<String, dynamic>?) ?? const {},
          ),
      },
    );
  }

  factory GameWeaknessSummary.fromGameAnalysis({
    required String gameId,
    required GameAnalysis analysis,
    required bool isWhitePlayer,
  }) {
    final byPhase = <GamePhase, PhaseStats>{
      for (final phase in GamePhase.values) phase: const PhaseStats(),
    };
    for (final move in analysis.movesBy(isWhitePlayer)) {
      final phase = GamePhase.fromMoveIndex(move.moveIndex);
      final isMistake = move.quality == MoveQuality.mistake;
      final isBlunder = move.quality == MoveQuality.blunder;
      byPhase[phase] = byPhase[phase]! +
          PhaseStats(
            movesPlayed: 1,
            mistakes: isMistake ? 1 : 0,
            blunders: isBlunder ? 1 : 0,
          );
    }
    return GameWeaknessSummary(
      gameId: gameId,
      analyzedAt: DateTime.now(),
      byPhase: byPhase,
    );
  }

  final String gameId;
  final DateTime analyzedAt;
  final Map<GamePhase, PhaseStats> byPhase;

  Map<String, dynamic> toJson() => {
        'analyzedAt': analyzedAt.toIso8601String(),
        'byPhase': {
          for (final entry in byPhase.entries) entry.key.name: entry.value.toJson(),
        },
      };
}

/// A player's weaknesses aggregated across every game they've had
/// analyzed, used to recommend specific learning content.
class WeaknessProfile {
  const WeaknessProfile({required this.byPhase, required this.gamesAnalyzed});

  static const empty = WeaknessProfile(
    byPhase: {
      GamePhase.opening: PhaseStats(),
      GamePhase.middlegame: PhaseStats(),
      GamePhase.endgame: PhaseStats(),
    },
    gamesAnalyzed: 0,
  );

  final Map<GamePhase, PhaseStats> byPhase;
  final int gamesAnalyzed;

  bool get hasEnoughData => gamesAnalyzed > 0 && totalMovesPlayed >= 10;

  int get totalMovesPlayed =>
      byPhase.values.fold(0, (sum, s) => sum + s.movesPlayed);

  /// The phase with the highest error rate among phases with at least
  /// one move played - null if there's no data at all yet.
  GamePhase? get weakestPhase {
    GamePhase? weakest;
    double bestRate = -1;
    for (final entry in byPhase.entries) {
      if (entry.value.movesPlayed == 0) continue;
      if (entry.value.errorRate > bestRate) {
        bestRate = entry.value.errorRate;
        weakest = entry.key;
      }
    }
    return weakest;
  }
}
