import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:komovia_core/komovia_core.dart';
import '../models/phase_k_models.dart';
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
  /// equivalent (prizePool/timeControl — see
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

  /// Create a new tournament. `prizePool`/`timeControl` have no
  /// komovia_core equivalent, so they're written onto the same document as
  /// extra fields rather than folded into `Tournament.toJson`.
  Future<Tournament> createTournament({
    required String name,
    required String description,
    required String format,
    required int maxParticipants,
    required String timeControl,
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

  /// Generate the round-1 bracket, seeded by rating (highest first), and
  /// move the tournament from 'upcoming' to 'active'. An odd number of
  /// participants leaves the lowest seed with a bye — a match with a null
  /// `player2Uid`, auto-completed with that player as the winner
  /// (komovia_core's `TournamentMatch.isBye`), matching how byes are
  /// handled for AI-adjacent sibling apps.
  ///
  /// Only generates round 1 - this app has no automatic next-round
  /// generation yet. Fine for a round_robin/swiss tournament (one round
  /// covers the whole schedule); a multi-round single_elimination bracket
  /// is a known, documented limitation until that's built.
  Future<List<TournamentMatch>> generateBracket(String tournamentId) async {
    try {
      final tournamentRef = _firestore.collection(tournamentsCollection).doc(tournamentId);

      // Atomically claim the tournament by flipping status from
      // 'upcoming' to 'active' inside a transaction before generating
      // anything - without this, an organizer re-tapping "Generate
      // Bracket" (or a retried request), or two co-organizers doing so
      // near-simultaneously, could each see the tournament as still
      // 'upcoming' and each create a full, duplicate round-1 bracket.
      // Firestore re-reads this transaction's reads at commit time, so
      // only the first caller actually transitions the status; a second
      // caller's transaction sees the now-'active' status and no-ops,
      // even if its own initial read happened before the first commit.
      var claimed = false;
      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(tournamentRef);
        final currentStatus = doc.data()?['status'] as String?;
        if (currentStatus != null && currentStatus != 'upcoming') {
          return;
        }
        transaction.update(tournamentRef, {'status': 'active'});
        claimed = true;
      });

      if (!claimed) {
        debugPrint(
            'Tournament $tournamentId already had its bracket generated; '
            'skipping duplicate generation');
        return [];
      }

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

      // status is already 'active' - set transactionally above when this
      // call claimed the tournament.
      await batch.commit();
      return matches;
    } catch (e) {
      debugPrint('Error generating bracket: $e');
      rethrow;
    }
  }

  /// Record a match result and update both players' win/loss/points
  /// bookkeeping (kept as extra fields on each participant doc — see
  /// `registerParticipant`). [gameId] is optional - this app has no
  /// per-match PvP-game-backed result flow yet (unlike sibling apps'
  /// PvpGame-backed tournaments), so the organizer records who won
  /// directly with no linked game to cite.
  Future<void> recordMatchResult({
    required String tournamentId,
    required String matchId,
    required String winnerId,
    required String loserId,
    String? gameId,
  }) async {
    try {
      final tournamentRef = _firestore.collection(tournamentsCollection).doc(tournamentId);
      final matchRef = tournamentRef.collection(matchesCollection).doc(matchId);
      final winnerRef = tournamentRef.collection(participantsCollection).doc(winnerId);
      final loserRef = tournamentRef.collection(participantsCollection).doc(loserId);

      int? completedRound;

      await _firestore.runTransaction((transaction) async {
        // Claim the match by its own `status` before applying any
        // win/loss deltas - without this, a double-tap on the "Who won?"
        // dialog, a retried request, or an organizer re-recording an
        // already-decided match would each re-increment the winner's
        // wins/points and the loser's losses, corrupting getStandings and
        // the prize split distributePrizes later reads as truth. Same
        // claim-first pattern as generateBracket/distributePrizes above.
        final matchDoc = await transaction.get(matchRef);
        if (matchDoc.data()?['status'] == 'completed') {
          return;
        }

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

        completedRound = matchDoc.data()?['round'] as int?;
      });

      // Previously generateBracket only ever produced round 1 and nothing
      // afterward ever generated round 2+ - any tournament with more than
      // one round was structurally stuck once round 1 finished. Mirrors
      // komovia_go's TournamentService._advanceRoundIfComplete.
      if (completedRound != null) {
        await _advanceRoundIfComplete(tournamentId, completedRound!);
      }
    } catch (e) {
      debugPrint('Error recording match result: $e');
      rethrow;
    }
  }

  /// After a match in [completedRound] is recorded, checks whether every
  /// match in that round is now complete and, if so, either generates the
  /// next round from this round's winners (same seed-order pairing as
  /// generateBracket - a bye's "winner" simply carries over with no
  /// opponent to re-pair against) or, once a single winner remains, marks
  /// the tournament 'completed' with that winner.
  ///
  /// Transactional and guarded by [Tournament.lastAdvancedRound] (same
  /// claim-first pattern as [generateBracket]) so two near-simultaneous
  /// [recordMatchResult] calls that each complete the last pending match
  /// of a round can't each generate a duplicate next round.
  Future<void> _advanceRoundIfComplete(
    String tournamentId,
    int completedRound,
  ) async {
    final roundMatches =
        await getTournamentMatches(tournamentId, round: completedRound);
    if (roundMatches.isEmpty || roundMatches.any((m) => !m.isCompleted)) {
      return;
    }

    final winners = roundMatches
        .map((m) => m.winnerUid)
        .whereType<String>()
        .toList();

    String? displayNameFor(String uid) {
      for (final match in roundMatches) {
        if (match.player1Uid == uid) return match.player1DisplayName;
        if (match.player2Uid == uid) return match.player2DisplayName;
      }
      return null;
    }

    final tournamentRef =
        _firestore.collection(tournamentsCollection).doc(tournamentId);
    var tournamentCompleted = false;
    var nextRoundGenerated = false;

    await _firestore.runTransaction((transaction) async {
      final tournamentDoc = await transaction.get(tournamentRef);
      final data = tournamentDoc.data();
      if (data == null) return;

      final lastAdvancedRound = (data['lastAdvancedRound'] as int?) ?? 0;
      if (lastAdvancedRound >= completedRound) {
        // Another call already advanced past this round.
        return;
      }

      if (winners.length <= 1) {
        transaction.update(tournamentRef, {
          'status': 'completed',
          'winnerId': winners.isNotEmpty ? winners.first : null,
          'lastAdvancedRound': completedRound,
        });
        tournamentCompleted = true;
        return;
      }
      // (winners.length > 1 falls through to generating the next round
      // below - tournamentCompleted stays false.)

      final nextRound = completedRound + 1;
      final now = DateTime.now();

      for (var i = 0; i < winners.length; i += 2) {
        final player1 = winners[i];
        final hasOpponent = i + 1 < winners.length;
        final player2 = hasOpponent ? winners[i + 1] : null;

        final matchRef = tournamentRef.collection(matchesCollection).doc();
        final match = TournamentMatch(
          id: matchRef.id,
          tournamentId: tournamentId,
          player1Uid: player1,
          player1DisplayName: displayNameFor(player1),
          player2Uid: player2,
          player2DisplayName: player2 != null ? displayNameFor(player2) : null,
          round: nextRound,
          winnerUid: hasOpponent ? null : player1,
          status: hasOpponent ? 'pending' : 'completed',
          scheduledAt: now.add(Duration(hours: nextRound)),
          completedAt: hasOpponent ? null : now,
        );
        transaction.set(matchRef, match.toFirestore());
      }

      transaction.update(tournamentRef, {'lastAdvancedRound': completedRound});
      nextRoundGenerated = true;
    });

    // A newly-generated round that turned out to be a single bye match is
    // already 'completed' the moment it's written (no opponent to wait
    // on) - cascade into checking that round too, so the tournament
    // doesn't sit stuck one round away from finishing until some
    // unrelated event happens to re-trigger this check.
    if (nextRoundGenerated && !tournamentCompleted) {
      await _advanceRoundIfComplete(tournamentId, completedRound + 1);
    }

    // Previously a tournament whose bracket ran to completion on its own
    // (the common case) could never actually pay its prizes: the only UI
    // path to distributePrizes was an organizer button shown only while
    // isActive, which this very status flip to 'completed' just hid, and
    // distributePrizes' own idempotency guard also keyed off
    // status == 'completed' - so even a direct call would have silently
    // no-op'd ("already distributed") despite no payout ever happening.
    // Best-effort: a transient failure here must not leave the bracket
    // itself stuck or retried, since _advanceRoundIfComplete's own
    // claim-first guard (lastAdvancedRound) has already committed.
    if (tournamentCompleted) {
      try {
        await distributePrizes(tournamentId);
      } catch (e) {
        debugPrint(
          'Tournament $tournamentId completed but prize distribution '
          'failed - it can still be retried via the organizer UI: $e',
        );
      }
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

  /// `prizePool`/`timeControl` as stored on the tournament document, read
  /// separately since they're not part of `Tournament.toJson`/`fromJson`.
  Future<Map<String, dynamic>> getTournamentExtras(String tournamentId) async {
    final doc = await _firestore.collection(tournamentsCollection).doc(tournamentId).get();
    final data = doc.data() ?? const {};
    return {
      'timeControl': data['timeControl'] as String? ?? '',
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
  ///
  /// Callable both as a manual organizer action (on an in-progress
  /// tournament, or as a retry on one whose bracket already auto-completed
  /// via [_advanceRoundIfComplete]) and automatically from
  /// [_advanceRoundIfComplete] once a winner is determined.
  Future<void> distributePrizes(String tournamentId) async {
    try {
      final tournamentRef =
          _firestore.collection(tournamentsCollection).doc(tournamentId);

      // Claim payout via a dedicated [prizesDistributedAt] field rather
      // than status == 'completed' - the bracket auto-completing
      // (_advanceRoundIfComplete) already sets status to 'completed' on
      // its own, independently of whether prizes have ever been paid, so
      // overloading that same value here previously made every
      // auto-completed tournament's prizes permanently unpayable (this
      // guard would always see 'completed' and skip, even on the very
      // first real payout attempt). This field is this guard's own
      // concern only; it's deliberately not surfaced on komovia_core's
      // Tournament model, the same way prizePool/timeControl aren't
      // (see [getTournamentExtras]).
      var claimed = false;
      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(tournamentRef);
        if (doc.data()?['prizesDistributedAt'] != null) {
          return;
        }
        transaction.update(tournamentRef, {
          'status': 'completed',
          'prizesDistributedAt': FieldValue.serverTimestamp(),
        });
        claimed = true;
      });

      if (!claimed) {
        debugPrint(
            'Tournament $tournamentId already had its prizes distributed; '
            'skipping duplicate payout');
        return;
      }

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
