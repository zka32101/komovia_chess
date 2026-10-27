import 'dart:async';
import 'package:stockfish/stockfish.dart';
import 'ai_opponent_engine.dart' show AIDifficulty;

/// Approximate playing strength (UCI_Elo) and thinking budget per difficulty.
/// Stockfish's `UCI_LimitStrength` + `UCI_Elo` options let a full-strength
/// engine play at a deliberately weaker, more human-like level instead of
/// just capping search depth.
extension AIDifficultyStockfishExt on AIDifficulty {
  /// Stockfish clamps `UCI_Elo` to its own internal floor (roughly 1320 on
  /// modern versions) regardless of what's requested below that - so
  /// `beginner` requests the floor here, but is actually made weak by
  /// `AIDifficulty.blunderProbability`'s random-move substitution
  /// (CpuGameNotifier._requestAiMove), not by this Elo value alone.
  int get stockfishElo {
    switch (this) {
      case AIDifficulty.beginner:
        return 1320;
      case AIDifficulty.easy:
        return 800;
      case AIDifficulty.medium:
        return 1500;
      case AIDifficulty.hard:
        return 2200;
      case AIDifficulty.master:
        return 2800;
    }
  }

  int get stockfishMoveTimeMs {
    switch (this) {
      case AIDifficulty.beginner:
        return 150;
      case AIDifficulty.easy:
        return 300;
      case AIDifficulty.medium:
        return 800;
      case AIDifficulty.hard:
        return 2000;
      case AIDifficulty.master:
        return 3500;
    }
  }

  /// クイック対局（[cpuQuickGameProvider]がtrue）時に使うAIの着手時間。
  /// 通常の[stockfishMoveTimeMs]より短く固定し、一局全体の所要時間を
  /// 読みやすくする（komovia_shogiの`ShogiDifficultyExt.quickTimeBudget`
  /// と同じ、将棋版で先に採った「持ち時間を短くする」アプローチ）。
  /// 強い設定ほど長め — 難易度の選択自体は、クイック対局中も「読みの質」
  /// として意味を持つ。
  int get quickMoveTimeMs {
    switch (this) {
      case AIDifficulty.beginner:
        return 80;
      case AIDifficulty.easy:
        return 150;
      case AIDifficulty.medium:
        return 250;
      case AIDifficulty.hard:
        return 400;
      case AIDifficulty.master:
        return 600;
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

  // Stockfish.stdout is a single broadcast stream over one physical engine
  // process/search - getBestMove/evaluatePosition each used to attach their
  // own listener and fire position/go independently, so two overlapping
  // calls (e.g. GameReviewScreen firing evaluatePosition on every seek/
  // autoplay tick, or a CPU move request landing while a review screen's
  // analysis is still running) would have both listeners see both
  // searches' output and could each resolve from the WRONG bestmove/score
  // line - silently wrong analysis or AI moves, no error surfaced anywhere.
  // Chaining every call through this queue guarantees only one
  // position+go+listen sequence is ever in flight on the shared process.
  Future<void> _queue = Future<void>.value();

  Future<T> _runExclusive<T>(Future<T> Function() task) {
    final resultCompleter = Completer<T>();
    _queue = _queue.then((_) async {
      try {
        resultCompleter.complete(await task());
      } catch (e, st) {
        resultCompleter.completeError(e, st);
      }
    });
    return resultCompleter.future;
  }

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
    return _runExclusive(() => _getBestMoveNow(fen, moveTimeMs, depth));
  }

  Future<String?> _getBestMoveNow(
    String fen,
    int? moveTimeMs,
    int? depth,
  ) async {
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
  /// When [depth] is given, evaluates to that fixed search depth instead
  /// of a time budget - lets the user trade analysis quality for speed via
  /// Settings' "Analysis Depth" preference, the same way [getBestMove]'s
  /// own [depth] parameter already does for the CPU opponent.
  Future<int?> evaluatePosition(String fen,
      {int moveTimeMs = 500, int? depth}) async {
    await initialize();
    return _runExclusive(() => _evaluatePositionNow(fen, moveTimeMs, depth));
  }

  Future<int?> _evaluatePositionNow(
    String fen,
    int moveTimeMs,
    int? depth,
  ) async {
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
    if (depth != null) {
      _send('go depth $depth');
    } else {
      _send('go movetime $moveTimeMs');
    }

    final timeoutMs = depth != null ? 15000 : moveTimeMs + 5000;
    try {
      return await completer.future.timeout(
        Duration(milliseconds: timeoutMs),
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
