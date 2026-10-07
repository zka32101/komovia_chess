import 'package:flutter/material.dart';

/// Visual representation of win percentage with animated progress bar
class WinRateProgressBar extends StatefulWidget {
  const WinRateProgressBar({
    required this.label,
    required this.percentage,
    Key? key,
    this.animated = true,
    this.customColor,
  }) : super(key: key);
  final String label;
  final int percentage;
  final bool animated;
  final Color? customColor;

  @override
  State<WinRateProgressBar> createState() => _WinRateProgressBarState();
}

class _WinRateProgressBarState extends State<WinRateProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _progressAnimation;
  double _previousPercentage = 0;

  @override
  void initState() {
    super.initState();
    _previousPercentage = widget.percentage.toDouble();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _progressAnimation = Tween<double>(
      begin: _previousPercentage / 100,
      end: widget.percentage / 100,
    ).animate(CurvedAnimation(
        parent: _animationController, curve: Curves.easeInOutQuad));

    if (widget.animated) {
      _animationController.forward();
    }
  }

  @override
  void didUpdateWidget(WinRateProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.percentage != widget.percentage) {
      _progressAnimation = Tween<double>(
        begin: _progressAnimation.value,
        end: widget.percentage / 100,
      ).animate(CurvedAnimation(
          parent: _animationController, curve: Curves.easeInOutQuad));

      _animationController.reset();
      if (widget.animated) {
        _animationController.forward();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.customColor ?? _getPerformanceColor(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
            Text(
              '${widget.percentage}%',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        AnimatedBuilder(
          animation: _progressAnimation,
          builder: (context, child) => ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _progressAnimation.value,
              minHeight: 12,
              backgroundColor:
                  Theme.of(context).colorScheme.outline.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
      ],
    );
  }

  Color _getPerformanceColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final percentage = widget.percentage;

    if (percentage >= 60) {
      return isDark ? const Color(0xFF81C784) : const Color(0xFF2CA02C);
    } else if (percentage >= 40) {
      return isDark ? const Color(0xFFFFB74D) : const Color(0xFFFF7F0E);
    } else {
      return isDark ? const Color(0xFFE57373) : const Color(0xFFD62728);
    }
  }
}
