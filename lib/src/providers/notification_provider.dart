import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:komovia_core/komovia_core.dart';
import '../services/firestore_time.dart';
import 'auth_provider.dart';

// `AppNotification` used to be declared locally here (in
// `models/notification.dart`) with its own freezed/Firestore-coupled
// shape (enum `NotificationType`, `NotificationPriority`, a
// `notificationId`/`userId` naming, and type-specific factory
// constructors/`getIcon()`/`getColor()` helpers). That shape has been
// replaced by `package:komovia_core`'s game-agnostic `AppNotification`,
// which has no storage dependency - converting to/from Firestore's
// `DocumentSnapshot`/`Timestamp` is this file's own responsibility (the
// same split komovia_go's `notification_provider.dart`/`models/
// notification.dart` already use).
//
// komovia_core's `AppNotification.type` is a plain `String` (not an enum)
// and its `data` map is exactly where the old model's extra
// `opponentName`/`gameId`/`ratingDelta`/`actionUrl`/`priority` fields now
// live - see `_notificationFromDoc` below. Icon/color dispatch per type
// moved to `notifications_screen.dart` (a simple `switch` on the type
// string), the same place komovia_go moved its own per-type dispatch to
// when it made this same migration.

/// Converts a Firestore notification doc into `AppNotification`. The doc's
/// own id becomes `AppNotification.id`; any of the old model's
/// type-specific extra fields found on the doc (`opponentName`/`gameId`/
/// `ratingDelta`/`actionUrl`/`priority`) are folded into `data` so callers
/// that still write them (see `FriendService`) keep working.
AppNotification notificationFromDoc(
  DocumentSnapshot<Map<String, dynamic>> doc,
) {
  final raw = doc.data() ?? const <String, dynamic>{};
  final existingData = raw['data'];
  final data = <String, Object?>{
    if (existingData is Map) ...existingData.cast<String, Object?>(),
    for (final key in const [
      'opponentName',
      'gameId',
      'ratingDelta',
      'actionUrl',
      'priority',
    ])
      if (raw[key] != null) key: raw[key],
  };
  return AppNotification.fromJson({
    ...raw,
    'id': doc.id,
    'uid': raw['uid'] ?? raw['userId'],
    'data': data.isEmpty ? null : data,
    'createdAt': isoFromTimestamp(raw['createdAt']),
    'readAt': isoFromTimestamp(raw['readAt']),
  });
}

/// A page of notifications plus the derived unread count - a thin,
/// app-local convenience wrapper (not a komovia_core concept) kept so the
/// existing screens/providers below don't need reshaping beyond the model
/// swap itself.
class NotificationBatch {
  const NotificationBatch({
    required this.notifications,
    required this.unreadCount,
    required this.lastFetchedAt,
  });
  final List<AppNotification> notifications;
  final int unreadCount;
  final DateTime lastFetchedAt;
}

/// Firebase notifications provider
final firebaseNotificationsProvider =
    StreamProvider.family<NotificationBatch?, String>((ref, userId) {
  final firestore = FirebaseFirestore.instance;

  return firestore
      .collection('users')
      .doc(userId)
      .collection('notifications')
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots()
      .map((snapshot) {
    if (snapshot.docs.isEmpty) {
      return NotificationBatch(
        notifications: const [],
        unreadCount: 0,
        lastFetchedAt: DateTime.now(),
      );
    }

    final notifications = snapshot.docs.map(notificationFromDoc).toList();

    final unreadCount = notifications.where((n) => !n.isRead).length;

    return NotificationBatch(
      notifications: notifications,
      unreadCount: unreadCount,
      lastFetchedAt: DateTime.now(),
    );
  });
});

/// Current user notifications provider
final currentUserNotificationsProvider =
    StreamProvider<NotificationBatch?>((ref) {
  final userAsync = ref.watch(currentUserProvider);

  return userAsync.when(
    loading: () => Stream.value(null),
    error: (err, stack) => Stream.value(null),
    data: (user) {
      if (user == null) {
        return Stream.value(null);
      }
      return ref.watch(firebaseNotificationsProvider(user.uid)).when(
            loading: () => Stream.value(null),
            error: (err, stack) => Stream.value(null),
            data: Stream.value,
          );
    },
  );
});

/// Unread notifications count provider
final unreadNotificationsCountProvider = Provider<int>((ref) {
  final userAsync = ref.watch(currentUserProvider);

  return userAsync.when(
    loading: () => 0,
    error: (err, stack) => 0,
    data: (user) {
      if (user == null) return 0;

      final batchAsync = ref.watch(firebaseNotificationsProvider(user.uid));
      return batchAsync.when(
        loading: () => 0,
        error: (err, stack) => 0,
        data: (batch) => batch?.unreadCount ?? 0,
      );
    },
  );
});

/// Notification service for marking as read and deleting
class NotificationServiceProvider {
  NotificationServiceProvider(this._firestore);
  final FirebaseFirestore _firestore;

  /// Mark a notification as read
  Future<void> markAsRead(String userId, String notificationId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
    } catch (e) {
      rethrow;
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead(String userId) async {
    try {
      final batch = _firestore.batch();
      final docs = await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .get();

      for (final doc in docs.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }

  /// Delete a notification
  Future<void> deleteNotification(String userId, String notificationId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .delete();
    } catch (e) {
      rethrow;
    }
  }

  /// Delete all notifications
  Future<void> deleteAllNotifications(String userId) async {
    try {
      final batch = _firestore.batch();
      final docs = await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .get();

      for (final doc in docs.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }
}

/// Notification service provider
final notificationServiceProvider = Provider((ref) {
  final firestore = FirebaseFirestore.instance;
  return NotificationServiceProvider(firestore);
});

/// Notification action handler
final notificationActionProvider =
    StateNotifierProvider<NotificationActionNotifier, AsyncValue<void>>(
        NotificationActionNotifier.new);

class NotificationActionNotifier extends StateNotifier<AsyncValue<void>> {
  NotificationActionNotifier(this.ref) : super(const AsyncValue.data(null));
  final StateNotifierProviderRef ref;

  /// Mark notification as read
  Future<void> markAsRead(String userId, String notificationId) async {
    state = const AsyncValue.loading();
    final service = ref.watch(notificationServiceProvider);
    state = await AsyncValue.guard(
        () => service.markAsRead(userId, notificationId));
  }

  /// Mark all as read
  Future<void> markAllAsRead(String userId) async {
    state = const AsyncValue.loading();
    final service = ref.watch(notificationServiceProvider);
    state = await AsyncValue.guard(() => service.markAllAsRead(userId));
  }

  /// Delete a notification
  Future<void> deleteNotification(String userId, String notificationId) async {
    state = const AsyncValue.loading();
    final service = ref.watch(notificationServiceProvider);
    state = await AsyncValue.guard(
        () => service.deleteNotification(userId, notificationId));
  }

  /// Delete all notifications
  Future<void> deleteAllNotifications(String userId) async {
    state = const AsyncValue.loading();
    final service = ref.watch(notificationServiceProvider);
    state =
        await AsyncValue.guard(() => service.deleteAllNotifications(userId));
  }
}
