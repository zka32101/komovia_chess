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

  /// The difficulty values actually stored on each game doc - the enum's
  /// `displayName` ('Easy'/'Medium'/'Hard'), not the enum name itself. A
  /// Firestore `isEqualTo` query against the lowercase enum name would
  /// silently match zero documents.
  static const _storedDifficultyLabels = ['Easy', 'Medium', 'Hard'];

  /// Get game statistics for a player
  Future<GameStats> _getGameStats(String userId) async {
    final gamesRef =
        _firestore.collection('users').doc(userId).collection('games');

    final snapshot = await gamesRef.get();
    final games = snapshot.docs;

    int wins = 0, losses = 0, draws = 0;
    int totalMoves = 0;
    DateTime? lastGameDate;

    for (final game in games) {
      final data = game.data();
      final result = data['result'] as String?;

      if (result == 'win') {
        wins++;
      } else if (result == 'loss')
        losses++;
      else if (result == 'draw') draws++;

      // FirebaseGameHistoryService.saveGame writes GameRecord.toJson()
      // directly, whose field is `totalMoves` (not `moves`) and
      // `playedAt` (not `date`) - see GameRecord in models/game_history.dart.
      totalMoves += (data['totalMoves'] as int?) ?? 0;

      final gameDate = (data['playedAt'] as Timestamp?)?.toDate();
      if (gameDate != null &&
          (lastGameDate == null || gameDate.isAfter(lastGameDate))) {
        lastGameDate = gameDate;
      }
    }

    final totalGames = games.length;
    final winRate = totalGames > 0 ? (wins / totalGames) * 100 : 0.0;

    return GameStats(
      totalGames: totalGames,
      wins: wins,
      losses: losses,
      draws: draws,
      winRate: winRate,
      // GameRecord has no per-game move-quality accuracy field (its
      // `statistics` is engine-performance data: nodes/sec, cache hit
      // rate, search depth - not move correctness), and nothing persists
      // the Stockfish-based accuracy ChessAnalysisService can compute for
      // a game back to this collection. Honestly 0 rather than reading a
      // field that was never written.
      averageAccuracy: 0,
      totalMoves: totalMoves,
      lastGameDate: lastGameDate ?? DateTime.now(),
    );
  }

  /// Get streak information, derived from the actual game history rather
  /// than a `currentWinStreak`/`longestWinStreak`/... set of fields on the
  /// user doc that nothing in this app ever writes (confirmed: no other
  /// file sets any of those field names) - reading them always returned
  /// all-zero/default streak info regardless of real game history.
  Future<StreakInfo> _getStreakInfo(String userId) async {
    final gamesRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('games')
        .orderBy('playedAt', descending: true);

    final snapshot = await gamesRef.get();
    final games = snapshot.docs;

    int currentWinStreak = 0;
    int currentLossStreak = 0;
    int longestWinStreak = 0;
    int longestLossStreak = 0;
    DateTime longestStreakDate = DateTime.now();

    int runningWinStreak = 0;
    int runningLossStreak = 0;
    var stillCountingCurrent = true;

    for (final game in games) {
      final data = game.data();
      final result = data['result'] as String?;
      final playedAt = (data['playedAt'] as Timestamp?)?.toDate();

      if (result == 'win') {
        runningWinStreak++;
        runningLossStreak = 0;
      } else if (result == 'loss') {
        runningLossStreak++;
        runningWinStreak = 0;
      } else {
        runningWinStreak = 0;
        runningLossStreak = 0;
      }

      // The "current" streak is only meaningful as the run of
      // consecutive results starting from the most recent game, so stop
      // updating it the moment the run breaks (a draw, or a switch from
      // win to loss or vice versa).
      if (stillCountingCurrent) {
        if (result == 'win' || result == 'loss') {
          currentWinStreak = runningWinStreak;
          currentLossStreak = runningLossStreak;
        } else {
          stillCountingCurrent = false;
        }
        if (runningWinStreak == 0 && runningLossStreak == 0) {
          stillCountingCurrent = false;
        }
      }

      if (runningWinStreak > longestWinStreak) {
        longestWinStreak = runningWinStreak;
        if (playedAt != null) longestStreakDate = playedAt;
      }
      if (runningLossStreak > longestLossStreak) {
        longestLossStreak = runningLossStreak;
      }
    }

    return StreakInfo(
      currentWinStreak: currentWinStreak,
      longestWinStreak: longestWinStreak,
      longestStreakDate: longestStreakDate,
      currentLossStreak: currentLossStreak,
      longestLossStreak: longestLossStreak,
    );
  }

  /// Get performance trend over last 30 days
  Future<PerformanceTrend> _getPerformanceTrend(String userId) async {
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));

    final gamesRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('games')
        .where('playedAt', isGreaterThan: thirtyDaysAgo)
        .orderBy('playedAt', descending: false);

    final snapshot = await gamesRef.get();
    final metrics = <PerformanceMetric>[];

    for (final doc in snapshot.docs) {
      final data = doc.data();
      // accuracy/rating are not persisted per-game anywhere (see
      // _getGameStats's comment) - left at 0 rather than reading fields
      // that were never written, so the chart's line is honestly flat
      // rather than silently wrong.
      metrics.add(PerformanceMetric(
        timestamp: (data['playedAt'] as Timestamp?)?.toDate() ??
            DateTime.now(),
        accuracy: 0,
        rating: 0,
        gameCount: 1,
        difficulty: data['difficulty'] as String? ?? 'unknown',
      ));
    }

    return PerformanceTrend(
      metrics: metrics,
      trendDirection: 0,
      averageAccuracy: 0,
      averageRating: 0,
      totalDataPoints: metrics.length,
    );
  }

  /// Get performance breakdown by difficulty
  Future<List<DifficultyBreakdown>> _getDifficultyStats(String userId) async {
    final stats = <DifficultyBreakdown>[];

    for (final storedLabel in _storedDifficultyLabels) {
      final gamesRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('games')
          .where('difficulty', isEqualTo: storedLabel);

      final snapshot = await gamesRef.get();
      final games = snapshot.docs;

      int wins = 0;
      for (final game in games) {
        if (game.data()['result'] == 'win') wins++;
      }

      final totalGames = games.length;
      final winRate = totalGames > 0 ? (wins / totalGames) * 100 : 0.0;

      stats.add(DifficultyBreakdown(
        difficulty: storedLabel.toLowerCase(),
        gamesPlayed: totalGames,
        wins: wins,
        winRate: winRate,
        // No per-game accuracy field exists to average - see
        // _getGameStats's comment.
        averageAccuracy: 0,
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
