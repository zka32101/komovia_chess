import 'package:flutter/material.dart';

/// Utility class for chart colors and styling
class ChartColors {
  /// Get performance color based on win percentage
  static Color getPerformanceColor(
    int percentage,
    BuildContext context,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (percentage >= 60) {
      return isDark ? const Color(0xFF81C784) : const Color(0xFF2CA02C);
    } else if (percentage >= 40) {
      return isDark ? const Color(0xFFFFB74D) : const Color(0xFFFF7F0E);
    } else {
      return isDark ? const Color(0xFFE57373) : const Color(0xFFD62728);
    }
  }

  /// Get color for streak (win/loss)
  static Color getStreakColor(bool isWinStreak, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isWinStreak) {
      return isDark ? const Color(0xFF81C784) : const Color(0xFF2CA02C);
    } else {
      return isDark ? const Color(0xFFE57373) : const Color(0xFFD62728);
    }
  }

  /// Get primary chart color
  static Color getPrimaryColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFF64B5F6) : const Color(0xFF1F77B4);
  }

  /// Get gradient colors for chart fill
  static List<Color> getGradientColors(BuildContext context) {
    final primary = getPrimaryColor(context);
    return [primary.withOpacity(0.4), primary.withOpacity(0)];
  }
}

/// Utility class for chart configurations
class ChartConfig {
  static const double gridInterval = 200;
  static const double borderWidth = 2;
  static const double dotRadius = 6;
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Duration chartEntranceDuration = Duration(milliseconds: 500);

  /// Get appropriate grid interval based on rating range
  static double getGridInterval(int minRating, int maxRating) {
    final range = maxRating - minRating;
    if (range <= 100) return 20;
    if (range <= 200) return 50;
    if (range <= 500) return 100;
    return 200;
  }

  /// Format rating for display
  static String formatRating(int rating) => rating.toString();

  /// Format date for display
  static String formatDate(DateTime date) => '${date.month}/${date.day}';

  /// Format percentage for display
  static String formatPercentage(int percentage) => '$percentage%';
}

/// Extension for easy color application
extension ColorExtension on BuildContext {
  Color getPerformanceColor(int percentage) =>
      ChartColors.getPerformanceColor(percentage, this);

  Color getStreakColor(bool isWin) => ChartColors.getStreakColor(isWin, this);

  Color getPrimaryChartColor() => ChartColors.getPrimaryColor(this);

  List<Color> getGradientColors() => ChartColors.getGradientColors(this);
}
