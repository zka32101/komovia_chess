import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import 'dart:async';

/// Manages advanced timeout detection and handling
class AdvancedTimeoutService {
  AdvancedTimeoutService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _firestore;
  final Logger _logger = Logger();

  static const String _gamesCollection = 'games';
  static const int _timeoutGracePeriodMs = 3000; // 3 second grace period
  static const int _inactivityTimeoutMs = 60000; // 1 minute inactivity timeout

  RealtimeTimeoutManager? _currentManager;

  /// Start timeout monitoring for a game
  RealtimeTimeoutManager startTimeoutMonitoring({
    required String gameId,
    required int initialWhiteTimeMs,
    required int initialBlackTimeMs,
    required VoidCallback onWhiteTimeout,
    required VoidCallback onBlackTimeout,
    required VoidCallback onInactivityDetected,
  }) {
    _currentManager = RealtimeTimeoutManager(
      gameId: gameId,
      initialWhiteTime: initialWhiteTimeMs,
      initialBlackTime: initialBlackTimeMs,
      onWhiteTimeout: onWhiteTimeout,
      onBlackTimeout: onBlackTimeout,
      onInactivityDetected: onInactivityDetected,
      firestore: _firestore,
      logger: _logger,
    );

    _currentManager!.start();
    return _currentManager!;
  }

  /// Stop timeout monitoring
  void stopTimeoutMonitoring() {
    _currentManager?.stop();
    _currentManager = null;
  }

  /// Record player activity to prevent inactivity timeout
  Future<void> recordPlayerActivity(String gameId, String playerId) async {
    try {
      await _firestore.collection(_gamesCollection).doc(gameId).update({
        '${playerId}LastActivityAt': FieldValue.serverTimestamp(),
      });

      _currentManager?.recordActivity(playerId);
    } catch (e, st) {
      _logger.e('Failed to record player activity', error: e, stackTrace: st);
    }
  }

  /// Get timeout status for a game
  Future<TimeoutStatus> getTimeoutStatus(String gameId) async {
    try {
      final gameDoc =
          await _firestore.collection(_gamesCollection).doc(gameId).get();

      if (!gameDoc.exists) {
        throw Exception('Game not found');
      }

      final data = gameDoc.data()!;
      final whiteTimeMs = data['whiteTimeRemainingMs'] as int? ?? 0;
      final blackTimeMs = data['blackTimeRemainingMs'] as int? ?? 0;

      final whiteLastActivity =
          (data['whiteLastActivityAt'] as Timestamp?)?.toDate();
      final blackLastActivity =
          (data['blackLastActivityAt'] as Timestamp?)?.toDate();

      final now = DateTime.now();

      return TimeoutStatus(
        gameId: gameId,
        whiteTimeRemaining: whiteTimeMs,
        blackTimeRemaining: blackTimeMs,
        whiteInactivityDuration: whiteLastActivity != null
            ? now.difference(whiteLastActivity).inMilliseconds
            : 0,
        blackInactivityDuration: blackLastActivity != null
            ? now.difference(blackLastActivity).inMilliseconds
            : 0,
        whiteTimedOut: whiteTimeMs <= 0,
        blackTimedOut: blackTimeMs <= 0,
        whiteInactive: whiteLastActivity != null &&
            now.difference(whiteLastActivity).inMilliseconds >
                _inactivityTimeoutMs,
        blackInactive: blackLastActivity != null &&
            now.difference(blackLastActivity).inMilliseconds >
                _inactivityTimeoutMs,
      );
    } catch (e, st) {
      _logger.e('Failed to get timeout status', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Get time control for a game
  Future<TimeControl> getTimeControl(String gameId) async {
    try {
      final gameDoc =
          await _firestore.collection(_gamesCollection).doc(gameId).get();

      if (!gameDoc.exists) {
        throw Exception('Game not found');
      }

      final data = gameDoc.data()!;

      return TimeControl(
        timeControl: data['timeControl'] as String? ?? '5min',
        totalTimeMs: data['timeControlMs'] as int? ?? 300000,
        incrementMs: data['incrementMs'] as int? ?? 0,
      );
    } catch (e, st) {
      _logger.e('Failed to get time control', error: e, stackTrace: st);
      rethrow;
    }
  }
}

/// Manages real-time timeout tracking during a game
class RealtimeTimeoutManager {
  RealtimeTimeoutManager({
    required this.gameId,
    required this.initialWhiteTime,
    required this.initialBlackTime,
    required this.onWhiteTimeout,
    required this.onBlackTimeout,
    required this.onInactivityDetected,
    required this.firestore,
    required this.logger,
  })  : _whiteTimeRemaining = initialWhiteTime,
        _blackTimeRemaining = initialBlackTime;
  final String gameId;
  final int initialWhiteTime;
  final int initialBlackTime;
  final VoidCallback onWhiteTimeout;
  final VoidCallback onBlackTimeout;
  final VoidCallback onInactivityDetected;
  final FirebaseFirestore firestore;
  final Logger logger;

  late Timer _whiteTimeTimer;
  late Timer _blackTimeTimer;
  late Timer _inactivityCheckTimer;

  int _whiteTimeRemaining;
  int _blackTimeRemaining;
  DateTime? _whiteLastActivity;
  DateTime? _blackLastActivity;
  bool _isRunning = false;

  void start() {
    if (_isRunning) return;
    _isRunning = true;

    _whiteLastActivity = DateTime.now();
    _blackLastActivity = DateTime.now();

    // Check time every 100ms
    _whiteTimeTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      _whiteTimeRemaining -= 100;
      if (_whiteTimeRemaining <= 0 && !_isRunning) {
        onWhiteTimeout();
        logger.w('White player timed out on game $gameId');
      }
    });

    _blackTimeTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      _blackTimeRemaining -= 100;
      if (_blackTimeRemaining <= 0 && !_isRunning) {
        onBlackTimeout();
        logger.w('Black player timed out on game $gameId');
      }
    });

    // Check inactivity every 5 seconds
    _inactivityCheckTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkInactivity();
    });

    logger.i('Started timeout monitoring for game $gameId');
  }

  void stop() {
    _isRunning = false;
    _whiteTimeTimer.cancel();
    _blackTimeTimer.cancel();
    _inactivityCheckTimer.cancel();
    logger.i('Stopped timeout monitoring for game $gameId');
  }

  void recordActivity(String playerId) {
    if (playerId == 'white') {
      _whiteLastActivity = DateTime.now();
    } else {
      _blackLastActivity = DateTime.now();
    }
  }

  void updateTimeRemaining(int whiteMs, int blackMs) {
    _whiteTimeRemaining = whiteMs;
    _blackTimeRemaining = blackMs;
  }

  void _checkInactivity() {
    const inactivityThresholdMs = 60000; // 1 minute
    final now = DateTime.now();

    if (_whiteLastActivity != null &&
        now.difference(_whiteLastActivity!).inMilliseconds >
            inactivityThresholdMs) {
      logger.w('White player inactive for >1 minute on game $gameId');
      onInactivityDetected();
    }

    if (_blackLastActivity != null &&
        now.difference(_blackLastActivity!).inMilliseconds >
            inactivityThresholdMs) {
      logger.w('Black player inactive for >1 minute on game $gameId');
      onInactivityDetected();
    }
  }
}

/// Data class for timeout status
class TimeoutStatus {
  TimeoutStatus({
    required this.gameId,
    required this.whiteTimeRemaining,
    required this.blackTimeRemaining,
    required this.whiteInactivityDuration,
    required this.blackInactivityDuration,
    required this.whiteTimedOut,
    required this.blackTimedOut,
    required this.whiteInactive,
    required this.blackInactive,
  });
  final String gameId;
  final int whiteTimeRemaining;
  final int blackTimeRemaining;
  final int whiteInactivityDuration;
  final int blackInactivityDuration;
  final bool whiteTimedOut;
  final bool blackTimedOut;
  final bool whiteInactive;
  final bool blackInactive;

  bool get anyPlayerTimedOut => whiteTimedOut || blackTimedOut;
  bool get anyPlayerInactive => whiteInactive || blackInactive;
}

/// Data class for time control
class TimeControl {
  TimeControl({
    required this.timeControl,
    required this.totalTimeMs,
    required this.incrementMs,
  });
  final String timeControl;
  final int totalTimeMs;
  final int incrementMs;
}

typedef VoidCallback = void Function();
