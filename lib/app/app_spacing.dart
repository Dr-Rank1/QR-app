import 'package:flutter/material.dart';

/// Uniform layout spacing used across all screens.
abstract final class AppSpacing {
  static const double screenHorizontal = 16;
  static const double screenVertical = 16;
  static const double listItemVertical = 12;
  static const double sectionGap = 20;

  static EdgeInsets screenPadding({
    double top = 0,
    double bottom = 0,
  }) {
    return EdgeInsets.fromLTRB(
      screenHorizontal,
      top,
      screenHorizontal,
      bottom,
    );
  }
}
