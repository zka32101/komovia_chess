import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/achievement_service.dart';
import 'auth_provider.dart';

final achievementServiceProvider =
    Provider<AchievementService>((ref) => AchievementService());

/// Every achievement definition paired with the signed-in user's progress
/// against it, sorted unlocked-first then by remaining progress.
final userAchievementProgressProvider =
    FutureProvider<List<AchievementProgress>>((ref) async {
  final user = ref.watch(currentUserProvider).value;
  if (user == null) return const [];

  final service = ref.watch(achievementServiceProvider);
  final definitions = await service.getAllAchievements();
  final progress = await Future.wait(
    definitions.map((d) => service.getAchievementProgress(
          user.uid,
          d.achievementId,
        )),
  );

  final byId = {for (final d in definitions) d.achievementId: d};
  final combined = progress
      .where((p) => byId.containsKey(p.achievementId))
      .toList()
    ..sort((a, b) {
      if (a.isUnlocked != b.isUnlocked) return a.isUnlocked ? -1 : 1;
      return b.progressPercentage.compareTo(a.progressPercentage);
    });
  return combined;
});

/// Looks up the achievement definition for a given id from the cached
/// definitions list - used for display (name/description/icon/tier).
final achievementDefinitionsProvider =
    FutureProvider<Map<String, AchievementDefinition>>((ref) async {
  final service = ref.watch(achievementServiceProvider);
  final definitions = await service.getAllAchievements();
  return {for (final d in definitions) d.achievementId: d};
});
