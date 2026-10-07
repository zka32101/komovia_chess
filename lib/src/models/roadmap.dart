import 'package:freezed_annotation/freezed_annotation.dart';

part 'roadmap.freezed.dart';
part 'roadmap.g.dart';

enum RoadmapStatus {
  @JsonValue('planned')
  planned,
  @JsonValue('in_progress')
  inProgress,
  @JsonValue('in_review')
  inReview,
  @JsonValue('completed')
  completed,
  @JsonValue('cancelled')
  cancelled,
}

@freezed
class RoadmapItem with _$RoadmapItem {
  const factory RoadmapItem({
    required String id,
    required String title,
    required String description,
    required String category,
    required int priority,
    required RoadmapStatus status,
    required DateTime targetDate,
    required String targetVersion,
    required int complexity,
    required DateTime createdDate,
    required List<String> relatedFeatureRequests,
    DateTime? completedDate,
  }) = _RoadmapItem;

  factory RoadmapItem.fromJson(Map<String, dynamic> json) =>
      _$RoadmapItemFromJson(json);
}

enum TestStatus {
  @JsonValue('planned')
  planned,
  @JsonValue('active')
  active,
  @JsonValue('paused')
  paused,
  @JsonValue('concluded')
  concluded,
}

@freezed
class Variant with _$Variant {
  const factory Variant({
    required String id,
    required String name,
    required String description,
    required int userCount,
    required double conversionRate,
    required Map<String, double> metrics,
  }) = _Variant;

  factory Variant.fromJson(Map<String, dynamic> json) =>
      _$VariantFromJson(json);
}

@freezed
class TestResult with _$TestResult {
  const factory TestResult({
    required Map<String, double> controlVariantMetrics,
    required Map<String, double> treatmentVariantMetrics,
    required double statisticalSignificance,
    required List<double> confidenceInterval,
    required String recommendation,
  }) = _TestResult;

  factory TestResult.fromJson(Map<String, dynamic> json) =>
      _$TestResultFromJson(json);
}

@freezed
class ABTest with _$ABTest {
  const factory ABTest({
    required String id,
    required String name,
    required String description,
    required DateTime startDate,
    required TestStatus status,
    required List<Variant> variants,
    required List<String> targetMetrics,
    required int sampleSize,
    required double confidenceLevel,
    required TestResult? results,
    DateTime? endDate,
    String? winner,
    double? statisticalSignificance,
  }) = _ABTest;

  factory ABTest.fromJson(Map<String, dynamic> json) => _$ABTestFromJson(json);
}
