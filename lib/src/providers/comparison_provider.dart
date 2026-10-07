import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/comparison_service.dart';
import '../models/head_to_head_stats.dart';
import '../models/match_record.dart';

/// Provider for comparison service
final comparisonServiceProvider = Provider((ref) => ComparisonService());

/// Head-to-head stats provider for two players
final headToHeadStatsProvider = StreamProvider.family<HeadToHeadStats,
    ({String player1Id, String player2Id})>(
  (ref, params) async* {
    final service = ref.watch(comparisonServiceProvider);
    yield* service.watchHeadToHeadStats(params.player1Id, params.player2Id);
  },
);

/// Recent matches provider for two players
final recentMatchesProvider = FutureProvider.family<List<MatchRecord>,
    ({String player1Id, String player2Id})>(
  (ref, params) async {
    final service = ref.watch(comparisonServiceProvider);
    return service.getRecentMatches(
      params.player1Id,
      params.player2Id,
    );
  },
);

/// Win probability calculator provider
final winProbabilityProvider = Provider.family<double, int>(
  (ref, ratingDiff) {
    final service = ref.watch(comparisonServiceProvider);
    return service.calculateWinProbability(ratingDiff);
  },
);
