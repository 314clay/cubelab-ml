import 'package:flutter/material.dart';

/// Spacing and radius constants for CubeLab.
abstract class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 24.0;
  static const double xl = 32.0;

  static const double pagePadding = 20.0;

  static const EdgeInsets pagePaddingInsets = EdgeInsets.symmetric(
    horizontal: pagePadding,
    vertical: 16.0,
  );

  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(12));
  static const BorderRadius buttonRadius = BorderRadius.all(Radius.circular(8));
}
