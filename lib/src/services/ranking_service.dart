import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:komovia_core/komovia_core.dart';
import 'firestore_time.dart';

/// Builds a komovia_core [LeaderboardEntry] from a raw `users`/ranking
/// Firestore doc. Distinct from [LeaderboardEntry.fromJson]: that factory
/// defaults a missing `lastUpdated` to `DateTime.now()`, which would make
/// every player with no real `updatedAt` on their doc look like they just
/// played — this uses the Unix epoch as the "never updated" sentinel
/// instead, so callers can tell the difference (see
/// `RankCard._formatTime`'s caller in `leaderboard_screen.dart`).
///
/// Note: komovia_core's `LeaderboardEntry` has no shogi-rank-string field
/// (chess has no such concept) — the leaderboard/ranking screens compute
/// that purely from `rating` via `ShogiRankService` themselves instead of
/// reading it off the entry, keeping "what score is this" (this model)
/// separate from "how do we print it as a word" (`ShogiRankService`/
/// `ShogiRankDisplay`, untouched by this migration).
LeaderboardEntry _leaderboardEntryFromJson(
  Map<String, dynamic> json, {
  int rank = 0,
}) {
  final wins = (json['wins'] as num?)?.toInt() ?? 0;
  final losses = (json['losses'] as num?)?.toInt() ?? 0;
  final gamesPlayed =
      (json['gamesPlayed'] as num?)?.toInt() ?? (wins + losses);
  return LeaderboardEntry(
    uid: (json['userId'] as String?) ?? '',
    displayName: (json['displayName'] as String?) ??
        (json['username'] as String?) ??
        'Anonymous',
    rank: rank,
    rating: (json['rating'] as num?)?.toInt() ?? 1000,
    gamesPlayed: gamesPlayed,
    wins: wins,
    winRate: (json['winRate'] as num?)?.toDouble() ??
        (gamesPlayed > 0 ? wins / gamesPlayed : 0.0),
    puzzlesSolved: (json['puzzlesSolved'] as num?)?.toInt() ?? 0,
    lastUpdated: dateTimeFromTimestamp(
      json['updatedAt'],
      DateTime.fromMillisecondsSinceEpoch(0),
    ),
  );
}

class RankingService {
  factory RankingService() => _instance;

  RankingService._internal();
  static final RankingService _instance = RankingService._internal();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, List<PlayerRanking>> _rankingCache = {};

  Future<List<PlayerRanking>> getGlobalRankings(int limit) async {
    if (_rankingCache.containsKey('global')) {
      return _rankingCache['global']!;
    }

    try {
      final snapshot = await _firestore
          .collection('rankings')
          .doc('global')
          .collection('players')
          .orderBy('rating', descending: true)
          .limit(limit)
          .get();

      final rankings = snapshot.docs
          .asMap()
          .entries
          .map((e) => PlayerRanking.fromJson(e.value.data(), rank: e.key + 1))
          .toList();

      _rankingCache['global'] = rankings;
      Future.delayed(const Duration(minutes: 5)).then((_) {
        _rankingCache.remove('global');
      });

      return rankings;
    } catch (e) {
      print('Error fetching global rankings: $e');
      return [];
    }
  }

  Future<List<PlayerRanking>> getRegionalRankings(
      String region, int limit) async {
    final cacheKey = 'region_$region';
    if (_rankingCache.containsKey(cacheKey)) {
      return _rankingCache[cacheKey]!;
    }

    try {
      final snapshot = await _firestore
          .collection('rankings')
          .doc('regional')
          .collection(region)
          .orderBy('rating', descending: true)
          .limit(limit)
          .get();

      final rankings = snapshot.docs
          .asMap()
          .entries
          .map((e) => PlayerRanking.fromJson(e.value.data(), rank: e.key + 1))
          .toList();

      _rankingCache[cacheKey] = rankings;
      Future.delayed(const Duration(minutes: 5)).then((_) {
        _rankingCache.remove(cacheKey);
      });

      return rankings;
    } catch (e) {
      print('Error fetching regional rankings: $e');
      return [];
    }
  }

  Future<List<PlayerRanking>> getFriendRankings(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final friendIds = List<String>.from(userDoc['friends'] ?? []);

      if (friendIds.isEmpty) return [];

      final snapshot = await _firestore
          .collection('rankings')
          .doc('global')
          .collection('players')
          .where(FieldPath.documentId, whereIn: friendIds)
          .orderBy('rating', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => PlayerRanking.fromJson(doc.data()))
          .toList();
    } catch (e) {
      print('Error fetching friend rankings: $e');
      return [];
    }
  }

  Future<int> getUserRankPosition(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('rankings')
          .doc('global')
          .collection('players')
          .orderBy('rating', descending: true)
          .get();

      final index = snapshot.docs.indexWhere((doc) => doc.id == userId);
      return index >= 0 ? index + 1 : -1;
    } catch (e) {
      print('Error fetching user rank: $e');
      return -1;
    }
  }

  Future<void> updatePlayerRanking(String userId, GameResult result) async {
    try {
      final playerDoc = await _firestore
          .collection('rankings')
          .doc('global')
          .collection('players')
          .doc(userId)
          .get();

      int currentRating = playerDoc['rating'] ?? 1000;
      int wins = playerDoc['wins'] ?? 0;
      int losses = playerDoc['losses'] ?? 0;

      if (result.isWin) {
        wins++;
        currentRating += 16;
      } else if (!result.isDraw) {
        losses++;
        currentRating -= 16;
      }

      final newWinRate = wins / (wins + losses);

      await _firestore
          .collection('rankings')
          .doc('global')
          .collection('players')
          .doc(userId)
          .update({
        'rating': currentRating,
        'wins': wins,
        'losses': losses,
        'winRate': newWinRate,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _rankingCache.clear();
    } catch (e) {
      print('Error updating player ranking: $e');
    }
  }

  /// Get a page of the global ranking as [LeaderboardEntry] (used by the
  /// leaderboard screen, which needs richer per-entry display fields than
  /// [getGlobalRankings]/[PlayerRanking] provide).
  Future<List<LeaderboardEntry>> getGlobalRanking({
    required int limit,
    int offset = 0,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .orderBy('rating', descending: true)
          .limit(limit + offset)
          .get();

      return snapshot.docs
          .skip(offset)
          .toList()
          .asMap()
          .entries
          .map((e) => _leaderboardEntryFromJson(
                {...e.value.data(), 'userId': e.value.id},
                rank: offset + e.key + 1,
              ))
          .toList();
    } catch (e) {
      print('Error fetching global ranking: $e');
      return [];
    }
  }

  /// Get the global ranking filtered to a single shogi rank tier.
  Future<List<LeaderboardEntry>> getRankingByShogi(
    String shogiRank, {
    required int limit,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('rankings')
          .doc('global')
          .collection('players')
          .where('shogiRank', isEqualTo: shogiRank)
          .orderBy('rating', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .asMap()
          .entries
          .map((e) => _leaderboardEntryFromJson(e.value.data(), rank: e.key + 1))
          .toList();
    } catch (e) {
      print('Error fetching shogi-rank ranking: $e');
      return [];
    }
  }

  /// Get the ranking for a given month (defaults to the current month).
  Future<List<LeaderboardEntry>> getMonthlyRanking({
    required int limit,
    String? monthKey,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('rankings')
          .doc('monthly')
          .collection(monthKey ?? _currentMonthKey())
          .orderBy('rating', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .asMap()
          .entries
          .map((e) => _leaderboardEntryFromJson(e.value.data(), rank: e.key + 1))
          .toList();
    } catch (e) {
      print('Error fetching monthly ranking: $e');
      return [];
    }
  }

  String _currentMonthKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  /// Get this user's 1-based position in the global ranking, or null if
  /// they don't have a ranking entry yet.
  Future<int?> getUserRank(String uid) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .orderBy('rating', descending: true)
          .get();

      final index = snapshot.docs.indexWhere((doc) => doc.id == uid);
      return index >= 0 ? index + 1 : null;
    } catch (e) {
      print('Error fetching user rank: $e');
      return null;
    }
  }

  /// Get the [proximityCount] players immediately above and below [uid] in
  /// the global ranking (inclusive of [uid] itself).
  Future<List<LeaderboardEntry>> getNearbyRankings(
    String uid, {
    required int proximityCount,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .orderBy('rating', descending: true)
          .get();

      final docs = snapshot.docs;
      final index = docs.indexWhere((doc) => doc.id == uid);
      if (index < 0) return [];

      final start = (index - proximityCount).clamp(0, docs.length);
      final end = (index + proximityCount + 1).clamp(0, docs.length);

      return docs
          .sublist(start, end)
          .asMap()
          .entries
          .map((e) => _leaderboardEntryFromJson(
                {...e.value.data(), 'userId': e.value.id},
                rank: start + e.key + 1,
              ))
          .toList();
    } catch (e) {
      print('Error fetching nearby rankings: $e');
      return [];
    }
  }

  /// Real-time stream of the global ranking's top [limit] entries.
  Stream<List<LeaderboardEntry>> watchGlobalRanking({required int limit}) =>
      _firestore
          .collection('users')
          .orderBy('rating', descending: true)
          .limit(limit)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .asMap()
              .entries
              .map((e) => _leaderboardEntryFromJson(
                    {...e.value.data(), 'userId': e.value.id},
                    rank: e.key + 1,
                  ))
              .toList());

  /// Real-time stream of a single user's own ranking entry.
  Stream<LeaderboardEntry?> watchUserRanking(String uid) => _firestore
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((doc) => doc.exists
          ? _leaderboardEntryFromJson({...doc.data()!, 'userId': doc.id})
          : null);

  /// Aggregate stats over the whole global ranking (used by the leaderboard
  /// screen's summary header). Distinct from [getRankingStatistics], which
  /// also buckets players into a rating [RatingDistribution].
  Future<RankingStats> getRankingStats() async {
    try {
      final snapshot = await _firestore.collection('users').get();

      final ratings = snapshot.docs
          .map((doc) => (doc['rating'] as num?)?.toInt() ?? 0)
          .toList();

      final totalPlayers = ratings.length;
      final averageRating = totalPlayers > 0
          ? ratings.reduce((a, b) => a + b) / totalPlayers
          : 0.0;
      final topRating =
          ratings.isNotEmpty ? ratings.reduce((a, b) => a > b ? a : b) : 0;

      return RankingStats(
        totalPlayers: totalPlayers,
        averageRating: averageRating,
        topRating: topRating,
      );
    } catch (e) {
      print('Error fetching ranking stats: $e');
      return RankingStats(totalPlayers: 0, averageRating: 0, topRating: 0);
    }
  }

  Future<RankingStatistics> getRankingStatistics() async {
    try {
      final snapshot = await _firestore
          .collection('rankings')
          .doc('global')
          .collection('players')
          .get();

      final ratings = snapshot.docs.map((doc) => doc['rating'] as int).toList();
      final totalPlayers = ratings.length;
      final averageRating = ratings.fold(0, (a, b) => a + b) /
          (totalPlayers > 0 ? totalPlayers : 1);
      final topPlayerRating = ratings.isNotEmpty ? ratings.first : 0;

      return RankingStatistics(
        totalPlayers: totalPlayers,
        averageRating: averageRating,
        topPlayerRating: topPlayerRating,
        distribution: [],
      );
    } catch (e) {
      print('Error fetching ranking statistics: $e');
      return RankingStatistics(
        totalPlayers: 0,
        averageRating: 0,
        topPlayerRating: 0,
        distribution: [],
      );
    }
  }
}

class PlayerRanking {
  PlayerRanking({
    required this.userId,
    required this.username,
    required this.rating,
    required this.rank,
    required this.wins,
    required this.losses,
    required this.winRate,
    required this.region,
    required this.updatedAt,
  });

  factory PlayerRanking.fromJson(Map<String, dynamic> json, {int rank = 0}) =>
      PlayerRanking(
        userId: json['userId'] ?? '',
        username: json['username'] ?? '',
        rating: json['rating'] ?? 1000,
        rank: rank,
        wins: json['wins'] ?? 0,
        losses: json['losses'] ?? 0,
        winRate: (json['winRate'] ?? 0.0).toDouble(),
        region: json['region'] ?? 'Global',
        updatedAt: json['updatedAt'] != null
            ? (json['updatedAt'] as Timestamp).toDate()
            : DateTime.now(),
      );
  final String userId;
  final String username;
  final int rating;
  final int rank;
  final int wins;
  final int losses;
  final double winRate;
  final String region;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'username': username,
        'rating': rating,
        'wins': wins,
        'losses': losses,
        'winRate': winRate,
        'region': region,
        'updatedAt': updatedAt,
      };
}

class RankingStatistics {
  RankingStatistics({
    required this.totalPlayers,
    required this.averageRating,
    required this.topPlayerRating,
    required this.distribution,
  });
  final int totalPlayers;
  final double averageRating;
  final int topPlayerRating;
  final List<RatingDistribution> distribution;
}

class RatingDistribution {
  RatingDistribution({
    required this.tier,
    required this.playerCount,
    required this.percentage,
  });
  final String tier;
  final int playerCount;
  final double percentage;
}

class GameResult {
  GameResult({required this.isWin, required this.isDraw});
  final bool isWin;
  final bool isDraw;
}

/// Aggregate statistics over the whole ranking, shown in the leaderboard
/// screen's summary header.
class RankingStats {
  RankingStats({
    required this.totalPlayers,
    required this.averageRating,
    required this.topRating,
  });
  final int totalPlayers;
  final double averageRating;
  final int topRating;
}
