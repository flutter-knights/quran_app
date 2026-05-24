// test/config/theme/app_palette_test.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quran_app/config/theme/app_palette.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/constants/color_palette.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  // Pre-warm TS.regular15 outside any test zone so the async google_fonts
  // font-load error (which fires because Cairo is not bundled in assets)
  // does not get attributed to any test. The error is swallowed here
  // intentionally — it only affects font rendering, not our tested values.
  setUpAll(() {
    runZonedGuarded(
      () {
        // ignore: unnecessary_statements
        TS.regular15; // triggers lazy static init → fires async font-load
      },
      (e, _) {
        // swallow google_fonts font-load failure
      },
    );
  });

  group('isDark', () {
    test('neutralDark is dark', () => expect(ColorPalette.neutralDark.isDark, true));
    test('neutralLight is not dark', () => expect(ColorPalette.neutralLight.isDark, false));
    test('slateDark is dark', () => expect(ColorPalette.slateDark.isDark, true));
    test('slateLight is not dark', () => expect(ColorPalette.slateLight.isDark, false));
  });

  group('bg colors', () {
    test('neutralDark bg', () => expect(ColorPalette.neutralDark.bg, const Color(0xFF0D0D0D)));
    test('neutralLight bg', () => expect(ColorPalette.neutralLight.bg, const Color(0xFFF4F4F4)));
    test('slateDark bg', () => expect(ColorPalette.slateDark.bg, const Color(0xFF0A0C10)));
    test('slateLight bg', () => expect(ColorPalette.slateLight.bg, const Color(0xFFF0F3F8)));
  });

  group('family color sharing', () {
    test('neutral palettes share primary', () {
      expect(ColorPalette.neutralDark.primary, ColorPalette.neutralLight.primary);
    });
    test('slate palettes share secondary', () {
      expect(ColorPalette.slateDark.secondary, ColorPalette.slateLight.secondary);
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
