import 'package:flutter/material.dart';
import 'package:quran_app/config/theme/app_colors.dart';

final ColorScheme darkColorScheme = ColorScheme(
  brightness: Brightness.dark,

  // ACCENTS
  primary: AppColors.blueSlate,
  onPrimary: AppColors.alabasterGrey,
  primaryContainer: AppColors.airForceBlue,
  onPrimaryContainer: AppColors.carbonBlack,

  secondary: AppColors.airForceBlue,
  onSecondary: AppColors.alabasterGrey,
  secondaryContainer: AppColors.blueSlate,
  onSecondaryContainer: AppColors.carbonBlack,

  // TERTIARY — use success accent (optional accent slot)
  tertiary: AppColors.mintLeaf,
  onTertiary: AppColors.carbonBlack,
  tertiaryContainer: AppColors.jetBlack2,
  onTertiaryContainer: AppColors.alabasterGrey,

  surface: AppColors.carbonBlack,
  onSurface: AppColors.alabasterGrey,

  onSurfaceVariant: AppColors.silver,

  surfaceContainerLow: AppColors.jetBlack,
  surfaceContainerHigh: AppColors.jetBlack2,

  // OUTLINE
  outline: AppColors.blueSlate,
  outlineVariant: AppColors.jetBlack2,

  // ERROR
  error: AppColors.dustyMauve,
  onError: AppColors.carbonBlack,
  errorContainer: AppColors.jetBlack2,
  onErrorContainer: AppColors.alabasterGrey,

  // Misc
  shadow: Colors.black,
  scrim: Colors.black,
  inverseSurface: AppColors.alabasterGrey,
  onInverseSurface: AppColors.carbonBlack,
  inversePrimary: AppColors.airForceBlue,
);

final ColorScheme lightColorScheme = ColorScheme(
  brightness: Brightness.light,

  // PRIMARY — Your main brand color (Blue Slate)
  primary: AppColors.blueSlate,
  onPrimary: Colors.white,
  primaryContainer: AppColors.airForceBlue.withValues(alpha: .15),
  onPrimaryContainer: AppColors.blueSlate,

  // SECONDARY — Air Force Blue for accents
  secondary: AppColors.airForceBlue,
  onSecondary: Colors.white,
  secondaryContainer: AppColors.alabasterGrey,
  onSecondaryContainer: AppColors.blueSlate,

  // BACKGROUND & SURFACE — The Off-White "Depth" Logic
  surface: Color(0xFFFBFBFA), // Very subtle warm off-white
  onSurface: AppColors.carbonBlack,

  // These containers provide the "elevation" layers without needing heavy shadows
  surfaceContainerLow: Color(
    0xFFF2F2F0,
  ), // Slightly darker for background layers
  surfaceContainerHigh: AppColors.alabasterGrey, // For cards and modal sheets

  onSurfaceVariant: AppColors.blueSlate.withValues(alpha: .8),

  // OUTLINE
  outline: AppColors.silver,
  outlineVariant: AppColors.silver.withValues(alpha: .8),

  // ACCENTS
  tertiary: AppColors.mintLeaf,
  onTertiary: Colors.white,
  error: AppColors.dustyMauve,
  onError: Colors.white,

  shadow: AppColors.carbonBlack.withValues(alpha: .08),
);

extension ColorSchemeExtension on BuildContext {
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
}
