import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_core/komovia_core.dart';
import '../../providers/auth_provider.dart';
import '../../providers/friend_provider.dart';
import '../../providers/challenge_provider.dart';
import '../messages/chat_screen.dart';
import '../../../l10n/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context);

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.friendsTitle),
          centerTitle: true,
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: l10n.friendsTabFriends),
              Tab(
                  text: requestCount > 0
                      ? l10n.friendsTabRequestsWithCount(requestCount)
                      : l10n.friendsTabRequests),
              Tab(text: l10n.friendsTabAddFriend),
              Tab(text: l10n.friendsTabActivity),
              Tab(text: l10n.friendsTabBlocked),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _FriendsListTab(),
            _RequestsTab(),
            _AddFriendTab(),
            _ActivityFeedTab(),
            _BlockedUsersTab(),
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
    final me = ref.watch(currentUserProvider).value;
    final l10n = AppLocalizations.of(context);

    return friends.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) =>
          Center(child: Text(l10n.friendsErrorMessage(error.toString()))),
      data: (list) {
        if (list.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(l10n.friendsNoFriendsYetMessage),
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
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(friend.displayName),
                subtitle:
                    Text(l10n.friendsSinceLabel(_dateLabel(friend.addedAt))),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chat_bubble_outline),
                      tooltip: l10n.friendsMessageTooltip,
                      onPressed: me == null
                          ? null
                          : () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatScreen(
                                    currentUid: me.uid,
                                    currentDisplayName: me.displayName ??
                                        l10n.homePlayerFallbackName,
                                    friendUid: friend.friendUid,
                                    friendDisplayName: friend.displayName,
                                  ),
                                ),
                              ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.bolt_outlined),
                      tooltip: l10n.friendsChallengeTooltip,
                      onPressed: () => _sendChallenge(context, ref, friend, l10n),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'remove') {
                          _confirmRemove(context, ref, friend, l10n);
                        } else if (value == 'block') {
                          _confirmBlock(context, ref, friend, l10n);
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'remove',
                          child: Text(l10n.friendsRemoveFriendMenuItem),
                        ),
                        PopupMenuItem(
                          value: 'block',
                          child: Text(l10n.friendsBlockMenuItem),
                        ),
                      ],
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

  String _dateLabel(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<void> _sendChallenge(
    BuildContext context,
    WidgetRef ref,
    Friendship friend,
    AppLocalizations l10n,
  ) async {
    await ref.read(challengeActionsProvider.notifier).sendChallenge(
          toUserId: friend.friendUid,
          toUsername: friend.displayName,
        );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(l10n.friendsChallengeSentMessage(friend.displayName)),
        ),
      );
    }
  }

  void _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    Friendship friend,
    AppLocalizations l10n,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.friendsRemoveFriendTitle),
        content: Text(
          l10n.friendsRemoveFriendConfirmation(friend.displayName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.friendsCancelButton),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(friendActionsProvider.notifier).removeFriend(friend);
            },
            child: Text(l10n.friendsRemoveButton),
          ),
        ],
      ),
    );
  }

  void _confirmBlock(
    BuildContext context,
    WidgetRef ref,
    Friendship friend,
    AppLocalizations l10n,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.friendsBlockUserTitle),
        content: Text(
          l10n.friendsBlockUserConfirmation(friend.displayName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.friendsCancelButton),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(friendActionsProvider.notifier).blockFriend(friend);
            },
            child: Text(l10n.friendsBlockButton),
          ),
        ],
      ),
    );
  }
}

class _BlockedUsersTab extends ConsumerWidget {
  const _BlockedUsersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocked = ref.watch(blockedUsersProvider);
    final l10n = AppLocalizations.of(context);

    return blocked.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) =>
          Center(child: Text(l10n.friendsErrorMessage(error.toString()))),
      data: (list) {
        if (list.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(l10n.friendsNoBlockedUsersMessage),
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
                leading: const CircleAvatar(child: Icon(Icons.block)),
                title: Text(friend.displayName),
                trailing: TextButton(
                  onPressed: () => ref
                      .read(friendActionsProvider.notifier)
                      .unblockFriend(friend),
                  child: Text(l10n.friendsUnblockButton),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _RequestsTab extends ConsumerWidget {
  const _RequestsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(pendingFriendRequestsProvider);
    final me = ref.watch(currentUserProvider).value;
    final l10n = AppLocalizations.of(context);

    return requests.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) =>
          Center(child: Text(l10n.friendsErrorMessage(error.toString()))),
      data: (list) {
        if (list.isEmpty || me == null) {
          return Center(child: Text(l10n.friendsNoPendingRequestsMessage));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final request = list[index];
            // A request the viewer sent themselves shows "sent" + cancel;
            // one they received shows accept/decline.
            final isOutgoing = request.wasRequestedBy(me.uid);

            return Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(request.displayName),
                subtitle:
                    isOutgoing ? Text(l10n.friendsRequestSentLabel) : null,
                trailing: isOutgoing
                    ? TextButton(
                        onPressed: () => ref
                            .read(friendActionsProvider.notifier)
                            .rejectRequest(request),
                        child: Text(l10n.friendsCancelRequestButton),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.check_circle,
                                color: Colors.green),
                            tooltip: l10n.friendsAcceptTooltip,
                            onPressed: () => ref
                                .read(friendActionsProvider.notifier)
                                .acceptRequest(request),
                          ),
                          IconButton(
                            icon: const Icon(Icons.cancel, color: Colors.red),
                            tooltip: l10n.friendsDeclineTooltip,
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
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              labelText: l10n.friendsSearchByDisplayNameLabel,
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (value) => setState(() => _query = value),
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _query.trim().isEmpty
                ? Center(child: Text(l10n.friendsTypeNameToSearchMessage))
                : results.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, stack) => Center(
                        child:
                            Text(l10n.friendsErrorMessage(error.toString()))),
                    data: (users) {
                      final others = users
                          .where((u) => u.uid != currentUser?.uid)
                          .toList();
                      if (others.isEmpty) {
                        return Center(
                            child: Text(l10n.friendsNoUsersFoundMessage));
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
                              title: Text(user.displayName ??
                                  l10n.friendsAnonymousFallbackName),
                              subtitle:
                                  Text(l10n.friendsRatingLabel(user.rating)),
                              trailing: FilledButton(
                                onPressed: () {
                                  ref
                                      .read(friendActionsProvider.notifier)
                                      .sendRequest(user);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        l10n.friendsRequestSentToMessage(
                                          user.displayName ??
                                              l10n.friendsUserFallbackName,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                                child: Text(l10n.friendsAddButton),
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
    final l10n = AppLocalizations.of(context);

    return activity.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) =>
          Center(child: Text(l10n.friendsErrorMessage(error.toString()))),
      data: (list) {
        if (list.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(l10n.friendsNoActivityYetMessage),
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
                subtitle: Text(_timeAgo(activity.timestamp, l10n)),
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

  String _timeAgo(DateTime timestamp, AppLocalizations l10n) {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 1) return l10n.friendsJustNowLabel;
    if (diff.inHours < 1) return l10n.friendsMinutesAgoLabel(diff.inMinutes);
    if (diff.inDays < 1) return l10n.friendsHoursAgoLabel(diff.inHours);
    return l10n.friendsDaysAgoLabel(diff.inDays);
  }
}
