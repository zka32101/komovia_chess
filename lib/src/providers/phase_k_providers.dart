import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/leaderboard_service.dart';
import '../services/friend_service.dart';
import '../services/challenge_service.dart';
import '../services/tournament_service.dart';
import '../models/phase_k_models.dart';

// ========== Service Providers ==========

/// Access to LeaderboardService singleton
final leaderboardServiceProvider =
    Provider((ref) => LeaderboardService.instance);

/// Access to FriendService singleton
final friendServiceProvider = Provider((ref) => FriendService.instance);

/// Access to FriendChallengeService singleton
final friendChallengeServiceProvider =
    Provider((ref) => FriendChallengeService.instance);

/// Access to TournamentService singleton
final tournamentServiceProvider = Provider((ref) => TournamentService.instance);

// ========== Leaderboard Providers ==========

/// Get global leaderboard
final globalLeaderboardProvider =
    FutureProvider.family<List<LeaderboardEntry>, int>((ref, limit) async {
  final service = ref.watch(leaderboardServiceProvider);
  return service.getGlobalLeaderboard(limit: limit);
});

/// Get regional leaderboard
final regionalLeaderboardProvider =
    FutureProvider.family<List<LeaderboardEntry>, (String, int)>(
        (ref, params) async {
  final (region, limit) = params;
  final service = ref.watch(leaderboardServiceProvider);
  return service.getRegionalLeaderboard(region, limit: limit);
});

/// Get time-based leaderboard
final timeBasedLeaderboardProvider =
    FutureProvider.family<List<LeaderboardEntry>, (String, int)>(
        (ref, params) async {
  final (period, limit) = params;
  final service = ref.watch(leaderboardServiceProvider);
  return service.getTimeBasedLeaderboard(period, limit: limit);
});

/// Get user's global rank
final userGlobalRankProvider =
    FutureProvider.family<int, String>((ref, userId) async {
  final service = ref.watch(leaderboardServiceProvider);
  return service.getUserGlobalRank(userId);
});

/// Get user's percentile rank
final userPercentileProvider =
    FutureProvider.family<int, String>((ref, userId) async {
  final service = ref.watch(leaderboardServiceProvider);
  return service.getUserPercentile(userId);
});

/// Get user's ranking statistics
final userRankingStatsProvider =
    FutureProvider.family<RankingStats, String>((ref, userId) async {
  final service = ref.watch(leaderboardServiceProvider);
  return service.getRankingStats(userId);
});

/// Get leaderboard history for user
final leaderboardHistoryProvider =
    FutureProvider.family<List<LeaderboardHistory>, (String, String, int)>(
        (ref, params) async {
  final (userId, period, limit) = params;
  final service = ref.watch(leaderboardServiceProvider);
  return service.getLeaderboardHistory(userId, period: period, limit: limit);
});

/// Search leaderboard by username
final leaderboardSearchProvider =
    FutureProvider.family<List<LeaderboardEntry>, String>((ref, query) async {
  final service = ref.watch(leaderboardServiceProvider);
  return service.searchByUsername(query);
});

/// Compare two players
final playerComparisonProvider =
    FutureProvider.family<LeaderboardComparison, (String, String)>(
        (ref, params) async {
  final (userId1, userId2) = params;
  final service = ref.watch(leaderboardServiceProvider);
  return service.comparePlayers(userId1, userId2);
});

// ========== Friend Providers ==========

/// Get user's friend list
final userFriendsProvider =
    FutureProvider.family<List<Friend>, String>((ref, userId) async {
  final service = ref.watch(friendServiceProvider);
  return service.getUserFriends(userId);
});

/// Get pending friend requests
final pendingFriendRequestsProvider =
    FutureProvider.family<List<FriendRequest>, String>((ref, userId) async {
  final service = ref.watch(friendServiceProvider);
  return service.getPendingRequests(userId);
});

/// Get activity feed
final activityFeedProvider =
    FutureProvider.family<List<FriendActivity>, (String, int)>(
        (ref, params) async {
  final (userId, limit) = params;
  final service = ref.watch(friendServiceProvider);
  return service.getActivityFeed(userId, limit: limit);
});

// ========== Challenge Providers ==========

/// Get pending challenges for user
final pendingChallengesProvider =
    FutureProvider.family<List<Challenge>, String>((ref, userId) async {
  final service = ref.watch(friendChallengeServiceProvider);
  return service.getPendingChallenges(userId);
});

/// Get active challenges for user
final activeChallengesProvider =
    FutureProvider.family<List<Challenge>, String>((ref, userId) async {
  final service = ref.watch(friendChallengeServiceProvider);
  return service.getActiveChallenges(userId);
});

/// Get challenge history
final challengeHistoryProvider =
    FutureProvider.family<List<Challenge>, (String, int)>((ref, params) async {
  final (userId, limit) = params;
  final service = ref.watch(friendChallengeServiceProvider);
  return service.getChallengeHistory(userId, limit: limit);
});

/// Get user's challenge streak
final userChallengeStreakProvider =
    FutureProvider.family<ChallengeStreak, String>((ref, userId) async {
  final service = ref.watch(friendChallengeServiceProvider);
  return service.getUserStreak(userId);
});

/// Get top challenge streaks
final topChallengeStreaksProvider =
    FutureProvider<List<ChallengeStreak>>((ref) async {
  final service = ref.watch(friendChallengeServiceProvider);
  return service.getTopStreaks();
});

/// Get head-to-head challenge stats
final headToHeadChallengeStatsProvider =
    FutureProvider.family<Map<String, int>, (String, String)>(
        (ref, params) async {
  final (userId1, userId2) = params;
  final service = ref.watch(friendChallengeServiceProvider);
  return service.getHeadToHeadStats(userId1, userId2);
});

// ========== Tournament Providers ==========

/// Get active tournaments
final activeTournamentsProvider = FutureProvider<List<Tournament>>((ref) async {
  final service = ref.watch(tournamentServiceProvider);
  return service.getActiveTournaments();
});

/// Get tournament details
final tournamentDetailsProvider =
    FutureProvider.family<Tournament, String>((ref, tournamentId) async {
  final service = ref.watch(tournamentServiceProvider);
  return service.getTournament(tournamentId);
});

/// Get tournament standings
final tournamentStandingsProvider =
    FutureProvider.family<TournamentStandings, String>(
        (ref, tournamentId) async {
  final service = ref.watch(tournamentServiceProvider);
  return service.getStandings(tournamentId);
});

/// Get tournament brackets
final tournamentBracketsProvider =
    FutureProvider.family<List<TournamentMatch>, String>(
        (ref, tournamentId) async {
  final service = ref.watch(tournamentServiceProvider);
  return service.getTournamentMatches(tournamentId);
});

/// Get tournament matches by round
final tournamentMatchesByRoundProvider =
    FutureProvider.family<List<TournamentMatch>, (String, int)>(
        (ref, params) async {
  final (tournamentId, round) = params;
  final service = ref.watch(tournamentServiceProvider);
  return service.getTournamentMatches(tournamentId, round: round);
});

/// Get user's tournament registrations (computed from active tournaments)
final userTournamentRegistrationsProvider =
    FutureProvider.family<List<TournamentParticipant>, String>(
        (ref, userId) async {
  // This would require additional queries; implemented as placeholder
  return [];
});

// ========== State Management Providers ==========

/// Selected leaderboard filter (global, regional, etc.)
final selectedLeaderboardFilterProvider =
    StateProvider<String>((ref) => 'global');

/// Selected leaderboard region
final selectedRegionProvider = StateProvider<String>((ref) => 'global');

/// Selected leaderboard time period
final selectedTimePeriodProvider = StateProvider<String>((ref) => 'all-time');

/// Friend search query
final friendSearchQueryProvider = StateProvider<String>((ref) => '');

/// Active tournament filter
final activeTournamentFilterProvider = StateProvider<String>((ref) => 'all');

/// Selected tournament for viewing
final selectedTournamentProvider = StateProvider<String?>((ref) => null);

// ========== Computed Providers ==========

/// Total friends count for user
final totalFriendsCountProvider =
    FutureProvider.family<int, String>((ref, userId) async {
  final friends = await ref.watch(userFriendsProvider(userId).future);
  return friends.length;
});

/// Pending friend requests count
final pendingRequestsCountProvider =
    FutureProvider.family<int, String>((ref, userId) async {
  final requests =
      await ref.watch(pendingFriendRequestsProvider(userId).future);
  return requests.length;
});

/// Active challenges count
final activeChallengesCountProvider =
    FutureProvider.family<int, String>((ref, userId) async {
  final challenges = await ref.watch(activeChallengesProvider(userId).future);
  return challenges.length;
});

/// Win rate for user
final userWinRateProvider =
    FutureProvider.family<double, String>((ref, userId) async {
  final streak = await ref.watch(userChallengeStreakProvider(userId).future);
  return streak.winRate;
});

/// User's social stats
final userSocialStatsProvider =
    FutureProvider.family<SocialStats, String>((ref, userId) async {
  final friends = await ref.watch(userFriendsProvider(userId).future);
  final requests =
      await ref.watch(pendingFriendRequestsProvider(userId).future);
  final challenges = await ref.watch(activeChallengesProvider(userId).future);
  final rank = await ref.watch(userGlobalRankProvider(userId).future);
  final stats = await ref.watch(userRankingStatsProvider(userId).future);

  return SocialStats(
    friendsCount: friends.length,
    pendingRequestsCount: requests.length,
    activeChallengesCount: challenges.length,
    globalRank: rank,
    currentRating: stats.currentRating,
    winRate:
        stats.currentRating > 0 ? (stats.totalGamesPlayed > 0 ? 0.5 : 0) : 0,
  );
});

// ========== Notifiers for State Management ==========

/// Notifier for managing leaderboard filter
class LeaderboardFilterNotifier extends StateNotifier<String> {
  LeaderboardFilterNotifier() : super('global');

  void setFilter(String filter) {
    state = filter;
  }
}

/// Notifier for managing tournament selection
class SelectedTournamentNotifier extends StateNotifier<String?> {
  SelectedTournamentNotifier() : super(null);

  void selectTournament(String tournamentId) {
    state = tournamentId;
  }

  void clearSelection() {
    state = null;
  }
}

// ========== Helper Classes ==========

/// User's social statistics
class SocialStats {
  SocialStats({
    required this.friendsCount,
    required this.pendingRequestsCount,
    required this.activeChallengesCount,
    required this.globalRank,
    required this.currentRating,
    required this.winRate,
  });
  final int friendsCount;
  final int pendingRequestsCount;
  final int activeChallengesCount;
  final int globalRank;
  final int currentRating;
  final double winRate;
}
