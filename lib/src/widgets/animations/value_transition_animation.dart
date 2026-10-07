import 'package:flutter/material.dart';

/// Animates value changes with smooth transitions
class ValueTransitionAnimation extends StatefulWidget {
  const ValueTransitionAnimation({
    required this.value,
    required this.builder,
    Key? key,
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.easeInOut,
  }) : super(key: key);
  final int value;
  final Widget Function(BuildContext context, int value) builder;
  final Duration duration;
  final Curve curve;

  @override
  State<ValueTransitionAnimation> createState() =>
      _ValueTransitionAnimationState();
}

class _ValueTransitionAnimationState extends State<ValueTransitionAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  late int _previousValue;
  late int _currentValue;

  @override
  void initState() {
    super.initState();
    _previousValue = widget.value;
    _currentValue = widget.value;

    _animationController = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: widget.curve),
    );
  }

  @override
  void didUpdateWidget(ValueTransitionAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.value != widget.value) {
      _previousValue = _currentValue;
      _currentValue = widget.value;

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
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final interpolatedValue = (_previousValue +
                  (_currentValue - _previousValue) * _animation.value)
              .toInt();

          return widget.builder(context, interpolatedValue);
        },
      );
}
