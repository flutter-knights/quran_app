// test/config/theme/app_palette_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/config/theme/app_palette.dart';
import 'package:quran_app/core/constants/color_palette.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('isDark', () {
    test(
      'neutralDark is dark',
      () => expect(ColorPalette.neutralDark.isDark, true),
    );
    test(
      'neutralLight is not dark',
      () => expect(ColorPalette.neutralLight.isDark, false),
    );
    test(
      'slateDark is dark',
      () => expect(ColorPalette.slateDark.isDark, true),
    );
    test(
      'slateLight is not dark',
      () => expect(ColorPalette.slateLight.isDark, false),
    );
  });

  group('bg colors', () {
    test(
      'neutralDark bg',
      () => expect(ColorPalette.neutralDark.bg, const Color(0xFF0D0D0D)),
    );
    test(
      'neutralLight bg',
      () => expect(ColorPalette.neutralLight.bg, const Color(0xFFF4F4F4)),
    );
    test(
      'slateDark bg',
      () => expect(ColorPalette.slateDark.bg, const Color(0xFF0A0C10)),
    );
    test(
      'slateLight bg',
      () => expect(ColorPalette.slateLight.bg, const Color(0xFFF0F3F8)),
    );
  });

  group('family color sharing', () {
    test('neutral palettes share primary', () {
      expect(
        ColorPalette.neutralDark.primary,
        ColorPalette.neutralLight.primary,
      );
    });
    test('slate palettes share secondary', () {
      expect(
        ColorPalette.slateDark.secondary,
        ColorPalette.slateLight.secondary,
      );
    });
  });

  group('toThemeData', () {
    test('neutralDark produces dark brightness', () {
      final theme = ColorPalette.neutralDark.toThemeData();
      expect(theme.colorScheme.brightness, Brightness.dark);
    });
    test('slateLight produces light brightness', () {
      final theme = ColorPalette.slateLight.toThemeData();
      expect(theme.colorScheme.brightness, Brightness.light);
    });
    test('theme uses palette primary as colorScheme.primary', () {
      final theme = ColorPalette.slateDark.toThemeData();
      expect(theme.colorScheme.primary, ColorPalette.slateDark.primary);
    });
  });
}
