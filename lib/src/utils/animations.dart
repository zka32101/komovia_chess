import 'package:flutter/material.dart';

/// Animation constants and utilities for Chess Tactics Master
class AnimationConstants {
  // Duration constants
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
  static const Duration veryVerySlow = Duration(milliseconds: 800);

  // Curve constants
  static const Curve standardCurve = Curves.easeInOut;
  static const Curve emphasisCurve = Curves.easeOutCubic;
  static const Curve decelerationCurve = Curves.easeOut;
  static const Curve accelerationCurve = Curves.easeIn;
}

/// Custom page transitions with Material 3 feel
class SmoothPageTransition extends PageRouteBuilder {
  SmoothPageTransition({
    required this.page,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1, 0);
            const end = Offset.zero;
            const curve = Curves.easeInOutCubic;

            final tween = Tween(begin: begin, end: end).chain(
              CurveTween(curve: curve),
            );

            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
          transitionDuration: AnimationConstants.normal,
        );
  final Widget page;
}

/// Fade in page transition
class FadePageTransition extends PageRouteBuilder {
  FadePageTransition({
    required this.page,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(
            opacity: animation.drive(
              Tween<double>(begin: 0, end: 1).chain(
                CurveTween(curve: AnimationConstants.standardCurve),
              ),
            ),
            child: child,
          ),
          transitionDuration: AnimationConstants.normal,
        );
  final Widget page;
}

/// Scale fade transition
class ScaleFadeTransition extends PageRouteBuilder {
  ScaleFadeTransition({
    required this.page,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const scaleCurve = Interval(0, 0.5, curve: Curves.easeOutCubic);
            const fadeCurve = Interval(0.5, 1, curve: Curves.easeInCubic);

            return ScaleTransition(
              scale: animation.drive(
                Tween<double>(begin: 0.9, end: 1).chain(
                  CurveTween(curve: scaleCurve),
                ),
              ),
              child: FadeTransition(
                opacity: animation.drive(
                  Tween<double>(begin: 0, end: 1).chain(
                    CurveTween(curve: fadeCurve),
                  ),
                ),
                child: child,
              ),
            );
          },
          transitionDuration: AnimationConstants.normal,
        );
  final Widget page;
}

/// Shake animation widget
class ShakeAnimation extends StatefulWidget {
  const ShakeAnimation({
    required this.child,
    Key? key,
    this.duration = const Duration(milliseconds: 500),
    this.intensity = 5.0,
    this.isShaking = false,
  }) : super(key: key);
  final Widget child;
  final Duration duration;
  final double intensity;
  final bool isShaking;

  @override
  State<ShakeAnimation> createState() => _ShakeAnimationState();
}

class _ShakeAnimationState extends State<ShakeAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    if (widget.isShaking) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(ShakeAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isShaking && !oldWidget.isShaking) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final offset = Offset(
            (0.5 - _controller.value) * widget.intensity,
            0,
          );
          return Transform.translate(
            offset: offset,
            child: child,
          );
        },
        child: widget.child,
      );
}

/// Pulse animation widget
class PulseAnimation extends StatefulWidget {
  const PulseAnimation({
    required this.child,
    Key? key,
    this.duration = const Duration(milliseconds: 1000),
    this.maxScale = 1.1,
  }) : super(key: key);
  final Widget child;
  final Duration duration;
  final double maxScale;

  @override
  State<PulseAnimation> createState() => _PulseAnimationState();
}

class _PulseAnimationState extends State<PulseAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 1, end: widget.maxScale).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(
        scale: _animation,
        child: widget.child,
      );
}

/// Bounce animation widget
class BounceAnimation extends StatefulWidget {
  const BounceAnimation({
    required this.child,
    Key? key,
    this.duration = const Duration(milliseconds: 600),
    this.curve = Curves.elasticOut,
  }) : super(key: key);
  final Widget child;
  final Duration duration;
  final Curve curve;

  @override
  State<BounceAnimation> createState() => _BounceAnimationState();
}

class _BounceAnimationState extends State<BounceAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    )..forward();

    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: widget.curve),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(
        scale: _animation,
        child: widget.child,
      );
}

/// Slide animation for list items
class SlideInAnimation extends StatefulWidget {
  const SlideInAnimation({
    required this.child,
    Key? key,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 400),
    this.direction = SlideDirection.left,
  }) : super(key: key);
  final Widget child;
  final Duration delay;
  final Duration duration;
  final SlideDirection direction;

  @override
  State<SlideInAnimation> createState() => _SlideInAnimationState();
}

enum SlideDirection { left, right, up, down }

class _SlideInAnimationState extends State<SlideInAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    Offset beginOffset;
    switch (widget.direction) {
      case SlideDirection.left:
        beginOffset = const Offset(-1, 0);
        break;
      case SlideDirection.right:
        beginOffset = const Offset(1, 0);
        break;
      case SlideDirection.up:
        beginOffset = const Offset(0, 1);
        break;
      case SlideDirection.down:
        beginOffset = const Offset(0, -1);
        break;
    }

    _offsetAnimation = Tween<Offset>(
      begin: beginOffset,
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    Future.delayed(widget.delay, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SlideTransition(
        position: _offsetAnimation,
        child: FadeTransition(
          opacity: _controller.drive(
            Tween<double>(begin: 0, end: 1).chain(
              CurveTween(curve: Curves.easeOut),
            ),
          ),
          child: widget.child,
        ),
      );
}

/// Chess piece move animation
class PieceMoveAnimation extends StatefulWidget {
  const PieceMoveAnimation({
    required this.child,
    required this.from,
    required this.to,
    Key? key,
    this.duration = const Duration(milliseconds: 400),
  }) : super(key: key);
  final Widget child;
  final Offset from;
  final Offset to;
  final Duration duration;

  @override
  State<PieceMoveAnimation> createState() => _PieceMoveAnimationState();
}

class _PieceMoveAnimationState extends State<PieceMoveAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _positionAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    // Position animation with easing
    _positionAnimation = Tween<Offset>(
      begin: widget.from,
      end: widget.to,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
    );

    // Subtle rotation during move
    _rotationAnimation = Tween<double>(begin: 0, end: 0.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Transform.translate(
          offset: _positionAnimation.value,
          child: Transform.rotate(
            angle: _rotationAnimation.value,
            child: child,
          ),
        ),
        child: widget.child,
      );
}

/// Capture animation for captured pieces
class CaptureAnimation extends StatefulWidget {
  const CaptureAnimation({
    required this.child,
    Key? key,
    this.duration = const Duration(milliseconds: 300),
  }) : super(key: key);
  final Widget child;
  final Duration duration;

  @override
  State<CaptureAnimation> createState() => _CaptureAnimationState();
}

class _CaptureAnimationState extends State<CaptureAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    // Scale down effect
    _scaleAnimation = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInCubic),
    );

    // Fade out effect
    _opacityAnimation = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(
        scale: _scaleAnimation,
        child: FadeTransition(
          opacity: _opacityAnimation,
          child: widget.child,
        ),
      );
}

/// Check warning animation
class CheckWarningAnimation extends StatefulWidget {
  const CheckWarningAnimation({
    required this.child,
    Key? key,
    this.duration = const Duration(milliseconds: 600),
  }) : super(key: key);
  final Widget child;
  final Duration duration;

  @override
  State<CheckWarningAnimation> createState() => _CheckWarningAnimationState();
}

class _CheckWarningAnimationState extends State<CheckWarningAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1, end: 1.15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(
        scale: _pulseAnimation,
        child: widget.child,
      );
}
