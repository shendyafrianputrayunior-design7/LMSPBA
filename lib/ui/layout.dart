import 'package:flutter/material.dart';

class AppLayout {
  static Widget centeredConstrained({
    required Widget child,
    double maxWidth = 520,
    Alignment alignment = Alignment.topCenter,
  }) {
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
