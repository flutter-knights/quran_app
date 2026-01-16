import 'package:flutter/material.dart';
import 'package:quran_app/config/theme/app_colors.dart';

const lightColorScheme = ColorScheme(
  brightness: Brightness.light,
  primary: AppColors.deepTeal,
  onPrimary: AppColors.brightSnow,
  secondary: AppColors.pineTeal,
  onSecondary: AppColors.brightSnow,
  error: AppColors.lightCoral,
  onError: AppColors.brightSnow,
  surface: AppColors.lightMist,
  onSurface: AppColors.onyx,
  onSurfaceVariant: AppColors.greyOlive,
  surfaceContainer: AppColors.brightSnow,
);
const darkColorScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: AppColors.pineTeal,
  onPrimary: AppColors.brightSnow,
  secondary: AppColors.deepTeal,
  onSecondary: AppColors.brightSnow,
  error: AppColors.lightCoral,
  onError: AppColors.onyx,
  surface: AppColors.onyx,
  onSurface: AppColors.brightSnow,
  onSurfaceVariant: AppColors.greyOlive,
  surfaceContainer: AppColors.evergreen,
);

extension ColorSchemeExtension on BuildContext {
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
}
