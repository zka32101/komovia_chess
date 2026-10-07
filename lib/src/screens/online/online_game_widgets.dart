import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/online_game.dart';

/// Widget displaying player presence status
class PlayerPresenceWidget extends ConsumerWidget {
  const PlayerPresenceWidget({
    required this.playerId,
    required this.playerName,
    required this.rating,
    required this.isOnline,
    Key? key,
    this.lastActivityTime,
    this.isCurrentPlayer = false,
  }) : super(key: key);
  final String playerId;
  final String playerName;
  final int rating;
  final bool isOnline;
  final DateTime? lastActivityTime;
  final bool isCurrentPlayer;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isOnline ? Colors.green[300]! : Colors.grey[400]!,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            // Presence indicator dot
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: isOnline ? Colors.green : Colors.grey[400],
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            // Player info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        playerName,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      if (isCurrentPlayer)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue[100],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'You',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: Colors.blue[900],
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                    ],
                  ),
                  Text(
                    'Rating: $rating',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  if (lastActivityTime != null && !isOnline)
                    Text(
                      'Last seen ${_formatTimeAgo(lastActivityTime!)}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Colors.grey[500],
                            fontSize: 10,
                          ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );

  String _formatTimeAgo(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inSeconds < 60) {
      return 'a few seconds ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}

/// Widget displaying matchmaking queue status
class MatchmakingStatusWidget extends ConsumerWidget {
  const MatchmakingStatusWidget({
    required this.queueId,
    required this.position,
    required this.estimatedWaitTime,
    required this.timeControl,
    Key? key,
  }) : super(key: key);
  final String queueId;
  final int position;
  final Duration estimatedWaitTime;
  final String timeControl;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue[200]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Searching for opponent...',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.blue[900],
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildStatusRow(context, 'Queue Position', '#$position'),
            _buildStatusRow(context, 'Time Control', timeControl),
            _buildStatusRow(
              context,
              'Est. Wait Time',
              _formatDuration(estimatedWaitTime),
            ),
          ],
        ),
      );

  Widget _buildStatusRow(BuildContext context, String label, String value) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.blue[900],
                  ),
            ),
          ],
        ),
      );

  String _formatDuration(Duration duration) {
    if (duration.inSeconds < 60) {
      return '${duration.inSeconds}s';
    } else if (duration.inMinutes < 60) {
      return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
    } else {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    }
  }
}

/// Widget displaying game info in a dialog or bottom sheet
class GameInfoWidget extends StatelessWidget {
  const GameInfoWidget({
    required this.game,
    Key? key,
    this.onMove,
    this.onResign,
    this.onDrawOffer,
  }) : super(key: key);
  final OnlineGame game;
  final VoidCallback? onMove;
  final VoidCallback? onResign;
  final VoidCallback? onDrawOffer;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 24),
            _buildGameInfo(context),
            const SizedBox(height: 24),
            _buildPlayerStats(context),
            if (game.status == 'active') ...[
              const SizedBox(height: 24),
              _buildActionButtons(context),
            ],
          ],
        ),
      );

  Widget _buildHeader(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Game Information',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getStatusColor(game.status).withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              game.status.replaceAll('_', ' ').toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: _getStatusColor(game.status),
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      );

  Widget _buildGameInfo(BuildContext context) {
    final duration = game.endedAt?.difference(game.startedAt ?? game.createdAt);
    final durationText = duration != null
        ? '${duration.inMinutes}m ${duration.inSeconds % 60}s'
        : 'Ongoing';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          _buildInfoRow('Game ID', game.gameId, context),
          _buildInfoRow('Type', game.type, context),
          _buildInfoRow('Time Control', game.timeControl, context),
          _buildInfoRow('Total Moves', '${game.moves.length}', context),
          _buildInfoRow('Duration', durationText, context),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, BuildContext context) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );

  Widget _buildPlayerStats(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Player Ratings',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildPlayerCard(
                  context,
                  game.whitePlayerName,
                  game.whiteRating,
                  'White',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPlayerCard(
                  context,
                  game.blackPlayerName,
                  game.blackRating,
                  'Black',
                ),
              ),
            ],
          ),
        ],
      );

  Widget _buildPlayerCard(
    BuildContext context,
    String name,
    int rating,
    String color,
  ) =>
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              color,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              name,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              '$rating elo',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.blue[700],
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      );

  Widget _buildActionButtons(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (onDrawOffer != null)
            ElevatedButton(
              onPressed: onDrawOffer,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.white,
              ),
              child: const Text('Offer Draw'),
            ),
          const SizedBox(height: 8),
          if (onResign != null)
            ElevatedButton(
              onPressed: onResign,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Resign Game'),
            ),
        ],
      );

  Color _getStatusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      case 'abandoned':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

/// Move history widget
class MoveHistoryWidget extends StatelessWidget {
  const MoveHistoryWidget({
    required this.moves,
    Key? key,
  }) : super(key: key);
  final List<GameMove> moves;

  @override
  Widget build(BuildContext context) {
    if (moves.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No moves yet',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: (moves.length / 2).ceil(),
      itemBuilder: (context, index) {
        final moveNumber = index + 1;
        final whiteMove = moves.length > index * 2 ? moves[index * 2] : null;
        final blackMove =
            moves.length > index * 2 + 1 ? moves[index * 2 + 1] : null;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 32,
                alignment: Alignment.center,
                child: Text(
                  '$moveNumber.',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              Expanded(
                child: _buildMoveChip(context, whiteMove),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMoveChip(context, blackMove),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMoveChip(BuildContext context, GameMove? move) {
    if (move == null) {
      return const SizedBox();
    }

    final moveStr = move.promotion != null
        ? '${move.from}${move.to}=${move.promotion}'
        : '${move.from}${move.to}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        moveStr,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
