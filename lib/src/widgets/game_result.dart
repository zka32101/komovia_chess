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
    this.onShare,
    this.isSharing = false,
  }) : super(key: key);
  final String result; // 'white_win', 'black_win', or 'draw'
  final String method; // 'checkmate', 'resignation', 'stalemate', 'timeout'
  final int moves;
  final Duration duration;
  final Function()? onAnalyze;
  final Function()? onNewGame;
  final Function()? onHome;

  /// Generates a move-by-move GIF of the finished game and opens the share
  /// sheet (X/Twitter among the targets). Omitted when the caller has no
  /// move list to replay (e.g. an online game screen that hasn't been
  /// wired up for this yet).
  final Function()? onShare;

  /// True while a share is being generated, so the button can show a
  /// spinner instead of letting a slow GIF encode look like a dead tap.
  final bool isSharing;

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

  // Previously fell through to '' (no text at all) for every reason
  // beyond these original 4 - callers across the app produce several
  // more real values (cpu_game_provider.dart's 'draw_agreement' and,
  // since this pass, 'insufficient_material'/'fifty_move_rule'/
  // 'threefold_repetition'; online_game_service.dart's 'abandonment'/
  // 'abandonment_forfeit'), so a result dialog for any of those showed
  // the title/icon with a silently blank subtitle underneath.
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
      case 'draw_agreement':
        return 'by Agreement';
      case 'insufficient_material':
        return 'by Insufficient Material';
      case 'fifty_move_rule':
        return 'by 50-Move Rule';
      case 'threefold_repetition':
        return 'by Threefold Repetition';
      case 'abandonment':
      case 'abandonment_forfeit':
        return 'by Abandonment';
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

              // Action buttons - New Game is the single most-likely next
              // action (a rematch), so it leads as the one filled/
              // prominent button; Share/Analyze are secondary and
              // de-emphasized (outlined, smaller) rather than visually
              // competing with it one-for-one; Home is the least likely
              // action right after a game ends, so it's last and plain.
              // Previously all 4 buttons had equal visual weight in the
              // same order every time, giving the player no hint about
              // which action is actually the common path.
              if (isMobile)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (onNewGame != null)
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: onNewGame,
                          icon: const Icon(Icons.refresh),
                          label: const Text('New Game'),
                        ),
                      ),
                    if (onShare != null || onAnalyze != null)
                      const SizedBox(height: 12),
                    if (onShare != null || onAnalyze != null)
                      Row(
                        children: [
                          if (onShare != null)
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: isSharing ? null : onShare,
                                icon: isSharing
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      )
                                    : const Icon(Icons.ios_share, size: 18),
                                label: Text(
                                    isSharing ? 'Sharing...' : 'Share on X'),
                              ),
                            ),
                          if (onShare != null && onAnalyze != null)
                            const SizedBox(width: 8),
                          if (onAnalyze != null)
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: onAnalyze,
                                icon: const Icon(Icons.analytics, size: 18),
                                label: const Text('Analyze'),
                              ),
                            ),
                        ],
                      ),
                    if (onHome != null) const SizedBox(height: 8),
                    if (onHome != null)
                      SizedBox(
                        width: double.infinity,
                        child: TextButton.icon(
                          onPressed: onHome,
                          icon: const Icon(Icons.home),
                          label: const Text('Home'),
                        ),
                      ),
                  ],
                )
              else
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (onNewGame != null)
                      FilledButton.icon(
                        onPressed: onNewGame,
                        icon: const Icon(Icons.refresh),
                        label: const Text('New Game'),
                      ),
                    if (onNewGame != null) const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (onShare != null)
                          OutlinedButton.icon(
                            onPressed: isSharing ? null : onShare,
                            icon: isSharing
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.ios_share, size: 18),
                            label: Text(
                                isSharing ? 'Sharing...' : 'Share on X'),
                          ),
                        if (onShare != null && onAnalyze != null)
                          const SizedBox(width: 12),
                        if (onAnalyze != null)
                          OutlinedButton.icon(
                            onPressed: onAnalyze,
                            icon: const Icon(Icons.analytics, size: 18),
                            label: const Text('Analyze'),
                          ),
                        if (onHome != null &&
                            (onShare != null || onAnalyze != null))
                          const SizedBox(width: 12),
                        if (onHome != null)
                          TextButton.icon(
                            onPressed: onHome,
                            icon: const Icon(Icons.home),
                            label: const Text('Home'),
                          ),
                      ],
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
