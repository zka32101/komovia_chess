import 'package:freezed_annotation/freezed_annotation.dart';

part 'feedback.freezed.dart';
part 'feedback.g.dart';

enum FeedbackCategory {
  @JsonValue('bug')
  bug,
  @JsonValue('feature')
  feature,
  @JsonValue('general')
  general,
  @JsonValue('ui')
  ui,
  @JsonValue('performance')
  performance,
}

enum BugSeverity {
  @JsonValue('critical')
  critical,
  @JsonValue('high')
  high,
  @JsonValue('medium')
  medium,
  @JsonValue('low')
  low,
}

enum BugStatus {
  @JsonValue('new')
  new_,
  @JsonValue('acknowledged')
  acknowledged,
  @JsonValue('in_progress')
  inProgress,
  @JsonValue('fixed')
  fixed,
}

enum RequestStatus {
  @JsonValue('new')
  new_,
  @JsonValue('under_review')
  underReview,
  @JsonValue('planned')
  planned,
  @JsonValue('in_development')
  inDevelopment,
  @JsonValue('completed')
  completed,
}

@freezed
class UserFeedback with _$UserFeedback {
  const factory UserFeedback({
    required String id,
    required String userId,
    required FeedbackCategory category,
    required String message,
    required int rating,
    required String deviceInfo,
    required String appVersion,
    required DateTime timestamp,
    required Map<String, dynamic> metadata,
  }) = _UserFeedback;

  factory UserFeedback.fromJson(Map<String, dynamic> json) =>
      _$UserFeedbackFromJson(json);
}

@freezed
class BugReport with _$BugReport {
  const factory BugReport({
    required String id,
    required String userId,
    required String title,
    required String description,
    required BugSeverity severity,
    required String deviceInfo,
    required String appVersion,
    required bool reproducible,
    required List<String> steps,
    required BugStatus status,
    required DateTime timestamp,
    String? stackTrace,
  }) = _BugReport;

  factory BugReport.fromJson(Map<String, dynamic> json) =>
      _$BugReportFromJson(json);
}

@freezed
class FeatureRequest with _$FeatureRequest {
  const factory FeatureRequest({
    required String id,
    required String userId,
    required String title,
    required String description,
    required int votesCount,
    required String category,
    required int priority,
    required RequestStatus status,
    required DateTime timestamp,
  }) = _FeatureRequest;

  factory FeatureRequest.fromJson(Map<String, dynamic> json) =>
      _$FeatureRequestFromJson(json);
}
