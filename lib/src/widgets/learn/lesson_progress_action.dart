import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/lesson.dart';
import '../../providers/phase_i_providers.dart';

/// Records that the signed-in user has opened [contentType]/[contentId]
/// (one of `ChessCurriculumData`'s tactics/openings/strategy guides) and
/// shows a "mark complete" action reflecting their current progress
/// against it. Safe to drop into a `Scaffold.appBar.actions` as-is - it
/// manages its own provider access and silently no-ops while signed out.
class LessonProgressAction extends ConsumerStatefulWidget {
  const LessonProgressAction({
    required this.contentType,
    required this.contentId,
    super.key,
  });
  final String contentType;
  final String contentId;

  @override
  ConsumerState<LessonProgressAction> createState() =>
      _LessonProgressActionState();
}

class _LessonProgressActionState extends ConsumerState<LessonProgressAction> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(lessonProgressActionsProvider).startLesson(
            contentType: widget.contentType,
            contentId: widget.contentId,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(
      lessonProgressProvider(
        (contentType: widget.contentType, contentId: widget.contentId),
      ),
    );
    final isCompleted = progress?.status == LessonStatus.completed;

    return IconButton(
      tooltip: isCompleted ? '完了済み' : '完了にする',
      icon: Icon(
        isCompleted ? Icons.check_circle : Icons.check_circle_outline,
        color: isCompleted ? Colors.green : null,
      ),
      onPressed: isCompleted ? null : _handleMarkComplete,
    );
  }

  Future<void> _handleMarkComplete() async {
    await ref.read(lessonProgressActionsProvider).markComplete(
          contentType: widget.contentType,
          contentId: widget.contentId,
        );
    if (!mounted) return;
    // selfAssessmentScore existed on UserLessonProgress from the start
    // but nothing ever asked the user for it - prompting right after
    // completion (rather than a separate always-visible control) keeps
    // this optional and out of the way for anyone who just wants to
    // tick lessons off.
    final score = await showDialog<double>(
      context: context,
      builder: (context) => const _SelfAssessmentDialog(),
    );
    if (score == null) return;
    await ref.read(lessonProgressActionsProvider).rateSelfAssessment(
          contentType: widget.contentType,
          contentId: widget.contentId,
          score: score,
        );
  }
}

class _SelfAssessmentDialog extends StatelessWidget {
  const _SelfAssessmentDialog();

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('理解度を評価'),
        content: const Text('このレッスンの内容をどのくらい理解できましたか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('スキップ'),
          ),
          for (var score = 1; score <= 5; score++)
            IconButton(
              tooltip: '$score',
              onPressed: () => Navigator.of(context).pop(score.toDouble()),
              icon: Icon(
                Icons.star,
                color: Colors.amber.shade700,
                size: 20 + score * 2,
              ),
            ),
        ],
      );
}
