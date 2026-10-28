import 'package:flutter/material.dart';
import 'package:komovia_core/komovia_core.dart' as core;

/// Time clock widget for displaying remaining time in online games
///
/// Features:
/// - Real-time countdown display (MM:SS or MM:SS.CS format)
/// - Color-coded warnings: yellow < 1 minute, red < 10 seconds
/// - Pulsing animation when time is critically low
/// - Smooth updates without frame stuttering
class TimeClock extends StatefulWidget {
  const TimeClock({
    required this.timeMs,
    Key? key,
    this.isCurrentPlayer = false,
    this.onTimeExpired,
    this.showCentiseconds = true,
    this.size = ClockSize.standard,
  }) : super(key: key);

  /// Time remaining in milliseconds
  final int timeMs;

  /// Whether this is the current player's clock
  final bool isCurrentPlayer;

  /// Callback when time expires (if provided)
  final VoidCallback? onTimeExpired;

  /// Show centiseconds (100ms precision) when time < 60s
  final bool showCentiseconds;

  /// Clock size - standard, large, or custom
  final ClockSize size;

  @override
  State<TimeClock> createState() => _TimeClockState();
}

enum ClockSize { small, standard, large }

class _TimeClockState extends State<TimeClock>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _timeExpiredNotified = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Check if time expired
    if (widget.timeMs <= 0 && !_timeExpiredNotified) {
      _timeExpiredNotified = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onTimeExpired?.call();
      });
    }
  }

  @override
  void didUpdateWidget(TimeClock oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Check if time just expired
    if (widget.timeMs <= 0 && oldWidget.timeMs > 0 && !_timeExpiredNotified) {
      _timeExpiredNotified = true;
      widget.onTimeExpired?.call();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  /// Format time for display.
  ///
  /// Correspondence games (⑤ from this round's feature survey) use the
  /// same clock fields as a live game, just with a much larger starting
  /// value (days' worth of milliseconds) - previously this always
  /// rendered as raw total minutes (e.g. "10080:00" for 7 days), since
  /// nothing here ever accounted for a duration longer than an hour.
  /// Days/hours are now shown for anything an hour or longer, falling
  /// back to the existing mm:ss(.cs) display below that.
  String _formatTime(int ms) {
    if (ms < 0) ms = 0;

    final totalSeconds = ms ~/ 1000;

    if (totalSeconds >= Duration.secondsPerDay) {
      final days = totalSeconds ~/ Duration.secondsPerDay;
      final hours = (totalSeconds % Duration.secondsPerDay) ~/ 3600;
      return '${days}d ${hours.toString().padLeft(2, '0')}h';
    }
    if (totalSeconds >= 3600) {
      final hours = totalSeconds ~/ 3600;
      final minutes = (totalSeconds % 3600) ~/ 60;
      return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
    }

    // Under an hour: komovia_core's formatClock owns the mm:ss(.cs) digit
    // math and the 60s centiseconds cutoff, so this widget doesn't
    // duplicate it (days/hours above stay local - formatClock has no
    // concept of either, since no other sibling app's clock runs that
    // long).
    return core.formatClock(
      Duration(milliseconds: ms),
      showCentiseconds: widget.showCentiseconds,
    );
  }

  /// [widget.timeMs]'s warning level via komovia_core's shared thresholds
  /// (critical < 10s, low < 1 minute) - same values this widget already
  /// used, now the single source of truth shared with komovia_go's own
  /// clock display.
  core.ClockWarningLevel get _warningLevel =>
      core.warningLevelFor(Duration(milliseconds: widget.timeMs));

  /// Get time display color based on remaining time and theme
  Color _getTimeColor(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    switch (_warningLevel) {
      case core.ClockWarningLevel.critical:
        return Colors.red; // < 10 seconds (same in both themes)
      case core.ClockWarningLevel.low:
        return Colors.orange; // < 1 minute (same in both themes)
      case core.ClockWarningLevel.normal:
        return isDarkMode ? Colors.white70 : Colors.black87;
    }
  }

  /// Get background color based on remaining time, player state, and theme
  Color _getBackgroundColor(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (_warningLevel == core.ClockWarningLevel.critical) {
      return Colors.red.withOpacity(0.2); // < 10 seconds
    } else if (_warningLevel == core.ClockWarningLevel.low) {
      return Colors.orange.withOpacity(0.15); // < 1 minute
    } else if (widget.isCurrentPlayer) {
      return isDarkMode
          ? Colors.blue.withOpacity(0.15) // Darker blue for dark mode
          : Colors.blue.withOpacity(0.05); // Light blue for light mode
    } else {
      return Colors.transparent;
    }
  }

  /// Get font size based on clock size
  double _getFontSize() {
    switch (widget.size) {
      case ClockSize.small:
        return 16;
      case ClockSize.standard:
        return 20;
      case ClockSize.large:
        return 28;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLowTime = _warningLevel == core.ClockWarningLevel.critical;
    final timeColor = _getTimeColor(context);
    final backgroundColor = _getBackgroundColor(context);
    final fontSize = _getFontSize();

    // Use pulse animation only when time is critically low
    if (isLowTime && widget.timeMs > 0) {
      return ScaleTransition(
        scale: _pulseAnimation,
        child: _buildClockWidget(context, timeColor, backgroundColor, fontSize),
      );
    } else {
      return _buildClockWidget(context, timeColor, backgroundColor, fontSize);
    }
  }

  /// Build the actual clock widget
  Widget _buildClockWidget(BuildContext context, Color timeColor,
      Color backgroundColor, double fontSize) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: timeColor.withOpacity(isDarkMode ? 0.5 : 0.3),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Time display
          Text(
            _formatTime(widget.timeMs),
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: timeColor,
              fontFamily: 'Courier',
              letterSpacing: 0.5,
            ),
          ),
          // Optional: Low time indicator
          if (_warningLevel != core.ClockWarningLevel.normal && widget.timeMs > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Low Time',
                style: TextStyle(
                  fontSize: fontSize * 0.4,
                  color: timeColor.withOpacity(0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Enhanced time clock for game screens with player info
///
/// Combines player information (name, rating) with an animated time clock
class PlayerTimeClock extends StatelessWidget {
  const PlayerTimeClock({
    required this.playerName,
    required this.rating,
    required this.timeMs,
    Key? key,
    this.isCurrentPlayer = false,
    this.onTimeExpired,
    this.backgroundColor,
  }) : super(key: key);

  /// Player name
  final String playerName;

  /// Player rating
  final int rating;

  /// Time remaining in milliseconds
  final int timeMs;

  /// Whether this is the current player
  final bool isCurrentPlayer;

  /// Callback when time expires
  final VoidCallback? onTimeExpired;

  /// Custom background color override
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) => Container(
        color: backgroundColor ??
            (isCurrentPlayer ? Colors.blue[50] : Colors.transparent),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Player info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    playerName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Rating: $rating',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ),
            // Time clock
            SizedBox(
              width: 90,
              child: TimeClock(
                timeMs: timeMs,
                isCurrentPlayer: isCurrentPlayer,
                onTimeExpired: onTimeExpired,
                size: ClockSize.standard,
              ),
            ),
          ],
        ),
      );
}
