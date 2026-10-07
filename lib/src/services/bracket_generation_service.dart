import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import 'dart:math';

/// Bracket generation for different tournament formats
class BracketGenerationService {
  BracketGenerationService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _firestore;
  final Logger _logger = Logger();

  static const String _tournamentsCollection = 'tournaments';
  static const String _participantsSubcollection = 'participants';
  static const String _bracketSubcollection = 'bracket';
  static const String _matchesSubcollection = 'matches';

  /// Generate bracket based on tournament format
  Future<void> generateBracket(
    String tournamentId,
    String format,
    List<String> participants,
  ) async {
    try {
      if (format == 'single_elimination') {
        await _generateSingleEliminationBracket(tournamentId, participants);
      } else if (format == 'round_robin') {
        await _generateRoundRobinBracket(tournamentId, participants);
      } else if (format == 'swiss') {
        await _generateSwissBracket(tournamentId, participants);
      } else {
        throw Exception('Unknown tournament format: $format');
      }

      _logger.i('Bracket generated for tournament $tournamentId');
    } catch (e, st) {
      _logger.e('Failed to generate bracket', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Generate single elimination bracket
  Future<void> _generateSingleEliminationBracket(
    String tournamentId,
    List<String> participants,
  ) async {
    final shuffled = List<String>.from(participants);
    shuffled.shuffle();

    final totalRounds = _calculateRounds(shuffled.length);
    int matchNumber = 1;

    // Generate first round
    for (int i = 0; i < shuffled.length; i += 2) {
      final player1 = shuffled[i];
      final player2 = i + 1 < shuffled.length ? shuffled[i + 1] : null;

      final match = TournamentMatch(
        matchId: '$tournamentId-$matchNumber',
        player1Id: player1,
        player2Id: player2,
        round: 1,
        status: 'scheduled',
        scheduledTime: DateTime.now().add(Duration(hours: matchNumber)),
      );

      await _firestore
          .collection(_tournamentsCollection)
          .doc(tournamentId)
          .collection(_matchesSubcollection)
          .doc(match.matchId)
          .set(match.toJson());

      matchNumber++;
    }
  }

  /// Generate round-robin bracket
  Future<void> _generateRoundRobinBracket(
    String tournamentId,
    List<String> participants,
  ) async {
    int matchNumber = 1;

    // Generate all pairings
    for (int i = 0; i < participants.length; i++) {
      for (int j = i + 1; j < participants.length; j++) {
        final match = TournamentMatch(
          matchId: '$tournamentId-$matchNumber',
          player1Id: participants[i],
          player2Id: participants[j],
          round: 1,
          status: 'scheduled',
          scheduledTime: DateTime.now().add(Duration(hours: matchNumber * 2)),
        );

        await _firestore
            .collection(_tournamentsCollection)
            .doc(tournamentId)
            .collection(_matchesSubcollection)
            .doc(match.matchId)
            .set(match.toJson());

        matchNumber++;
      }
    }
  }

  /// Generate Swiss system bracket (first round)
  Future<void> _generateSwissBracket(
    String tournamentId,
    List<String> participants,
  ) async {
    // For first round, pair by rating proximity
    final sorted = List<String>.from(participants);
    int matchNumber = 1;

    for (int i = 0; i < sorted.length; i += 2) {
      final player1 = sorted[i];
      final player2 = i + 1 < sorted.length ? sorted[i + 1] : null;

      if (player2 != null) {
        final match = TournamentMatch(
          matchId: '$tournamentId-$matchNumber',
          player1Id: player1,
          player2Id: player2,
          round: 1,
          status: 'scheduled',
          scheduledTime: DateTime.now().add(Duration(hours: matchNumber)),
        );

        await _firestore
            .collection(_tournamentsCollection)
            .doc(tournamentId)
            .collection(_matchesSubcollection)
            .doc(match.matchId)
            .set(match.toJson());

        matchNumber++;
      }
    }
  }

  /// Get bracket matches for a round
  Future<List<TournamentMatch>> getBracketRound(
    String tournamentId,
    int round,
  ) async {
    try {
      final snapshot = await _firestore
          .collection(_tournamentsCollection)
          .doc(tournamentId)
          .collection(_matchesSubcollection)
          .where('round', isEqualTo: round)
          .orderBy('scheduledTime')
          .get();

      return snapshot.docs
          .map((doc) => TournamentMatch.fromJson(doc.data()))
          .toList();
    } catch (e, st) {
      _logger.e('Failed to get bracket round', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Record match result
  Future<void> recordMatchResult({
    required String tournamentId,
    required String matchId,
    required String winnerId,
    String? result, // white_win, black_win, draw
  }) async {
    try {
      final matchDoc = await _firestore
          .collection(_tournamentsCollection)
          .doc(tournamentId)
          .collection(_matchesSubcollection)
          .doc(matchId)
          .get();

      if (!matchDoc.exists) {
        throw Exception('Match not found');
      }

      final match = TournamentMatch.fromJson(matchDoc.data()!);

      // Determine loser and points
      final loserId =
          match.player1Id == winnerId ? match.player2Id : match.player1Id;
      int winnerPoints = 1;
      int loserPoints = 0;

      if (result == 'draw') {
        winnerPoints = 0; // Draw handling
        loserPoints = 0;
      }

      // Update participants
      final participantsRef = _firestore
          .collection(_tournamentsCollection)
          .doc(tournamentId)
          .collection('participants');

      final winnerDoc =
          await participantsRef.where('playerId', isEqualTo: winnerId).get();
      final loserDoc =
          await participantsRef.where('playerId', isEqualTo: loserId).get();

      if (winnerDoc.docs.isNotEmpty) {
        await winnerDoc.docs.first.reference.update({
          'wins': FieldValue.increment(1),
          'points': FieldValue.increment(winnerPoints),
        });
      }

      if (loserDoc.docs.isNotEmpty && loserId != null) {
        await loserDoc.docs.first.reference.update({
          'losses': FieldValue.increment(1),
          'points': FieldValue.increment(loserPoints),
        });
      }

      // Update match result
      await matchDoc.reference.update({
        'status': 'completed',
        'winnerId': winnerId,
        'result': result ?? 'white_win',
        'completedAt': FieldValue.serverTimestamp(),
      });

      _logger.i('Match $matchId result recorded: $winnerId won');
    } catch (e, st) {
      _logger.e('Failed to record match result', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Private helper methods

  int _calculateRounds(int participants) {
    if (participants <= 1) return 1;
    return (log(participants) / log(2)).ceil();
  }
}

/// Tournament match
class TournamentMatch {
  TournamentMatch({
    required this.matchId,
    required this.player1Id,
    required this.round,
    required this.status,
    required this.scheduledTime,
    this.player2Id,
    this.winnerId,
    this.result,
    this.completedAt,
  });

  factory TournamentMatch.fromJson(Map<String, dynamic> json) =>
      TournamentMatch(
        matchId: json['matchId'] as String,
        player1Id: json['player1Id'] as String,
        player2Id: json['player2Id'] as String?,
        round: json['round'] as int,
        status: json['status'] as String,
        scheduledTime: (json['scheduledTime'] as Timestamp).toDate(),
        winnerId: json['winnerId'] as String?,
        result: json['result'] as String?,
        completedAt: json['completedAt'] != null
            ? (json['completedAt'] as Timestamp).toDate()
            : null,
      );
  final String matchId;
  final String player1Id;
  final String? player2Id;
  final int round;
  final String status; // scheduled, in_progress, completed
  final DateTime scheduledTime;
  String? winnerId;
  String? result;
  DateTime? completedAt;

  Map<String, dynamic> toJson() => {
        'matchId': matchId,
        'player1Id': player1Id,
        'player2Id': player2Id,
        'round': round,
        'status': status,
        'scheduledTime': Timestamp.fromDate(scheduledTime),
        'winnerId': winnerId,
        'result': result,
        'completedAt':
            completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      };
}
