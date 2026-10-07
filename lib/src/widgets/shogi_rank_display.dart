import 'package:flutter/material.dart';
import '../services/shogi_rank_service.dart';

/// Displays a player's shogi rank with visual styling
class ShogiRankDisplay extends StatelessWidget {
  const ShogiRankDisplay({
    required this.rank,
    required this.eloRating,
    Key? key,
    this.compact = false,
    this.textStyle,
  }) : super(key: key);
  final ShogiRank rank;
  final int eloRating;
  final bool compact;
  final TextStyle? textStyle;

  Color _getRankColor() => rank.when(
        dan: (level) {
          // Dan色の濃淡でレベルを表現
          switch (level) {
            case 8:
              return const Color(0xFFFFD700); // Gold
            case 7:
              return const Color(0xFFC0C0C0); // Silver
            case 6:
              return const Color(0xFFCD7F32); // Bronze
            case 5:
            case 4:
              return const Color(0xFF6A4C93); // Purple
            case 3:
            case 2:
              return const Color(0xFF1982C4); // Blue
            default:
              return const Color(0xFF8AC926); // Green
          }
        },
        kyu: (level) {
          // 級の色: グリーン系
          if (level <= 3) {
            return const Color(0xFF52B788); // Dark green
          } else if (level <= 10) {
            return const Color(0xFF74C69D); // Medium green
          } else {
            return const Color(0xFFB7E4C7); // Light green
          }
        },
      );

  Widget _buildRankBadge(BuildContext context) {
    final color = _getRankColor();
    final displayName = ShogiRankService.displayName(rank);

    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          border: Border.all(color: color, width: 1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          displayName,
          style: textStyle ??
              TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: color,
              ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withOpacity(0.3), color.withOpacity(0.1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: color, width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              displayName,
              style: textStyle ??
                  TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                    color: color,
                  ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          ShogiRankService.getDescription(rank),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => _buildRankBadge(context);
}

/// Displays rank progression bar
class ShogiRankProgressBar extends StatelessWidget {
  const ShogiRankProgressBar({
    required this.currentRank,
    required this.eloRating,
    Key? key,
    this.showLabel = true,
  }) : super(key: key);
  final ShogiRank currentRank;
  final int eloRating;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final progress =
        ShogiRankService.progressToNextRank(eloRating, currentRank);
    final currentRankName = ShogiRankService.displayName(currentRank);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabel) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '段位進度',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Text(
                currentRankName,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: Colors.grey.withOpacity(0.3),
            valueColor: AlwaysStoppedAnimation<Color>(
              _getProgressColor(currentRank),
            ),
          ),
        ),
        if (showLabel) ...[
          const SizedBox(height: 4),
          Text(
            '${(progress * 100).toStringAsFixed(0)}% 次のランクまで',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }

  Color _getProgressColor(ShogiRank rank) => rank.when(
        dan: (level) {
          switch (level) {
            case 8:
              return const Color(0xFFFFD700);
            case 7:
              return const Color(0xFFC0C0C0);
            case 6:
              return const Color(0xFFCD7F32);
            case 5:
            case 4:
              return const Color(0xFF6A4C93);
            case 3:
            case 2:
              return const Color(0xFF1982C4);
            default:
              return const Color(0xFF8AC926);
          }
        },
        kyu: (level) {
          if (level <= 3) {
            return const Color(0xFF52B788);
          } else if (level <= 10) {
            return const Color(0xFF74C69D);
          } else {
            return const Color(0xFFB7E4C7);
          }
        },
      );
}

/// Displays rank comparison between two players
class ShogiRankComparison extends StatelessWidget {
  const ShogiRankComparison({
    required this.player1Name,
    required this.player1Rank,
    required this.player2Name,
    required this.player2Rank,
    Key? key,
  }) : super(key: key);
  final String player1Name;
  final ShogiRank player1Rank;
  final String player2Name;
  final ShogiRank player2Rank;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(
            child: Column(
              children: [
                Text(
                  player1Name,
                  style: Theme.of(context).textTheme.titleSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        ShogiRankService.displayName(player1Rank),
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ShogiRankService.getDescription(player1Rank),
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'vs',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  player2Name,
                  style: Theme.of(context).textTheme.titleSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        ShogiRankService.displayName(player2Rank),
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ShogiRankService.getDescription(player2Rank),
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      );
}
