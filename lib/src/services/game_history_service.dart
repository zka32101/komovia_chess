import '../models/game_history.dart';
import 'ai_opponent_engine_enhanced.dart';
import '../widgets/performance_graphs.dart';

/// Service for managing game history and statistics
///
/// Handles saving, loading, and analyzing game records
abstract class GameHistoryService {
  /// Save a completed game
  Future<void> saveGame(GameRecord game);

  /// Load all games
  Future<List<GameRecord>> loadAllGames();

  /// Load games by difficulty
  Future<List<GameRecord>> loadGamesByDifficulty(AIDifficulty difficulty);

  /// Load games within date range
  Future<List<GameRecord>> loadGamesBetween(DateTime start, DateTime end);

  /// Delete a game
  Future<void> deleteGame(String gameId);

  /// Clear all games
  Future<void> clearAllGames();

  /// Get player statistics
  Future<PlayerStatistics> getPlayerStatistics();
}

/// Local implementation using in-memory storage
class LocalGameHistoryService implements GameHistoryService {
  final Map<String, GameRecord> _games = {};
  final String _playerId = 'local_player';

  @override
  Future<void> saveGame(GameRecord game) async {
    _games[game.gameId] = game;
  }

  @override
  Future<List<GameRecord>> loadAllGames() async =>
      _games.values.toList()..sort((a, b) => b.playedAt.compareTo(a.playedAt));

  @override
  Future<List<GameRecord>> loadGamesByDifficulty(
          AIDifficulty difficulty) async =>
      _games.values.where((g) => g.difficulty == difficulty).toList()
        ..sort((a, b) => b.playedAt.compareTo(a.playedAt));

  @override
  Future<List<GameRecord>> loadGamesBetween(
          DateTime start, DateTime end) async =>
      _games.values
          .where((g) => g.playedAt.isAfter(start) && g.playedAt.isBefore(end))
          .toList()
        ..sort((a, b) => b.playedAt.compareTo(a.playedAt));

  @override
  Future<void> deleteGame(String gameId) async {
    _games.remove(gameId);
  }

  @override
  Future<void> clearAllGames() async {
    _games.clear();
  }

  @override
  Future<PlayerStatistics> getPlayerStatistics() async {
    final allGames = await loadAllGames();
    if (allGames.isEmpty) {
      return PlayerStatistics(
        playerId: _playerId,
        games: [],
        firstGame: DateTime.now(),
        lastGame: DateTime.now(),
      );
    }

    return PlayerStatistics(
      playerId: _playerId,
      games: allGames,
      firstGame: allGames.last.playedAt,
      lastGame: allGames.first.playedAt,
    );
  }
}

/// Builder for creating GameRecord from a completed game
class GameRecordBuilder {
  GameRecordBuilder({
    this.gameId,
    this.playedAt,
  });
  String? gameId;
  DateTime? playedAt;
  AIDifficulty difficulty = AIDifficulty.medium;
  GameResult result = GameResult.draw;
  int totalMoves = 0;
  int totalTimeMs = 0;
  final List<MoveMetrics> moveMetrics = [];
  String? notes;

  /// Set game properties
  void setProperties({
    required int totalMoves,
    required int totalTimeMs,
    required GameResult result,
    required AIDifficulty difficulty,
  }) {
    this.totalMoves = totalMoves;
    this.totalTimeMs = totalTimeMs;
    this.result = result;
    this.difficulty = difficulty;
  }

  /// Add move metric
  void addMoveMetric(MoveMetrics metric) {
    moveMetrics.add(metric);
  }

  /// Add multiple metrics
  void addMoveMetrics(List<MoveMetrics> metrics) {
    moveMetrics.addAll(metrics);
  }

  /// Set notes
  void setNotes(String newNotes) {
    notes = newNotes;
  }

  /// Build the game record
  GameRecord build() {
    assert(gameId != null, 'gameId must be set');
    assert(playedAt != null, 'playedAt must be set');

    final stats = GameStatistics.fromMetrics(moveMetrics);

    return GameRecord(
      gameId: gameId!,
      playedAt: playedAt!,
      difficulty: difficulty,
      result: result,
      totalMoves: totalMoves,
      totalTimeMs: totalTimeMs,
      moveMetrics: moveMetrics,
      statistics: stats,
      notes: notes,
    );
  }
}

/// Analyzer for game records and statistics
class GameAnalyzer {
  /// Estimate Elo rating from game statistics
  static int estimateElo(GameStatistics stats) {
    // Base Elo for medium difficulty engine
    const baseElo = 1900;

    // Factors that contribute to Elo
    double eloAdjustment = 0;

    // Node evaluation rate factor (20K-30K = ~0 adjustment)
    final nodeRate = stats.avgNodesPerSec;
    if (nodeRate < 15000) {
      eloAdjustment -= 100;
    } else if (nodeRate > 35000) {
      eloAdjustment += 100;
    }

    // Cache hit rate factor (55-70% = ~0 adjustment)
    final cacheHitRate = stats.avgCacheHitRate * 100;
    if (cacheHitRate < 50) {
      eloAdjustment -= 50;
    } else if (cacheHitRate > 75) {
      eloAdjustment += 100;
    }

    // Search depth factor
    final depth = stats.avgSearchDepth;
    if (depth < 2.5) {
      eloAdjustment -= 150;
    } else if (depth > 3.5) {
      eloAdjustment += 150;
    }

    // Total cutoff factor (heuristic effectiveness)
    if (stats.totalKillerCutoffs + stats.totalCountermoveCutoffs > 100) {
      eloAdjustment += 50;
    }

    return (baseElo + eloAdjustment).toInt();
  }

  /// Calculate improvement between two game sets
  static Map<String, dynamic> compareGameSets(
    List<GameRecord> before,
    List<GameRecord> after,
  ) {
    if (before.isEmpty || after.isEmpty) {
      return {'error': 'insufficient_data'};
    }

    final beforeStats = _aggregateStats(before);
    final afterStats = _aggregateStats(after);

    final nodeImprovement =
        ((afterStats['avgNodesPerSec'] - beforeStats['avgNodesPerSec']) /
                beforeStats['avgNodesPerSec'] *
                100)
            .toStringAsFixed(1);

    final cacheImprovement =
        ((afterStats['avgCacheHitRate'] - beforeStats['avgCacheHitRate']) /
                beforeStats['avgCacheHitRate'] *
                100)
            .toStringAsFixed(1);

    final eloBefor = estimateEloFromAgg(beforeStats);
    final eloAfter = estimateEloFromAgg(afterStats);
    final eloGain = eloAfter - eloBefor;

    return {
      'nodeImprovement': nodeImprovement,
      'cacheImprovement': cacheImprovement,
      'eloBefore': eloBefor,
      'eloAfter': eloAfter,
      'eloGain': eloGain,
      'improvingTrend': eloGain > 0,
    };
  }

  /// Identify optimal difficulty level based on performance
  static AIDifficulty suggestedDifficulty(PlayerStatistics playerStats) {
    final easyStats = playerStats.getStatsByDifficulty(AIDifficulty.easy);
    final mediumStats = playerStats.getStatsByDifficulty(AIDifficulty.medium);
    final hardStats = playerStats.getStatsByDifficulty(AIDifficulty.hard);

    // If player hasn't tried a difficulty, suggest it
    if (easyStats['gamesPlayed'] == 0) return AIDifficulty.easy;
    if (mediumStats['gamesPlayed'] == 0) return AIDifficulty.medium;
    if (hardStats['gamesPlayed'] == 0) return AIDifficulty.hard;

    // Calculate win rates
    final easyGames = playerStats.gamesByDifficulty(AIDifficulty.easy);
    final mediumGames = playerStats.gamesByDifficulty(AIDifficulty.medium);
    final hardGames = playerStats.gamesByDifficulty(AIDifficulty.hard);

    final easyWinRate = _calculateWinRate(easyGames);
    final mediumWinRate = _calculateWinRate(mediumGames);
    final hardWinRate = _calculateWinRate(hardGames);

    // Suggest difficulty based on win rate
    if (easyWinRate < 0.7) return AIDifficulty.easy; // Too hard
    if (mediumWinRate < 0.5) return AIDifficulty.medium; // Too hard
    if (hardWinRate > 0.4) return AIDifficulty.hard; // Good challenge

    return AIDifficulty.medium;
  }

  /// Get performance insights
  static List<String> getInsights(PlayerStatistics playerStats) {
    final insights = <String>[];
    final overall = playerStats.getOverallStats();
    final trend = playerStats.getPerformanceTrend();

    // Insight 1: Overall performance
    if (overall['totalGames'] >= 5) {
      if (overall['winRate'] > 0.6) {
        insights.add(
            'Excellent performance with ${(overall["winRate"] * 100).toStringAsFixed(0)}% win rate');
      } else if (overall['winRate'] > 0.4) {
        insights.add(
            'Good balanced play with ${(overall["winRate"] * 100).toStringAsFixed(0)}% win rate');
      } else {
        insights.add('Learning opportunities at lower win rate');
      }
    }

    // Insight 2: Trend
    if (trend.containsKey('trend') && trend['trend'] == 'improving') {
      insights.add(
          'Performance trending upward: ${trend["nodeImprovement"]}% improvement');
    }

    // Insight 3: Cache efficiency
    if (overall['avgCacheHitRate'] > 0.65) {
      insights.add('Excellent cache efficiency utilization');
    } else if (overall['avgCacheHitRate'] > 0.50) {
      insights.add('Good cache performance, room for improvement');
    }

    return insights;
  }

  static Map<String, dynamic> _aggregateStats(List<GameRecord> games) {
    double totalNodes = 0;
    double totalCache = 0;
    double totalDepth = 0;

    for (final game in games) {
      totalNodes += game.statistics.avgNodesPerSec;
      totalCache += game.statistics.avgCacheHitRate;
      totalDepth += game.statistics.avgSearchDepth;
    }

    final count = games.length.toDouble();
    return {
      'avgNodesPerSec': totalNodes / count,
      'avgCacheHitRate': totalCache / count,
      'avgSearchDepth': totalDepth / count,
    };
  }

  static int estimateEloFromAgg(Map<String, dynamic> aggStats) {
    const baseElo = 1900;
    double adjustment = 0;

    final nodeRate = aggStats['avgNodesPerSec'] as double;
    final cacheHitRate = aggStats['avgCacheHitRate'] as double;
    final depth = aggStats['avgSearchDepth'] as double;

    if (nodeRate > 25000) adjustment += 100;
    if (cacheHitRate > 0.65) adjustment += 100;
    if (depth > 3.5) adjustment += 100;

    return (baseElo + adjustment).toInt();
  }

  static double _calculateWinRate(List<GameRecord> games) {
    if (games.isEmpty) return 0;
    final wins = games.where((g) => g.result == GameResult.win).length;
    return wins / games.length;
  }
}
