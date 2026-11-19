// lib/config/theme/app_palette.dart
import 'package:flutter/material.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/constants/color_palette.dart';

extension AppPaletteX on ColorPalette {
  bool get isDark =>
      this == ColorPalette.neutralDark || this == ColorPalette.slateDark;

  Color get bg => switch (this) {
    ColorPalette.neutralDark => const Color(0xFF121413),
    ColorPalette.neutralLight => const Color(0xFFEDEEEA),
    ColorPalette.slateDark => const Color(0xFF121418),
    ColorPalette.slateLight => const Color(0xFFEBEEF2),
  };

  Color get surface => switch (this) {
    ColorPalette.neutralDark => const Color(0xFF202421),
    ColorPalette.neutralLight => const Color(0xFFDCE0DA),
    ColorPalette.slateDark => const Color(0xFF1F242C),
    ColorPalette.slateLight => const Color(0xFFDBE1E8),
  };

  Color get primary => switch (this) {
    ColorPalette.neutralDark ||
    ColorPalette.neutralLight => const Color(0xFF2E5244),
    ColorPalette.slateDark ||
    ColorPalette.slateLight => const Color(0xFF1C4558),
  };

  Color get secondary => switch (this) {
    ColorPalette.neutralDark ||
    ColorPalette.neutralLight => const Color(0xFF5C8070),
    ColorPalette.slateDark ||
    ColorPalette.slateLight => const Color(0xFF4878A0),
  };

  Color get onSurface => switch (this) {
    ColorPalette.neutralDark => const Color(0xFFE4E6E3),
    ColorPalette.neutralLight => const Color(0xFF1B1F1D),
    ColorPalette.slateDark => const Color(0xFFE3E6EA),
    ColorPalette.slateLight => const Color(0xFF1A1E24),
  };

  Color get onSurfaceVar => switch (this) {
    ColorPalette.neutralDark => const Color(0xFFADB2AE),
    ColorPalette.neutralLight => const Color(0xFF545A56),
    ColorPalette.slateDark => const Color(0xFFADB4BF),
    ColorPalette.slateLight => const Color(0xFF4C5563),
  };

  Color get onPrimary => switch (this) {
    ColorPalette.neutralDark => const Color(0xFFECEEEB),
    ColorPalette.neutralLight => const Color(0xFFF5F5F2),
    ColorPalette.slateDark => const Color(0xFFECEEF1),
    ColorPalette.slateLight => const Color(0xFFF3F5F7),
  };

  Color get primaryInk => switch (this) {
    ColorPalette.neutralDark => const Color(0xFF93BAA8),
    ColorPalette.slateDark => const Color(0xFF8DB5CC),
    ColorPalette.neutralLight || ColorPalette.slateLight => primary,
  };

  Color get primaryTint => isDark
      ? secondary.withValues(alpha: 0.24)
      : primary.withValues(alpha: 0.10);

  Color get error => isDark ? const Color(0xFFE68A84) : const Color(0xFFA33A35);

  Color get onError => isDark ? bg : const Color(0xFFF5F5F2);

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
    onPrimary: onPrimary,
    secondary: secondary,
    onSecondary: const Color(0xFFF5F5F5),
    error: error,
    onError: onError,
    surface: bg,
    onSurface: onSurface,
    onSurfaceVariant: onSurfaceVar,
    surfaceContainer: surface,
  );

  ThemeData toThemeData() => ThemeData(
    useMaterial3: true,
    fontFamily: TS.fontFamily,
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
    switchTheme: SwitchThemeData(
      trackColor: _whenSelected(primaryInk),
      thumbColor: _whenSelected(isDark ? bg : onPrimary),
    ),
  );

  WidgetStateProperty<Color?> _whenSelected(Color color) =>
      WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.disabled) ||
                !states.contains(WidgetState.selected)
            ? null
            : color,
      );
}
