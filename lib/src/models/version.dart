import 'package:freezed_annotation/freezed_annotation.dart';

part 'version.freezed.dart';
part 'version.g.dart';

enum ChangeType {
  @JsonValue('feature')
  feature,
  @JsonValue('bugfix')
  bugfix,
  @JsonValue('improvement')
  improvement,
  @JsonValue('security')
  security,
  @JsonValue('performance')
  performance,
}

enum NotificationType {
  @JsonValue('optional')
  optional,
  @JsonValue('recommended')
  recommended,
  @JsonValue('critical')
  critical,
}

enum ActionType {
  @JsonValue('dismissed')
  dismissed,
  @JsonValue('snoozed')
  snoozed,
  @JsonValue('updated')
  updated,
}

@freezed
class ChangelogEntry with _$ChangelogEntry {
  const factory ChangelogEntry({
    required String id,
    required ChangeType type,
    required String title,
    required String description,
    required List<String> relatedIssues,
    required int priority,
  }) = _ChangelogEntry;

  factory ChangelogEntry.fromJson(Map<String, dynamic> json) =>
      _$ChangelogEntryFromJson(json);
}

@freezed
class AppVersion with _$AppVersion {
  const factory AppVersion({
    required String versionNumber,
    required int buildNumber,
    required DateTime releaseDate,
    required String minSupportedVersion,
    required bool isCritical,
    required List<ChangelogEntry> changelog,
    required String downloadUrl,
    required List<String> knownIssues,
    String? installationGuide,
  }) = _AppVersion;

  factory AppVersion.fromJson(Map<String, dynamic> json) =>
      _$AppVersionFromJson(json);
}

@freezed
class UpdateNotification with _$UpdateNotification {
  const factory UpdateNotification({
    required String id,
    required String userId,
    required String versionId,
    required NotificationType type,
    required String title,
    required String message,
    required DateTime sentDate,
    required bool actionTaken,
    DateTime? viewedDate,
    ActionType? actionType,
  }) = _UpdateNotification;

  factory UpdateNotification.fromJson(Map<String, dynamic> json) =>
      _$UpdateNotificationFromJson(json);
}

@freezed
class VersionStat with _$VersionStat {
  const factory VersionStat({
    required String version,
    required int activeUsers,
    required double adoptionRate,
    required double updatePercentage,
    required double crashRate,
    required DateTime timestamp,
  }) = _VersionStat;

  factory VersionStat.fromJson(Map<String, dynamic> json) =>
      _$VersionStatFromJson(json);
}
