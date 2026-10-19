import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/phase_k_models.dart';

/// Friend-to-friend challenge service for head-to-head competitive matches
class FriendChallengeService {
  factory FriendChallengeService() => _instance;
  FriendChallengeService._internal();
  static final FriendChallengeService _instance =
      FriendChallengeService._internal();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, List<Challenge>> _challengesCache = {};
  final Map<String, ChallengeStreak> _streakCache = {};

  static FriendChallengeService get instance => _instance;

  /// Send challenge to friend
  Future<Challenge> sendChallenge({
    required String challengerUserId,
    required String challengerUsername,
    required String challengeeUserId,
    required String challengeeUsername,
    required String timeControl,
    required int wagerPoints,
  }) async {
    try {
      final challengeId = DateTime.now().millisecondsSinceEpoch.toString();

      await _firestore
          .collection('friend_challenges')
          .doc('active')
          .collection('list')
          .doc(challengeId)
          .set({
        'challengeId': challengeId,
        'challengerUserId': challengerUserId,
        'challengerUsername': challengerUsername,
        'challengeeUserId': challengeeUserId,
        'challengeeUsername': challengeeUsername,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
        'timeControl': timeControl,
        'wagerPoints': wagerPoints,
        'respondedAt': null,
        'winnerId': null,
        'gameId': null,
        'completedAt': null,
      });

      _challengesCache.remove(challengeeUserId);

      return Challenge(
        challengeId: challengeId,
        challengerUserId: challengerUserId,
        challengerUsername: challengerUsername,
        challengeeUserId: challengeeUserId,
        challengeeUsername: challengeeUsername,
        createdAt: DateTime.now(),
        status: 'pending',
        timeControl: timeControl,
        wagerPoints: wagerPoints,
        respondedAt: null,
        winnerId: null,
        gameId: null,
        completedAt: null,
      );
    } catch (e) {
      debugPrint('Error sending challenge: $e');
      rethrow;
    }
  }

  /// Accept challenge
  Future<void> acceptChallenge(
    String challengeId,
    String gameId,
  ) async {
    try {
      await _firestore
          .collection('friend_challenges')
          .doc('active')
          .collection('list')
          .doc(challengeId)
          .update({
        'status': 'accepted',
        'respondedAt': FieldValue.serverTimestamp(),
        'gameId': gameId,
      });

      _challengesCache.clear();
    } catch (e) {
      debugPrint('Error accepting challenge: $e');
      rethrow;
    }
  }

  /// Reject challenge
  Future<void> rejectChallenge(String challengeId) async {
    try {
      await _firestore
          .collection('friend_challenges')
          .doc('active')
          .collection('list')
          .doc(challengeId)
          .update({
        'status': 'rejected',
        'respondedAt': FieldValue.serverTimestamp(),
      });

      _challengesCache.clear();
    } catch (e) {
      debugPrint('Error rejecting challenge: $e');
      rethrow;
    }
  }

  /// Cancel challenge
  Future<void> cancelChallenge(String challengeId) async {
    try {
      await _firestore
          .collection('friend_challenges')
          .doc('active')
          .collection('list')
          .doc(challengeId)
          .update({
        'status': 'cancelled',
        'completedAt': FieldValue.serverTimestamp(),
      });

      _challengesCache.clear();
    } catch (e) {
      debugPrint('Error cancelling challenge: $e');
      rethrow;
    }
  }

  /// Complete challenge with winner
  Future<void> completeChallengeWithWinner({
    required String challengeId,
    required String winnerId,
    required String loserId,
    required int winnerRatingGain,
    required int loserRatingLoss,
    required int moveCount,
  }) async {
    try {
      final resultId = DateTime.now().millisecondsSinceEpoch.toString();
      final winnerStreakRef =
          _firestore.collection('challenge_streaks').doc(winnerId);
      final loserStreakRef =
          _firestore.collection('challenge_streaks').doc(loserId);

      await _firestore.runTransaction((transaction) async {
        // Firestore transactions require every read before any write, so
        // the streak docs (which may not exist yet) are read here and
        // written with set(), never update() -- update() throws NOT_FOUND
        // on a doc nothing has created before.
        final winnerSnapshot = await transaction.get(winnerStreakRef);
        final loserSnapshot = await transaction.get(loserStreakRef);

        final winnerData = winnerSnapshot.data() ?? const {};
        final winnerCurrentStreak =
            ((winnerData['currentStreak'] as num?)?.toInt() ?? 0) + 1;
        final winnerBestStreak =
            (winnerData['bestStreak'] as num?)?.toInt() ?? 0;
        final winnerWon =
            ((winnerData['totalChallengesWon'] as num?)?.toInt() ?? 0) + 1;
        final winnerLost =
            (winnerData['totalChallengesLost'] as num?)?.toInt() ?? 0;
        final winnerTotal = winnerWon + winnerLost;

        final loserData = loserSnapshot.data() ?? const {};
        final loserWon =
            (loserData['totalChallengesWon'] as num?)?.toInt() ?? 0;
        final loserLost =
            ((loserData['totalChallengesLost'] as num?)?.toInt() ?? 0) + 1;
        final loserTotal = loserWon + loserLost;

        // Update challenge status
        transaction.update(
            _firestore
                .collection('friend_challenges')
                .doc('active')
                .collection('list')
                .doc(challengeId),
            {
              'status': 'completed',
              'winnerId': winnerId,
              'completedAt': FieldValue.serverTimestamp(),
            });

        // Record result
        transaction
            .set(_firestore.collection('challenge_results').doc(resultId), {
          'resultId': resultId,
          'challengeId': challengeId,
          'winnerId': winnerId,
          'loserId': loserId,
          'winnerRatingGain': winnerRatingGain,
          'loserRatingLoss': loserRatingLoss,
          'completedAt': FieldValue.serverTimestamp(),
          'gameMode': 'challenge',
          'moveCount': moveCount,
        });

        transaction.set(winnerStreakRef, {
          'userId': winnerId,
          'currentStreak': winnerCurrentStreak,
          'bestStreak': winnerCurrentStreak > winnerBestStreak
              ? winnerCurrentStreak
              : winnerBestStreak,
          'totalChallengesWon': winnerWon,
          'totalChallengesLost': winnerLost,
          'winRate': winnerTotal == 0 ? 0.0 : winnerWon / winnerTotal,
          'streakStartDate':
              winnerData['streakStartDate'] ?? FieldValue.serverTimestamp(),
        });

        transaction.set(loserStreakRef, {
          'userId': loserId,
          'currentStreak': 0,
          'bestStreak': loserData['bestStreak'] ?? 0,
          'totalChallengesWon': loserWon,
          'totalChallengesLost': loserLost,
          'winRate': loserTotal == 0 ? 0.0 : loserWon / loserTotal,
          'streakStartDate':
              loserData['streakStartDate'] ?? FieldValue.serverTimestamp(),
        });
      });

      _challengesCache.clear();
      _streakCache.remove(winnerId);
      _streakCache.remove(loserId);
    } catch (e) {
      debugPrint('Error completing challenge: $e');
      rethrow;
    }
  }

  /// Get pending challenges
  Future<List<Challenge>> getPendingChallenges(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('friend_challenges')
          .doc('active')
          .collection('list')
          .where('challengeeUserId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => Challenge.fromJson(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error fetching pending challenges: $e');
      return [];
    }
  }

  /// Get active challenges.
  ///
  /// Runs two separately-filtered queries (one per side of the
  /// challenge) rather than an unfiltered `where('status', ...)` query
  /// post-filtered client-side - firestore.rules' read rule for this
  /// collection only allows a `list` whose own query already
  /// constrains it to the caller's challenges, since the rule itself
  /// can't evaluate an OR across the two uid fields against an
  /// unconstrained query. The old unfiltered version would have let
  /// any signed-in user query every pair's challenges directly (status/
  /// wagerPoints/both display names), bypassing this method's own
  /// client-side `.where()` filter entirely.
  Future<List<Challenge>> getActiveChallenges(String userId) async {
    try {
      final challenges = await _queryBothSides(
        userId,
        status: 'accepted',
        orderByField: 'createdAt',
      );
      return challenges;
    } catch (e) {
      debugPrint('Error fetching active challenges: $e');
      return [];
    }
  }

  /// Get challenge history. See [getActiveChallenges]'s doc comment for
  /// why this queries both sides separately instead of filtering a
  /// broader query client-side.
  Future<List<Challenge>> getChallengeHistory(
    String userId, {
    int limit = 50,
  }) async {
    try {
      final challenges = await _queryBothSides(
        userId,
        status: 'completed',
        orderByField: 'completedAt',
      );
      return challenges.take(limit).toList();
    } catch (e) {
      debugPrint('Error fetching challenge history: $e');
      return [];
    }
  }

  /// Queries `friend_challenges/active/list` for [userId]'s challenges
  /// with the given [status], as challenger and as challengee
  /// separately (each query individually satisfies firestore.rules'
  /// read rule, which requires the query to already constrain one of
  /// the two participant fields to the caller's own uid), merges the
  /// two result sets, de-duplicates (a challenge can never match both
  /// queries at once since challengerUserId != challengeeUserId, but
  /// de-duping by id is cheap insurance), and sorts by [orderByField]
  /// descending to match the single-query behavior this replaces.
  Future<List<Challenge>> _queryBothSides(
    String userId, {
    required String status,
    required String orderByField,
  }) async {
    final collection = _firestore
        .collection('friend_challenges')
        .doc('active')
        .collection('list');

    final results = await Future.wait([
      collection
          .where('challengerUserId', isEqualTo: userId)
          .where('status', isEqualTo: status)
          .get(),
      collection
          .where('challengeeUserId', isEqualTo: userId)
          .where('status', isEqualTo: status)
          .get(),
    ]);

    final byId = <String, Challenge>{};
    for (final snapshot in results) {
      for (final doc in snapshot.docs) {
        byId[doc.id] = Challenge.fromJson(doc.data());
      }
    }

    final challenges = byId.values.toList()
      ..sort((a, b) {
        final aTime = orderByField == 'completedAt'
            ? a.completedAt
            : a.createdAt;
        final bTime = orderByField == 'completedAt'
            ? b.completedAt
            : b.createdAt;
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime);
      });
    return challenges;
  }

  /// Get user's challenge streak
  Future<ChallengeStreak> getUserStreak(String userId) async {
    if (_streakCache.containsKey(userId)) {
      return _streakCache[userId]!;
    }

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

      final streak = ChallengeStreak.fromJson(doc.data()!);
      _streakCache[userId] = streak;
      return streak;
    } catch (e) {
      debugPrint('Error fetching user streak: $e');
      rethrow;
    }
  }

  /// Get top streaks
  Future<List<ChallengeStreak>> getTopStreaks({int limit = 50}) async {
    try {
      final snapshot = await _firestore
          .collection('challenge_streaks')
          .orderBy('currentStreak', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => ChallengeStreak.fromJson(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error fetching top streaks: $e');
      return [];
    }
  }

  /// Get head-to-head stats
  Future<Map<String, int>> getHeadToHeadStats(
    String userId1,
    String userId2,
  ) async {
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

      return {'wins1': wins1, 'wins2': wins2};
    } catch (e) {
      debugPrint('Error fetching head-to-head stats: $e');
      return {'wins1': 0, 'wins2': 0};
    }
  }

  /// Clear cache
  void clearCache() {
    _challengesCache.clear();
    _streakCache.clear();
  }
}
