import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/notification_service.dart';
import '../utils/animations.dart';

/// Global notification overlay widget
class NotificationOverlay extends ConsumerWidget {
  const NotificationOverlay({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);

    return Stack(
      children: [
        for (int i = 0; i < notifications.length; i++)
          Positioned(
            top: 16 + (i * 80),
            left: 16,
            right: 16,
            child: SlideInAnimation(
              direction: SlideDirection.up,
              delay: Duration(milliseconds: i * 100),
              child: _NotificationCard(
                notification: notifications[i],
                onDismiss: () {
                  ref.read(notificationsProvider.notifier).clearAll();
                },
              ),
            ),
          ),
      ],
    );
  }
}

/// Individual notification card
class _NotificationCard extends StatefulWidget {
  const _NotificationCard({
    required this.notification,
    required this.onDismiss,
  });
  final AppNotification notification;
  final VoidCallback onDismiss;

  @override
  State<_NotificationCard> createState() => _NotificationCardState();
}

class _NotificationCardState extends State<_NotificationCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _dismissController;

  @override
  void initState() {
    super.initState();
    _dismissController = AnimationController(
      duration: AnimationConstants.normal,
      vsync: this,
    );

    // Auto-dismiss after duration
    if (widget.notification.dismissible) {
      Future.delayed(widget.notification.duration, () {
        if (mounted) {
          _dismiss();
        }
      });
    }
  }

  @override
  void dispose() {
    _dismissController.dispose();
    super.dispose();
  }

  void _dismiss() async {
    await _dismissController.forward();
    if (mounted) {
      widget.onDismiss();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final severity = widget.notification.severity;

    return SlideTransition(
      position: Tween<Offset>(begin: Offset.zero, end: const Offset(2, 0))
          .animate(_dismissController),
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: severity.getColor(context).withOpacity(0.1),
            border: Border.all(
              color: severity.getColor(context),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: severity.getColor(context).withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                severity.getIcon(),
                color: severity.getColor(context),
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.notification.message,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (widget.notification.actionLabel != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: TextButton(
                          onPressed: () {
                            widget.notification.onAction?.call();
                            _dismiss();
                          },
                          child: Text(widget.notification.actionLabel!),
                        ),
                      ),
                  ],
                ),
              ),
              if (widget.notification.dismissible)
                IconButton(
                  onPressed: _dismiss,
                  icon: const Icon(Icons.close),
                  iconSize: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Snackbar helper for backward compatibility
class NotificationHelper {
  static void showSnackBar(
    BuildContext context,
    String message, {
    NotificationSeverity severity = NotificationSeverity.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              severity.getIcon(),
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: severity.getColor(context),
        duration: duration,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
