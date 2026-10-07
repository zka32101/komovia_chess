import 'package:freezed_annotation/freezed_annotation.dart';

part 'performance.freezed.dart';
part 'performance.g.dart';

enum MetricType {
  @JsonValue('screen_load')
  screenLoad,
  @JsonValue('api_latency')
  apiLatency,
  @JsonValue('memory')
  memory,
  @JsonValue('battery')
  battery,
  @JsonValue('crash')
  crash,
}

enum CrashStatus {
  @JsonValue('new')
  new_,
  @JsonValue('acknowledged')
  acknowledged,
  @JsonValue('fixed')
  fixed,
}

@freezed
class PerformanceMetric with _$PerformanceMetric {
  const factory PerformanceMetric({
    required String id,
    required MetricType type,
    required String component,
    required double value,
    required String unit,
    required DateTime timestamp,
    required String deviceInfo,
    required String appVersion,
    required String sessionId,
  }) = _PerformanceMetric;

  factory PerformanceMetric.fromJson(Map<String, dynamic> json) =>
      _$PerformanceMetricFromJson(json);
}

@freezed
class CrashReport with _$CrashReport {
  const factory CrashReport({
    required String id,
    required String userId,
    required String error,
    required String stackTrace,
    required DateTime timestamp,
    required String appVersion,
    required String deviceInfo,
    required bool reproducible,
    required CrashStatus status,
  }) = _CrashReport;

  factory CrashReport.fromJson(Map<String, dynamic> json) =>
      _$CrashReportFromJson(json);
}

@freezed
class OptimizationSuggestion with _$OptimizationSuggestion {
  const factory OptimizationSuggestion({
    required String id,
    required String component,
    required String issue,
    required double currentBaseline,
    required double suggestedImprovement,
    required double estimatedImpact,
    required int effort,
    required int priority,
    required String category,
    required List<String> recommendations,
  }) = _OptimizationSuggestion;

  factory OptimizationSuggestion.fromJson(Map<String, dynamic> json) =>
      _$OptimizationSuggestionFromJson(json);
}
