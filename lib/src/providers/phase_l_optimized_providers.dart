import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/leaderboard_service_optimized.dart';
import '../services/friend_service_optimized.dart';
import '../services/challenge_service_optimized.dart';
import '../services/tournament_service_optimized.dart';
import '../models/phase_k_models.dart';
import '../utils/pagination_helper.dart';
import '../utils/performance_monitor.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ========== Optimized Service Providers ==========

/// Access to optimized LeaderboardService
final leaderboardServiceOptimizedProvider =
    Provider((ref) => LeaderboardServiceOptimized.instance);

/// Access to optimized FriendService
final friendServiceOptimizedProvider =
    Provider((ref) => FriendServiceOptimized.instance);

/// Access to optimized FriendChallengeService
final friendChallengeServiceOptimizedProvider =
    Provider((ref) => FriendChallengeServiceOptimized.instance);

/// Access to optimized TournamentService
final tournamentServiceOptimizedProvider =
    Provider((ref) => TournamentServiceOptimized.instance);

/// Performance monitoring
final performanceMonitorProvider =
    Provider((ref) => PerformanceMonitor.instance);

// ========== Paginated Leaderboard Providers ==========

/// Global leaderboard with pagination
final globalLeaderboardPaginatedProvider = FutureProvider.family<
    PaginatedResult<LeaderboardEntry>, (int, DocumentSnapshot?)>(
  (ref, params) async {
    final (pageSize, startAfter) = params;
    final service = ref.watch(leaderboardServiceOptimizedProvider);
    return service.getGlobalLeaderboardPaginated(
      pageSize: pageSize,
      startAfter: startAfter,
    );
  },
);

/// Regional leaderboard with pagination
final regionalLeaderboardPaginatedProvider = FutureProvider.family<
    PaginatedResult<LeaderboardEntry>, (String, int, DocumentSnapshot?)>(
  (ref, params) async {
    final (region, pageSize, startAfter) = params;
    final service = ref.watch(leaderboardServiceOptimizedProvider);
    return service.getRegionalLeaderboardPaginated(
      region,
      pageSize: pageSize,
      startAfter: startAfter,
    );
  },
);

/// Optimized H2H stats with monitoring
final headToHeadStatsOptimizedProvider =
    FutureProvider.family<Map<String, int>, (String, String)>(
  (ref, params) async {
    final (userId1, userId2) = params;
    final service = ref.watch(leaderboardServiceOptimizedProvider);
    final monitor = ref.watch(performanceMonitorProvider);

    return monitor.measureAsync(
      'headToHeadStats_${userId1}_$userId2',
      () => service.getHeadToHeadStatsOptimized(userId1, userId2),
    );
  },
);

/// Batch ranking stats query
final rankingStatsBatchProvider =
    FutureProvider.family<List<RankingStats>, List<String>>(
  (ref, userIds) async {
    final service = ref.watch(leaderboardServiceOptimizedProvider);
    final monitor = ref.watch(performanceMonitorProvider);

    return monitor.measureAsync(
      'rankingStatsBatch_${userIds.length}users',
      () => service.getRankingStatsBatch(userIds),
    );
  },
);

// ========== Paginated Friend Providers ==========

/// Friend list with pagination
final userFriendsPaginatedProvider = FutureProvider.family<
    PaginatedResult<Friend>, (String, int, DocumentSnapshot?)>(
  (ref, params) async {
    final (userId, pageSize, startAfter) = params;
    final service = ref.watch(friendServiceOptimizedProvider);

    return service.getUserFriendsPaginated(
      userId,
      pageSize: pageSize,
      startAfter: startAfter,
    );
  },
);

/// Pending friend requests with pagination
final pendingFriendRequestsPaginatedProvider = FutureProvider.family<
    PaginatedResult<FriendRequest>, (String, int, DocumentSnapshot?)>(
  (ref, params) async {
    final (userId, pageSize, startAfter) = params;
    final service = ref.watch(friendServiceOptimizedProvider);

    return service.getPendingRequestsPaginated(
      userId,
      pageSize: pageSize,
      startAfter: startAfter,
    );
  },
);

/// Activity feed with pagination
final activityFeedPaginatedProvider = FutureProvider.family<
    PaginatedResult<FriendActivity>, (String, int, DocumentSnapshot?)>(
  (ref, params) async {
    final (userId, pageSize, startAfter) = params;
    final service = ref.watch(friendServiceOptimizedProvider);

    return service.getActivityFeedPaginated(
      userId,
      pageSize: pageSize,
      startAfter: startAfter,
    );
  },
);

/// Friend count (cached)
final friendCountProvider = FutureProvider.family<int, String>(
  (ref, userId) async {
    final service = ref.watch(friendServiceOptimizedProvider);
    return service.getFriendCount(userId);
  },
);

/// Mutual friends
final mutualFriendsProvider =
    FutureProvider.family<List<Friend>, (String, String)>(
  (ref, params) async {
    final (userId1, userId2) = params;
    final service = ref.watch(friendServiceOptimizedProvider);

    return service.getMutualFriends(userId1, userId2);
  },
);

// ========== Paginated Challenge Providers ==========

/// Pending challenges with pagination
final pendingChallengesPaginatedProvider = FutureProvider.family<
    PaginatedResult<Challenge>, (String, int, DocumentSnapshot?)>(
  (ref, params) async {
    final (userId, pageSize, startAfter) = params;
    final service = ref.watch(friendChallengeServiceOptimizedProvider);

    return service.getPendingChallengesPaginated(
      userId,
      pageSize: pageSize,
      startAfter: startAfter,
    );
  },
);

/// Active challenges with pagination
final activeChallengesPaginatedProvider = FutureProvider.family<
    PaginatedResult<Challenge>, (String, int, DocumentSnapshot?)>(
  (ref, params) async {
    final (userId, pageSize, startAfter) = params;
    final service = ref.watch(friendChallengeServiceOptimizedProvider);

    return service.getActiveChallengesPaginated(
      userId,
      pageSize: pageSize,
      startAfter: startAfter,
    );
  },
);

/// Challenge history with pagination
final challengeHistoryPaginatedProvider = FutureProvider.family<
    PaginatedResult<Challenge>, (String, int, DocumentSnapshot?)>(
  (ref, params) async {
    final (userId, pageSize, startAfter) = params;
    final service = ref.watch(friendChallengeServiceOptimizedProvider);

    return service.getChallengHistoryPaginated(
      userId,
      pageSize: pageSize,
      startAfter: startAfter,
    );
  },
);

/// User's current streak (optimized caching)
final userChallengeStreakOptimizedProvider =
    FutureProvider.family<ChallengeStreak, String>(
  (ref, userId) async {
    final service = ref.watch(friendChallengeServiceOptimizedProvider);
    return service.getUserStreakOptimized(userId);
  },
);

/// Top challenge streaks (cached)
final topChallengeStreaksOptimizedProvider =
    FutureProvider<List<ChallengeStreak>>(
  (ref) async {
    final service = ref.watch(friendChallengeServiceOptimizedProvider);
    return service.getTopStreaksOptimized();
  },
);

/// Head-to-head challenge stats (monitored cache)
final headToHeadChallengeStatsOptimizedProvider =
    FutureProvider.family<Map<String, int>, (String, String)>(
  (ref, params) async {
    final (userId1, userId2) = params;
    final service = ref.watch(friendChallengeServiceOptimizedProvider);

    return service.getHeadToHeadChallengeStats(userId1, userId2);
  },
);

/// Recent challenges
final userRecentChallengesProvider =
    FutureProvider.family<List<Challenge>, (String, int)>(
  (ref, params) async {
    final (userId, limit) = params;
    final service = ref.watch(friendChallengeServiceOptimizedProvider);

    return service.getUserRecentChallenges(userId, limit: limit);
  },
);

// ========== Paginated Tournament Providers ==========

/// Active tournaments with pagination
final activeTournamentsPaginatedProvider = FutureProvider.family<
    PaginatedResult<Tournament>, (int, DocumentSnapshot?)>(
  (ref, params) async {
    final (pageSize, startAfter) = params;
    final service = ref.watch(tournamentServiceOptimizedProvider);

    return service.getActiveTournamentsPaginated(
      pageSize: pageSize,
      startAfter: startAfter,
    );
  },
);

/// Tournament standings (optimized caching)
final tournamentStandingsOptimizedProvider =
    FutureProvider.family<TournamentStandings, String>(
  (ref, tournamentId) async {
    final service = ref.watch(tournamentServiceOptimizedProvider);
    return service.getTournamentStandingsOptimized(tournamentId);
  },
);

/// Tournament matches with pagination
final tournamentMatchesPaginatedProvider = FutureProvider.family<
    PaginatedResult<TournamentMatch>, (String, int?, int, DocumentSnapshot?)>(
  (ref, params) async {
    final (tournamentId, round, pageSize, startAfter) = params;
    final service = ref.watch(tournamentServiceOptimizedProvider);

    return service.getTournamentMatchesPaginated(
      tournamentId,
      round: round,
      pageSize: pageSize,
      startAfter: startAfter,
    );
  },
);

/// User's upcoming matches with pagination
final userUpcomingMatchesPaginatedProvider = FutureProvider.family<
    PaginatedResult<TournamentMatch>, (String, int, DocumentSnapshot?)>(
  (ref, params) async {
    final (userId, pageSize, startAfter) = params;
    final service = ref.watch(tournamentServiceOptimizedProvider);

    return service.getUserUpcomingMatches(
      userId,
      pageSize: pageSize,
      startAfter: startAfter,
    );
  },
);

/// Tournament participant count (cached)
final tournamentParticipantCountProvider = FutureProvider.family<int, String>(
  (ref, tournamentId) async {
    final service = ref.watch(tournamentServiceOptimizedProvider);
    return service.getTournamentParticipantCount(tournamentId);
  },
);

// ========== Performance Monitoring ==========

/// Performance summary for all operations
final performanceSummaryProvider = Provider((ref) {
  final monitor = ref.watch(performanceMonitorProvider);
  return monitor.getSummary();
});

/// Get slowest operations
final slowestOperationsProvider = Provider<List<PerformanceMetric>>((ref) {
  final monitor = ref.watch(performanceMonitorProvider);
  return monitor.getSlowestOperations(10);
});

/// Failed operations
final failedOperationsProvider = Provider<List<PerformanceMetric>>((ref) {
  final monitor = ref.watch(performanceMonitorProvider);
  return monitor.getFailedOperations();
});

// ========== Cache Invalidation Helpers ==========

/// Notifier for invalidating caches
final cacheInvalidationProvider = Provider<CacheInvalidationHelper>((ref) {
  final leaderboardService = ref.watch(leaderboardServiceOptimizedProvider);
  final friendService = ref.watch(friendServiceOptimizedProvider);
  final challengeService = ref.watch(friendChallengeServiceOptimizedProvider);
  final tournamentService = ref.watch(tournamentServiceOptimizedProvider);

  return CacheInvalidationHelper(
    leaderboardService: leaderboardService,
    friendService: friendService,
    challengeService: challengeService,
    tournamentService: tournamentService,
  );
});

// ========== Helper Classes ==========

class CacheInvalidationHelper {
  CacheInvalidationHelper({
    required this.leaderboardService,
    required this.friendService,
    required this.challengeService,
    required this.tournamentService,
  });
  final LeaderboardServiceOptimized leaderboardService;
  final FriendServiceOptimized friendService;
  final FriendChallengeServiceOptimized challengeService;
  final TournamentServiceOptimized tournamentService;

  void invalidateUserAllCaches(String userId) {
    leaderboardService.invalidateUserCache(userId);
    friendService.invalidateUserCache(userId);
    challengeService.invalidateUserCache(userId);
  }

  void invalidateUserInteractionCaches(String userId1, String userId2) {
    leaderboardService.invalidateUserCache(userId1);
    leaderboardService.invalidateUserCache(userId2);
    friendService.invalidateFriendCache(userId1, userId2);
    challengeService.invalidateStreakCache(userId1, userId2);
  }

  void invalidateTournamentCaches(String tournamentId) {
    tournamentService.invalidateTournamentCache(tournamentId);
  }

  void clearAllCaches() {
    leaderboardService.clearCache();
    friendService.clearCache();
    challengeService.clearCache();
    tournamentService.clearCache();
  }
}
