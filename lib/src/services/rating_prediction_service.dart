import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import 'dart:math' show pow, sqrt;

/// Rating prediction and forecasting service
class RatingPredictionService {
  RatingPredictionService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _firestore;
  final Logger _logger = Logger();

  static const String _usersCollection = 'users';
  static const String _ratingHistorySubcollection = 'ratingHistory';

  /// Predict player's rating in N days
  Future<RatingForecast> predictFutureRating(
    String playerId, {
    int daysAhead = 30,
  }) async {
    try {
      // Get player's current rating and history
      final userDoc =
          await _firestore.collection(_usersCollection).doc(playerId).get();

      if (!userDoc.exists) {
        throw Exception('Player not found');
      }

      final currentRating = userDoc.data()!['rating'] as int? ?? 1200;
      final gamesPlayed = userDoc.data()!['gamesPlayed'] as int? ?? 0;

      // Get rating history
      final historySnapshot = await _firestore
          .collection(_usersCollection)
          .doc(playerId)
          .collection(_ratingHistorySubcollection)
          .orderBy('createdAt', descending: true)
          .limit(30)
          .get();

      final history = historySnapshot.docs
          .map((doc) => doc.data()['ratingChange'] as int? ?? 0)
          .toList();

      if (history.isEmpty) {
        return RatingForecast(
          playerId: playerId,
          currentRating: currentRating,
          forecastedRating: currentRating,
          daysAhead: daysAhead,
          trend: 'stable',
          confidence: 0.3,
          averageDailyChange: 0,
          predictedWinRate: 0.5,
          improvements: [],
        );
      }

      // Calculate trend metrics
      final averageDailyChange = history.isNotEmpty
          ? history.reduce((a, b) => a + b) / history.length
          : 0.0;

      final trend = _calculateTrend(history);
      final volatility = _calculateVolatility(history);
      final confidence = _calculateConfidence(gamesPlayed, volatility);

      // Predict future rating based on trend
      var forecastedRating = currentRating;
      if (trend == 'improving') {
        forecastedRating =
            (currentRating + (averageDailyChange * daysAhead * 0.7)).toInt();
      } else if (trend == 'declining') {
        forecastedRating =
            (currentRating + (averageDailyChange * daysAhead * 0.7)).toInt();
      }

      // Apply rating ceiling/floor
      forecastedRating = forecastedRating.clamp(600, 3000);

      // Calculate predicted win rate based on rating
      final predictedWinRate = _calculateExpectedWinRate(forecastedRating);

      // Generate improvement suggestions
      final improvements = _generateImprovements(
        currentRating,
        forecastedRating,
        trend,
        history,
      );

      return RatingForecast(
        playerId: playerId,
        currentRating: currentRating,
        forecastedRating: forecastedRating,
        daysAhead: daysAhead,
        trend: trend,
        confidence: confidence,
        averageDailyChange: averageDailyChange,
        predictedWinRate: predictedWinRate,
        improvements: improvements,
      );
    } catch (e, st) {
      _logger.e('Failed to predict future rating', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Analyze rating volatility
  Future<RatingVolatility> analyzeRatingVolatility(String playerId) async {
    try {
      final historySnapshot = await _firestore
          .collection(_usersCollection)
          .doc(playerId)
          .collection(_ratingHistorySubcollection)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      if (historySnapshot.docs.isEmpty) {
        return RatingVolatility(
          playerId: playerId,
          volatilityScore: 0,
          maxGain: 0,
          maxLoss: 0,
          averageChange: 0,
          stabilityTrend: 'stable',
        );
      }

      final changes = historySnapshot.docs
          .map((doc) => doc.data()['ratingChange'] as int? ?? 0)
          .toList();

      final volatility = _calculateVolatility(changes);
      final maxGain = changes.reduce((a, b) => a > b ? a : b);
      final maxLoss = changes.reduce((a, b) => a < b ? a : b).abs();
      final averageChange = changes.reduce((a, b) => a + b) / changes.length;

      return RatingVolatility(
        playerId: playerId,
        volatilityScore: volatility,
        maxGain: maxGain,
        maxLoss: maxLoss,
        averageChange: averageChange,
        stabilityTrend: volatility < 10
            ? 'stable'
            : volatility < 20
                ? 'variable'
                : 'volatile',
      );
    } catch (e, st) {
      _logger.e('Failed to analyze rating volatility',
          error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Get rating progression over time
  Future<RatingProgression> getRatingProgression(
    String playerId, {
    int months = 3,
  }) async {
    try {
      final historySnapshot = await _firestore
          .collection(_usersCollection)
          .doc(playerId)
          .collection(_ratingHistorySubcollection)
          .orderBy('createdAt', descending: false)
          .limit(100)
          .get();

      final now = DateTime.now();
      final cutoffDate = now.subtract(Duration(days: months * 30));

      final relevantChanges = <RatingChange>[];

      for (final doc in historySnapshot.docs) {
        final data = doc.data();
        final createdAt = (data['createdAt'] as Timestamp).toDate();

        if (createdAt.isAfter(cutoffDate)) {
          relevantChanges.add(RatingChange(
            ratingChange: data['ratingChange'] as int? ?? 0,
            newRating: data['newRating'] as int? ?? 1200,
            timestamp: createdAt,
            result: data['result'] as String? ?? 'unknown',
          ));
        }
      }

      // Calculate monthly progression
      final monthlyData = <String, MonthlyRatingData>{};

      for (final change in relevantChanges) {
        final monthKey =
            '${change.timestamp.year}-${change.timestamp.month.toString().padLeft(2, '0')}';

        if (!monthlyData.containsKey(monthKey)) {
          monthlyData[monthKey] = MonthlyRatingData(
            month: monthKey,
            startRating: change.newRating,
            endRating: change.newRating,
            gamesPlayed: 0,
            wins: 0,
            losses: 0,
            draws: 0,
          );
        }

        monthlyData[monthKey]!.endRating = change.newRating;
        monthlyData[monthKey]!.gamesPlayed++;

        if (change.result == 'white_win' || change.result == 'black_win') {
          monthlyData[monthKey]!.wins++;
        } else if (change.result == 'draw') {
          monthlyData[monthKey]!.draws++;
        } else {
          monthlyData[monthKey]!.losses++;
        }
      }

      // Calculate peak and lowest ratings
      int peakRating = 0;
      int lowestRating = 9999;

      for (final change in relevantChanges) {
        if (change.newRating > peakRating) peakRating = change.newRating;
        if (change.newRating < lowestRating) lowestRating = change.newRating;
      }

      if (lowestRating == 9999) lowestRating = 0;

      return RatingProgression(
        playerId: playerId,
        changes: relevantChanges,
        monthlyData: monthlyData.values.toList(),
        peakRating: peakRating,
        lowestRating: lowestRating,
        totalGamesInPeriod: relevantChanges.length,
      );
    } catch (e, st) {
      _logger.e('Failed to get rating progression', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Private helper methods

  String _calculateTrend(List<int> changes) {
    if (changes.length < 5) return 'stable';

    final recentChanges = changes.take(5).toList();
    final recentAverage =
        recentChanges.reduce((a, b) => a + b) / recentChanges.length;
    final overallAverage = changes.reduce((a, b) => a + b) / changes.length;

    if (recentAverage > overallAverage + 5) return 'improving';
    if (recentAverage < overallAverage - 5) return 'declining';
    return 'stable';
  }

  double _calculateVolatility(List<int> changes) {
    if (changes.length < 2) return 0;

    final mean = changes.reduce((a, b) => a + b) / changes.length;
    final variance =
        changes.map((change) => pow(change - mean, 2)).reduce((a, b) => a + b) /
            changes.length;

    return sqrt(variance);
  }

  double _calculateConfidence(int gamesPlayed, double volatility) {
    // Higher confidence for more games and lower volatility
    final gamesConfidence = (gamesPlayed / 100).clamp(0.0, 1.0);
    final volatilityConfidence = 1.0 / (1.0 + (volatility / 10));

    return ((gamesConfidence * 0.6 + volatilityConfidence * 0.4) * 100)
            .toInt() /
        100;
  }

  double _calculateExpectedWinRate(int rating) {
    // Rough estimation: higher rating = higher win rate
    if (rating < 1000) return 0.40;
    if (rating < 1200) return 0.45;
    if (rating < 1400) return 0.50;
    if (rating < 1600) return 0.55;
    if (rating < 1800) return 0.60;
    if (rating < 2000) return 0.65;
    return 0.70;
  }

  List<String> _generateImprovements(
    int currentRating,
    int forecastedRating,
    String trend,
    List<int> history,
  ) {
    final improvements = <String>[];

    // Analyze trend
    if (trend == 'declining') {
      improvements.add('Focus on solid fundamentals and openings');
      improvements.add('Review recent losses for patterns');
      improvements.add('Practice endgames to prevent low-rating games');
    } else if (trend == 'improving') {
      improvements.add('Continue current strategy and practice');
      improvements.add('Challenge higher-rated opponents');
      improvements.add('Study advanced tactics');
    } else {
      improvements.add('Maintain consistent practice schedule');
      improvements.add('Analyze games regularly');
      improvements.add('Play longer time controls');
    }

    // Forecast-specific
    if (forecastedRating > currentRating + 50) {
      improvements.add('You\'re on an upward trajectory!');
    } else if (forecastedRating < currentRating - 50) {
      improvements.add('Consider studying tactical puzzles');
    }

    return improvements;
  }
}

/// Rating forecast data
class RatingForecast {
  RatingForecast({
    required this.playerId,
    required this.currentRating,
    required this.forecastedRating,
    required this.daysAhead,
    required this.trend,
    required this.confidence,
    required this.averageDailyChange,
    required this.predictedWinRate,
    required this.improvements,
  });
  final String playerId;
  final int currentRating;
  final int forecastedRating;
  final int daysAhead;
  final String trend;
  final double confidence;
  final double averageDailyChange;
  final double predictedWinRate;
  final List<String> improvements;
}

/// Rating volatility analysis
class RatingVolatility {
  RatingVolatility({
    required this.playerId,
    required this.volatilityScore,
    required this.maxGain,
    required this.maxLoss,
    required this.averageChange,
    required this.stabilityTrend,
  });
  final String playerId;
  final double volatilityScore;
  final int maxGain;
  final int maxLoss;
  final double averageChange;
  final String stabilityTrend;
}

/// Rating progression over time
class RatingProgression {
  RatingProgression({
    required this.playerId,
    required this.changes,
    required this.monthlyData,
    required this.peakRating,
    required this.lowestRating,
    required this.totalGamesInPeriod,
  });
  final String playerId;
  final List<RatingChange> changes;
  final List<MonthlyRatingData> monthlyData;
  final int peakRating;
  final int lowestRating;
  final int totalGamesInPeriod;
}

/// Individual rating change record
class RatingChange {
  RatingChange({
    required this.ratingChange,
    required this.newRating,
    required this.timestamp,
    required this.result,
  });
  final int ratingChange;
  final int newRating;
  final DateTime timestamp;
  final String result;
}

/// Monthly rating data
class MonthlyRatingData {
  MonthlyRatingData({
    required this.month,
    required this.startRating,
    required this.endRating,
    required this.gamesPlayed,
    required this.wins,
    required this.losses,
    required this.draws,
  });
  final String month;
  int startRating;
  int endRating;
  int gamesPlayed;
  int wins;
  int losses;
  int draws;

  double get winRate => gamesPlayed > 0 ? (wins / gamesPlayed * 100) : 0.0;
  int get ratingDelta => endRating - startRating;
}
