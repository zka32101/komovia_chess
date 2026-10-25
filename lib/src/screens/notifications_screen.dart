import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_core/komovia_core.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';
import 'challenges/challenges_screen.dart';
import 'friends/friends_screen.dart';
import 'online/online_game_screen.dart';
import '../../l10n/app_localizations.dart';

// `AppNotification.type` is a plain string (komovia_core doesn't define
// a fixed enum of notification types - see its own doc comments), so the
// icon/color dispatch that used to live as methods on this app's own
// AppNotification model now lives here instead, the same place
// komovia_go moved its equivalent per-type dispatch to when it made this
// same migration.
String _iconForType(String type) {
  switch (type) {
    case 'friend_request':
      return '🤝';
    case 'game_matched':
      return '👥';
    case 'game_turn':
      return '♟️';
    case 'game_ended':
      return '🏁';
    case 'rating_changed':
      return '📊';
    case 'achievement':
      return '🏆';
    case 'message':
      return '💬';
    case 'challenge_received':
    case 'challenge_accepted':
    case 'challenge_declined':
      return '⚔️';
    default:
      return '🔔';
  }
}

Color _colorForType(String type) {
  switch (type) {
    case 'friend_request':
      return const Color(0xff9C27B0);
    case 'game_matched':
      return const Color(0xff4CAF50);
    case 'game_turn':
      return const Color(0xff2196F3);
    case 'game_ended':
      return const Color(0xffFF9800);
    case 'rating_changed':
      return const Color(0xff00BCD4);
    case 'achievement':
      return const Color(0xffFFC107);
    case 'message':
      return const Color(0xff3F51B5);
    case 'challenge_received':
    case 'challenge_accepted':
    case 'challenge_declined':
      return const Color(0xffE91E63);
    default:
      return const Color(0xff607D8B);
  }
}

/// Groups `AppNotification.type` into a handful of broad categories for
/// the filter chips below - previously every notification type (friend
/// requests, challenges, game events, ...) was shown in one
/// undifferentiated list with no way to narrow it down.
enum _NotificationCategory { all, friends, challenges, games, other }

_NotificationCategory _categoryForType(String type) {
  switch (type) {
    case 'friend_request':
      return _NotificationCategory.friends;
    case 'challenge_received':
    case 'challenge_accepted':
    case 'challenge_declined':
      return _NotificationCategory.challenges;
    case 'game_matched':
    case 'game_turn':
    case 'game_ended':
    case 'rating_changed':
      return _NotificationCategory.games;
    default:
      return _NotificationCategory.other;
  }
}

String _labelForCategory(_NotificationCategory category, AppLocalizations l10n) {
  switch (category) {
    case _NotificationCategory.all:
      return l10n.notificationsCategoryAll;
    case _NotificationCategory.friends:
      return l10n.notificationsCategoryFriends;
    case _NotificationCategory.challenges:
      return l10n.notificationsCategoryChallenges;
    case _NotificationCategory.games:
      return l10n.notificationsCategoryGames;
    case _NotificationCategory.other:
      return l10n.notificationsCategoryOther;
  }
}

/// Notifications screen displaying all user notifications
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  _NotificationCategory _selectedCategory = _NotificationCategory.all;

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.notificationsTitle),
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
                    _showDeleteAllDialog(context, ref, user.uid, l10n);
                  }
                },
                itemBuilder: (context) => <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'mark_all_read',
                    child: Text(l10n.notificationsMarkAllReadMenuItem),
                  ),
                  PopupMenuItem<String>(
                    value: 'delete_all',
                    child: Text(l10n.notificationsDeleteAllMenuItem),
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
          child: Text(l10n.notificationsErrorMessage(error.toString())),
        ),
        data: (user) {
          if (user == null) {
            return Center(
              child: Text(l10n.notificationsLoginRequiredMessage),
            );
          }
          return _buildNotificationsList(context, ref, user.uid, l10n);
        },
      ),
    );
  }

  Widget _buildCategoryFilterBar(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SizedBox(
        height: 36,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: _NotificationCategory.values.map((category) {
            final selected = category == _selectedCategory;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(_labelForCategory(category, l10n)),
                selected: selected,
                onSelected: (_) =>
                    setState(() => _selectedCategory = category),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildNotificationsList(
    BuildContext context,
    WidgetRef ref,
    String userId,
    AppLocalizations l10n,
  ) {
    final notificationsAsync = ref.watch(firebaseNotificationsProvider(userId));

    return notificationsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(),
      ),
      error: (error, stack) => Center(
        child: Text(l10n.notificationsLoadErrorMessage(error.toString())),
      ),
      data: (batch) {
        final allNotifications = batch?.notifications ?? const [];
        final filtered = _selectedCategory == _NotificationCategory.all
            ? allNotifications
            : allNotifications
                .where((n) =>
                    _categoryForType(n.type) == _selectedCategory)
                .toList();

        if (allNotifications.isEmpty) {
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
                  l10n.notificationsNoNotificationsMessage,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            _buildCategoryFilterBar(l10n),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        l10n.notificationsNoCategoryNotificationsMessage(
                          _labelForCategory(_selectedCategory, l10n)
                              .toLowerCase(),
                        ),
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(color: Colors.grey[600]),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async {
                        // Trigger a refresh of the notifications
                        ref.refresh(firebaseNotificationsProvider(userId));
                      },
                      child: ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (context, index) => Divider(
                          height: 1,
                          color: Colors.grey[200],
                        ),
                        itemBuilder: (context, index) {
                          final notification = filtered[index];
                          return _buildNotificationTile(
                              context, ref, notification, userId, l10n);
                        },
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNotificationTile(
    BuildContext context,
    WidgetRef ref,
    AppNotification notification,
    String userId,
    AppLocalizations l10n,
  ) {
    final service = ref.read(notificationServiceProvider);

    return Material(
      color: notification.isRead ? Colors.transparent : Colors.blue[50],
      child: InkWell(
        onTap: () async {
          if (!notification.isRead) {
            await service.markAsRead(userId, notification.id);
          }
          final actionUrl = notification.data?['actionUrl'] as String?;
          if (actionUrl != null) {
            _navigateToAction(context, actionUrl, l10n);
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
                  color: _colorForType(notification.type).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    _iconForType(notification.type),
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
                              color: _colorForType(notification.type),
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
                          _formatTime(notification.createdAt, l10n),
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
                                    notification.id,
                                  );
                                },
                                icon: const Icon(Icons.done_all, size: 16),
                                label: Text(l10n.notificationsMarkReadButton),
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
                                  notification.id,
                                );
                              },
                              icon: const Icon(Icons.delete, size: 16),
                              label: Text(l10n.notificationsDeleteButton),
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

  String _formatTime(DateTime dateTime, AppLocalizations l10n) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return l10n.notificationsJustNowLabel;
    } else if (difference.inMinutes < 60) {
      return l10n.notificationsMinutesAgoLabel(difference.inMinutes);
    } else if (difference.inHours < 24) {
      return l10n.notificationsHoursAgoLabel(difference.inHours);
    } else if (difference.inDays < 7) {
      return l10n.notificationsDaysAgoLabel(difference.inDays);
    } else {
      return l10n.notificationsDateLabel(
        dateTime.month,
        dateTime.day,
        dateTime.year,
      );
    }
  }

  /// Routes a tapped notification's `actionUrl` to the real screen it
  /// names. This app has no named-route table at all (every navigation
  /// elsewhere is a direct `MaterialPageRoute`), so actionUrl values are
  /// parsed here the same way - only the shapes any service actually
  /// writes today (`/friends`, `/challenges`, `/online-game/{gameId}`)
  /// are handled; anything else falls back to a snackbar rather than
  /// silently doing nothing, so a future sender's typo is visible
  /// instead of invisible.
  void _navigateToAction(
    BuildContext context,
    String actionUrl,
    AppLocalizations l10n,
  ) {
    if (actionUrl == '/friends') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const FriendsScreen()),
      );
      return;
    }

    if (actionUrl == '/challenges') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ChallengesScreen()),
      );
      return;
    }

    final gameMatch = RegExp(r'^/online-game/(.+)$').firstMatch(actionUrl);
    if (gameMatch != null) {
      final gameId = gameMatch.group(1)!;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => OnlineGameScreen(gameId: gameId)),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l10n.notificationsUnknownDestinationMessage(actionUrl),
        ),
      ),
    );
  }

  void _showDeleteAllDialog(
    BuildContext context,
    WidgetRef ref,
    String userId,
    AppLocalizations l10n,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.notificationsDeleteAllTitle),
        content: Text(l10n.notificationsDeleteAllConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.notificationsCancelButton),
          ),
          FilledButton(
            onPressed: () async {
              final service = ref.read(notificationServiceProvider);
              await service.deleteAllNotifications(userId);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.notificationsAllDeletedMessage)),
                );
              }
            },
            child: Text(l10n.notificationsDeleteButtonAction),
          ),
        ],
      ),
    );
  }
}
