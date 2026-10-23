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

  /// Advance every currently-active challenge in [seasonId] whose
  /// [Challenge.resolvedMetricType] matches [metric] by [amount] - the
  /// entry point every reachable gameplay-completion flow calls (online
  /// PvP win/loss/draw, CPU-game win/loss/draw, puzzle solve). Previously
  /// nothing in the app ever called `updateChallengeProgress`/
  /// `completeChallenge` at all, so no seasonal challenge could progress
  /// through actual play, only be looked at. Best-effort: a failure here
  /// (e.g. no active season) never blocks or surfaces to the game/puzzle
  /// flow that triggered it.
  Future<void> recordMetricProgress({
    required String playerId,
    required String seasonId,
    required String metric,
    int amount = 1,
  }) async {
    try {
      final now = DateTime.now();
      final challenges = await getChallenges(seasonId: seasonId);
      for (final challenge in challenges) {
        if (challenge.resolvedMetricType != metric) continue;
        if (now.isBefore(challenge.startDate) || now.isAfter(challenge.endDate)) {
          continue;
        }
        await updateChallengeProgress(
          playerId: playerId,
          challengeId: challenge.challengeId,
          progressAmount: amount,
        );
      }
    } catch (e, st) {
      _logger.e('Failed to record metric progress', error: e, stackTrace: st);
    }
  }

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
          // Same cap as the update branch below - progressAmount could
          // in principle exceed challenge.target on a single call (e.g.
          // a future caller passing a batched amount), which without
          // clamping would both write a currentProgress above
          // targetProgress (wrong progress-bar percentages) and, since
          // firestore.rules' create rule only checks playerId and has no
          // bound on the initial value, is the one write path a client
          // could otherwise use to directly create an already-completed
          // challenge.
          final initialProgress = progressAmount.clamp(0, challenge.target);
          transaction.set(progressRef, {
            'playerId': playerId,
            'challengeId': challengeId,
            'currentProgress': initialProgress,
            'targetProgress': challenge.target,
            'isCompleted': initialProgress >= challenge.target,
            'startedAt': FieldValue.serverTimestamp(),
            'completedAt': initialProgress >= challenge.target
                ? FieldValue.serverTimestamp()
                : null,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          final progress = PlayerChallengeProgress.fromJson(doc.data()!);
          // recordMetricProgress has no notion of "already complete" and
          // keeps calling this after every matching game/puzzle for the
          // rest of the season - without capping, currentProgress grew
          // unbounded past targetProgress (wrong progress bars/
          // percentages anywhere this is rendered), and completedAt kept
          // getting re-stamped to "now" on every later call instead of
          // staying at the moment the challenge actually finished.
          // int.clamp returns num, not int - leaving it unconverted would
          // write a double to Firestore and break the next read's
          // `json['currentProgress'] as int?` cast.
          final newProgress =
              (progress.currentProgress + progressAmount)
                  .clamp(0, challenge.target)
                  .toInt();
          final isCompleted = newProgress >= challenge.target;
          final justCompleted = isCompleted && !progress.isCompleted;

          transaction.update(progressRef, {
            'currentProgress': newProgress,
            'isCompleted': isCompleted,
            if (justCompleted) 'completedAt': FieldValue.serverTimestamp(),
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
    this.metricType,
  });

  factory Challenge.fromJson(Map<String, dynamic> json) => Challenge(
        challengeId: json['challengeId'] as String,
        seasonId: json['seasonId'] as String,
        name: json['name'] as String,
        description: json['description'] as String,
        type: json['type'] as String,
        eventId: json['eventId'] as String?,
        objective: json['objective'] as String,
        metricType: json['metricType'] as String?,
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

  /// Machine-readable gameplay metric this challenge tracks - one of
  /// [GameplayMetric]'s keys. No curated `season_challenges` document in
  /// this app currently sets this (there's no in-app content-authoring
  /// tool for this collection, which is `allow write: if false` in
  /// firestore.rules), so it's nullable and [resolvedMetricType] falls
  /// back to guessing from the free-text [objective] for any existing/
  /// future document that never sets it explicitly.
  final String? metricType;

  /// Best-effort inference from [objective]'s free text when [metricType]
  /// isn't set - a real curated challenge document should set
  /// [metricType] directly instead of relying on this.
  String? get resolvedMetricType {
    if (metricType != null) return metricType;
    final text = objective.toLowerCase();
    if (text.contains('puzzle')) return GameplayMetric.solvePuzzles;
    // 'win' is checked before 'draw' - an objective mentioning both (e.g.
    // "Win or draw 10 games") previously fell through to drawGames since
    // the 'draw' check ran first and short-circuited, silently
    // misrouting progress tracking for any such challenge text.
    if (text.contains('win')) return GameplayMetric.winGames;
    if (text.contains('draw')) return GameplayMetric.drawGames;
    if (text.contains('game') || text.contains('play')) {
      return GameplayMetric.playGames;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'challengeId': challengeId,
        'seasonId': seasonId,
        'name': name,
        'description': description,
        'type': type,
        'eventId': eventId,
        'objective': objective,
        'metricType': metricType,
        'target': target,
        'difficulty': difficulty,
        'rewards': rewards.map((r) => r.toJson()).toList(),
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
      };
}

/// The gameplay events a challenge's progress can be driven by - see
/// [SeasonChallengeService.recordMetricProgress], called from every
/// reachable game/puzzle-completion flow (online PvP, CPU games, puzzles).
abstract class GameplayMetric {
  static const String winGames = 'win_games';
  static const String playGames = 'play_games';
  static const String drawGames = 'draw_games';
  static const String solvePuzzles = 'solve_puzzles';
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
