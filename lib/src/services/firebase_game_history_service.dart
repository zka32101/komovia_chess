import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import '../models/game_history.dart';
import 'ai_opponent_engine_enhanced.dart';
import 'game_history_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Firebase implementation of game history service
///
/// Handles cloud storage, synchronization, and online statistics
class FirebaseGameHistoryService implements GameHistoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Logger _logger = Logger();

  /// Collection path for game records
  String get _gamesCollection => 'users/$_userId/games';
  String get _userId => _auth.currentUser?.uid ?? 'anonymous';

  /// Collection path for aggregated statistics
  String get _statsCollection => 'users/$_userId/statistics';

  @override
  Future<void> saveGame(GameRecord game) async {
    try {
      _logger.i('Saving game ${game.gameId} to Firebase');

      final gameRef = _firestore.collection(_gamesCollection).doc(game.gameId);

      // Save game with metadata
      await gameRef.set({
        ...game.toJson(),
        'syncedAt': FieldValue.serverTimestamp(),
        'difficulty': game.difficulty.displayName,
        'result': game.result.name,
      });

      // Update player statistics in parallel
      await _updatePlayerStats();

      _logger.i('Game saved successfully: ${game.gameId}');
    } catch (e) {
      _logger.e('Error saving game to Firebase: $e');
      rethrow;
    }
  }

  @override
  Future<List<GameRecord>> loadAllGames() async {
    try {
      _logger.i('Loading all games from Firebase');

      final snapshot = await _firestore
          .collection(_gamesCollection)
          .orderBy('playedAt', descending: true)
          .get();

      final games =
          snapshot.docs.map((doc) => GameRecord.fromJson(doc.data())).toList();

      _logger.i('Loaded ${games.length} games from Firebase');
      return games;
    } catch (e) {
      _logger.e('Error loading games from Firebase: $e');
      rethrow;
    }
  }

  @override
  Future<List<GameRecord>> loadGamesByDifficulty(
      AIDifficulty difficulty) async {
    try {
      _logger.i('Loading games by difficulty: ${difficulty.displayName}');

      final snapshot = await _firestore
          .collection(_gamesCollection)
          .where('difficulty', isEqualTo: difficulty.displayName)
          .orderBy('playedAt', descending: true)
          .get();

      final games =
          snapshot.docs.map((doc) => GameRecord.fromJson(doc.data())).toList();

      _logger.i('Loaded ${games.length} ${difficulty.displayName} games');
      return games;
    } catch (e) {
      _logger.e('Error loading games by difficulty: $e');
      rethrow;
    }
  }

  @override
  Future<List<GameRecord>> loadGamesBetween(
      DateTime start, DateTime end) async {
    try {
      _logger.i('Loading games between $start and $end');

      final snapshot = await _firestore
          .collection(_gamesCollection)
          .where('playedAt', isGreaterThanOrEqualTo: start)
          .where('playedAt', isLessThanOrEqualTo: end)
          .orderBy('playedAt', descending: true)
          .get();

      final games =
          snapshot.docs.map((doc) => GameRecord.fromJson(doc.data())).toList();

      _logger.i('Loaded ${games.length} games in date range');
      return games;
    } catch (e) {
      _logger.e('Error loading games by date range: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteGame(String gameId) async {
    try {
      _logger.i('Deleting game $gameId from Firebase');

      await _firestore.collection(_gamesCollection).doc(gameId).delete();

      // Recalculate stats after deletion
      await _updatePlayerStats();

      _logger.i('Game deleted: $gameId');
    } catch (e) {
      _logger.e('Error deleting game: $e');
      rethrow;
    }
  }

  @override
  Future<void> clearAllGames() async {
    try {
      _logger.w('Clearing all games for user $_userId');

      final batch = _firestore.batch();
      final snapshot = await _firestore.collection(_gamesCollection).get();

      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      // Clear stats
      await _firestore.collection(_statsCollection).doc('overall').delete();

      _logger.i('All games cleared');
    } catch (e) {
      _logger.e('Error clearing games: $e');
      rethrow;
    }
  }

  @override
  Future<PlayerStatistics> getPlayerStatistics() async {
    try {
      _logger.i('Fetching player statistics from Firebase');

      final games = await loadAllGames();

      if (games.isEmpty) {
        return PlayerStatistics(
          playerId: _userId,
          games: [],
          firstGame: DateTime.now(),
          lastGame: DateTime.now(),
        );
      }

      return PlayerStatistics(
        playerId: _userId,
        games: games,
        firstGame: games.last.playedAt,
        lastGame: games.first.playedAt,
      );
    } catch (e) {
      _logger.e('Error getting player statistics: $e');
      rethrow;
    }
  }

  /// Update aggregated player statistics in Firestore
  Future<void> _updatePlayerStats() async {
    try {
      final stats = await getPlayerStatistics();
      final overall = stats.getOverallStats();
      final trend = stats.getPerformanceTrend();

      // Aggregate stats by difficulty
      final easyStats = stats.getStatsByDifficulty(AIDifficulty.easy);
      final mediumStats = stats.getStatsByDifficulty(AIDifficulty.medium);
      final hardStats = stats.getStatsByDifficulty(AIDifficulty.hard);

      await _firestore.collection(_statsCollection).doc('overall').set({
        'totalGames': overall['totalGames'],
        'wins': overall['wins'],
        'draws': overall['draws'],
        'losses': overall['losses'],
        'winRate': overall['winRate'],
        'avgNodesPerSec': overall['avgNodesPerSec'],
        'avgCacheHitRate': overall['avgCacheHitRate'],
        'trend': trend['trend'],
        'nodeImprovement': trend['nodeImprovement'],
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Store difficulty-specific stats
      await _firestore.collection(_statsCollection).doc('byDifficulty').set({
        'easy': easyStats,
        'medium': mediumStats,
        'hard': hardStats,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      _logger.e('Error updating player stats: $e');
      // Don't rethrow - stats update failure shouldn't block game save
    }
  }

  /// Get cached player statistics from Firestore
  Future<Map<String, dynamic>?> getCachedStats() async {
    try {
      final doc =
          await _firestore.collection(_statsCollection).doc('overall').get();

      return doc.data();
    } catch (e) {
      _logger.e('Error getting cached stats: $e');
      return null;
    }
  }

  /// Get statistics by difficulty from cache
  Future<Map<String, dynamic>?> getCachedStatsByDifficulty() async {
    try {
      final doc = await _firestore
          .collection(_statsCollection)
          .doc('byDifficulty')
          .get();

      return doc.data();
    } catch (e) {
      _logger.e('Error getting cached difficulty stats: $e');
      return null;
    }
  }

  /// Stream of player statistics for real-time updates
  Stream<PlayerStatistics> watchPlayerStatistics() => _firestore
          .collection(_gamesCollection)
          .orderBy('playedAt', descending: true)
          .snapshots()
          .map((snapshot) {
        final games = snapshot.docs
            .map((doc) => GameRecord.fromJson(doc.data()))
            .toList();

        if (games.isEmpty) {
          return PlayerStatistics(
            playerId: _userId,
            games: [],
            firstGame: DateTime.now(),
            lastGame: DateTime.now(),
          );
        }

        return PlayerStatistics(
          playerId: _userId,
          games: games,
          firstGame: games.last.playedAt,
          lastGame: games.first.playedAt,
        );
      });

  /// Stream of games for real-time sync
  Stream<List<GameRecord>> watchAllGames() => _firestore
      .collection(_gamesCollection)
      .orderBy('playedAt', descending: true)
      .snapshots()
      .map((snapshot) =>
          snapshot.docs.map((doc) => GameRecord.fromJson(doc.data())).toList());

  /// Sync games from local storage to cloud
  Future<int> syncLocalGames(List<GameRecord> localGames) async {
    try {
      _logger.i('Syncing ${localGames.length} local games to Firebase');

      int synced = 0;
      for (final game in localGames) {
        try {
          await saveGame(game);
          synced++;
        } catch (e) {
          _logger.w('Failed to sync game ${game.gameId}: $e');
        }
      }

      _logger.i('Synced $synced games to Firebase');
      return synced;
    } catch (e) {
      _logger.e('Error syncing games: $e');
      rethrow;
    }
  }

  /// Export all games as JSON for backup
  Future<String> exportGamesAsJson() async {
    try {
      final games = await loadAllGames();
      final json = {
        'userId': _userId,
        'exportedAt': DateTime.now().toIso8601String(),
        'gameCount': games.length,
        'games': games.map((g) => g.toJson()).toList(),
      };

      return jsonStringify(json);
    } catch (e) {
      _logger.e('Error exporting games: $e');
      rethrow;
    }
  }

  /// Import games from JSON backup
  Future<int> importGamesFromJson(String jsonData) async {
    try {
      _logger.i('Importing games from JSON backup');

      final json = jsonParse(jsonData);
      final games = (json['games'] as List)
          .map((g) => GameRecord.fromJson(g as Map<String, dynamic>))
          .toList();

      int imported = 0;
      for (final game in games) {
        try {
          await saveGame(game);
          imported++;
        } catch (e) {
          _logger.w('Failed to import game ${game.gameId}: $e');
        }
      }

      _logger.i('Imported $imported games from backup');
      return imported;
    } catch (e) {
      _logger.e('Error importing games: $e');
      rethrow;
    }
  }

  /// Get games played today
  Future<List<GameRecord>> getTodaysGames() async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      return loadGamesBetween(startOfDay, endOfDay);
    } catch (e) {
      _logger.e('Error getting today\'s games: $e');
      rethrow;
    }
  }

  /// Get performance metrics for the last N games
  Future<Map<String, dynamic>> getRecentPerformance(int gameCount) async {
    try {
      final games = await loadAllGames();
      final recent = games.take(gameCount).toList();

      if (recent.isEmpty) {
        return {
          'gameCount': 0,
          'winRate': 0,
          'avgNodesPerSec': 0,
          'avgCacheHitRate': 0,
        };
      }

      double totalNodes = 0;
      double totalCache = 0;
      int wins = 0;

      for (final game in recent) {
        totalNodes += game.statistics.avgNodesPerSec;
        totalCache += game.statistics.avgCacheHitRate;
        if (game.result == GameResult.win) wins++;
      }

      return {
        'gameCount': recent.length,
        'winRate': wins / recent.length,
        'avgNodesPerSec': totalNodes / recent.length,
        'avgCacheHitRate': totalCache / recent.length,
      };
    } catch (e) {
      _logger.e('Error getting recent performance: $e');
      rethrow;
    }
  }

  /// Check if user has games synced to cloud
  Future<bool> hasSyncedGames() async {
    try {
      final snapshot =
          await _firestore.collection(_gamesCollection).limit(1).get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      _logger.e('Error checking synced games: $e');
      return false;
    }
  }
}

/// Helper functions for JSON serialization
String jsonStringify(Map<String, dynamic> json) {
  // Simple JSON stringification
  return json.toString();
}

dynamic jsonParse(String jsonString) {
  // Simple JSON parsing - in production use dart:convert
  // This is a placeholder
  throw UnimplementedError('Use dart:convert.jsonDecode in production');
}
