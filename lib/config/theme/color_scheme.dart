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
extension ColorSchemeExtension on BuildContext {
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
}