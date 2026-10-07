import 'package:flutter/material.dart';

/// Performance Metrics Graphs
///
/// Displays various performance metrics as visual charts
class PerformanceGraphs extends StatefulWidget {
  const PerformanceGraphs({
    required this.moveMetrics,
    Key? key,
    this.selectedMetric = PerformanceMetric.nodesPerSecond,
    this.onMetricChanged,
  }) : super(key: key);

  /// List of game move data points
  final List<MoveMetrics> moveMetrics;

  /// Selected metric to display
  final PerformanceMetric selectedMetric;

  /// Callback when metric selection changes
  final Function(PerformanceMetric)? onMetricChanged;

  @override
  State<PerformanceGraphs> createState() => _PerformanceGraphsState();
}

class _PerformanceGraphsState extends State<PerformanceGraphs> {
  late PerformanceMetric _selectedMetric;

  @override
  void initState() {
    super.initState();
    _selectedMetric = widget.selectedMetric;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.moveMetrics.isEmpty) {
      return Center(
        child: Text(
          'No metrics data yet',
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.grey,
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Metric selector
        Padding(
          padding: const EdgeInsets.all(12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: PerformanceMetric.values.map((metric) {
                final isSelected = _selectedMetric == metric;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FilterChip(
                    label: Text(metric.displayName),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedMetric = metric;
                        });
                        widget.onMetricChanged?.call(metric);
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        // Graph
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: _buildGraph(context),
          ),
        ),

        // Statistics summary
        Padding(
          padding: const EdgeInsets.all(12),
          child: _buildStatisticsSummary(context),
        ),
      ],
    );
  }

  Widget _buildGraph(BuildContext context) {
    final data = _getMetricData(_selectedMetric);
    final theme = Theme.of(context);

    if (data.isEmpty) {
      return Center(
        child: Text(
          'No data for ${_selectedMetric.displayName}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.grey,
          ),
        ),
      );
    }

    final maxValue = data.fold<double>(0, (max, val) => val > max ? val : max);
    final minValue =
        data.fold<double>(double.infinity, (min, val) => val < min ? val : min);
    final range = maxValue - minValue;
    final normalizedData =
        data.map((val) => range > 0 ? (val - minValue) / range : 0.5).toList();

    return CustomPaint(
      painter: GraphPainter(
        data: normalizedData,
        maxValue: maxValue,
        minValue: minValue,
        metric: _selectedMetric,
        color: _getColorForMetric(_selectedMetric),
      ),
      child: Container(),
    );
  }

  Widget _buildStatisticsSummary(BuildContext context) {
    final data = _getMetricData(_selectedMetric);
    if (data.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final max = data.reduce((a, b) => a > b ? a : b);
    final min = data.reduce((a, b) => a < b ? a : b);
    final avg = data.reduce((a, b) => a + b) / data.length;

    final maxLabel = _formatValue(max);
    final minLabel = _formatValue(min);
    final avgLabel = _formatValue(avg);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatItem(context, 'Max', maxLabel, Colors.green),
        _buildStatItem(context, 'Avg', avgLabel, Colors.blue),
        _buildStatItem(context, 'Min', minLabel, Colors.red),
      ],
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: Colors.grey,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            value,
            style: theme.textTheme.labelLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  List<double> _getMetricData(PerformanceMetric metric) {
    switch (metric) {
      case PerformanceMetric.nodesPerSecond:
        return widget.moveMetrics
            .map((m) => (m.nodesEvaluated / (m.timeMs / 1000)).toDouble())
            .toList();
      case PerformanceMetric.cacheHitRate:
        return widget.moveMetrics.map((m) => m.cacheHitRate * 100).toList();
      case PerformanceMetric.searchDepth:
        return widget.moveMetrics.map((m) => m.depth.toDouble()).toList();
      case PerformanceMetric.timePerMove:
        return widget.moveMetrics.map((m) => m.timeMs.toDouble()).toList();
      case PerformanceMetric.killerEffectiveness:
        return widget.moveMetrics
            .map((m) => m.killerCutoffs.toDouble())
            .toList();
      case PerformanceMetric.countermoveEffectiveness:
        return widget.moveMetrics
            .map((m) => m.countermoveCutoffs.toDouble())
            .toList();
    }
  }

  String _formatValue(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    } else if (value >= 100) {
      return value.toStringAsFixed(0);
    } else if (value >= 10) {
      return value.toStringAsFixed(1);
    } else {
      return value.toStringAsFixed(2);
    }
  }

  Color _getColorForMetric(PerformanceMetric metric) {
    switch (metric) {
      case PerformanceMetric.nodesPerSecond:
        return Colors.blue;
      case PerformanceMetric.cacheHitRate:
        return Colors.green;
      case PerformanceMetric.searchDepth:
        return Colors.purple;
      case PerformanceMetric.timePerMove:
        return Colors.orange;
      case PerformanceMetric.killerEffectiveness:
        return Colors.red;
      case PerformanceMetric.countermoveEffectiveness:
        return Colors.teal;
    }
  }
}

/// Custom painter for line graph
class GraphPainter extends CustomPainter {
  GraphPainter({
    required this.data,
    required this.maxValue,
    required this.minValue,
    required this.metric,
    required this.color,
  });
  final List<double> data;
  final double maxValue;
  final double minValue;
  final PerformanceMetric metric;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty || data.length < 2) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.2)
      ..strokeWidth = 0.5;

    const pointRadius = 3.0;
    const padding = 40.0;
    final graphWidth = size.width - (padding * 2);
    final graphHeight = size.height - (padding * 2);

    // Draw grid lines
    for (int i = 0; i <= 5; i++) {
      final y = padding + (graphHeight / 5) * i;
      canvas.drawLine(
        Offset(padding, y),
        Offset(size.width - padding, y),
        gridPaint,
      );
    }

    // Draw data points and lines
    final path = Path();
    for (int i = 0; i < data.length; i++) {
      final x = padding + (graphWidth / (data.length - 1)) * i;
      final y = size.height - padding - (graphHeight * data[i]);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    // Draw line
    canvas.drawPath(path, paint);

    // Draw points
    for (int i = 0; i < data.length; i++) {
      final x = padding + (graphWidth / (data.length - 1)) * i;
      final y = size.height - padding - (graphHeight * data[i]);

      canvas.drawCircle(
        Offset(x, y),
        pointRadius,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill,
      );
    }

    // Draw axes
    final axisPaint = Paint()
      ..color = Colors.grey
      ..strokeWidth = 1;

    canvas.drawLine(
      Offset(padding, size.height - padding),
      Offset(size.width - padding, size.height - padding),
      axisPaint,
    );

    canvas.drawLine(
      const Offset(padding, padding),
      Offset(padding, size.height - padding),
      axisPaint,
    );
  }

  @override
  bool shouldRepaint(GraphPainter oldDelegate) =>
      oldDelegate.data != data ||
      oldDelegate.color != color ||
      oldDelegate.maxValue != maxValue;
}

/// Performance metric types
enum PerformanceMetric {
  nodesPerSecond('Nodes/Sec', 'nodes_sec'),
  cacheHitRate('Cache Hit %', 'cache_hit'),
  searchDepth('Search Depth', 'depth'),
  timePerMove('Time/Move (ms)', 'time'),
  killerEffectiveness('Killer Moves', 'killer'),
  countermoveEffectiveness('Countermoves', 'countermove');

  final String displayName;
  final String id;

  const PerformanceMetric(this.displayName, this.id);
}

/// Move performance metrics data
class MoveMetrics {
  // opening, midgame, endgame

  MoveMetrics({
    required this.moveNumber,
    required this.nodesEvaluated,
    required this.timeMs,
    required this.depth,
    required this.cacheHitRate,
    required this.zobristHits,
    required this.zobristMisses,
    required this.killerCutoffs,
    required this.countermoveCutoffs,
    required this.gamePhase,
  });

  /// Create from engine statistics
  factory MoveMetrics.fromEngineStats({
    required int moveNumber,
    required Map<String, dynamic> stats,
    required int timeMs,
  }) =>
      MoveMetrics(
        moveNumber: moveNumber,
        nodesEvaluated: stats['nodesEvaluated'] as int? ?? 0,
        timeMs: timeMs,
        depth: stats['depth'] as int? ?? 0,
        cacheHitRate:
            double.tryParse(stats['zobristHitRate'] as String? ?? '0') ?? 0,
        zobristHits: stats['zobristHits'] as int? ?? 0,
        zobristMisses: stats['zobristMisses'] as int? ?? 0,
        killerCutoffs:
            (stats['killerStats'] as Map?)?['totalCutoffs'] as int? ?? 0,
        countermoveCutoffs:
            (stats['countermoveStats'] as Map?)?['totalCutoffs'] as int? ?? 0,
        gamePhase: _determineGamePhase(moveNumber),
      );
  final int moveNumber;
  final int nodesEvaluated;
  final int timeMs;
  final int depth;
  final double cacheHitRate;
  final int zobristHits;
  final int zobristMisses;
  final int killerCutoffs;
  final int countermoveCutoffs;
  final String gamePhase;

  static String _determineGamePhase(int moveNumber) {
    if (moveNumber <= 12) return 'opening';
    if (moveNumber <= 35) return 'midgame';
    return 'endgame';
  }
}
