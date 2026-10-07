import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'notification.freezed.dart';
part 'notification.g.dart';

/// `createdAt` is written via `FieldValue.serverTimestamp()` (see
/// `NotificationServiceProvider.createNotification` in
/// notification_provider.dart), which reads back as a [Timestamp], not the
/// ISO-8601 string json_serializable's default `DateTime` handling expects.
DateTime _requiredDateTimeFromTimestamp(Object? json) =>
    (json is Timestamp) ? json.toDate() : DateTime.parse(json as String);

/// Notification type enum
enum NotificationType {
  gameMatched('Game Matched', 'opponent_found'),
  gameTurn('Your Turn', 'your_turn'),
  gameEnded('Game Ended', 'game_ended'),
  friendRequest('Friend Request', 'friend_request'),
  ratingChanged('Rating Changed', 'rating_changed'),
  achievement('Achievement Unlocked', 'achievement'),
  message('New Message', 'message');

  final String label;
  final String iconName;
  const NotificationType(this.label, this.iconName);
}

/// Notification priority
enum NotificationPriority { low, normal, high }

/// Game notification model
@freezed
class AppNotification with _$AppNotification {
  const factory AppNotification({
    required String notificationId,
    required String userId,
    required NotificationType type,
    required String title,
    required String body,
    // ignore: invalid_annotation_target
    @JsonKey(fromJson: _requiredDateTimeFromTimestamp)
    required DateTime createdAt,
    required bool isRead,
    String? opponentName,
    String? gameId,
    String? ratingDelta,
    String? actionUrl,
    @Default(NotificationPriority.normal) NotificationPriority priority,
  }) = _AppNotification;
  const AppNotification._();

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      _$AppNotificationFromJson(json);

  /// Create game matched notification
  static AppNotification gameMatched({
    required String notificationId,
    required String userId,
    required String opponentName,
    required String gameId,
  }) =>
      AppNotification(
        notificationId: notificationId,
        userId: userId,
        type: NotificationType.gameMatched,
        title: 'Opponent Found!',
        body: 'You matched with $opponentName. Game is starting!',
        createdAt: DateTime.now(),
        isRead: false,
        opponentName: opponentName,
        gameId: gameId,
        actionUrl: '/game/$gameId',
        priority: NotificationPriority.high,
      );

  /// Create your turn notification
  static AppNotification gameTurn({
    required String notificationId,
    required String userId,
    required String opponentName,
    required String gameId,
  }) =>
      AppNotification(
        notificationId: notificationId,
        userId: userId,
        type: NotificationType.gameTurn,
        title: 'Your Move!',
        body: '$opponentName is waiting for your move.',
        createdAt: DateTime.now(),
        isRead: false,
        opponentName: opponentName,
        gameId: gameId,
        actionUrl: '/game/$gameId',
        priority: NotificationPriority.high,
      );

  /// Create game ended notification
  static AppNotification gameEnded({
    required String notificationId,
    required String userId,
    required String opponentName,
    required String result, // win, loss, draw
    required String gameId,
    int? ratingDelta,
  }) {
    final resultText = result == 'win'
        ? 'You won!'
        : result == 'loss'
            ? 'You lost.'
            : 'Draw!';

    final body = ratingDelta != null && ratingDelta != 0
        ? '$resultText Rating: ${ratingDelta > 0 ? '+' : ''}$ratingDelta'
        : resultText;

    return AppNotification(
      notificationId: notificationId,
      userId: userId,
      type: NotificationType.gameEnded,
      title: 'Game Complete',
      body: body,
      createdAt: DateTime.now(),
      isRead: false,
      opponentName: opponentName,
      gameId: gameId,
      ratingDelta: ratingDelta?.toString(),
      actionUrl: '/game/$gameId/result',
      priority: NotificationPriority.normal,
    );
  }

  /// Create rating changed notification
  static AppNotification ratingChanged({
    required String notificationId,
    required String userId,
    required int oldRating,
    required int newRating,
  }) {
    final delta = newRating - oldRating;
    final sign = delta > 0 ? '+' : '';

    return AppNotification(
      notificationId: notificationId,
      userId: userId,
      type: NotificationType.ratingChanged,
      title: 'Rating Updated',
      body: 'Your rating is now $newRating ($sign$delta)',
      createdAt: DateTime.now(),
      isRead: false,
      ratingDelta: '$sign$delta',
      priority: NotificationPriority.normal,
    );
  }

  /// Create achievement notification
  static AppNotification achievement({
    required String notificationId,
    required String userId,
    required String achievementName,
    required String description,
  }) =>
      AppNotification(
        notificationId: notificationId,
        userId: userId,
        type: NotificationType.achievement,
        title: 'Achievement Unlocked!',
        body: '$achievementName: $description',
        createdAt: DateTime.now(),
        isRead: false,
        priority: NotificationPriority.high,
      );

  /// Get notification icon based on type
  String getIcon() {
    switch (type) {
      case NotificationType.gameMatched:
        return '👥';
      case NotificationType.gameTurn:
        return '♟️';
      case NotificationType.gameEnded:
        return '🏁';
      case NotificationType.friendRequest:
        return '🤝';
      case NotificationType.ratingChanged:
        return '📊';
      case NotificationType.achievement:
        return '🏆';
      case NotificationType.message:
        return '💬';
    }
  }

  /// Get notification color based on type
  String getColor() {
    switch (type) {
      case NotificationType.gameMatched:
        return '#4CAF50'; // Green
      case NotificationType.gameTurn:
        return '#2196F3'; // Blue
      case NotificationType.gameEnded:
        return '#FF9800'; // Orange
      case NotificationType.friendRequest:
        return '#9C27B0'; // Purple
      case NotificationType.ratingChanged:
        return '#00BCD4'; // Cyan
      case NotificationType.achievement:
        return '#FFC107'; // Amber
      case NotificationType.message:
        return '#3F51B5'; // Indigo
    }
  }
}

/// Notification batch for multiple notifications
@freezed
class NotificationBatch with _$NotificationBatch {
  const factory NotificationBatch({
    required List<AppNotification> notifications,
    required int unreadCount,
    required DateTime lastFetchedAt,
  }) = _NotificationBatch;
  const NotificationBatch._();

  factory NotificationBatch.fromJson(Map<String, dynamic> json) =>
      _$NotificationBatchFromJson(json);

  /// Get unread notifications only
  List<AppNotification> getUnreadNotifications() =>
      notifications.where((n) => !n.isRead).toList();

  /// Get notifications of specific type
  List<AppNotification> getNotificationsOfType(NotificationType type) =>
      notifications.where((n) => n.type == type).toList();

  /// Get high priority notifications
  List<AppNotification> getHighPriorityNotifications() => notifications
      .where((n) => n.priority == NotificationPriority.high && !n.isRead)
      .toList();
}
