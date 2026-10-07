import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/phase_k_models.dart';
import '../utils/query_cache.dart';
import '../utils/pagination_helper.dart';

class LeaderboardServiceOptimized {
  factory LeaderboardServiceOptimized() => _instance;
  LeaderboardServiceOptimized._internal() {
    _leaderboardCache = SmartCache(
      fetcher: (_) => Future.value([]),
      cacheTtl: const Duration(minutes: 5),
    );
    _rankingStatsCache = SmartCache(
      fetcher: (_) => Future.value(
        RankingStats(
          userId: '',
          currentRating: 1200,
          peakRating: 1200,
          peakDate: DateTime.now(),
          rank: -1,
          percentile: 0,
          totalGamesPlayed: 0,
          ratingByTimeControl: {},
        ),
      ),
      cacheTtl: const Duration(minutes: 10),
    );
    _h2hCache = MonitoredCache(cacheTtl: const Duration(hours: 1));
    _cacheStats = CacheStats();
  }
  static final LeaderboardServiceOptimized _instance =
      LeaderboardServiceOptimized._internal();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late final SmartCache<String, List<LeaderboardEntry>> _leaderboardCache;
  late final SmartCache<String, RankingStats> _rankingStatsCache;
  late final MonitoredCache<String, Map<String, int>> _h2hCache;
  late final CacheStats _cacheStats;

  static LeaderboardServiceOptimized get instance => _instance;

  /// Get global leaderboard with optimized pagination
  Future<PaginatedResult<LeaderboardEntry>> getGlobalLeaderboardPaginated({
    int pageSize = 20,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      final params = PaginationParams(
        pageSize: pageSize,
        startAfter: startAfter,
      );

      var query = _firestore
          .collection('leaderboards')
          .doc('global')
          .collection('entries')
          .orderBy('rating', descending: true)
          .orderBy('wins', descending: true);

      query = QueryOptimizer.applyPagination(
        query,
        params,
      );

      return await QueryOptimizer.executePaginatedQuery(
        query,
        params,
        LeaderboardEntry.fromJson,
      );
    } catch (e) {
      debugPrint('Error fetching paginated global leaderboard: $e');
      return PaginatedResult.empty();
    }
  }

  /// Get regional leaderboard with pagination
  Future<PaginatedResult<LeaderboardEntry>> getRegionalLeaderboardPaginated(
    String region, {
    int pageSize = 20,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      final params = PaginationParams(
        pageSize: pageSize,
        startAfter: startAfter,
      );

      var query = _firestore
          .collection('leaderboards')
          .doc('regional')
          .collection(region)
          .orderBy('rating', descending: true);

      query = QueryOptimizer.applyPagination(
        query,
        params,
      );

      return await QueryOptimizer.executePaginatedQuery(
        query,
        params,
        LeaderboardEntry.fromJson,
      );
    } catch (e) {
      debugPrint('Error fetching paginated regional leaderboard: $e');
      return PaginatedResult.empty();
    }
  }

  /// Get ranking statistics with smart caching
  Future<RankingStats> getRankingStatsOptimized(String userId) async =>
      _rankingStatsCache.get(userId);

  /// Get head-to-head stats with monitored caching
  Future<Map<String, int>> getHeadToHeadStatsOptimized(
    String userId1,
    String userId2,
  ) async {
    final cacheKey = '$userId1:$userId2';
    final cached = _h2hCache.get(cacheKey);

    if (cached != null) {
      _cacheStats.hits++;
      return cached;
    }

    _cacheStats.misses++;

    try {
      final stats = await _getHeadToHeadStats(userId1, userId2);
      _h2hCache.set(cacheKey, stats);
      return stats;
    } catch (e) {
      debugPrint('Error fetching head-to-head stats: $e');
      return {'wins1': 0, 'wins2': 0, 'draws': 0};
    }
  }

  /// Batch query multiple users' ranking stats
  Future<List<RankingStats>> getRankingStatsBatch(List<String> userIds) async {
    try {
      final queryChunks = BatchQueryHelper.chunk(userIds, 10);
      final results = <RankingStats>[];

      for (final chunk in queryChunks) {
        final query = _firestore
            .collection('ranking_stats')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();

        final snapshot = await query;
        results.addAll(
          snapshot.docs.map((doc) => RankingStats.fromJson(doc.data())),
        );
      }

      return results;
    } catch (e) {
      debugPrint('Error fetching batch ranking stats: $e');
      return [];
    }
  }

  /// Get multiple leaderboards efficiently
  Future<Map<String, List<LeaderboardEntry>>> getMultipleLeaderboards({
    List<String> regions = const [],
    int limit = 20,
  }) async {
    try {
      final queries = <Future<List<LeaderboardEntry>>>[];

      for (final region in regions) {
        queries.add(
          _firestore
              .collection('leaderboards')
              .doc('regional')
              .collection(region)
              .orderBy('rating', descending: true)
              .limit(limit)
              .get()
              .then((snapshot) => snapshot.docs
                  .map((doc) => LeaderboardEntry.fromJson(doc.data()))
                  .toList()),
        );
      }

      final results = await Future.wait(queries);
      final resultMap = <String, List<LeaderboardEntry>>{};

      for (int i = 0; i < regions.length; i++) {
        resultMap[regions[i]] = results[i];
      }

      return resultMap;
    } catch (e) {
      debugPrint('Error fetching multiple leaderboards: $e');
      return {};
    }
  }

  /// Internal head-to-head calculation
  Future<Map<String, int>> _getHeadToHeadStats(
    String userId1,
    String userId2,
  ) async {
    try {
      final snapshot = await _firestore
          .collectionGroup('games')
          .where('participants', arrayContains: userId1)
          .get();

      int wins1 = 0;
      int wins2 = 0;
      int draws = 0;

      for (final doc in snapshot.docs) {
        if (doc['participants'].contains(userId2)) {
          if (doc['winnerId'] == userId1) {
            wins1++;
          } else if (doc['winnerId'] == userId2) {
            wins2++;
          } else if (doc['isDraw'] == true) {
            draws++;
          }
        }
      }

      return {'wins1': wins1, 'wins2': wins2, 'draws': draws};
    } catch (e) {
      debugPrint('Error calculating head-to-head: $e');
      return {'wins1': 0, 'wins2': 0, 'draws': 0};
    }
  }

  /// Get cache statistics
  CacheStats get cacheStats => _cacheStats;

  /// Clear all caches
  void clearCache() {
    _leaderboardCache.invalidateAll();
    _rankingStatsCache.invalidateAll();
    _h2hCache.clear();
    _cacheStats.reset();
  }

  /// Invalidate specific user's cache
  void invalidateUserCache(String userId) {
    _rankingStatsCache.invalidate(userId);
    _h2hCache.removeWhere((key) => key.contains(userId));
  }
}
