import '../services/ai_opponent_engine_enhanced.dart';
import '../widgets/performance_graphs.dart';

/// Represents a complete game with all analysis data
class GameRecord {
  GameRecord({
    required this.gameId,
    required this.playedAt,
    required this.difficulty,
    required this.result,
    required this.totalMoves,
    required this.totalTimeMs,
    required this.moveMetrics,
    required this.statistics,
    this.notes,
  });

  /// Create from JSON
  factory GameRecord.fromJson(Map<String, dynamic> json) => GameRecord(
        gameId: json['gameId'] as String,
        playedAt: DateTime.parse(json['playedAt'] as String),
        difficulty: _parseDifficulty(json['difficulty'] as String),
        result: GameResult.values.byName(json['result'] as String),
        totalMoves: json['totalMoves'] as int,
        totalTimeMs: json['totalTimeMs'] as int,
        moveMetrics: (json['moveMetrics'] as List?)
                ?.map((m) => _moveMetricsFromJson(m as Map<String, dynamic>))
                .toList() ??
            [],
        statistics:
            GameStatistics.fromJson(json['statistics'] as Map<String, dynamic>),
        notes: json['notes'] as String?,
      );
  final String gameId;
  final DateTime playedAt;
  final AIDifficulty difficulty;
  final GameResult result;
  final int totalMoves;
  final int totalTimeMs;

  /// Performance metrics for all AI moves
  final List<MoveMetrics> moveMetrics;

  /// Aggregated statistics
  final GameStatistics statistics;

  /// Player notes
  final String? notes;

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() => {
        'gameId': gameId,
        'playedAt': playedAt.toIso8601String(),
        'difficulty': difficulty.displayName,
        'result': result.name,
        'totalMoves': totalMoves,
        'totalTimeMs': totalTimeMs,
        'moveMetrics': moveMetrics.map(_moveMetricsToJson).toList(),
        'statistics': statistics.toJson(),
        'notes': notes,
      };

  static AIDifficulty _parseDifficulty(String name) {
    switch (name.toLowerCase()) {
      case 'easy':
        return AIDifficulty.easy;
      case 'medium':
        return AIDifficulty.medium;
      case 'hard':
        return AIDifficulty.hard;
      default:
        return AIDifficulty.medium;
    }
  }

  static Map<String, dynamic> _moveMetricsToJson(MoveMetrics m) => {
        'moveNumber': m.moveNumber,
        'nodesEvaluated': m.nodesEvaluated,
        'timeMs': m.timeMs,
        'depth': m.depth,
        'cacheHitRate': m.cacheHitRate,
        'zobristHits': m.zobristHits,
        'zobristMisses': m.zobristMisses,
        'killerCutoffs': m.killerCutoffs,
        'countermoveCutoffs': m.countermoveCutoffs,
        'gamePhase': m.gamePhase,
      };

  static MoveMetrics _moveMetricsFromJson(Map<String, dynamic> json) =>
      MoveMetrics(
        moveNumber: json['moveNumber'] as int,
        nodesEvaluated: json['nodesEvaluated'] as int,
        timeMs: json['timeMs'] as int,
        depth: json['depth'] as int,
        cacheHitRate: json['cacheHitRate'] as double,
        zobristHits: json['zobristHits'] as int,
        zobristMisses: json['zobristMisses'] as int,
        killerCutoffs: json['killerCutoffs'] as int,
        countermoveCutoffs: json['countermoveCutoffs'] as int,
        gamePhase: json['gamePhase'] as String,
      );
}

/// Game result enumeration
enum GameResult {
  win('Win', 1),
  draw('Draw', 0.5),
  loss('Loss', 0);

  final String displayName;
  final double scoreValue;

  const GameResult(this.displayName, this.scoreValue);
}

/// Aggregated statistics for a single game
class GameStatistics {
  GameStatistics({
    required this.avgNodesPerSec,
    required this.avgCacheHitRate,
    required this.avgSearchDepth,
    required this.avgTimePerMove,
    required this.totalKillerCutoffs,
    required this.totalCountermoveCutoffs,
    required this.openingStats,
    required this.midgameStats,
    required this.endgameStats,
  });

  /// Calculate from move metrics
  factory GameStatistics.fromMetrics(List<MoveMetrics> metrics) {
    if (metrics.isEmpty) {
      return GameStatistics(
        avgNodesPerSec: 0,
        avgCacheHitRate: 0,
        avgSearchDepth: 0,
        avgTimePerMove: 0,
        totalKillerCutoffs: 0,
        totalCountermoveCutoffs: 0,
        openingStats: PhaseStatistics.empty(),
        midgameStats: PhaseStatistics.empty(),
        endgameStats: PhaseStatistics.empty(),
      );
    }

    // Calculate averages
    double totalNodesPerSec = 0;
    double totalCacheHitRate = 0;
    double totalDepth = 0;
    double totalTime = 0;
    int totalKillers = 0;
    int totalCountermoves = 0;

    final List<MoveMetrics> openingMetrics = [];
    final List<MoveMetrics> midgameMetrics = [];
    final List<MoveMetrics> endgameMetrics = [];

    for (final m in metrics) {
      totalNodesPerSec += m.nodesEvaluated / (m.timeMs / 1000);
      totalCacheHitRate += m.cacheHitRate;
      totalDepth += m.depth;
      totalTime += m.timeMs;
      totalKillers += m.killerCutoffs;
      totalCountermoves += m.countermoveCutoffs;

      // Categorize by phase
      switch (m.gamePhase) {
        case 'opening':
          openingMetrics.add(m);
          break;
        case 'midgame':
          midgameMetrics.add(m);
          break;
        case 'endgame':
          endgameMetrics.add(m);
          break;
      }
    }

    final count = metrics.length.toDouble();
    return GameStatistics(
      avgNodesPerSec: totalNodesPerSec / count,
      avgCacheHitRate: totalCacheHitRate / count,
      avgSearchDepth: totalDepth / count,
      avgTimePerMove: totalTime / count,
      totalKillerCutoffs: totalKillers,
      totalCountermoveCutoffs: totalCountermoves,
      openingStats: PhaseStatistics.fromMetrics(openingMetrics),
      midgameStats: PhaseStatistics.fromMetrics(midgameMetrics),
      endgameStats: PhaseStatistics.fromMetrics(endgameMetrics),
    );
  }

  /// Create from JSON
  factory GameStatistics.fromJson(Map<String, dynamic> json) => GameStatistics(
        avgNodesPerSec: json['avgNodesPerSec'] as double? ?? 0,
        avgCacheHitRate: json['avgCacheHitRate'] as double? ?? 0,
        avgSearchDepth: json['avgSearchDepth'] as double? ?? 0,
        avgTimePerMove: json['avgTimePerMove'] as double? ?? 0,
        totalKillerCutoffs: json['totalKillerCutoffs'] as int? ?? 0,
        totalCountermoveCutoffs: json['totalCountermoveCutoffs'] as int? ?? 0,
        openingStats: PhaseStatistics.fromJson(
            json['openingStats'] as Map<String, dynamic>? ?? {}),
        midgameStats: PhaseStatistics.fromJson(
            json['midgameStats'] as Map<String, dynamic>? ?? {}),
        endgameStats: PhaseStatistics.fromJson(
            json['endgameStats'] as Map<String, dynamic>? ?? {}),
      );
  final double avgNodesPerSec;
  final double avgCacheHitRate;
  final double avgSearchDepth;
  final double avgTimePerMove;
  final int totalKillerCutoffs;
  final int totalCountermoveCutoffs;

  /// Performance by game phase
  final PhaseStatistics openingStats;
  final PhaseStatistics midgameStats;
  final PhaseStatistics endgameStats;

  /// Convert to JSON
  Map<String, dynamic> toJson() => {
        'avgNodesPerSec': avgNodesPerSec,
        'avgCacheHitRate': avgCacheHitRate,
        'avgSearchDepth': avgSearchDepth,
        'avgTimePerMove': avgTimePerMove,
        'totalKillerCutoffs': totalKillerCutoffs,
        'totalCountermoveCutoffs': totalCountermoveCutoffs,
        'openingStats': openingStats.toJson(),
        'midgameStats': midgameStats.toJson(),
        'endgameStats': endgameStats.toJson(),
      };
}

/// Statistics for a specific game phase
class PhaseStatistics {
  PhaseStatistics({
    required this.moveCount,
    required this.avgNodesPerSec,
    required this.avgCacheHitRate,
    required this.avgSearchDepth,
    required this.totalCutoffs,
  });

  /// Empty statistics
  factory PhaseStatistics.empty() => PhaseStatistics(
        moveCount: 0,
        avgNodesPerSec: 0,
        avgCacheHitRate: 0,
        avgSearchDepth: 0,
        totalCutoffs: 0,
      );

  /// Calculate from metrics
  factory PhaseStatistics.fromMetrics(List<MoveMetrics> metrics) {
    if (metrics.isEmpty) return PhaseStatistics.empty();

    double totalNodesPerSec = 0;
    double totalCacheHitRate = 0;
    double totalDepth = 0;
    int totalCutoffs = 0;

    for (final m in metrics) {
      totalNodesPerSec += m.nodesEvaluated / (m.timeMs / 1000);
      totalCacheHitRate += m.cacheHitRate;
      totalDepth += m.depth;
      totalCutoffs += m.killerCutoffs + m.countermoveCutoffs;
    }

    final count = metrics.length.toDouble();
    return PhaseStatistics(
      moveCount: metrics.length,
      avgNodesPerSec: totalNodesPerSec / count,
      avgCacheHitRate: totalCacheHitRate / count,
      avgSearchDepth: totalDepth / count,
      totalCutoffs: totalCutoffs,
    );
  }

  /// Create from JSON
  factory PhaseStatistics.fromJson(Map<String, dynamic> json) =>
      PhaseStatistics(
        moveCount: json['moveCount'] as int? ?? 0,
        avgNodesPerSec: json['avgNodesPerSec'] as double? ?? 0,
        avgCacheHitRate: json['avgCacheHitRate'] as double? ?? 0,
        avgSearchDepth: json['avgSearchDepth'] as double? ?? 0,
        totalCutoffs: json['totalCutoffs'] as int? ?? 0,
      );
  final int moveCount;
  final double avgNodesPerSec;
  final double avgCacheHitRate;
  final double avgSearchDepth;
  final int totalCutoffs;

  /// Convert to JSON
  Map<String, dynamic> toJson() => {
        'moveCount': moveCount,
        'avgNodesPerSec': avgNodesPerSec,
        'avgCacheHitRate': avgCacheHitRate,
        'avgSearchDepth': avgSearchDepth,
        'totalCutoffs': totalCutoffs,
      };
}

/// Player statistics aggregated across games
class PlayerStatistics {
  PlayerStatistics({
    required this.playerId,
    required this.games,
    required this.firstGame,
    required this.lastGame,
  });
  final String playerId;
  final List<GameRecord> games;
  final DateTime firstGame;
  final DateTime lastGame;

  /// Total games played
  int get totalGames => games.length;

  /// Games by result
  int get wins => games.where((g) => g.result == GameResult.win).length;
  int get draws => games.where((g) => g.result == GameResult.draw).length;
  int get losses => games.where((g) => g.result == GameResult.loss).length;

  /// Win rate (0.0-1.0)
  double get winRate {
    if (totalGames == 0) return 0;
    return wins / totalGames;
  }

  /// Games by difficulty
  List<GameRecord> gamesByDifficulty(AIDifficulty difficulty) =>
      games.where((g) => g.difficulty == difficulty).toList();

  /// Average stats by difficulty
  Map<String, dynamic> getStatsByDifficulty(AIDifficulty difficulty) {
    final difficultyGames = gamesByDifficulty(difficulty);
    if (difficultyGames.isEmpty) {
      return {
        'gamesPlayed': 0,
        'avgNodesPerSec': 0,
        'avgCacheHitRate': 0,
        'avgSearchDepth': 0,
      };
    }

    double totalNodes = 0;
    double totalCache = 0;
    double totalDepth = 0;

    for (final game in difficultyGames) {
      totalNodes += game.statistics.avgNodesPerSec;
      totalCache += game.statistics.avgCacheHitRate;
      totalDepth += game.statistics.avgSearchDepth;
    }

    final count = difficultyGames.length.toDouble();
    return {
      'gamesPlayed': difficultyGames.length,
      'avgNodesPerSec': totalNodes / count,
      'avgCacheHitRate': totalCache / count,
      'avgSearchDepth': totalDepth / count,
    };
  }

  /// Overall performance metrics
  Map<String, dynamic> getOverallStats() {
    if (games.isEmpty) {
      return {
        'totalGames': 0,
        'winRate': 0,
        'avgNodesPerSec': 0,
        'avgCacheHitRate': 0,
      };
    }

    double totalNodes = 0;
    double totalCache = 0;

    for (final game in games) {
      totalNodes += game.statistics.avgNodesPerSec;
      totalCache += game.statistics.avgCacheHitRate;
    }

    return {
      'totalGames': totalGames,
      'wins': wins,
      'draws': draws,
      'losses': losses,
      'winRate': winRate,
      'avgNodesPerSec': totalNodes / games.length,
      'avgCacheHitRate': totalCache / games.length,
    };
  }

  /// Performance trend (comparing first half vs second half of games)
  Map<String, dynamic> getPerformanceTrend() {
    if (games.length < 4) {
      return {'trend': 'insufficient_data'};
    }

    final midpoint = games.length ~/ 2;
    final firstHalf = games.sublist(0, midpoint);
    final secondHalf = games.sublist(midpoint);

    double firstHalfNodes = 0;
    double secondHalfNodes = 0;
    double firstHalfCache = 0;
    double secondHalfCache = 0;

    for (final game in firstHalf) {
      firstHalfNodes += game.statistics.avgNodesPerSec;
      firstHalfCache += game.statistics.avgCacheHitRate;
    }

    for (final game in secondHalf) {
      secondHalfNodes += game.statistics.avgNodesPerSec;
      secondHalfCache += game.statistics.avgCacheHitRate;
    }

    firstHalfNodes /= firstHalf.length;
    secondHalfNodes /= secondHalf.length;
    firstHalfCache /= firstHalf.length;
    secondHalfCache /= secondHalf.length;

    final nodeImprovement =
        (secondHalfNodes - firstHalfNodes) / firstHalfNodes * 100;
    final cacheImprovement =
        (secondHalfCache - firstHalfCache) / firstHalfCache * 100;

    return {
      'firstHalfAvgNodesPerSec': firstHalfNodes.toStringAsFixed(0),
      'secondHalfAvgNodesPerSec': secondHalfNodes.toStringAsFixed(0),
      'nodeImprovement': nodeImprovement.toStringAsFixed(1),
      'cacheImprovement': cacheImprovement.toStringAsFixed(1),
      'trend': nodeImprovement > 0 ? 'improving' : 'declining',
    };
  }
}
