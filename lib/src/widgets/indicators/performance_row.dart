import 'package:flutter/material.dart';
import 'win_rate_progress_bar.dart';

/// Row displaying performance category with progress bar and label
class PerformanceRow extends StatelessWidget {
  const PerformanceRow({
    required this.label,
    required this.percentage,
    Key? key,
    this.subtitle,
  }) : super(key: key);
  final String label;
  final int percentage;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            WinRateProgressBar(
              label: label,
              percentage: percentage,
              animated: true,
            ),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              ),
          ],
        ),
      );
}
