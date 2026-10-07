import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification.dart';
import 'auth_provider.dart';

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
        notifications: [],
        unreadCount: 0,
        lastFetchedAt: DateTime.now(),
      );
    }

    final notifications = snapshot.docs
        .map((doc) => AppNotification.fromJson(doc.data()))
        .toList();

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

  /// Delete notification
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
