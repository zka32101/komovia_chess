import 'package:freezed_annotation/freezed_annotation.dart';

part 'rating_progression.freezed.dart';
part 'rating_progression.g.dart';

/// Represents a daily rating snapshot for progression tracking
@freezed
class RatingProgression with _$RatingProgression {
  const factory RatingProgression({
    required DateTime date,
    required int rating,
    required int gamesPlayed,
    required double winRate,
  }) = _RatingProgression;

  factory RatingProgression.fromJson(Map<String, dynamic> json) =>
      _$RatingProgressionFromJson(json);
}
