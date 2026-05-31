import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/constants/mushaf_paper.dart';
import 'package:quran_app/features/surah/presentation/utils/mushaf_paper_colors.dart';

void main() {
  test('there are exactly six paper themes', () {
    expect(MushafPaper.values.length, 6);
  });

  test('cream is the eye-tuned default day paper', () {
    final c = MushafPaper.cream.colors;
    expect(c.background, const Color(0xFFFBF4E3));
    expect(c.ink, const Color(0xFF2A2419));
    expect(c.accent, const Color(0xFF2E5244));
  });

  test('night uses an off-black background and warm ink (no halation)', () {
    final c = MushafPaper.night.colors;
    expect(c.background, const Color(0xFF14161A));
    expect(c.ink, const Color(0xFFE8D9A8));
  });

  test('every theme exposes a non-empty Arabic label', () {
    for (final p in MushafPaper.values) {
      expect(p.label, isNotEmpty, reason: p.name);
    }
  });
}
