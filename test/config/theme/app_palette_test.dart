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
      () => expect(ColorPalette.neutralDark.bg, const Color(0xFF121413)),
    );
    test(
      'neutralLight bg',
      () => expect(ColorPalette.neutralLight.bg, const Color(0xFFEDEEEA)),
    );
    test(
      'slateDark bg',
      () => expect(ColorPalette.slateDark.bg, const Color(0xFF121418)),
    );
    test(
      'slateLight bg',
      () => expect(ColorPalette.slateLight.bg, const Color(0xFFEBEEF2)),
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

  group('Appendix B comfort values', () {
    const table = {
      ColorPalette.neutralLight: [
        0xFFEDEEEA,
        0xFFDCE0DA,
        0xFF1B1F1D,
        0xFF545A56,
        0xFF2E5244,
        0xFFF5F5F2,
        0xFF2E5244,
        0xFFA33A35,
        0xFFF5F5F2,
      ],
      ColorPalette.neutralDark: [
        0xFF121413,
        0xFF202421,
        0xFFE4E6E3,
        0xFFADB2AE,
        0xFF2E5244,
        0xFFECEEEB,
        0xFF93BAA8,
        0xFFE68A84,
        0xFF121413,
      ],
      ColorPalette.slateLight: [
        0xFFEBEEF2,
        0xFFDBE1E8,
        0xFF1A1E24,
        0xFF4C5563,
        0xFF1C4558,
        0xFFF3F5F7,
        0xFF1C4558,
        0xFFA33A35,
        0xFFF5F5F2,
      ],
      ColorPalette.slateDark: [
        0xFF121418,
        0xFF1F242C,
        0xFFE3E6EA,
        0xFFADB4BF,
        0xFF1C4558,
        0xFFECEEF1,
        0xFF8DB5CC,
        0xFFE68A84,
        0xFF121418,
      ],
    };
    for (final MapEntry(key: p, value: v) in table.entries) {
      test('$p', () {
        expect([
          p.bg,
          p.surface,
          p.onSurface,
          p.onSurfaceVar,
          p.primary,
          p.onPrimary,
          p.primaryInk,
          p.error,
          p.onError,
        ], v.map(Color.new).toList());
      });
    }
    test('primaryTint is primary at 10% in light', () {
      expect(
        ColorPalette.neutralLight.primaryTint,
        const Color(0xFF2E5244).withValues(alpha: 0.10),
      );
      expect(
        ColorPalette.slateLight.primaryTint,
        const Color(0xFF1C4558).withValues(alpha: 0.10),
      );
    });
    test('primaryTint is secondary at 24% in dark', () {
      expect(
        ColorPalette.neutralDark.primaryTint,
        const Color(0xFF5C8070).withValues(alpha: 0.24),
      );
      expect(
        ColorPalette.slateDark.primaryTint,
        const Color(0xFF4878A0).withValues(alpha: 0.24),
      );
    });
    test('colorScheme reads onPrimary, error and onError from the getters', () {
      for (final p in ColorPalette.values) {
        expect(p.colorScheme.onPrimary, p.onPrimary);
        expect(p.colorScheme.error, p.error);
        expect(p.colorScheme.onError, p.onError);
      }
    });
  });

  group('switchTheme', () {
    const selected = {WidgetState.selected};
    test('dark palettes use a primaryInk track and a bg thumb', () {
      for (final (p, track, thumb) in [
        (ColorPalette.neutralDark, 0xFF93BAA8, 0xFF121413),
        (ColorPalette.slateDark, 0xFF8DB5CC, 0xFF121418),
      ]) {
        final t = p.toThemeData().switchTheme;
        expect(t.trackColor!.resolve(selected), Color(track));
        expect(t.thumbColor!.resolve(selected), Color(thumb));
      }
    });
    test('light palettes use a primary track and an onPrimary thumb', () {
      for (final (p, track, thumb) in [
        (ColorPalette.neutralLight, 0xFF2E5244, 0xFFF5F5F2),
        (ColorPalette.slateLight, 0xFF1C4558, 0xFFF3F5F7),
      ]) {
        final t = p.toThemeData().switchTheme;
        expect(t.trackColor!.resolve(selected), Color(track));
        expect(t.thumbColor!.resolve(selected), Color(thumb));
      }
    });
    test('unselected and disabled states keep the Material defaults', () {
      for (final p in ColorPalette.values) {
        final t = p.toThemeData().switchTheme;
        for (final states in [
          <WidgetState>{},
          {WidgetState.disabled, WidgetState.selected},
        ]) {
          expect(t.trackColor!.resolve(states), isNull);
          expect(t.thumbColor!.resolve(states), isNull);
        }
      }
    });
  });
}
