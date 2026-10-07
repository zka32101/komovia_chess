import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:logger/logger.dart';
import '../models/game_history.dart';
import 'game_history_service.dart';
import 'firebase_game_history_service.dart';
import 'ai_opponent_engine_enhanced.dart';

/// Hybrid service combining local and cloud storage with automatic sync
///
/// Provides offline-first experience with background cloud synchronization
class HybridGameHistoryService implements GameHistoryService {
  HybridGameHistoryService({
    required LocalGameHistoryService local,
    required FirebaseGameHistoryService firebase,
  })  : _local = local,
        _firebase = firebase {
    _initializeConnectivity();
  }
  final LocalGameHistoryService _local;
  final FirebaseGameHistoryService _firebase;
  final Connectivity _connectivity = Connectivity();
  final Logger _logger = Logger();

  bool _isOnline = false;
  late Stream<ConnectivityResult> _connectivityStream;

  /// Initialize connectivity monitoring
  void _initializeConnectivity() {
    _connectivityStream = _connectivity.onConnectivityChanged;
    _connectivityStream.listen((result) {
      _isOnline = result != ConnectivityResult.none;
      _logger.i('Connectivity changed: $_isOnline');

      if (_isOnline) {
        _syncPendingGames();
      }
    });
  }

  /// Check current connectivity status
  Future<bool> isOnline() async {
    final result = await _connectivity.checkConnectivity();
    return result != ConnectivityResult.none;
  }

  @override
  Future<void> saveGame(GameRecord game) async {
    try {
      // Always save locally first
      await _local.saveGame(game);
      _logger.i('Game saved locally: ${game.gameId}');

      // Mark game as needing sync
      _markGameForSync(game.gameId);

      // Try to sync to cloud if online
      if (_isOnline) {
        try {
          await _firebase.saveGame(game);
          _logger.i('Game synced to cloud: ${game.gameId}');
          _markGameSynced(game.gameId);
        } catch (e) {
          _logger.w('Failed to sync game to cloud (will retry): $e');
        }
      }
    } catch (e) {
      _logger.e('Error saving game: $e');
      rethrow;
    }
  }

  @override
  Future<List<GameRecord>> loadAllGames() async {
    try {
      // If offline, return local games
      if (!_isOnline) {
        _logger.i('Offline: Loading games from local storage');
        return _local.loadAllGames();
      }

      // If online, try cloud first, fall back to local
      try {
        _logger.i('Online: Loading games from cloud');
        final cloudGames = await _firebase.loadAllGames();

        // Update local cache with cloud games
        for (final game in cloudGames) {
          await _local.saveGame(game);
        }

        return cloudGames;
      } catch (e) {
        _logger.w('Failed to load from cloud (using local): $e');
        return _local.loadAllGames();
      }
    } catch (e) {
      _logger.e('Error loading games: $e');
      rethrow;
    }
  }

  @override
  Future<List<GameRecord>> loadGamesByDifficulty(
      AIDifficulty difficulty) async {
    try {
      if (!_isOnline) {
        return _local.loadGamesByDifficulty(difficulty);
      }

      try {
        return _firebase.loadGamesByDifficulty(difficulty);
      } catch (e) {
        _logger.w('Failed to load from cloud (using local): $e');
        return _local.loadGamesByDifficulty(difficulty);
      }
    } catch (e) {
      _logger.e('Error loading games by difficulty: $e');
      rethrow;
    }
  }

  @override
  Future<List<GameRecord>> loadGamesBetween(
      DateTime start, DateTime end) async {
    try {
      if (!_isOnline) {
        return _local.loadGamesBetween(start, end);
      }

      try {
        return _firebase.loadGamesBetween(start, end);
      } catch (e) {
        _logger.w('Failed to load from cloud (using local): $e');
        return _local.loadGamesBetween(start, end);
      }
    } catch (e) {
      _logger.e('Error loading games between dates: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteGame(String gameId) async {
    try {
      // Delete locally
      await _local.deleteGame(gameId);
      _logger.i('Game deleted locally: $gameId');

      // Mark for sync
      _markGameDeleted(gameId);

      // Delete from cloud if online
      if (_isOnline) {
        try {
          await _firebase.deleteGame(gameId);
          _logger.i('Game deleted from cloud: $gameId');
          _markGameSynced(gameId);
        } catch (e) {
          _logger.w('Failed to delete from cloud (will retry): $e');
        }
      }
    } catch (e) {
      _logger.e('Error deleting game: $e');
      rethrow;
    }
  }

  @override
  Future<void> clearAllGames() async {
    try {
      await _local.clearAllGames();
      _logger.i('All games cleared locally');

      if (_isOnline) {
        try {
          await _firebase.clearAllGames();
          _logger.i('All games cleared from cloud');
        } catch (e) {
          _logger.w('Failed to clear cloud games: $e');
        }
      }
    } catch (e) {
      _logger.e('Error clearing games: $e');
      rethrow;
    }
  }

  @override
  Future<PlayerStatistics> getPlayerStatistics() async {
    try {
      if (!_isOnline) {
        return _local.getPlayerStatistics();
      }

      try {
        return _firebase.getPlayerStatistics();
      } catch (e) {
        _logger.w('Failed to get stats from cloud (using local): $e');
        return _local.getPlayerStatistics();
      }
    } catch (e) {
      _logger.e('Error getting player statistics: $e');
      rethrow;
    }
  }

  /// Watch player statistics with real-time cloud updates
  Stream<PlayerStatistics> watchPlayerStatisticsLive() =>
      _firebase.watchPlayerStatistics();

  /// Watch all games for real-time updates
  Stream<List<GameRecord>> watchAllGamesLive() => _firebase.watchAllGames();

  /// Sync all pending local games to cloud
  Future<int> _syncPendingGames() async {
    try {
      _logger.i('Syncing pending games to cloud...');

      final localGames = await _local.loadAllGames();
      int synced = 0;

      for (final game in localGames) {
        if (_shouldSyncGame(game.gameId)) {
          try {
            await _firebase.saveGame(game);
            _markGameSynced(game.gameId);
            synced++;
          } catch (e) {
            _logger.w('Failed to sync game ${game.gameId}: $e');
          }
        }
      }

      _logger.i('Synced $synced games to cloud');
      return synced;
    } catch (e) {
      _logger.e('Error syncing pending games: $e');
      return 0;
    }
  }

  /// Get list of games needing synchronization
  Future<List<GameRecord>> getPendingSync() async {
    try {
      final allGames = await _local.loadAllGames();
      return allGames.where((game) => _shouldSyncGame(game.gameId)).toList();
    } catch (e) {
      _logger.e('Error getting pending sync: $e');
      return [];
    }
  }

  /// Export all games for backup
  Future<String> exportGamesForBackup() async {
    try {
      _logger.i('Exporting games for backup');

      if (_isOnline) {
        return _firebase.exportGamesAsJson();
      } else {
        final games = await _local.loadAllGames();
        final json = {
          'exportedAt': DateTime.now().toIso8601String(),
          'gameCount': games.length,
          'games': games.map((g) => g.toJson()).toList(),
        };
        return json.toString();
      }
    } catch (e) {
      _logger.e('Error exporting games: $e');
      rethrow;
    }
  }

  /// Import games from backup
  Future<int> importGamesFromBackup(String backupData) async {
    try {
      _logger.i('Importing games from backup');

      int imported = 0;

      // Parse backup data and import to local
      // Then sync to cloud if online
      if (_isOnline) {
        imported = await _firebase.importGamesFromJson(backupData);
      } else {
        // Local import only, will sync when online
        _logger.i('Offline: Games will be synced when online');
      }

      return imported;
    } catch (e) {
      _logger.e('Error importing backup: $e');
      rethrow;
    }
  }

  /// Get storage stats
  Future<Map<String, dynamic>> getStorageStats() async {
    try {
      final localGames = await _local.loadAllGames();
      final pending = await getPendingSync();
      final synced = localGames.length - pending.length;

      return {
        'localGameCount': localGames.length,
        'syncedToCloud': synced,
        'pendingSync': pending.length,
        'isOnline': _isOnline,
        'totalSize': _estimateSize(localGames),
      };
    } catch (e) {
      _logger.e('Error getting storage stats: $e');
      rethrow;
    }
  }

  // Private sync tracking
  final Map<String, int> _syncStatus = {}; // gameId -> timestamp

  void _markGameForSync(String gameId) {
    _syncStatus[gameId] = 0; // 0 = needs sync
  }

  void _markGameSynced(String gameId) {
    _syncStatus[gameId] = DateTime.now().millisecondsSinceEpoch;
  }

  void _markGameDeleted(String gameId) {
    _syncStatus[gameId] = -1; // -1 = deleted
  }

  bool _shouldSyncGame(String gameId) =>
      _syncStatus[gameId] == null || _syncStatus[gameId] == 0;

  int _estimateSize(List<GameRecord> games) {
    // Rough estimate: ~2KB per game
    return games.length * 2048;
  }
}
