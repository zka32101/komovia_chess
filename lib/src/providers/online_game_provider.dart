import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/online_game.dart';
import '../services/matchmaking_service.dart';
import '../services/online_game_service.dart';
import '../services/chess_engine_service.dart';
import 'auth_provider.dart';

/// Provider for Firebase Auth state
final firebaseAuthProvider =
    StreamProvider<User?>((ref) => FirebaseAuth.instance.authStateChanges());

/// Provider for matchmaking service
final matchmakingServiceProvider =
    Provider<MatchmakingService>((ref) => MatchmakingService());

/// Provider for online game service
final onlineGameServiceProvider =
    Provider<OnlineGameService>((ref) => OnlineGameService());

/// Provider for current queue status
final queueStatusProvider = FutureProvider.family<Map<String, dynamic>, String>(
  (ref, queueId) async {
    final service = ref.watch(matchmakingServiceProvider);
    return service.getQueueStatus(queueId);
  },
);

/// Provider for queue statistics
final queueStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final service = ref.watch(matchmakingServiceProvider);
  return service.getQueueStats();
});

/// Provider for current user's active games
final userActiveGamesProvider = FutureProvider<List<OnlineGame>>((ref) async {
  final authState = ref.watch(firebaseAuthProvider);
  final service = ref.watch(onlineGameServiceProvider);

  final userId = authState.whenData((user) => user?.uid).value;
  if (userId == null) {
    return [];
  }

  return service.getPlayerActiveGames(userId);
});

/// Provider for current user's recent games
final userRecentGamesProvider = FutureProvider<List<OnlineGame>>((ref) async {
  final authState = ref.watch(firebaseAuthProvider);
  final service = ref.watch(onlineGameServiceProvider);

  final userId = authState.whenData((user) => user?.uid).value;
  if (userId == null) {
    return [];
  }

  return service.getPlayerRecentGames(userId, limit: 20);
});

/// Provider for specific game by ID
final onlineGameProvider = FutureProvider.family<OnlineGame?, String>(
  (ref, gameId) async {
    final service = ref.watch(onlineGameServiceProvider);
    return service.getGame(gameId);
  },
);

/// Stream provider for real-time game updates
final gameStreamProvider =
    StreamProvider.family<OnlineGame, String>((ref, gameId) {
  final service = ref.watch(onlineGameServiceProvider);
  return service.watchGame(gameId);
});

/// Stream provider for real-time game updates that emits null when the
/// game document doesn't (or no longer) exists, instead of throwing.
final onlineGameStreamProvider = StreamProvider.family<OnlineGame?, String>(
    (ref, gameId) => FirebaseFirestore.instance
        .collection('games')
        .doc(gameId)
        .snapshots()
        .map((snapshot) =>
            snapshot.exists ? OnlineGame.fromJson(snapshot.data()!) : null));

/// Whether the opponent currently has an outstanding draw offer pending
/// for the local player to respond to.
final drawOfferStreamProvider =
    StreamProvider.family<bool, String>((ref, gameId) {
  final currentUserId = ref.watch(currentUserProvider).value?.uid;
  return ref.watch(onlineGameStreamProvider(gameId).stream).map(
        (game) =>
            game?.drawOfferedBy != null && game?.drawOfferedBy != currentUserId,
      );
});

/// Provider for game moves
final gameMoveProvider =
    FutureProvider.family<List<GameMove>, String>((ref, gameId) async {
  final service = ref.watch(onlineGameServiceProvider);
  return service.getGameMoves(gameId);
});

/// Notifier for online game operations
class OnlineGameNotifier extends StateNotifier<AsyncValue<void>> {
  OnlineGameNotifier(this._service, this._userId)
      : super(const AsyncValue.data(null));
  final OnlineGameService _service;
  final String? _userId;

  /// Create a new online game
  Future<OnlineGame> createGame({
    required String whitePlayerId,
    required String whitePlayerName,
    required int whiteRating,
    required String blackPlayerId,
    required String blackPlayerName,
    required int blackRating,
    required String gameType,
    required String timeControl,
  }) async {
    state = const AsyncValue.loading();
    try {
      final game = await _service.createGame(
        whitePlayerId: whitePlayerId,
        whitePlayerName: whitePlayerName,
        whiteRating: whiteRating,
        blackPlayerId: blackPlayerId,
        blackPlayerName: blackPlayerName,
        blackRating: blackRating,
        gameType: gameType,
        timeControl: timeControl,
      );
      state = const AsyncValue.data(null);
      return game;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Start a game
  Future<void> startGame(String gameId) async {
    state = const AsyncValue.loading();
    try {
      await _service.startGame(gameId);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Record a move
  Future<void> recordMove({
    required String gameId,
    required int moveNumber,
    required String from,
    required String to,
    required String playerId,
    required String updatedFen,
    required String updatedPgn,
    String? promotion,
  }) async {
    try {
      await _service.recordMove(
        gameId: gameId,
        moveNumber: moveNumber,
        from: from,
        to: to,
        promotion: promotion,
        playerId: playerId,
        updatedFen: updatedFen,
        updatedPgn: updatedPgn,
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Update time remaining
  Future<void> updateTimeRemaining({
    required String gameId,
    required int whiteTimeMs,
    required int blackTimeMs,
  }) async {
    try {
      await _service.updateTimeRemaining(
        gameId: gameId,
        whiteTimeMs: whiteTimeMs,
        blackTimeMs: blackTimeMs,
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Record player activity
  Future<void> recordActivity(String gameId, String playerId) async {
    try {
      await _service.recordActivity(gameId, playerId);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Resign from game
  Future<void> resign(String gameId) async {
    if (_userId == null) return;

    state = const AsyncValue.loading();
    try {
      await _service.resignGame(gameId, _userId!);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Abandon game
  Future<void> abandon(String gameId) async {
    if (_userId == null) return;

    state = const AsyncValue.loading();
    try {
      await _service.abandonGame(gameId, _userId!);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

/// State notifier provider for online game operations
final onlineGameNotifierProvider =
    StateNotifierProvider<OnlineGameNotifier, AsyncValue<void>>((ref) {
  final service = ref.watch(onlineGameServiceProvider);
  final authState = ref.watch(firebaseAuthProvider);
  final userId = authState.whenData((user) => user?.uid).value;

  return OnlineGameNotifier(service, userId);
});

/// Notifier for matchmaking operations
class MatchmakingNotifier extends StateNotifier<AsyncValue<void>> {
  MatchmakingNotifier(this._service) : super(const AsyncValue.data(null));
  final MatchmakingService _service;

  /// Join matchmaking queue
  Future<MatchmakingQueueEntry> joinQueue({
    required String playerId,
    required String playerName,
    required int currentRating,
    required String timeControlType,
    required String color,
  }) async {
    state = const AsyncValue.loading();
    try {
      final entry = await _service.joinQueue(
        playerId: playerId,
        playerName: playerName,
        currentRating: currentRating,
        timeControlType: timeControlType,
        color: color,
      );
      state = const AsyncValue.data(null);
      return entry;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Leave matchmaking queue
  Future<void> leaveQueue(String queueId) async {
    state = const AsyncValue.loading();
    try {
      await _service.leaveQueue(queueId);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

/// Local play state for an online game screen: the chess engine kept in
/// sync with the server's current FEN, plus in-flight move/error status.
class OnlineGameState {
  OnlineGameState({
    required this.engine,
    this.isSyncingMove = false,
    this.lastError,
  });
  final ChessEngineService engine;
  final bool isSyncingMove;
  final String? lastError;

  OnlineGameState copyWith({
    bool? isSyncingMove,
    String? lastError,
  }) =>
      OnlineGameState(
        engine: engine,
        isSyncingMove: isSyncingMove ?? this.isSyncingMove,
        lastError: lastError,
      );
}

/// Drives a single online game's board: keeps [OnlineGameState.engine] in
/// sync with the authoritative server state, and submits the local
/// player's moves/draw offers/resignation back to Firestore.
class OnlineGameStateNotifier extends StateNotifier<OnlineGameState> {
  OnlineGameStateNotifier(this._ref, this._gameId)
      : super(OnlineGameState(engine: ChessEngineService()..initGame())) {
    _ref.listen<AsyncValue<OnlineGame?>>(
      onlineGameStreamProvider(_gameId),
      (previous, next) => _onGameUpdate(next.value),
      fireImmediately: true,
    );
  }
  final Ref _ref;
  final String _gameId;

  OnlineGame? _latestGame;
  String? _lastSyncedFen;

  void _onGameUpdate(OnlineGame? game) {
    _latestGame = game;
    if (game == null) return;
    if (game.currentFen != _lastSyncedFen) {
      _lastSyncedFen = game.currentFen;
      state.engine.loadFromFen(game.currentFen);
      state = state.copyWith();
    }
  }

  /// Validate and play [from]->[to] locally, then sync it to Firestore.
  Future<void> makeMove(String from, String to, {String? promotion}) async {
    final userId = _ref.read(currentUserProvider).value?.uid;
    final game = _latestGame;
    if (userId == null || game == null) return;

    state = state.copyWith(isSyncingMove: true, lastError: null);

    if (!state.engine.makeMove(from, to, promotion: promotion)) {
      state = state.copyWith(isSyncingMove: false, lastError: 'Illegal move');
      return;
    }

    try {
      final updatedFen = state.engine.getCurrentFen();
      _lastSyncedFen = updatedFen;
      await _ref.read(onlineGameServiceProvider).recordMove(
            gameId: _gameId,
            moveNumber: game.moves.length + 1,
            from: from,
            to: to,
            promotion: promotion,
            playerId: userId,
            updatedFen: updatedFen,
            updatedPgn: state.engine.getPgnMoves(),
          );
      state = state.copyWith(isSyncingMove: false);
    } catch (e) {
      state = state.copyWith(isSyncingMove: false, lastError: e.toString());
    }
  }

  /// Offer a draw to the opponent.
  Future<void> offerDraw() async {
    final userId = _ref.read(currentUserProvider).value?.uid;
    if (userId == null) return;
    try {
      await _ref.read(onlineGameServiceProvider).offerDraw(_gameId, userId);
    } catch (e) {
      state = state.copyWith(lastError: e.toString());
    }
  }

  /// Accept the opponent's outstanding draw offer.
  Future<void> acceptDraw() async {
    try {
      await _ref.read(onlineGameServiceProvider).acceptDraw(_gameId);
    } catch (e) {
      state = state.copyWith(lastError: e.toString());
    }
  }

  /// Resign the game.
  Future<void> resign() async {
    final userId = _ref.read(currentUserProvider).value?.uid;
    if (userId == null) return;
    try {
      await _ref.read(onlineGameServiceProvider).resignGame(_gameId, userId);
    } catch (e) {
      state = state.copyWith(lastError: e.toString());
    }
  }
}

/// Per-game online play state, keyed by gameId.
final onlineGameStateProvider = StateNotifierProvider.family<
    OnlineGameStateNotifier, OnlineGameState, String>(
  OnlineGameStateNotifier.new,
);

/// State notifier provider for matchmaking operations
final matchmakingNotifierProvider =
    StateNotifierProvider<MatchmakingNotifier, AsyncValue<void>>((ref) {
  final service = ref.watch(matchmakingServiceProvider);
  return MatchmakingNotifier(service);
});
