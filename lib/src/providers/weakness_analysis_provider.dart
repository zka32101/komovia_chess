import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/weakness_profile.dart';
import '../services/weakness_analysis_service.dart';
import 'auth_provider.dart';

final weaknessAnalysisServiceProvider =
    Provider<WeaknessAnalysisService>((ref) => WeaknessAnalysisService());

/// The signed-in user's weakness profile, aggregated across every game
/// they've had analyzed via GameAnalysisScreen.
final weaknessProfileProvider = FutureProvider<WeaknessProfile>((ref) async {
  final user = ref.watch(currentUserProvider).value;
  if (user == null) return WeaknessProfile.empty;
  return ref.watch(weaknessAnalysisServiceProvider).getWeaknessProfile(user.uid);
});
