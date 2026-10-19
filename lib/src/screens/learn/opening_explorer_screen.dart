import 'package:chess/chess.dart' as chess_lib;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../providers/opening_explorer_provider.dart';
import '../../services/opening_explorer_service.dart';
import '../../widgets/game_board.dart';

/// Personal opening explorer - browses the position tree built from the
/// signed-in player's own past games (see OpeningExplorerService's doc
/// comment for why this is personal rather than a global/masters
/// database), showing how often each continuation was played from here
/// and how those games turned out.
class OpeningExplorerScreen extends ConsumerStatefulWidget {
  const OpeningExplorerScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<OpeningExplorerScreen> createState() =>
      _OpeningExplorerScreenState();
}

class _OpeningExplorerScreenState
    extends ConsumerState<OpeningExplorerScreen> {
  final _path = <String>[];

  void _playMove(String token) {
    setState(() => _path.add(token));
  }

  void _goBack() {
    if (_path.isEmpty) return;
    setState(() => _path.removeLast());
  }

  void _reset() {
    setState(_path.clear);
  }

  chess_lib.Chess _replayPath() {
    final chess = chess_lib.Chess();
    for (final token in _path) {
      final withoutPromotion = token.split('=').first;
      final promotion = token.contains('=') ? token.split('=').last : null;
      if (withoutPromotion.length < 4) continue;
      chess.move({
        'from': withoutPromotion.substring(0, 2),
        'to': withoutPromotion.substring(2, 4),
        if (promotion != null) 'promotion': promotion,
      });
    }
    return chess;
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('マイオープニング統計'),
        actions: [
          if (_path.isNotEmpty)
            TextButton(
              onPressed: _reset,
              child: const Text(
                '最初から',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: user == null
          ? const Center(child: Text('ログインしてください'))
          : _buildBody(user.uid),
    );
  }

  Widget _buildBody(String uid) {
    final gamesAsync = ref.watch(userOpeningGamesProvider(uid));

    return gamesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('読み込みに失敗しました: $e')),
      data: (games) {
        if (games.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                '対局データがありません。対局をプレイすると、ここに自分のオープニング傾向が'
                '表示されるようになります。',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final service = ref.read(openingExplorerServiceProvider);
        final candidates = service.getCandidateMoves(games, _path);
        final chess = _replayPath();

        return Column(
          children: [
            if (_path.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: _goBack,
                      tooltip: '一手戻る',
                    ),
                    Expanded(
                      child: Text(
                        _path.join(' '),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              flex: 4,
              child: SingleChildScrollView(
                child: GameBoard(
                  gameState: chess,
                  showMaterial: false,
                  isPlayerTurn: false,
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              flex: 3,
              child: candidates.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('この局面より先の対局データはありません。'),
                      ),
                    )
                  : ListView.builder(
                      itemCount: candidates.length,
                      itemBuilder: (context, index) =>
                          _buildCandidateTile(candidates[index]),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCandidateTile(OpeningMoveStat stat) => ListTile(
        title: Text(_formatMove(stat.move)),
        subtitle: Text(
          '${stat.games}局 - 勝${stat.wins} 分${stat.draws} 負${stat.losses}',
        ),
        trailing: Text(
          '${(stat.winRate * 100).toStringAsFixed(0)}%',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        onTap: () => _playMove(stat.move),
      );

  String _formatMove(String token) {
    final withoutPromotion = token.split('=').first;
    if (withoutPromotion.length < 4) return token;
    final from = withoutPromotion.substring(0, 2);
    final to = withoutPromotion.substring(2, 4);
    final promotion = token.contains('=') ? token.split('=').last : null;
    return promotion == null
        ? '$from → $to'
        : '$from → $to (=${promotion.toUpperCase()})';
  }
}
