import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/phase_k_models.dart';
import '../utils/query_cache.dart';
import '../utils/pagination_helper.dart';

class FriendChallengeServiceOptimized {
  factory FriendChallengeServiceOptimized() => _instance;
  FriendChallengeServiceOptimized._internal() {
    _challengesCache = SmartCache(
      fetcher: (_) => Future.value([]),
      cacheTtl: const Duration(minutes: 2),
    );
    _streakCache = SmartCache(
      fetcher: _getUserStreakFromDb,
      cacheTtl: const Duration(minutes: 10),
    );
    _h2hChallengeCache = MonitoredCache(
      cacheTtl: const Duration(hours: 1),
    );
    _topStreaksCache = SmartCache(
      fetcher: (_) => _getTopStreaksFromDb(),
      cacheTtl: const Duration(minutes: 15),
    );
  }
  static final FriendChallengeServiceOptimized _instance =
      FriendChallengeServiceOptimized._internal();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late final SmartCache<String, List<Challenge>> _challengesCache;
  late final SmartCache<String, ChallengeStreak> _streakCache;
  late final MonitoredCache<String, Map<String, int>> _h2hChallengeCache;
  late final SmartCache<String, List<ChallengeStreak>> _topStreaksCache;

  static FriendChallengeServiceOptimized get instance => _instance;

  /// Get pending challenges with pagination
  Future<PaginatedResult<Challenge>> getPendingChallengesPaginated(
    String userId, {
    int pageSize = 20,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      final params = PaginationParams(
        pageSize: pageSize,
        startAfter: startAfter,
      );

      var query = _firestore
          .collection('friend_challenges')
          .doc('active')
          .collection('list')
          .where('challengeeUserId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true);

      query = QueryOptimizer.applyPagination(
        query,
        params,
      );

      return await QueryOptimizer.executePaginatedQuery(
        query,
        params,
        Challenge.fromJson,
      );
    } catch (e) {
      debugPrint('Error fetching pending challenges: $e');
      return PaginatedResult.empty();
    }
  }

  /// Get active challenges with pagination
  Future<PaginatedResult<Challenge>> getActiveChallengesPaginated(
    String userId, {
    int pageSize = 20,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      final params = PaginationParams(
        pageSize: pageSize,
        startAfter: startAfter,
      );

      var query = _firestore
          .collection('friend_challenges')
          .doc('active')
          .collection('list')
          .where('status', isEqualTo: 'accepted')
          .orderBy('createdAt', descending: true);

      query = QueryOptimizer.applyPagination(
        query,
        params,
      );

      final paginated = await QueryOptimizer.executePaginatedQuery(
        query,
        params,
        Challenge.fromJson,
      );

      // Filter by user (either challenger or challengee)
      final userChallenges = paginated.items
          .where((c) =>
              c.challengerUserId == userId || c.challengeeUserId == userId)
          .toList();

      return PaginatedResult(
        items: userChallenges,
        nextPageToken: paginated.nextPageToken,
        hasMore: paginated.hasMore,
        totalRetrieved: userChallenges.length,
      );
    } catch (e) {
      debugPrint('Error fetching active challenges: $e');
      return PaginatedResult.empty();
    }
  }

  /// Get challenge history with pagination
  Future<PaginatedResult<Challenge>> getChallengHistoryPaginated(
    String userId, {
    int pageSize = 20,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      final params = PaginationParams(
        pageSize: pageSize,
        startAfter: startAfter,
      );

      var query = _firestore
          .collection('friend_challenges')
          .doc('active')
          .collection('list')
          .where('status', isEqualTo: 'completed')
          .orderBy('completedAt', descending: true);

      query = QueryOptimizer.applyPagination(
        query,
        params,
      );

      final paginated = await QueryOptimizer.executePaginatedQuery(
        query,
        params,
        Challenge.fromJson,
      );

      // Filter by user
      final userChallenges = paginated.items
          .where((c) =>
              c.challengerUserId == userId || c.challengeeUserId == userId)
          .toList();

      return PaginatedResult(
        items: userChallenges,
        nextPageToken: paginated.nextPageToken,
        hasMore: paginated.hasMore,
        totalRetrieved: userChallenges.length,
      );
    } catch (e) {
      debugPrint('Error fetching challenge history: $e');
      return PaginatedResult.empty();
    }
  }

  /// Get user streak with caching
  Future<ChallengeStreak> getUserStreakOptimized(String userId) async =>
      _streakCache.get(userId);

  /// Get top streaks with caching
  Future<List<ChallengeStreak>> getTopStreaksOptimized({int limit = 50}) async {
    final cached = await _topStreaksCache.get('all');
    return cached.take(limit).toList();
  }

  /// Get head-to-head challenge stats (cached)
  Future<Map<String, int>> getHeadToHeadChallengeStats(
    String userId1,
    String userId2,
  ) async {
    final cacheKey = '$userId1:$userId2';
    final cached = _h2hChallengeCache.get(cacheKey);

    if (cached != null) {
      return cached;
    }

    try {
      int wins1 = 0;
      int wins2 = 0;

      final snapshot1 = await _firestore
          .collection('challenge_results')
          .where('winnerId', isEqualTo: userId1)
          .where('loserId', isEqualTo: userId2)
          .get();

      wins1 = snapshot1.docs.length;

      final snapshot2 = await _firestore
          .collection('challenge_results')
          .where('winnerId', isEqualTo: userId2)
          .where('loserId', isEqualTo: userId1)
          .get();

      wins2 = snapshot2.docs.length;

      final result = {'wins1': wins1, 'wins2': wins2};
      _h2hChallengeCache.set(cacheKey, result);
      return result;
    } catch (e) {
      debugPrint('Error fetching head-to-head stats: $e');
      return {'wins1': 0, 'wins2': 0};
    }
  }

  /// Get user's recent challenges
  Future<List<Challenge>> getUserRecentChallenges(
    String userId, {
    int limit = 10,
  }) async {
    try {
      // Pending challenges
      final pendingSnapshot = await _firestore
          .collection('friend_challenges')
          .doc('active')
          .collection('list')
          .where('challengeeUserId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      final pending = pendingSnapshot.docs
          .map((doc) => Challenge.fromJson(doc.data()))
          .toList();

      // Active challenges
      final activeSnapshot = await _firestore
          .collection('friend_challenges')
          .doc('active')
          .collection('list')
          .where('status', isEqualTo: 'accepted')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      final active = activeSnapshot.docs
          .map((doc) => Challenge.fromJson(doc.data()))
          .where(
            (c) => c.challengerUserId == userId || c.challengeeUserId == userId,
          )
          .toList();

      // Combine and sort by recency
      final combined = [...pending, ...active];
      combined.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return combined.take(limit).toList();
    } catch (e) {
      debugPrint('Error fetching recent challenges: $e');
      return [];
    }
  }

  /// Get challenge statistics for user
  Future<ChallengeStats> getChallengeStats(String userId) async {
    try {
      final streak = await getUserStreakOptimized(userId);

      final completedSnapshot = await _firestore
          .collection('friend_challenges')
          .doc('active')
          .collection('list')
          .where('status', isEqualTo: 'completed')
          .get();

      int totalWins = 0;
      int totalLosses = 0;

      for (final doc in completedSnapshot.docs) {
        if (doc['winnerId'] == userId) {
          totalWins++;
        } else if (doc['loserId'] == userId) {
          totalLosses++;
        }
      }

      return ChallengeStats(
        userId: userId,
        totalWins: totalWins,
        totalLosses: totalLosses,
        winRate: totalWins + totalLosses > 0
            ? totalWins / (totalWins + totalLosses)
            : 0.0,
        currentStreak: streak.currentStreak,
        bestStreak: streak.bestStreak,
      );
    } catch (e) {
      debugPrint('Error fetching challenge stats: $e');
      return ChallengeStats(
        userId: userId,
        totalWins: 0,
        totalLosses: 0,
        winRate: 0,
        currentStreak: 0,
        bestStreak: 0,
      );
    }
  }

  /// Database fetchers

  Future<ChallengeStreak> _getUserStreakFromDb(String userId) async {
    try {
      final doc =
          await _firestore.collection('challenge_streaks').doc(userId).get();

      if (!doc.exists) {
        return ChallengeStreak(
          userId: userId,
          currentStreak: 0,
          bestStreak: 0,
          streakStartDate: DateTime.now(),
          totalChallengesWon: 0,
          totalChallengesLost: 0,
          winRate: 0,
        );
      }

      return ChallengeStreak.fromJson(doc.data()!);
    } catch (e) {
      debugPrint('Error fetching streak from db: $e');
      rethrow;
    }
  }

  Future<List<ChallengeStreak>> _getTopStreaksFromDb() async {
    try {
      final snapshot = await _firestore
          .collection('challenge_streaks')
          .orderBy('currentStreak', descending: true)
          .limit(100)
          .get();

      return snapshot.docs
          .map((doc) => ChallengeStreak.fromJson(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error fetching top streaks from db: $e');
      return [];
    }
  }

  /// Cache invalidation

  void invalidateUserCache(String userId) {
    _challengesCache.invalidate(userId);
    _streakCache.invalidate(userId);
    _h2hChallengeCache.removeWhere((key) => key.contains(userId));
  }

  void invalidateStreakCache(String userId1, String userId2) {
    _streakCache.invalidate(userId1);
    _streakCache.invalidate(userId2);
    _h2hChallengeCache.remove('$userId1:$userId2');
    _h2hChallengeCache.remove('$userId2:$userId1');
  }

  void clearCache() {
    _challengesCache.invalidateAll();
    _streakCache.invalidateAll();
    _h2hChallengeCache.clear();
    _topStreaksCache.invalidateAll();
  }
}

class ChallengeStats {
  ChallengeStats({
    required this.userId,
    required this.totalWins,
    required this.totalLosses,
    required this.winRate,
    required this.currentStreak,
    required this.bestStreak,
  });
  final String userId;
  final int totalWins;
  final int totalLosses;
  final double winRate;
  final int currentStreak;
  final int bestStreak;
}
