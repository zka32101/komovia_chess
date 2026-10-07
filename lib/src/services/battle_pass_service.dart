import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';

/// Manages battle pass progression and rewards
class BattlePassService {
  BattlePassService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _firestore;
  final Logger _logger = Logger();

  static const String _battlePassCollection = 'battle_passes';
  static const String _playerBattlePassCollection = 'player_battle_passes';

  /// Create a new battle pass for a season
  Future<BattlePass> createBattlePass({
    required String seasonId,
    required String name,
    required int maxLevel,
    required List<BattlePassTier> tiers,
    required int experiencePerLevel,
  }) async {
    try {
      final battlePassId =
          _firestore.collection(_battlePassCollection).doc().id;
      final now = DateTime.now();

      final battlePass = BattlePass(
        battlePassId: battlePassId,
        seasonId: seasonId,
        name: name,
        maxLevel: maxLevel,
        tiers: tiers,
        experiencePerLevel: experiencePerLevel,
        createdAt: now,
        updatedAt: now,
      );

      await _firestore
          .collection(_battlePassCollection)
          .doc(battlePassId)
          .set(battlePass.toJson());

      _logger.i('Battle pass created: $battlePassId for season $seasonId');
      return battlePass;
    } catch (e, st) {
      _logger.e('Failed to create battle pass', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Get battle pass by ID
  Future<BattlePass?> getBattlePass(String battlePassId) async {
    try {
      final doc = await _firestore
          .collection(_battlePassCollection)
          .doc(battlePassId)
          .get();

      if (!doc.exists) {
        return null;
      }

      return BattlePass.fromJson(doc.data()!);
    } catch (e, st) {
      _logger.e('Failed to get battle pass', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Get battle pass for a season
  Future<BattlePass?> getBattlePassBySeasonId(String seasonId) async {
    try {
      final snapshot = await _firestore
          .collection(_battlePassCollection)
          .where('seasonId', isEqualTo: seasonId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      return BattlePass.fromJson(snapshot.docs.first.data());
    } catch (e, st) {
      _logger.e('Failed to get battle pass by season',
          error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Get player's battle pass progress
  Future<PlayerBattlePassProgress?> getPlayerBattlePassProgress(
    String playerId,
    String seasonId,
  ) async {
    try {
      final doc = await _firestore
          .collection(_playerBattlePassCollection)
          .doc(playerId)
          .collection('seasons')
          .doc(seasonId)
          .get();

      if (!doc.exists) {
        return null;
      }

      return PlayerBattlePassProgress.fromJson(doc.data()!);
    } catch (e, st) {
      _logger.e('Failed to get player battle pass progress',
          error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Claim a battle pass reward
  Future<void> claimBattlePassReward({
    required String playerId,
    required String seasonId,
    required int level,
    required bool isPremium,
  }) async {
    try {
      final progressRef = _firestore
          .collection(_playerBattlePassCollection)
          .doc(playerId)
          .collection('seasons')
          .doc(seasonId);

      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(progressRef);

        if (doc.exists) {
          final progress = PlayerBattlePassProgress.fromJson(doc.data()!);

          List<int> claimed;
          if (isPremium) {
            claimed = [...progress.claimedPremiumRewards];
          } else {
            claimed = [...progress.claimedFreeRewards];
          }

          if (!claimed.contains(level)) {
            claimed.add(level);

            if (isPremium) {
              transaction.update(progressRef, {
                'claimedPremiumRewards': claimed,
                'updatedAt': FieldValue.serverTimestamp(),
              });
            } else {
              transaction.update(progressRef, {
                'claimedFreeRewards': claimed,
                'updatedAt': FieldValue.serverTimestamp(),
              });
            }
          }
        }
      });

      _logger.i(
          'Reward claimed by $playerId for level $level (premium: $isPremium)');
    } catch (e, st) {
      _logger.e('Failed to claim battle pass reward', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Get all tiers for a battle pass
  Future<List<BattlePassTier>> getBattlePassTiers(String battlePassId) async {
    try {
      final battlePass = await getBattlePass(battlePassId);
      if (battlePass == null) {
        return [];
      }

      return battlePass.tiers;
    } catch (e, st) {
      _logger.e('Failed to get battle pass tiers', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Upgrade to premium battle pass
  Future<void> upgradeToPremiumPass({
    required String playerId,
    required String seasonId,
  }) async {
    try {
      final progressRef = _firestore
          .collection(_playerBattlePassCollection)
          .doc(playerId)
          .collection('seasons')
          .doc(seasonId);

      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(progressRef);

        if (!doc.exists) {
          // Initialize with premium pass
          transaction.set(progressRef, {
            'playerId': playerId,
            'seasonId': seasonId,
            'currentLevel': 1,
            'currentExperience': 0,
            'hasPremiumPass': true,
            'claimedFreeRewards': <int>[],
            'claimedPremiumRewards': <int>[],
            'purchasedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          transaction.update(progressRef, {
            'hasPremiumPass': true,
            'purchasedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });

      _logger.i('Premium pass upgraded for $playerId in season $seasonId');
    } catch (e, st) {
      _logger.e('Failed to upgrade to premium pass', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Add experience to player's battle pass
  Future<void> addBattlePassExperience({
    required String playerId,
    required String seasonId,
    required int experienceAmount,
  }) async {
    try {
      final progressRef = _firestore
          .collection(_playerBattlePassCollection)
          .doc(playerId)
          .collection('seasons')
          .doc(seasonId);

      final battlePass = await getBattlePassBySeasonId(seasonId);
      if (battlePass == null) {
        throw Exception('Battle pass not found for season $seasonId');
      }

      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(progressRef);

        if (!doc.exists) {
          // Initialize new battle pass progress
          transaction.set(progressRef, {
            'playerId': playerId,
            'seasonId': seasonId,
            'currentLevel': 1,
            'currentExperience': experienceAmount,
            'hasPremiumPass': false,
            'claimedFreeRewards': <int>[],
            'claimedPremiumRewards': <int>[],
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          final progress = PlayerBattlePassProgress.fromJson(doc.data()!);
          int newExp = progress.currentExperience + experienceAmount;
          int newLevel = progress.currentLevel;

          // Level up if experience exceeds requirement
          while (newExp >= battlePass.experiencePerLevel &&
              newLevel < battlePass.maxLevel) {
            newExp -= battlePass.experiencePerLevel;
            newLevel++;
          }

          transaction.update(progressRef, {
            'currentExperience': newExp,
            'currentLevel': newLevel,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });

      _logger.i('Added $experienceAmount exp to battle pass for $playerId');
    } catch (e, st) {
      _logger.e('Failed to add battle pass experience',
          error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Get claimed rewards for player
  Future<List<int>> getClaimedRewards({
    required String playerId,
    required String seasonId,
    required bool isPremium,
  }) async {
    try {
      final progress = await getPlayerBattlePassProgress(playerId, seasonId);
      if (progress == null) {
        return [];
      }

      return isPremium
          ? progress.claimedPremiumRewards
          : progress.claimedFreeRewards;
    } catch (e, st) {
      _logger.e('Failed to get claimed rewards', error: e, stackTrace: st);
      rethrow;
    }
  }
}

/// Battle pass configuration
class BattlePass {
  BattlePass({
    required this.battlePassId,
    required this.seasonId,
    required this.name,
    required this.maxLevel,
    required this.tiers,
    required this.experiencePerLevel,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BattlePass.fromJson(Map<String, dynamic> json) => BattlePass(
        battlePassId: json['battlePassId'] as String,
        seasonId: json['seasonId'] as String,
        name: json['name'] as String,
        maxLevel: json['maxLevel'] as int,
        tiers: (json['tiers'] as List<dynamic>?)
                ?.map((t) => BattlePassTier.fromJson(t as Map<String, dynamic>))
                .toList() ??
            [],
        experiencePerLevel: json['experiencePerLevel'] as int,
        createdAt: (json['createdAt'] as Timestamp).toDate(),
        updatedAt: (json['updatedAt'] as Timestamp).toDate(),
      );
  final String battlePassId;
  final String seasonId;
  final String name;
  final int maxLevel;
  final List<BattlePassTier> tiers;
  final int experiencePerLevel;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
        'battlePassId': battlePassId,
        'seasonId': seasonId,
        'name': name,
        'maxLevel': maxLevel,
        'tiers': tiers.map((t) => t.toJson()).toList(),
        'experiencePerLevel': experiencePerLevel,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };
}

/// Individual battle pass tier
class BattlePassTier {
  BattlePassTier({
    required this.level,
    required this.name,
    required this.icon,
    required this.experienceRequired,
    required this.freeRewards,
    required this.premiumRewards,
    this.isLocked = false,
  });

  factory BattlePassTier.fromJson(Map<String, dynamic> json) => BattlePassTier(
        level: json['level'] as int,
        name: json['name'] as String,
        icon: json['icon'] as String,
        experienceRequired: json['experienceRequired'] as int,
        freeRewards: (json['freeRewards'] as List<dynamic>?)
                ?.map(
                    (r) => BattlePassReward.fromJson(r as Map<String, dynamic>))
                .toList() ??
            [],
        premiumRewards: (json['premiumRewards'] as List<dynamic>?)
                ?.map(
                    (r) => BattlePassReward.fromJson(r as Map<String, dynamic>))
                .toList() ??
            [],
        isLocked: json['isLocked'] as bool? ?? false,
      );
  final int level;
  final String name;
  final String icon;
  final int experienceRequired;
  final List<BattlePassReward> freeRewards;
  final List<BattlePassReward> premiumRewards;
  final bool isLocked;

  Map<String, dynamic> toJson() => {
        'level': level,
        'name': name,
        'icon': icon,
        'experienceRequired': experienceRequired,
        'freeRewards': freeRewards.map((r) => r.toJson()).toList(),
        'premiumRewards': premiumRewards.map((r) => r.toJson()).toList(),
        'isLocked': isLocked,
      };
}

/// Battle pass reward item
class BattlePassReward {
  // amount, rarity, etc.

  BattlePassReward({
    required this.rewardId,
    required this.type,
    required this.name,
    required this.description,
    required this.icon,
    required this.value,
  });

  factory BattlePassReward.fromJson(Map<String, dynamic> json) =>
      BattlePassReward(
        rewardId: json['rewardId'] as String,
        type: json['type'] as String,
        name: json['name'] as String,
        description: json['description'] as String,
        icon: json['icon'] as String,
        value: json['value'] as Map<String, dynamic>? ?? {},
      );
  final String rewardId;
  final String type; // cosmetic, currency, item, battle_pass
  final String name;
  final String description;
  final String icon;
  final Map<String, dynamic> value;

  Map<String, dynamic> toJson() => {
        'rewardId': rewardId,
        'type': type,
        'name': name,
        'description': description,
        'icon': icon,
        'value': value,
      };
}

/// Player's battle pass progress
class PlayerBattlePassProgress {
  PlayerBattlePassProgress({
    required this.playerId,
    required this.seasonId,
    required this.currentLevel,
    required this.currentExperience,
    required this.hasPremiumPass,
    required this.claimedFreeRewards,
    required this.claimedPremiumRewards,
    required this.updatedAt,
    this.purchasedAt,
  });

  factory PlayerBattlePassProgress.fromJson(Map<String, dynamic> json) =>
      PlayerBattlePassProgress(
        playerId: json['playerId'] as String,
        seasonId: json['seasonId'] as String,
        currentLevel: json['currentLevel'] as int? ?? 1,
        currentExperience: json['currentExperience'] as int? ?? 0,
        hasPremiumPass: json['hasPremiumPass'] as bool? ?? false,
        claimedFreeRewards:
            List<int>.from(json['claimedFreeRewards'] as List? ?? []),
        claimedPremiumRewards:
            List<int>.from(json['claimedPremiumRewards'] as List? ?? []),
        purchasedAt: json['purchasedAt'] != null
            ? (json['purchasedAt'] as Timestamp).toDate()
            : null,
        updatedAt: json['updatedAt'] != null
            ? (json['updatedAt'] as Timestamp).toDate()
            : DateTime.now(),
      );
  final String playerId;
  final String seasonId;
  final int currentLevel;
  final int currentExperience;
  final bool hasPremiumPass;
  final List<int> claimedFreeRewards;
  final List<int> claimedPremiumRewards;
  final DateTime? purchasedAt;
  final DateTime updatedAt;
}
