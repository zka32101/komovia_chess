import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/repertoire_line.dart';
import '../../providers/repertoire_provider.dart';
import '../../services/chess_engine_service.dart';
import '../../widgets/game_board.dart';

enum _ReviewFeedback { none, correct, wrong }

/// Quizzes the player on every line in [lines] in turn, same alternating
/// solver/auto-play flow as `PuzzleSolvingScreen`: at each ply belonging
/// to the line's own side ([RepertoireLine.playerIsWhite]), the player
/// must find the move actually recorded in [RepertoireLine.moveUcis];
/// the opponent's replies are always auto-played. Getting every one of
/// the player's own moves right advances the line's Leitner box; a single
/// wrong move anywhere in the line resets it to box 1 and reveals the
/// correct move.
class RepertoireReviewScreen extends ConsumerStatefulWidget {
  const RepertoireReviewScreen({required this.uid, required this.lines, Key? key})
      : super(key: key);
  final String uid;
  final List<RepertoireLine> lines;

  @override
  ConsumerState<RepertoireReviewScreen> createState() =>
      _RepertoireReviewScreenState();
}

class _RepertoireReviewScreenState
    extends ConsumerState<RepertoireReviewScreen> {
  final _chess = ChessEngineService();
  int _lineIndex = 0;
  int _moveIndex = 0;
  String? _loadedLineId;
  bool _isPlayerTurn = true;
  _ReviewFeedback _feedback = _ReviewFeedback.none;
  String? _correctMoveLabel;
  int _reviewedCount = 0;
  int _correctCount = 0;

  RepertoireLine get _currentLine => widget.lines[_lineIndex];

  bool get _finished => _lineIndex >= widget.lines.length;

  /// Whose turn it is at ply [moveIndex] (0-based, white moves first).
  bool _plyBelongsToPlayer(RepertoireLine line, int moveIndex) =>
      (moveIndex.isEven) == line.playerIsWhite;

  /// Sets up [line] as the one currently on the board: resets the engine,
  /// then auto-plays any opponent moves at the very start (this line is
  /// for Black, so White's opening move needs to be played before the
  /// player's first turn). Mutates state fields directly without
  /// `setState` - every caller either runs before the first build
  /// (`initState`) or is itself already inside a `setState`.
  void _loadLine(RepertoireLine line) {
    _chess.initGame();
    _loadedLineId = line.id;
    _moveIndex = 0;
    _feedback = _ReviewFeedback.none;
    _correctMoveLabel = null;
    _autoPlayOpponentMoves(line);
  }

  /// Plays every consecutive opponent-side move starting at [_moveIndex],
  /// stopping as soon as it's the player's turn again (or the line ends,
  /// which only happens for a degenerate line with no moves on the
  /// player's own side at all - treated as an automatic pass, since
  /// there's nothing to quiz). Never itself completes the line; the
  /// caller is responsible for checking whether the line just ran out.
  void _autoPlayOpponentMoves(RepertoireLine line) {
    while (_moveIndex < line.moveUcis.length &&
        !_plyBelongsToPlayer(line, _moveIndex)) {
      _chess.makeMoveUCI(line.moveUcis[_moveIndex]);
      _moveIndex++;
    }
    _isPlayerTurn = _moveIndex < line.moveUcis.length;
  }

  Future<void> _handleMove(String from, String to, {String? promotion}) async {
    if (!_isPlayerTurn || _finished) return;
    final line = _currentLine;
    final attempted = '$from$to${promotion ?? ''}'.toLowerCase();
    final expected = line.moveUcis[_moveIndex].toLowerCase();

    if (attempted != expected) {
      setState(() {
        _feedback = _ReviewFeedback.wrong;
        _correctMoveLabel = _formatUci(expected);
        _isPlayerTurn = false;
      });
      await Future.delayed(const Duration(milliseconds: 1400));
      if (!mounted || _loadedLineId != line.id) return;
      _completeLine(correct: false);
      return;
    }

    setState(() {
      _chess.makeMove(from, to, promotion: promotion);
      _moveIndex++;
      _feedback = _ReviewFeedback.correct;
      _isPlayerTurn = false;
    });

    if (_moveIndex >= line.moveUcis.length) {
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted || _loadedLineId != line.id) return;
      _completeLine(correct: true);
      return;
    }

    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted || _loadedLineId != line.id) return;
    setState(() {
      _feedback = _ReviewFeedback.none;
      _autoPlayOpponentMoves(line);
    });
    if (_moveIndex >= line.moveUcis.length) {
      _completeLine(correct: true);
    }
  }

  void _completeLine({required bool correct}) {
    final line = _currentLine;
    _reviewedCount++;
    if (correct) _correctCount++;

    // Best-effort - a failed write here shouldn't block moving on to the
    // next line in the session (same convention as fire-and-forget
    // background writes elsewhere in this app, e.g. PuzzleSolvingScreen's
    // `_recordAttempt`).
    unawaited(
      ref
          .read(repertoireServiceProvider)
          .recordReview(uid: widget.uid, line: line, correct: correct)
          .catchError((_) => line),
    );

    setState(() {
      _lineIndex++;
      _loadedLineId = null;
      if (!_finished) {
        _loadLine(_currentLine);
      } else {
        // Refreshes the management screen's due-count/box display once
        // the player backs out of this session.
        ref.invalidate(repertoireLinesProvider(widget.uid));
        ref.invalidate(dueRepertoireLinesProvider(widget.uid));
      }
    });
  }

  String _formatUci(String uci) {
    final withoutPromotion =
        uci.length > 4 ? uci.substring(0, 4) : uci;
    if (withoutPromotion.length < 4) return uci;
    final from = withoutPromotion.substring(0, 2);
    final to = withoutPromotion.substring(2, 4);
    final promotion = uci.length > 4 ? uci.substring(4) : null;
    return promotion == null
        ? '$from → $to'
        : '$from → $to (=${promotion.toUpperCase()})';
  }

  @override
  void initState() {
    super.initState();
    if (widget.lines.isNotEmpty) {
      _loadLine(_currentLine);
      if (_moveIndex >= _currentLine.moveUcis.length) {
        // Degenerate line with no moves on the player's own side at all -
        // nothing to quiz, so count it as an automatic pass on the next
        // frame (not synchronously, since `_completeLine` calls
        // `setState` and this runs during `initState`, before the first
        // build).
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _completeLine(correct: true));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.lines.isEmpty || _finished) {
      return Scaffold(
        appBar: AppBar(title: const Text('復習')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.emoji_events, color: Colors.amber, size: 48),
                const SizedBox(height: 16),
                Text(
                  _reviewedCount == 0
                      ? '復習するレパートリーはありません。'
                      : '復習完了！ $_reviewedCount本中 $_correctCount本正解',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('戻る'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final line = _currentLine;
    return Scaffold(
      appBar: AppBar(
        title: Text('復習 ${_lineIndex + 1}/${widget.lines.length}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              '${line.name}（${line.playerIsWhite ? "白番" : "黒番"} · Box ${line.box}）',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildFeedbackBanner(),
            const SizedBox(height: 12),
            GameBoard(
              gameState: _chess.rawChess,
              onMove: _handleMove,
              isPlayerTurn: _isPlayerTurn,
              showMaterial: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackBanner() {
    switch (_feedback) {
      case _ReviewFeedback.correct:
        return const _FeedbackChip(
          text: '正解！',
          color: Colors.green,
          icon: Icons.check_circle,
        );
      case _ReviewFeedback.wrong:
        return _FeedbackChip(
          text: '不正解。正しい手: $_correctMoveLabel',
          color: Colors.red,
          icon: Icons.cancel,
        );
      case _ReviewFeedback.none:
        return const Text(
          '次の一手を指してください',
          style: TextStyle(color: Colors.grey),
        );
    }
  }
}

class _FeedbackChip extends StatelessWidget {
  const _FeedbackChip({required this.text, required this.color, required this.icon});
  final String text;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                text,
                style: TextStyle(color: color, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
}
