import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/constants/mushaf_paper.dart';
import 'package:quran_app/features/surah/presentation/utils/mushaf_paper_colors.dart';

void main() {
  const scheme = ColorScheme.light(
    surface: Color(0xFFF4F4F4),
    onSurface: Color(0xFF141414),
    secondary: Color(0xFF5C8070),
  );

  test('parchment has fixed colors', () {
    final c = MushafPaper.parchment.colors(scheme, mushafBg: const Color(0xFFFFFCF5));
    expect(c.background, const Color(0xFFF0E6D2));
    expect(c.ink, const Color(0xFF3A2A14));
    expect(c.accent, const Color(0xFF8A6D3B));
  });

  test('default follows the app scheme + mushaf bg', () {
    final c = MushafPaper.defaultPaper.colors(scheme, mushafBg: const Color(0xFFFFFCF5));
    expect(c.background, const Color(0xFFFFFCF5));
    expect(c.ink, scheme.onSurface);
    expect(c.accent, scheme.secondary);
  });
}
