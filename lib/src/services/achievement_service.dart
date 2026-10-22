import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class AchievementService {
  factory AchievementService() => _instance;

  AchievementService._internal();
  static final AchievementService _instance = AchievementService._internal();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, List<AchievementDefinition>> _achievementCache = {};
  final Map<String, Timer> _cacheTimers = {};

  /// Fetches `users/{userId}` once, for callers (like
  /// `userAchievementProgressProvider`) that otherwise evaluate
  /// [getAchievementProgress] once per achievement definition and would
  /// each independently re-read the same doc.
  Future<DocumentSnapshot<Map<String, dynamic>>> getUserDocSnapshot(
          String userId) =>
      _firestore.collection('users').doc(userId).get();

  Future<List<UserAchievement>> getUserAchievements(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('achievements')
          .doc('user_achievements')
          .collection(userId)
          .get();

      return snapshot.docs
          .map((doc) => UserAchievement.fromJson(doc.data()))
          .toList();
    } catch (e) {
      print('Error fetching user achievements: $e');
      return [];
    }
  }

  /// Baseline achievements shown when nothing has been curated into
  /// `achievements/definitions/all` yet (that collection has no in-repo
  /// seed script, same situation as this app's other curated/admin-only
  /// content) - `_calculateCurrentProgress` already special-cases exactly
  /// these 3 ids, so the feature has something real to unlock out of the
  /// box rather than being an empty list until an admin populates one.
  static final List<AchievementDefinition> _bootstrapDefinitions = [
    AchievementDefinition(
      achievementId: 'first_win',
      name: 'First Victory',
      description: 'Win your first game',
      icon: '🏆',
      tier: 'Bronze',
      condition: const {'targetValue': 1},
      points: 10,
      isHidden: false,
    ),
    AchievementDefinition(
      achievementId: 'five_wins',
      name: 'Rising Star',
      description: 'Win 5 games',
      icon: '⭐',
      tier: 'Silver',
      condition: const {'targetValue': 5},
      points: 25,
      isHidden: false,
    ),
    AchievementDefinition(
      achievementId: 'puzzle_master',
      name: 'Puzzle Master',
      description: 'Complete 20 tactics puzzles',
      icon: '🧩',
      tier: 'Gold',
      condition: const {'targetValue': 20},
      points: 50,
      isHidden: false,
    ),
  ];

  Future<List<AchievementDefinition>> getAllAchievements() async {
    if (_achievementCache.containsKey('all')) {
      return _achievementCache['all']!;
    }

    try {
      final snapshot = await _firestore
          .collection('achievements')
          .doc('definitions')
          .collection('all')
          .get();

      final achievements = snapshot.docs.isEmpty
          ? _bootstrapDefinitions
          : snapshot.docs
              .map((doc) => AchievementDefinition.fromJson(doc.data()))
              .toList();

      _achievementCache['all'] = achievements;

      // Cancel existing timer if present
      _cacheTimers['all']?.cancel();

      // Set new timer for cache invalidation
      _cacheTimers['all'] = Timer(const Duration(hours: 1), () {
        _achievementCache.remove('all');
        _cacheTimers.remove('all');
      });

      return achievements;
    } catch (e) {
      print('Error fetching all achievements: $e');
      return [];
    }
  }

  /// [userDoc], when given, is used instead of a fresh `users/{userId}`
  /// read - callers that already evaluate progress for several
  /// achievements in one invocation (checkAndUnlockAchievements,
  /// getNearbyAchievements) fetch it once and pass it to every call
  /// here, rather than each call independently re-reading the same
  /// unchanging-within-this-invocation user doc.
  Future<AchievementProgress> getAchievementProgress(
      String userId, String achievementId,
      {DocumentSnapshot<Map<String, dynamic>>? userDoc}) async {
    try {
      // Resolved through getAllAchievements() (bootstrap-fallback aware)
      // rather than a raw doc read, since `achievements/definitions/all`
      // may not have a real doc for this id at all when falling back to
      // _bootstrapDefinitions. Cached in-process for an hour, so this is
      // a real Firestore read only on a cold cache, never per-call.
      final allAchievements = await getAllAchievements();
      final def = allAchievements.firstWhere(
        (a) => a.achievementId == achievementId,
        orElse: () => AchievementDefinition(
          achievementId: achievementId,
          name: achievementId,
          description: '',
          icon: '',
          tier: 'Bronze',
          condition: const {},
          points: 0,
          isHidden: false,
        ),
      );
      final targetValue = (def.condition['targetValue'] as num?)?.toInt() ?? 0;

      final userAchievement = await _firestore
          .collection('achievements')
          .doc('user_achievements')
          .collection(userId)
          .doc(achievementId)
          .get();

      final isUnlocked = userAchievement.exists;
      int currentValue = 0;

      if (!isUnlocked) {
        currentValue = await _calculateCurrentProgress(userId, achievementId,
            userDoc: userDoc);
      }

      final unlockedData = userAchievement.data();
      return AchievementProgress(
        achievementId: achievementId,
        isUnlocked: isUnlocked,
        currentValue: currentValue,
        targetValue: targetValue,
        unlockedAt: isUnlocked && unlockedData?['unlockedAt'] != null
            ? (unlockedData!['unlockedAt'] as Timestamp).toDate()
            : null,
      );
    } catch (e) {
      print('Error fetching achievement progress: $e');
      return AchievementProgress(
        achievementId: achievementId,
        isUnlocked: false,
        currentValue: 0,
        targetValue: 0,
      );
    }
  }

  Future<List<NearbyAchievement>> getNearbyAchievements(String userId) async {
    try {
      final allAchievements = await getAllAchievements();
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final nearby = <NearbyAchievement>[];

      for (final achievement in allAchievements) {
        final progress = await getAchievementProgress(
            userId, achievement.achievementId,
            userDoc: userDoc);

        if (!progress.isUnlocked) {
          final progressPercent = progress.targetValue > 0
              ? (progress.currentValue / progress.targetValue * 100)
                  .clamp(0.0, 100.0)
              : 0.0;

          if (progressPercent >= 75) {
            nearby.add(NearbyAchievement(
              achievement: achievement,
              currentValue: progress.currentValue,
              targetValue: progress.targetValue,
              progressPercentage: progressPercent,
            ));
          }
        }
      }

      return nearby;
    } catch (e) {
      print('Error fetching nearby achievements: $e');
      return [];
    }
  }

  Future<void> unlockAchievement(String userId, String achievementId) async {
    try {
      final ref = _firestore
          .collection('achievements')
          .doc('user_achievements')
          .collection(userId)
          .doc(achievementId);
      // Re-checks existence inside the transaction rather than trusting
      // checkAndUnlockAchievements' own earlier (non-transactional) read
      // - this mirrors the fix already applied to the Cloud Functions
      // side (functions/src/achievement-service.js) that never made it
      // over to this Dart copy. checkAndUnlockAchievements runs
      // fire-and-forget from both a CPU game win and an online game win;
      // two near-simultaneous unlocks for the same user (e.g. finishing
      // an online game right as a CPU game also concludes) could both
      // see the achievement as not-yet-unlocked and both call set(),
      // re-stamping unlockedAt with a later timestamp than the player's
      // true first unlock.
      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(ref);
        if (doc.exists) return;
        transaction.set(ref, {
          'userId': userId,
          'achievementId': achievementId,
          'unlockedAt': FieldValue.serverTimestamp(),
          'progressPercentage': 100,
        });
      });
    } catch (e) {
      print('Error unlocking achievement: $e');
    }
  }

  /// Evaluates every achievement's current progress for [userId] and
  /// unlocks any that have newly reached their target. Nothing called
  /// `unlockAchievement` anywhere before this - best-effort by design
  /// (swallows its own errors) since it's meant to run as a fire-and-forget
  /// side effect of things like a game ending, never block them.
  Future<void> checkAndUnlockAchievements(String userId) async {
    try {
      final definitions = await getAllAchievements();
      final userDoc = await _firestore.collection('users').doc(userId).get();
      for (final def in definitions) {
        final progress = await getAchievementProgress(
            userId, def.achievementId,
            userDoc: userDoc);
        if (!progress.isUnlocked &&
            progress.targetValue > 0 &&
            progress.currentValue >= progress.targetValue) {
          await unlockAchievement(userId, def.achievementId);
        }
      }
    } catch (e) {
      print('Error checking achievements for unlock: $e');
    }
  }

  Future<int> _calculateCurrentProgress(
      String userId, String achievementId,
      {DocumentSnapshot<Map<String, dynamic>>? userDoc}) async {
    try {
      final doc =
          userDoc ?? await _firestore.collection('users').doc(userId).get();
      final data = doc.data() ?? const <String, dynamic>{};
      final wins = (data['wins'] as num?)?.toInt() ?? 0;
      // PuzzleService.recordPuzzleAttempt writes this as `puzzlesSolved`
      // (same field `getUserPuzzleStats`/the puzzle screen read) - this
      // read used the nonexistent name `puzzlesCompleted`, which nothing
      // in the app ever wrote, so puzzle_master could never progress
      // past 0 regardless of how many puzzles were solved.
      final puzzlesSolved = (data['puzzlesSolved'] as num?)?.toInt() ?? 0;

      switch (achievementId) {
        case 'first_win':
          return wins > 0 ? 1 : 0;
        case 'five_wins':
          return wins;
        case 'puzzle_master':
          return puzzlesSolved;
        default:
          return 0;
      }
    } catch (e) {
      print('Error calculating progress: $e');
      return 0;
    }
  }
}

class AchievementDefinition {
  AchievementDefinition({
    required this.achievementId,
    required this.name,
    required this.description,
    required this.icon,
    required this.tier,
    required this.condition,
    required this.points,
    required this.isHidden,
  });

  factory AchievementDefinition.fromJson(Map<String, dynamic> json) =>
      AchievementDefinition(
        achievementId: json['achievementId'] ?? '',
        name: json['name'] ?? '',
        description: json['description'] ?? '',
        icon: json['icon'] ?? '',
        tier: json['tier'] ?? 'Bronze',
        condition: json['condition'] ?? {},
        points: json['points'] ?? 0,
        isHidden: json['isHidden'] ?? false,
      );
  final String achievementId;
  final String name;
  final String description;
  final String icon;
  final String tier;
  final Map<String, dynamic> condition;
  final int points;
  final bool isHidden;
}

class UserAchievement {
  UserAchievement({
    required this.userId,
    required this.achievementId,
    required this.unlockedAt,
    required this.progressPercentage,
  });

  factory UserAchievement.fromJson(Map<String, dynamic> json) =>
      UserAchievement(
        userId: json['userId'] ?? '',
        achievementId: json['achievementId'] ?? '',
        unlockedAt: json['unlockedAt'] != null
            ? (json['unlockedAt'] as Timestamp).toDate()
            : DateTime.now(),
        progressPercentage: json['progressPercentage'] ?? 0,
      );
  final String userId;
  final String achievementId;
  final DateTime unlockedAt;
  final int progressPercentage;
}

class AchievementProgress {
  AchievementProgress({
    required this.achievementId,
    required this.isUnlocked,
    required this.currentValue,
    required this.targetValue,
    this.unlockedAt,
  });
  final String achievementId;
  final bool isUnlocked;
  final int currentValue;
  final int targetValue;
  final DateTime? unlockedAt;

  double get progressPercentage =>
      targetValue > 0 ? (currentValue / targetValue * 100).clamp(0, 100) : 0;
}

class NearbyAchievement {
  NearbyAchievement({
    required this.achievement,
    required this.currentValue,
    required this.targetValue,
    required this.progressPercentage,
  });
  final AchievementDefinition achievement;
  final int currentValue;
  final int targetValue;
  final double progressPercentage;
}
