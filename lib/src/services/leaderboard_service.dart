import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/phase_k_models.dart';

class LeaderboardService {
  factory LeaderboardService() => _instance;
  LeaderboardService._internal();
  static final LeaderboardService _instance = LeaderboardService._internal();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, List<LeaderboardEntry>> _leaderboardCache = {};
  final Map<String, RankingStats> _rankingStatsCache = {};

  static LeaderboardService get instance => _instance;

  /// Get global leaderboard with pagination
  Future<List<LeaderboardEntry>> getGlobalLeaderboard({
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('leaderboards')
          .doc('global')
          .collection('entries')
          .orderBy('rating', descending: true)
          .orderBy('wins', descending: true)
          .limit(limit + offset)
          .get();

      return snapshot.docs
          .skip(offset)
          .map((doc) => LeaderboardEntry.fromJson(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error fetching global leaderboard: $e');
      return [];
    }
  }

  /// Get regional leaderboard
  Future<List<LeaderboardEntry>> getRegionalLeaderboard(
    String region, {
    int limit = 100,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('leaderboards')
          .doc('regional')
          .collection(region)
          .orderBy('rating', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => LeaderboardEntry.fromJson(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error fetching regional leaderboard: $e');
      return [];
    }
  }

  /// Get time-based leaderboard (daily, weekly, monthly)
  Future<List<LeaderboardEntry>> getTimeBasedLeaderboard(
    String period, {
    int limit = 100,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('leaderboards')
          .doc('time-based')
          .collection(period)
          .orderBy('rating', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => LeaderboardEntry.fromJson(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error fetching time-based leaderboard: $e');
      return [];
    }
  }

  /// Get user's rank on global leaderboard
  Future<int> getUserGlobalRank(String userId) async {
    try {
      final userDoc = await _firestore
          .collection('leaderboards')
          .doc('global')
          .collection('entries')
          .doc(userId)
          .get();

      if (!userDoc.exists) return -1;
      return userDoc['rank'] as int;
    } catch (e) {
      debugPrint('Error fetching user rank: $e');
      return -1;
    }
  }

  /// Get user's percentile rank
  Future<int> getUserPercentile(String userId) async {
    try {
      final userRank = await getUserGlobalRank(userId);
      if (userRank <= 0) return 0;

      final totalUsers = await _firestore
          .collection('leaderboards')
          .doc('global')
          .collection('entries')
          .count()
          .get();

      final totalCount = totalUsers.count ?? 0;
      if (totalCount == 0) return 0;

      return ((totalCount - userRank) / totalCount * 100).toInt();
    } catch (e) {
      debugPrint('Error calculating percentile: $e');
      return 0;
    }
  }

  /// Get ranking statistics for user
  Future<RankingStats> getRankingStats(String userId) async {
    if (_rankingStatsCache.containsKey(userId)) {
      return _rankingStatsCache[userId]!;
    }

    try {
      final doc =
          await _firestore.collection('ranking_stats').doc(userId).get();

      if (!doc.exists) {
        return RankingStats(
          userId: userId,
          currentRating: 1200,
          peakRating: 1200,
          peakDate: DateTime.now(),
          rank: -1,
          percentile: 0,
          totalGamesPlayed: 0,
          ratingByTimeControl: {},
        );
      }

      final stats = RankingStats.fromJson(doc.data()!);
      _rankingStatsCache[userId] = stats;
      return stats;
    } catch (e) {
      debugPrint('Error fetching ranking stats: $e');
      rethrow;
    }
  }

  /// Get leaderboard history for user
  Future<List<LeaderboardHistory>> getLeaderboardHistory(
    String userId, {
    required String period,
    int limit = 30,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('leaderboard_history')
          .where('userId', isEqualTo: userId)
          .where('period', isEqualTo: period)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => LeaderboardHistory.fromJson(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error fetching leaderboard history: $e');
      return [];
    }
  }

  /// Update leaderboard after game completion
  Future<void> updateLeaderboardAfterGame({
    required String winnerId,
    required String loserId,
    required int ratingChange,
  }) async {
    try {
      await _firestore.runTransaction((transaction) async {
        // Update global leaderboard for winner
        final winnerDoc = _firestore
            .collection('leaderboards')
            .doc('global')
            .collection('entries')
            .doc(winnerId);

        transaction.update(winnerDoc, {
          'rating': FieldValue.increment(ratingChange),
          'wins': FieldValue.increment(1),
          'lastUpdated': FieldValue.serverTimestamp(),
        });

        // Update global leaderboard for loser
        final loserDoc = _firestore
            .collection('leaderboards')
            .doc('global')
            .collection('entries')
            .doc(loserId);

        transaction.update(loserDoc, {
          'rating': FieldValue.increment(-ratingChange),
          'losses': FieldValue.increment(1),
          'lastUpdated': FieldValue.serverTimestamp(),
        });

        // Invalidate cache
        _leaderboardCache.clear();
        _rankingStatsCache.remove(winnerId);
        _rankingStatsCache.remove(loserId);
      });
    } catch (e) {
      debugPrint('Error updating leaderboard: $e');
    }
  }

  /// Compare two players
  Future<LeaderboardComparison> comparePlayers(
    String userId1,
    String userId2,
  ) async {
    try {
      final user1 = await _firestore
          .collection('leaderboards')
          .doc('global')
          .collection('entries')
          .doc(userId1)
          .get();

      final user2 = await _firestore
          .collection('leaderboards')
          .doc('global')
          .collection('entries')
          .doc(userId2)
          .get();

      final h2h = await _getHeadToHeadStats(userId1, userId2);

      return LeaderboardComparison(
        userId1: userId1,
        username1: user1['username'] ?? 'Unknown',
        rating1: user1['rating'] ?? 1200,
        rank1: user1['rank'] ?? -1,
        userId2: userId2,
        username2: user2['username'] ?? 'Unknown',
        rating2: user2['rating'] ?? 1200,
        rank2: user2['rank'] ?? -1,
        headToHeadWins1: h2h['wins1'] ?? 0,
        headToHeadWins2: h2h['wins2'] ?? 0,
        headToHeadDraws: h2h['draws'] ?? 0,
      );
    } catch (e) {
      debugPrint('Error comparing players: $e');
      rethrow;
    }
  }

  /// Get head-to-head statistics
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
      debugPrint('Error fetching head-to-head stats: $e');
      return {'wins1': 0, 'wins2': 0, 'draws': 0};
    }
  }

  /// Search leaderboard by username
  Future<List<LeaderboardEntry>> searchByUsername(String query) async {
    try {
      final snapshot = await _firestore
          .collection('leaderboards')
          .doc('global')
          .collection('entries')
          .where('username', isGreaterThanOrEqualTo: query)
          .where('username', isLessThan: '$query')
          .limit(20)
          .get();

      return snapshot.docs
          .map((doc) => LeaderboardEntry.fromJson(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error searching leaderboard: $e');
      return [];
    }
  }

  /// Clear cache
  void clearCache() {
    _leaderboardCache.clear();
    _rankingStatsCache.clear();
  }
}
