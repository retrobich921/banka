import 'package:flutter/material.dart';

/// Цветовая палитра приложения.
///
/// Строгая тёмная тема: глубокий чёрный фон, серая иерархия поверхностей и
/// единый янтарный акцент-цвет под «энергетики».
abstract final class AppColors {
  // Backgrounds / surfaces
  static const Color background = Color(0xFF000000);
  static const Color surface = Color(0xFF0F0F0F);
  static const Color surfaceVariant = Color(0xFF1A1A1A);
  static const Color outline = Color(0xFF2A2A2A);

  // Foreground
  static const Color onBackground = Color(0xFFFFFFFF);
  static const Color onSurface = Color(0xFFFFFFFF);
  static const Color onSurfaceMuted = Color(0xFFA0A0A0);
  static const Color onSurfaceFaint = Color(0xFF707070);

  // Accent
  static const Color primary = Color(0xFFFFB300);
  static const Color onPrimary = Color(0xFF000000);

  // Semantic
  static const Color error = Color(0xFFFF5252);
  static const Color onError = Color(0xFF000000);
  static const Color success = Color(0xFF4CAF50);
}
