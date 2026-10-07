import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';

/// Performance trend analysis service
class PerformanceTrendService {
  PerformanceTrendService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _firestore;
  final Logger _logger = Logger();

  static const String _gamesCollection = 'games';
  static const String _usersCollection = 'users';

  /// Analyze performance trends over different time periods
  Future<PerformanceTrends> analyzePerformanceTrends(String playerId) async {
    try {
      // Get player's recent games
      final allGames = await _getPlayerGames(playerId, limit: 100);

      final now = DateTime.now();
      final sevenDaysAgo = now.subtract(const Duration(days: 7));
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));
      final ninetyDaysAgo = now.subtract(const Duration(days: 90));

      // Segment games by time period
      final sevenDayGames = allGames
          .where((g) =>
              DateTime.parse(g['createdAt'] as String).isAfter(sevenDaysAgo))
          .toList();

      final thirtyDayGames = allGames
          .where((g) =>
              DateTime.parse(g['createdAt'] as String).isAfter(thirtyDaysAgo))
          .toList();

      final ninetyDayGames = allGames
          .where((g) =>
              DateTime.parse(g['createdAt'] as String).isAfter(ninetyDaysAgo))
          .toList();

      // Calculate statistics for each period
      final sevenDayStats = _calculatePeriodStats(sevenDayGames, playerId);
      final thirtyDayStats = _calculatePeriodStats(thirtyDayGames, playerId);
      final ninetyDayStats = _calculatePeriodStats(ninetyDayGames, playerId);

      // Determine trend direction
      String trend = 'stable';
      if (sevenDayStats.accuracy > thirtyDayStats.accuracy + 5) {
        trend = 'improving';
      } else if (sevenDayStats.accuracy < thirtyDayStats.accuracy - 5) {
        trend = 'declining';
      }

      return PerformanceTrends(
        playerId: playerId,
        sevenDayStats: sevenDayStats,
        thirtyDayStats: thirtyDayStats,
        ninetyDayStats: ninetyDayStats,
        overallTrend: trend,
        bestPerformanceDay: _findBestPerformanceDay(allGames, playerId),
        worstPerformanceDay: _findWorstPerformanceDay(allGames, playerId),
      );
    } catch (e, st) {
      _logger.e('Failed to analyze performance trends',
          error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Get specific performance metrics for a time period
  Future<TimePeriodMetrics> getPerformanceMetricsForPeriod(
    String playerId, {
    required int daysBack,
  }) async {
    try {
      final now = DateTime.now();
      final cutoffDate = now.subtract(Duration(days: daysBack));

      final games = await _getPlayerGames(playerId, limit: 200);

      final relevantGames = games
          .where((g) =>
              DateTime.parse(g['createdAt'] as String).isAfter(cutoffDate))
          .toList();

      return _calculatePeriodStats(relevantGames, playerId);
    } catch (e, st) {
      _logger.e('Failed to get period metrics', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Analyze performance by day of week
  Future<Map<String, DayPerformance>> analyzePerformanceByDayOfWeek(
    String playerId,
  ) async {
    try {
      final games = await _getPlayerGames(playerId, limit: 100);

      final dayStats = <String, List<Map<String, dynamic>>>{
        'Monday': [],
        'Tuesday': [],
        'Wednesday': [],
        'Thursday': [],
        'Friday': [],
        'Saturday': [],
        'Sunday': [],
      };

      for (final game in games) {
        final date = DateTime.parse(game['createdAt'] as String);
        final dayName = [
          'Monday',
          'Tuesday',
          'Wednesday',
          'Thursday',
          'Friday',
          'Saturday',
          'Sunday'
        ][date.weekday - 1];

        dayStats[dayName]!.add(game);
      }

      final dayPerformance = <String, DayPerformance>{};

      dayStats.forEach((day, dayGames) {
        if (dayGames.isNotEmpty) {
          final stats = _calculatePeriodStats(dayGames, playerId);
          dayPerformance[day] = DayPerformance(
            dayOfWeek: day,
            gamesPlayed: dayGames.length,
            winRate: stats.winRate,
            accuracy: stats.accuracy,
            averageRatingChange: stats.averageRatingChange,
          );
        }
      });

      return dayPerformance;
    } catch (e, st) {
      _logger.e('Failed to analyze performance by day',
          error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Private helper methods

  Future<List<Map<String, dynamic>>> _getPlayerGames(
    String playerId, {
    required int limit,
  }) async {
    final whiteGames = await _firestore
        .collection(_gamesCollection)
        .where('whitePlayerId', isEqualTo: playerId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    final blackGames = await _firestore
        .collection(_gamesCollection)
        .where('blackPlayerId', isEqualTo: playerId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    final allGames = [...whiteGames.docs, ...blackGames.docs]
        .map((doc) => doc.data())
        .toList();

    // Sort by date
    allGames.sort((a, b) {
      final dateA = DateTime.parse(a['createdAt'] as String? ?? '');
      final dateB = DateTime.parse(b['createdAt'] as String? ?? '');
      return dateB.compareTo(dateA);
    });

    return allGames;
  }

  TimePeriodMetrics _calculatePeriodStats(
    List<Map<String, dynamic>> games,
    String playerId,
  ) {
    if (games.isEmpty) {
      return TimePeriodMetrics(
        gamesPlayed: 0,
        wins: 0,
        losses: 0,
        draws: 0,
        winRate: 0,
        accuracy: 0,
        averageRatingChange: 0,
      );
    }

    int wins = 0;
    int losses = 0;
    int draws = 0;
    double totalAccuracy = 0;
    double totalRatingChange = 0;

    for (final game in games) {
      final result = game['result'] as String?;
      final accuracy = game['accuracy'] as double? ?? 0.0;
      final ratingChange = game['whitePlayerId'] == playerId
          ? (game['whiteRatingDelta'] as int? ?? 0).toDouble()
          : (game['blackRatingDelta'] as int? ?? 0).toDouble();

      if (result == 'white_win') {
        if (game['whitePlayerId'] == playerId) {
          wins++;
        } else {
          losses++;
        }
      } else if (result == 'black_win') {
        if (game['blackPlayerId'] == playerId) {
          wins++;
        } else {
          losses++;
        }
      } else if (result == 'draw') {
        draws++;
      }

      totalAccuracy += accuracy;
      totalRatingChange += ratingChange;
    }

    return TimePeriodMetrics(
      gamesPlayed: games.length,
      wins: wins,
      losses: losses,
      draws: draws,
      winRate: wins / games.length * 100,
      accuracy: totalAccuracy / games.length,
      averageRatingChange: totalRatingChange / games.length,
    );
  }

  String? _findBestPerformanceDay(
      List<Map<String, dynamic>> games, String playerId) {
    if (games.isEmpty) return null;

    String? bestDay;
    double bestAccuracy = -1;

    for (final game in games) {
      final accuracy = game['accuracy'] as double? ?? 0.0;
      if (accuracy > bestAccuracy) {
        bestAccuracy = accuracy;
        bestDay = (game['createdAt'] as String?)?.split('T').first;
      }
    }

    return bestDay;
  }

  String? _findWorstPerformanceDay(
      List<Map<String, dynamic>> games, String playerId) {
    if (games.isEmpty) return null;

    String? worstDay;
    double worstAccuracy = 101;

    for (final game in games) {
      final accuracy = game['accuracy'] as double? ?? 0.0;
      if (accuracy < worstAccuracy) {
        worstAccuracy = accuracy;
        worstDay = (game['createdAt'] as String?)?.split('T').first;
      }
    }

    return worstDay;
  }
}

/// Performance trends data
class PerformanceTrends {
  PerformanceTrends({
    required this.playerId,
    required this.sevenDayStats,
    required this.thirtyDayStats,
    required this.ninetyDayStats,
    required this.overallTrend,
    this.bestPerformanceDay,
    this.worstPerformanceDay,
  });
  final String playerId;
  final TimePeriodMetrics sevenDayStats;
  final TimePeriodMetrics thirtyDayStats;
  final TimePeriodMetrics ninetyDayStats;
  final String overallTrend;
  final String? bestPerformanceDay;
  final String? worstPerformanceDay;
}

/// Time period metrics
class TimePeriodMetrics {
  TimePeriodMetrics({
    required this.gamesPlayed,
    required this.wins,
    required this.losses,
    required this.draws,
    required this.winRate,
    required this.accuracy,
    required this.averageRatingChange,
  });
  final int gamesPlayed;
  final int wins;
  final int losses;
  final int draws;
  final double winRate;
  final double accuracy;
  final double averageRatingChange;
}

/// Day of week performance
class DayPerformance {
  DayPerformance({
    required this.dayOfWeek,
    required this.gamesPlayed,
    required this.winRate,
    required this.accuracy,
    required this.averageRatingChange,
  });
  final String dayOfWeek;
  final int gamesPlayed;
  final double winRate;
  final double accuracy;
  final double averageRatingChange;
}
