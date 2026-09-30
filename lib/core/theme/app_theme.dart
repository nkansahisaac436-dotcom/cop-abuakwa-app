import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';

class AppTheme {
  AppTheme._();

  static bool get _isTestEnvironment {
    return WidgetsBinding.instance.runtimeType.toString().contains('Test');
  }

  static TextStyle _serifStyle({
    required double fontSize,
    FontWeight fontWeight = FontWeight.normal,
    Color? color,
  }) {
    if (_isTestEnvironment) {
      return TextStyle(
        fontFamily: 'Source Serif 4',
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
      );
    }
    return GoogleFonts.sourceSerif4(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
  }

  static TextStyle _sansStyle({
    required double fontSize,
    FontWeight fontWeight = FontWeight.normal,
    Color? color,
    double? height,
  }) {
    if (_isTestEnvironment) {
      return TextStyle(
        fontFamily: 'Nunito Sans',
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
      );
    }
    return GoogleFonts.nunitoSans(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
    );
  }

  static TextTheme _buildTextTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : AppColors.text;
    final subtextColor = isDark ? const Color(0xFF94A3B8) : AppColors.softGrey;

    return TextTheme(
      displayLarge: _serifStyle(
        fontSize: AppDimensions.fontSizeAppName,
        fontWeight: FontWeight.bold,
        color: isDark ? Colors.white : AppColors.white,
      ),
      displayMedium: _serifStyle(
        fontSize: AppDimensions.fontSizeScreenTitle,
        fontWeight: FontWeight.bold,
        color: primaryTextColor,
      ),
      headlineSmall: _serifStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: primaryTextColor,
      ),
      titleLarge: _serifStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: primaryTextColor,
      ),
      titleMedium: _sansStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: primaryTextColor,
      ),
      bodyLarge: _sansStyle(
        fontSize: AppDimensions.fontSizeInput,
        color: primaryTextColor,
      ),
      bodyMedium: _sansStyle(
        fontSize: 14,
        color: primaryTextColor,
      ),
      bodySmall: _sansStyle(
        fontSize: AppDimensions.fontSizeSubtext,
        color: subtextColor,
      ),
      labelLarge: _sansStyle(
        fontSize: AppDimensions.fontSizeButton,
        fontWeight: FontWeight.bold,
        color: AppColors.white,
      ),
      labelMedium: _sansStyle(
        fontSize: AppDimensions.fontSizeLabel,
        fontWeight: FontWeight.bold,
        color: primaryTextColor,
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.background,
      primaryColor: AppColors.navy,
      colorScheme: const ColorScheme.light(
        primary: AppColors.navy,
        onPrimary: AppColors.white,
        secondary: AppColors.gold,
        onSecondary: AppColors.white,
        surface: AppColors.white,
        onSurface: AppColors.text,
        error: AppColors.error,
        onError: AppColors.white,
      ),
      textTheme: _buildTextTheme(Brightness.light),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.navy,
        foregroundColor: AppColors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: _serifStyle(
          fontSize: AppDimensions.fontSizeScreenTitle,
          fontWeight: FontWeight.bold,
          color: AppColors.white,
        ),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.white,
        elevation: 2,
        shadowColor: Color(0x10000000),
        shape: RoundedRectangleBorder(
          borderRadius: AppDimensions.cardBorderRadius,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: AppDimensions.inputBorderRadius,
          borderSide: const BorderSide(color: AppColors.border, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppDimensions.inputBorderRadius,
          borderSide: const BorderSide(color: AppColors.border, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppDimensions.inputBorderRadius,
          borderSide: const BorderSide(color: AppColors.navy, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppDimensions.inputBorderRadius,
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: AppDimensions.inputBorderRadius,
          borderSide: const BorderSide(color: AppColors.border, width: 1.0),
        ),
        hintStyle: _sansStyle(
          fontSize: AppDimensions.fontSizeInput,
          color: AppColors.softGrey,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.navy,
          foregroundColor: AppColors.white,
          minimumSize: const Size(double.infinity, AppDimensions.buttonHeight),
          shape: const StadiumBorder(),
          textStyle: _sansStyle(
            fontSize: AppDimensions.fontSizeButton,
            fontWeight: FontWeight.bold,
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.gold,
          minimumSize: const Size(double.infinity, AppDimensions.buttonHeight),
          side: const BorderSide(color: AppColors.gold, width: 1.8),
          shape: const StadiumBorder(),
          textStyle: _sansStyle(
            fontSize: AppDimensions.fontSizeButton,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0F172A),
      primaryColor: AppColors.navy,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.lightGold,
        onPrimary: AppColors.navyDark,
        secondary: AppColors.gold,
        onSecondary: Colors.black,
        surface: Color(0xFF1E293B),
        onSurface: Colors.white,
        error: Color(0xFFEF4444),
        onError: Colors.white,
      ),
      textTheme: _buildTextTheme(Brightness.dark),
      cardTheme: const CardThemeData(
        color: Color(0xFF1E293B),
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: AppDimensions.cardBorderRadius,
        ),
      ),
    );
  }
}
