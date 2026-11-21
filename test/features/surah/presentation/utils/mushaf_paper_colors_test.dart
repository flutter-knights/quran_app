import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/constants/mushaf_paper.dart';
import 'package:quran_app/features/surah/presentation/utils/mushaf_paper_colors.dart';

void main() {
  test('there are exactly six paper themes', () {
    expect(MushafPaper.values.length, 6);
  });

  test('persisted paper names are unchanged', () {
    expect(MushafPaper.values.map((p) => p.name), [
      'cream',
      'sepia',
      'green',
      'gray',
      'night',
      'slateNight',
    ]);
  });

  const expected = {
    MushafPaper.cream: (0xFFFDF7E8, 0xFF1B1A17, 0xFF9A7B3C),
    MushafPaper.sepia: (0xFFF3E6C9, 0xFF2B2116, 0xFF8A5A2B),
    MushafPaper.green: (0xFFEEF3E8, 0xFF18231B, 0xFF2F6E55),
    MushafPaper.gray: (0xFFFAFAF7, 0xFF161616, 0xFF1F5E7A),
    MushafPaper.night: (0xFF141210, 0xFFECE3CF, 0xFFC9A45A),
    MushafPaper.slateNight: (0xFF0F141A, 0xFFDCE5EC, 0xFF6E9CC4),
  };

  for (final entry in expected.entries) {
    test('${entry.key.name} uses its printed-mushaf triple', () {
      final c = entry.key.colors;
      final (background, ink, accent) = entry.value;
      expect(c.background, Color(background));
      expect(c.ink, Color(ink));
      expect(c.accent, Color(accent));
    });
  }

  test('ink2 and leaf are blends of ink over the background', () {
    for (final p in MushafPaper.values) {
      final c = p.colors;
      expect(
        c.ink2,
        Color.alphaBlend(c.ink.withValues(alpha: 0.78), c.background),
      );
      expect(
        c.leaf,
        Color.alphaBlend(c.ink.withValues(alpha: 0.06), c.background),
      );
    }
  });
}
