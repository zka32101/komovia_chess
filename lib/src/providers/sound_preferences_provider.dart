import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Sound categories for granular control
enum SoundCategory {
  gamePlay, // Piece movement, capture, check, checkmate
  gameEnd, // Game over
  ui, // Button taps, swipes
  notifications, // Notifications, success, error
}

extension SoundCategoryExt on SoundCategory {
  String get displayName {
    switch (this) {
      case SoundCategory.gamePlay:
        return 'Gameplay';
      case SoundCategory.gameEnd:
        return 'Game End';
      case SoundCategory.ui:
        return 'UI Sounds';
      case SoundCategory.notifications:
        return 'Notifications';
    }
  }

  String get description {
    switch (this) {
      case SoundCategory.gamePlay:
        return 'Piece movement, captures, and checks';
      case SoundCategory.gameEnd:
        return 'Checkmate and game over';
      case SoundCategory.ui:
        return 'Button taps and menu interactions';
      case SoundCategory.notifications:
        return 'Notifications and status alerts';
    }
  }

  IconData get icon {
    switch (this) {
      case SoundCategory.gamePlay:
        return Icons.videogame_asset;
      case SoundCategory.gameEnd:
        return Icons.flag;
      case SoundCategory.ui:
        return Icons.touch_app;
      case SoundCategory.notifications:
        return Icons.notifications;
    }
  }
}

/// Sound preferences model
class SoundPreferences {
  SoundPreferences({
    required this.userId,
    this.soundMasterEnabled = true,
    Map<SoundCategory, bool>? categoryEnabled,
    this.volume = 1.0,
    this.lastUpdated,
  }) : categoryEnabled = categoryEnabled ?? _defaultCategories();

  factory SoundPreferences.fromMap(Map<String, dynamic> map) {
    final categoryMap = map['categoryEnabled'] as Map<String, dynamic>? ?? {};
    final categories = <SoundCategory, bool>{};

    for (final category in SoundCategory.values) {
      final key = category.toString().split('.').last;
      categories[category] = categoryMap[key] ?? true;
    }

    return SoundPreferences(
      userId: map['userId'] ?? '',
      soundMasterEnabled: map['soundMasterEnabled'] ?? true,
      categoryEnabled: categories,
      volume: (map['volume'] as num?)?.toDouble() ?? 1.0,
      lastUpdated: map['lastUpdated'] != null
          ? (map['lastUpdated'] as Timestamp).toDate()
          : null,
    );
  }
  final String userId;
  final bool soundMasterEnabled;
  final Map<SoundCategory, bool> categoryEnabled;
  final double volume; // 0.0 - 1.0
  final DateTime? lastUpdated;

  static Map<SoundCategory, bool> _defaultCategories() => {
        SoundCategory.gamePlay: true,
        SoundCategory.gameEnd: true,
        SoundCategory.ui: true,
        SoundCategory.notifications: true,
      };

  /// Check if a category is enabled (respects master toggle)
  bool isCategoryEnabled(SoundCategory category) =>
      soundMasterEnabled && (categoryEnabled[category] ?? true);

  /// Check if any sound is enabled
  bool hasAnySoundEnabled() {
    if (!soundMasterEnabled) return false;
    return categoryEnabled.values.any((enabled) => enabled);
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'soundMasterEnabled': soundMasterEnabled,
        'categoryEnabled': {
          for (final category in SoundCategory.values)
            category.toString().split('.').last:
                categoryEnabled[category] ?? true,
        },
        'volume': volume,
        'lastUpdated': FieldValue.serverTimestamp(),
      };

  SoundPreferences copyWith({
    String? userId,
    bool? soundMasterEnabled,
    Map<SoundCategory, bool>? categoryEnabled,
    double? volume,
    DateTime? lastUpdated,
  }) =>
      SoundPreferences(
        userId: userId ?? this.userId,
        soundMasterEnabled: soundMasterEnabled ?? this.soundMasterEnabled,
        categoryEnabled: categoryEnabled ?? this.categoryEnabled,
        volume: volume ?? this.volume,
        lastUpdated: lastUpdated ?? this.lastUpdated,
      );
}

/// Sound preferences service
class SoundPreferencesService {
  SoundPreferencesService(this._firestore, this._auth);
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  /// Get sound preferences
  Future<SoundPreferences> getPreferences() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user logged in');

    try {
      final doc = await _firestore
          .collection('user_preferences')
          .doc(user.uid)
          .collection('sound')
          .doc('preferences')
          .get();

      if (doc.exists) {
        return SoundPreferences.fromMap({
          'userId': user.uid,
          ...doc.data()!,
        });
      }

      // Return default preferences if not found
      return SoundPreferences(userId: user.uid);
    } catch (e) {
      print('Error fetching sound preferences: $e');
      return SoundPreferences(userId: user.uid);
    }
  }

  /// Update master sound toggle
  Future<void> setSoundMasterEnabled(bool enabled) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user logged in');

    try {
      await _firestore
          .collection('user_preferences')
          .doc(user.uid)
          .collection('sound')
          .doc('preferences')
          .set(
        {
          'soundMasterEnabled': enabled,
          'lastUpdated': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      print('Error updating master sound preference: $e');
      rethrow;
    }
  }

  /// Update category sound toggle
  Future<void> setCategoryEnabled(SoundCategory category, bool enabled) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user logged in');

    try {
      final key = category.toString().split('.').last;
      await _firestore
          .collection('user_preferences')
          .doc(user.uid)
          .collection('sound')
          .doc('preferences')
          .set(
        {
          'categoryEnabled': {
            key: enabled,
          },
          'lastUpdated': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      print('Error updating category sound preference: $e');
      rethrow;
    }
  }

  /// Update volume level
  Future<void> setVolume(double volume) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user logged in');

    try {
      await _firestore
          .collection('user_preferences')
          .doc(user.uid)
          .collection('sound')
          .doc('preferences')
          .set(
        {
          'volume': volume.clamp(0.0, 1.0),
          'lastUpdated': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      print('Error updating volume: $e');
      rethrow;
    }
  }

  /// Reset sound preferences to defaults
  Future<void> resetToDefaults() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user logged in');

    try {
      final defaults = SoundPreferences(userId: user.uid);
      await _firestore
          .collection('user_preferences')
          .doc(user.uid)
          .collection('sound')
          .doc('preferences')
          .set(defaults.toMap());
    } catch (e) {
      print('Error resetting sound preferences: $e');
      rethrow;
    }
  }
}

// Riverpod Providers

/// Sound preferences service provider
final soundPreferencesServiceProvider = Provider((ref) {
  final firestore = FirebaseFirestore.instance;
  final auth = FirebaseAuth.instance;
  return SoundPreferencesService(firestore, auth);
});

/// Sound preferences provider (cached)
final soundPreferencesProvider = FutureProvider<SoundPreferences>((ref) async {
  final service = ref.watch(soundPreferencesServiceProvider);
  return service.getPreferences();
});

/// Sound master toggle provider (state)
final soundMasterEnabledProvider = StateProvider<bool>((ref) {
  final preferences = ref.watch(soundPreferencesProvider);
  return preferences.when(
    data: (prefs) => prefs.soundMasterEnabled,
    loading: () => true,
    error: (_, __) => true,
  );
});

/// Sound category providers (state)
final soundCategoryProvider =
    StateProvider.family<bool, SoundCategory>((ref, category) {
  final preferences = ref.watch(soundPreferencesProvider);
  return preferences.when(
    data: (prefs) => prefs.isCategoryEnabled(category),
    loading: () => true,
    error: (_, __) => true,
  );
});

/// Volume provider (state)
final soundVolumeProvider = StateProvider<double>((ref) {
  final preferences = ref.watch(soundPreferencesProvider);
  return preferences.when(
    data: (prefs) => prefs.volume,
    loading: () => 1.0,
    error: (_, __) => 1.0,
  );
});
