import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';

/// Manages time-limited events and special modes
class SeasonalEventService {
  SeasonalEventService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _firestore;
  final Logger _logger = Logger();

  static const String _eventsCollection = 'seasonal_events';
  static const String _playerEventCollection = 'player_event_progress';

  /// Get all active events for a season
  Future<List<SeasonalEvent>> getActiveEvents({
    required String seasonId,
  }) async {
    try {
      final now = DateTime.now();

      final snapshot = await _firestore
          .collection(_eventsCollection)
          .where('seasonId', isEqualTo: seasonId)
          .where('startDate', isLessThanOrEqualTo: now)
          .where('endDate', isGreaterThanOrEqualTo: now)
          .get();

      return snapshot.docs
          .map((doc) => SeasonalEvent.fromJson(doc.data()))
          .toList();
    } catch (e, st) {
      _logger.e('Failed to get active events', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Get event details by ID
  Future<SeasonalEvent?> getEventDetails(String eventId) async {
    try {
      final doc =
          await _firestore.collection(_eventsCollection).doc(eventId).get();

      if (!doc.exists) {
        return null;
      }

      return SeasonalEvent.fromJson(doc.data()!);
    } catch (e, st) {
      _logger.e('Failed to get event details', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Get player's event participation
  Future<EventParticipation?> getPlayerEventProgress(
    String playerId,
    String eventId,
  ) async {
    try {
      final doc = await _firestore
          .collection(_playerEventCollection)
          .doc(playerId)
          .collection('events')
          .doc(eventId)
          .get();

      if (!doc.exists) {
        return null;
      }

      return EventParticipation.fromJson(doc.data()!);
    } catch (e, st) {
      _logger.e('Failed to get player event progress',
          error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Register player for event
  Future<void> participateInEvent({
    required String playerId,
    required String eventId,
  }) async {
    try {
      final event = await getEventDetails(eventId);
      if (event == null) {
        throw Exception('Event not found: $eventId');
      }

      final participationRef = _firestore
          .collection(_playerEventCollection)
          .doc(playerId)
          .collection('events')
          .doc(eventId);

      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(participationRef);

        if (!doc.exists) {
          transaction.set(participationRef, {
            'playerId': playerId,
            'eventId': eventId,
            'seasonId': event.seasonId,
            'joinedAt': FieldValue.serverTimestamp(),
            'currentScore': 0,
            'rank': -1,
            'hasWithdrawn': false,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          // Increment participant count
          transaction.update(
            _firestore.collection(_eventsCollection).doc(eventId),
            {'currentParticipants': FieldValue.increment(1)},
          );
        }
      });

      _logger.i('Player $playerId joined event $eventId');
    } catch (e, st) {
      _logger.e('Failed to participate in event', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Withdraw from event
  Future<void> withdrawFromEvent({
    required String playerId,
    required String eventId,
  }) async {
    try {
      final participationRef = _firestore
          .collection(_playerEventCollection)
          .doc(playerId)
          .collection('events')
          .doc(eventId);

      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(participationRef);

        if (doc.exists) {
          transaction.update(participationRef, {
            'hasWithdrawn': true,
            'withdrawnAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

          // Decrement participant count
          transaction.update(
            _firestore.collection(_eventsCollection).doc(eventId),
            {'currentParticipants': FieldValue.increment(-1)},
          );
        }
      });

      _logger.i('Player $playerId withdrew from event $eventId');
    } catch (e, st) {
      _logger.e('Failed to withdraw from event', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Update player's event score
  Future<void> updateEventScore({
    required String playerId,
    required String eventId,
    required int scoreIncrease,
  }) async {
    try {
      final participationRef = _firestore
          .collection(_playerEventCollection)
          .doc(playerId)
          .collection('events')
          .doc(eventId);

      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(participationRef);

        if (doc.exists) {
          transaction.update(participationRef, {
            'currentScore': FieldValue.increment(scoreIncrease),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });

      _logger.i('Updated score for $playerId in event $eventId');
    } catch (e, st) {
      _logger.e('Failed to update event score', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Get event leaderboard
  Future<List<EventLeaderboardEntry>> getEventLeaderboard(
    String eventId, {
    int limit = 100,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(_playerEventCollection)
          .doc(eventId)
          .collection('leaderboard')
          .orderBy('rank')
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => EventLeaderboardEntry.fromJson(doc.data()))
          .toList();
    } catch (e, st) {
      _logger.e('Failed to get event leaderboard', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Get top ranked event participants
  Future<List<EventParticipation>> getTopEventParticipants(
    String eventId, {
    int limit = 50,
  }) async {
    try {
      final snapshot = await _firestore
          .collectionGroup('events')
          .where('eventId', isEqualTo: eventId)
          .orderBy('currentScore', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => EventParticipation.fromJson(doc.data()))
          .toList();
    } catch (e, st) {
      _logger.e('Failed to get top event participants',
          error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Get event rewards
  Future<List<EventReward>> getEventRewards(String eventId) async {
    try {
      final event = await getEventDetails(eventId);
      if (event == null) {
        return [];
      }

      return event.rewards;
    } catch (e, st) {
      _logger.e('Failed to get event rewards', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Distribute event completion rewards
  Future<void> distributeEventReward({
    required String playerId,
    required String eventId,
    required int rank,
  }) async {
    try {
      final event = await getEventDetails(eventId);
      if (event == null) {
        throw Exception('Event not found: $eventId');
      }

      // Find reward tier for this rank
      EventReward? rewardTier;
      for (final reward in event.rewards) {
        if (rank >= reward.minRank && rank <= reward.maxRank) {
          rewardTier = reward;
          break;
        }
      }

      if (rewardTier == null) {
        _logger.w('No reward tier found for rank $rank in event $eventId');
        return;
      }

      // Record reward in player history
      final historyRef = _firestore
          .collection('player_reward_history')
          .doc(playerId)
          .collection('rewards')
          .doc();

      await historyRef.set({
        'playerId': playerId,
        'eventId': eventId,
        'seasonId': event.seasonId,
        'rank': rank,
        'reward': rewardTier.toJson(),
        'claimedAt': FieldValue.serverTimestamp(),
        'isClaimed': false,
        'source': 'event',
      });

      _logger.i(
          'Event reward distributed to $playerId for rank $rank in event $eventId');
    } catch (e, st) {
      _logger.e('Failed to distribute event reward', error: e, stackTrace: st);
      rethrow;
    }
  }
}

/// Seasonal event
class SeasonalEvent {
  SeasonalEvent({
    required this.eventId,
    required this.seasonId,
    required this.name,
    required this.description,
    required this.type,
    required this.startDate,
    required this.endDate,
    required this.maxParticipants,
    required this.currentParticipants,
    required this.rewards,
    required this.isActive,
    this.bannerUrl,
  });

  factory SeasonalEvent.fromJson(Map<String, dynamic> json) => SeasonalEvent(
        eventId: json['eventId'] as String,
        seasonId: json['seasonId'] as String,
        name: json['name'] as String,
        description: json['description'] as String,
        type: json['type'] as String,
        startDate: (json['startDate'] as Timestamp).toDate(),
        endDate: (json['endDate'] as Timestamp).toDate(),
        maxParticipants: json['maxParticipants'] as int,
        currentParticipants: json['currentParticipants'] as int? ?? 0,
        rewards: (json['rewards'] as List<dynamic>?)
                ?.map((r) => EventReward.fromJson(r as Map<String, dynamic>))
                .toList() ??
            [],
        isActive: json['isActive'] as bool? ?? true,
        bannerUrl: json['bannerUrl'] as String?,
      );
  final String eventId;
  final String seasonId;
  final String name;
  final String description;
  final String type; // tournament, challenge_rush, rating_boost
  final DateTime startDate;
  final DateTime endDate;
  final int maxParticipants;
  final int currentParticipants;
  final List<EventReward> rewards;
  final bool isActive;
  final String? bannerUrl;

  Map<String, dynamic> toJson() => {
        'eventId': eventId,
        'seasonId': seasonId,
        'name': name,
        'description': description,
        'type': type,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
        'maxParticipants': maxParticipants,
        'currentParticipants': currentParticipants,
        'rewards': rewards.map((r) => r.toJson()).toList(),
        'isActive': isActive,
        'bannerUrl': bannerUrl,
      };
}

/// Event participation record
class EventParticipation {
  EventParticipation({
    required this.playerId,
    required this.eventId,
    required this.seasonId,
    required this.joinedAt,
    required this.currentScore,
    required this.rank,
    required this.hasWithdrawn,
    required this.updatedAt,
    this.withdrawnAt,
  });

  factory EventParticipation.fromJson(Map<String, dynamic> json) =>
      EventParticipation(
        playerId: json['playerId'] as String,
        eventId: json['eventId'] as String,
        seasonId: json['seasonId'] as String,
        joinedAt: (json['joinedAt'] as Timestamp).toDate(),
        currentScore: json['currentScore'] as int? ?? 0,
        rank: json['rank'] as int? ?? -1,
        hasWithdrawn: json['hasWithdrawn'] as bool? ?? false,
        withdrawnAt: json['withdrawnAt'] != null
            ? (json['withdrawnAt'] as Timestamp).toDate()
            : null,
        updatedAt: (json['updatedAt'] as Timestamp).toDate(),
      );
  final String playerId;
  final String eventId;
  final String seasonId;
  final DateTime joinedAt;
  final int currentScore;
  final int rank;
  final bool hasWithdrawn;
  final DateTime? withdrawnAt;
  final DateTime updatedAt;
}

/// Event leaderboard entry
class EventLeaderboardEntry {
  EventLeaderboardEntry({
    required this.playerId,
    required this.username,
    required this.rank,
    required this.score,
    required this.timestamp,
    this.avatar,
  });

  factory EventLeaderboardEntry.fromJson(Map<String, dynamic> json) =>
      EventLeaderboardEntry(
        playerId: json['playerId'] as String,
        username: json['username'] as String,
        rank: json['rank'] as int,
        score: json['score'] as int,
        avatar: json['avatar'] as String?,
        timestamp: (json['timestamp'] as Timestamp).toDate(),
      );
  final String playerId;
  final String username;
  final int rank;
  final int score;
  final String? avatar;
  final DateTime timestamp;
}

/// Event reward tier
class EventReward {
  // common, rare, epic, legendary

  EventReward({
    required this.minRank,
    required this.maxRank,
    required this.rewardType,
    required this.rewards,
    required this.rarity,
  });

  factory EventReward.fromJson(Map<String, dynamic> json) => EventReward(
        minRank: json['minRank'] as int,
        maxRank: json['maxRank'] as int,
        rewardType: json['rewardType'] as String,
        rewards: json['rewards'] as Map<String, dynamic>? ?? {},
        rarity: json['rarity'] as String? ?? 'common',
      );
  final int minRank;
  final int maxRank;
  final String rewardType; // championship, participation
  final Map<String, dynamic> rewards; // items and amounts
  final String rarity;

  Map<String, dynamic> toJson() => {
        'minRank': minRank,
        'maxRank': maxRank,
        'rewardType': rewardType,
        'rewards': rewards,
        'rarity': rarity,
      };
}
