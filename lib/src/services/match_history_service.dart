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

      // Apply date range filters. `playedAt` is stored as an ISO8601
      // string (MatchRecord's generated toJson/fromJson), so it must be
      // compared against a string here too - a raw DateTime never
      // matches, which silently returned zero results for any date-range
      // filter.
      if (fromDate != null) {
        query = query.where(
          'playedAt',
          isGreaterThanOrEqualTo: fromDate.toIso8601String(),
        );
      }
      if (toDate != null) {
        query = query.where(
          'playedAt',
          isLessThanOrEqualTo: toDate.toIso8601String(),
        );
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

  /// Record a new match.
  ///
  /// Only writes the `match_history` entry itself - CpuGameProvider and
  /// OnlineGameService (the two real callers) both already update
  /// `users/{playerId}`'s `gamesPlayed`/`wins`/`losses`/`draws`/rating
  /// fields themselves as part of ending a game, before calling this.
  /// This method used to ALSO increment those same fields a second
  /// time, which - had it ever been wired up with those fields still
  /// here - would have double-counted every game. (Previously this had
  /// zero callers anywhere, so match_history_screen.dart/
  /// comparison_service.dart's reads were permanently empty, and this
  /// double-increment bug was never actually exercised either.)
  ///
  /// [moves], when given, is the game's move list as plain
  /// {'from','to','promotion'} maps - stored under the raw `movesUci`
  /// key alongside [match]'s own fields rather than as a declared field
  /// on [MatchRecord] itself, since adding a field to that @freezed
  /// model would need build_runner codegen this sandbox has no dart
  /// tooling to run. OpeningExplorerService reads this same raw key
  /// back directly (bypassing MatchRecord.fromJson) to build personal
  /// opening statistics.
  Future<void> recordMatch(
    MatchRecord match, {
    List<Map<String, dynamic>>? moves,
  }) async {
    try {
      await _firestore
          .collection('match_history')
          .doc(match.playerId)
          .collection('matches')
          .doc(match.matchId)
          .set({
        ...match.toJson(),
        if (moves != null) 'movesUci': moves,
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
