import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/sound_service.dart';
import 'sound_preferences_provider.dart';

/// Sound manager that combines sound service with user preferences
class SoundManager {
  SoundManager(this._soundService, this._preferences);
  final SoundService _soundService;
  final SoundPreferences _preferences;

  /// Play a sound effect if it's allowed by user preferences
  Future<void> play(SoundEffect sound) async {
    // Update service with current preferences
    _soundService.setSoundMasterEnabled(_preferences.soundMasterEnabled);
    _soundService.setVolume(_preferences.volume);

    for (final category in SoundCategory.values) {
      _soundService.setCategoryEnabled(
        category,
        _preferences.categoryEnabled[category] ?? true,
      );
    }

    // Play the sound
    await _soundService.play(sound);
  }

  /// Play multiple sounds in sequence
  Future<void> playSequence(List<SoundEffect> sounds) async {
    for (final sound in sounds) {
      await play(sound);
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  /// Stop all sounds
  Future<void> stopAll() async {
    await _soundService.stopAll();
  }

  /// Check if sound is enabled for a category
  bool isCategoryEnabled(SoundCategory category) =>
      _preferences.isCategoryEnabled(category);

  /// Check if any sound is enabled
  bool hasAnySoundEnabled() => _preferences.hasAnySoundEnabled();
}

/// Sound manager provider that handles all sound playback
final soundManagerProvider = FutureProvider((ref) async {
  final soundService = ref.watch(soundServiceProvider);
  final preferences = await ref.watch(soundPreferencesProvider.future);
  return SoundManager(soundService, preferences);
});

/// Convenience provider for playing sounds (use this in your app)
/// Example: ref.read(soundPlayProvider(SoundEffect.buttonTap));
final soundPlayProvider =
    FutureProvider.family<void, SoundEffect>((ref, sound) async {
  final manager = await ref.watch(soundManagerProvider.future);
  return manager.play(sound);
});
