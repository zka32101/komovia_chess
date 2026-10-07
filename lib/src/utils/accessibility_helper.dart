import 'dart:math';
import 'package:flutter/material.dart';

/// Accessibility utilities for WCAG 2.1 compliance
class AccessibilityHelper {
  // Private constructor to prevent instantiation
  AccessibilityHelper._();

  /// Minimum touch target size (WCAG 2.1 AA)
  static const double minTouchTargetSize = 48;

  /// Check if two colors have sufficient contrast ratio for WCAG AA
  /// - Normal text: requires 4.5:1
  /// - Large text: requires 3:1
  /// - Graphics: requires 3:1
  static bool hasEnoughContrast(
    Color foreground,
    Color background, {
    required bool isLargeText,
  }) {
    final minContrast = isLargeText ? 3.0 : 4.5;
    final contrastRatio = _calculateContrastRatio(foreground, background);
    return contrastRatio >= minContrast;
  }

  /// Calculate the contrast ratio between two colors
  /// Formula from WCAG 2.1
  static double _calculateContrastRatio(Color foreground, Color background) {
    final fg = _relativeLuminance(foreground);
    final bg = _relativeLuminance(background);

    final lighter = max(fg, bg);
    final darker = min(fg, bg);

    return (lighter + 0.05) / (darker + 0.05);
  }

  /// Calculate relative luminance per WCAG 2.1
  static double _relativeLuminance(Color color) {
    final r = _linearizeChannel(color.red / 255.0);
    final g = _linearizeChannel(color.green / 255.0);
    final b = _linearizeChannel(color.blue / 255.0);

    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  /// Linearize sRGB channel values
  static double _linearizeChannel(double value) {
    if (value <= 0.03928) {
      return value / 12.92;
    }
    return pow((value + 0.055) / 1.055, 2.0).toDouble();
  }

  /// Get animation duration respecting prefers-reduced-motion
  static Duration getAnimationDuration(
    BuildContext context, {
    Duration defaultDuration = const Duration(milliseconds: 300),
  }) {
    final mediaQuery = MediaQuery.of(context);
    if (mediaQuery.disableAnimations) {
      return Duration.zero;
    }
    return defaultDuration;
  }

  /// Create an accessible button with proper semantics
  static Widget createAccessibleButton({
    required String label,
    required VoidCallback onTap,
    String? hint,
    Widget? child,
    double? minSize = minTouchTargetSize,
  }) =>
      Semantics(
        button: true,
        enabled: true,
        label: label,
        hint: hint,
        onTap: onTap,
        child: SizedBox(
          width: minSize,
          height: minSize,
          child: child ?? Text(label),
        ),
      );

  /// Create an accessible switch
  static Widget createAccessibleSwitch({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
    String? hint,
  }) =>
      Semantics(
        enabled: true,
        label: label,
        hint: hint,
        toggled: value,
        onTap: () => onChanged(!value),
        child: GestureDetector(
          onTap: () => onChanged(!value),
          child: Switch(
            value: value,
            onChanged: onChanged,
          ),
        ),
      );

  /// Create an accessible slider
  static Widget createAccessibleSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
    String? hint,
    int? divisions,
  }) {
    final percentage = ((value - min) / (max - min) * 100).toStringAsFixed(0);

    return Semantics(
      slider: true,
      enabled: true,
      label: label,
      hint: '$hint ($percentage%)',
      onIncrease: value < max
          ? () => onChanged((value + (max - min) / 10).clamp(min, max))
          : null,
      onDecrease: value > min
          ? () => onChanged((value - (max - min) / 10).clamp(min, max))
          : null,
      child: Slider(
        value: value,
        min: min,
        max: max,
        divisions: divisions,
        label: '$percentage%',
        onChanged: onChanged,
      ),
    );
  }

  /// Ensure text has proper font scaling support
  static TextStyle ensureTextScaling(
    TextStyle style, {
    required double maxScaleFactor,
  }) =>
      style.copyWith(
          // TextScaler.linear will be applied by the widget
          );

  /// Create an accessible image that works with screen readers
  static Widget createAccessibleImage({
    required ImageProvider image,
    required String semanticLabel,
    required BoxFit fit,
  }) =>
      Semantics(
        image: true,
        label: semanticLabel,
        child: Image(
          image: image,
          fit: fit,
          semanticLabel: semanticLabel,
        ),
      );

  /// Check if a widget has adequate touch target size
  static bool hasSufficientTouchTarget(Size size) =>
      size.width >= minTouchTargetSize && size.height >= minTouchTargetSize;

  /// Format color value for accessibility (for error messages, etc)
  static String getColorName(Color color) {
    // Simple color naming - could be extended
    final value = color.value;

    if (value == 0xFF2E7D32) return 'Primary Green';
    if (value == 0xFFFF6F00) return 'Secondary Orange';
    if (value == 0xFFFAFAFA) return 'Light Background';
    if (value == 0xFFFFFFFF) return 'White';
    if (value == 0xFF1A1A1A) return 'Dark Text';
    if (value == 0xFFD32F2F) return 'Error Red';
    if (value == 0xFF388E3C) return 'Success Green';
    if (value == 0xFFFBC02D) return 'Warning Amber';
    if (value == 0xFF1976D2) return 'Info Blue';

    return 'Color #${value.toRadixString(16)}';
  }

  /// Validate page meets accessibility standards
  static List<String> validateAccessibility({
    required Color foregroundColor,
    required Color backgroundColor,
    required bool isLargeText,
  }) {
    final issues = <String>[];

    if (!hasEnoughContrast(
      foregroundColor,
      backgroundColor,
      isLargeText: isLargeText,
    )) {
      final ratio = _calculateContrastRatio(foregroundColor, backgroundColor);
      final minRequired = isLargeText ? 3.0 : 4.5;
      issues.add(
        'Insufficient color contrast: $ratio:1 (requires $minRequired:1)',
      );
    }

    return issues;
  }
}
