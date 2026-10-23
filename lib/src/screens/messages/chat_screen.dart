import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/direct_message_provider.dart';
import '../../services/direct_message_service.dart';

/// フレンドとの1対1チャット画面。フレンド一覧からの遷移のみを想定して
/// いるため（通知からの直接遷移は未対応）、名前付きルートではなくウィ
/// ジェット引数で現在/相手のuid・表示名を受け取る。
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({
    super.key,
    required this.currentUid,
    required this.currentDisplayName,
    required this.friendUid,
    required this.friendDisplayName,
  });

  final String currentUid;
  final String currentDisplayName;
  final String friendUid;
  final String friendDisplayName;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  late final String _threadId;

  @override
  void initState() {
    super.initState();
    _threadId = DirectMessageService.threadIdFor(widget.currentUid, widget.friendUid);
    ref.read(markThreadReadProvider)(threadId: _threadId, uid: widget.currentUid);
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final content = _textController.text;
    if (content.trim().isEmpty) return;

    _textController.clear();
    try {
      await ref.read(sendDirectMessageProvider)(
        fromUid: widget.currentUid,
        fromDisplayName: widget.currentDisplayName,
        toUid: widget.friendUid,
        toDisplayName: widget.friendDisplayName,
        content: content,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send message')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(threadMessagesProvider(_threadId));
    // markThreadRead previously only ran once, in initState - a friend
    // sending further messages while this screen stayed open left
    // unreadCount climbing in the background (sendMessage increments it
    // on every new message, unconditionally), so the inbox/notification
    // badge kept showing unread messages for a thread the user was
    // actually looking at. Re-marking read on every new emission from
    // the live messages stream (not every rebuild - ref.listen only
    // fires on an actual state change) keeps it at zero while the
    // screen is open.
    ref.listen(threadMessagesProvider(_threadId), (previous, next) {
      if (next.hasValue) {
        ref.read(markThreadReadProvider)(
          threadId: _threadId,
          uid: widget.currentUid,
        );
      }
    });

    return Scaffold(
      appBar: AppBar(title: Text(widget.friendDisplayName)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: messagesAsync.when(
                data: (messages) {
                  if (messages.isEmpty) {
                    return const Center(child: Text('No messages yet'));
                  }
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_scrollController.hasClients) {
                      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
                    }
                  });
                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final isMine = message.fromUid == widget.currentUid;
                      return _MessageBubble(content: message.content, isMine: isMine);
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('Error: $err')),
              ),
            ),
            _buildInputRow(),
          ],
        ),
      ),
    );
  }

  Widget _buildInputRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              decoration: const InputDecoration(
                hintText: 'Message',
                border: InputBorder.none,
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              minLines: 1,
              maxLines: 4,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: _send,
            tooltip: 'Send',
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.content, required this.isMine});

  final String content;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMine ? theme.colorScheme.primary : theme.cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          content,
          style: TextStyle(
            color: isMine ? theme.colorScheme.onPrimary : null,
          ),
        ),
      ),
    );
  }
}
