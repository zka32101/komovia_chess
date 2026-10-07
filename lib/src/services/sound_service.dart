import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../providers/sound_preferences_provider.dart';

/// Sound effects available in the app
enum SoundEffect {
  movePiece,
  capture,
  check,
  checkmate,
  gameOver,
  buttonTap,
  notification,
  success,
  error,
  uiSwipe,
}

extension SoundEffectExt on SoundEffect {
  String get assetPath {
    switch (this) {
      case SoundEffect.movePiece:
        return 'assets/sounds/move.mp3';
      case SoundEffect.capture:
        return 'assets/sounds/capture.mp3';
      case SoundEffect.check:
        return 'assets/sounds/check.mp3';
      case SoundEffect.checkmate:
        return 'assets/sounds/checkmate.mp3';
      case SoundEffect.gameOver:
        return 'assets/sounds/game_over.mp3';
      case SoundEffect.buttonTap:
        return 'assets/sounds/tap.mp3';
      case SoundEffect.notification:
        return 'assets/sounds/notification.mp3';
      case SoundEffect.success:
        return 'assets/sounds/success.mp3';
      case SoundEffect.error:
        return 'assets/sounds/error.mp3';
      case SoundEffect.uiSwipe:
        return 'assets/sounds/swipe.mp3';
    }
  }

  String get displayName {
    switch (this) {
      case SoundEffect.movePiece:
        return 'Piece Movement';
      case SoundEffect.capture:
        return 'Piece Capture';
      case SoundEffect.check:
        return 'Check Warning';
      case SoundEffect.checkmate:
        return 'Checkmate';
      case SoundEffect.gameOver:
        return 'Game Over';
      case SoundEffect.buttonTap:
        return 'Button Tap';
      case SoundEffect.notification:
        return 'Notification';
      case SoundEffect.success:
        return 'Success';
      case SoundEffect.error:
        return 'Error';
      case SoundEffect.uiSwipe:
        return 'UI Swipe';
    }
  }

  /// The user-facing sound category this effect belongs to, matching the
  /// groupings in [SoundCategory]'s own documentation.
  SoundCategory get category {
    switch (this) {
      case SoundEffect.movePiece:
      case SoundEffect.capture:
      case SoundEffect.check:
      case SoundEffect.checkmate:
        return SoundCategory.gamePlay;
      case SoundEffect.gameOver:
        return SoundCategory.gameEnd;
      case SoundEffect.buttonTap:
      case SoundEffect.uiSwipe:
        return SoundCategory.ui;
      case SoundEffect.notification:
      case SoundEffect.success:
      case SoundEffect.error:
        return SoundCategory.notifications;
    }
  }
}

/// Sound service for managing audio playback with just_audio
///
/// Uses audio player pooling per sound effect for efficient resource management.
/// Supports volume control, sound sequences, and full playback state management.
class SoundService {
  factory SoundService() => _instance;

  SoundService._internal();
  bool _soundEnabled = true;
  double _volume = 1;
  bool _initialized = false;

  // Map of sound effects to audio players
  late final Map<SoundEffect, AudioPlayer> _players;

  // Per-category enable state, mirroring the user's sound preferences
  final Map<SoundCategory, bool> _categoryEnabled = {
    for (final category in SoundCategory.values) category: true,
  };

  static final SoundService _instance = SoundService._internal();

  /// Initialize the sound service by preloading all sound files
  /// Should be called once during app startup
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      _players = {};

      // Create an audio player for each sound effect
      for (final effect in SoundEffect.values) {
        final player = AudioPlayer();
        await player.setAsset(effect.assetPath);
        _players[effect] = player;
      }

      _initialized = true;

      if (kDebugMode) {
        print(
            '[SOUND] SoundService initialized with ${_players.length} audio players');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[SOUND] Error initializing SoundService: $e');
      }
    }
  }

  /// Set whether sound is enabled
  void setSoundEnabled(bool enabled) {
    _soundEnabled = enabled;
  }

  /// Set the master sound toggle (alias of [setSoundEnabled], matching the
  /// naming used by [SoundPreferences.soundMasterEnabled]).
  void setSoundMasterEnabled(bool enabled) => setSoundEnabled(enabled);

  /// Get current sound enabled state
  bool get isSoundEnabled => _soundEnabled;

  /// Enable or disable a specific sound category
  void setCategoryEnabled(SoundCategory category, bool enabled) {
    _categoryEnabled[category] = enabled;
  }

  /// Check if a specific sound category is enabled
  bool isCategoryEnabled(SoundCategory category) =>
      _categoryEnabled[category] ?? true;

  /// Set global volume (0.0 - 1.0)
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);

    // Apply volume to all players
    for (final player in _players.values) {
      await player.setVolume(_volume);
    }
  }

  /// Get current global volume
  double get volume => _volume;

  /// Play a sound effect with global volume
  Future<void> play(SoundEffect sound) async {
    if (!_soundEnabled || !_initialized || !isCategoryEnabled(sound.category)) {
      return;
    }

    try {
      final player = _players[sound];
      if (player != null) {
        await player.seek(Duration.zero);
        await player.play();

        if (kDebugMode) {
          print('[SOUND] Playing: ${sound.displayName}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('[SOUND] Error playing ${sound.displayName}: $e');
      }
    }
  }

  /// Play a sound with specific volume override
  Future<void> playWithVolume(SoundEffect sound, double volumeOverride) async {
    if (!_soundEnabled || !_initialized || !isCategoryEnabled(sound.category)) {
      return;
    }

    try {
      final player = _players[sound];
      if (player != null) {
        final previousVolume = player.volume;

        // Set temporary volume
        await player.setVolume(volumeOverride.clamp(0.0, 1.0));

        // Reset position and play
        await player.seek(Duration.zero);
        await player.play();

        // Restore original volume after playback completes
        player.playerStateStream.listen(
          (state) {
            if (state.processingState == ProcessingState.completed) {
              player.setVolume(previousVolume);
            }
          },
          onError: (e) => player.setVolume(previousVolume),
        );

        if (kDebugMode) {
          print(
              '[SOUND] Playing: ${sound.displayName} (volume: ${volumeOverride.toStringAsFixed(2)})');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('[SOUND] Error playing ${sound.displayName}: $e');
      }
    }
  }

  /// Play multiple sounds in sequence
  Future<void> playSequence(
    List<SoundEffect> sounds, {
    Duration delayBetween = const Duration(milliseconds: 100),
  }) async {
    for (int i = 0; i < sounds.length; i++) {
      await play(sounds[i]);

      // Wait before playing next sound (except for the last one)
      if (i < sounds.length - 1) {
        await Future.delayed(delayBetween);
      }
    }
  }

  /// Pause all sounds
  Future<void> pauseAll() async {
    try {
      for (final player in _players.values) {
        await player.pause();
      }

      if (kDebugMode) {
        print('[SOUND] All sounds paused');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[SOUND] Error pausing sounds: $e');
      }
    }
  }

  /// Resume all sounds
  Future<void> resumeAll() async {
    if (!_soundEnabled) return;

    try {
      for (final player in _players.values) {
        if (player.playerState.playing == false &&
            player.playerState.processingState != ProcessingState.idle) {
          await player.play();
        }
      }

      if (kDebugMode) {
        print('[SOUND] All sounds resumed');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[SOUND] Error resuming sounds: $e');
      }
    }
  }

  /// Stop all sounds
  Future<void> stopAll() async {
    try {
      for (final player in _players.values) {
        await player.stop();
      }

      if (kDebugMode) {
        print('[SOUND] All sounds stopped');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[SOUND] Error stopping sounds: $e');
      }
    }
  }

  /// Dispose resources and cleanup audio players
  /// Call this when the app exits or sound service is no longer needed
  Future<void> dispose() async {
    try {
      await stopAll();

      for (final player in _players.values) {
        await player.dispose();
      }

      _players.clear();
      _initialized = false;
      _soundEnabled = false;

      if (kDebugMode) {
        print('[SOUND] SoundService disposed - all audio players released');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[SOUND] Error disposing SoundService: $e');
      }
    }
  }
}

/// Riverpod provider for sound service
final soundServiceProvider = Provider((ref) => SoundService());
