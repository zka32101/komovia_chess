import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../providers/direct_message_provider.dart';
import 'chat_screen.dart';

/// メッセージスレッド一覧（受信箱）。フレンド一覧の「メッセージ」から
/// 既存/新規の会話に入る方式を主としているため、ここに新規会話を開始する
/// ボタンは置いていない。
class MessageThreadsScreen extends ConsumerWidget {
  const MessageThreadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: currentUser == null
          ? const Center(child: Text('Please sign in'))
          : _buildThreadList(context, ref, currentUser.uid, currentUser.displayName ?? 'Player'),
    );
  }

  Widget _buildThreadList(
    BuildContext context,
    WidgetRef ref,
    String uid,
    String displayName,
  ) {
    final threadsAsync = ref.watch(messageThreadsProvider(uid));

    return threadsAsync.when(
      data: (threads) {
        if (threads.isEmpty) {
          return const Center(child: Text('No conversations yet'));
        }

        return ListView.separated(
          itemCount: threads.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final thread = threads[index];
            final otherUid = thread.otherUidFor(uid);
            final otherName = thread.otherDisplayNameFor(uid);
            final unread = thread.unreadCountFor(uid);

            return ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(otherName),
              subtitle: Text(
                thread.lastMessage ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: unread > 0
                  ? Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                      child: Text(
                        unread > 9 ? '9+' : '$unread',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  : null,
              onTap: () {
                if (otherUid.isEmpty) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      currentUid: uid,
                      currentDisplayName: displayName,
                      friendUid: otherUid,
                      friendDisplayName: otherName,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Could not load messages: $err')),
    );
  }
}
