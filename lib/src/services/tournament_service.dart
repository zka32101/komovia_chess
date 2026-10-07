import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:komovia_core/komovia_core.dart';
import 'firestore_time.dart';

/// `Tournament`/`TournamentMatch` have no storage dependency (see
/// komovia_core's doc comments) — converting to/from Firestore's
/// `DocumentSnapshot`/`Timestamp` shape is this service's own
/// responsibility.
Tournament _tournamentFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data() ?? const {};
  return Tournament.fromJson({
    ...data,
    'id': doc.id,
    'startDate': isoFromTimestamp(data['startDate']),
    'endDate': isoFromTimestamp(data['endDate']),
    'createdAt': isoFromTimestamp(data['createdAt']),
  });
}

extension _TournamentFirestore on Tournament {
  /// [extraFields] carries this app's own fields with no komovia_core
  /// equivalent (entryFee/prizePool/timeControl — see
  /// `TournamentService.createTournament`), kept on the same document but
  /// outside `Tournament.toJson`/`fromJson`.
  Map<String, dynamic> toFirestore(Map<String, dynamic> extraFields) {
    final json = toJson()
      ..remove('id')
      ..remove('startDate')
      ..remove('endDate')
      ..remove('createdAt');
    json['startDate'] = Timestamp.fromDate(startDate);
    json['endDate'] = Timestamp.fromDate(endDate);
    json['createdAt'] = Timestamp.fromDate(createdAt);
    return {...json, ...extraFields};
  }
}

TournamentMatch _tournamentMatchFromDoc(
  DocumentSnapshot<Map<String, dynamic>> doc,
) {
  final data = doc.data() ?? const {};
  return TournamentMatch.fromJson({
    ...data,
    'id': doc.id,
    'scheduledAt': isoFromTimestamp(data['scheduledAt']),
    'completedAt':
        data['completedAt'] != null ? isoFromTimestamp(data['completedAt']) : null,
  });
}

extension _TournamentMatchFirestore on TournamentMatch {
  Map<String, dynamic> toFirestore() {
    final json = toJson()
      ..remove('id')
      ..remove('scheduledAt')
      ..remove('completedAt');
    json['scheduledAt'] = Timestamp.fromDate(scheduledAt);
    json['completedAt'] = completedAt != null ? Timestamp.fromDate(completedAt!) : null;
    return json;
  }
}

/// Tournament management service for organized competitive play.
///
/// `Tournament`/`TournamentParticipant`/`TournamentMatch` are now
/// `package:komovia_core`'s shared shapes (status 'upcoming'/'active'/
/// 'completed'/'cancelled', format 'single_elimination'/'round_robin'/
/// 'swiss', nullable bye-aware player slots) — see `phase_k_models.dart`'s
/// doc comment on the removed local versions for what changed.
class TournamentService {
  factory TournamentService({FirebaseFirestore? firestore}) =>
      firestore == null ? _instance : TournamentService._internal(firestore);
  TournamentService._internal([FirebaseFirestore? firestore])
      : _firestore = firestore ?? FirebaseFirestore.instance;
  static final TournamentService _instance = TournamentService._internal();

  static TournamentService get instance => _instance;

  final FirebaseFirestore _firestore;

  static const String tournamentsCollection = 'tournaments';
  static const String participantsCollection = 'participants';
  static const String matchesCollection = 'matches';

  /// Create a new tournament. `entryFee`/`prizePool`/`timeControl` have no
  /// komovia_core equivalent, so they're written onto the same document as
  /// extra fields rather than folded into `Tournament.toJson`.
  Future<Tournament> createTournament({
    required String name,
    required String description,
    required String format,
    required int maxParticipants,
    required String timeControl,
    required int entryFee,
    required int prizePool,
    required String createdBy,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final docRef = _firestore.collection(tournamentsCollection).doc();
      final tournament = Tournament(
        id: docRef.id,
        name: name,
        description: description,
        startDate: startDate,
        endDate: endDate,
        maxParticipants: maxParticipants,
        format: format,
        status: 'upcoming',
        participantUids: const [],
        createdBy: createdBy,
        createdAt: DateTime.now(),
      );

      await docRef.set(tournament.toFirestore({
        'timeControl': timeControl,
        'entryFee': entryFee,
        'prizePool': prizePool,
      }));

      return tournament;
    } catch (e) {
      debugPrint('Error creating tournament: $e');
      rethrow;
    }
  }

  /// Register a participant. Fails (via the transaction) if the tournament
  /// is already full.
  Future<void> registerParticipant(
    String tournamentId,
    String userId,
    String username,
    int seedRating,
  ) async {
    try {
      final tournamentRef = _firestore.collection(tournamentsCollection).doc(tournamentId);

      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(tournamentRef);
        if (!doc.exists) throw Exception('Tournament not found');
        final tournament = _tournamentFromDoc(doc);
        if (tournament.isFull) throw Exception('Tournament is full');

        transaction.set(
            tournamentRef.collection(participantsCollection).doc(userId),
            {
              'tournamentId': tournamentId,
              'uid': userId,
              'displayName': username,
              'seed': tournament.participantUids.length + 1,
              'joinedAt': Timestamp.now(),
              // Extra fields with no komovia_core `TournamentParticipant`
              // equivalent — chess's round-robin/swiss points bookkeeping
              // (see `getStandings`).
              'status': 'registered',
              'seedRating': seedRating,
              'points': 0,
              'wins': 0,
              'losses': 0,
              'draws': 0,
              'opponentIds': <String>[],
            });

        transaction.update(tournamentRef, {
          'participantUids': FieldValue.arrayUnion([userId]),
        });
      });
    } catch (e) {
      debugPrint('Error registering participant: $e');
      rethrow;
    }
  }

  /// Generate the round-1 bracket, seeded by rating (highest first). An odd
  /// number of participants leaves the lowest seed with a bye — a match
  /// with a null `player2Uid`, auto-completed with that player as the
  /// winner (komovia_core's `TournamentMatch.isBye`), matching how byes are
  /// handled for AI-adjacent sibling apps.
  Future<List<TournamentMatch>> generateBracket(String tournamentId) async {
    try {
      final tournamentRef = _firestore.collection(tournamentsCollection).doc(tournamentId);
      final participantsSnapshot =
          await tournamentRef.collection(participantsCollection).get();

      final participants = participantsSnapshot.docs
          .where((doc) => (doc.data()['status'] as String?) == 'registered')
          .toList()
        ..sort((a, b) => ((b.data()['seedRating'] as num?) ?? 0)
            .compareTo((a.data()['seedRating'] as num?) ?? 0));

      final batch = _firestore.batch();
      final now = DateTime.now();
      final matches = <TournamentMatch>[];
      const round = 1;

      for (var i = 0; i < participants.length; i += 2) {
        final player1Doc = participants[i];
        final hasOpponent = i + 1 < participants.length;
        final player2Doc = hasOpponent ? participants[i + 1] : null;

        final matchRef = tournamentRef.collection(matchesCollection).doc();
        final match = TournamentMatch(
          id: matchRef.id,
          tournamentId: tournamentId,
          player1Uid: player1Doc.id,
          player1DisplayName: player1Doc.data()['displayName'] as String?,
          player2Uid: player2Doc?.id,
          player2DisplayName: player2Doc?.data()['displayName'] as String?,
          round: round,
          // A bye is immediately resolved in player1's favor.
          winnerUid: hasOpponent ? null : player1Doc.id,
          status: hasOpponent ? 'pending' : 'completed',
          scheduledAt: now.add(const Duration(hours: round)),
          completedAt: hasOpponent ? null : now,
        );
        batch.set(matchRef, match.toFirestore());
        matches.add(match);
      }

      await batch.commit();
      return matches;
    } catch (e) {
      debugPrint('Error generating bracket: $e');
      rethrow;
    }
  }

  /// Record a match result and update both players' win/loss/points
  /// bookkeeping (kept as extra fields on each participant doc — see
  /// `registerParticipant`).
  Future<void> recordMatchResult({
    required String tournamentId,
    required String matchId,
    required String winnerId,
    required String loserId,
    required String gameId,
  }) async {
    try {
      final tournamentRef = _firestore.collection(tournamentsCollection).doc(tournamentId);
      final matchRef = tournamentRef.collection(matchesCollection).doc(matchId);
      final winnerRef = tournamentRef.collection(participantsCollection).doc(winnerId);
      final loserRef = tournamentRef.collection(participantsCollection).doc(loserId);

      await _firestore.runTransaction((transaction) async {
        final winnerDoc = await transaction.get(winnerRef);
        final loserDoc = await transaction.get(loserRef);

        transaction.update(matchRef, {
          'winnerUid': winnerId,
          'status': 'completed',
          'gameId': gameId,
          'completedAt': Timestamp.now(),
        });

        if (winnerDoc.exists) {
          transaction.update(winnerRef, {
            'wins': FieldValue.increment(1),
            'points': FieldValue.increment(3),
          });
        }
        if (loserDoc.exists) {
          transaction.update(loserRef, {'losses': FieldValue.increment(1)});
        }
      });
    } catch (e) {
      debugPrint('Error recording match result: $e');
      rethrow;
    }
  }

  Future<Tournament> getTournament(String tournamentId) async {
    try {
      final doc = await _firestore.collection(tournamentsCollection).doc(tournamentId).get();
      if (!doc.exists) throw Exception('Tournament not found');
      return _tournamentFromDoc(doc);
    } catch (e) {
      debugPrint('Error fetching tournament: $e');
      rethrow;
    }
  }

  /// `entryFee`/`prizePool`/`timeControl` as stored on the tournament
  /// document, read separately since they're not part of
  /// `Tournament.toJson`/`fromJson`.
  Future<Map<String, dynamic>> getTournamentExtras(String tournamentId) async {
    final doc = await _firestore.collection(tournamentsCollection).doc(tournamentId).get();
    final data = doc.data() ?? const {};
    return {
      'timeControl': data['timeControl'] as String? ?? '',
      'entryFee': (data['entryFee'] as num?)?.toInt() ?? 0,
      'prizePool': (data['prizePool'] as num?)?.toInt() ?? 0,
    };
  }

  /// Current standings, ranked by points then wins — computed from each
  /// participant's own raw points/wins/losses/draws fields (chess-specific
  /// bookkeeping with no komovia_core equivalent; see `registerParticipant`
  /// and `recordMatchResult`).
  Future<List<TournamentRanking>> getStandings(String tournamentId) async {
    try {
      final participantsSnapshot = await _firestore
          .collection(tournamentsCollection)
          .doc(tournamentId)
          .collection(participantsCollection)
          .orderBy('points', descending: true)
          .orderBy('wins', descending: true)
          .get();

      return participantsSnapshot.docs.asMap().entries.map((entry) {
        final doc = entry.value.data();
        return TournamentRanking(
          position: entry.key + 1,
          userId: doc['uid'] as String? ?? entry.value.id,
          username: doc['displayName'] as String? ?? 'Player',
          points: (doc['points'] as num?)?.toInt() ?? 0,
          wins: (doc['wins'] as num?)?.toInt() ?? 0,
          losses: (doc['losses'] as num?)?.toInt() ?? 0,
          draws: (doc['draws'] as num?)?.toInt() ?? 0,
          buchholz: 0,
          performance: 0,
        );
      }).toList();
    } catch (e) {
      debugPrint('Error fetching standings: $e');
      rethrow;
    }
  }

  Future<List<TournamentMatch>> getTournamentMatches(
    String tournamentId, {
    int? round,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection(tournamentsCollection)
          .doc(tournamentId)
          .collection(matchesCollection)
          .orderBy('round')
          .orderBy('scheduledAt');

      if (round != null) {
        query = query.where('round', isEqualTo: round);
      }

      final snapshot = await query.get();
      return snapshot.docs.map(_tournamentMatchFromDoc).toList();
    } catch (e) {
      debugPrint('Error fetching tournament matches: $e');
      return [];
    }
  }

  Future<List<Tournament>> getActiveTournaments() async {
    try {
      final snapshot = await _firestore
          .collection(tournamentsCollection)
          .where('status', whereIn: ['upcoming', 'active'])
          .orderBy('startDate')
          .get();

      return snapshot.docs.map(_tournamentFromDoc).toList();
    } catch (e) {
      debugPrint('Error fetching active tournaments: $e');
      return [];
    }
  }

  /// Distribute prize money to the top 3 finishers (50/30/20 split, or
  /// 60/40 for a 2-participant field) and mark the tournament completed.
  Future<void> distributePrizes(String tournamentId) async {
    try {
      final standings = await getStandings(tournamentId);
      final extras = await getTournamentExtras(tournamentId);
      final prizePool = extras['prizePool'] as int;

      final prizeDistribution = _calculatePrizeDistribution(prizePool, standings.length);

      for (var i = 0; i < standings.length && i < 3; i++) {
        final ranking = standings[i];
        final prizeAmount = prizeDistribution[i];

        await _firestore.collection('user_rewards').doc(ranking.userId).set({
          'totalPrizeWinnings': FieldValue.increment(prizeAmount),
          'tournaments': FieldValue.increment(1),
        }, SetOptions(merge: true));
      }

      await _firestore
          .collection(tournamentsCollection)
          .doc(tournamentId)
          .update({'status': 'completed'});
    } catch (e) {
      debugPrint('Error distributing prizes: $e');
      rethrow;
    }
  }

  List<int> _calculatePrizeDistribution(int totalPrize, int participantCount) {
    if (participantCount >= 3) {
      return [
        (totalPrize * 0.5).toInt(),
        (totalPrize * 0.3).toInt(),
        (totalPrize * 0.2).toInt(),
      ];
    } else if (participantCount == 2) {
      return [
        (totalPrize * 0.6).toInt(),
        (totalPrize * 0.4).toInt(),
      ];
    } else {
      return [totalPrize];
    }
  }
}
