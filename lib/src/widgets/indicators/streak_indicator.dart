import 'package:flutter/material.dart';

/// Displays current and longest streaks with animated circular progress
class StreakIndicator extends StatefulWidget {
  const StreakIndicator({
    required this.currentStreak,
    required this.longestWin,
    required this.longestLoss,
    Key? key,
  }) : super(key: key);
  final int
      currentStreak; // +/- value, positive for win streak, negative for loss streak
  final int longestWin;
  final int longestLoss;

  @override
  State<StreakIndicator> createState() => _StreakIndicatorState();
}

class _StreakIndicatorState extends State<StreakIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();
  }

  @override
  void didUpdateWidget(StreakIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentStreak != widget.currentStreak) {
      _animationController.reset();
      _animationController.forward();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWinStreak = widget.currentStreak > 0;
    final streakValue = widget.currentStreak.abs();

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Current streak circle
          ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _getStreakColor(isWinStreak).withOpacity(0.8),
                    _getStreakColor(isWinStreak),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: _getStreakColor(isWinStreak).withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    streakValue.toString(),
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Text(
                    isWinStreak ? 'W' : 'L',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Current streak label
          Text(
            isWinStreak ? '連勝中' : '連敗中',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 24),

          // Longest streaks comparison
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildComparisonCard(
                context: context,
                label: '最長連勝',
                value: widget.longestWin,
                color: Colors.green,
              ),
              _buildComparisonCard(
                context: context,
                label: '最長連敗',
                value: widget.longestLoss,
                color: Colors.red,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonCard({
    required BuildContext context,
    required String label,
    required int value,
    required Color color,
  }) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              value.toString(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      );

  Color _getStreakColor(bool isWinStreak) {
    if (isWinStreak) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return isDark ? const Color(0xFF81C784) : const Color(0xFF2CA02C);
    } else {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return isDark ? const Color(0xFFE57373) : const Color(0xFFD62728);
    }
  }
}
