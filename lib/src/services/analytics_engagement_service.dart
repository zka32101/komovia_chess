import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:logger/logger.dart';

/// User engagement analytics tracking service
///
/// Tracks user interactions like puzzle completions, games, and feature usage
class AnalyticsEngagementService {
  factory AnalyticsEngagementService() => _instance;

  AnalyticsEngagementService._internal();
  static final AnalyticsEngagementService _instance =
      AnalyticsEngagementService._internal();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  final Logger _logger = Logger();

  /// Track puzzle completion
  ///
  /// Called when user completes a chess puzzle
  Future<void> trackPuzzleCompleted({
    required String puzzleId,
    required int difficulty,
    required bool solved,
    required int movesUsed,
    required int optimalmoves,
    required double timeSpent,
    String? category,
  }) async {
    try {
      _logger.i('Tracking puzzle completion: $puzzleId (solved: $solved)');

      await _analytics.logEvent(
        name: 'puzzle_completed',
        parameters: {
          'puzzle_id': puzzleId,
          'difficulty': difficulty,
          'solved': solved,
          'moves_used': movesUsed,
          'optimal_moves': optimalmoves,
          'time_spent': timeSpent.toStringAsFixed(2),
          'category': category ?? 'unknown',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      _logger.d('Puzzle completion event logged');
    } catch (e) {
      _logger.e('Failed to track puzzle completion', error: e);
    }
  }

  /// Track puzzle streak
  ///
  /// Called when user reaches consecutive puzzle milestones
  Future<void> trackPuzzleStreak({
    required int streakCount,
    required int successRate,
  }) async {
    try {
      _logger.i('Tracking puzzle streak: $streakCount puzzles');

      await _analytics.logEvent(
        name: 'puzzle_streak_milestone',
        parameters: {
          'streak_count': streakCount,
          'success_rate': successRate,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      _logger.d('Puzzle streak event logged');
    } catch (e) {
      _logger.e('Failed to track puzzle streak', error: e);
    }
  }

  /// Track online game started
  ///
  /// Called when user starts multiplayer match
  Future<void> trackGameStarted({
    required String gameId,
    required String gameType,
    required String opponentRating,
    required bool isRated,
  }) async {
    try {
      _logger.i('Tracking game started: $gameId ($gameType)');

      await _analytics.logEvent(
        name: 'game_started',
        parameters: {
          'game_id': gameId,
          'game_type': gameType,
          'opponent_rating': opponentRating,
          'is_rated': isRated,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      _logger.d('Game started event logged');
    } catch (e) {
      _logger.e('Failed to track game started', error: e);
    }
  }

  /// Track game completed
  ///
  /// Called when multiplayer game finishes
  Future<void> trackGameCompleted({
    required String gameId,
    required String result,
    required int movesCount,
    required double durationSeconds,
    required int? ratingChangePoints,
  }) async {
    try {
      _logger.i('Tracking game completed: $gameId - $result');

      await _analytics.logEvent(
        name: 'game_completed',
        parameters: {
          'game_id': gameId,
          'result': result,
          'moves_count': movesCount,
          'duration_seconds': durationSeconds.toStringAsFixed(2),
          'rating_change': ratingChangePoints ?? 0,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      _logger.d('Game completed event logged');
    } catch (e) {
      _logger.e('Failed to track game completed', error: e);
    }
  }

  /// Track game abandoned
  ///
  /// Called when player abandons game
  Future<void> trackGameAbandoned({
    required String gameId,
    required String reason,
    required int elapsedSeconds,
  }) async {
    try {
      _logger.i('Tracking game abandoned: $gameId - $reason');

      await _analytics.logEvent(
        name: 'game_abandoned',
        parameters: {
          'game_id': gameId,
          'reason': reason,
          'elapsed_seconds': elapsedSeconds,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      _logger.d('Game abandoned event logged');
    } catch (e) {
      _logger.e('Failed to track game abandoned', error: e);
    }
  }

  /// Track app session start
  ///
  /// Called when user opens app
  Future<void> trackSessionStart({
    required String sessionId,
    required bool isReturning,
    required int? daysSinceLastSession,
  }) async {
    try {
      _logger.i('Tracking session start: $sessionId');

      await _analytics.logEvent(
        name: 'session_start',
        parameters: {
          'session_id': sessionId,
          'is_returning': isReturning,
          'days_since_last_session': daysSinceLastSession ?? 0,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      _logger.d('Session start event logged');
    } catch (e) {
      _logger.e('Failed to track session start', error: e);
    }
  }

  /// Track app session end
  ///
  /// Called when user closes app or session ends
  Future<void> trackSessionEnd({
    required String sessionId,
    required double sessionDurationSeconds,
    required int puzzlesCompleted,
    required int gamesPlayed,
  }) async {
    try {
      _logger.i('Tracking session end: $sessionId');

      await _analytics.logEvent(
        name: 'session_end',
        parameters: {
          'session_id': sessionId,
          'session_duration': sessionDurationSeconds.toStringAsFixed(2),
          'puzzles_completed': puzzlesCompleted,
          'games_played': gamesPlayed,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      _logger.d('Session end event logged');
    } catch (e) {
      _logger.e('Failed to track session end', error: e);
    }
  }

  /// Track feature usage
  ///
  /// Generic method to track any feature access
  Future<void> trackFeatureUsed({
    required String featureName,
    required String featureCategory,
    Map<String, dynamic>? customData,
  }) async {
    try {
      _logger.i('Tracking feature used: $featureName');

      final parameters = {
        'feature_name': featureName,
        'feature_category': featureCategory,
        'timestamp': DateTime.now().toIso8601String(),
        ...?customData,
      };

      await _analytics.logEvent(
        name: 'feature_used',
        parameters: parameters,
      );

      _logger.d('Feature usage event logged: $featureName');
    } catch (e) {
      _logger.e('Failed to track feature usage', error: e);
    }
  }

  /// Track user milestone achievement
  ///
  /// Called when user reaches achievements like rating milestones
  Future<void> trackMilestoneAchieved({
    required String milestoneId,
    required String milestoneType,
    required int value,
    String? milestone,
  }) async {
    try {
      _logger.i('Tracking milestone achieved: $milestoneId');

      await _analytics.logEvent(
        name: 'milestone_achieved',
        parameters: {
          'milestone_id': milestoneId,
          'milestone_type': milestoneType,
          'value': value,
          'milestone_name': milestone ?? 'unknown',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      _logger.d('Milestone achievement event logged');
    } catch (e) {
      _logger.e('Failed to track milestone achievement', error: e);
    }
  }

  /// Track rating change
  ///
  /// Called after rating calculation following a game
  Future<void> trackRatingChange({
    required String userId,
    required int oldRating,
    required int newRating,
    required String reason,
  }) async {
    try {
      final ratingDelta = newRating - oldRating;
      _logger.i('Tracking rating change: $oldRating → $newRating');

      await _analytics.logEvent(
        name: 'rating_changed',
        parameters: {
          'user_id': userId,
          'old_rating': oldRating,
          'new_rating': newRating,
          'rating_delta': ratingDelta,
          'reason': reason,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      _logger.d('Rating change event logged');
    } catch (e) {
      _logger.e('Failed to track rating change', error: e);
    }
  }

  /// Track error occurrence
  ///
  /// Called when app encounters non-fatal errors
  Future<void> trackErrorOccurred({
    required String errorCode,
    required String errorMessage,
    required String errorContext,
    String? errorDetails,
  }) async {
    try {
      _logger.i('Tracking error: $errorCode in $errorContext');

      await _analytics.logEvent(
        name: 'error_occurred',
        parameters: {
          'error_code': errorCode,
          'error_message': errorMessage,
          'error_context': errorContext,
          'error_details': errorDetails ?? 'none',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      _logger.d('Error tracking event logged');
    } catch (e) {
      _logger.e('Failed to track error occurrence', error: e);
    }
  }

  /// Track content view
  ///
  /// Called when user views specific content/screens
  Future<void> trackContentView({
    required String contentId,
    required String contentName,
    required String contentType,
  }) async {
    try {
      _logger.i('Tracking content view: $contentName');

      await _analytics.logEvent(
        name: 'view_item',
        parameters: {
          'content_id': contentId,
          'content_name': contentName,
          'content_type': contentType,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      _logger.d('Content view event logged');
    } catch (e) {
      _logger.e('Failed to track content view', error: e);
    }
  }

  /// Track navigation event
  ///
  /// Called when user navigates between screens
  Future<void> trackNavigationEvent({
    required String fromScreen,
    required String toScreen,
    String? navigationSource,
  }) async {
    try {
      _logger.i('Tracking navigation: $fromScreen → $toScreen');

      await _analytics.logEvent(
        name: 'screen_view',
        parameters: {
          'from_screen': fromScreen,
          'to_screen': toScreen,
          'navigation_source': navigationSource ?? 'unknown',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      _logger.d('Navigation event logged');
    } catch (e) {
      _logger.e('Failed to track navigation event', error: e);
    }
  }

  /// Track user preference change
  ///
  /// Called when user changes app settings
  Future<void> trackPreferenceChanged({
    required String preferenceName,
    required dynamic oldValue,
    required dynamic newValue,
  }) async {
    try {
      _logger.i('Tracking preference change: $preferenceName');

      await _analytics.logEvent(
        name: 'preference_changed',
        parameters: {
          'preference_name': preferenceName,
          'old_value': oldValue.toString(),
          'new_value': newValue.toString(),
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      _logger.d('Preference change event logged');
    } catch (e) {
      _logger.e('Failed to track preference change', error: e);
    }
  }
}
