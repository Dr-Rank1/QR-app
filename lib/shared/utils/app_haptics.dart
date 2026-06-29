import 'package:flutter/services.dart';

/// Device-local haptic feedback (no network or backend).
abstract final class AppHaptics {
  static Future<void> success() => HapticFeedback.mediumImpact();

  static Future<void> light() => HapticFeedback.lightImpact();

  static Future<void> selection() => HapticFeedback.selectionClick();
}
