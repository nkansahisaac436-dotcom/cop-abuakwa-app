import 'package:flutter/material.dart';

/// Design tokens and dimensions specified in Section 9
class AppDimensions {
  AppDimensions._();

  // Radii
  static const double cardRadius = 26.0;
  static const double inputRadius = 14.0;
  static const double buttonRadius = 27.0; // Fully rounded (pill)
  static const BorderRadius cardBorderRadius = BorderRadius.all(Radius.circular(cardRadius));
  static const BorderRadius inputBorderRadius = BorderRadius.all(Radius.circular(inputRadius));
  static const BorderRadius buttonBorderRadius = BorderRadius.all(Radius.circular(buttonRadius));

  // Sizes & Heights
  static const double buttonHeight = 54.0;
  static const double minTouchTarget = 48.0;

  // Typography Sizes
  static const double fontSizeAppName = 27.0;
  static const double fontSizeScreenTitle = 23.0;
  static const double fontSizeButton = 17.0;
  static const double fontSizeInput = 15.0;
  static const double fontSizeLabel = 13.0;
  static const double fontSizeSubtext = 12.0;

  // Paddings
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;
  static const double paddingExtraLarge = 32.0;
}
