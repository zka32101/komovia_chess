import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/game.dart';
import '../../providers/game_provider.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({
    required this.gameId,
    Key? key,
  }) : super(key: key);
  final String gameId;

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  @override
  Widget build(BuildContext context) {
    final gameAsyncValue = ref.watch(gameByIdProvider(widget.gameId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Game'),
        centerTitle: true,
        elevation: 0,
      ),
      body: gameAsyncValue.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading game: $error'),
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
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.search_off, size: 48, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('Game not found'),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            );
          }

          return SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Player info cards
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Black player (top)
                        _buildPlayerCard(
                          playerName: game.blackPlayerName ?? 'Black Player',
                          rating: game.blackRating,
                          timeRemaining: game.blackTimeRemainingMs ?? 0,
                          isTopCard: true,
                        ),
                        const SizedBox(height: 16),

                        // Chess board placeholder
                        Container(
                          width: 350,
                          height: 350,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: GridView.builder(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 8,
                            ),
                            itemCount: 64,
                            itemBuilder: (context, index) {
                              final row = index ~/ 8;
                              final col = index % 8;
                              final isLight = (row + col) % 2 == 0;

                              return Container(
                                color: isLight
                                    ? Colors.amber[100]
                                    : Colors.amber[700],
                                child: const Center(
                                  child: Text(
                                    '', // Pieces would be rendered here
                                    style: TextStyle(fontSize: 24),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 16),

                        // White player (bottom)
                        _buildPlayerCard(
                          playerName: game.whitePlayerName ?? 'White Player',
                          rating: game.whiteRating,
                          timeRemaining: game.whiteTimeRemainingMs ?? 0,
                          isTopCard: false,
                        ),
                      ],
                    ),
                  ),

                  // Game info
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
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
                                  const Text(
                                    'Time Control',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
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
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text(
                                    'Moves',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${game.moves.length}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              if (game.status == 'completed')
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text(
                                      'Result',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      game.result ?? 'N/A',
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
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Action buttons (if game is active)
                  if (game.status == 'active')
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _showGameMenu(context, game),
                              child: const Text('Menu'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: () {
                                // Move is made via chess board tap
                              },
                              child: const Text('In Game'),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 24),
                ],
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
    required int timeRemaining,
    required bool isTopCard,
  }) {
    final hours = timeRemaining ~/ (60 * 60 * 1000);
    final minutes = (timeRemaining ~/ (60 * 1000)) % 60;
    final seconds = (timeRemaining ~/ 1000) % 60;

    String timeString;
    if (hours > 0) {
      timeString =
          '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else if (minutes > 0) {
      timeString = '$minutes:${seconds.toString().padLeft(2, '0')}';
    } else {
      timeString = '${seconds.toString().padLeft(2, '0')}s';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                timeString,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Time',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showGameMenu(BuildContext context, GameModel game) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.flag),
              title: const Text('Resign'),
              onTap: () {
                Navigator.pop(context);
                _resignGame(game.gameId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.handshake),
              title: const Text('Offer Draw'),
              onTap: () {
                Navigator.pop(context);
                _offerDraw(game.gameId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('Game Info'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Show game info dialog
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _resignGame(String gameId) async {
    try {
      await ref.read(gameServiceProvider).resignGame(gameId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You have resigned')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _offerDraw(String gameId) async {
    try {
      await ref.read(gameServiceProvider).offerDraw(gameId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Draw offer sent')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}
