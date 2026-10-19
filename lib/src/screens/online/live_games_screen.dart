import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/online_game.dart';
import '../../providers/online_game_provider.dart';
import 'spectator_game_screen.dart';

/// Lists currently-active online PvP games any signed-in user may watch -
/// previously there was no spectator mode in the app at all (confirmed via
/// a repo-wide search for "spectat"): firestore.rules only ever let a
/// game's two participants read it, so there was nothing for a screen
/// like this to even query.
class LiveGamesScreen extends ConsumerWidget {
  const LiveGamesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gamesAsync = ref.watch(liveGamesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Games'),
        centerTitle: true,
      ),
      body: gamesAsync.when(
        data: (games) {
          if (games.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No games are being played right now.\nCheck back soon!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: games.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) =>
                _LiveGameTile(game: games[index]),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading live games: $err')),
      ),
    );
  }
}

class _LiveGameTile extends StatelessWidget {
  const _LiveGameTile({required this.game});
  final OnlineGame game;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: const CircleAvatar(child: Icon(Icons.visibility)),
          title: Text(
            '${game.whitePlayerName} vs ${game.blackPlayerName}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            '${game.whiteRating} vs ${game.blackRating} · '
            '${game.moves.length} moves played',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SpectatorGameScreen(gameId: game.gameId),
              ),
            );
          },
        ),
      );
}
