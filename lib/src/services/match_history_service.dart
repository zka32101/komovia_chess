import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/match_record.dart';

/// Service for managing and querying match history
class MatchHistoryService {
  MatchHistoryService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _firestore;

  /// Get paginated match history for a player
  Future<List<MatchRecord>> getMatchHistory(
    String playerId, {
    int limit = 50,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      Query query = _firestore
          .collection('match_history')
          .doc(playerId)
          .collection('matches')
          .orderBy('playedAt', descending: true)
          .limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) =>
              MatchRecord.fromJson(doc.data()! as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to get match history: $e');
    }
  }

  /// Stream match history updates
  Stream<List<MatchRecord>> watchMatchHistory(String playerId) => _firestore
      .collection('match_history')
      .doc(playerId)
      .collection('matches')
      .orderBy('playedAt', descending: true)
      .snapshots()
      .map((snapshot) =>
          snapshot.docs.map((doc) => MatchRecord.fromJson(doc.data())).toList())
      .handleError((e) => throw Exception('Failed to watch match history: $e'));

  /// Filter matches by criteria
  Future<List<MatchRecord>> filterMatches(
    String playerId, {
    DateTime? fromDate,
    DateTime? toDate,
    String? opponentId,
    String? result, // 'win', 'loss', 'draw'
    String? timeControl,
  }) async {
    try {
      Query query = _firestore
          .collection('match_history')
          .doc(playerId)
          .collection('matches');

      // Apply date range filters
      if (fromDate != null) {
        query = query.where('playedAt', isGreaterThanOrEqualTo: fromDate);
      }
      if (toDate != null) {
        query = query.where('playedAt', isLessThanOrEqualTo: toDate);
      }

      // Apply result filter
      if (result != null) {
        query = query.where('result', isEqualTo: result);
      }

      // Apply opponent filter
      if (opponentId != null) {
        query = query.where('opponentId', isEqualTo: opponentId);
      }

      // Apply time control filter
      if (timeControl != null) {
        query = query.where('timeControl', isEqualTo: timeControl);
      }

      query = query.orderBy('playedAt', descending: true);

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) =>
              MatchRecord.fromJson(doc.data()! as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to filter matches: $e');
    }
  }

  /// Export match history as CSV
  Future<String> exportMatchHistoryAsCSV(String playerId) async {
    try {
      final matches = await getMatchHistory(playerId, limit: 1000);

      final buffer = StringBuffer();

      // CSV Header
      buffer
          .writeln('Date,Opponent,Result,Rating Change,Time Control,Duration');

      // CSV Data
      for (final match in matches) {
        final ratingChange = match.playerRatingAfter - match.playerRatingBefore;
        final durationStr = match.duration != null ? '${match.duration}s' : '-';

        buffer.writeln(
          '${match.playedAt.toIso8601String()}'
          ',${match.opponentName}'
          ',${match.result}'
          ',+$ratingChange'
          ',${match.timeControl}'
          ',$durationStr',
        );
      }

      return buffer.toString();
    } catch (e) {
      throw Exception('Failed to export match history: $e');
    }
  }

  /// Get match statistics for a specific opponent
  Future<Map<String, int>> getStatsVsOpponent(
    String playerId,
    String opponentId,
  ) async {
    try {
      int wins = 0;
      int losses = 0;
      int draws = 0;

      final snapshot = await _firestore
          .collection('match_history')
          .doc(playerId)
          .collection('matches')
          .where('opponentId', isEqualTo: opponentId)
          .get();

      for (final doc in snapshot.docs) {
        final match = MatchRecord.fromJson(doc.data());
        switch (match.result) {
          case 'win':
            wins++;
            break;
          case 'loss':
            losses++;
            break;
          case 'draw':
            draws++;
            break;
        }
      }

      return {
        'wins': wins,
        'losses': losses,
        'draws': draws,
      };
    } catch (e) {
      throw Exception('Failed to get stats vs opponent: $e');
    }
  }

  /// Record a new match
  Future<void> recordMatch(MatchRecord match) async {
    try {
      // Record for player
      await _firestore
          .collection('match_history')
          .doc(match.playerId)
          .collection('matches')
          .doc(match.matchId)
          .set(match.toJson());

      // Also record basic info in user stats for quick access
      await _firestore.collection('users').doc(match.playerId).update({
        'gamesPlayed': FieldValue.increment(1),
        if (match.result == 'win') 'wins': FieldValue.increment(1),
        if (match.result == 'loss') 'losses': FieldValue.increment(1),
        if (match.result == 'draw') 'draws': FieldValue.increment(1),
        'rating': match.playerRatingAfter,
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to record match: $e');
    }
  }

  /// Get total games played
  Future<int> getTotalGamesPlayed(String playerId) async {
    try {
      final snapshot = await _firestore
          .collection('match_history')
          .doc(playerId)
          .collection('matches')
          .get();

      return snapshot.size;
    } catch (e) {
      throw Exception('Failed to get total games: $e');
    }
  }

  /// Get win rate
  Future<double> getWinRate(String playerId) async {
    try {
      final snapshot = await _firestore
          .collection('match_history')
          .doc(playerId)
          .collection('matches')
          .get();

      if (snapshot.size == 0) return 0.0;

      int wins = 0;
      for (final doc in snapshot.docs) {
        final match = MatchRecord.fromJson(doc.data());
        if (match.result == 'win') wins++;
      }

      return wins / snapshot.size * 100;
    } catch (e) {
      throw Exception('Failed to get win rate: $e');
    }
  }
}
