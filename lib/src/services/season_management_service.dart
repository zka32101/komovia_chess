import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';

/// Manages seasonal lifecycle, configuration, and progression
class SeasonManagementService {
  SeasonManagementService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _firestore;
  final Logger _logger = Logger();

  static const String _seasonsCollection = 'seasons';
  static const String _playerSeasonsCollection = 'player_seasons';

  /// Create a new season
  Future<Season> createSeason({
    required String name,
    required String description,
    required int seasonNumber,
    required DateTime startDate,
    required DateTime endDate,
    required String theme,
    required int maxLevel,
  }) async {
    try {
      final seasonId = _firestore.collection(_seasonsCollection).doc().id;
      final now = DateTime.now();

      final season = Season(
        seasonId: seasonId,
        name: name,
        description: description,
        seasonNumber: seasonNumber,
        startDate: startDate,
        endDate: endDate,
        status: 'upcoming',
        theme: theme,
        maxLevel: maxLevel,
        createdAt: now,
        updatedAt: now,
      );

      await _firestore
          .collection(_seasonsCollection)
          .doc(seasonId)
          .set(season.toJson());

      _logger.i('Season created: $seasonId ($name)');
      return season;
    } catch (e, st) {
      _logger.e('Failed to create season', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Get current active season
  Future<Season?> getCurrentSeason() async {
    try {
      final now = DateTime.now();

      final snapshot = await _firestore
          .collection(_seasonsCollection)
          .where('startDate', isLessThanOrEqualTo: now)
          .where('endDate', isGreaterThanOrEqualTo: now)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      return Season.fromJson(snapshot.docs.first.data());
    } catch (e, st) {
      _logger.e('Failed to get current season', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Get season by ID
  Future<Season?> getSeasonById(String seasonId) async {
    try {
      final doc =
          await _firestore.collection(_seasonsCollection).doc(seasonId).get();

      if (!doc.exists) {
        return null;
      }

      return Season.fromJson(doc.data()!);
    } catch (e, st) {
      _logger.e('Failed to get season', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Activate a season (change from upcoming to active)
  Future<void> activateSeason(String seasonId) async {
    try {
      await _firestore.collection(_seasonsCollection).doc(seasonId).update({
        'status': 'active',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _logger.i('Season activated: $seasonId');
    } catch (e, st) {
      _logger.e('Failed to activate season', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Complete a season (change from active to completed)
  Future<void> completeSeason(String seasonId) async {
    try {
      await _firestore.collection(_seasonsCollection).doc(seasonId).update({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _logger.i('Season completed: $seasonId');
    } catch (e, st) {
      _logger.e('Failed to complete season', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Get player's seasonal progress
  Future<PlayerSeasonProgress?> getPlayerSeasonProgress(
    String playerId,
    String seasonId,
  ) async {
    try {
      final doc = await _firestore
          .collection(_playerSeasonsCollection)
          .doc(playerId)
          .collection('seasons')
          .doc(seasonId)
          .get();

      if (!doc.exists) {
        return null;
      }

      return PlayerSeasonProgress.fromJson(doc.data()!);
    } catch (e, st) {
      _logger.e('Failed to get player season progress',
          error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Update player seasonal experience
  Future<void> addSeasonalExperience({
    required String playerId,
    required String seasonId,
    required int experienceAmount,
  }) async {
    try {
      final progressRef = _firestore
          .collection(_playerSeasonsCollection)
          .doc(playerId)
          .collection('seasons')
          .doc(seasonId);

      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(progressRef);

        if (!doc.exists) {
          // Initialize new season progress
          transaction.set(progressRef, {
            'playerId': playerId,
            'seasonId': seasonId,
            'currentLevel': 1,
            'totalExperience': experienceAmount,
            'seasonRating': 1200,
            'startedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          // Update existing progress
          transaction.update(progressRef, {
            'totalExperience': FieldValue.increment(experienceAmount),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });

      _logger
          .i('Added $experienceAmount exp to $playerId for season $seasonId');
    } catch (e, st) {
      _logger.e('Failed to add seasonal experience', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Get all seasons with pagination
  Future<List<Season>> getAllSeasons({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(_seasonsCollection)
          .orderBy('startDate', descending: true)
          .limit(limit + offset)
          .get();

      final seasons = <Season>[];
      for (int i = offset;
          i < snapshot.docs.length && i < offset + limit;
          i++) {
        seasons.add(Season.fromJson(snapshot.docs[i].data()));
      }

      return seasons;
    } catch (e, st) {
      _logger.e('Failed to get all seasons', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Get upcoming seasons
  Future<List<Season>> getUpcomingSeasons() async {
    try {
      final now = DateTime.now();

      final snapshot = await _firestore
          .collection(_seasonsCollection)
          .where('status', isEqualTo: 'upcoming')
          .where('startDate', isGreaterThan: now)
          .orderBy('startDate')
          .limit(5)
          .get();

      return snapshot.docs.map((doc) => Season.fromJson(doc.data())).toList();
    } catch (e, st) {
      _logger.e('Failed to get upcoming seasons', error: e, stackTrace: st);
      rethrow;
    }
  }
}

/// Season data model
class Season {
  Season({
    required this.seasonId,
    required this.name,
    required this.description,
    required this.seasonNumber,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.theme,
    required this.maxLevel,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
  });

  factory Season.fromJson(Map<String, dynamic> json) => Season(
        seasonId: json['seasonId'] as String,
        name: json['name'] as String,
        description: json['description'] as String,
        seasonNumber: json['seasonNumber'] as int,
        startDate: (json['startDate'] as Timestamp).toDate(),
        endDate: (json['endDate'] as Timestamp).toDate(),
        status: json['status'] as String,
        theme: json['theme'] as String,
        maxLevel: json['maxLevel'] as int,
        createdAt: (json['createdAt'] as Timestamp).toDate(),
        updatedAt: (json['updatedAt'] as Timestamp).toDate(),
        completedAt: json['completedAt'] != null
            ? (json['completedAt'] as Timestamp).toDate()
            : null,
      );
  final String seasonId;
  final String name;
  final String description;
  final int seasonNumber;
  final DateTime startDate;
  final DateTime endDate;
  final String status; // upcoming, active, completed
  final String theme;
  final int maxLevel;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;

  Map<String, dynamic> toJson() => {
        'seasonId': seasonId,
        'name': name,
        'description': description,
        'seasonNumber': seasonNumber,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
        'status': status,
        'theme': theme,
        'maxLevel': maxLevel,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
        'completedAt':
            completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      };
}

/// Player's seasonal progress
class PlayerSeasonProgress {
  PlayerSeasonProgress({
    required this.playerId,
    required this.seasonId,
    required this.currentLevel,
    required this.totalExperience,
    required this.seasonRating,
    required this.challengesCompleted,
    required this.eventsParticipated,
    required this.startedAt,
    required this.updatedAt,
  });

  factory PlayerSeasonProgress.fromJson(Map<String, dynamic> json) =>
      PlayerSeasonProgress(
        playerId: json['playerId'] as String,
        seasonId: json['seasonId'] as String,
        currentLevel: json['currentLevel'] as int? ?? 1,
        totalExperience: json['totalExperience'] as int? ?? 0,
        seasonRating: json['seasonRating'] as int? ?? 1200,
        challengesCompleted:
            List<String>.from(json['challengesCompleted'] as List? ?? []),
        eventsParticipated:
            List<String>.from(json['eventsParticipated'] as List? ?? []),
        startedAt: json['startedAt'] != null
            ? (json['startedAt'] as Timestamp).toDate()
            : DateTime.now(),
        updatedAt: json['updatedAt'] != null
            ? (json['updatedAt'] as Timestamp).toDate()
            : DateTime.now(),
      );
  final String playerId;
  final String seasonId;
  final int currentLevel;
  final int totalExperience;
  final int seasonRating;
  final List<String> challengesCompleted;
  final List<String> eventsParticipated;
  final DateTime startedAt;
  final DateTime updatedAt;
}
