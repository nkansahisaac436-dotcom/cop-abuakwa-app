import 'package:flutter/material.dart';

/// Design tokens specified in Project Brief Section 9
class AppColors {
  AppColors._();

  // Primary Navy Brand Colors
  static const Color navy = Color(0xFF1F3A5F);
  static const Color navyDark = Color(0xFF14294A);
  static const LinearGradient navyGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [navy, navyDark],
  );

  // Gold Accents
  static const Color gold = Color(0xFFB8860B);
  static const Color lightGold = Color(0xFFE8C766);

  // Background & Surfaces
  static const Color background = Color(0xFFF5F7FA);
  static const Color white = Color(0xFFFFFFFF);
  static const Color disabled = Color(0xFFEEF0F4);
  static const Color disabledText = Color(0xFFA0AEC0);

  // Text & Borders
  static const Color text = Color(0xFF1B2433);
  static const Color softGrey = Color(0xFF6B7686);
  static const Color border = Color(0xFFDDE2EA);
  static const Color error = Color(0xFFB3261E);

  // Warning Banner
  static const Color warningFill = Color(0xFFFFF4E0);
  static const Color warningBorder = Color(0xFFE0A11B);
  static const Color warningText = Color(0xFF7A4A00);

  // Additional status colors
  static const Color success = Color(0xFF2E7D32);
  static const Color info = Color(0xFF0288D1);
}
