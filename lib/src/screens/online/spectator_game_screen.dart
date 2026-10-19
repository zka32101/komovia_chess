import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess/chess.dart' as chess_lib;
import '../../models/online_game.dart';
import '../../providers/online_game_provider.dart';
import '../../providers/user_preferences_provider.dart';
import '../../widgets/game_board.dart';
import '../../widgets/time_clock.dart';

/// Read-only live view of someone else's online PvP game - reuses the same
/// GameBoard widget and currentFen/moves data `OnlineGameScreen` renders
/// for its own participants, but with no `onMove`/`onResign` callbacks at
/// all (GameBoard already treats a null onMove as a non-interactive
/// board), no move-submission or resign/draw actions, and no navigation
/// into OnlineGameResultScreen (its rematch/share actions are meant for a
/// participant, not someone watching).
class SpectatorGameScreen extends ConsumerWidget {
  const SpectatorGameScreen({required this.gameId, Key? key})
      : super(key: key);
  final String gameId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameAsync = ref.watch(onlineGameStreamProvider(gameId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Watching'),
        centerTitle: true,
      ),
      body: gameAsync.when(
        data: (game) {
          if (game == null) {
            return const Center(child: Text('This game no longer exists.'));
          }
          return _buildBoard(context, ref, game);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error watching game: $err')),
      ),
    );
  }

  Widget _buildBoard(BuildContext context, WidgetRef ref, OnlineGame game) {
    try {
      final gameState = chess_lib.Chess.fromFEN(game.currentFen);
      final showCoordinates =
          ref.watch(userPreferencesProvider).value?.showCoordinates ?? true;

      return Column(
        children: [
          PlayerTimeClock(
            playerName: game.blackPlayerName,
            rating: game.blackRating,
            timeMs: game.blackTimeRemainingMs,
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: GameBoard(
                  gameState: gameState,
                  showCoordinates: showCoordinates,
                  showMaterial: true,
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          PlayerTimeClock(
            playerName: game.whitePlayerName,
            rating: game.whiteRating,
            timeMs: game.whiteTimeRemainingMs,
          ),
          if (game.status != 'active') _buildGameOverBanner(game),
        ],
      );
    } catch (e) {
      return Center(child: Text('Error loading board: $e'));
    }
  }

  Widget _buildGameOverBanner(OnlineGame game) {
    final resultText = switch (game.result) {
      'white_win' => '${game.whitePlayerName} won',
      'black_win' => '${game.blackPlayerName} won',
      'draw' => 'Draw',
      _ => 'Game over',
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: Colors.black87,
      child: Text(
        resultText,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
    );
  }
}
