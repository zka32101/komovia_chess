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
      onPressed: isCompleted
          ? null
          : () => ref.read(lessonProgressActionsProvider).markComplete(
                contentType: widget.contentType,
                contentId: widget.contentId,
              ),
    );
  }
}
