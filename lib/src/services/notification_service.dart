import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Notification severity levels
enum NotificationSeverity {
  info,
  success,
  warning,
  error,
}

extension NotificationSeverityExt on NotificationSeverity {
  Color getColor(BuildContext context) {
    switch (this) {
      case NotificationSeverity.info:
        return Colors.blue;
      case NotificationSeverity.success:
        return Colors.green;
      case NotificationSeverity.warning:
        return Colors.orange;
      case NotificationSeverity.error:
        return Colors.red;
    }
  }

  IconData getIcon() {
    switch (this) {
      case NotificationSeverity.info:
        return Icons.info_outline;
      case NotificationSeverity.success:
        return Icons.check_circle_outline;
      case NotificationSeverity.warning:
        return Icons.warning_amber_outlined;
      case NotificationSeverity.error:
        return Icons.error_outline;
    }
  }
}

/// Notification model
class AppNotification {
  AppNotification({
    required this.message,
    this.severity = NotificationSeverity.info,
    this.duration = const Duration(seconds: 3),
    this.actionLabel,
    this.onAction,
    this.dismissible = true,
  });
  final String message;
  final NotificationSeverity severity;
  final Duration duration;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool dismissible;
}

/// Service for managing notifications
class NotificationService {
  final List<AppNotification> _notifications = [];
  final List<VoidCallback> _listeners = [];

  /// Show a notification
  void show(AppNotification notification) {
    _notifications.add(notification);
    _notifyListeners();

    // Auto-remove after duration if dismissible
    if (notification.dismissible) {
      Future.delayed(notification.duration, () {
        dismiss(notification);
      });
    }
  }

  /// Dismiss a single notification - unlike [clearAll], leaves every
  /// other currently-shown notification untouched. Both NotificationOverlay's
  /// own per-card auto-dismiss timer and [show]'s auto-remove timer above
  /// call this, instead of [clearAll], so one notification timing out
  /// never wipes other notifications still on screen.
  void dismiss(AppNotification notification) {
    if (_notifications.remove(notification)) {
      _notifyListeners();
    }
  }

  /// Show an info notification
  void showInfo(String message, {Duration? duration}) {
    show(AppNotification(
      message: message,
      severity: NotificationSeverity.info,
      duration: duration ?? const Duration(seconds: 3),
    ));
  }

  /// Show a success notification
  void showSuccess(String message, {Duration? duration}) {
    show(AppNotification(
      message: message,
      severity: NotificationSeverity.success,
      duration: duration ?? const Duration(seconds: 2),
    ));
  }

  /// Show a warning notification
  void showWarning(String message, {Duration? duration}) {
    show(AppNotification(
      message: message,
      severity: NotificationSeverity.warning,
      duration: duration ?? const Duration(seconds: 4),
    ));
  }

  /// Show an error notification
  void showError(String message,
      {Duration? duration, String? actionLabel, VoidCallback? onAction}) {
    show(AppNotification(
      message: message,
      severity: NotificationSeverity.error,
      duration: duration ?? const Duration(seconds: 5),
      actionLabel: actionLabel,
      onAction: onAction,
      dismissible: true,
    ));
  }

  /// Clear all notifications
  void clearAll() {
    _notifications.clear();
    _notifyListeners();
  }

  /// Add listener for notifications
  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  /// Remove listener
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  /// Notify all listeners that the notification list changed. Previously
  /// took the single `AppNotification` that triggered the change and
  /// passed it on, but no listener ever used that argument for anything
  /// beyond re-reading the whole list (see NotificationNotifier below) -
  /// and [clearAll] had no notification to pass at all, which is exactly
  /// why it never actually notified listeners before this fix, leaving
  /// Riverpod's `state` holding already-cleared notifications.
  void _notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }

  /// Get current notifications
  List<AppNotification> getNotifications() => List.unmodifiable(_notifications);
}

/// Riverpod provider for notification service
final notificationServiceProvider = Provider((ref) => NotificationService());

/// Notification state notifier
class NotificationNotifier extends StateNotifier<List<AppNotification>> {
  NotificationNotifier(this._service) : super([]) {
    _service.addListener(() {
      state = [..._service.getNotifications()];
    });
  }
  final NotificationService _service;

  void show(AppNotification notification) => _service.show(notification);
  void showInfo(String message) => _service.showInfo(message);
  void showSuccess(String message) => _service.showSuccess(message);
  void showWarning(String message) => _service.showWarning(message);
  void showError(String message,
          {String? actionLabel, VoidCallback? onAction}) =>
      _service.showError(message, actionLabel: actionLabel, onAction: onAction);
  void dismiss(AppNotification notification) => _service.dismiss(notification);
  void clearAll() => _service.clearAll();
}

/// Riverpod provider for notifications state
final notificationsProvider =
    StateNotifierProvider<NotificationNotifier, List<AppNotification>>(
  (ref) => NotificationNotifier(ref.watch(notificationServiceProvider)),
);

/// Helper extension for easy error handling
extension ErrorHandling on Object {
  String get userFriendlyMessage {
    final error = toString();
    if (error.contains('No user logged in')) {
      return 'Please log in to continue';
    } else if (error.contains('Network')) {
      return 'Network error - please check your connection';
    } else if (error.contains('Permission')) {
      return 'You don\'t have permission for this action';
    } else if (error.contains('Timeout')) {
      return 'Request timed out - please try again';
    } else if (error.contains('Not found')) {
      return 'The requested item was not found';
    }
    return 'Something went wrong - please try again';
  }
}
