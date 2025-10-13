import 'package:flutter/material.dart';

class AppDecor extends ThemeExtension<AppDecor> {
  final Gradient headerGradient;
  final Gradient surfaceGradient;

  const AppDecor({required this.headerGradient, required this.surfaceGradient});

  static AppDecor fromScheme(ColorScheme scheme) {
    final primary = scheme.primary;
    final secondary = scheme.tertiary;
    final header = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        primary.withValues(alpha: 0.95),
        secondary.withValues(alpha: 0.85),
      ],
    );
    final surface = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        scheme.surface,
  scheme.surfaceContainerHighest,
      ],
    );
    return AppDecor(headerGradient: header, surfaceGradient: surface);
  }

  @override
  ThemeExtension<AppDecor> copyWith({Gradient? headerGradient, Gradient? surfaceGradient}) => AppDecor(
        headerGradient: headerGradient ?? this.headerGradient,
        surfaceGradient: surfaceGradient ?? this.surfaceGradient,
      );

  @override
  ThemeExtension<AppDecor> lerp(ThemeExtension<AppDecor>? other, double t) {
    if (other is! AppDecor) return this;
    // Gradients don't support lerp out of the box; return one of them based on t.
    return t < 0.5 ? this : other;
  }
}
