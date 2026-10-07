import 'package:flutter/material.dart';

/// Game Analysis Bar Widget
///
/// Displays real-time position evaluation and engine statistics during gameplay.
/// Shows:
/// - Evaluation score (negative = black advantage, positive = white advantage)
/// - Zobrist cache efficiency
/// - Nodes evaluated
/// - Search depth achieved
class GameAnalysisBar extends StatelessWidget {
  const GameAnalysisBar({
    required this.stats,
    Key? key,
    this.detailed = false,
    this.onTapDetails,
  }) : super(key: key);

  /// Engine statistics from AIOpponentEngineEnhanced.getSearchStats()
  final Map<String, dynamic> stats;

  /// Whether to show detailed statistics or compact view
  final bool detailed;

  /// Callback when user taps for more details
  final VoidCallback? onTapDetails;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GestureDetector(
        onTap: onTapDetails,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: detailed ? _buildDetailed(context) : _buildCompact(context),
        ),
      ),
    );
  }

  Widget _buildCompact(BuildContext context) {
    final depth = stats['depth'] as int? ?? 0;
    final nodes = stats['nodesEvaluated'] as int? ?? 0;
    final hitRate = stats['zobristHitRate'] as String? ?? '0.0';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Analysis',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Depth: $depth | Nodes: ${_formatNumber(nodes)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        Chip(
          label: Text('Cache: $hitRate%'),
          backgroundColor:
              _getCacheQualityColor(_parseDouble(hitRate), context),
          labelStyle: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildDetailed(BuildContext context) {
    final depth = stats['depth'] as int? ?? 0;
    final nodes = stats['nodesEvaluated'] as int? ?? 0;
    final difficulty = stats['difficulty'] as String? ?? 'Medium';
    final zobristHits = stats['zobristHits'] as int? ?? 0;
    final zobristMisses = stats['zobristMisses'] as int? ?? 0;
    final zobristHitRate = stats['zobristHitRate'] as String? ?? '0.0';

    final adaptive = stats['adaptiveSettings'] as Map?;
    final killerStats = stats['killerStats'] as Map?;
    final countermoveStats = stats['countermoveStats'] as Map?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Main metrics row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildMetricTile('Depth', '$depth', Colors.blue),
            _buildMetricTile('Nodes', _formatNumber(nodes), Colors.green),
            _buildMetricTile('Difficulty', difficulty, Colors.orange),
          ],
        ),
        const Divider(height: 16),

        // Cache performance
        Text(
          'Cache Performance',
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(height: 8),
        _buildCacheBar(zobristHits, zobristMisses),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Hit Rate: $zobristHitRate%',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              'Hits: $zobristHits | Misses: $zobristMisses',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const Divider(height: 16),

        // Heuristic stats
        if (killerStats != null || countermoveStats != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Heuristic Effectiveness',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 8),
              if (killerStats != null)
                Text(
                  '• Killer Moves: ${killerStats['totalCutoffs'] ?? 0} cutoffs',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              if (countermoveStats != null)
                Text(
                  '• Countermoves: ${countermoveStats['totalCutoffs'] ?? 0} cutoffs',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),

        // Adaptive settings
        if (adaptive != null) ...[
          const Divider(height: 16),
          Text(
            'Adaptive Settings',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '• Time Remaining: ${adaptive['timeRemaining']}ms',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Text(
            '• Position Phase: ${_getPhaseLabel(adaptive['positionPhase'] as int? ?? 0)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }

  Widget _buildMetricTile(String label, String value, Color color) => Expanded(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
      );

  Widget _buildCacheBar(int hits, int misses) {
    final total = hits + misses;
    if (total == 0) return const SizedBox.shrink();

    final hitPercentage = hits / total;

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Row(
        children: [
          Expanded(
            flex: (hitPercentage * 100).toInt(),
            child: Container(
              height: 20,
              color: Colors.green.shade400,
            ),
          ),
          Expanded(
            flex: 100 - (hitPercentage * 100).toInt(),
            child: Container(
              height: 20,
              color: Colors.red.shade300,
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }

  double _parseDouble(String value) {
    try {
      return double.parse(value);
    } catch (e) {
      return 0;
    }
  }

  Color _getCacheQualityColor(double hitRate, BuildContext context) {
    if (hitRate >= 80) {
      return Colors.green.withOpacity(0.3);
    } else if (hitRate >= 50) {
      return Colors.yellow.withOpacity(0.3);
    } else {
      return Colors.red.withOpacity(0.3);
    }
  }

  String _getPhaseLabel(int phase) {
    switch (phase) {
      case 0:
        return 'Opening';
      case 1:
        return 'Midgame';
      case 2:
        return 'Endgame';
      default:
        return 'Unknown';
    }
  }
}

/// Evaluation Bar Widget
///
/// Shows position evaluation as a visual bar.
/// Negative values = black advantage, Positive = white advantage
class EvaluationBar extends StatelessWidget {
  const EvaluationBar({
    required this.evaluation,
    Key? key,
    this.maxEvaluation = 500,
    this.showValue = true,
  }) : super(key: key);

  /// Evaluation score from position evaluator
  /// Typical range: -500 to +500 (centipawns)
  final int evaluation;

  /// Maximum evaluation value for scaling
  final int maxEvaluation;

  /// Whether to show numeric value
  final bool showValue;

  @override
  Widget build(BuildContext context) {
    // Normalize evaluation to 0-1 range where 0.5 = equal position
    final normalized =
        evaluation.clamp(-maxEvaluation, maxEvaluation) / (maxEvaluation * 2) +
            0.5;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 30,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Row(
              children: [
                // Black advantage bar
                Expanded(
                  flex: ((1 - normalized) * 100).toInt(),
                  child: Container(
                    color: Colors.grey[800],
                  ),
                ),
                // White advantage bar
                Expanded(
                  flex: (normalized * 100).toInt(),
                  child: Container(
                    color: Colors.grey[200],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (showValue)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              evaluation > 0 ? '+$evaluation' : '$evaluation',
              style: TextStyle(
                fontSize: 12,
                color: evaluation > 0 ? Colors.grey[200] : Colors.grey[800],
              ),
            ),
          ),
      ],
    );
  }
}

/// Statistics Dashboard Widget
///
/// Comprehensive display of engine statistics for game analysis
class StatisticsDashboard extends StatelessWidget {
  const StatisticsDashboard({
    required this.stats,
    required this.tableStats,
    Key? key,
  }) : super(key: key);

  /// Engine statistics from AIOpponentEngineEnhanced.getSearchStats()
  final Map<String, dynamic> stats;

  /// Transposition table statistics from AIOpponentEngineEnhanced.getTableStats()
  final Map<String, dynamic> tableStats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Performance'),
              Tab(text: 'Cache'),
              Tab(text: 'Heuristics'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildPerformanceTab(context),
                _buildCacheTab(context),
                _buildHeuristicsTab(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceTab(BuildContext context) {
    final depth = stats['depth'] as int? ?? 0;
    final nodes = stats['nodesEvaluated'] as int? ?? 0;
    final difficulty = stats['difficulty'] as String? ?? 'Medium';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildStatItem(context, 'Search Depth', '$depth'),
        _buildStatItem(context, 'Nodes Evaluated', _formatNumber(nodes)),
        _buildStatItem(context, 'Difficulty Level', difficulty),
        const Divider(),
        if (tableStats.isNotEmpty)
          _buildStatItem(
            context,
            'TT Entries',
            _formatNumber(tableStats['entries'] as int? ?? 0),
          ),
      ],
    );
  }

  Widget _buildCacheTab(BuildContext context) {
    final zobristHits = stats['zobristHits'] as int? ?? 0;
    final zobristMisses = stats['zobristMisses'] as int? ?? 0;
    final zobristHitRate = stats['zobristHitRate'] as String? ?? '0.0';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildStatItem(context, 'Zobrist Hits', zobristHits.toString()),
        _buildStatItem(context, 'Zobrist Misses', zobristMisses.toString()),
        _buildStatItem(context, 'Hit Rate', '$zobristHitRate%'),
        const Divider(),
        if (tableStats.isNotEmpty) ...[
          _buildStatItem(
            context,
            'Table Fills',
            _formatNumber(tableStats['fills'] as int? ?? 0),
          ),
        ],
      ],
    );
  }

  Widget _buildHeuristicsTab(BuildContext context) {
    final killerStats = stats['killerStats'] as Map?;
    final countermoveStats = stats['countermoveStats'] as Map?;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (killerStats != null) ...[
          Text(
            'Killer Move Heuristic',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          _buildStatItem(
            context,
            'Total Cutoffs',
            (killerStats['totalCutoffs'] ?? 0).toString(),
          ),
          _buildStatItem(
            context,
            'Total Killers',
            (killerStats['totalKillers'] ?? 0).toString(),
          ),
          const Divider(),
        ],
        if (countermoveStats != null) ...[
          Text(
            'Countermove Heuristic',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          _buildStatItem(
            context,
            'Total Cutoffs',
            (countermoveStats['totalCutoffs'] ?? 0).toString(),
          ),
          _buildStatItem(
            context,
            'Total Countermoves',
            (countermoveStats['totalCountermoves'] ?? 0).toString(),
          ),
        ],
      ],
    );
  }

  Widget _buildStatItem(BuildContext context, String label, String value) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
            Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      );

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }
}
