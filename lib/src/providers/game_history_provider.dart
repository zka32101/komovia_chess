import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/game_history.dart';
import '../services/game_history_service.dart';
import '../services/firebase_game_history_service.dart';
import '../services/hybrid_game_history_service.dart';
import '../services/ai_opponent_engine_enhanced.dart';

/// Provider for Firebase Auth state
final firebaseAuthProvider =
    StreamProvider<User?>((ref) => FirebaseAuth.instance.authStateChanges());

/// Provider for game history service (local or Firebase)
final gameHistoryServiceProvider = Provider<GameHistoryService>((ref) {
  final authState = ref.watch(firebaseAuthProvider);

  return authState.when(
    loading: LocalGameHistoryService.new,
    error: (_, __) => LocalGameHistoryService(),
    data: (user) {
      if (user != null) {
        // User is authenticated - use hybrid service
        return HybridGameHistoryService(
          local: LocalGameHistoryService(),
          firebase: FirebaseGameHistoryService(),
        );
      } else {
        // User not authenticated - use local only
        return LocalGameHistoryService();
      }
    },
  );
});

/// Provider for Firebase service (when user is authenticated)
final firebaseGameHistoryServiceProvider =
    Provider<FirebaseGameHistoryService?>((ref) {
  final authState = ref.watch(firebaseAuthProvider);

  return authState
      .whenData((user) => user != null ? FirebaseGameHistoryService() : null)
      .value;
});

/// Provider for player statistics
final playerStatisticsProvider = FutureProvider<PlayerStatistics>((ref) async {
  final service = ref.watch(gameHistoryServiceProvider);
  return service.getPlayerStatistics();
});

/// Provider for all games
final allGamesProvider = FutureProvider<List<GameRecord>>((ref) async {
  final service = ref.watch(gameHistoryServiceProvider);
  return service.loadAllGames();
});

/// Provider for games by difficulty
final gamesByDifficultyProvider =
    FutureProvider.family<List<GameRecord>, AIDifficulty>(
  (ref, difficulty) async {
    final service = ref.watch(gameHistoryServiceProvider);
    return service.loadGamesByDifficulty(difficulty);
  },
);

/// Provider for recent games
final recentGamesProvider = FutureProvider<List<GameRecord>>((ref) async {
  final service = ref.watch(gameHistoryServiceProvider);
  final games = await service.loadAllGames();
  return games.take(10).toList();
});

/// Provider for easy games
final easyGamesProvider = FutureProvider<List<GameRecord>>((ref) async {
  final service = ref.watch(gameHistoryServiceProvider);
  return service.loadGamesByDifficulty(AIDifficulty.easy);
});

/// Provider for medium games
final mediumGamesProvider = FutureProvider<List<GameRecord>>((ref) async {
  final service = ref.watch(gameHistoryServiceProvider);
  return service.loadGamesByDifficulty(AIDifficulty.medium);
});

/// Provider for hard games
final hardGamesProvider = FutureProvider<List<GameRecord>>((ref) async {
  final service = ref.watch(gameHistoryServiceProvider);
  return service.loadGamesByDifficulty(AIDifficulty.hard);
});

/// Provider for sync status
final syncStatusProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final service = ref.watch(gameHistoryServiceProvider);

  if (service is HybridGameHistoryService) {
    return service.getStorageStats();
  }

  return {
    'localGameCount': 0,
    'syncedToCloud': 0,
    'pendingSync': 0,
    'isOnline': false,
  };
});

/// Provider for pending sync games
final pendingSyncProvider = FutureProvider<List<GameRecord>>((ref) async {
  final service = ref.watch(gameHistoryServiceProvider);

  if (service is HybridGameHistoryService) {
    return service.getPendingSync();
  }

  return [];
});

/// Stream provider for real-time player statistics
final playerStatisticsStreamProvider = StreamProvider<PlayerStatistics>((ref) {
  final service = ref.watch(gameHistoryServiceProvider);

  if (service is HybridGameHistoryService) {
    return service.watchPlayerStatisticsLive();
  }

  // Fallback: return single value as stream
  return Stream.fromFuture(service.getPlayerStatistics());
});

/// Stream provider for real-time games
final allGamesStreamProvider = StreamProvider<List<GameRecord>>((ref) {
  final service = ref.watch(gameHistoryServiceProvider);

  if (service is HybridGameHistoryService) {
    return service.watchAllGamesLive();
  }

  // Fallback: return single value as stream
  return Stream.fromFuture(service.loadAllGames());
});

/// Notifier for game history operations
class GameHistoryNotifier extends StateNotifier<AsyncValue<void>> {
  GameHistoryNotifier(this._service) : super(const AsyncValue.data(null));
  final GameHistoryService _service;

  /// Save a game
  Future<void> saveGame(GameRecord game) async {
    state = const AsyncValue.loading();
    try {
      await _service.saveGame(game);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Delete a game
  Future<void> deleteGame(String gameId) async {
    state = const AsyncValue.loading();
    try {
      await _service.deleteGame(gameId);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Clear all games
  Future<void> clearAll() async {
    state = const AsyncValue.loading();
    try {
      await _service.clearAllGames();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

/// State notifier provider for game history operations
final gameHistoryNotifierProvider =
    StateNotifierProvider<GameHistoryNotifier, AsyncValue<void>>((ref) {
  final service = ref.watch(gameHistoryServiceProvider);
  return GameHistoryNotifier(service);
});

/// Provider for export/import operations
final gameHistoryExportProvider = FutureProvider<String>((ref) async {
  final service = ref.watch(gameHistoryServiceProvider);

  if (service is HybridGameHistoryService) {
    return service.exportGamesForBackup();
  }

  return '';
});

/// Get specific game record by ID
final gameRecordProvider =
    FutureProvider.family<GameRecord?, String>((ref, gameId) async {
  final games = await ref.watch(allGamesProvider.future);
  try {
    return games.firstWhere((game) => game.gameId == gameId);
  } catch (_) {
    return null;
  }
});
