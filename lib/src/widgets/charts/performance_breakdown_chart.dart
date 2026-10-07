import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'chart_utils.dart';

/// Bar chart displaying performance breakdown by category
class PerformanceBreakdownChart extends StatelessWidget {
  const PerformanceBreakdownChart({
    required this.performanceData,
    required this.title,
    Key? key,
    this.horizontal = true,
  }) : super(key: key);
  final Map<String, int> performanceData;
  final String title;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    if (performanceData.isEmpty) {
      return Center(
        child: Text(
          'データがありません',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    final entries = performanceData.entries.toList();
    const maxValue = 100.0; // Win percentage max is 100%

    // Create bar chart data
    final barGroups = <BarChartGroupData>[];
    for (int i = 0; i < entries.length; i++) {
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: entries[i].value.toDouble(),
              color: context.getPerformanceColor(entries[i].value),
              width: 16,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(4),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      height: 250,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxValue,
                minY: 0,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 20,
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
                      reservedSize: 50,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= entries.length) {
                          return const Text('');
                        }
                        return Transform.rotate(
                          angle: -0.5,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              _getCategoryLabel(entries[index].key),
                              style: Theme.of(context).textTheme.labelSmall,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) => Text(
                        '${value.toInt()}%',
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
                barGroups: barGroups,
                barTouchData: BarTouchData(
                  handleBuiltInTouches: true,
                  touchTooltipData: BarTouchTooltipData(
                    tooltipBgColor:
                        Theme.of(context).colorScheme.surface.withOpacity(0.9),
                    tooltipBorder: BorderSide(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                        BarTooltipItem(
                      '${rod.toY.toInt()}%',
                      TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getCategoryLabel(String key) {
    // Format time control labels
    switch (key) {
      case 'bullet':
        return 'バレット\n(1分以下)';
      case 'blitz':
        return 'ブリッツ\n(3-5分)';
      case 'rapid':
        return 'ラピッド\n(10分+)';
      default:
        // For rank labels, use as-is (they come from backend)
        return key;
    }
  }
}
