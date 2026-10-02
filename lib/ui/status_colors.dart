import 'package:flutter/material.dart';

@immutable
class StatusColors extends ThemeExtension<StatusColors> {
  final Color submittedBg;
  final Color submittedFg;
  final Color pendingBg;
  final Color pendingFg;

  const StatusColors({
    required this.submittedBg,
    required this.submittedFg,
    required this.pendingBg,
    required this.pendingFg,
  });

  @override
  StatusColors copyWith({
    Color? submittedBg,
    Color? submittedFg,
    Color? pendingBg,
    Color? pendingFg,
  }) {
    return StatusColors(
      submittedBg: submittedBg ?? this.submittedBg,
      submittedFg: submittedFg ?? this.submittedFg,
      pendingBg: pendingBg ?? this.pendingBg,
      pendingFg: pendingFg ?? this.pendingFg,
    );
  }

  @override
  StatusColors lerp(ThemeExtension<StatusColors>? other, double t) {
    if (other is! StatusColors) return this;
    return StatusColors(
      submittedBg: Color.lerp(submittedBg, other.submittedBg, t)!,
      submittedFg: Color.lerp(submittedFg, other.submittedFg, t)!,
      pendingBg: Color.lerp(pendingBg, other.pendingBg, t)!,
      pendingFg: Color.lerp(pendingFg, other.pendingFg, t)!,
    );
  }
}
