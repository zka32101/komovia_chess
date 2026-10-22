import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:komovia_core/komovia_core.dart';
import 'firestore_time.dart';
import 'shogi_rank_service.dart';

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

  /// Get a page of the global ranking as [LeaderboardEntry].
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

  /// Get the global ranking filtered to a single shogi rank tier
  /// (identified by its display label, e.g. `'3段'`/`'5級'` - see
  /// [ShogiRankService.displayName]/[ShogiRankService.allRanks]).
  ///
  /// Previously queried `rankings/global/players` filtered by a
  /// `shogiRank` field - but nothing anywhere ever writes to that
  /// collection, and `UserModel.shogiRank` is never set either, so this
  /// always returned zero results. [ShogiRank] is a pure function of
  /// `rating` ([ShogiRankService.calculateRank]), so it's queried here as
  /// a rating range against the real `users` collection instead - the
  /// same collection [getGlobalRanking] already uses.
  ///
  /// [offset] mirrors [getGlobalRanking]'s pagination (previously missing
  /// here entirely - nextPage()/previousPage() on the "by shogi rank" tab
  /// always re-queried from rank #1 with just a bigger/smaller limit,
  /// so paging never actually advanced through the list).
  Future<List<LeaderboardEntry>> getRankingByShogi(
    String shogiRankLabel, {
    required int limit,
    int offset = 0,
  }) async {
    try {
      final rank = ShogiRankService.allRanks.firstWhere(
        (r) => ShogiRankService.displayName(r) == shogiRankLabel,
        orElse: () => throw ArgumentError('Unknown shogi rank: $shogiRankLabel'),
      );
      final (min, max) = ShogiRankService.ratingRangeForRank(rank);

      Query<Map<String, dynamic>> query = _firestore.collection('users');
      if (min != null) {
        query = query.where('rating', isGreaterThanOrEqualTo: min);
      }
      if (max != null) {
        query = query.where('rating', isLessThan: max);
      }

      final snapshot = await query
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
      print('Error fetching shogi-rank ranking: $e');
      return [];
    }
  }

  /// Get the ranking for a given month (defaults to the current month).
  ///
  /// [offset] mirrors [getGlobalRanking]'s pagination (same previously
  /// -missing pagination bug as [getRankingByShogi] above, for the
  /// "monthly" tab).
  Future<List<LeaderboardEntry>> getMonthlyRanking({
    required int limit,
    int offset = 0,
    String? monthKey,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('rankings')
          .doc('monthly')
          .collection(monthKey ?? _currentMonthKey())
          .orderBy('rating', descending: true)
          .limit(limit + offset)
          .get();

      return snapshot.docs
          .skip(offset)
          .toList()
          .asMap()
          .entries
          .map((e) => _leaderboardEntryFromJson(e.value.data(), rank: offset + e.key + 1))
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
  ///
  /// Previously this (and [getNearbyRankings]) read every single document
  /// in `users` on every call just to answer "what rank is this one user"
  /// - unlike getGlobalRanking/getRankingByShogi/getMonthlyRanking in this
  /// same file, which already page with limit(). Rank is now derived from
  /// a count() aggregate query (one user document's own rating field,
  /// then a count of users with a strictly higher rating), which the
  /// Firestore server computes without the client ever downloading the
  /// matching documents.
  Future<int?> getUserRank(String uid) async {
    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      final rating = userDoc.data()?['rating'] as num?;
      if (rating == null) return null;

      final higherRatedCount = await _firestore
          .collection('users')
          .where('rating', isGreaterThan: rating)
          .count()
          .get();

      return (higherRatedCount.count ?? 0) + 1;
    } catch (e) {
      print('Error fetching user rank: $e');
      return null;
    }
  }

  /// Get the [proximityCount] players immediately above and below [uid] in
  /// the global ranking (inclusive of [uid] itself).
  ///
  /// Same full-collection-read problem as [getUserRank] previously had -
  /// now fetches only the 2*proximityCount+1 documents actually needed:
  /// one bounded range query for the closest-rated players above [uid]
  /// and one for those below, plus the single rank count each side needs
  /// to label its results.
  Future<List<LeaderboardEntry>> getNearbyRankings(
    String uid, {
    required int proximityCount,
  }) async {
    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      final data = userDoc.data();
      final rating = data?['rating'] as num?;
      if (rating == null) return [];

      final higherRatedCount = await _firestore
          .collection('users')
          .where('rating', isGreaterThan: rating)
          .count()
          .get();
      final selfRank = (higherRatedCount.count ?? 0) + 1;

      // Ascending order starting just above `rating` lists the closest
      // players above first, so the i-th result (0-based) is exactly
      // selfRank - (i + 1).
      final aboveSnapshot = await _firestore
          .collection('users')
          .where('rating', isGreaterThan: rating)
          .orderBy('rating')
          .limit(proximityCount)
          .get();
      // Descending order starting just below `rating` lists the closest
      // players below first, so the i-th result is selfRank + (i + 1).
      final belowSnapshot = await _firestore
          .collection('users')
          .where('rating', isLessThan: rating)
          .orderBy('rating', descending: true)
          .limit(proximityCount)
          .get();

      final entries = <LeaderboardEntry>[];
      final aboveDocs = aboveSnapshot.docs;
      for (var i = aboveDocs.length - 1; i >= 0; i--) {
        final doc = aboveDocs[i];
        entries.add(_leaderboardEntryFromJson(
          {...doc.data(), 'userId': doc.id},
          rank: selfRank - (i + 1),
        ));
      }
      entries.add(_leaderboardEntryFromJson(
        {...?data, 'userId': uid},
        rank: selfRank,
      ));
      final belowDocs = belowSnapshot.docs;
      for (var i = 0; i < belowDocs.length; i++) {
        final doc = belowDocs[i];
        entries.add(_leaderboardEntryFromJson(
          {...doc.data(), 'userId': doc.id},
          rank: selfRank + (i + 1),
        ));
      }

      return entries;
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
  /// screen's summary header).
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
