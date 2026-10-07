import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';

/// Notifications screen displaying all user notifications
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        centerTitle: true,
        elevation: 0,
        actions: [
          userAsync.when(
            loading: () => const SizedBox(),
            error: (_, __) => const SizedBox(),
            data: (user) {
              if (user == null) return const SizedBox();
              return PopupMenuButton<String>(
                onSelected: (value) async {
                  final service = ref.read(notificationServiceProvider);
                  if (value == 'mark_all_read') {
                    await service.markAllAsRead(user.uid);
                  } else if (value == 'delete_all') {
                    _showDeleteAllDialog(context, ref, user.uid);
                  }
                },
                itemBuilder: (context) => <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(
                    value: 'mark_all_read',
                    child: Text('Mark all as read'),
                  ),
                  const PopupMenuItem<String>(
                    value: 'delete_all',
                    child: Text('Delete all'),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: userAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stack) => Center(
          child: Text('Error: $error'),
        ),
        data: (user) {
          if (user == null) {
            return const Center(
              child: Text('Please log in to view notifications'),
            );
          }
          return _buildNotificationsList(context, ref, user.uid);
        },
      ),
    );
  }

  Widget _buildNotificationsList(
      BuildContext context, WidgetRef ref, String userId) {
    final notificationsAsync = ref.watch(firebaseNotificationsProvider(userId));

    return notificationsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(),
      ),
      error: (error, stack) => Center(
        child: Text('Error loading notifications: $error'),
      ),
      data: (batch) {
        if (batch == null || batch.notifications.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.notifications_none,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No notifications',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            // Trigger a refresh of the notifications
            ref.refresh(firebaseNotificationsProvider(userId));
          },
          child: ListView.separated(
            itemCount: batch.notifications.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              color: Colors.grey[200],
            ),
            itemBuilder: (context, index) {
              final notification = batch.notifications[index];
              return _buildNotificationTile(context, ref, notification, userId);
            },
          ),
        );
      },
    );
  }

  Widget _buildNotificationTile(
    BuildContext context,
    WidgetRef ref,
    AppNotification notification,
    String userId,
  ) {
    final service = ref.read(notificationServiceProvider);

    return Material(
      color: notification.isRead ? Colors.transparent : Colors.blue[50],
      child: InkWell(
        onTap: () async {
          if (!notification.isRead) {
            await service.markAsRead(userId, notification.notificationId);
          }
          if (notification.actionUrl != null) {
            _navigateToAction(context, notification.actionUrl!);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Color(
                    int.parse(
                      notification.getColor().replaceFirst('#', '0xff'),
                    ),
                  ).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    notification.getIcon(),
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style:
                                Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      fontWeight: notification.isRead
                                          ? FontWeight.w500
                                          : FontWeight.w700,
                                    ),
                          ),
                        ),
                        if (!notification.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Color(
                                int.parse(
                                  notification
                                      .getColor()
                                      .replaceFirst('#', '0xff'),
                                ),
                              ),
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatTime(notification.createdAt),
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: Colors.grey[500],
                                  ),
                        ),
                        Row(
                          children: [
                            if (!notification.isRead)
                              TextButton.icon(
                                onPressed: () async {
                                  await service.markAsRead(
                                    userId,
                                    notification.notificationId,
                                  );
                                },
                                icon: const Icon(Icons.done_all, size: 16),
                                label: const Text('Mark read'),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            TextButton.icon(
                              onPressed: () async {
                                await service.deleteNotification(
                                  userId,
                                  notification.notificationId,
                                );
                              },
                              icon: const Icon(Icons.delete, size: 16),
                              label: const Text('Delete'),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.month}/${dateTime.day}/${dateTime.year}';
    }
  }

  void _navigateToAction(BuildContext context, String actionUrl) {
    // This would typically navigate to a specific screen based on the action URL
    // For now, just a placeholder
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Navigate to: $actionUrl')),
    );
  }

  void _showDeleteAllDialog(
      BuildContext context, WidgetRef ref, String userId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete all notifications?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final service = ref.read(notificationServiceProvider);
              await service.deleteAllNotifications(userId);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All notifications deleted')),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
