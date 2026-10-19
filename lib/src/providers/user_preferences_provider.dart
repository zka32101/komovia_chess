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
    this.notifyFriendRequests = true,
    this.notifyGameAlerts = true,
    this.notifyAchievements = true,
    this.boardSize = 350,
    this.showCoordinates = true,
    this.pieceStyle = 'default',
    this.boardStyle = 'default',
    this.analysisDepth = 12,
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
      notifyFriendRequests: map['notifyFriendRequests'] ?? true,
      notifyGameAlerts: map['notifyGameAlerts'] ?? true,
      notifyAchievements: map['notifyAchievements'] ?? true,
      boardSize: map['boardSize'] ?? 350,
      showCoordinates: map['showCoordinates'] ?? true,
      pieceStyle: map['pieceStyle'] ?? 'default',
      boardStyle: map['boardStyle'] ?? 'default',
      analysisDepth: map['analysisDepth'] ?? 12,
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

  /// Per-category filters, only consulted when [notificationsEnabled] is
  /// true. Each corresponds to one or more of the notification `type`
  /// strings a service may write under `users/{uid}/notifications` - see
  /// `notification_provider.dart`'s `_categoryForNotificationType`.
  final bool notifyFriendRequests;
  final bool notifyGameAlerts;
  final bool notifyAchievements;
  final int boardSize; // 300-600 pixels
  final bool showCoordinates;
  final String pieceStyle; // 'default', 'wooden', 'classic'
  final String boardStyle; // 'default', 'wooden', 'marble'

  /// Fixed Stockfish search depth used for post-game computer analysis
  /// (GameReviewScreen) - previously hardcoded to a 500ms time budget
  /// with no user-facing control at all. 8-20; default 12 is a modest
  /// depth that still returns quickly on typical mobile hardware.
  final int analysisDepth;
  final DateTime? lastUpdated;

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'themeMode': themeMode.toString().split('.').last,
        'language': language,
        'soundEnabled': soundEnabled,
        'notificationsEnabled': notificationsEnabled,
        'notifyFriendRequests': notifyFriendRequests,
        'notifyGameAlerts': notifyGameAlerts,
        'notifyAchievements': notifyAchievements,
        'boardSize': boardSize,
        'showCoordinates': showCoordinates,
        'pieceStyle': pieceStyle,
        'boardStyle': boardStyle,
        'analysisDepth': analysisDepth,
        'lastUpdated': FieldValue.serverTimestamp(),
      };

  UserPreferences copyWith({
    String? userId,
    ThemeMode? themeMode,
    String? language,
    bool? soundEnabled,
    bool? notificationsEnabled,
    bool? notifyFriendRequests,
    bool? notifyGameAlerts,
    bool? notifyAchievements,
    int? boardSize,
    bool? showCoordinates,
    String? pieceStyle,
    String? boardStyle,
    int? analysisDepth,
    DateTime? lastUpdated,
  }) =>
      UserPreferences(
        userId: userId ?? this.userId,
        themeMode: themeMode ?? this.themeMode,
        language: language ?? this.language,
        soundEnabled: soundEnabled ?? this.soundEnabled,
        notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
        notifyFriendRequests: notifyFriendRequests ?? this.notifyFriendRequests,
        notifyGameAlerts: notifyGameAlerts ?? this.notifyGameAlerts,
        notifyAchievements: notifyAchievements ?? this.notifyAchievements,
        boardSize: boardSize ?? this.boardSize,
        showCoordinates: showCoordinates ?? this.showCoordinates,
        pieceStyle: pieceStyle ?? this.pieceStyle,
        boardStyle: boardStyle ?? this.boardStyle,
        analysisDepth: analysisDepth ?? this.analysisDepth,
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

  // Update friend-request notification category
  Future<void> setNotifyFriendRequests(bool enabled) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user logged in');

    try {
      await _firestore.collection('user_preferences').doc(user.uid).set(
        {
          'notifyFriendRequests': enabled,
          'lastUpdated': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      print('Error updating friend request notification preference: $e');
      rethrow;
    }
  }

  // Update game-alert (matches/rematches/challenges) notification category
  Future<void> setNotifyGameAlerts(bool enabled) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user logged in');

    try {
      await _firestore.collection('user_preferences').doc(user.uid).set(
        {
          'notifyGameAlerts': enabled,
          'lastUpdated': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      print('Error updating game alert notification preference: $e');
      rethrow;
    }
  }

  // Update achievement notification category
  Future<void> setNotifyAchievements(bool enabled) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user logged in');

    try {
      await _firestore.collection('user_preferences').doc(user.uid).set(
        {
          'notifyAchievements': enabled,
          'lastUpdated': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      print('Error updating achievement notification preference: $e');
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

  // Update post-game computer analysis depth
  Future<void> setAnalysisDepth(int depth) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user logged in');

    try {
      await _firestore.collection('user_preferences').doc(user.uid).set(
        {
          'analysisDepth': depth.clamp(8, 20),
          'lastUpdated': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      print('Error updating analysis depth: $e');
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

// Friend-request notification category provider (state)
final notifyFriendRequestsProvider = StateProvider<bool>((ref) {
  final preferences = ref.watch(userPreferencesProvider);
  return preferences.when(
    data: (prefs) => prefs.notifyFriendRequests,
    loading: () => true,
    error: (_, __) => true,
  );
});

// Game-alert notification category provider (state)
final notifyGameAlertsProvider = StateProvider<bool>((ref) {
  final preferences = ref.watch(userPreferencesProvider);
  return preferences.when(
    data: (prefs) => prefs.notifyGameAlerts,
    loading: () => true,
    error: (_, __) => true,
  );
});

// Achievement notification category provider (state)
final notifyAchievementsProvider = StateProvider<bool>((ref) {
  final preferences = ref.watch(userPreferencesProvider);
  return preferences.when(
    data: (prefs) => prefs.notifyAchievements,
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

// Post-game computer analysis depth provider (state)
final analysisDepthProvider = StateProvider<int>((ref) {
  final preferences = ref.watch(userPreferencesProvider);
  return preferences.when(
    data: (prefs) => prefs.analysisDepth,
    loading: () => 12,
    error: (_, __) => 12,
  );
});
