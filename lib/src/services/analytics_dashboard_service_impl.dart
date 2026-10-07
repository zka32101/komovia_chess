import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/analytics_models.dart';
import 'firestore_result_cache_service.dart';

/// Comprehensive analytics dashboard service for player statistics.
class AnalyticsDashboardService {
  factory AnalyticsDashboardService() => _instance;

  AnalyticsDashboardService._internal();
  static final AnalyticsDashboardService _instance =
      AnalyticsDashboardService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirestoreResultCacheService _cache = FirestoreResultCacheService();

  /// Get comprehensive player analytics dashboard
  Future<PlayerAnalyticsDashboard> getPlayerDashboard(String userId) async {
    final cacheKey = 'dashboard:$userId';
    if (_cache.isQueryCached('analytics', filters: {'userId': userId})) {
      final cached = _cache.getCachedDocument<PlayerAnalyticsDashboard>(
        'analytics',
        userId,
      );
      if (cached != null) return cached;
    }

    final gameStats = await _getGameStats(userId);
    final streakInfo = await _getStreakInfo(userId);
    final performanceTrend = await _getPerformanceTrend(userId);
    final difficultyStats = await _getDifficultyStats(userId);

    final dashboard = PlayerAnalyticsDashboard(
      userId: userId,
      gameStats: gameStats,
      streakInfo: streakInfo,
      performanceTrend: performanceTrend,
      difficultyStats: difficultyStats,
      generatedAt: DateTime.now(),
    );

    _cache.cacheDocument('analytics', userId, dashboard);
    return dashboard;
  }

  /// Get game statistics for a player
  Future<GameStats> _getGameStats(String userId) async {
    final gamesRef =
        _firestore.collection('users').doc(userId).collection('games');

    final snapshot = await gamesRef.get();
    final games = snapshot.docs;

    int wins = 0, losses = 0, draws = 0;
    double totalAccuracy = 0;
    int totalMoves = 0;
    DateTime lastGameDate = DateTime.now();

    for (final game in games) {
      final data = game.data();
      final result = data['result'] as String?;

      if (result == 'win') {
        wins++;
      } else if (result == 'loss')
        losses++;
      else if (result == 'draw') draws++;

      totalAccuracy += (data['accuracy'] as num?)?.toDouble() ?? 0;
      totalMoves += (data['moves'] as int?) ?? 0;

      final gameDate = (data['date'] as Timestamp?)?.toDate();
      if (gameDate != null && gameDate.isAfter(lastGameDate)) {
        lastGameDate = gameDate;
      }
    }

    final totalGames = games.length;
    final winRate = totalGames > 0 ? (wins / totalGames) * 100 : 0.0;
    final avgAccuracy = totalGames > 0 ? totalAccuracy / totalGames : 0.0;

    return GameStats(
      totalGames: totalGames,
      wins: wins,
      losses: losses,
      draws: draws,
      winRate: winRate,
      averageAccuracy: avgAccuracy,
      totalMoves: totalMoves,
      lastGameDate: lastGameDate,
    );
  }

  /// Get streak information
  Future<StreakInfo> _getStreakInfo(String userId) async {
    final userDoc = await _firestore.collection('users').doc(userId).get();
    final data = userDoc.data() ?? {};

    return StreakInfo(
      currentWinStreak: (data['currentWinStreak'] as int?) ?? 0,
      longestWinStreak: (data['longestWinStreak'] as int?) ?? 0,
      longestStreakDate:
          (data['longestStreakDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      currentLossStreak: (data['currentLossStreak'] as int?) ?? 0,
      longestLossStreak: (data['longestLossStreak'] as int?) ?? 0,
    );
  }

  /// Get performance trend over last 30 days
  Future<PerformanceTrend> _getPerformanceTrend(String userId) async {
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));

    final gamesRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('games')
        .where('date', isGreaterThan: thirtyDaysAgo)
        .orderBy('date', descending: false);

    final snapshot = await gamesRef.get();
    final metrics = <PerformanceMetric>[];

    double totalAccuracy = 0;
    double totalRating = 0;
    int validMetrics = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final metric = PerformanceMetric(
        timestamp: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
        accuracy: (data['accuracy'] as num?)?.toDouble() ?? 0,
        rating: (data['rating'] as num?)?.toDouble() ?? 0,
        gameCount: 1,
        difficulty: data['difficulty'] as String? ?? 'unknown',
      );
      metrics.add(metric);
      totalAccuracy += metric.accuracy;
      totalRating += metric.rating;
      validMetrics++;
    }

    final trendDirection =
        validMetrics > 1 ? metrics.last.accuracy - metrics.first.accuracy : 0.0;

    return PerformanceTrend(
      metrics: metrics,
      trendDirection: trendDirection,
      averageAccuracy: validMetrics > 0 ? totalAccuracy / validMetrics : 0.0,
      averageRating: validMetrics > 0 ? totalRating / validMetrics : 0.0,
      totalDataPoints: validMetrics,
    );
  }

  /// Get performance breakdown by difficulty
  Future<List<DifficultyBreakdown>> _getDifficultyStats(String userId) async {
    final difficulties = ['easy', 'medium', 'hard'];
    final stats = <DifficultyBreakdown>[];

    for (final difficulty in difficulties) {
      final gamesRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('games')
          .where('difficulty', isEqualTo: difficulty);

      final snapshot = await gamesRef.get();
      final games = snapshot.docs;

      int wins = 0;
      double totalAccuracy = 0;

      for (final game in games) {
        final data = game.data();
        if (data['result'] == 'win') wins++;
        totalAccuracy += (data['accuracy'] as num?)?.toDouble() ?? 0;
      }

      final totalGames = games.length;
      final winRate = totalGames > 0 ? (wins / totalGames) * 100 : 0.0;
      final avgAccuracy = totalGames > 0 ? totalAccuracy / totalGames : 0.0;

      stats.add(DifficultyBreakdown(
        difficulty: difficulty,
        gamesPlayed: totalGames,
        wins: wins,
        winRate: winRate,
        averageAccuracy: avgAccuracy,
      ));
    }

    return stats;
  }

  /// Get comparison between two players
  Future<(GameStats, GameStats)> comparePlayersStats(
    String player1Id,
    String player2Id,
  ) async {
    final stats1 = await _getGameStats(player1Id);
    final stats2 = await _getGameStats(player2Id);
    return (stats1, stats2);
  }

  /// Batch get multiple player dashboards
  Future<Map<String, PlayerAnalyticsDashboard>> batchGetDashboards(
    List<String> userIds,
  ) async {
    final results = <String, PlayerAnalyticsDashboard>{};
    for (final userId in userIds) {
      try {
        results[userId] = await getPlayerDashboard(userId);
      } catch (e) {
        debugPrintError('Error loading dashboard for $userId: $e');
      }
    }
    return results;
  }

  /// Invalidate player analytics cache
  void invalidatePlayerAnalytics(String userId) {
    _cache.invalidateDocument('analytics', userId);
  }

  /// Clear all analytics cache
  void clearCache() {
    _cache.clear();
  }
}

void debugPrintError(String message) {
  print('❌ $message');
}
