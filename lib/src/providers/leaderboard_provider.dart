import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/ranking_service.dart';

export '../services/ranking_service.dart'
    show RankingService, RankingEntry, RankingStats;

/// Leaderboard filter type
enum LeaderboardFilter {
  global, // Global rankings by ELO
  byShogi, // Filtered by shogi rank
  monthly, // Monthly rankings
}

/// Leaderboard view state
class LeaderboardState {
  LeaderboardState({
    required this.entries,
    this.stats,
    this.isLoading = false,
    this.error,
    this.currentPage = 0,
    this.filter = LeaderboardFilter.global,
    this.shogiRankFilter,
    this.monthKeyFilter,
    this.lastRefreshed,
  });
  final List<RankingEntry> entries;
  final RankingStats? stats;
  final bool isLoading;
  final String? error;
  final int currentPage;
  final LeaderboardFilter filter;
  final String?
      shogiRankFilter; // Used when filter == LeaderboardFilter.byShogi
  final String? monthKeyFilter; // Used when filter == LeaderboardFilter.monthly
  final DateTime? lastRefreshed;

  LeaderboardState copyWith({
    List<RankingEntry>? entries,
    RankingStats? stats,
    bool? isLoading,
    String? error,
    int? currentPage,
    LeaderboardFilter? filter,
    String? shogiRankFilter,
    String? monthKeyFilter,
    DateTime? lastRefreshed,
  }) =>
      LeaderboardState(
        entries: entries ?? this.entries,
        stats: stats ?? this.stats,
        isLoading: isLoading ?? this.isLoading,
        error: error,
        currentPage: currentPage ?? this.currentPage,
        filter: filter ?? this.filter,
        shogiRankFilter: shogiRankFilter ?? this.shogiRankFilter,
        monthKeyFilter: monthKeyFilter ?? this.monthKeyFilter,
        lastRefreshed: lastRefreshed ?? this.lastRefreshed,
      );
}

/// Leaderboard notifier for managing state
class LeaderboardNotifier extends StateNotifier<LeaderboardState> {
  LeaderboardNotifier(this.rankingService)
      : super(LeaderboardState(entries: [])) {
    _initialize();
  }
  final RankingService rankingService;

  Future<void> _initialize() async {
    await loadGlobalRanking();
  }

  /// Load global rankings
  Future<void> loadGlobalRanking({int page = 0}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      const pageSize = 50;
      final offset = page * pageSize;

      final entries = await rankingService.getGlobalRanking(
        limit: pageSize,
        offset: offset,
      );

      final stats = await rankingService.getRankingStats();

      state = state.copyWith(
        entries: entries,
        stats: stats,
        isLoading: false,
        currentPage: page,
        filter: LeaderboardFilter.global,
        lastRefreshed: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load rankings: $e',
      );
    }
  }

  /// Load rankings by shogi rank
  Future<void> loadRankingByShogi(String shogiRank, {int page = 0}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      const pageSize = 50;

      final entries = await rankingService.getRankingByShogi(
        shogiRank,
        limit: pageSize * (page + 1),
      );

      final stats = await rankingService.getRankingStats();

      state = state.copyWith(
        entries: entries,
        stats: stats,
        isLoading: false,
        currentPage: page,
        filter: LeaderboardFilter.byShogi,
        shogiRankFilter: shogiRank,
        lastRefreshed: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load shogi rankings: $e',
      );
    }
  }

  /// Load monthly rankings
  Future<void> loadMonthlyRanking({String? monthKey, int page = 0}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      const pageSize = 50;

      final entries = await rankingService.getMonthlyRanking(
        limit: pageSize * (page + 1),
        monthKey: monthKey,
      );

      final stats = await rankingService.getRankingStats();

      state = state.copyWith(
        entries: entries,
        stats: stats,
        isLoading: false,
        currentPage: page,
        filter: LeaderboardFilter.monthly,
        monthKeyFilter: monthKey,
        lastRefreshed: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load monthly rankings: $e',
      );
    }
  }

  /// Next page of rankings
  Future<void> nextPage() async {
    final nextPage = state.currentPage + 1;
    switch (state.filter) {
      case LeaderboardFilter.global:
        await loadGlobalRanking(page: nextPage);
        break;
      case LeaderboardFilter.byShogi:
        if (state.shogiRankFilter != null) {
          await loadRankingByShogi(state.shogiRankFilter!, page: nextPage);
        }
        break;
      case LeaderboardFilter.monthly:
        await loadMonthlyRanking(
            monthKey: state.monthKeyFilter, page: nextPage);
        break;
    }
  }

  /// Previous page of rankings
  Future<void> previousPage() async {
    if (state.currentPage > 0) {
      final prevPage = state.currentPage - 1;
      switch (state.filter) {
        case LeaderboardFilter.global:
          await loadGlobalRanking(page: prevPage);
          break;
        case LeaderboardFilter.byShogi:
          if (state.shogiRankFilter != null) {
            await loadRankingByShogi(state.shogiRankFilter!, page: prevPage);
          }
          break;
        case LeaderboardFilter.monthly:
          await loadMonthlyRanking(
              monthKey: state.monthKeyFilter, page: prevPage);
          break;
      }
    }
  }

  /// Refresh current rankings
  Future<void> refresh() async {
    final currentFilter = state.filter;
    switch (currentFilter) {
      case LeaderboardFilter.global:
        await loadGlobalRanking(page: 0);
        break;
      case LeaderboardFilter.byShogi:
        if (state.shogiRankFilter != null) {
          await loadRankingByShogi(state.shogiRankFilter!, page: 0);
        }
        break;
      case LeaderboardFilter.monthly:
        await loadMonthlyRanking(monthKey: state.monthKeyFilter, page: 0);
        break;
    }
  }
}

/// User rank notifier for tracking individual user rank
class UserRankNotifier extends StateNotifier<AsyncValue<int?>> {
  UserRankNotifier(this.rankingService, this.uid)
      : super(const AsyncValue.loading()) {
    _initialize();
  }
  final RankingService rankingService;
  final String uid;

  Future<void> _initialize() async {
    await loadUserRank();
  }

  Future<void> loadUserRank() async {
    state = const AsyncValue.loading();
    try {
      final rank = await rankingService.getUserRank(uid);
      state = AsyncValue.data(rank);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async {
    await loadUserRank();
  }
}

/// Nearby rankings notifier
class NearbyRankingsNotifier
    extends StateNotifier<AsyncValue<List<RankingEntry>>> {
  NearbyRankingsNotifier(this.rankingService, this.uid)
      : super(const AsyncValue.loading()) {
    _initialize();
  }
  final RankingService rankingService;
  final String uid;

  Future<void> _initialize() async {
    await loadNearbyRankings();
  }

  Future<void> loadNearbyRankings() async {
    state = const AsyncValue.loading();
    try {
      final rankings = await rankingService.getNearbyRankings(
        uid,
        proximityCount: 5,
      );
      state = AsyncValue.data(rankings);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async {
    await loadNearbyRankings();
  }
}

/// RankingService provider
final rankingServiceProvider = Provider((ref) => RankingService());

/// Main leaderboard provider
final leaderboardProvider =
    StateNotifierProvider<LeaderboardNotifier, LeaderboardState>((ref) {
  final rankingService = ref.watch(rankingServiceProvider);
  return LeaderboardNotifier(rankingService);
});

/// Global ranking stream provider (real-time)
final globalRankingStreamProvider = StreamProvider<List<RankingEntry>>((ref) {
  final rankingService = ref.watch(rankingServiceProvider);
  return rankingService.watchGlobalRanking(limit: 100);
});

/// User rank provider (with auto-refresh)
final userRankProvider =
    StateNotifierProvider.family<UserRankNotifier, AsyncValue<int?>, String>(
        (ref, uid) {
  final rankingService = ref.watch(rankingServiceProvider);
  return UserRankNotifier(rankingService, uid);
});

/// Nearby rankings provider
final nearbyRankingsProvider = StateNotifierProvider.family<
    NearbyRankingsNotifier, AsyncValue<List<RankingEntry>>, String>((ref, uid) {
  final rankingService = ref.watch(rankingServiceProvider);
  return NearbyRankingsNotifier(rankingService, uid);
});

/// Watch user's own ranking (real-time)
final watchUserRankingProvider =
    StreamProvider.family<RankingEntry?, String>((ref, uid) {
  final rankingService = ref.watch(rankingServiceProvider);
  return rankingService.watchUserRanking(uid);
});

/// Ranking stats provider
final rankingStatsProvider = FutureProvider<RankingStats?>((ref) async {
  final rankingService = ref.watch(rankingServiceProvider);
  return rankingService.getRankingStats();
});
