import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/puzzle.dart';
import '../../providers/puzzle_provider.dart';
import '../../services/chess_engine_service.dart';
import '../../widgets/game_board.dart';

/// Puzzle Rush: solve as many tactics puzzles as possible before the clock
/// runs out or three wrong moves are made - a standard engagement-loop
/// feature on competitor chess apps that this app didn't have (unlike the
/// already-existing Daily Challenge, which tracks a day-to-day streak
/// instead of a single timed session).
///
/// A wrong move costs a life and immediately moves on to the next puzzle
/// (there's no retry) - this matches how the mode is commonly played
/// elsewhere, keeping the pace fast rather than letting one hard puzzle
/// stall the whole run.
class PuzzleRushScreen extends ConsumerStatefulWidget {
  const PuzzleRushScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<PuzzleRushScreen> createState() => _PuzzleRushScreenState();
}

enum _RushFeedback { none, correct, wrong }

class _PuzzleRushScreenState extends ConsumerState<PuzzleRushScreen> {
  static const _runDuration = Duration(minutes: 3);
  static const _startingLives = 3;

  final _chess = ChessEngineService();
  List<PuzzleModel> _queue = [];
  int _queueIndex = -1;
  int _moveIndex = 0;
  bool _isPlayerTurn = true;
  int _score = 0;
  int _lives = _startingLives;
  Duration _remaining = _runDuration;
  Timer? _timer;
  _RushFeedback _feedback = _RushFeedback.none;
  bool _loading = true;
  bool _finished = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadQueue();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadQueue() async {
    try {
      final service = ref.read(puzzleServiceProvider);
      // A single wide rating band gives a shuffled mix of easy and hard
      // puzzles rather than a strict difficulty ramp - simple and good
      // enough for a first version of this mode.
      final puzzles = await service.getPuzzlesByRating(400, 2800, limit: 60);
      if (!mounted) return;
      if (puzzles.isEmpty) {
        setState(() {
          _loading = false;
          _error = 'No puzzles available right now.';
        });
        return;
      }
      puzzles.shuffle(Random());
      setState(() {
        _queue = puzzles;
        _loading = false;
      });
      _advanceToNextPuzzle();
      _startTimer();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load puzzles: $e';
      });
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _remaining -= const Duration(seconds: 1);
      });
      if (_remaining <= Duration.zero) {
        _endRun();
      }
    });
  }

  void _advanceToNextPuzzle() {
    if (_queue.isEmpty) return;
    _queueIndex = (_queueIndex + 1) % _queue.length;
    final puzzle = _queue[_queueIndex];
    _chess.initGame(fen: puzzle.fen);
    setState(() {
      _moveIndex = 0;
      _isPlayerTurn = true;
      _feedback = _RushFeedback.none;
    });
  }

  Future<void> _handleMove(String from, String to, {String? promotion}) async {
    if (_finished || _queueIndex < 0) return;
    final puzzle = _queue[_queueIndex];
    if (!_isPlayerTurn) return;

    final attempted = '$from$to${promotion ?? ''}'.toLowerCase();
    final expected = puzzle.moves[_moveIndex].toLowerCase();

    if (attempted != expected) {
      setState(() {
        _feedback = _RushFeedback.wrong;
        _lives--;
      });
      if (_lives <= 0) {
        _endRun();
        return;
      }
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      _advanceToNextPuzzle();
      return;
    }

    setState(() {
      _chess.makeMove(from, to, promotion: promotion);
      _moveIndex++;
      _feedback = _RushFeedback.correct;
    });

    if (_moveIndex >= puzzle.moves.length) {
      setState(() => _score++);
      await Future.delayed(const Duration(milliseconds: 250));
      if (!mounted) return;
      _advanceToNextPuzzle();
      return;
    }

    // Auto-play the opponent's reply, same as the regular puzzle screen.
    setState(() => _isPlayerTurn = false);
    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;

    setState(() {
      _chess.makeMoveUCI(puzzle.moves[_moveIndex]);
      _moveIndex++;
      _feedback = _RushFeedback.none;
      _isPlayerTurn = _moveIndex < puzzle.moves.length;
    });

    if (_moveIndex >= puzzle.moves.length) {
      setState(() => _score++);
      await Future.delayed(const Duration(milliseconds: 250));
      if (!mounted) return;
      _advanceToNextPuzzle();
    }
  }

  void _endRun() {
    if (_finished) return;
    _timer?.cancel();
    setState(() => _finished = true);
    ref
        .read(puzzleServiceProvider)
        .recordPuzzleRushScore(_score)
        .catchError((_) {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Puzzle Rush'),
          centerTitle: true,
          elevation: 0,
        ),
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text(_error!))
                  : _finished
                      ? _buildResult()
                      : _buildRun(),
        ),
      );

  Widget _buildRun() => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStat(Icons.timer_outlined, _formatDuration(_remaining)),
                _buildStat(Icons.emoji_events_outlined, 'Score $_score'),
                _buildStat(Icons.favorite, '×$_lives', color: Colors.red),
              ],
            ),
            const SizedBox(height: 12),
            if (_feedback != _RushFeedback.none)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _feedback == _RushFeedback.correct ? 'Correct!' : 'Wrong move',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _feedback == _RushFeedback.correct
                        ? Colors.green
                        : Colors.red,
                  ),
                ),
              ),
            Expanded(
              child: Center(
                child: GameBoard(
                  gameState: _chess.rawChess,
                  isPlayerTurn: _isPlayerTurn,
                  showMaterial: false,
                  onMove: _isPlayerTurn ? _handleMove : null,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _buildStat(IconData icon, String label, {Color? color}) => Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      );

  Widget _buildResult() {
    final bestScore = ref.watch(puzzleRushBestScoreProvider);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events, size: 64, color: Colors.amber),
            const SizedBox(height: 16),
            Text(
              'Score: $_score',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            bestScore.when(
              data: (best) => Text(
                _score >= best && _score > 0
                    ? 'New best score!'
                    : 'Best: $best',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: _score >= best && _score > 0
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _finished = false;
                  _score = 0;
                  _lives = _startingLives;
                  _remaining = _runDuration;
                  _queueIndex = -1;
                });
                _advanceToNextPuzzle();
                _startTimer();
              },
              child: const Text('Play Again'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Back to Puzzles'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final clamped = d.isNegative ? Duration.zero : d;
    final minutes = clamped.inMinutes;
    final seconds = clamped.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
