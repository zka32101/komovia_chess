import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/performance_analytics_provider.dart';
import '../../models/rating_progression.dart';
import 'chart_utils.dart';

/// Chart displaying rating progression over time
class RatingProgressionChart extends ConsumerWidget {
  const RatingProgressionChart({
    required this.playerId,
    required this.days,
    Key? key,
  }) : super(key: key);
  final String playerId;
  final int days;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressionData = ref.watch(
      ratingProgressionProvider(
        (playerId: playerId, days: days),
      ),
    );

    return progressionData.when(
      data: (progression) => _buildChart(context, progression),
      loading: () => _buildLoadingState(context),
      error: (error, stackTrace) => _buildErrorState(context),
    );
  }

  Widget _buildChart(BuildContext context, List<RatingProgression> data) {
    if (data.isEmpty) {
      return Center(
        child: Text(
          'データがありません',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    final ratings = data.map((p) => p.rating.toDouble()).toList();
    final minRating = ratings.reduce((a, b) => a < b ? a : b).toInt();
    final maxRating = ratings.reduce((a, b) => a > b ? a : b).toInt();
    final avgRating =
        (ratings.reduce((a, b) => a + b) / ratings.length).toInt();

    // Create chart spots
    final spots = <FlSpot>[];
    for (int i = 0; i < data.length; i++) {
      spots.add(FlSpot(i.toDouble(), data[i].rating.toDouble()));
    }

    return Container(
      padding: const EdgeInsets.all(16),
      height: 300,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title and stats
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '現在: ${data.last.rating}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '最高: $maxRating',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.green,
                        ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '最低: $minRating',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.red,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '平均: $avgRating',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.blue,
                        ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Chart
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval:
                      ChartConfig.getGridInterval(minRating, maxRating)
                          .toDouble(),
                  getDrawingHorizontalLine: (value) => FlLine(
                    color:
                        Theme.of(context).colorScheme.outline.withOpacity(0.3),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: (spots.length / 5).ceilToDouble(),
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= data.length) {
                          return const Text('');
                        }
                        return Text(
                          ChartConfig.formatDate(data[index].date),
                          style: Theme.of(context).textTheme.labelSmall,
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) => Text(
                        value.toInt().toString(),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border(
                    left: BorderSide(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    bottom: BorderSide(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ),
                minX: 0,
                maxX: (spots.length - 1).toDouble(),
                minY: (minRating - 50).toDouble(),
                maxY: (maxRating + 50).toDouble(),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    gradient: LinearGradient(
                      colors: context.getGradientColors(),
                    ),
                    barWidth: ChartConfig.borderWidth,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) =>
                          FlDotCirclePainter(
                        radius: ChartConfig.dotRadius,
                        color: context.getPrimaryChartColor(),
                        strokeWidth: 2,
                        strokeColor: Theme.of(context).colorScheme.surface,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          context.getPrimaryChartColor().withOpacity(0.3),
                          context.getPrimaryChartColor().withOpacity(0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  handleBuiltInTouches: true,
                  touchTooltipData: LineTouchTooltipData(
                    tooltipBgColor:
                        Theme.of(context).colorScheme.surface.withOpacity(0.9),
                    tooltipBorder: BorderSide(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    getTooltipItems: (touchedSpots) =>
                        touchedSpots.map((touchedBarSpot) {
                      final textColor = Theme.of(context).colorScheme.onSurface;
                      return LineTooltipItem(
                        'レーティング: ${touchedBarSpot.y.toInt()}',
                        TextStyle(color: textColor),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'データを読み込み中...',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );

  Widget _buildErrorState(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'データの取得に失敗しました',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
}
