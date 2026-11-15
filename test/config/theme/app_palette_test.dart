// test/config/theme/app_palette_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/config/theme/app_colors.dart';
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
  group('alert getters keep today\'s colours', () {
    test('onPrimary is the old onPrimary on every palette', () {
      for (final p in ColorPalette.values) {
        expect(p.onPrimary, const Color(0xFFF5F5F5));
      }
    });
    test('primaryInk is primary in light and secondary in dark', () {
      expect(
        ColorPalette.neutralLight.primaryInk,
        ColorPalette.neutralLight.primary,
      );
      expect(
        ColorPalette.slateLight.primaryInk,
        ColorPalette.slateLight.primary,
      );
      expect(
        ColorPalette.neutralDark.primaryInk,
        ColorPalette.neutralDark.secondary,
      );
      expect(
        ColorPalette.slateDark.primaryInk,
        ColorPalette.slateDark.secondary,
      );
    });
    test(
      'primaryTint is primary at 12% in light and secondary at 22% in dark',
      () {
        expect(
          ColorPalette.neutralLight.primaryTint,
          ColorPalette.neutralLight.primary.withValues(alpha: 0.12),
        );
        expect(
          ColorPalette.slateDark.primaryTint,
          ColorPalette.slateDark.secondary.withValues(alpha: 0.22),
        );
      },
    );
    test('error and onError match the old colour scheme', () {
      for (final p in ColorPalette.values) {
        expect(p.error, AppColors.error);
      }
      expect(ColorPalette.neutralDark.onError, const Color(0xFF0D0D0D));
      expect(ColorPalette.slateDark.onError, const Color(0xFF0D0D0D));
      expect(ColorPalette.neutralLight.onError, const Color(0xFFF5F5F5));
      expect(ColorPalette.slateLight.onError, const Color(0xFFF5F5F5));
    });
    test('colorScheme reads onPrimary, error and onError from the getters', () {
      for (final p in ColorPalette.values) {
        expect(p.colorScheme.onPrimary, p.onPrimary);
        expect(p.colorScheme.error, p.error);
        expect(p.colorScheme.onError, p.onError);
      }
    });
  });
}
