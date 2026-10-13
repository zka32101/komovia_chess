import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/lesson.dart';
import '../services/chess_lessons_service.dart';
import 'auth_provider.dart';

final chessLessonsServiceProvider =
    Provider<ChessLessonsService>((ref) => ChessLessonsService());

/// Live progress records for the signed-in user across all built-in
/// curriculum content (tactics/openings/strategy guides).
final userLessonProgressProvider =
    StreamProvider<List<UserLessonProgress>>((ref) {
  final user = ref.watch(currentUserProvider).value;
  if (user == null) return Stream.value(const []);
  return ref.watch(chessLessonsServiceProvider).watchUserProgress(user.uid);
});

/// This user's progress record for one specific piece of content, if any.
final lessonProgressProvider = Provider.family<UserLessonProgress?,
    ({String contentType, String contentId})>((ref, args) {
  final all = ref.watch(userLessonProgressProvider).value ?? const [];
  final key = ChessLessonsService.lessonKey(args.contentType, args.contentId);
  for (final progress in all) {
    if (progress.lessonId == key) return progress;
  }
  return null;
});

/// How many pieces of content the user has marked completed, out of how
/// many they have started - used for a simple completion badge on the
/// learn hub.
final lessonCompletionSummaryProvider =
    Provider<({int completed, int started})>((ref) {
  final all = ref.watch(userLessonProgressProvider).value ?? const [];
  final completed =
      all.where((p) => p.status == LessonStatus.completed).length;
  return (completed: completed, started: all.length);
});

/// Action provider for marking a piece of content as opened/completed.
final lessonProgressActionsProvider =
    Provider<LessonProgressActions>((ref) => LessonProgressActions(ref));

class LessonProgressActions {
  LessonProgressActions(this._ref);
  final Ref _ref;

  Future<void> startLesson({
    required String contentType,
    required String contentId,
  }) async {
    final user = _ref.read(currentUserProvider).value;
    if (user == null) return;
    await _ref.read(chessLessonsServiceProvider).startLesson(
          userId: user.uid,
          contentType: contentType,
          contentId: contentId,
        );
  }

  Future<void> markComplete({
    required String contentType,
    required String contentId,
  }) async {
    final user = _ref.read(currentUserProvider).value;
    if (user == null) return;
    await _ref.read(chessLessonsServiceProvider).updateLessonProgress(
          userId: user.uid,
          contentType: contentType,
          contentId: contentId,
          percentageComplete: 100,
        );
  }
}
