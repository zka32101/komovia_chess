import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/phase_k_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/friend_provider.dart';
import '../../providers/challenge_provider.dart';

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  @override
  Widget build(BuildContext context) {
    final pendingRequests = ref.watch(pendingFriendRequestsProvider);
    final requestCount = pendingRequests.value?.length ?? 0;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Friends'),
          centerTitle: true,
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              const Tab(text: 'Friends'),
              Tab(
                  text: requestCount > 0
                      ? 'Requests ($requestCount)'
                      : 'Requests'),
              const Tab(text: 'Add Friend'),
              const Tab(text: 'Activity'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _FriendsListTab(),
            _RequestsTab(),
            _AddFriendTab(),
            _ActivityFeedTab(),
          ],
        ),
      ),
    );
  }
}

class _FriendsListTab extends ConsumerWidget {
  const _FriendsListTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friends = ref.watch(userFriendsProvider);

    return friends.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
      data: (list) {
        if (list.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('No friends yet. Add one from the "Add Friend" tab.'),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final friend = list[index];
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundImage: friend.friendAvatar.isNotEmpty
                      ? NetworkImage(friend.friendAvatar)
                      : null,
                  child: friend.friendAvatar.isEmpty
                      ? const Icon(Icons.person)
                      : null,
                ),
                title: Text(friend.friendUsername),
                subtitle: Text('Rating: ${friend.friendRating}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.bolt_outlined),
                      tooltip: 'Challenge',
                      onPressed: () => _sendChallenge(context, ref, friend),
                    ),
                    IconButton(
                      icon: const Icon(Icons.person_remove_outlined),
                      tooltip: 'Remove friend',
                      onPressed: () => _confirmRemove(context, ref, friend),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _sendChallenge(
    BuildContext context,
    WidgetRef ref,
    Friend friend,
  ) async {
    await ref.read(challengeActionsProvider.notifier).sendChallenge(
          toUserId: friend.friendId,
          toUsername: friend.friendUsername,
        );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Challenge sent to ${friend.friendUsername}')),
      );
    }
  }

  void _confirmRemove(BuildContext context, WidgetRef ref, Friend friend) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Friend?'),
        content: Text('Remove ${friend.friendUsername} from your friends?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(friendActionsProvider.notifier).removeFriend(friend);
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}

class _RequestsTab extends ConsumerWidget {
  const _RequestsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(pendingFriendRequestsProvider);

    return requests.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
      data: (list) {
        if (list.isEmpty) {
          return const Center(child: Text('No pending friend requests'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final request = list[index];
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundImage: request.fromAvatar.isNotEmpty
                      ? NetworkImage(request.fromAvatar)
                      : null,
                  child: request.fromAvatar.isEmpty
                      ? const Icon(Icons.person)
                      : null,
                ),
                title: Text(request.fromUsername),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check_circle, color: Colors.green),
                      tooltip: 'Accept',
                      onPressed: () => ref
                          .read(friendActionsProvider.notifier)
                          .acceptRequest(request),
                    ),
                    IconButton(
                      icon: const Icon(Icons.cancel, color: Colors.red),
                      tooltip: 'Decline',
                      onPressed: () => ref
                          .read(friendActionsProvider.notifier)
                          .rejectRequest(request),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _AddFriendTab extends ConsumerStatefulWidget {
  const _AddFriendTab();

  @override
  ConsumerState<_AddFriendTab> createState() => _AddFriendTabState();
}

class _AddFriendTabState extends ConsumerState<_AddFriendTab> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider).value;
    final results = ref.watch(userSearchProvider(_query));

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              labelText: 'Search by display name',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onSubmitted: (value) => setState(() => _query = value),
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _query.trim().isEmpty
                ? const Center(child: Text('Type a name to search'))
                : results.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, stack) =>
                        Center(child: Text('Error: $error')),
                    data: (users) {
                      final others = users
                          .where((u) => u.uid != currentUser?.uid)
                          .toList();
                      if (others.isEmpty) {
                        return const Center(child: Text('No users found'));
                      }

                      return ListView.separated(
                        itemCount: others.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final user = others[index];
                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundImage: user.photoUrl != null
                                    ? NetworkImage(user.photoUrl!)
                                    : null,
                                child: user.photoUrl == null
                                    ? const Icon(Icons.person)
                                    : null,
                              ),
                              title: Text(user.displayName ?? 'Anonymous'),
                              subtitle: Text('Rating: ${user.rating}'),
                              trailing: FilledButton(
                                onPressed: () {
                                  ref
                                      .read(friendActionsProvider.notifier)
                                      .sendRequest(user);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Friend request sent to ${user.displayName ?? "user"}',
                                      ),
                                    ),
                                  );
                                },
                                child: const Text('Add'),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ActivityFeedTab extends ConsumerWidget {
  const _ActivityFeedTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activity = ref.watch(activityFeedProvider);

    return activity.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
      data: (list) {
        if (list.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No activity yet. Games your friends finish will show up here.',
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final activity = list[index];
            return Card(
              child: ListTile(
                leading: Icon(_iconFor(activity.activityType)),
                title: Text(activity.description),
                subtitle: Text(_timeAgo(activity.timestamp)),
              ),
            );
          },
        );
      },
    );
  }

  IconData _iconFor(String activityType) {
    switch (activityType) {
      case 'win':
        return Icons.emoji_events;
      case 'loss':
        return Icons.sentiment_dissatisfied;
      case 'draw':
        return Icons.handshake;
      default:
        return Icons.info_outline;
    }
  }

  String _timeAgo(DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
