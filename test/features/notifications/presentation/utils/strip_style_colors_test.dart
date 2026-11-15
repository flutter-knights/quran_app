import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/constants/color_palette.dart';
import 'package:quran_app/features/notifications/domain/entities/strip_render_style.dart';
import 'package:quran_app/features/notifications/domain/entities/strip_style.dart';
import 'package:quran_app/features/notifications/presentation/utils/strip_style_colors.dart';

void main() {
  test('stripRenderStyle maps enums to day and night ARGB', () {
    final r = stripRenderStyle(
      const StripStyle(
        highlight: StripHighlight.maroon,
        background: StripBackground.sand,
        shape: StripShape.pill,
        showCountdown: false,
      ),
      ColorPalette.neutralLight,
    );
    expect(r.highlightDay, 0xFF9A3B3B);
    expect(r.highlightNight, 0xFFE7A3A3);
    expect(r.pillTextDay, 0xFFFFFFFF);
    expect(r.pillTextNight, 0xFF121413);
    expect(r.backgroundDay, 0xFFF3ECDD);
    expect(r.backgroundNight, 0xFF2E2A20);
    expect(r.shape, StripShape.pill);
    expect(r.countdown, isFalse);
    expect(r.expanded, isTrue);
  });

  test('app highlight uses the palette primary and auto has no background', () {
    final r = stripRenderStyle(const StripStyle(), ColorPalette.slateDark);
    expect(r.highlightDay, 0xFF1C4558);
    expect(r.highlightNight, 0xFF8DB5CC);
    expect(r.backgroundDay, isNull);
    expect(r.backgroundNight, isNull);
    expect(r.shape, StripShape.rounded);
    expect(r.toJson().containsKey('backgroundDay'), isFalse);
    expect(r.toJson().containsKey('backgroundNight'), isFalse);
    expect(r.toJson()['highlightDay'], '#FF1C4558');
  });

  test('neutral app highlight lifts to #93BAA8 at night', () {
    final r = stripRenderStyle(const StripStyle(), ColorPalette.neutralDark);
    expect(r.highlightDay, 0xFF2E5244);
    expect(r.highlightNight, 0xFF93BAA8);
  });

  test('toJson carries every field as the native contract names it', () {
    final json = stripRenderStyle(
      const StripStyle(
        expanded: false,
        highlight: StripHighlight.blue,
        background: StripBackground.rose,
        shape: StripShape.outline,
      ),
      ColorPalette.neutralLight,
    ).toJson();
    expect(json, {
      'expanded': false,
      'countdown': true,
      'highlightDay': '#FF2F5F98',
      'highlightNight': '#FF8EBBE3',
      'highlightTextDay': '#FF2F5F98',
      'pillTextDay': '#FFFFFFFF',
      'pillTextNight': '#FF121413',
      'backgroundDay': '#FFF4E4E6',
      'backgroundNight': '#FF33201F',
      'shape': 'outline',
    });
  });

  test('every highlight has its day and night swatch', () {
    const expected = {
      StripHighlight.darkGreen: (0xFF4A7C6A, 0xFF8FC4AE),
      StripHighlight.emerald: (0xFF1E7A57, 0xFF7FD1AE),
      StripHighlight.blue: (0xFF2F5F98, 0xFF8EBBE3),
      StripHighlight.indigo: (0xFF4B4FA6, 0xFFA9ABEB),
      StripHighlight.maroon: (0xFF9A3B3B, 0xFFE7A3A3),
      StripHighlight.bronze: (0xFF8A5A14, 0xFFDDB77A),
    };
    for (final MapEntry(key: h, value: (day, night)) in expected.entries) {
      expect(
        stripHighlightSwatch(h, ColorPalette.neutralLight),
        Color(day),
        reason: h.name,
      );
      expect(
        stripHighlightSwatch(h, ColorPalette.neutralLight, night: true),
        Color(night),
        reason: h.name,
      );
    }
  });

  test('every background has its day and night swatch, auto has none', () {
    const expected = {
      StripBackground.mint: (0xFFE3EFEA, 0xFF16302A),
      StripBackground.sand: (0xFFF3ECDD, 0xFF2E2A20),
      StripBackground.sky: (0xFFE3ECF5, 0xFF1B2735),
      StripBackground.rose: (0xFFF4E4E6, 0xFF33201F),
    };
    for (final MapEntry(key: b, value: (day, night)) in expected.entries) {
      expect(stripBackgroundSwatch(b), Color(day), reason: b.name);
      expect(
        stripBackgroundSwatch(b, night: true),
        Color(night),
        reason: b.name,
      );
    }
    expect(stripBackgroundSwatch(StripBackground.auto), isNull);
    expect(stripBackgroundSwatch(StripBackground.auto, night: true), isNull);
  });

  test('text-only day highlight darkens darkGreen and emerald to 4.5:1', () {
    StripRenderStyle text(StripHighlight h) => stripRenderStyle(
      StripStyle(highlight: h, shape: StripShape.none),
      ColorPalette.neutralLight,
    );
    expect(text(StripHighlight.darkGreen).highlightTextDay, 0xFF406C5C);
    expect(text(StripHighlight.emerald).highlightTextDay, 0xFF1C7151);
    for (final h in [
      StripHighlight.app,
      StripHighlight.blue,
      StripHighlight.indigo,
      StripHighlight.maroon,
      StripHighlight.bronze,
    ]) {
      expect(text(h).highlightTextDay, text(h).highlightDay, reason: h.name);
    }
  });

  test('swatches default to the day colour', () {
    expect(
      stripHighlightSwatch(StripHighlight.app, ColorPalette.slateLight),
      const Color(0xFF1C4558),
    );
    expect(
      stripHighlightSwatch(
        StripHighlight.app,
        ColorPalette.slateLight,
        night: true,
      ),
      const Color(0xFF8DB5CC),
    );
  });
}
