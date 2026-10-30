import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/repertoire_line.dart';
import '../../providers/auth_provider.dart';
import '../../providers/repertoire_provider.dart';
import '../../services/repertoire_scheduler.dart';
import '../../utils/move_sequence_parser.dart';
import 'repertoire_review_screen.dart';

/// Repertoire management: lists every line the player has saved, shows
/// each one's current Leitner box/due state, lets them add a new line
/// (name + side + pasted move sequence), and starts a review session over
/// whichever lines are currently due - the entry point for the
/// spaced-repetition opening trainer, alongside (not replacing)
/// `OpeningExplorerScreen`'s own-games statistics browser.
class RepertoireScreen extends ConsumerWidget {
  const RepertoireScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('オープニング・レパートリー'),
        actions: [
          if (user != null)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: '新しいレパートリーを追加',
              onPressed: () => _showAddDialog(context, ref, user.uid),
            ),
        ],
      ),
      body: user == null
          ? const Center(child: Text('ログインしてください'))
          : _buildBody(context, ref, user.uid),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, String uid) {
    final linesAsync = ref.watch(repertoireLinesProvider(uid));

    return linesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('読み込みに失敗しました: $e')),
      data: (lines) {
        final now = DateTime.now();
        final dueCount =
            lines.where((l) => RepertoireScheduler.isDue(l.dueAt, now)).length;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: dueCount == 0
                      ? null
                      : () async {
                          final due = await ref
                              .read(repertoireServiceProvider)
                              .getDueLines(uid);
                          if (!context.mounted) return;
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => RepertoireReviewScreen(
                                uid: uid,
                                lines: due,
                              ),
                            ),
                          );
                          ref.invalidate(repertoireLinesProvider(uid));
                        },
                  icon: const Icon(Icons.quiz_outlined),
                  label: Text(
                    dueCount == 0
                        ? '復習するレパートリーはありません'
                        : '復習する（$dueCount件）',
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: lines.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'まだレパートリーがありません。右上の「＋」から、'
                          '覚えたいオープニングの手順を追加しましょう。',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: lines.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) =>
                          _buildLineTile(context, ref, uid, lines[index]),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLineTile(
    BuildContext context,
    WidgetRef ref,
    String uid,
    RepertoireLine line,
  ) {
    final due = RepertoireScheduler.isDue(line.dueAt, DateTime.now());
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: line.playerIsWhite ? Colors.grey.shade200 : Colors.black87,
          child: Icon(
            Icons.circle,
            color: line.playerIsWhite ? Colors.black87 : Colors.white,
            size: 14,
          ),
        ),
        title: Text(line.name),
        subtitle: Text(
          '${line.playerIsWhite ? "白番" : "黒番"} · ${line.moveUcis.length}手 · '
          'Box ${line.box}/${RepertoireScheduler.maxBox}'
          '${due ? " · 復習可能" : " · ${_formatDueDate(line.dueAt)}まで待機"}',
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: '削除',
          onPressed: () async {
            await ref
                .read(repertoireServiceProvider)
                .deleteLine(uid, line.id);
            ref.invalidate(repertoireLinesProvider(uid));
          },
        ),
      ),
    );
  }

  String _formatDueDate(DateTime date) =>
      '${date.year}/${date.month}/${date.day}';

  void _showAddDialog(BuildContext context, WidgetRef ref, String uid) {
    final nameController = TextEditingController();
    final movesController = TextEditingController();
    bool playerIsWhite = true;
    String? errorMessage;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: const Text('レパートリーを追加'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: '名前（例: シシリアン・ドラゴン）',
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('学習する側: '),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('白番'),
                      selected: playerIsWhite,
                      onSelected: (_) => setState(() => playerIsWhite = true),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('黒番'),
                      selected: !playerIsWhite,
                      onSelected: (_) => setState(() => playerIsWhite = false),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: movesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: '手順',
                    hintText: '1. e4 c5 2. Nf3 d6 3. d4 cxd4 ...',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  setState(() => errorMessage = '名前を入力してください。');
                  return;
                }
                List<String> moveUcis;
                try {
                  moveUcis = parseMoveSequenceToUci(movesController.text);
                } on MoveSequenceParseException catch (e) {
                  setState(() => errorMessage = e.message);
                  return;
                }

                await ref.read(repertoireServiceProvider).addLine(
                      uid: uid,
                      name: name,
                      playerIsWhite: playerIsWhite,
                      moveUcis: moveUcis,
                    );
                ref.invalidate(repertoireLinesProvider(uid));
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              },
              child: const Text('追加'),
            ),
          ],
        ),
      ),
    );
  }
}
