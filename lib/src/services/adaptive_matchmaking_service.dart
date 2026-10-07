import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import 'match_prediction_service.dart';

/// Adaptive matchmaking using predictions and analytics
class AdaptiveMatchmakingService {
  AdaptiveMatchmakingService({
    FirebaseFirestore? firestore,
    MatchPredictionService? predictionService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _predictionService =
            predictionService ?? MatchPredictionService(firestore: firestore);
  final FirebaseFirestore _firestore;
  final MatchPredictionService _predictionService;
  final Logger _logger = Logger();

  static const String _queuesCollection = 'matchmakingQueues';
  static const String _usersCollection = 'users';

  /// Find optimal match using predictions
  Future<AdaptiveMatchResult?> findOptimalMatch(String queueId) async {
    try {
      final queueDoc =
          await _firestore.collection(_queuesCollection).doc(queueId).get();

      if (!queueDoc.exists) {
        return null;
      }

      final queueData = queueDoc.data()!;
      final playerId = queueData['playerId'] as String;
      final playerRating = queueData['rating'] as int;
      final timeControl = queueData['timeControl'] as String;

      // Get candidate opponents
      final candidates = await _getCandidateOpponents(
        playerId,
        playerRating,
        timeControl,
      );

      if (candidates.isEmpty) {
        return null;
      }

      // Score each candidate based on competitiveness and other factors
      final scoredCandidates = <ScoredCandidate>[];

      for (final candidate in candidates) {
        try {
          final competitiveness = await _predictionService
              .analyzeMatchCompetitiveness(playerId, candidate['playerId']);
          final prediction = await _predictionService.predictMatchOutcome(
            playerId,
            candidate['playerId'],
          );

          final score = _calculateMatchScore(
            competitiveness,
            prediction,
            candidate['waitTimeMs'] as int,
          );

          scoredCandidates.add(ScoredCandidate(
            candidate: candidate,
            competitiveness: competitiveness,
            prediction: prediction,
            score: score,
          ));
        } catch (e) {
          _logger.w('Error scoring candidate: $e');
          continue;
        }
      }

      if (scoredCandidates.isEmpty) {
        return null;
      }

      // Sort by score (highest first)
      scoredCandidates.sort((a, b) => b.score.compareTo(a.score));

      final bestMatch = scoredCandidates.first;
      final candidate = bestMatch.candidate;

      return AdaptiveMatchResult(
        player1Id: playerId,
        player1Name: queueData['playerName'] as String,
        player1Rating: playerRating,
        player2Id: candidate['playerId'],
        player2Name: candidate['playerName'],
        player2Rating: candidate['rating'],
        matchQuality: bestMatch.score,
        competitivenessScore: bestMatch.competitiveness.competitivenessScore,
        predictedDifficulty: bestMatch.prediction.matchDifficulty,
        timeControl: timeControl,
      );
    } catch (e, st) {
      _logger.e('Failed to find optimal match', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Get intelligent match suggestions based on player performance
  Future<List<MatchSuggestion>> getMatchSuggestions(String playerId) async {
    try {
      final playerDoc =
          await _firestore.collection(_usersCollection).doc(playerId).get();

      if (!playerDoc.exists) {
        throw Exception('Player not found');
      }

      final playerData = playerDoc.data()!;
      final playerRating = playerData['rating'] as int? ?? 1200;
      final gamesPlayed = playerData['gamesPlayed'] as int? ?? 0;

      final suggestions = <MatchSuggestion>[];

      // Suggest challenging matches for improving players
      if (gamesPlayed < 50) {
        suggestions.add(MatchSuggestion(
          type: 'improvement',
          description: 'Play against slightly stronger opponents',
          recommendedRatingRange: (playerRating + 50, playerRating + 150),
          priority: 1,
          reasoning: 'Challenge helps skill development',
        ));
      }

      // Suggest confidence-building matches
      if (gamesPlayed > 20) {
        suggestions.add(MatchSuggestion(
          type: 'confidence_building',
          description: 'Play competitive matches at your level',
          recommendedRatingRange: (playerRating - 50, playerRating + 50),
          priority: 2,
          reasoning: 'Build confidence with evenly matched opponents',
        ));
      }

      // Suggest testing against stronger players
      if (gamesPlayed > 50) {
        suggestions.add(MatchSuggestion(
          type: 'skill_test',
          description: 'Test skills against stronger opponents',
          recommendedRatingRange: (playerRating + 150, playerRating + 300),
          priority: 3,
          reasoning: 'Evaluate readiness for higher rating tiers',
        ));
      }

      return suggestions;
    } catch (e, st) {
      _logger.e('Failed to get match suggestions', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Calculate wait time adjustment based on match quality
  Future<MatchQualityMetrics> analyzeMatchQuality(
    String playerId,
    String opponentId,
  ) async {
    try {
      final prediction =
          await _predictionService.predictMatchOutcome(playerId, opponentId);
      final competitiveness =
          await _predictionService.analyzeMatchCompetitiveness(
        playerId,
        opponentId,
      );

      return MatchQualityMetrics(
        playerId: playerId,
        opponentId: opponentId,
        qualityScore: _calculateQualityScore(competitiveness, prediction),
        competitivenessScore: competitiveness.competitivenessScore,
        fairnessScore: _calculateFairnessScore(prediction),
        recommendedMatch: competitiveness.isCompetitiveMatch,
      );
    } catch (e, st) {
      _logger.e('Failed to analyze match quality', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Private helper methods

  Future<List<Map<String, dynamic>>> _getCandidateOpponents(
    String playerId,
    int playerRating,
    String timeControl,
  ) async {
    try {
      // Get players in queue with same time control
      final snapshot = await _firestore
          .collection(_queuesCollection)
          .where('timeControl', isEqualTo: timeControl)
          .where('status', isEqualTo: 'waiting')
          .get();

      final candidates = <Map<String, dynamic>>[];
      final now = DateTime.now();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final opponentId = data['playerId'] as String;

        if (opponentId == playerId) continue;

        final waitTimeMs = now
            .difference((data['enqueuedAt'] as Timestamp).toDate())
            .inMilliseconds;

        candidates.add({
          'playerId': opponentId,
          'playerName': data['playerName'] as String? ?? 'Unknown',
          'rating': data['rating'] as int? ?? 1200,
          'waitTimeMs': waitTimeMs,
          'isProvisional': data['isProvisional'] as bool? ?? false,
        });
      }

      return candidates;
    } catch (e, st) {
      _logger.e('Failed to get candidate opponents', error: e, stackTrace: st);
      return [];
    }
  }

  int _calculateMatchScore(
    MatchCompetitiveness competitiveness,
    MatchOutcomePrediction prediction,
    int waitTimeMs,
  ) {
    // Score based on multiple factors
    int score = 0;

    // Competitiveness weight (40%)
    score += (competitiveness.competitivenessScore * 0.4).toInt();

    // Prediction confidence weight (30%)
    score += (prediction.confidence * 100 * 0.3).toInt();

    // Fairness (win probability gap) weight (20%)
    final fairness = 1.0 - prediction.whiteWinProbability.abs();
    score += (fairness * 100 * 0.2).toInt();

    // Wait time bonus (10%) - prefer shorter waits
    final waitTimeBonus = (100 - (waitTimeMs / 300).clamp(0, 100)).toInt();
    score += (waitTimeBonus * 0.1).toInt();

    return score.clamp(0, 100);
  }

  int _calculateQualityScore(
    MatchCompetitiveness competitiveness,
    MatchOutcomePrediction prediction,
  ) {
    // Quality is a combination of competitiveness and prediction confidence
    final competitivenessWeight = competitiveness.competitivenessScore / 100;
    final confidenceWeight = prediction.confidence;

    return ((competitivenessWeight * 0.6 + confidenceWeight * 0.4) * 100)
        .toInt();
  }

  int _calculateFairnessScore(MatchOutcomePrediction prediction) {
    // Fairness is highest when win probabilities are close
    // 100 = perfectly fair (50-50), 0 = completely one-sided
    final gapFromFair = (prediction.whiteWinProbability - 0.5).abs() * 2;
    return ((1.0 - gapFromFair) * 100).toInt();
  }
}

/// Result of adaptive matching
class AdaptiveMatchResult {
  AdaptiveMatchResult({
    required this.player1Id,
    required this.player1Name,
    required this.player1Rating,
    required this.player2Id,
    required this.player2Name,
    required this.player2Rating,
    required this.matchQuality,
    required this.competitivenessScore,
    required this.predictedDifficulty,
    required this.timeControl,
  });
  final String player1Id;
  final String player1Name;
  final int player1Rating;
  final String player2Id;
  final String player2Name;
  final int player2Rating;
  final int matchQuality;
  final int competitivenessScore;
  final int predictedDifficulty;
  final String timeControl;
}

/// Match suggestion for player development
class MatchSuggestion {
  MatchSuggestion({
    required this.type,
    required this.description,
    required this.recommendedRatingRange,
    required this.priority,
    required this.reasoning,
  });
  final String type;
  final String description;
  final (int, int) recommendedRatingRange;
  final int priority;
  final String reasoning;
}

/// Match quality metrics
class MatchQualityMetrics {
  MatchQualityMetrics({
    required this.playerId,
    required this.opponentId,
    required this.qualityScore,
    required this.competitivenessScore,
    required this.fairnessScore,
    required this.recommendedMatch,
  });
  final String playerId;
  final String opponentId;
  final int qualityScore;
  final int competitivenessScore;
  final int fairnessScore;
  final bool recommendedMatch;
}

/// Scored candidate for internal use
class ScoredCandidate {
  ScoredCandidate({
    required this.candidate,
    required this.competitiveness,
    required this.prediction,
    required this.score,
  });
  final Map<String, dynamic> candidate;
  final MatchCompetitiveness competitiveness;
  final MatchOutcomePrediction prediction;
  final int score;
}
