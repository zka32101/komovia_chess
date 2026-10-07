import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/player_connection_service.dart';
import '../services/leaderboard_service.dart';
import '../services/achievement_service.dart';
import '../models/phase_k_models.dart' hide FriendRequest;

/// Phase T - Social & Community Features Providers
/// Provides reactive access to social connections, leaderboards, and achievements

// Service Providers

final playerConnectionServiceProvider = Provider<PlayerConnectionService>(
    (ref) => PlayerConnectionService(firestore: FirebaseFirestore.instance));

final leaderboardServiceProvider =
    Provider<LeaderboardService>((ref) => LeaderboardService());

final achievementServiceProvider =
    Provider<AchievementService>((ref) => AchievementService());

// Connection Providers

/// Get player's friend list
final playerFriendsProvider =
    FutureProvider.family<List<PlayerConnection>, String>((ref, playerId) {
  final service = ref.watch(playerConnectionServiceProvider);
  return service.getFriendsList(playerId);
});

/// Get pending friend requests (incoming)
final pendingFriendRequestsProvider =
    FutureProvider.family<List<FriendRequest>, String>((ref, playerId) {
  final service = ref.watch(playerConnectionServiceProvider);
  return service.getPendingRequests(playerId);
});

/// Get sent friend requests (outgoing)
final sentFriendRequestsProvider =
    FutureProvider.family<List<FriendRequest>, String>((ref, playerId) {
  final service = ref.watch(playerConnectionServiceProvider);
  return service.getSentRequests(playerId);
});

/// Check friendship status between two players
final friendshipStatusProvider = FutureProvider.family<
    FriendshipStatus,
    ({
      String playerId,
      String otherPlayerId,
    })>((ref, params) {
  final service = ref.watch(playerConnectionServiceProvider);
  return service.isPlayerFriend(params.playerId, params.otherPlayerId);
});

// Leaderboard Providers

/// Get global leaderboard
final globalLeaderboardProvider = FutureProvider.family<
    List<LeaderboardEntry>,
    ({
      int limit,
      int offset,
    })>((ref, params) {
  final service = ref.watch(leaderboardServiceProvider);
  return service.getGlobalLeaderboard(
    limit: params.limit,
    offset: params.offset,
  );
});

/// Get regional leaderboard
final regionalLeaderboardProvider =
    FutureProvider.family<List<LeaderboardEntry>, String>((ref, region) {
  final service = ref.watch(leaderboardServiceProvider);
  return service.getRegionalLeaderboard(region);
});

/// Get player's leaderboard rank
final playerLeaderboardRankProvider =
    FutureProvider.family<int, String>((ref, playerId) {
  final service = ref.watch(leaderboardServiceProvider);
  return service.getUserGlobalRank(playerId);
});

/// Get player's percentile rank
final playerPercentileProvider =
    FutureProvider.family<int, String>((ref, playerId) {
  final service = ref.watch(leaderboardServiceProvider);
  return service.getUserPercentile(playerId);
});

/// Get time-based leaderboard (daily, weekly, monthly)
final timeBasedLeaderboardProvider =
    FutureProvider.family<List<LeaderboardEntry>, String>((ref, period) {
  final service = ref.watch(leaderboardServiceProvider);
  return service.getTimeBasedLeaderboard(period);
});

/// Search leaderboard by username
final leaderboardSearchProvider =
    FutureProvider.family<List<LeaderboardEntry>, String>((ref, query) {
  final service = ref.watch(leaderboardServiceProvider);
  return service.searchByUsername(query);
});

// Achievement Providers

/// Get all available achievements
final allAchievementsProvider =
    FutureProvider<List<AchievementDefinition>>((ref) {
  final service = ref.watch(achievementServiceProvider);
  return service.getAllAchievements();
});

/// Get player's earned achievements
final playerAchievementsProvider =
    FutureProvider.family<List<UserAchievement>, String>((ref, playerId) {
  final service = ref.watch(achievementServiceProvider);
  return service.getUserAchievements(playerId);
});

/// Check progress toward achievement
final achievementProgressProvider = FutureProvider.family<
    AchievementProgress,
    ({
      String playerId,
      String achievementId,
    })>((ref, params) {
  final service = ref.watch(achievementServiceProvider);
  return service.getAchievementProgress(params.playerId, params.achievementId);
});

/// Get nearby achievements (close to completion)
final nearbyAchievementsProvider =
    FutureProvider.family<List<NearbyAchievement>, String>((ref, playerId) {
  final service = ref.watch(achievementServiceProvider);
  return service.getNearbyAchievements(playerId);
});

// State Management Providers

/// State notifier for friend request operations
final friendRequestNotifierProvider =
    StateNotifierProvider<FriendRequestNotifier, FriendRequestState>((ref) {
  final service = ref.watch(playerConnectionServiceProvider);
  return FriendRequestNotifier(service);
});

/// State notifier for achievement unlocks
final achievementUnlockNotifierProvider =
    StateNotifierProvider<AchievementUnlockNotifier, AchievementUnlockState>(
        (ref) {
  final service = ref.watch(achievementServiceProvider);
  return AchievementUnlockNotifier(service);
});

// Notifier Implementations

class FriendRequestNotifier extends StateNotifier<FriendRequestState> {
  FriendRequestNotifier(this._service) : super(const FriendRequestState());
  final PlayerConnectionService _service;

  Future<void> sendFriendRequest({
    required String fromPlayerId,
    required String toPlayerId,
  }) async {
    state = state.copyWith(isLoading: true);

    try {
      await _service.sendFriendRequest(
        fromPlayerId: fromPlayerId,
        toPlayerId: toPlayerId,
      );

      state = state.copyWith(
        isLoading: false,
        lastAction: 'request_sent',
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> acceptFriendRequest({
    required String playerId,
    required String requestId,
  }) async {
    state = state.copyWith(isLoading: true);

    try {
      await _service.acceptFriendRequest(
        playerId: playerId,
        requestId: requestId,
      );

      state = state.copyWith(
        isLoading: false,
        lastAction: 'request_accepted',
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> declineFriendRequest({
    required String playerId,
    required String requestId,
  }) async {
    state = state.copyWith(isLoading: true);

    try {
      await _service.declineFriendRequest(
        playerId: playerId,
        requestId: requestId,
      );

      state = state.copyWith(
        isLoading: false,
        lastAction: 'request_declined',
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> removeFriend({
    required String playerId,
    required String friendId,
  }) async {
    state = state.copyWith(isLoading: true);

    try {
      await _service.removeFriend(
        playerId: playerId,
        friendId: friendId,
      );

      state = state.copyWith(
        isLoading: false,
        lastAction: 'friend_removed',
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }
}

class AchievementUnlockNotifier extends StateNotifier<AchievementUnlockState> {
  AchievementUnlockNotifier(this._service)
      : super(const AchievementUnlockState());
  final AchievementService _service;

  Future<void> unlockAchievement({
    required String playerId,
    required String achievementId,
  }) async {
    state = state.copyWith(isLoading: true);

    try {
      await _service.unlockAchievement(
        playerId,
        achievementId,
      );

      state = state.copyWith(
        isLoading: false,
        lastUnlockedId: achievementId,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }
}

// State Classes

class FriendRequestState {
  const FriendRequestState({
    this.isLoading = false,
    this.lastAction,
    this.error,
  });
  final bool isLoading;
  final String? lastAction;
  final String? error;

  FriendRequestState copyWith({
    bool? isLoading,
    String? lastAction,
    String? error,
  }) =>
      FriendRequestState(
        isLoading: isLoading ?? this.isLoading,
        lastAction: lastAction ?? this.lastAction,
        error: error ?? this.error,
      );
}

class AchievementUnlockState {
  const AchievementUnlockState({
    this.isLoading = false,
    this.lastUnlockedId,
    this.error,
  });
  final bool isLoading;
  final String? lastUnlockedId;
  final String? error;

  AchievementUnlockState copyWith({
    bool? isLoading,
    String? lastUnlockedId,
    String? error,
  }) =>
      AchievementUnlockState(
        isLoading: isLoading ?? this.isLoading,
        lastUnlockedId: lastUnlockedId ?? this.lastUnlockedId,
        error: error ?? this.error,
      );
}
