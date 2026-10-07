import 'dart:async';
import 'package:stockfish/stockfish.dart';
import 'ai_opponent_engine.dart' show AIDifficulty;

/// Approximate playing strength (UCI_Elo) and thinking budget per difficulty.
/// Stockfish's `UCI_LimitStrength` + `UCI_Elo` options let a full-strength
/// engine play at a deliberately weaker, more human-like level instead of
/// just capping search depth.
extension AIDifficultyStockfishExt on AIDifficulty {
  int get stockfishElo {
    switch (this) {
      case AIDifficulty.easy:
        return 800;
      case AIDifficulty.medium:
        return 1500;
      case AIDifficulty.hard:
        return 2200;
    }
  }

  int get stockfishMoveTimeMs {
    switch (this) {
      case AIDifficulty.easy:
        return 300;
      case AIDifficulty.medium:
        return 800;
      case AIDifficulty.hard:
        return 2000;
    }
  }
}

/// Wraps the `stockfish` plugin (native Stockfish binary via FFI/process on
/// Android/iOS/desktop) behind a simple async UCI interface.
///
/// Runs entirely off the Flutter UI isolate/thread, so `getBestMove()` never
/// blocks the app the way the hand-rolled minimax engine does.
class StockfishEngineService {
  StockfishEngineService._internal();
  static StockfishEngineService? _instance;
  Stockfish? _stockfish;
  StreamSubscription<String>? _stdoutSub;
  bool _uciReady = false;

  static StockfishEngineService get instance {
    _instance ??= StockfishEngineService._internal();
    return _instance!;
  }

  StockfishState get state =>
      _stockfish?.state.value ?? StockfishState.disposed;

  /// Boots the engine process and waits for `uciok`. Safe to call multiple
  /// times; subsequent calls are no-ops while already ready.
  Future<void> initialize() async {
    if (_uciReady && _stockfish != null) return;

    _stockfish = Stockfish();

    // Wait for the underlying process to reach the ready state.
    await _waitForState(StockfishState.ready);

    final uciOkCompleter = Completer<void>();
    _stdoutSub = _stockfish!.stdout.listen((line) {
      if (!uciOkCompleter.isCompleted && line.trim() == 'uciok') {
        uciOkCompleter.complete();
      }
    });

    _stockfish!.stdin = 'uci';
    await uciOkCompleter.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () =>
          throw TimeoutException('Stockfish did not respond to uci'),
    );

    _uciReady = true;
  }

  Future<void> _waitForState(StockfishState target) async {
    if (_stockfish!.state.value == target) return;
    final completer = Completer<void>();
    void listener() {
      if (_stockfish!.state.value == target && !completer.isCompleted) {
        completer.complete();
      }
    }

    _stockfish!.state.addListener(listener);
    try {
      await completer.future.timeout(const Duration(seconds: 10));
    } finally {
      _stockfish!.state.removeListener(listener);
    }
  }

  /// Configures playing strength to roughly match [difficulty] using
  /// Stockfish's built-in strength limiter, rather than just cutting search
  /// depth (which tends to produce obviously "dumb" moves).
  Future<void> configureDifficulty(AIDifficulty difficulty) async {
    await initialize();
    _send('setoption name UCI_LimitStrength value true');
    _send('setoption name UCI_Elo value ${difficulty.stockfishElo}');
    // Use all available cores for faster search at higher difficulties.
    _send(
        'setoption name Threads value ${difficulty == AIDifficulty.hard ? 4 : 2}');
    _send('setoption name Hash value 64');
  }

  /// Asks Stockfish for the best move in [fen], thinking for up to
  /// [moveTimeMs] milliseconds (or a fixed [depth] if provided instead).
  /// Returns the move in UCI notation, e.g. "e2e4" or "e7e8q".
  Future<String?> getBestMove(
    String fen, {
    int? moveTimeMs,
    int? depth,
  }) async {
    await initialize();

    final completer = Completer<String?>();
    StreamSubscription<String>? sub;
    sub = _stockfish!.stdout.listen((line) {
      final trimmed = line.trim();
      if (trimmed.startsWith('bestmove')) {
        final parts = trimmed.split(' ');
        final move = parts.length > 1 ? parts[1] : null;
        if (!completer.isCompleted) {
          completer.complete(move == '(none)' ? null : move);
        }
        sub?.cancel();
      }
    });

    _send('position fen $fen');
    if (depth != null) {
      _send('go depth $depth');
    } else {
      _send('go movetime ${moveTimeMs ?? 800}');
    }

    try {
      return await completer.future.timeout(
        Duration(
            milliseconds: (moveTimeMs ?? (depth != null ? 5000 : 800)) + 5000),
        onTimeout: () {
          sub?.cancel();
          _send('stop');
          return null;
        },
      );
    } finally {
      await sub.cancel();
    }
  }

  /// Evaluates [fen] for up to [moveTimeMs] milliseconds and returns the
  /// score in centipawns from White's perspective (positive favors White),
  /// or null if no score was reported before the engine settled on a move.
  /// A forced mate is reported as a large magnitude score (±100000, further
  /// reduced by however many moves away the mate is) so it still sorts
  /// correctly against ordinary centipawn scores.
  Future<int?> evaluatePosition(String fen, {int moveTimeMs = 500}) async {
    await initialize();

    final completer = Completer<int?>();
    int? lastScore;
    StreamSubscription<String>? sub;
    sub = _stockfish!.stdout.listen((line) {
      final trimmed = line.trim();
      if (trimmed.startsWith('info') && trimmed.contains('score')) {
        final cpMatch = RegExp(r'score cp (-?\d+)').firstMatch(trimmed);
        final mateMatch = RegExp(r'score mate (-?\d+)').firstMatch(trimmed);
        if (cpMatch != null) {
          lastScore = int.parse(cpMatch.group(1)!);
        } else if (mateMatch != null) {
          final movesToMate = int.parse(mateMatch.group(1)!);
          lastScore =
              movesToMate >= 0 ? 100000 - movesToMate : -100000 - movesToMate;
        }
      }
      if (trimmed.startsWith('bestmove') && !completer.isCompleted) {
        completer.complete(lastScore);
      }
    });

    _send('position fen $fen');
    _send('go movetime $moveTimeMs');

    try {
      return await completer.future.timeout(
        Duration(milliseconds: moveTimeMs + 5000),
        onTimeout: () {
          _send('stop');
          return lastScore;
        },
      );
    } finally {
      await sub.cancel();
    }
  }

  void _send(String command) {
    if (_stockfish == null) return;
    _stockfish!.stdin = command;
  }

  Future<void> dispose() async {
    await _stdoutSub?.cancel();
    _stockfish?.dispose();
    _stockfish = null;
    _uciReady = false;
  }
}
