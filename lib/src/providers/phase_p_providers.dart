import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/realtime_sync_service.dart';
import '../services/advanced_timeout_service.dart';
import '../services/enhanced_rating_system.dart';
import '../services/optimized_matchmaking_service.dart';

// ============================================================================
// Service Providers
// ============================================================================

/// Real-time synchronization service provider
final realtimeSyncServiceProvider =
    Provider<RealtimeSyncService>((ref) => RealtimeSyncService());

/// Advanced timeout service provider
final advancedTimeoutServiceProvider =
    Provider<AdvancedTimeoutService>((ref) => AdvancedTimeoutService());

/// Enhanced rating system provider
final enhancedRatingSystemProvider =
    Provider<EnhancedRatingSystem>((ref) => EnhancedRatingSystem());

/// Optimized matchmaking service provider
final optimizedMatchmakingServiceProvider =
    Provider<OptimizedMatchmakingService>(
        (ref) => OptimizedMatchmakingService());

// ============================================================================
// Game Synchronization Providers
// ============================================================================

/// Watch real-time sync state for a game
final gameSyncStateProvider =
    StreamProvider.family<GameSyncState, String>((ref, gameId) {
  final service = ref.watch(realtimeSyncServiceProvider);
  return service.watchSyncState(gameId);
});

/// Get pending moves for a game
final pendingMovesProvider =
    FutureProvider.family<List<MoveSync>, String>((ref, gameId) async {
  final service = ref.watch(realtimeSyncServiceProvider);
  return service.getPendingMoves(gameId);
});

/// Provider for game sync progress
final gameSyncProgressProvider =
    FutureProvider.family<double, String>((ref, gameId) async {
  final syncState = ref.watch(gameSyncStateProvider(gameId));
  return syncState.whenData((state) => state.syncProgress).value ?? 0.0;
});

// ============================================================================
// Timeout Management Providers
// ============================================================================

/// Get current timeout status for a game
final timeoutStatusProvider =
    FutureProvider.family<TimeoutStatus, String>((ref, gameId) async {
  final service = ref.watch(advancedTimeoutServiceProvider);
  return service.getTimeoutStatus(gameId);
});

/// Get time control for a game
final timeControlProvider =
    FutureProvider.family<TimeControl, String>((ref, gameId) async {
  final service = ref.watch(advancedTimeoutServiceProvider);
  return service.getTimeControl(gameId);
});

// ============================================================================
// Rating System Providers
// ============================================================================

/// Get player's rating statistics
final playerRatingStatsProvider =
    FutureProvider.family<RatingStats, String>((ref, playerId) async {
  final service = ref.watch(enhancedRatingSystemProvider);
  return service.getRatingStats(playerId);
});

/// Get player's rating history
final playerRatingHistoryProvider =
    FutureProvider.family<List<RatingHistoryEntry>, String>(
        (ref, playerId) async {
  final service = ref.watch(enhancedRatingSystemProvider);
  return service.getRatingHistory(playerId, limit: 50);
});

/// Calculate rating change for a game result
final ratingChangeCalculatorProvider =
    FutureProvider.family<RatingChangeResult, RatingCalculationParams>(
        (ref, params) async {
  final service = ref.watch(enhancedRatingSystemProvider);
  return service.calculateRatingChange(
    whitePlayerId: params.whitePlayerId,
    blackPlayerId: params.blackPlayerId,
    whiteCurrentRating: params.whiteCurrentRating,
    blackCurrentRating: params.blackCurrentRating,
    result: params.result,
    timeControl: params.timeControl,
    timeControlMs: params.timeControlMs,
  );
});

// ============================================================================
// Matchmaking Providers
// ============================================================================

/// Matchmaking queue entry notifier
class MatchmakingQueueNotifier
    extends StateNotifier<AsyncValue<MatchmakingQueue?>> {
  MatchmakingQueueNotifier(this._service) : super(const AsyncValue.data(null));
  final OptimizedMatchmakingService _service;

  Future<void> enqueuePlayer({
    required String playerId,
    required String playerName,
    required int rating,
    required String timeControl,
    bool isProvisional = false,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _service.enqueuePlayer(
          playerId: playerId,
          playerName: playerName,
          rating: rating,
          timeControl: timeControl,
          isProvisional: isProvisional,
        ));
  }

  Future<void> removeFromQueue(String queueId) async {
    await _service.removeFromQueue(queueId);
    state = const AsyncValue.data(null);
  }
}

/// Matchmaking queue state provider
final matchmakingQueueProvider = StateNotifierProvider<MatchmakingQueueNotifier,
    AsyncValue<MatchmakingQueue?>>((ref) {
  final service = ref.watch(optimizedMatchmakingServiceProvider);
  return MatchmakingQueueNotifier(service);
});

/// Get matchmaking statistics for a time control
final matchmakingStatsProvider =
    FutureProvider.family<MatchmakingStats, String>((ref, timeControl) async {
  final service = ref.watch(optimizedMatchmakingServiceProvider);
  return service.getMatchmakingStats(timeControl);
});

/// Find match for queued player
final matchFindingProvider =
    FutureProvider.family<MatchResult?, String>((ref, queueId) async {
  final service = ref.watch(optimizedMatchmakingServiceProvider);
  return service.findMatch(queueId);
});

// ============================================================================
// State Management Notifiers
// ============================================================================

/// Notifier for timeout operations
class TimeoutOperationNotifier extends StateNotifier<AsyncValue<void>> {
  TimeoutOperationNotifier(this._service) : super(const AsyncValue.data(null));
  final AdvancedTimeoutService _service;
  RealtimeTimeoutManager? _currentManager;

  Future<void> startTimeoutMonitoring({
    required String gameId,
    required int initialWhiteTimeMs,
    required int initialBlackTimeMs,
    required VoidCallback onWhiteTimeout,
    required VoidCallback onBlackTimeout,
    required VoidCallback onInactivityDetected,
  }) async {
    _currentManager = _service.startTimeoutMonitoring(
      gameId: gameId,
      initialWhiteTimeMs: initialWhiteTimeMs,
      initialBlackTimeMs: initialBlackTimeMs,
      onWhiteTimeout: onWhiteTimeout,
      onBlackTimeout: onBlackTimeout,
      onInactivityDetected: onInactivityDetected,
    );
  }

  void stopTimeoutMonitoring() {
    _service.stopTimeoutMonitoring();
    _currentManager = null;
  }

  void updateTimeRemaining(int whiteMs, int blackMs) {
    _currentManager?.updateTimeRemaining(whiteMs, blackMs);
  }
}

/// Timeout operation provider
final timeoutOperationProvider =
    StateNotifierProvider<TimeoutOperationNotifier, AsyncValue<void>>((ref) {
  final service = ref.watch(advancedTimeoutServiceProvider);
  return TimeoutOperationNotifier(service);
});

/// Notifier for rating operations
class RatingOperationNotifier extends StateNotifier<AsyncValue<void>> {
  RatingOperationNotifier(this._service) : super(const AsyncValue.data(null));
  final EnhancedRatingSystem _service;

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
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _service.recordRatingChange(
          playerId: playerId,
          previousRating: previousRating,
          newRating: newRating,
          ratingChange: ratingChange,
          opponentId: opponentId,
          gameId: gameId,
          result: result,
          timeControl: timeControl,
        ));
  }
}

/// Rating operation provider
final ratingOperationProvider =
    StateNotifierProvider<RatingOperationNotifier, AsyncValue<void>>((ref) {
  final service = ref.watch(enhancedRatingSystemProvider);
  return RatingOperationNotifier(service);
});

// ============================================================================
// Data Classes for Provider Parameters
// ============================================================================

/// Parameters for rating change calculation
class RatingCalculationParams {
  RatingCalculationParams({
    required this.whitePlayerId,
    required this.blackPlayerId,
    required this.whiteCurrentRating,
    required this.blackCurrentRating,
    required this.result,
    required this.timeControl,
    this.timeControlMs,
  });
  final String whitePlayerId;
  final String blackPlayerId;
  final int whiteCurrentRating;
  final int blackCurrentRating;
  final String result;
  final String timeControl;
  final int? timeControlMs;
}

typedef VoidCallback = void Function();
