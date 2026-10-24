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
/// many they have started, plus their average self-assessment rating
/// (1-5) across whatever lessons they've actually rated - used for a
/// simple completion/mastery badge on the learn hub. 0 when nothing's
/// been rated yet, distinct from "rated 0" (ratings are clamped to 1-5
/// at write time, so a real average is never exactly 0).
final lessonCompletionSummaryProvider =
    Provider<({int completed, int started, double averageMastery})>((ref) {
  final all = ref.watch(userLessonProgressProvider).value ?? const [];
  final completed =
      all.where((p) => p.status == LessonStatus.completed).length;
  final rated = all.where((p) => p.selfAssessmentScore > 0).toList();
  final averageMastery = rated.isEmpty
      ? 0.0
      : rated.fold(0.0, (sum, p) => sum + p.selfAssessmentScore) / rated.length;
  return (completed: completed, started: all.length, averageMastery: averageMastery);
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

  Future<void> rateSelfAssessment({
    required String contentType,
    required String contentId,
    required double score,
  }) async {
    final user = _ref.read(currentUserProvider).value;
    if (user == null) return;
    await _ref.read(chessLessonsServiceProvider).setSelfAssessmentScore(
          userId: user.uid,
          contentType: contentType,
          contentId: contentId,
          score: score,
        );
  }
}
