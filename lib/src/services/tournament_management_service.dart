import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';

/// Tournament creation, management, and lifecycle
class TournamentManagementService {
  TournamentManagementService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _firestore;
  final Logger _logger = Logger();

  static const String _tournamentsCollection = 'tournaments';
  static const String _participantsSubcollection = 'participants';
  static const String _matchesSubcollection = 'matches';

  /// Create a new tournament
  Future<Tournament> createTournament({
    required String name,
    required String description,
    required String format, // single_elimination, round_robin, swiss
    required String timeControl,
    required int maxParticipants,
    required DateTime startDate,
    required DateTime endDate,
    required int entryFee,
    required List<int> prizePool, // Prize amounts by placement
  }) async {
    try {
      final tournamentId =
          _firestore.collection(_tournamentsCollection).doc().id;
      final now = DateTime.now();

      final tournament = Tournament(
        tournamentId: tournamentId,
        name: name,
        description: description,
        format: format,
        timeControl: timeControl,
        maxParticipants: maxParticipants,
        currentParticipants: 0,
        status: 'registration', // registration, in_progress, completed
        startDate: startDate,
        endDate: endDate,
        entryFee: entryFee,
        prizePool: prizePool,
        createdAt: now,
        updatedAt: now,
      );

      await _firestore
          .collection(_tournamentsCollection)
          .doc(tournamentId)
          .set(tournament.toJson());

      _logger.i('Tournament created: $tournamentId ($name)');
      return tournament;
    } catch (e, st) {
      _logger.e('Failed to create tournament', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Register player for tournament
  Future<void> registerParticipant({
    required String tournamentId,
    required String playerId,
    required String playerName,
    required int playerRating,
  }) async {
    try {
      final tournamentDoc = await _firestore
          .collection(_tournamentsCollection)
          .doc(tournamentId)
          .get();

      if (!tournamentDoc.exists) {
        throw Exception('Tournament not found');
      }

      final tournamentData = tournamentDoc.data()!;
      final currentParticipants = tournamentData['currentParticipants'] as int;
      final maxParticipants = tournamentData['maxParticipants'] as int;

      if (currentParticipants >= maxParticipants) {
        throw Exception('Tournament is full');
      }

      final participantId = _firestore
          .collection(_tournamentsCollection)
          .doc(tournamentId)
          .collection(_participantsSubcollection)
          .doc()
          .id;

      final participant = TournamentParticipant(
        participantId: participantId,
        playerId: playerId,
        playerName: playerName,
        playerRating: playerRating,
        status: 'active', // active, eliminated, withdrawn
        wins: 0,
        losses: 0,
        draws: 0,
        points: 0,
        registerDate: DateTime.now(),
      );

      await _firestore
          .collection(_tournamentsCollection)
          .doc(tournamentId)
          .collection(_participantsSubcollection)
          .doc(participantId)
          .set(participant.toJson());

      // Update participant count
      await _firestore
          .collection(_tournamentsCollection)
          .doc(tournamentId)
          .update({
        'currentParticipants': currentParticipants + 1,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _logger.i('Player $playerId registered for tournament $tournamentId');
    } catch (e, st) {
      _logger.e('Failed to register participant', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Withdraw player from tournament
  Future<void> withdrawParticipant(String tournamentId, String playerId) async {
    try {
      final participantQuery = await _firestore
          .collection(_tournamentsCollection)
          .doc(tournamentId)
          .collection(_participantsSubcollection)
          .where('playerId', isEqualTo: playerId)
          .get();

      if (participantQuery.docs.isEmpty) {
        throw Exception('Participant not found');
      }

      await participantQuery.docs.first.reference.update({
        'status': 'withdrawn',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Decrease participant count
      await _firestore
          .collection(_tournamentsCollection)
          .doc(tournamentId)
          .update({
        'currentParticipants': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _logger.i('Player $playerId withdrawn from tournament $tournamentId');
    } catch (e, st) {
      _logger.e('Failed to withdraw participant', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Get tournament details
  Future<Tournament?> getTournament(String tournamentId) async {
    try {
      final doc = await _firestore
          .collection(_tournamentsCollection)
          .doc(tournamentId)
          .get();

      if (!doc.exists) {
        return null;
      }

      return Tournament.fromJson(doc.data()!);
    } catch (e, st) {
      _logger.e('Failed to get tournament', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Get tournament participants
  Future<List<TournamentParticipant>> getTournamentParticipants(
    String tournamentId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection(_tournamentsCollection)
          .doc(tournamentId)
          .collection(_participantsSubcollection)
          .get();

      return snapshot.docs
          .map((doc) => TournamentParticipant.fromJson(doc.data()))
          .toList();
    } catch (e, st) {
      _logger.e('Failed to get participants', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Start tournament and generate matches
  Future<void> startTournament(String tournamentId) async {
    try {
      final tournamentDoc = await _firestore
          .collection(_tournamentsCollection)
          .doc(tournamentId)
          .get();

      if (!tournamentDoc.exists) {
        throw Exception('Tournament not found');
      }

      final tournament = Tournament.fromJson(tournamentDoc.data()!);

      if (tournament.status != 'registration') {
        throw Exception('Tournament is not in registration phase');
      }

      // Update tournament status
      await _firestore
          .collection(_tournamentsCollection)
          .doc(tournamentId)
          .update({
        'status': 'in_progress',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _logger.i('Tournament $tournamentId started');
    } catch (e, st) {
      _logger.e('Failed to start tournament', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Complete tournament
  Future<void> completeTournament(
    String tournamentId,
    List<String> finalStandings,
  ) async {
    try {
      final tournamentDoc = await _firestore
          .collection(_tournamentsCollection)
          .doc(tournamentId)
          .get();

      if (!tournamentDoc.exists) {
        throw Exception('Tournament not found');
      }

      final tournament = Tournament.fromJson(tournamentDoc.data()!);

      // Distribute prizes
      await _distributePrizes(tournamentId, tournament, finalStandings);

      // Update tournament status
      await _firestore
          .collection(_tournamentsCollection)
          .doc(tournamentId)
          .update({
        'status': 'completed',
        'finalStandings': finalStandings,
        'completedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _logger.i('Tournament $tournamentId completed');
    } catch (e, st) {
      _logger.e('Failed to complete tournament', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Get tournament standings
  Future<List<TournamentStanding>> getTournamentStandings(
    String tournamentId,
  ) async {
    try {
      final participants = await getTournamentParticipants(tournamentId);

      final standings = participants
          .where((p) => p.status != 'eliminated')
          .map((p) => TournamentStanding(
                participantId: p.participantId,
                playerId: p.playerId,
                playerName: p.playerName,
                playerRating: p.playerRating,
                wins: p.wins,
                losses: p.losses,
                draws: p.draws,
                points: p.points,
                buchholzScore:
                    _calculateBuchholzScore(participants, p.playerId),
              ))
          .toList();

      // Sort by points, then by Buchholz score
      standings.sort((a, b) {
        final pointsDiff = b.points.compareTo(a.points);
        if (pointsDiff != 0) return pointsDiff;
        return b.buchholzScore.compareTo(a.buchholzScore);
      });

      return standings;
    } catch (e, st) {
      _logger.e('Failed to get standings', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Private helper methods

  Future<void> _distributePrizes(
    String tournamentId,
    Tournament tournament,
    List<String> finalStandings,
  ) async {
    try {
      for (int i = 0;
          i < finalStandings.length && i < tournament.prizePool.length;
          i++) {
        final participantId = finalStandings[i];
        final prizeAmount = tournament.prizePool[i];

        // Update participant prize
        final participantDoc = await _firestore
            .collection(_tournamentsCollection)
            .doc(tournamentId)
            .collection(_participantsSubcollection)
            .doc(participantId)
            .get();

        if (participantDoc.exists) {
          await participantDoc.reference.update({
            'prizeAmount': prizeAmount,
            'placement': i + 1,
          });
        }
      }

      _logger.i('Prizes distributed for tournament $tournamentId');
    } catch (e, st) {
      _logger.e('Failed to distribute prizes', error: e, stackTrace: st);
      rethrow;
    }
  }

  double _calculateBuchholzScore(
    List<TournamentParticipant> participants,
    String playerId,
  ) {
    // Sum of opponents' scores
    double score = 0;
    for (final participant in participants) {
      if (participant.playerId != playerId) {
        score += participant.points.toDouble();
      }
    }
    return score;
  }
}

/// Tournament data model
class Tournament {
  Tournament({
    required this.tournamentId,
    required this.name,
    required this.description,
    required this.format,
    required this.timeControl,
    required this.maxParticipants,
    required this.currentParticipants,
    required this.status,
    required this.startDate,
    required this.endDate,
    required this.entryFee,
    required this.prizePool,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
    this.finalStandings,
  });

  factory Tournament.fromJson(Map<String, dynamic> json) => Tournament(
        tournamentId: json['tournamentId'] as String,
        name: json['name'] as String,
        description: json['description'] as String,
        format: json['format'] as String,
        timeControl: json['timeControl'] as String,
        maxParticipants: json['maxParticipants'] as int,
        currentParticipants: json['currentParticipants'] as int,
        status: json['status'] as String,
        startDate: (json['startDate'] as Timestamp).toDate(),
        endDate: (json['endDate'] as Timestamp).toDate(),
        entryFee: json['entryFee'] as int,
        prizePool: List<int>.from(json['prizePool'] as List),
        createdAt: (json['createdAt'] as Timestamp).toDate(),
        updatedAt: (json['updatedAt'] as Timestamp).toDate(),
        completedAt: json['completedAt'] != null
            ? (json['completedAt'] as Timestamp).toDate()
            : null,
        finalStandings: json['finalStandings'] != null
            ? List<String>.from(json['finalStandings'] as List)
            : null,
      );
  final String tournamentId;
  final String name;
  final String description;
  final String format;
  final String timeControl;
  final int maxParticipants;
  final int currentParticipants;
  final String status;
  final DateTime startDate;
  final DateTime endDate;
  final int entryFee;
  final List<int> prizePool;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;
  final List<String>? finalStandings;

  Map<String, dynamic> toJson() => {
        'tournamentId': tournamentId,
        'name': name,
        'description': description,
        'format': format,
        'timeControl': timeControl,
        'maxParticipants': maxParticipants,
        'currentParticipants': currentParticipants,
        'status': status,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
        'entryFee': entryFee,
        'prizePool': prizePool,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
        'completedAt':
            completedAt != null ? Timestamp.fromDate(completedAt!) : null,
        'finalStandings': finalStandings,
      };
}

/// Tournament participant
class TournamentParticipant {
  TournamentParticipant({
    required this.participantId,
    required this.playerId,
    required this.playerName,
    required this.playerRating,
    required this.status,
    required this.wins,
    required this.losses,
    required this.draws,
    required this.points,
    required this.registerDate,
    this.prizeAmount,
    this.placement,
  });

  factory TournamentParticipant.fromJson(Map<String, dynamic> json) =>
      TournamentParticipant(
        participantId: json['participantId'] as String,
        playerId: json['playerId'] as String,
        playerName: json['playerName'] as String,
        playerRating: json['playerRating'] as int,
        status: json['status'] as String,
        wins: json['wins'] as int,
        losses: json['losses'] as int,
        draws: json['draws'] as int,
        points: json['points'] as int,
        registerDate: (json['registerDate'] as Timestamp).toDate(),
        prizeAmount: json['prizeAmount'] as int?,
        placement: json['placement'] as int?,
      );
  final String participantId;
  final String playerId;
  final String playerName;
  final int playerRating;
  final String status;
  int wins;
  int losses;
  int draws;
  int points;
  final DateTime registerDate;
  int? prizeAmount;
  int? placement;

  Map<String, dynamic> toJson() => {
        'participantId': participantId,
        'playerId': playerId,
        'playerName': playerName,
        'playerRating': playerRating,
        'status': status,
        'wins': wins,
        'losses': losses,
        'draws': draws,
        'points': points,
        'registerDate': Timestamp.fromDate(registerDate),
        'prizeAmount': prizeAmount,
        'placement': placement,
      };
}

/// Tournament standing in standings list
class TournamentStanding {
  TournamentStanding({
    required this.participantId,
    required this.playerId,
    required this.playerName,
    required this.playerRating,
    required this.wins,
    required this.losses,
    required this.draws,
    required this.points,
    required this.buchholzScore,
  });
  final String participantId;
  final String playerId;
  final String playerName;
  final int playerRating;
  final int wins;
  final int losses;
  final int draws;
  final int points;
  final double buchholzScore;
}
