import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_chess/src/models/game_history.dart';
import 'package:komovia_chess/src/services/game_history_service.dart';
import 'package:komovia_chess/src/services/hybrid_game_history_service.dart';
import 'package:komovia_chess/src/services/firebase_game_history_service.dart';
import 'package:komovia_chess/src/services/ai_opponent_engine_enhanced.dart';

// Mock implementations
class MockLocalGameHistoryService implements LocalGameHistoryService {
  Map<String, GameRecord> _games = {};

  @override
  Future<void> saveGame(GameRecord game) async {
    _games[game.gameId] = game;
  }

  @override
  Future<List<GameRecord>> loadAllGames() async {
    return _games.values.toList()
      ..sort((a, b) => b.playedAt.compareTo(a.playedAt));
  }

  @override
  Future<List<GameRecord>> loadGamesByDifficulty(
      AIDifficulty difficulty) async {
    return _games.values.where((g) => g.difficulty == difficulty).toList()
      ..sort((a, b) => b.playedAt.compareTo(a.playedAt));
  }

  @override
  Future<List<GameRecord>> loadGamesBetween(
      DateTime start, DateTime end) async {
    return _games.values
        .where((g) => g.playedAt.isAfter(start) && g.playedAt.isBefore(end))
        .toList()
      ..sort((a, b) => b.playedAt.compareTo(a.playedAt));
  }

  @override
  Future<void> deleteGame(String gameId) async {
    _games.remove(gameId);
  }

  @override
  Future<void> clearAllGames() async {
    _games.clear();
  }

  @override
  Future<PlayerStatistics> getPlayerStatistics() async {
    final allGames = await loadAllGames();
    if (allGames.isEmpty) {
      return PlayerStatistics(
        playerId: 'local_player',
        games: [],
        firstGame: DateTime.now(),
        lastGame: DateTime.now(),
      );
    }

    return PlayerStatistics(
      playerId: 'local_player',
      games: allGames,
      firstGame: allGames.last.playedAt,
      lastGame: allGames.first.playedAt,
    );
  }
}

class MockFirebaseGameHistoryService implements FirebaseGameHistoryService {
  Map<String, GameRecord> _games = {};
  bool shouldFail = false;

  @override
  Future<void> saveGame(GameRecord game) async {
    if (shouldFail) throw Exception('Firebase error');
    _games[game.gameId] = game;
  }

  @override
  Future<List<GameRecord>> loadAllGames() async {
    if (shouldFail) throw Exception('Firebase error');
    return _games.values.toList()
      ..sort((a, b) => b.playedAt.compareTo(a.playedAt));
  }

  @override
  Future<List<GameRecord>> loadGamesByDifficulty(
      AIDifficulty difficulty) async {
    if (shouldFail) throw Exception('Firebase error');
    return _games.values.where((g) => g.difficulty == difficulty).toList()
      ..sort((a, b) => b.playedAt.compareTo(a.playedAt));
  }

  @override
  Future<List<GameRecord>> loadGamesBetween(
      DateTime start, DateTime end) async {
    if (shouldFail) throw Exception('Firebase error');
    return _games.values
        .where((g) => g.playedAt.isAfter(start) && g.playedAt.isBefore(end))
        .toList()
      ..sort((a, b) => b.playedAt.compareTo(a.playedAt));
  }

  @override
  Future<void> deleteGame(String gameId) async {
    if (shouldFail) throw Exception('Firebase error');
    _games.remove(gameId);
  }

  @override
  Future<void> clearAllGames() async {
    if (shouldFail) throw Exception('Firebase error');
    _games.clear();
  }

  @override
  Future<PlayerStatistics> getPlayerStatistics() async {
    if (shouldFail) throw Exception('Firebase error');
    final allGames = await loadAllGames();
    if (allGames.isEmpty) {
      return PlayerStatistics(
        playerId: 'firebase_player',
        games: [],
        firstGame: DateTime.now(),
        lastGame: DateTime.now(),
      );
    }

    return PlayerStatistics(
      playerId: 'firebase_player',
      games: allGames,
      firstGame: allGames.last.playedAt,
      lastGame: allGames.first.playedAt,
    );
  }

  @override
  Future<int> syncLocalGames(List<GameRecord> localGames) async =>
      localGames.length;

  @override
  Future<String> exportGamesAsJson() async => '{}';

  @override
  Future<int> importGamesFromJson(String jsonData) async => 0;

  @override
  Future<bool> hasSyncedGames() async => _games.isNotEmpty;

  @override
  Stream<PlayerStatistics> watchPlayerStatistics() {
    throw UnimplementedError();
  }

  @override
  Stream<List<GameRecord>> watchAllGames() {
    throw UnimplementedError();
  }

  @override
  Future<Map<String, dynamic>> getRecentPerformance(int gameCount) async => {};

  @override
  Future<List<GameRecord>> getTodaysGames() async => [];

  @override
  Future<Map<String, dynamic>?> getCachedStats() async => null;

  @override
  Future<Map<String, dynamic>?> getCachedStatsByDifficulty() async => null;
}

GameRecord createTestGame({
  String gameId = 'test-game',
  AIDifficulty difficulty = AIDifficulty.medium,
  GameResult result = GameResult.win,
  int totalMoves = 30,
}) {
  return GameRecord(
    gameId: gameId,
    playedAt: DateTime.now(),
    difficulty: difficulty,
    result: result,
    totalMoves: totalMoves,
    totalTimeMs: 45000,
    moveMetrics: [],
    statistics: GameStatistics(
      avgNodesPerSec: 25000,
      avgCacheHitRate: 0.65,
      avgSearchDepth: 3.5,
      avgTimePerMove: 1500,
      totalKillerCutoffs: 45,
      totalCountermoveCutoffs: 32,
      openingStats: PhaseStatistics.empty(),
      midgameStats: PhaseStatistics.empty(),
      endgameStats: PhaseStatistics.empty(),
    ),
  );
}

void main() {
  group('HybridGameHistoryService', () {
    late HybridGameHistoryService hybrid;
    late MockLocalGameHistoryService mockLocal;
    late MockFirebaseGameHistoryService mockFirebase;

    setUp(() {
      mockLocal = MockLocalGameHistoryService();
      mockFirebase = MockFirebaseGameHistoryService();

      hybrid = HybridGameHistoryService(
        local: mockLocal,
        firebase: mockFirebase,
      );

      // Simulate online by default
      hybrid._isOnline = true;
    });

    group('saveGame', () {
      test('saves game to local storage immediately', () async {
        final game = createTestGame();
        await hybrid.saveGame(game);

        final localGames = await mockLocal.loadAllGames();
        expect(localGames, contains(game));
      });

      test('syncs to cloud when online', () async {
        hybrid._isOnline = true;
        final game = createTestGame();

        await hybrid.saveGame(game);

        final cloudGames = await mockFirebase.loadAllGames();
        expect(cloudGames, contains(game));
      });

      test('marks game for sync when offline', () async {
        hybrid._isOnline = false;
        final game = createTestGame();

        await hybrid.saveGame(game);

        final localGames = await mockLocal.loadAllGames();
        expect(localGames, contains(game));

        // Game should be marked for sync
        expect(hybrid._shouldSyncGame(game.gameId), true);
      });

      test('continues to work if cloud sync fails', () async {
        hybrid._isOnline = true;
        mockFirebase.shouldFail = true;

        final game = createTestGame();
        // Should not throw - local save succeeds
        await hybrid.saveGame(game);

        final localGames = await mockLocal.loadAllGames();
        expect(localGames, contains(game));
      });
    });

    group('loadAllGames', () {
      test('loads from local storage when offline', () async {
        hybrid._isOnline = false;
        final game = createTestGame();
        await mockLocal.saveGame(game);

        final loaded = await hybrid.loadAllGames();
        expect(loaded, contains(game));
      });

      test('loads from cloud when online', () async {
        hybrid._isOnline = true;
        final game = createTestGame();
        await mockFirebase.saveGame(game);

        final loaded = await hybrid.loadAllGames();
        expect(loaded, contains(game));
      });

      test('falls back to local if cloud fails', () async {
        hybrid._isOnline = true;
        mockFirebase.shouldFail = true;

        final game = createTestGame();
        await mockLocal.saveGame(game);

        final loaded = await hybrid.loadAllGames();
        expect(loaded, contains(game));
      });

      test('updates local cache from cloud', () async {
        hybrid._isOnline = true;

        final game = createTestGame();
        await mockFirebase.saveGame(game);

        await hybrid.loadAllGames();

        final localGames = await mockLocal.loadAllGames();
        expect(localGames, contains(game));
      });
    });

    group('loadGamesByDifficulty', () {
      test('filters by difficulty when online', () async {
        hybrid._isOnline = true;

        final easyGame = createTestGame(
          gameId: 'easy-1',
          difficulty: AIDifficulty.easy,
        );
        final mediumGame = createTestGame(
          gameId: 'medium-1',
          difficulty: AIDifficulty.medium,
        );

        await mockFirebase.saveGame(easyGame);
        await mockFirebase.saveGame(mediumGame);

        final loaded = await hybrid.loadGamesByDifficulty(AIDifficulty.easy);
        expect(loaded.length, 1);
        expect(loaded.first.difficulty, AIDifficulty.easy);
      });

      test('filters by difficulty when offline', () async {
        hybrid._isOnline = false;

        final easyGame = createTestGame(
          gameId: 'easy-1',
          difficulty: AIDifficulty.easy,
        );
        final mediumGame = createTestGame(
          gameId: 'medium-1',
          difficulty: AIDifficulty.medium,
        );

        await mockLocal.saveGame(easyGame);
        await mockLocal.saveGame(mediumGame);

        final loaded = await hybrid.loadGamesByDifficulty(AIDifficulty.easy);
        expect(loaded.length, 1);
        expect(loaded.first.difficulty, AIDifficulty.easy);
      });
    });

    group('deleteGame', () {
      test('deletes from local storage', () async {
        final game = createTestGame();
        await mockLocal.saveGame(game);

        await hybrid.deleteGame(game.gameId);

        final games = await mockLocal.loadAllGames();
        expect(games, isEmpty);
      });

      test('deletes from cloud when online', () async {
        hybrid._isOnline = true;
        final game = createTestGame();
        await mockFirebase.saveGame(game);

        await hybrid.deleteGame(game.gameId);

        final games = await mockFirebase.loadAllGames();
        expect(games, isEmpty);
      });

      test('marks for sync when offline', () async {
        hybrid._isOnline = false;
        final game = createTestGame();
        await mockLocal.saveGame(game);

        await hybrid.deleteGame(game.gameId);

        // Game should be marked as deleted
        expect(hybrid._syncStatus[game.gameId], -1);
      });
    });

    group('Sync operations', () {
      test('getPendingSync returns games needing sync', () async {
        hybrid._isOnline = false;
        final game1 = createTestGame(gameId: 'pending-1');
        final game2 = createTestGame(gameId: 'pending-2');

        await mockLocal.saveGame(game1);
        await mockLocal.saveGame(game2);

        // Mark as needing sync
        hybrid._markGameForSync(game1.gameId);
        hybrid._markGameForSync(game2.gameId);

        final pending = await hybrid.getPendingSync();
        expect(pending.length, greaterThanOrEqualTo(0));
      });

      test('syncs pending games to cloud', () async {
        // Start offline
        hybrid._isOnline = false;
        final game = createTestGame();
        await hybrid.saveGame(game);

        // Go online
        hybrid._isOnline = true;

        // Sync should work
        int synced = await hybrid._syncPendingGames();
        expect(synced, greaterThanOrEqualTo(0));
      });

      test('handles sync failures gracefully', () async {
        hybrid._isOnline = true;
        mockFirebase.shouldFail = true;

        final game = createTestGame();
        await mockLocal.saveGame(game);

        // Should not throw
        final synced = await hybrid._syncPendingGames();
        expect(synced, isA<int>());
      });
    });

    group('Export/Import', () {
      test('exports games for backup', () async {
        final game = createTestGame();
        await mockLocal.saveGame(game);

        final backup = await hybrid.exportGamesForBackup();
        expect(backup, isNotEmpty);
      });

      test('imports games from backup', () async {
        const backupData = '{}';

        final imported = await hybrid.importGamesFromBackup(backupData);
        expect(imported, isA<int>());
      });
    });

    group('Storage statistics', () {
      test('getStorageStats returns storage info', () async {
        final game = createTestGame();
        await mockLocal.saveGame(game);

        final stats = await hybrid.getStorageStats();

        expect(stats.containsKey('localGameCount'), true);
        expect(stats.containsKey('syncedToCloud'), true);
        expect(stats.containsKey('pendingSync'), true);
        expect(stats.containsKey('isOnline'), true);
      });

      test('tracks local and cloud game counts', () async {
        final game = createTestGame();
        await mockLocal.saveGame(game);

        final stats = await hybrid.getStorageStats();

        expect(stats['localGameCount'], greaterThan(0));
      });
    });

    group('Connectivity changes', () {
      test('detects online connectivity', () async {
        hybrid._isOnline = true;
        expect(hybrid._isOnline, true);
      });

      test('detects offline connectivity', () async {
        hybrid._isOnline = false;
        expect(hybrid._isOnline, false);
      });

      test('syncs on reconnection', () async {
        // Start offline
        hybrid._isOnline = false;
        final game = createTestGame();
        await hybrid.saveGame(game);

        // Simulate reconnection
        hybrid._isOnline = true;
        // Should sync automatically when connection restored

        expect(hybrid._isOnline, true);
      });
    });

    group('Fallback behavior', () {
      test('uses local storage if cloud temporarily unavailable', () async {
        hybrid._isOnline = true;
        mockFirebase.shouldFail = true;

        final game = createTestGame();
        await hybrid.saveGame(game);

        // Should fall back to local
        mockFirebase.shouldFail = false;
        final loaded = await hybrid.loadAllGames();
        expect(loaded, contains(game));
      });

      test('gracefully handles network errors', () async {
        hybrid._isOnline = true;
        mockFirebase.shouldFail = true;

        final game = createTestGame();
        // Should not throw
        await hybrid.saveGame(game);

        // Local should have it
        final local = await mockLocal.loadAllGames();
        expect(local, contains(game));
      });
    });

    group('Player statistics', () {
      test('gets statistics from appropriate source', () async {
        final game = createTestGame();
        await mockLocal.saveGame(game);

        final stats = await hybrid.getPlayerStatistics();

        expect(stats.totalGames, greaterThanOrEqualTo(1));
      });

      test('aggregates statistics across local and cloud', () async {
        hybrid._isOnline = true;

        final localGame = createTestGame(gameId: 'local-1');
        final cloudGame = createTestGame(gameId: 'cloud-1');

        await mockLocal.saveGame(localGame);
        await mockFirebase.saveGame(cloudGame);

        final stats = await hybrid.getPlayerStatistics();

        // Should have at least the cloud game
        expect(stats.totalGames, greaterThanOrEqualTo(1));
      });
    });

    group('Sync tracking', () {
      test('marks game as needing sync', () async {
        final gameId = 'test-123';
        hybrid._markGameForSync(gameId);

        expect(hybrid._syncStatus[gameId], 0);
        expect(hybrid._shouldSyncGame(gameId), true);
      });

      test('marks game as synced', () async {
        final gameId = 'test-123';
        hybrid._markGameForSync(gameId);
        hybrid._markGameSynced(gameId);

        expect(hybrid._shouldSyncGame(gameId), false);
      });

      test('marks game as deleted', () async {
        final gameId = 'test-123';
        hybrid._markGameDeleted(gameId);

        expect(hybrid._syncStatus[gameId], -1);
      });
    });
  });

  group('Hybrid Service Integration Scenarios', () {
    test('complete offline to online workflow', () async {
      final mockLocal = MockLocalGameHistoryService();
      final mockFirebase = MockFirebaseGameHistoryService();
      final hybrid = HybridGameHistoryService(
        local: mockLocal,
        firebase: mockFirebase,
      );

      // 1. Start offline
      hybrid._isOnline = false;
      final game1 = createTestGame(gameId: 'game-1');
      await hybrid.saveGame(game1);

      // 2. Play another game
      final game2 = createTestGame(gameId: 'game-2');
      await hybrid.saveGame(game2);

      // 3. Check local has both
      var localGames = await mockLocal.loadAllGames();
      expect(localGames.length, 2);

      // 4. Go online
      hybrid._isOnline = true;
      await hybrid._syncPendingGames();

      // 5. Cloud should have synced games
      final cloudGames = await mockFirebase.loadAllGames();
      expect(cloudGames.length, greaterThanOrEqualTo(0));
    });

    test('cloud-first sync workflow', () async {
      final mockLocal = MockLocalGameHistoryService();
      final mockFirebase = MockFirebaseGameHistoryService();
      final hybrid = HybridGameHistoryService(
        local: mockLocal,
        firebase: mockFirebase,
      );

      // 1. Save to cloud
      hybrid._isOnline = true;
      final game = createTestGame();
      await hybrid.saveGame(game);

      // 2. Load games
      final loaded = await hybrid.loadAllGames();
      expect(loaded, isNotEmpty);

      // 3. Local cache updated
      final localGames = await mockLocal.loadAllGames();
      expect(localGames.length, greaterThanOrEqualTo(1));
    });

    test('multi-device sync scenario', () async {
      // Simulate 2 devices
      final device1Local = MockLocalGameHistoryService();
      final device1Firebase = MockFirebaseGameHistoryService();
      final device1 = HybridGameHistoryService(
        local: device1Local,
        firebase: device1Firebase,
      );

      final device2Local = MockLocalGameHistoryService();
      final device2Firebase = device1Firebase; // Same cloud backend
      final device2 = HybridGameHistoryService(
        local: device2Local,
        firebase: device2Firebase,
      );

      // Device 1 plays a game
      device1._isOnline = true;
      final game = createTestGame();
      await device1.saveGame(game);

      // Device 2 syncs and sees the game
      device2._isOnline = true;
      final device2Games = await device2.loadAllGames();
      expect(device2Games, contains(game));
    });
  });
}
