import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// User preferences model
class UserPreferences {
  UserPreferences({
    required this.userId,
    this.themeMode = ThemeMode.system,
    this.language = 'en',
    this.soundEnabled = true,
    this.notificationsEnabled = true,
    this.boardSize = 350,
    this.showCoordinates = true,
    this.pieceStyle = 'default',
    this.boardStyle = 'default',
    this.lastUpdated,
  });

  factory UserPreferences.fromMap(Map<String, dynamic> map) {
    ThemeMode themeMode = ThemeMode.system;
    final themeModeStr = map['themeMode'] as String?;
    if (themeModeStr == 'light') {
      themeMode = ThemeMode.light;
    } else if (themeModeStr == 'dark') {
      themeMode = ThemeMode.dark;
    }

    return UserPreferences(
      userId: map['userId'] ?? '',
      themeMode: themeMode,
      language: map['language'] ?? 'en',
      soundEnabled: map['soundEnabled'] ?? true,
      notificationsEnabled: map['notificationsEnabled'] ?? true,
      boardSize: map['boardSize'] ?? 350,
      showCoordinates: map['showCoordinates'] ?? true,
      pieceStyle: map['pieceStyle'] ?? 'default',
      boardStyle: map['boardStyle'] ?? 'default',
      lastUpdated: map['lastUpdated'] != null
          ? (map['lastUpdated'] as Timestamp).toDate()
          : null,
    );
  }
  final String userId;
  final ThemeMode themeMode; // light, dark, system
  final String language; // 'en', 'ja', etc.
  final bool soundEnabled;
  final bool notificationsEnabled;
  final int boardSize; // 300-600 pixels
  final bool showCoordinates;
  final String pieceStyle; // 'default', 'wooden', 'classic'
  final String boardStyle; // 'default', 'wooden', 'marble'
  final DateTime? lastUpdated;

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'themeMode': themeMode.toString().split('.').last,
        'language': language,
        'soundEnabled': soundEnabled,
        'notificationsEnabled': notificationsEnabled,
        'boardSize': boardSize,
        'showCoordinates': showCoordinates,
        'pieceStyle': pieceStyle,
        'boardStyle': boardStyle,
        'lastUpdated': FieldValue.serverTimestamp(),
      };

  UserPreferences copyWith({
    String? userId,
    ThemeMode? themeMode,
    String? language,
    bool? soundEnabled,
    bool? notificationsEnabled,
    int? boardSize,
    bool? showCoordinates,
    String? pieceStyle,
    String? boardStyle,
    DateTime? lastUpdated,
  }) =>
      UserPreferences(
        userId: userId ?? this.userId,
        themeMode: themeMode ?? this.themeMode,
        language: language ?? this.language,
        soundEnabled: soundEnabled ?? this.soundEnabled,
        notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
        boardSize: boardSize ?? this.boardSize,
        showCoordinates: showCoordinates ?? this.showCoordinates,
        pieceStyle: pieceStyle ?? this.pieceStyle,
        boardStyle: boardStyle ?? this.boardStyle,
        lastUpdated: lastUpdated ?? this.lastUpdated,
      );
}

// User preferences service
class UserPreferencesService {
  UserPreferencesService(this._firestore, this._auth);
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  // Get user preferences
  Future<UserPreferences> getPreferences() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user logged in');

    try {
      final doc =
          await _firestore.collection('user_preferences').doc(user.uid).get();

      if (doc.exists) {
        return UserPreferences.fromMap({
          'userId': user.uid,
          ...doc.data()!,
        });
      }

      // Return default preferences if not found
      return UserPreferences(userId: user.uid);
    } catch (e) {
      print('Error fetching user preferences: $e');
      return UserPreferences(userId: user.uid);
    }
  }

  // Update theme preference
  Future<void> setThemeMode(ThemeMode themeMode) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user logged in');

    try {
      await _firestore.collection('user_preferences').doc(user.uid).set(
        {
          'themeMode': themeMode.toString().split('.').last,
          'lastUpdated': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      print('Error updating theme preference: $e');
      rethrow;
    }
  }

  // Update language preference
  Future<void> setLanguage(String language) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user logged in');

    try {
      await _firestore.collection('user_preferences').doc(user.uid).set(
        {
          'language': language,
          'lastUpdated': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      print('Error updating language preference: $e');
      rethrow;
    }
  }

  // Update sound preference
  Future<void> setSoundEnabled(bool enabled) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user logged in');

    try {
      await _firestore.collection('user_preferences').doc(user.uid).set(
        {
          'soundEnabled': enabled,
          'lastUpdated': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      print('Error updating sound preference: $e');
      rethrow;
    }
  }

  // Update notifications preference
  Future<void> setNotificationsEnabled(bool enabled) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user logged in');

    try {
      await _firestore.collection('user_preferences').doc(user.uid).set(
        {
          'notificationsEnabled': enabled,
          'lastUpdated': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      print('Error updating notifications preference: $e');
      rethrow;
    }
  }

  // Update board size
  Future<void> setBoardSize(int size) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user logged in');

    try {
      await _firestore.collection('user_preferences').doc(user.uid).set(
        {
          'boardSize': size.clamp(300, 600),
          'lastUpdated': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      print('Error updating board size: $e');
      rethrow;
    }
  }

  // Update show coordinates preference
  Future<void> setShowCoordinates(bool show) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user logged in');

    try {
      await _firestore.collection('user_preferences').doc(user.uid).set(
        {
          'showCoordinates': show,
          'lastUpdated': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      print('Error updating show coordinates preference: $e');
      rethrow;
    }
  }

  // Update piece and board styles
  Future<void> setStyles({
    required String pieceStyle,
    required String boardStyle,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user logged in');

    try {
      await _firestore.collection('user_preferences').doc(user.uid).set(
        {
          'pieceStyle': pieceStyle,
          'boardStyle': boardStyle,
          'lastUpdated': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      print('Error updating styles: $e');
      rethrow;
    }
  }

  // Reset to default preferences
  Future<void> resetToDefaults() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user logged in');

    try {
      final defaults = UserPreferences(userId: user.uid);
      await _firestore.collection('user_preferences').doc(user.uid).set(
            defaults.toMap(),
          );
    } catch (e) {
      print('Error resetting preferences: $e');
      rethrow;
    }
  }
}

// Riverpod Providers
final userPreferencesServiceProvider = Provider((ref) {
  final firestore = FirebaseFirestore.instance;
  final auth = FirebaseAuth.instance;
  return UserPreferencesService(firestore, auth);
});

// User preferences provider (cached)
final userPreferencesProvider = FutureProvider<UserPreferences>((ref) async {
  final service = ref.watch(userPreferencesServiceProvider);
  return service.getPreferences();
});

// Theme mode provider (state)
final themeModeProvider = StateProvider<ThemeMode>((ref) {
  final preferences = ref.watch(userPreferencesProvider);
  return preferences.when(
    data: (prefs) => prefs.themeMode,
    loading: () => ThemeMode.system,
    error: (_, __) => ThemeMode.system,
  );
});

// Language provider (state)
final languageProvider = StateProvider<String>((ref) {
  final preferences = ref.watch(userPreferencesProvider);
  return preferences.when(
    data: (prefs) => prefs.language,
    loading: () => 'en',
    error: (_, __) => 'en',
  );
});

// Sound enabled provider (state)
final soundEnabledProvider = StateProvider<bool>((ref) {
  final preferences = ref.watch(userPreferencesProvider);
  return preferences.when(
    data: (prefs) => prefs.soundEnabled,
    loading: () => true,
    error: (_, __) => true,
  );
});

// Notifications enabled provider (state)
final notificationsEnabledProvider = StateProvider<bool>((ref) {
  final preferences = ref.watch(userPreferencesProvider);
  return preferences.when(
    data: (prefs) => prefs.notificationsEnabled,
    loading: () => true,
    error: (_, __) => true,
  );
});

// Board size provider (state)
final boardSizeProvider = StateProvider<int>((ref) {
  final preferences = ref.watch(userPreferencesProvider);
  return preferences.when(
    data: (prefs) => prefs.boardSize,
    loading: () => 350,
    error: (_, __) => 350,
  );
});
