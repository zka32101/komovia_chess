import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Haptic feedback service for vibration and tactile feedback
class HapticService {
  // Private constructor to prevent instantiation
  HapticService._();

  /// Light tap haptic feedback
  /// Used for subtle interactions
  static Future<void> lightTap() async {
    try {
      await HapticFeedback.lightImpact();
      debugPrint('[HapticService] Light tap');
    } catch (e) {
      debugPrint('[HapticService] Error light tap: $e');
    }
  }

  /// Medium tap haptic feedback
  /// Used for standard interactions
  static Future<void> mediumTap() async {
    try {
      await HapticFeedback.mediumImpact();
      debugPrint('[HapticService] Medium tap');
    } catch (e) {
      debugPrint('[HapticService] Error medium tap: $e');
    }
  }

  /// Heavy tap haptic feedback
  /// Used for important actions
  static Future<void> heavyTap() async {
    try {
      await HapticFeedback.heavyImpact();
      debugPrint('[HapticService] Heavy tap');
    } catch (e) {
      debugPrint('[HapticService] Error heavy tap: $e');
    }
  }

  /// Selection click haptic feedback
  /// Used for selection changes
  static Future<void> selection() async {
    try {
      await HapticFeedback.selectionClick();
      debugPrint('[HapticService] Selection click');
    } catch (e) {
      debugPrint('[HapticService] Error selection: $e');
    }
  }

  /// Success haptic pattern
  /// Used for successful actions
  static Future<void> success() async {
    try {
      // Double tap for success
      await HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 100));
      await HapticFeedback.lightImpact();
      debugPrint('[HapticService] Success pattern');
    } catch (e) {
      debugPrint('[HapticService] Error success: $e');
    }
  }

  /// Error haptic pattern
  /// Used for error actions
  static Future<void> error() async {
    try {
      // Triple tap for error
      await HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 50));
      await HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 50));
      await HapticFeedback.mediumImpact();
      debugPrint('[HapticService] Error pattern');
    } catch (e) {
      debugPrint('[HapticService] Error error: $e');
    }
  }

  /// Warning haptic pattern
  /// Used for warning states
  static Future<void> warning() async {
    try {
      // Long medium tap
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 200));
      await HapticFeedback.lightImpact();
      debugPrint('[HapticService] Warning pattern');
    } catch (e) {
      debugPrint('[HapticService] Error warning: $e');
    }
  }
}

/// Game-specific haptic feedback patterns
extension GameHapticExtension on HapticService {
  /// Haptic feedback for chess move
  static Future<void> onPieceMoved() async {
    await HapticService.lightTap();
  }

  /// Haptic feedback for capture
  static Future<void> onCapture() async {
    await HapticService.mediumTap();
  }

  /// Haptic feedback for check
  static Future<void> onCheck() async {
    await HapticService.warning();
  }

  /// Haptic feedback for checkmate
  static Future<void> onCheckmate() async {
    await HapticService.success();
  }

  /// Haptic feedback for illegal move
  static Future<void> onIllegalMove() async {
    await HapticService.error();
  }

  /// Haptic feedback for puzzle completion
  static Future<void> onPuzzleComplete() async {
    await HapticService.success();
  }

  /// Haptic feedback for puzzle failure
  static Future<void> onPuzzleFail() async {
    await HapticService.error();
  }

  /// Haptic feedback for achievement
  static Future<void> onAchievement() async {
    await HapticService.success();
  }
}
