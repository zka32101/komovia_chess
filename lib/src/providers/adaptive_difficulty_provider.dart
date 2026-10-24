import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/adaptive_difficulty_service.dart';
import 'auth_provider.dart';

final adaptiveDifficultyServiceProvider =
    Provider<AdaptiveDifficultyService>((ref) => AdaptiveDifficultyService());

/// The signed-in user's recommended CPU difficulty, based on their recent
/// win rate at whatever difficulty they last played. Null while signed
/// out or on a read error - callers should fall back to their own
/// existing default in that case.
final difficultyRecommendationProvider =
    FutureProvider<DifficultyRecommendation?>((ref) async {
  final user = ref.watch(currentUserProvider).value;
  if (user == null) return null;
  try {
    return await ref
        .watch(adaptiveDifficultyServiceProvider)
        .getRecommendation(user.uid);
  } catch (_) {
    return null;
  }
});
