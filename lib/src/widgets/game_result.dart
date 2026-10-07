import 'package:flutter/material.dart';

/// Game result display with statistics
class GameResult extends StatelessWidget {
  const GameResult({
    required this.result,
    required this.method,
    required this.moves,
    required this.duration,
    Key? key,
    this.onAnalyze,
    this.onNewGame,
    this.onHome,
  }) : super(key: key);
  final String result; // 'white_win', 'black_win', or 'draw'
  final String method; // 'checkmate', 'resignation', 'stalemate', 'timeout'
  final int moves;
  final Duration duration;
  final Function()? onAnalyze;
  final Function()? onNewGame;
  final Function()? onHome;

  String _getResultTitle() {
    switch (result) {
      case 'white_win':
        return 'White Wins!';
      case 'black_win':
        return 'Black Wins!';
      case 'draw':
        return 'Draw';
      default:
        return 'Game Over';
    }
  }

  String _getResultIcon() {
    switch (result) {
      case 'white_win':
      case 'black_win':
        return '👑';
      case 'draw':
        return '🤝';
      default:
        return '🏁';
    }
  }

  String _getMethodDescription() {
    switch (method) {
      case 'checkmate':
        return 'by Checkmate';
      case 'resignation':
        return 'by Resignation';
      case 'stalemate':
        return 'by Stalemate';
      case 'timeout':
        return 'by Timeout';
      default:
        return '';
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    if (minutes == 0) {
      return '${seconds}s';
    }
    return '${minutes}m ${seconds}s';
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Result icon
              Text(
                _getResultIcon(),
                style: const TextStyle(fontSize: 64),
              ),

              const SizedBox(height: 16),

              // Result title
              Text(
                _getResultTitle(),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),

              const SizedBox(height: 8),

              // Result method
              Text(
                _getMethodDescription(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey,
                    ),
              ),

              const SizedBox(height: 32),

              // Statistics
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Moves:',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        Text(
                          '$moves',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Duration:',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        Text(
                          _formatDuration(duration),
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Action buttons
              if (isMobile)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (onAnalyze != null)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: onAnalyze,
                          icon: const Icon(Icons.analytics),
                          label: const Text('Analyze Game'),
                        ),
                      ),
                    const SizedBox(height: 8),
                    if (onNewGame != null)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: onNewGame,
                          icon: const Icon(Icons.refresh),
                          label: const Text('New Game'),
                        ),
                      ),
                    const SizedBox(height: 8),
                    if (onHome != null)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: onHome,
                          icon: const Icon(Icons.home),
                          label: const Text('Home'),
                        ),
                      ),
                  ],
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    if (onAnalyze != null)
                      ElevatedButton.icon(
                        onPressed: onAnalyze,
                        icon: const Icon(Icons.analytics),
                        label: const Text('Analyze'),
                      ),
                    if (onNewGame != null)
                      ElevatedButton.icon(
                        onPressed: onNewGame,
                        icon: const Icon(Icons.refresh),
                        label: const Text('New Game'),
                      ),
                    if (onHome != null)
                      OutlinedButton.icon(
                        onPressed: onHome,
                        icon: const Icon(Icons.home),
                        label: const Text('Home'),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
