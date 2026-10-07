import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';

/// Handles reward distribution and item management
class SeasonalRewardService {
  SeasonalRewardService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _firestore;
  final Logger _logger = Logger();

  static const String _rewardsCollection = 'seasonal_rewards';
  static const String _playerRewardHistoryCollection = 'player_reward_history';
  static const String _rewardCodesCollection = 'reward_codes';

  /// Get rewards by type
  Future<List<Reward>> getRewardsByType({
    required String seasonId,
    required String type, // battle_pass, challenge, event, seasonal_end
  }) async {
    try {
      final snapshot = await _firestore
          .collection(_rewardsCollection)
          .where('seasonId', isEqualTo: seasonId)
          .where('type', isEqualTo: type)
          .get();

      return snapshot.docs.map((doc) => Reward.fromJson(doc.data())).toList();
    } catch (e, st) {
      _logger.e('Failed to get rewards by type', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Distribute season reward to player
  Future<void> distributeSeasonReward({
    required String playerId,
    required String seasonId,
    required String rewardId,
  }) async {
    try {
      final reward = await _getRewardById(rewardId);
      if (reward == null) {
        throw Exception('Reward not found: $rewardId');
      }

      await _firestore.runTransaction((transaction) async {
        final historyRef = _firestore
            .collection(_playerRewardHistoryCollection)
            .doc(playerId)
            .collection('rewards')
            .doc();

        transaction.set(historyRef, {
          'playerId': playerId,
          'seasonId': seasonId,
          'rewardId': rewardId,
          'rewardType': reward.type,
          'items': reward.items.map((i) => i.toJson()).toList(),
          'claimedAt': FieldValue.serverTimestamp(),
          'isRead': false,
        });
      });

      _logger.i('Reward distributed to $playerId: $rewardId');
    } catch (e, st) {
      _logger.e('Failed to distribute season reward', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Track reward claim
  Future<void> trackRewardClaim({
    required String playerId,
    required String rewardId,
    required String historyId,
  }) async {
    try {
      await _firestore
          .collection(_playerRewardHistoryCollection)
          .doc(playerId)
          .collection('rewards')
          .doc(historyId)
          .update({
        'isClaimed': true,
        'claimedAt': FieldValue.serverTimestamp(),
      });

      _logger.i('Reward claim tracked: $rewardId for $playerId');
    } catch (e, st) {
      _logger.e('Failed to track reward claim', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Get player's reward history
  Future<List<PlayerRewardHistory>> getPlayerRewardHistory({
    required String playerId,
    String? seasonId,
    int limit = 50,
  }) async {
    try {
      Query query = _firestore
          .collection(_playerRewardHistoryCollection)
          .doc(playerId)
          .collection('rewards')
          .orderBy('claimedAt', descending: true)
          .limit(limit);

      if (seasonId != null) {
        query = query.where('seasonId', isEqualTo: seasonId);
      }

      final snapshot = await query.get();

      return snapshot.docs
          .map((doc) =>
              PlayerRewardHistory.fromJson(doc.data()! as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      _logger.e('Failed to get player reward history',
          error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Calculate season-end rewards
  Future<List<Reward>> calculateSeasonEndRewards({
    required String playerId,
    required String seasonId,
  }) async {
    try {
      // Get player's season stats
      final playerSeasonRef = _firestore
          .collection('player_seasons')
          .doc(playerId)
          .collection('seasons')
          .doc(seasonId);

      final playerSeasonDoc = await playerSeasonRef.get();
      if (!playerSeasonDoc.exists) {
        return [];
      }

      final seasonRating = playerSeasonDoc['seasonRating'] as int? ?? 1200;
      final levelReached = playerSeasonDoc['currentLevel'] as int? ?? 1;

      // Get end-season reward tiers
      final snapshot = await _firestore
          .collection(_rewardsCollection)
          .where('seasonId', isEqualTo: seasonId)
          .where('type', isEqualTo: 'seasonal_end')
          .get();

      final rewards = <Reward>[];
      for (final doc in snapshot.docs) {
        final reward = Reward.fromJson(doc.data());

        // Filter by player achievement level
        if (reward.requirements?['minLevel'] != null) {
          if (levelReached >= (reward.requirements!['minLevel'] as int)) {
            rewards.add(reward);
          }
        } else {
          rewards.add(reward);
        }
      }

      return rewards;
    } catch (e, st) {
      _logger.e('Failed to calculate season-end rewards',
          error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Redeem promotional reward code
  Future<bool> redeemRewardCode({
    required String playerId,
    required String code,
  }) async {
    try {
      final result = await _firestore.runTransaction((transaction) async {
        final codeDoc = await transaction.get(
          _firestore.collection(_rewardCodesCollection).doc(code),
        );

        if (!codeDoc.exists) {
          return false;
        }

        final rewardCode = RewardCode.fromJson(codeDoc.data()!);

        // Check validity
        if (!rewardCode.isActive ||
            DateTime.now().isAfter(rewardCode.expiresAt)) {
          return false;
        }

        // Check redemption limit
        if (rewardCode.currentRedemptions >= rewardCode.maxRedemptions) {
          return false;
        }

        // Award reward
        final historyRef = _firestore
            .collection(_playerRewardHistoryCollection)
            .doc(playerId)
            .collection('rewards')
            .doc();

        transaction.set(historyRef, {
          'playerId': playerId,
          'rewardCode': code,
          'items': rewardCode.reward,
          'claimedAt': FieldValue.serverTimestamp(),
          'isClaimed': true,
          'source': 'code_redemption',
        });

        // Increment redemption count
        transaction.update(codeDoc.reference, {
          'currentRedemptions': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        return true;
      });

      if (result) {
        _logger.i('Reward code redeemed: $code for $playerId');
      }
      return result;
    } catch (e, st) {
      _logger.e('Failed to redeem reward code', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Check if code has been used by player
  Future<bool> hasPlayerRedeemedCode({
    required String playerId,
    required String code,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(_playerRewardHistoryCollection)
          .doc(playerId)
          .collection('rewards')
          .where('rewardCode', isEqualTo: code)
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e, st) {
      _logger.e('Failed to check code redemption', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Helper: Get reward by ID
  Future<Reward?> _getRewardById(String rewardId) async {
    try {
      final doc =
          await _firestore.collection(_rewardsCollection).doc(rewardId).get();

      if (!doc.exists) {
        return null;
      }

      return Reward.fromJson(doc.data()!);
    } catch (e, st) {
      _logger.e('Failed to get reward by ID', error: e, stackTrace: st);
      return null;
    }
  }
}

/// Reward definition
class Reward {
  Reward({
    required this.rewardId,
    required this.seasonId,
    required this.type,
    required this.name,
    required this.description,
    required this.items,
    required this.rarity,
    required this.createdAt,
    this.requirements,
  });

  factory Reward.fromJson(Map<String, dynamic> json) => Reward(
        rewardId: json['rewardId'] as String,
        seasonId: json['seasonId'] as String,
        type: json['type'] as String,
        name: json['name'] as String,
        description: json['description'] as String,
        items: (json['items'] as List<dynamic>?)
                ?.map((i) => RewardItem.fromJson(i as Map<String, dynamic>))
                .toList() ??
            [],
        rarity: json['rarity'] as String? ?? 'common',
        requirements: json['requirements'] as Map<String, dynamic>?,
        createdAt: (json['createdAt'] as Timestamp).toDate(),
      );
  final String rewardId;
  final String seasonId;
  final String type; // battle_pass, challenge, event, seasonal_end
  final String name;
  final String description;
  final List<RewardItem> items;
  final String rarity; // common, rare, epic, legendary
  final Map<String, dynamic>? requirements; // minLevel, minRating, etc.
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'rewardId': rewardId,
        'seasonId': seasonId,
        'type': type,
        'name': name,
        'description': description,
        'items': items.map((i) => i.toJson()).toList(),
        'rarity': rarity,
        'requirements': requirements,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}

/// Individual reward item
class RewardItem {
  RewardItem({
    required this.itemId,
    required this.type,
    required this.name,
    required this.quantity,
    this.icon,
  });

  factory RewardItem.fromJson(Map<String, dynamic> json) => RewardItem(
        itemId: json['itemId'] as String,
        type: json['type'] as String,
        name: json['name'] as String,
        quantity: json['quantity'] as int,
        icon: json['icon'] as String?,
      );
  final String itemId;
  final String type; // currency, cosmetic, battle_pass_level
  final String name;
  final int quantity;
  final String? icon;

  Map<String, dynamic> toJson() => {
        'itemId': itemId,
        'type': type,
        'name': name,
        'quantity': quantity,
        'icon': icon,
      };
}

/// Player's reward history entry
class PlayerRewardHistory {
  PlayerRewardHistory({
    required this.playerId,
    required this.rewardType,
    required this.items,
    required this.claimedAt,
    this.seasonId,
    this.rewardId,
    this.rewardCode,
    this.isClaimed = false,
    this.isRead = false,
  });

  factory PlayerRewardHistory.fromJson(Map<String, dynamic> json) =>
      PlayerRewardHistory(
        playerId: json['playerId'] as String,
        seasonId: json['seasonId'] as String?,
        rewardId: json['rewardId'] as String?,
        rewardCode: json['rewardCode'] as String?,
        rewardType: json['rewardType'] as String,
        items: (json['items'] as List<dynamic>?)
                ?.map((i) => RewardItem.fromJson(i as Map<String, dynamic>))
                .toList() ??
            [],
        claimedAt: (json['claimedAt'] as Timestamp).toDate(),
        isClaimed: json['isClaimed'] as bool? ?? false,
        isRead: json['isRead'] as bool? ?? false,
      );
  final String playerId;
  final String? seasonId;
  final String? rewardId;
  final String? rewardCode;
  final String rewardType;
  final List<RewardItem> items;
  final DateTime claimedAt;
  final bool isClaimed;
  final bool isRead;
}

/// Promotional reward code
class RewardCode {
  RewardCode({
    required this.code,
    required this.reward,
    required this.maxRedemptions,
    required this.currentRedemptions,
    required this.expiresAt,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RewardCode.fromJson(Map<String, dynamic> json) => RewardCode(
        code: json['code'] as String,
        reward: json['reward'] as Map<String, dynamic>? ?? {},
        maxRedemptions: json['maxRedemptions'] as int,
        currentRedemptions: json['currentRedemptions'] as int? ?? 0,
        expiresAt: (json['expiresAt'] as Timestamp).toDate(),
        isActive: json['isActive'] as bool? ?? true,
        createdAt: (json['createdAt'] as Timestamp).toDate(),
        updatedAt: (json['updatedAt'] as Timestamp).toDate(),
      );
  final String code;
  final Map<String, dynamic> reward; // reward items
  final int maxRedemptions;
  final int currentRedemptions;
  final DateTime expiresAt;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
}
