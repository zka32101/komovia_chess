import 'package:flutter/material.dart';

/// Game information panel for displaying game metadata
///
/// Shows detailed game information such as:
/// - Game ID
/// - Game type (Blitz, Rapid, Classical)
/// - Current status
/// - Time control
/// - Total moves played
/// - Time elapsed
class GameInfoPanel extends StatelessWidget {
  const GameInfoPanel({
    required this.gameId,
    required this.gameType,
    required this.status,
    required this.timeControl,
    required this.totalMoves,
    required this.elapsedSeconds,
    required this.whitePlayerName,
    required this.blackPlayerName,
    Key? key,
    this.currentTurn,
  }) : super(key: key);

  /// Unique game identifier
  final String gameId;

  /// Game type (e.g., "Online", "Blitz", "Rapid")
  final String gameType;

  /// Current game status (e.g., "active", "ended", "paused")
  final String status;

  /// Time control setting (e.g., "3+0", "5+3", "15+10")
  final String timeControl;

  /// Total number of moves made
  final int totalMoves;

  /// Time elapsed in seconds
  final int elapsedSeconds;

  /// White player name
  final String whitePlayerName;

  /// Black player name
  final String blackPlayerName;

  /// Current turn player (white or black)
  final String? currentTurn;

  /// Format elapsed time as MM:SS
  String _formatElapsedTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }

  /// Get status color based on game status
  Color _getStatusColor() {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'ended':
      case 'completed':
        return Colors.grey;
      case 'paused':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  /// Get status icon based on game status
  IconData _getStatusIcon() {
    switch (status.toLowerCase()) {
      case 'active':
        return Icons.play_circle_filled;
      case 'ended':
      case 'completed':
        return Icons.check_circle;
      case 'paused':
        return Icons.pause_circle;
      default:
        return Icons.info_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with title and status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Game Information',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Chip(
                  avatar: Icon(
                    _getStatusIcon(),
                    size: 16,
                    color: Colors.white,
                  ),
                  label: Text(
                    status,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                  backgroundColor: _getStatusColor(),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Game details grid
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                _buildInfoCard(
                  context,
                  icon: Icons.category,
                  label: 'Type',
                  value: gameType,
                ),
                _buildInfoCard(
                  context,
                  icon: Icons.schedule,
                  label: 'Time Control',
                  value: timeControl,
                ),
                _buildInfoCard(
                  context,
                  icon: Icons.layers,
                  label: 'Moves',
                  value: totalMoves.toString(),
                ),
                _buildInfoCard(
                  context,
                  icon: Icons.timer,
                  label: 'Elapsed',
                  value: _formatElapsedTime(elapsedSeconds),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Players section
            Text(
              'Players',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            _buildPlayerRow('White', whitePlayerName),
            const SizedBox(height: 8),
            _buildPlayerRow('Black', blackPlayerName),

            if (currentTurn != null) ...[
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.turn_right, size: 16, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(
                      'Turn: $currentTurn',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Game ID (copyable)
            const SizedBox(height: 12),
            _buildGameIdRow(context),
          ],
        ),
      ),
    );
  }

  /// Build info card widget
  Widget _buildInfoCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final cardColor = isDarkMode ? Colors.grey[900] : Colors.grey[50];
    final borderColor = isDarkMode ? Colors.grey[800] : Colors.grey[200];
    final labelColor = isDarkMode ? Colors.grey[400] : Colors.grey[600];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor ?? Colors.grey),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: primaryColor),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: labelColor),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white70 : Colors.black87,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// Build player row
  Widget _buildPlayerRow(String color, String playerName) => Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: color.toLowerCase() == 'white'
                  ? Colors.grey[300]
                  : Colors.grey[800],
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey[400]!),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 50,
            child: Text(
              color,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              playerName,
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );

  /// Build game ID row with copy button
  Widget _buildGameIdRow(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDarkMode ? Colors.grey[900] : Colors.grey[50];
    final borderColor = isDarkMode ? Colors.grey[800] : Colors.grey[200];
    final labelColor = isDarkMode ? Colors.grey[400] : Colors.grey[600];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor ?? Colors.grey),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Game ID',
                style: TextStyle(fontSize: 10, color: labelColor),
              ),
              const SizedBox(height: 2),
              Text(
                gameId,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Courier',
                  color: isDarkMode ? Colors.white70 : Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.content_copy, size: 16),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Game ID copied to clipboard'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            tooltip: 'Copy Game ID',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }
}

/// Compact game info for display in headers
class CompactGameInfo extends StatelessWidget {
  const CompactGameInfo({
    required this.gameType,
    required this.timeControl,
    required this.totalMoves,
    Key? key,
  }) : super(key: key);

  /// Game type
  final String gameType;

  /// Time control
  final String timeControl;

  /// Total moves
  final int totalMoves;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTag(gameType),
          const SizedBox(width: 8),
          _buildTag(timeControl),
          const SizedBox(width: 8),
          _buildTag('Moves: $totalMoves'),
        ],
      );

  /// Build individual tag
  Widget _buildTag(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
}
