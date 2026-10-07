import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';

/// Manages seasonal challenges and event-based objectives
class SeasonChallengeService {
  SeasonChallengeService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _firestore;
  final Logger _logger = Logger();

  static const String _challengesCollection = 'season_challenges';
  static const String _playerChallengeCollection = 'player_challenge_progress';

  /// Get all active challenges for a season
  Future<List<Challenge>> getChallenges({
    required String seasonId,
    String? type, // daily, weekly, seasonal, event
  }) async {
    try {
      Query query = _firestore
          .collection(_challengesCollection)
          .where('seasonId', isEqualTo: seasonId);

      if (type != null) {
        query = query.where('type', isEqualTo: type);
      }

      final snapshot = await query.get();

      return snapshot.docs
          .map((doc) => Challenge.fromJson(doc.data()! as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      _logger.e('Failed to get challenges', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Get challenges by difficulty tier
  Future<List<Challenge>> getChallengeTiers(
    String seasonId, {
    required String difficulty, // easy, medium, hard
  }) async {
    try {
      final snapshot = await _firestore
          .collection(_challengesCollection)
          .where('seasonId', isEqualTo: seasonId)
          .where('difficulty', isEqualTo: difficulty)
          .get();

      return snapshot.docs
          .map((doc) => Challenge.fromJson(doc.data()))
          .toList();
    } catch (e, st) {
      _logger.e('Failed to get challenge tiers', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Get player's progress on a challenge
  Future<PlayerChallengeProgress?> getPlayerChallengeProgress(
    String playerId,
    String challengeId,
  ) async {
    try {
      final doc = await _firestore
          .collection(_playerChallengeCollection)
          .doc(playerId)
          .collection('challenges')
          .doc(challengeId)
          .get();

      if (!doc.exists) {
        return null;
      }

      return PlayerChallengeProgress.fromJson(doc.data()!);
    } catch (e, st) {
      _logger.e('Failed to get player challenge progress',
          error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Mark challenge as completed
  Future<void> completeChallenge({
    required String playerId,
    required String challengeId,
  }) async {
    try {
      final progressRef = _firestore
          .collection(_playerChallengeCollection)
          .doc(playerId)
          .collection('challenges')
          .doc(challengeId);

      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(progressRef);

        if (doc.exists) {
          transaction.update(progressRef, {
            'isCompleted': true,
            'completedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          transaction.set(progressRef, {
            'playerId': playerId,
            'challengeId': challengeId,
            'currentProgress': 0,
            'targetProgress': 0,
            'isCompleted': true,
            'completedAt': FieldValue.serverTimestamp(),
            'startedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });

      _logger.i('Challenge completed: $challengeId by $playerId');
    } catch (e, st) {
      _logger.e('Failed to complete challenge', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Update challenge progress
  Future<void> updateChallengeProgress({
    required String playerId,
    required String challengeId,
    required int progressAmount,
  }) async {
    try {
      final progressRef = _firestore
          .collection(_playerChallengeCollection)
          .doc(playerId)
          .collection('challenges')
          .doc(challengeId);

      final challenge = await _getChallengeById(challengeId);
      if (challenge == null) {
        throw Exception('Challenge not found: $challengeId');
      }

      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(progressRef);

        if (!doc.exists) {
          transaction.set(progressRef, {
            'playerId': playerId,
            'challengeId': challengeId,
            'currentProgress': progressAmount,
            'targetProgress': challenge.target,
            'isCompleted': progressAmount >= challenge.target,
            'startedAt': FieldValue.serverTimestamp(),
            'completedAt': progressAmount >= challenge.target
                ? FieldValue.serverTimestamp()
                : null,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          final progress = PlayerChallengeProgress.fromJson(doc.data()!);
          final newProgress = progress.currentProgress + progressAmount;
          final isCompleted = newProgress >= challenge.target;

          transaction.update(progressRef, {
            'currentProgress': newProgress,
            'isCompleted': isCompleted,
            'completedAt': isCompleted ? FieldValue.serverTimestamp() : null,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });

      _logger.i('Updated challenge progress: $challengeId for $playerId');
    } catch (e, st) {
      _logger.e('Failed to update challenge progress',
          error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Get rewards for completing a challenge
  Future<List<ChallengeReward>> getChallengeRewards(
    String challengeId,
  ) async {
    try {
      final challenge = await _getChallengeById(challengeId);
      if (challenge == null) {
        return [];
      }

      return challenge.rewards;
    } catch (e, st) {
      _logger.e('Failed to get challenge rewards', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Get event-specific challenges
  Future<List<Challenge>> getEventChallenges(
    String seasonId, {
    required String eventId,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(_challengesCollection)
          .where('seasonId', isEqualTo: seasonId)
          .where('type', isEqualTo: 'event')
          .where('eventId', isEqualTo: eventId)
          .get();

      return snapshot.docs
          .map((doc) => Challenge.fromJson(doc.data()))
          .toList();
    } catch (e, st) {
      _logger.e('Failed to get event challenges', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Get all player challenges for a season
  Future<List<PlayerChallengeProgress>> getPlayerSeasonChallenges(
    String playerId,
    String seasonId,
  ) async {
    try {
      final seasonChallenges = await getChallenges(seasonId: seasonId);
      final progress = <PlayerChallengeProgress>[];

      for (final challenge in seasonChallenges) {
        final playerProgress = await getPlayerChallengeProgress(
          playerId,
          challenge.challengeId,
        );
        if (playerProgress != null) {
          progress.add(playerProgress);
        }
      }

      return progress;
    } catch (e, st) {
      _logger.e('Failed to get player season challenges',
          error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Helper: Get challenge by ID
  Future<Challenge?> _getChallengeById(String challengeId) async {
    try {
      final doc = await _firestore
          .collection(_challengesCollection)
          .doc(challengeId)
          .get();

      if (!doc.exists) {
        return null;
      }

      return Challenge.fromJson(doc.data()!);
    } catch (e, st) {
      _logger.e('Failed to get challenge by ID', error: e, stackTrace: st);
      return null;
    }
  }
}

/// Challenge definition
class Challenge {
  Challenge({
    required this.challengeId,
    required this.seasonId,
    required this.name,
    required this.description,
    required this.type,
    required this.objective,
    required this.target,
    required this.difficulty,
    required this.rewards,
    required this.startDate,
    required this.endDate,
    this.eventId,
  });

  factory Challenge.fromJson(Map<String, dynamic> json) => Challenge(
        challengeId: json['challengeId'] as String,
        seasonId: json['seasonId'] as String,
        name: json['name'] as String,
        description: json['description'] as String,
        type: json['type'] as String,
        eventId: json['eventId'] as String?,
        objective: json['objective'] as String,
        target: json['target'] as int,
        difficulty: json['difficulty'] as String,
        rewards: (json['rewards'] as List<dynamic>?)
                ?.map(
                    (r) => ChallengeReward.fromJson(r as Map<String, dynamic>))
                .toList() ??
            [],
        startDate: (json['startDate'] as Timestamp).toDate(),
        endDate: (json['endDate'] as Timestamp).toDate(),
      );
  final String challengeId;
  final String seasonId;
  final String name;
  final String description;
  final String type; // daily, weekly, seasonal, event
  final String? eventId; // if type == event
  final String objective; // e.g., "Win 5 games"
  final int target;
  final String difficulty; // easy, medium, hard
  final List<ChallengeReward> rewards;
  final DateTime startDate;
  final DateTime endDate;

  Map<String, dynamic> toJson() => {
        'challengeId': challengeId,
        'seasonId': seasonId,
        'name': name,
        'description': description,
        'type': type,
        'eventId': eventId,
        'objective': objective,
        'target': target,
        'difficulty': difficulty,
        'rewards': rewards.map((r) => r.toJson()).toList(),
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
      };
}

/// Challenge reward
class ChallengeReward {
  ChallengeReward({
    required this.type,
    required this.name,
    required this.amount,
    this.icon,
  });

  factory ChallengeReward.fromJson(Map<String, dynamic> json) =>
      ChallengeReward(
        type: json['type'] as String,
        name: json['name'] as String,
        amount: json['amount'] as int,
        icon: json['icon'] as String?,
      );
  final String type; // currency, experience, item
  final String name;
  final int amount;
  final String? icon;

  Map<String, dynamic> toJson() => {
        'type': type,
        'name': name,
        'amount': amount,
        'icon': icon,
      };
}

/// Player's progress on a challenge
class PlayerChallengeProgress {
  PlayerChallengeProgress({
    required this.playerId,
    required this.challengeId,
    required this.currentProgress,
    required this.targetProgress,
    required this.isCompleted,
    required this.startedAt,
    required this.updatedAt,
    this.completedAt,
  });

  factory PlayerChallengeProgress.fromJson(Map<String, dynamic> json) =>
      PlayerChallengeProgress(
        playerId: json['playerId'] as String,
        challengeId: json['challengeId'] as String,
        currentProgress: json['currentProgress'] as int? ?? 0,
        targetProgress: json['targetProgress'] as int? ?? 0,
        isCompleted: json['isCompleted'] as bool? ?? false,
        startedAt: json['startedAt'] != null
            ? (json['startedAt'] as Timestamp).toDate()
            : DateTime.now(),
        completedAt: json['completedAt'] != null
            ? (json['completedAt'] as Timestamp).toDate()
            : null,
        updatedAt: json['updatedAt'] != null
            ? (json['updatedAt'] as Timestamp).toDate()
            : DateTime.now(),
      );
  final String playerId;
  final String challengeId;
  final int currentProgress;
  final int targetProgress;
  final bool isCompleted;
  final DateTime startedAt;
  final DateTime? completedAt;
  final DateTime updatedAt;
}
