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

  /// Get current active season
  ///
  /// Nothing anywhere in this app (nor any Cloud Function) has ever
  /// created a document in the `seasons` collection - there's no
  /// season-lifecycle job and no admin tooling to seed one, so this
  /// query always returned zero documents in a real deployment. Every
  /// consumer that already correctly gates on `getCurrentSeason()` being
  /// non-null before calling into battle pass XP, season challenges, or
  /// seasonal event score (see cpu_game_provider.dart/
  /// online_game_service.dart/puzzle_provider.dart, and
  /// seasonal_hub_screen.dart's "No active season" branch) was therefore
  /// permanently dead code, regardless of how correctly any of it was
  /// wired up. Falls back to a synthesized "current calendar month"
  /// season when the collection is empty - same bootstrap-fallback
  /// pattern AchievementService._bootstrapDefinitions already uses for
  /// its own never-seeded curated collection, kept purely in-memory
  /// (never written back) since `seasons` is genuinely admin/curated
  /// content this service has no business writing to.
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
        return _bootstrapCurrentSeason();
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
        // The one id getCurrentSeason() can ever hand out when `seasons`
        // is empty - keeps SeasonProgressCard's own getSeasonById(season.
        // seasonId) re-lookup (seasonal_hub_screen.dart's real UI path)
        // from seeing a real season from getCurrentSeason() but then a
        // null from this method for the exact same id.
        final bootstrap = _bootstrapCurrentSeason();
        if (bootstrap.seasonId == seasonId) return bootstrap;
        return null;
      }

      return Season.fromJson(doc.data()!);
    } catch (e, st) {
      _logger.e('Failed to get season', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// A deterministic, in-memory "current calendar month" season - stable
  /// across calls within the same month (so battle pass XP/challenge/
  /// event progress keyed by this seasonId doesn't fragment across
  /// different synthetic ids), never persisted to Firestore.
  Season _bootstrapCurrentSeason() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 1)
        .subtract(const Duration(seconds: 1));
    final seasonId =
        'bootstrap-${now.year}-${now.month.toString().padLeft(2, '0')}';
    return Season(
      seasonId: seasonId,
      name: '${now.year}年${now.month}月シーズン',
      description: 'このシーズンの対局・パズル・イベントに挑戦しよう',
      seasonNumber: now.year * 12 + now.month,
      startDate: start,
      endDate: end,
      status: 'active',
      theme: 'default',
      maxLevel: 50,
      createdAt: start,
      updatedAt: start,
    );
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
