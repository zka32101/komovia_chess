import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/chess_board.dart';
import '../../providers/online_game_provider.dart';
import '../../providers/auth_provider.dart';

class OnlineGameScreen extends ConsumerStatefulWidget {
  const OnlineGameScreen({
    required this.gameId,
    Key? key,
  }) : super(key: key);
  final String gameId;

  @override
  ConsumerState<OnlineGameScreen> createState() => _OnlineGameScreenState();
}

class _OnlineGameScreenState extends ConsumerState<OnlineGameScreen> {
  @override
  Widget build(BuildContext context) {
    final gameStream = ref.watch(onlineGameStreamProvider(widget.gameId));
    final onlineGameState = ref.watch(onlineGameStateProvider(widget.gameId));
    final drawOfferStream = ref.watch(drawOfferStreamProvider(widget.gameId));
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Online Game'),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showGameInfo(context),
          ),
        ],
      ),
      body: gameStream.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $error'),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
        data: (game) {
          if (game == null) {
            return const Center(child: Text('Game not found'));
          }

          final opponentName = currentUser.value?.uid == game.whitePlayerId
              ? game.blackPlayerName
              : game.whitePlayerName;
          final opponentRating = currentUser.value?.uid == game.whitePlayerId
              ? game.blackRating
              : game.whiteRating;

          final isPlayerWhite = currentUser.value?.uid == game.whitePlayerId;
          final isPlayerTurn = isPlayerWhite == (game.moves.length % 2 == 0);

          return SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Opponent card
                    _buildPlayerCard(
                      playerName: opponentName,
                      rating: opponentRating,
                      isTopCard: true,
                      isCurrentTurn: !isPlayerTurn && game.status == 'active',
                    ),
                    const SizedBox(height: 16),

                    // Chess board
                    Center(
                      child: ChessBoard(
                        engine: onlineGameState.engine,
                        size: 350,
                        enabled: isPlayerTurn &&
                            game.status == 'active' &&
                            !onlineGameState.isSyncingMove,
                        onMoveMade: (from, to) async {
                          await ref
                              .read(onlineGameStateProvider(widget.gameId)
                                  .notifier)
                              .makeMove(from, to);
                        },
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Player card
                    _buildPlayerCard(
                      playerName: currentUser.value?.displayName ?? 'You',
                      rating: currentUser.value?.onlineRating ?? 1600,
                      isTopCard: false,
                      isCurrentTurn: isPlayerTurn && game.status == 'active',
                    ),

                    const SizedBox(height: 24),

                    // Draw offer notification
                    drawOfferStream.when(
                      data: (hasDrawOffer) {
                        if (!hasDrawOffer || game.status != 'active') {
                          return const SizedBox.shrink();
                        }

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.1),
                            border: Border.all(
                              color: Colors.amber,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.handshake, color: Colors.amber),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Opponent offered a draw',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                              TextButton(
                                onPressed: () => ref
                                    .read(onlineGameStateProvider(widget.gameId)
                                        .notifier)
                                    .acceptDraw(),
                                child: const Text('Accept'),
                              ),
                              const SizedBox(width: 8),
                              TextButton(
                                onPressed: () async {
                                  final service =
                                      ref.read(onlineGameServiceProvider);
                                  await service.declineDraw(widget.gameId);
                                },
                                child: const Text('Decline'),
                              ),
                            ],
                          ),
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),

                    const SizedBox(height: 16),

                    // Game status
                    if (game.status == 'completed')
                      _buildGameOverCard(game, currentUser.value?.uid ?? '')
                    else
                      _buildGameInfoCard(game, onlineGameState.isSyncingMove),

                    const SizedBox(height: 16),

                    // Error display
                    if (onlineGameState.lastError != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          border: Border.all(color: Colors.red),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Error: ${onlineGameState.lastError}',
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),

                    const SizedBox(height: 16),

                    // Action buttons
                    if (game.status == 'active')
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () =>
                                  _showResignDialog(context, widget.gameId),
                              child: const Text('Resign'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.tonal(
                              onPressed: isPlayerTurn
                                  ? () => ref
                                      .read(
                                          onlineGameStateProvider(widget.gameId)
                                              .notifier)
                                      .offerDraw()
                                  : null,
                              child: const Text('Offer Draw'),
                            ),
                          ),
                        ],
                      )
                    else
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Exit Game'),
                      ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlayerCard({
    required String playerName,
    required int rating,
    required bool isTopCard,
    required bool isCurrentTurn,
  }) =>
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isCurrentTurn ? Colors.blue : Colors.grey.shade300,
            width: isCurrentTurn ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: isCurrentTurn ? Colors.blue.withOpacity(0.05) : null,
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.blue.shade100,
              child: Text(
                playerName.substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    playerName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Rating: $rating',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            if (isCurrentTurn)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Your Turn',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      );

  Widget _buildGameInfoCard(var game, bool isSyncingMove) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Moves',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${(game.moves?.length ?? 0) ~/ 2}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Status',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (isSyncingMove)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      const Text(
                        'Active',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Time Control',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      game.timeControl ?? '5+3',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      );

  Widget _buildGameOverCard(var game, String currentUserId) {
    final result = game.result;
    final reason = game.resultReason;

    String resultText;
    Color resultColor;

    final isPlayerWhite = currentUserId == game.whitePlayerId;
    final playerWon = (isPlayerWhite && result == 'white_win') ||
        (!isPlayerWhite && result == 'black_win');

    if (playerWon) {
      resultText = 'You won!';
      resultColor = Colors.green;
    } else if (result == 'draw') {
      resultText = 'Draw';
      resultColor = Colors.orange;
    } else {
      resultText = 'You lost';
      resultColor = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: resultColor.withOpacity(0.1),
        border: Border.all(color: resultColor.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            resultText,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: resultColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Result: ${reason?.replaceAll('_', ' ').toUpperCase() ?? 'GAME ENDED'}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          if (game.whiteRatingDelta != null)
            Column(
              children: [
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Column(
                      children: [
                        const Text('Rating Change',
                            style: TextStyle(fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(
                          '${isPlayerWhite ? game.whiteRatingDelta : game.blackRatingDelta >= 0 ? '+' : ''}${isPlayerWhite ? game.whiteRatingDelta : game.blackRatingDelta}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: (isPlayerWhite
                                        ? game.whiteRatingDelta
                                        : game.blackRatingDelta) >=
                                    0
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        const Text('New Rating',
                            style: TextStyle(fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(
                          '${isPlayerWhite ? game.whiteNewRating : game.blackNewRating}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }

  void _showGameInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Game Information'),
        content: Text('Game ID: ${widget.gameId}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showResignDialog(BuildContext context, String gameId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resign Game'),
        content: const Text(
            'Are you sure you want to resign? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(onlineGameStateProvider(gameId).notifier).resign();
              Navigator.pop(context);
            },
            child: const Text('Resign'),
          ),
        ],
      ),
    );
  }
}
