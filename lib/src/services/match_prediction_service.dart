import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import 'dart:math' show pow;

/// Match outcome prediction and probability analysis
class MatchPredictionService {
  MatchPredictionService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _firestore;
  final Logger _logger = Logger();

  static const String _usersCollection = 'users';
  static const String _gamesCollection = 'games';

  /// Predict match outcome probabilities between two players
  Future<MatchOutcomePrediction> predictMatchOutcome(
    String whitePlayerId,
    String blackPlayerId,
  ) async {
    try {
      // Get player ratings
      final whiteDoc = await _firestore
          .collection(_usersCollection)
          .doc(whitePlayerId)
          .get();
      final blackDoc = await _firestore
          .collection(_usersCollection)
          .doc(blackPlayerId)
          .get();

      if (!whiteDoc.exists || !blackDoc.exists) {
        throw Exception('One or both players not found');
      }

      final whiteRating = whiteDoc.data()!['rating'] as int? ?? 1200;
      final blackRating = blackDoc.data()!['rating'] as int? ?? 1200;

      // Calculate expected scores using ELO formula
      const double D = 400;
      final whiteExpected =
          1.0 / (1.0 + pow(10, (blackRating - whiteRating) / D).toDouble());
      final blackExpected = 1.0 - whiteExpected;

      // Calculate draw probability based on rating similarity
      final ratingDiff = (whiteRating - blackRating).abs();
      final drawProbability = _calculateDrawProbability(ratingDiff);

      // Adjust win probabilities based on draw probability
      final whiteWinProbability = whiteExpected * (1.0 - drawProbability);
      final blackWinProbability = blackExpected * (1.0 - drawProbability);

      return MatchOutcomePrediction(
        whitePlayerId: whitePlayerId,
        blackPlayerId: blackPlayerId,
        whiteRating: whiteRating,
        blackRating: blackRating,
        whiteWinProbability: whiteWinProbability,
        blackWinProbability: blackWinProbability,
        drawProbability: drawProbability,
        expectedRatingChange: _calculateExpectedRatingChange(
          whiteRating,
          blackRating,
          whiteExpected,
        ),
        matchDifficulty: _calculateMatchDifficulty(ratingDiff),
        confidence: _calculateConfidence(ratingDiff),
      );
    } catch (e, st) {
      _logger.e('Failed to predict match outcome', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Get expected skill gap between two players
  Future<SkillGapAnalysis> analyzeSkillGap(
    String player1Id,
    String player2Id,
  ) async {
    try {
      final player1Doc =
          await _firestore.collection(_usersCollection).doc(player1Id).get();
      final player2Doc =
          await _firestore.collection(_usersCollection).doc(player2Id).get();

      if (!player1Doc.exists || !player2Doc.exists) {
        throw Exception('One or both players not found');
      }

      final rating1 = player1Doc.data()!['rating'] as int? ?? 1200;
      final rating2 = player2Doc.data()!['rating'] as int? ?? 1200;
      final games1 = player1Doc.data()!['gamesPlayed'] as int? ?? 0;
      final games2 = player2Doc.data()!['gamesPlayed'] as int? ?? 0;

      final ratingDiff = (rating1 - rating2).abs();
      final gamesDiff = (games1 - games2).abs();

      // Determine skill gap category
      String skillGapCategory;
      if (ratingDiff < 50) {
        skillGapCategory = 'evenly_matched';
      } else if (ratingDiff < 150) {
        skillGapCategory = 'slight_advantage';
      } else if (ratingDiff < 300) {
        skillGapCategory = 'moderate_advantage';
      } else {
        skillGapCategory = 'significant_advantage';
      }

      return SkillGapAnalysis(
        player1Id: player1Id,
        player2Id: player2Id,
        rating1: rating1,
        rating2: rating2,
        ratingDifference: ratingDiff,
        skillGapCategory: skillGapCategory,
        gamesDifference: gamesDiff,
        expectedOutcome: ratingDiff > 0
            ? 'player1_favored'
            : ratingDiff < 0
                ? 'player2_favored'
                : 'neutral',
      );
    } catch (e, st) {
      _logger.e('Failed to analyze skill gap', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Calculate match competitiveness score (0-100, higher = more competitive)
  Future<MatchCompetitiveness> analyzeMatchCompetitiveness(
    String whitePlayerId,
    String blackPlayerId,
  ) async {
    try {
      final prediction =
          await predictMatchOutcome(whitePlayerId, blackPlayerId);

      // Competitiveness is highest when win probabilities are close to 50-50
      // Calculate how close to 0.5 each probability is
      final whiteProb = prediction.whiteWinProbability;
      final blackProb = prediction.blackWinProbability;

      // Perfect match would be 50-50 for both win chances
      // Score decreases as one side becomes more favored
      final competitivenessScore = (1.0 - (whiteProb - 0.5).abs() * 2) *
          (1.0 - (blackProb - 0.5).abs() * 2);

      return MatchCompetitiveness(
        whitePlayerId: whitePlayerId,
        blackPlayerId: blackPlayerId,
        competitivenessScore: (competitivenessScore * 100).toInt(),
        winProbabilityGap: (whiteProb - blackProb).abs(),
        isCompetitiveMatch: competitivenessScore > 0.3,
      );
    } catch (e, st) {
      _logger.e('Failed to analyze competitiveness', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Get optimal opponent recommendations for a player
  Future<List<OpponentRecommendation>> getOptimalOpponents(
    String playerId, {
    required int limit,
    required int maxRatingDiff,
  }) async {
    try {
      final playerDoc =
          await _firestore.collection(_usersCollection).doc(playerId).get();

      if (!playerDoc.exists) {
        throw Exception('Player not found');
      }

      final playerRating = playerDoc.data()!['rating'] as int? ?? 1200;
      final minRating = playerRating - maxRatingDiff;
      final maxRating = playerRating + maxRatingDiff;

      // Get available players in rating range
      final snapshot = await _firestore
          .collection(_usersCollection)
          .where('rating', isGreaterThanOrEqualTo: minRating)
          .where('rating', isLessThanOrEqualTo: maxRating)
          .limit(limit * 2) // Fetch more to filter
          .get();

      final recommendations = <OpponentRecommendation>[];

      for (final doc in snapshot.docs) {
        final opponentId = doc.id;
        if (opponentId == playerId) continue;

        final opponentRating = doc.data()['rating'] as int? ?? 1200;

        try {
          final competitiveness =
              await analyzeMatchCompetitiveness(playerId, opponentId);
          final prediction = await predictMatchOutcome(playerId, opponentId);

          recommendations.add(OpponentRecommendation(
            opponentId: opponentId,
            opponentName: doc.data()['playerName'] as String? ?? 'Unknown',
            opponentRating: opponentRating,
            competitivenessScore: competitiveness.competitivenessScore,
            winProbability: prediction.whiteWinProbability,
            predictedDifficulty: prediction.matchDifficulty,
          ));
        } catch (e) {
          _logger.w('Error processing opponent $opponentId: $e');
          continue;
        }
      }

      // Sort by competitiveness score (descending)
      recommendations.sort(
          (a, b) => b.competitivenessScore.compareTo(a.competitivenessScore));

      return recommendations.take(limit).toList();
    } catch (e, st) {
      _logger.e('Failed to get optimal opponents', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Predict rating change if match occurs
  (int, int) _calculateExpectedRatingChange(
    int whiteRating,
    int blackRating,
    double whiteExpected,
  ) {
    const int kFactorStandard = 32;

    // Estimate based on expected outcome
    // If white is expected to win, draw means rating drop
    final whiteChange = (kFactorStandard * (0.5 - whiteExpected)).toInt();
    final blackChange = -whiteChange;

    return (whiteChange, blackChange);
  }

  /// Calculate draw probability based on rating difference
  double _calculateDrawProbability(int ratingDiff) {
    // Higher probability for closely matched players
    if (ratingDiff < 50) {
      return 0.35; // Evenly matched
    } else if (ratingDiff < 100) {
      return 0.30;
    } else if (ratingDiff < 200) {
      return 0.20;
    } else if (ratingDiff < 300) {
      return 0.10;
    } else {
      return 0.05; // Very uneven
    }
  }

  /// Calculate match difficulty rating (1-10)
  int _calculateMatchDifficulty(int ratingDiff) {
    if (ratingDiff < 50) {
      return 10; // Extremely difficult/competitive
    } else if (ratingDiff < 100) {
      return 9;
    } else if (ratingDiff < 150) {
      return 8;
    } else if (ratingDiff < 200) {
      return 7;
    } else if (ratingDiff < 250) {
      return 6;
    } else if (ratingDiff < 300) {
      return 5;
    } else if (ratingDiff < 400) {
      return 3;
    } else {
      return 1; // Very one-sided
    }
  }

  /// Calculate confidence score (0-1) for prediction
  double _calculateConfidence(int ratingDiff) {
    // Higher confidence for similar ratings (more stable predictions)
    if (ratingDiff < 50) {
      return 0.85;
    } else if (ratingDiff < 100) {
      return 0.80;
    } else if (ratingDiff < 150) {
      return 0.75;
    } else if (ratingDiff < 200) {
      return 0.70;
    } else if (ratingDiff < 300) {
      return 0.65;
    } else {
      return 0.50;
    }
  }
}

/// Match outcome prediction result
class MatchOutcomePrediction {
  MatchOutcomePrediction({
    required this.whitePlayerId,
    required this.blackPlayerId,
    required this.whiteRating,
    required this.blackRating,
    required this.whiteWinProbability,
    required this.blackWinProbability,
    required this.drawProbability,
    required this.expectedRatingChange,
    required this.matchDifficulty,
    required this.confidence,
  });
  final String whitePlayerId;
  final String blackPlayerId;
  final int whiteRating;
  final int blackRating;
  final double whiteWinProbability;
  final double blackWinProbability;
  final double drawProbability;
  final (int, int) expectedRatingChange;
  final int matchDifficulty;
  final double confidence;
}

/// Skill gap analysis between two players
class SkillGapAnalysis {
  SkillGapAnalysis({
    required this.player1Id,
    required this.player2Id,
    required this.rating1,
    required this.rating2,
    required this.ratingDifference,
    required this.skillGapCategory,
    required this.gamesDifference,
    required this.expectedOutcome,
  });
  final String player1Id;
  final String player2Id;
  final int rating1;
  final int rating2;
  final int ratingDifference;
  final String skillGapCategory;
  final int gamesDifference;
  final String expectedOutcome;
}

/// Match competitiveness analysis
class MatchCompetitiveness {
  MatchCompetitiveness({
    required this.whitePlayerId,
    required this.blackPlayerId,
    required this.competitivenessScore,
    required this.winProbabilityGap,
    required this.isCompetitiveMatch,
  });
  final String whitePlayerId;
  final String blackPlayerId;
  final int competitivenessScore;
  final double winProbabilityGap;
  final bool isCompetitiveMatch;
}

/// Opponent recommendation with scoring
class OpponentRecommendation {
  OpponentRecommendation({
    required this.opponentId,
    required this.opponentName,
    required this.opponentRating,
    required this.competitivenessScore,
    required this.winProbability,
    required this.predictedDifficulty,
  });
  final String opponentId;
  final String opponentName;
  final int opponentRating;
  final int competitivenessScore;
  final double winProbability;
  final int predictedDifficulty;
}
