import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/lesson.dart';

/// Tracks a signed-in user's progress through the app's built-in curriculum
/// (`ChessCurriculumData`'s tactics/opening/strategy content). The content
/// itself is static and bundled with the app (see `chess_curriculum_data.dart`);
/// this service only persists each user's own `UserLessonProgress` against
/// it, under `users/{uid}/lesson_progress/{contentType}_{contentId}`.
class ChessLessonsService {
  ChessLessonsService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _progressCollection(
          String userId) =>
      _firestore.collection('users').doc(userId).collection('lesson_progress');

  /// Deterministic doc id so re-opening the same content never creates a
  /// duplicate progress record - `contentType` is one of 'tactic',
  /// 'opening', 'strategy', matching the three built-in curriculum lists.
  static String lessonKey(String contentType, String contentId) =>
      '${contentType}_$contentId';

  /// Starts (or resumes) tracking progress for a piece of lesson content,
  /// returning the existing record if the user has opened it before.
  Future<UserLessonProgress> startLesson({
    required String userId,
    required String contentType,
    required String contentId,
  }) async {
    final key = lessonKey(contentType, contentId);
    final ref = _progressCollection(userId).doc(key);
    final doc = await ref.get();
    if (doc.exists) {
      return UserLessonProgress.fromJson(doc.data()!);
    }

    final now = DateTime.now();
    final progress = UserLessonProgress(
      id: key,
      userId: userId,
      lessonId: key,
      status: LessonStatus.inProgress,
      percentageComplete: 0,
      timesReviewed: 1,
      startedDate: now,
      completedDate: null,
      lastAccessedDate: now,
      selfAssessmentScore: 0,
      notesAdded: const [],
      interactionData: const {},
    );
    await ref.set(progress.toJson());
    return progress;
  }

  /// Updates a lesson's completion percentage, flipping its status to
  /// completed once it reaches 100. Bumps `lastAccessedDate`/
  /// `timesReviewed` on every call, including ones after completion (so
  /// re-reading a finished guide still counts as a review).
  Future<UserLessonProgress> updateLessonProgress({
    required String userId,
    required String contentType,
    required String contentId,
    required int percentageComplete,
  }) async {
    final key = lessonKey(contentType, contentId);
    final ref = _progressCollection(userId).doc(key);
    final doc = await ref.get();
    final existing =
        doc.exists ? UserLessonProgress.fromJson(doc.data()!) : null;

    final now = DateTime.now();
    final clamped = percentageComplete.clamp(0, 100).toInt();
    final completed = clamped >= 100;

    final progress = UserLessonProgress(
      id: key,
      userId: userId,
      lessonId: key,
      status: completed ? LessonStatus.completed : LessonStatus.inProgress,
      percentageComplete: clamped,
      timesReviewed: (existing?.timesReviewed ?? 0) + 1,
      startedDate: existing?.startedDate ?? now,
      completedDate: completed ? (existing?.completedDate ?? now) : null,
      lastAccessedDate: now,
      selfAssessmentScore: existing?.selfAssessmentScore ?? 0,
      notesAdded: existing?.notesAdded ?? const [],
      interactionData: existing?.interactionData ?? const {},
    );
    await ref.set(progress.toJson());
    return progress;
  }

  /// Records the user's own 1-5 rating of how well they understood a
  /// piece of content - selfAssessmentScore existed on the model from
  /// the start but nothing ever wrote anything but its default 0 into
  /// it, and nothing read it back; this is the first real writer.
  /// Doesn't touch percentageComplete/status, so rating a lesson is
  /// independent of marking it complete (a user could rate without
  /// finishing, though the UI only offers this right after completing).
  Future<UserLessonProgress> setSelfAssessmentScore({
    required String userId,
    required String contentType,
    required String contentId,
    required double score,
  }) async {
    final key = lessonKey(contentType, contentId);
    final ref = _progressCollection(userId).doc(key);
    final doc = await ref.get();
    final existing =
        doc.exists ? UserLessonProgress.fromJson(doc.data()!) : null;

    final now = DateTime.now();
    final clampedScore = score.clamp(1.0, 5.0);
    final progress = UserLessonProgress(
      id: key,
      userId: userId,
      lessonId: key,
      status: existing?.status ?? LessonStatus.inProgress,
      percentageComplete: existing?.percentageComplete ?? 0,
      timesReviewed: existing?.timesReviewed ?? 1,
      startedDate: existing?.startedDate ?? now,
      completedDate: existing?.completedDate,
      lastAccessedDate: now,
      selfAssessmentScore: clampedScore,
      notesAdded: existing?.notesAdded ?? const [],
      interactionData: existing?.interactionData ?? const {},
    );
    await ref.set(progress.toJson());
    return progress;
  }

  /// All of [userId]'s lesson progress records, keyed by `lessonKey`.
  Future<List<UserLessonProgress>> getUserProgress(String userId) async {
    final snapshot = await _progressCollection(userId).get();
    return snapshot.docs
        .map((d) => UserLessonProgress.fromJson(d.data()))
        .toList();
  }

  /// Live stream of [userId]'s lesson progress records.
  Stream<List<UserLessonProgress>> watchUserProgress(String userId) =>
      _progressCollection(userId).snapshots().map(
            (s) => s.docs
                .map((d) => UserLessonProgress.fromJson(d.data()))
                .toList(),
          );
}
