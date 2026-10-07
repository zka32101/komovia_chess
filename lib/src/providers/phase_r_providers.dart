import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/match_prediction_service.dart';
import '../services/adaptive_matchmaking_service.dart';

/// Phase R - Predictive Matchmaking Providers
/// Provides reactive access to match prediction and adaptive matchmaking

// Service Providers
final matchPredictionServiceProvider = Provider<MatchPredictionService>(
    (ref) => MatchPredictionService(firestore: FirebaseFirestore.instance));

final adaptiveMatchmakingServiceProvider =
    Provider<AdaptiveMatchmakingService>((ref) {
  final predictionService = ref.watch(matchPredictionServiceProvider);
  return AdaptiveMatchmakingService(
    firestore: FirebaseFirestore.instance,
    predictionService: predictionService,
  );
});

// Match Prediction Providers

/// Predict match outcome between two players
final matchOutcomePredictionProvider = FutureProvider.family<
    MatchOutcomePrediction,
    ({
      String whitePlayerId,
      String blackPlayerId,
    })>((ref, params) {
  final service = ref.watch(matchPredictionServiceProvider);
  return service.predictMatchOutcome(
    params.whitePlayerId,
    params.blackPlayerId,
  );
});

/// Analyze skill gap between two players
final skillGapAnalysisProvider = FutureProvider.family<
    SkillGapAnalysis,
    ({
      String player1Id,
      String player2Id,
    })>((ref, params) {
  final service = ref.watch(matchPredictionServiceProvider);
  return service.analyzeSkillGap(
    params.player1Id,
    params.player2Id,
  );
});

/// Analyze match competitiveness
final matchCompetitivenessProvider = FutureProvider.family<
    MatchCompetitiveness,
    ({
      String whitePlayerId,
      String blackPlayerId,
    })>((ref, params) {
  final service = ref.watch(matchPredictionServiceProvider);
  return service.analyzeMatchCompetitiveness(
    params.whitePlayerId,
    params.blackPlayerId,
  );
});

/// Get optimal opponent recommendations
final optimalOpponentsProvider = FutureProvider.family<
    List<OpponentRecommendation>,
    ({
      String playerId,
      int limit,
      int maxRatingDiff,
    })>((ref, params) {
  final service = ref.watch(matchPredictionServiceProvider);
  return service.getOptimalOpponents(
    params.playerId,
    limit: params.limit,
    maxRatingDiff: params.maxRatingDiff,
  );
});

// Adaptive Matchmaking Providers

/// Find optimal match for queued player
final adaptiveMatchProvider =
    FutureProvider.family<AdaptiveMatchResult?, String>((ref, queueId) {
  final service = ref.watch(adaptiveMatchmakingServiceProvider);
  return service.findOptimalMatch(queueId);
});

/// Get match suggestions for player development
final matchSuggestionsProvider =
    FutureProvider.family<List<MatchSuggestion>, String>((ref, playerId) {
  final service = ref.watch(adaptiveMatchmakingServiceProvider);
  return service.getMatchSuggestions(playerId);
});

/// Analyze match quality between two players
final matchQualityProvider = FutureProvider.family<
    MatchQualityMetrics,
    ({
      String playerId,
      String opponentId,
    })>((ref, params) {
  final service = ref.watch(adaptiveMatchmakingServiceProvider);
  return service.analyzeMatchQuality(
    params.playerId,
    params.opponentId,
  );
});

// Combined Analytics Providers

/// Get comprehensive match analysis (prediction + quality + suggestions)
final comprehensiveMatchAnalysisProvider = FutureProvider.family<
    ComprehensiveMatchAnalysis,
    ({
      String playerId,
      String? opponentId,
    })>((ref, params) async {
  final predictionService = ref.watch(matchPredictionServiceProvider);
  final adaptiveService = ref.watch(adaptiveMatchmakingServiceProvider);

  final suggestionsAsync = ref.watch(matchSuggestionsProvider(params.playerId));

  if (params.opponentId != null) {
    final predictionAsync = ref.watch(matchOutcomePredictionProvider((
      whitePlayerId: params.playerId,
      blackPlayerId: params.opponentId!,
    )));
    final qualityAsync = ref.watch(matchQualityProvider((
      playerId: params.playerId,
      opponentId: params.opponentId!,
    )));

    return Future.wait([
      predictionAsync.when(
        data: (data) async => data,
        error: (err, st) => throw err,
        loading: () => throw Exception('Loading prediction'),
      ),
      qualityAsync.when(
        data: (data) async => data,
        error: (err, st) => throw err,
        loading: () => throw Exception('Loading quality'),
      ),
      suggestionsAsync.when(
        data: (data) async => data,
        error: (err, st) => throw err,
        loading: () => throw Exception('Loading suggestions'),
      ),
    ]).then((results) => ComprehensiveMatchAnalysis(
          playerId: params.playerId,
          prediction: results[0] as MatchOutcomePrediction,
          quality: results[1] as MatchQualityMetrics,
          suggestions: results[2] as List<MatchSuggestion>,
        ));
  }

  return await suggestionsAsync.when(
    data: (suggestions) async => ComprehensiveMatchAnalysis(
      playerId: params.playerId,
      suggestions: suggestions,
    ),
    error: (err, st) => throw err,
    loading: () => throw Exception('Loading suggestions'),
  );
});

/// Comprehensive match analysis data class
class ComprehensiveMatchAnalysis {
  ComprehensiveMatchAnalysis({
    required this.playerId,
    required this.suggestions,
    this.prediction,
    this.quality,
  });
  final String playerId;
  final MatchOutcomePrediction? prediction;
  final MatchQualityMetrics? quality;
  final List<MatchSuggestion> suggestions;
}
