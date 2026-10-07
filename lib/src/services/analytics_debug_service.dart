import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// Analytics debug service
///
/// Provides debugging and testing utilities for analytics tracking
class AnalyticsDebugService {
  factory AnalyticsDebugService() => _instance;

  AnalyticsDebugService._internal();
  static final AnalyticsDebugService _instance =
      AnalyticsDebugService._internal();

  final Logger _logger = Logger();
  bool _debugMode = kDebugMode;
  bool _logAllEvents = false;
  bool _mockAnalyticsEnabled = false;

  // Event tracking for debugging
  final List<Map<String, dynamic>> _eventLog = [];
  final int _maxEventLogSize = 500;

  /// Enable/disable debug mode
  void setDebugMode(bool enabled) {
    _debugMode = enabled;
    _logger.i('Debug mode: $enabled');
  }

  /// Enable/disable logging all events
  void setLogAllEvents(bool enabled) {
    _logAllEvents = enabled;
    _logger.i('Log all events: $enabled');
  }

  /// Enable/disable mock analytics (events are logged but not sent)
  void setMockAnalyticsEnabled(bool enabled) {
    _mockAnalyticsEnabled = enabled;
    _logger.i('Mock analytics: $enabled');
  }

  /// Log analytics event for debugging
  void logAnalyticsEvent(
    String eventName,
    Map<String, dynamic> parameters,
  ) {
    if (!_debugMode && !_logAllEvents) {
      return;
    }

    final event = {
      'eventName': eventName,
      'parameters': parameters,
      'timestamp': DateTime.now().toIso8601String(),
    };

    _eventLog.add(event);

    // Keep log size manageable
    if (_eventLog.length > _maxEventLogSize) {
      _eventLog.removeAt(0);
    }

    _logger.d('Analytics Event: $eventName\nParameters: $parameters');
  }

  /// Get event log
  List<Map<String, dynamic>> getEventLog() => List.from(_eventLog);

  /// Clear event log
  void clearEventLog() {
    _eventLog.clear();
    _logger.i('Analytics event log cleared');
  }

  /// Get event count
  int getEventCount() => _eventLog.length;

  /// Get events by name
  List<Map<String, dynamic>> getEventsByName(String eventName) =>
      _eventLog.where((event) => event['eventName'] == eventName).toList();

  /// Get events by time range
  List<Map<String, dynamic>> getEventsByTimeRange(
    DateTime start,
    DateTime end,
  ) =>
      _eventLog.where((event) {
        try {
          final timestamp = DateTime.parse(event['timestamp'] as String);
          return timestamp.isAfter(start) && timestamp.isBefore(end);
        } catch (e) {
          return false;
        }
      }).toList();

  /// Print event log
  void printEventLog() {
    _logger.i('=== Analytics Event Log (${_eventLog.length} events) ===');
    for (final event in _eventLog) {
      _logger.i('${event['timestamp']} | ${event['eventName']}');
      _logger.i('  Parameters: ${event['parameters']}');
    }
    _logger.i('=== End Event Log ===');
  }

  /// Export event log as JSON
  String exportEventLogAsJson() {
    // Simple JSON export - in production use json_serializable
    final events = _eventLog
        .map((e) => '{\n'
            '  "eventName": "${e['eventName']}",\n'
            '  "timestamp": "${e['timestamp']}",\n'
            '  "parameters": ${_parametersToJsonString(e['parameters'] as Map<String, dynamic>)}\n'
            '}')
        .join(',\n');

    return '[\n$events\n]';
  }

  /// Convert parameters to JSON string
  String _parametersToJsonString(Map<String, dynamic> params) {
    final entries = params.entries.map((e) {
      final value = e.value;
      if (value is String) {
        return '"${e.key}": "$value"';
      } else if (value is num) {
        return '"${e.key}": $value';
      } else if (value is bool) {
        return '"${e.key}": $value';
      } else {
        return '"${e.key}": "${value.toString()}"';
      }
    }).join(', ');

    return '{$entries}';
  }

  /// Get analytics status
  Map<String, dynamic> getAnalyticsStatus() => {
        'debug_mode': _debugMode,
        'log_all_events': _logAllEvents,
        'mock_analytics': _mockAnalyticsEnabled,
        'event_log_size': _eventLog.length,
        'max_log_size': _maxEventLogSize,
        'recent_events': _eventLog.isNotEmpty
            ? _eventLog.sublist(
                (_eventLog.length - 5).clamp(0, _eventLog.length),
              )
            : [],
      };

  /// Simulate purchase event
  void simulatePurchaseEvent({
    String productId = 'test.pro.monthly',
    double price = 9.99,
    String currency = 'USD',
  }) {
    logAnalyticsEvent('subscription_purchase', {
      'product_id': productId,
      'subscription_tier': 'pro',
      'value': price,
      'currency': currency,
      'transaction_id': 'test_${DateTime.now().millisecondsSinceEpoch}',
    });
    _logger.i('Simulated purchase event');
  }

  /// Simulate upgrade event
  void simulateUpgradeEvent({
    String fromTier = 'free',
    String toTier = 'pro',
    double price = 9.99,
  }) {
    logAnalyticsEvent('subscription_upgrade', {
      'from_tier': fromTier,
      'to_tier': toTier,
      'value': price,
      'currency': 'USD',
    });
    _logger.i('Simulated upgrade event');
  }

  /// Simulate game event
  void simulateGameEvent({
    String result = 'win',
    int ratingChange = 25,
  }) {
    logAnalyticsEvent('game_completed', {
      'game_id': 'test_${DateTime.now().millisecondsSinceEpoch}',
      'result': result,
      'moves_count': 42,
      'duration_seconds': 600.0,
      'rating_change': ratingChange,
    });
    _logger.i('Simulated game event');
  }

  /// Simulate puzzle event
  void simulatePuzzleEvent({
    bool solved = true,
    int difficulty = 1500,
  }) {
    logAnalyticsEvent('puzzle_completed', {
      'puzzle_id': 'test_${DateTime.now().millisecondsSinceEpoch}',
      'difficulty': difficulty,
      'solved': solved,
      'moves_used': 3,
      'optimal_moves': 2,
      'time_spent': 45.5,
    });
    _logger.i('Simulated puzzle event');
  }

  /// Simulate error event
  void simulateErrorEvent({
    String errorCode = 'TEST_ERROR',
    String errorContext = 'test_context',
  }) {
    logAnalyticsEvent('error_occurred', {
      'error_code': errorCode,
      'error_message': 'Test error message',
      'error_context': errorContext,
      'error_details': 'Test error details',
    });
    _logger.i('Simulated error event');
  }

  /// Generate analytics report
  String generateAnalyticsReport() {
    final status = getAnalyticsStatus();
    final eventsByName = <String, int>{};

    for (final event in _eventLog) {
      final eventName = event['eventName'] as String;
      eventsByName[eventName] = (eventsByName[eventName] ?? 0) + 1;
    }

    final report = StringBuffer();
    report.writeln('=== Analytics Debug Report ===');
    report.writeln('Debug Mode: ${status['debug_mode']}');
    report.writeln('Log All Events: ${status['log_all_events']}');
    report.writeln('Mock Analytics: ${status['mock_analytics']}');
    report.writeln('');
    report.writeln('Total Events: ${status['event_log_size']}');
    report.writeln('');
    report.writeln('Events by Type:');

    eventsByName.forEach((name, count) {
      report.writeln('  $name: $count');
    });

    report.writeln('');
    report.writeln('Recent Events:');

    final recentEvents = status['recent_events'] as List;
    for (final event in recentEvents) {
      report.writeln(
        '  ${event['timestamp']} | ${event['eventName']}',
      );
    }

    report.writeln('');
    report.writeln('=== End Report ===');

    return report.toString();
  }

  /// Validate event
  bool validateEvent(String eventName, Map<String, dynamic> parameters) {
    if (eventName.isEmpty) {
      _logger.w('Event name is empty');
      return false;
    }

    if (parameters.isEmpty) {
      _logger.w('Event parameters are empty');
      return false;
    }

    // Check for required timestamp
    if (!parameters.containsKey('timestamp')) {
      _logger.w('Event missing timestamp');
      return false;
    }

    return true;
  }

  /// Reset debug service
  void reset() {
    _debugMode = kDebugMode;
    _logAllEvents = false;
    _mockAnalyticsEnabled = false;
    _eventLog.clear();
    _logger.i('Debug service reset');
  }
}
