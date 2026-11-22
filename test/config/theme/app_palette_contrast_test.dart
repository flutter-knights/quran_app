import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/config/theme/app_palette.dart';
import 'package:quran_app/core/constants/color_palette.dart';

double contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (max(la, lb) + 0.05) / (min(la, lb) + 0.05);
}

void main() {
  for (final p in ColorPalette.values) {
    test('$p text contrast', () {
      expect(contrast(p.onSurface, p.bg), greaterThanOrEqualTo(4.5));
      expect(contrast(p.onSurface, p.surface), greaterThanOrEqualTo(4.5));
      expect(contrast(p.onSurfaceVar, p.bg), greaterThanOrEqualTo(4.5));
      expect(contrast(p.onSurfaceVar, p.surface), greaterThanOrEqualTo(4.5));
      expect(contrast(p.primaryInk, p.surface), greaterThanOrEqualTo(3));
    });
    test('$p fill contrast', () {
      expect(contrast(p.onPrimary, p.primary), greaterThanOrEqualTo(4.5));
      expect(contrast(p.onError, p.error), greaterThanOrEqualTo(4.5));
    });
    test('$p text and outlined buttons read on cards', () {
      final theme = p.toThemeData();
      for (final style in [
        theme.textButtonTheme.style,
        theme.outlinedButtonTheme.style,
      ]) {
        final ink = style?.foregroundColor?.resolve({});
        expect(ink, isNotNull);
        expect(contrast(ink!, p.surface), greaterThanOrEqualTo(4.5));
        expect(contrast(ink, p.bg), greaterThanOrEqualTo(4.5));
      }
    });
    test('$p snack bar action reads on the snack bar', () {
      final scheme = p.toThemeData().colorScheme;
      expect(
        contrast(scheme.inversePrimary, scheme.inverseSurface),
        greaterThanOrEqualTo(4.5),
      );
    });
  }
}
