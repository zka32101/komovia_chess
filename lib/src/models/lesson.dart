import 'package:freezed_annotation/freezed_annotation.dart';

part 'lesson.freezed.dart';
part 'lesson.g.dart';

enum DifficultyLevel {
  @JsonValue('beginner')
  beginner,
  @JsonValue('intermediate')
  intermediate,
  @JsonValue('advanced')
  advanced,
  @JsonValue('expert')
  expert,
}

enum ContentType {
  @JsonValue('opening')
  opening,
  @JsonValue('tactic')
  tactic,
  @JsonValue('strategy')
  strategy,
}

enum LessonStatus {
  @JsonValue('not_started')
  notStarted,
  @JsonValue('in_progress')
  inProgress,
  @JsonValue('completed')
  completed,
  @JsonValue('reviewed')
  reviewed,
}

@freezed
class ChessLesson with _$ChessLesson {
  const factory ChessLesson({
    required String id,
    required String title,
    required String description,
    required ContentType type,
    required DifficultyLevel difficulty,
    required List<String> pgn,
    required List<String> keyPoints,
    required List<String> commonMistakes,
    required String instructorNotes,
    required int estimatedDurationMinutes,
    required List<String> prerequisites,
    required List<String> relatedTopics,
    required int totalStudents,
    required double averageRating,
    required DateTime createdDate,
    required DateTime updatedDate,
  }) = _ChessLesson;

  factory ChessLesson.fromJson(Map<String, dynamic> json) =>
      _$ChessLessonFromJson(json);
}

@freezed
class OpeningExplanation with _$OpeningExplanation {
  const factory OpeningExplanation({
    required String id,
    required String name,
    required String ecoCode,
    required String description,
    required DifficultyLevel difficulty,
    required List<String> mainLinesPgn,
    required List<String> alternativeLinesPgn,
    required List<String> strategicIdeas,
    required List<String> typicalPlans,
    required List<String> commonTrapsPgn,
    required List<String> historyNotes,
    required Map<String, double> statistics,
    required int totalGamesWithOpening,
    required double winRateWhite,
    required double winRateBlack,
    required double drawRate,
    required DateTime createdDate,
  }) = _OpeningExplanation;

  factory OpeningExplanation.fromJson(Map<String, dynamic> json) =>
      _$OpeningExplanationFromJson(json);
}

@freezed
class TacticsPattern with _$TacticsPattern {
  const factory TacticsPattern({
    required String id,
    required String name,
    required String description,
    required DifficultyLevel difficulty,
    required List<String> examplePositionsPgn,
    required List<String> recognitionFeatures,
    required List<String> executionSteps,
    required List<String> relatedTactics,
    required String motif,
    required int typicalOccurrenceFrequency,
    required DateTime createdDate,
  }) = _TacticsPattern;

  factory TacticsPattern.fromJson(Map<String, dynamic> json) =>
      _$TacticsPatternFromJson(json);
}

@freezed
class StrategyGuide with _$StrategyGuide {
  const factory StrategyGuide({
    required String id,
    required String title,
    required String description,
    required DifficultyLevel difficulty,
    required List<String> principlesPgn,
    required List<String> keyConceptsExplained,
    required List<String> positionEvaluationCriteria,
    required List<String> planFormationGuidelines,
    required List<String> endgameTransitionTips,
    required List<String> relatedStrategies,
    required DateTime createdDate,
  }) = _StrategyGuide;

  factory StrategyGuide.fromJson(Map<String, dynamic> json) =>
      _$StrategyGuideFromJson(json);
}

@freezed
class UserLessonProgress with _$UserLessonProgress {
  const factory UserLessonProgress({
    required String id,
    required String userId,
    required String lessonId,
    required LessonStatus status,
    required int percentageComplete,
    required int timesReviewed,
    required DateTime startedDate,
    required DateTime? completedDate,
    required DateTime lastAccessedDate,
    required double selfAssessmentScore,
    required List<String> notesAdded,
    required Map<String, dynamic> interactionData,
  }) = _UserLessonProgress;

  factory UserLessonProgress.fromJson(Map<String, dynamic> json) =>
      _$UserLessonProgressFromJson(json);
}

@freezed
class LessonCollection with _$LessonCollection {
  const factory LessonCollection({
    required String id,
    required String name,
    required String description,
    required List<String> lessonIds,
    required DifficultyLevel targetDifficulty,
    required int estimatedTotalHours,
    required int studentEnrollmentCount,
    required double averageCompletionRate,
    required DateTime createdDate,
  }) = _LessonCollection;

  factory LessonCollection.fromJson(Map<String, dynamic> json) =>
      _$LessonCollectionFromJson(json);
}
