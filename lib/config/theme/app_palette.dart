// lib/config/theme/app_palette.dart
import 'package:flutter/material.dart';
import 'package:quran_app/config/theme/app_colors.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/constants/color_palette.dart';

extension AppPaletteX on ColorPalette {
  bool get isDark =>
      this == ColorPalette.neutralDark || this == ColorPalette.slateDark;

  Color get bg => switch (this) {
        ColorPalette.neutralDark => const Color(0xFF0D0D0D),
        ColorPalette.neutralLight => const Color(0xFFF4F4F4),
        ColorPalette.slateDark => const Color(0xFF0A0C10),
        ColorPalette.slateLight => const Color(0xFFF0F3F8),
      };

  Color get surface => switch (this) {
        ColorPalette.neutralDark => const Color(0xFF1A1A1A),
        ColorPalette.neutralLight => const Color(0xFFEAEAEA),
        ColorPalette.slateDark => const Color(0xFF141820),
        ColorPalette.slateLight => const Color(0xFFE2E8F2),
      };

  Color get primary => switch (this) {
        ColorPalette.neutralDark || ColorPalette.neutralLight =>
          const Color(0xFF2E5244),
        ColorPalette.slateDark || ColorPalette.slateLight =>
          const Color(0xFF1C4558),
      };

  Color get secondary => switch (this) {
        ColorPalette.neutralDark || ColorPalette.neutralLight =>
          const Color(0xFF5C8070),
        ColorPalette.slateDark || ColorPalette.slateLight =>
          const Color(0xFF4878A0),
      };

  Color get onSurface => switch (this) {
        ColorPalette.neutralDark => const Color(0xFFF5F5F5),
        ColorPalette.neutralLight => const Color(0xFF141414),
        ColorPalette.slateDark => const Color(0xFFF0F4F8),
        ColorPalette.slateLight => const Color(0xFF0A0C12),
      };

  Color get onSurfaceVar => switch (this) {
        ColorPalette.neutralDark => const Color(0xFF8A8A8A),
        ColorPalette.neutralLight => const Color(0xFF686868),
        ColorPalette.slateDark => const Color(0xFF8A92A0),
        ColorPalette.slateLight => const Color(0xFF5E6880),
      };

  Color get mushafBg => switch (this) {
        ColorPalette.neutralDark => const Color(0xFF1C1A14),
        ColorPalette.neutralLight => const Color(0xFFFFFCF5),
        ColorPalette.slateDark => const Color(0xFF111620),
        ColorPalette.slateLight => const Color(0xFFF8FBFF),
      };

  Color get mushafText => switch (this) {
        ColorPalette.neutralDark => const Color(0xFFD4C5B0),
        ColorPalette.neutralLight => const Color(0xFF1A1208),
        ColorPalette.slateDark => const Color(0xFFC8D4E0),
        ColorPalette.slateLight => const Color(0xFF0A0E14),
      };

  // rgba(255,255,255,0.06) for dark; rgba(0,0,0,0.06) for light
  Color get mushafBorderColor =>
      isDark ? const Color(0x0FFFFFFF) : const Color(0x0F000000);

  ColorScheme get colorScheme => ColorScheme(
        brightness: isDark ? Brightness.dark : Brightness.light,
        primary: primary,
        onPrimary: const Color(0xFFF5F5F5),
        secondary: secondary,
        onSecondary: const Color(0xFFF5F5F5),
        error: AppColors.error,
        onError: isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF5F5F5),
        surface: bg,
        onSurface: onSurface,
        onSurfaceVariant: onSurfaceVar,
        surfaceContainer: surface,
      );

  ThemeData toThemeData() => ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surface,
          suffixIconColor: onSurface,
          prefixIconColor: onSurface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          hintStyle: TS.regular15.copyWith(color: onSurface),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      );
}
