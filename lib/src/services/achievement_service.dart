import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class AchievementService {
  factory AchievementService() => _instance;

  AchievementService._internal();
  static final AchievementService _instance = AchievementService._internal();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, List<AchievementDefinition>> _achievementCache = {};
  final Map<String, Timer> _cacheTimers = {};

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

      final achievements = snapshot.docs
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

  Future<AchievementProgress> getAchievementProgress(
      String userId, String achievementId) async {
    try {
      final achievementDef = await _firestore
          .collection('achievements')
          .doc('definitions')
          .collection('all')
          .doc(achievementId)
          .get();

      final userAchievement = await _firestore
          .collection('achievements')
          .doc('user_achievements')
          .collection(userId)
          .doc(achievementId)
          .get();

      final isUnlocked = userAchievement.exists;
      int currentValue = 0;

      if (!isUnlocked) {
        currentValue = await _calculateCurrentProgress(userId, achievementId);
      }

      return AchievementProgress(
        achievementId: achievementId,
        isUnlocked: isUnlocked,
        currentValue: currentValue,
        targetValue: achievementDef['condition']['targetValue'] ?? 0,
        unlockedAt: isUnlocked && userAchievement['unlockedAt'] != null
            ? (userAchievement['unlockedAt'] as Timestamp).toDate()
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
      final nearby = <NearbyAchievement>[];

      for (final achievement in allAchievements) {
        final progress =
            await getAchievementProgress(userId, achievement.achievementId);

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
      await _firestore
          .collection('achievements')
          .doc('user_achievements')
          .collection(userId)
          .doc(achievementId)
          .set({
        'userId': userId,
        'achievementId': achievementId,
        'unlockedAt': FieldValue.serverTimestamp(),
        'progressPercentage': 100,
      });
    } catch (e) {
      print('Error unlocking achievement: $e');
    }
  }

  Future<int> _calculateCurrentProgress(
      String userId, String achievementId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();

      // Placeholder: Calculate based on achievement type
      switch (achievementId) {
        case 'first_win':
          return (userDoc['wins'] ?? 0) > 0 ? 1 : 0;
        case 'five_wins':
          return userDoc['wins'] ?? 0;
        case 'puzzle_master':
          return userDoc['puzzlesCompleted'] ?? 0;
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
