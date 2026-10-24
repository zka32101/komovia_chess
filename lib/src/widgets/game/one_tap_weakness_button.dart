import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/online_game.dart';
import '../../models/lesson.dart' show ContentType;
import '../../models/weakness_profile.dart';
import '../../providers/auth_provider.dart';
import '../../providers/weakness_analysis_provider.dart';
import '../../screens/learn/opening_course_screen.dart';
import '../../screens/learn/strategy_screen.dart';
import '../../screens/learn/tactics_screen.dart';
import '../../services/chess_analysis_service.dart';

/// One-tap "analyze this game, then take me straight to the lesson for my
/// weakest area" button, for the result screen right after a game ends.
///
/// Previously the only path to this app's weakness analysis (PR #154) was
/// several separate steps: open the game review, tap "Analyze Game", wait,
/// then separately navigate to the Learn hub to notice the weakness card
/// and tap into a lesson - a player who didn't already know that card
/// existed would never discover it at all. This collapses the whole
/// analyze -> aggregate -> recommend -> navigate chain into one button.
class OneTapWeaknessButton extends ConsumerStatefulWidget {
  const OneTapWeaknessButton({
    required this.moves,
    required this.gameId,
    required this.whitePlayerId,
    required this.blackPlayerId,
    this.startingFen,
    Key? key,
  }) : super(key: key);

  final List<GameMove> moves;
  final String gameId;
  final String whitePlayerId;
  final String blackPlayerId;
  final String? startingFen;

  @override
  ConsumerState<OneTapWeaknessButton> createState() =>
      _OneTapWeaknessButtonState();
}

class _OneTapWeaknessButtonState extends ConsumerState<OneTapWeaknessButton> {
  bool _isRunning = false;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: _isRunning ? null : _run,
        icon: _isRunning
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.auto_fix_high),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        label: Text(
          _isRunning ? '分析中...' : '弱点を分析してレッスンへ',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      );

  Future<void> _run() async {
    if (widget.moves.isEmpty) {
      _showMessage('この対局は手数が0のため分析できません');
      return;
    }

    setState(() => _isRunning = true);
    try {
      final analysis = await ChessAnalysisService().analyzeGame(
        widget.moves,
        startingFen: widget.startingFen ?? standardStartingFen,
      );

      final uid = ref.read(currentUserProvider).value?.uid;
      if (uid != null) {
        final isWhitePlayer = uid == widget.whitePlayerId ||
            widget.whitePlayerId == 'player';
        final isBlackPlayer = uid == widget.blackPlayerId ||
            widget.blackPlayerId == 'player';
        if (isWhitePlayer || isBlackPlayer) {
          await ref.read(weaknessAnalysisServiceProvider).recordGameAnalysis(
                uid: uid,
                gameId: widget.gameId,
                analysis: analysis,
                isWhitePlayer: isWhitePlayer,
              );
        }
      }

      ref.invalidate(weaknessProfileProvider);
      final profile = uid == null
          ? WeaknessProfile.empty
          : await ref.read(weaknessAnalysisServiceProvider).getWeaknessProfile(uid);

      if (!mounted) return;
      final weakest = profile.weakestPhase;
      if (!profile.hasEnoughData || weakest == null) {
        _showMessage(
          'まだ分析データが十分ではありません。あと数局分析すると、'
          '苦手分野に合わせたレッスンをおすすめできます。',
        );
        return;
      }

      final screen = _screenFor(weakest.recommendedContentType);
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    } catch (e) {
      if (mounted) _showMessage('分析に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isRunning = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _screenFor(ContentType type) {
    switch (type) {
      case ContentType.opening:
        return const OpeningCourseScreen();
      case ContentType.tactic:
        return const TacticsScreen();
      case ContentType.strategy:
        return const StrategyScreen();
    }
  }
}
