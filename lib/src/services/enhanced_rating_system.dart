import 'dart:math' show pow;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';

/// Enhanced ELO rating system with provisional ratings and bonuses
class EnhancedRatingSystem {
  EnhancedRatingSystem({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _firestore;
  final Logger _logger = Logger();

  static const String _usersCollection = 'users';
  static const String _ratingHistorySubcollection = 'ratingHistory';
  static const int _kFactorProvisional = 48; // Higher K-factor for new players
  static const int _kFactorStandard = 32; // Standard K-factor
  static const int _kFactorHighRated =
      24; // Lower K-factor for high-rated players
  static const int _provisionalGameThreshold =
      30; // Games until provisional rating is considered
  static const int _ratingFloor = 600;
  static const int _ratingCeiling = 3000;

  /// Calculate rating change with advanced metrics
  Future<RatingChangeResult> calculateRatingChange({
    required String whitePlayerId,
    required String blackPlayerId,
    required int whiteCurrentRating,
    required int blackCurrentRating,
    required String result, // white_win, black_win, draw
    required String timeControl, // 3min, 5min, 10min
    int? timeControlMs,
  }) async {
    try {
      // Get player profiles for provisional status
      final whiteProfile = await _getPlayerProfile(whitePlayerId);
      final blackProfile = await _getPlayerProfile(blackPlayerId);

      // Determine K-factors based on rating and provisional status
      final whiteKFactor = _determineKFactor(
        whiteCurrentRating,
        whiteProfile.gamesPlayed,
        whiteProfile.isProvisional,
      );
      final blackKFactor = _determineKFactor(
        blackCurrentRating,
        blackProfile.gamesPlayed,
        blackProfile.isProvisional,
      );

      // Calculate expected scores
      final expectedScores = _calculateExpectedScores(
        whiteCurrentRating,
        blackCurrentRating,
      );

      // Determine actual scores
      final (whiteScore, blackScore) = _getScoresFromResult(result);

      // Calculate base rating changes
      var whiteChange =
          (whiteKFactor * (whiteScore - expectedScores['white']!)).round();
      var blackChange =
          (blackKFactor * (blackScore - expectedScores['black']!)).round();

      // Apply time control bonus/penalty
      final (whiteTimeBonus, blackTimeBonus) = _calculateTimeControlBonus(
          timeControl, whiteCurrentRating, blackCurrentRating);
      whiteChange += whiteTimeBonus;
      blackChange += blackTimeBonus;

      // Apply activity bonus for players with low game count
      if (whiteProfile.gamesPlayed < 10) {
        whiteChange = (whiteChange * 1.1).round();
      }
      if (blackProfile.gamesPlayed < 10) {
        blackChange = (blackChange * 1.1).round();
      }

      // Calculate new ratings with floor/ceiling
      final whiteNewRating =
          _applyFloorAndCeiling(whiteCurrentRating + whiteChange);
      final blackNewRating =
          _applyFloorAndCeiling(blackCurrentRating + blackChange);

      return RatingChangeResult(
        whiteChange: whiteChange,
        blackChange: blackChange,
        whiteNewRating: whiteNewRating,
        blackNewRating: blackNewRating,
        whiteKFactor: whiteKFactor,
        blackKFactor: blackKFactor,
        whiteExpectedScore: expectedScores['white']!,
        blackExpectedScore: expectedScores['black']!,
        timeControlBonus: (whiteTimeBonus, blackTimeBonus),
        whiteIsProvisional: whiteProfile.isProvisional,
        blackIsProvisional: blackProfile.isProvisional,
      );
    } catch (e, st) {
      _logger.e('Failed to calculate rating change', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Record rating change in player history
  Future<void> recordRatingChange({
    required String playerId,
    required int previousRating,
    required int newRating,
    required int ratingChange,
    required String opponentId,
    required String gameId,
    required String result,
    required String timeControl,
  }) async {
    try {
      final timestamp = FieldValue.serverTimestamp();

      final historyEntry = {
        'gameId': gameId,
        'opponentId': opponentId,
        'previousRating': previousRating,
        'newRating': newRating,
        'ratingChange': ratingChange,
        'result': result,
        'timeControl': timeControl,
        'createdAt': timestamp,
      };

      // Add to rating history subcollection
      await _firestore
          .collection(_usersCollection)
          .doc(playerId)
          .collection(_ratingHistorySubcollection)
          .add(historyEntry);

      // Update current rating
      await _firestore.collection(_usersCollection).doc(playerId).update({
        'rating': newRating,
        'lastRatingUpdate': timestamp,
      });

      _logger.i(
          'Rating updated for $playerId: $previousRating -> $newRating (${ratingChange > 0 ? '+' : ''}$ratingChange)');
    } catch (e, st) {
      _logger.e('Failed to record rating change', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Get player's rating history
  Future<List<RatingHistoryEntry>> getRatingHistory(String playerId,
      {int limit = 50}) async {
    try {
      final snapshot = await _firestore
          .collection(_usersCollection)
          .doc(playerId)
          .collection(_ratingHistorySubcollection)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => RatingHistoryEntry.fromJson(doc.data()))
          .toList();
    } catch (e, st) {
      _logger.e('Failed to get rating history', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Get player's rating statistics
  Future<RatingStats> getRatingStats(String playerId) async {
    try {
      final userDoc =
          await _firestore.collection(_usersCollection).doc(playerId).get();

      if (!userDoc.exists) {
        throw Exception('Player not found');
      }

      final data = userDoc.data()!;
      final currentRating = data['rating'] as int? ?? 1200;
      final gamesPlayed = data['gamesPlayed'] as int? ?? 0;

      final history = await getRatingHistory(playerId, limit: 100);

      // Calculate rating trends
      double ratingTrend = 0;
      if (history.length >= 10) {
        final recent = history.take(10).toList();
        final ratingChanges =
            recent.map((entry) => entry.ratingChange.toDouble()).toList();
        ratingTrend =
            ratingChanges.reduce((a, b) => a + b) / ratingChanges.length;
      }

      // Calculate peak and lowest ratings
      int peakRating = currentRating;
      int lowestRating = currentRating;
      for (final entry in history) {
        if (entry.newRating > peakRating) peakRating = entry.newRating;
        if (entry.newRating < lowestRating) lowestRating = entry.newRating;
      }

      return RatingStats(
        currentRating: currentRating,
        gamesPlayed: gamesPlayed,
        peakRating: peakRating,
        lowestRating: lowestRating,
        averageRatingChange: ratingTrend,
        isProvisional: gamesPlayed < _provisionalGameThreshold,
      );
    } catch (e, st) {
      _logger.e('Failed to get rating stats', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Private helper methods

  Future<PlayerProfile> _getPlayerProfile(String playerId) async {
    final userDoc =
        await _firestore.collection(_usersCollection).doc(playerId).get();

    if (!userDoc.exists) {
      return PlayerProfile(
        gamesPlayed: 0,
        rating: 1200,
        isProvisional: true,
      );
    }

    final data = userDoc.data()!;
    return PlayerProfile(
      gamesPlayed: data['gamesPlayed'] as int? ?? 0,
      rating: data['rating'] as int? ?? 1200,
      isProvisional:
          (data['gamesPlayed'] as int? ?? 0) < _provisionalGameThreshold,
    );
  }

  int _determineKFactor(int rating, int gamesPlayed, bool isProvisional) {
    if (isProvisional) return _kFactorProvisional;
    if (rating >= 2400) return _kFactorHighRated;
    return _kFactorStandard;
  }

  Map<String, double> _calculateExpectedScores(
      int whiteRating, int blackRating) {
    const double D = 400;
    final whiteExpected =
        1.0 / (1.0 + pow(10, (blackRating - whiteRating) / D).toDouble());
    final blackExpected = 1.0 - whiteExpected;

    return {
      'white': whiteExpected,
      'black': blackExpected,
    };
  }

  (double, double) _getScoresFromResult(String result) {
    switch (result) {
      case 'white_win':
        return (1.0, 0.0);
      case 'black_win':
        return (0.0, 1.0);
      case 'draw':
        return (0.5, 0.5);
      default:
        return (0.5, 0.5);
    }
  }

  (int, int) _calculateTimeControlBonus(
      String timeControl, int whiteRating, int blackRating) {
    // Bonus for playing faster time controls
    int whiteBonus = 0;
    int blackBonus = 0;

    switch (timeControl) {
      case '3min':
        whiteBonus = 8;
        blackBonus = 8;
        break;
      case '5min':
        whiteBonus = 4;
        blackBonus = 4;
        break;
      default:
        whiteBonus = 0;
        blackBonus = 0;
    }

    return (whiteBonus, blackBonus);
  }

  int _applyFloorAndCeiling(int rating) =>
      rating.clamp(_ratingFloor, _ratingCeiling);
}

/// Result of rating calculation
class RatingChangeResult {
  RatingChangeResult({
    required this.whiteChange,
    required this.blackChange,
    required this.whiteNewRating,
    required this.blackNewRating,
    required this.whiteKFactor,
    required this.blackKFactor,
    required this.whiteExpectedScore,
    required this.blackExpectedScore,
    required this.timeControlBonus,
    required this.whiteIsProvisional,
    required this.blackIsProvisional,
  });
  final int whiteChange;
  final int blackChange;
  final int whiteNewRating;
  final int blackNewRating;
  final int whiteKFactor;
  final int blackKFactor;
  final double whiteExpectedScore;
  final double blackExpectedScore;
  final (int, int) timeControlBonus;
  final bool whiteIsProvisional;
  final bool blackIsProvisional;
}

/// Player profile for rating calculations
class PlayerProfile {
  PlayerProfile({
    required this.gamesPlayed,
    required this.rating,
    required this.isProvisional,
  });
  final int gamesPlayed;
  final int rating;
  final bool isProvisional;
}

/// Rating history entry
class RatingHistoryEntry {
  RatingHistoryEntry({
    required this.gameId,
    required this.opponentId,
    required this.previousRating,
    required this.newRating,
    required this.ratingChange,
    required this.result,
    required this.timeControl,
    required this.createdAt,
  });

  factory RatingHistoryEntry.fromJson(Map<String, dynamic> json) =>
      RatingHistoryEntry(
        gameId: json['gameId'] as String,
        opponentId: json['opponentId'] as String,
        previousRating: json['previousRating'] as int,
        newRating: json['newRating'] as int,
        ratingChange: json['ratingChange'] as int,
        result: json['result'] as String,
        timeControl: json['timeControl'] as String,
        createdAt: (json['createdAt'] as Timestamp).toDate(),
      );
  final String gameId;
  final String opponentId;
  final int previousRating;
  final int newRating;
  final int ratingChange;
  final String result;
  final String timeControl;
  final DateTime createdAt;
}

/// Rating statistics
class RatingStats {
  RatingStats({
    required this.currentRating,
    required this.gamesPlayed,
    required this.peakRating,
    required this.lowestRating,
    required this.averageRatingChange,
    required this.isProvisional,
  });
  final int currentRating;
  final int gamesPlayed;
  final int peakRating;
  final int lowestRating;
  final double averageRatingChange;
  final bool isProvisional;

  int get ratingDeltaFromLowest => currentRating - lowestRating;
  int get ratingDeltaFromPeak => peakRating - currentRating;
}
