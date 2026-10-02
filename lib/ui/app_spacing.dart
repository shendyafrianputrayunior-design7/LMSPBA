import 'package:flutter/material.dart';

class AppSpacing {
  static const double xs = 6;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;

  static EdgeInsets screenPadding(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final horizontal = (size.width * 0.05).clamp(12.0, 28.0);
    final vertical = (size.height * 0.02).clamp(12.0, 24.0);
    return EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical);
  }

  static EdgeInsets listPadding(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final horizontal = (size.width * 0.04).clamp(12.0, 28.0);
    return EdgeInsets.symmetric(horizontal: horizontal, vertical: md);
  }
}
