import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/match_history_service.dart';
import '../models/match_record.dart';

/// Provider for match history service
final matchHistoryServiceProvider = Provider((ref) => MatchHistoryService());

/// State class for match history with pagination
class MatchHistoryState {
  MatchHistoryState({
    required this.matches,
    this.isLoading = false,
    this.error,
    this.lastDocument,
    this.hasMore = true,
  });
  final List<MatchRecord> matches;
  final bool isLoading;
  final String? error;
  final DocumentSnapshot? lastDocument; // For pagination
  final bool hasMore;

  MatchHistoryState copyWith({
    List<MatchRecord>? matches,
    bool? isLoading,
    String? error,
    DocumentSnapshot? lastDocument,
    bool? hasMore,
  }) =>
      MatchHistoryState(
        matches: matches ?? this.matches,
        isLoading: isLoading ?? this.isLoading,
        error: error,
        lastDocument: lastDocument ?? this.lastDocument,
        hasMore: hasMore ?? this.hasMore,
      );
}

/// State notifier for match history with pagination
class MatchHistoryNotifier
    extends StateNotifier<AsyncValue<MatchHistoryState>> {
  MatchHistoryNotifier(this._service) : super(const AsyncValue.loading());
  final MatchHistoryService _service;

  /// Load initial match history
  Future<void> loadHistory(String playerId) async {
    state = const AsyncValue.loading();

    try {
      final matches = await _service.getMatchHistory(playerId);
      state = AsyncValue.data(
        MatchHistoryState(
          matches: matches,
          isLoading: false,
          hasMore: matches.length >= 50, // Assuming 50 per page
        ),
      );
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  /// Load more matches (pagination)
  Future<void> loadMore(String playerId) async {
    final currentState = state.whenData((data) => data);

    if (currentState.value?.hasMore != true) return;

    try {
      final moreMatches = await _service.getMatchHistory(
        playerId,
        startAfter: currentState.value?.lastDocument,
      );

      if (moreMatches.isEmpty) {
        // No more matches
        state = AsyncValue.data(
          currentState.value!.copyWith(hasMore: false),
        );
      } else {
        // Add new matches
        final allMatches = [
          ...currentState.value!.matches,
          ...moreMatches,
        ];

        state = AsyncValue.data(
          currentState.value!.copyWith(
            matches: allMatches,
            hasMore: moreMatches.length >= 50,
          ),
        );
      }
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  /// Filter matches by criteria
  Future<void> filterMatches({
    required String playerId,
    DateTime? fromDate,
    DateTime? toDate,
    String? opponentId,
    String? result,
    String? timeControl,
  }) async {
    state = const AsyncValue.loading();

    try {
      final filtered = await _service.filterMatches(
        playerId,
        fromDate: fromDate,
        toDate: toDate,
        opponentId: opponentId,
        result: result,
        timeControl: timeControl,
      );

      state = AsyncValue.data(
        MatchHistoryState(
          matches: filtered,
          isLoading: false,
          hasMore: false, // Filtered results are not paginated
        ),
      );
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  /// Reset filters and reload
  Future<void> resetFilters(String playerId) async {
    await loadHistory(playerId);
  }
}

/// Match history provider with pagination support
final matchHistoryProvider =
    StateNotifierProvider<MatchHistoryNotifier, AsyncValue<MatchHistoryState>>(
  (ref) => MatchHistoryNotifier(ref.watch(matchHistoryServiceProvider)),
);

/// Provider to watch match history stream
final watchMatchHistoryProvider =
    StreamProvider.family<List<MatchRecord>, String>(
  (ref, playerId) {
    final service = ref.watch(matchHistoryServiceProvider);
    return service.watchMatchHistory(playerId);
  },
);

/// Provider for total games played
final totalGamesPlayedProvider = FutureProvider.family<int, String>(
  (ref, playerId) {
    final service = ref.watch(matchHistoryServiceProvider);
    return service.getTotalGamesPlayed(playerId);
  },
);

/// Provider for win rate
final matchHistoryWinRateProvider = FutureProvider.family<double, String>(
  (ref, playerId) {
    final service = ref.watch(matchHistoryServiceProvider);
    return service.getWinRate(playerId);
  },
);
