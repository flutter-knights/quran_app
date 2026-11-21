import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/constants/mushaf_paper.dart';
import 'package:quran_app/features/surah/presentation/utils/mushaf_paper_colors.dart';

double contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (max(la, lb) + 0.05) / (min(la, lb) + 0.05);
}

void main() {
  for (final p in MushafPaper.values) {
    group(p.name, () {
      final c = p.colors;
      final accentTint = Color.alphaBlend(
        c.accent.withValues(alpha: 0.20),
        c.background,
      );
      final inkTint = Color.alphaBlend(
        c.ink.withValues(alpha: 0.15),
        c.background,
      );
      final stacked = Color.alphaBlend(
        c.ink.withValues(alpha: 0.15),
        accentTint,
      );

      test('ink on background is at least 7', () {
        expect(contrast(c.ink, c.background), greaterThanOrEqualTo(7));
      });

      test('ink2 on background is at least 4.5', () {
        expect(contrast(c.ink2, c.background), greaterThanOrEqualTo(4.5));
      });

      test('accent on background is at least 3', () {
        expect(contrast(c.accent, c.background), greaterThanOrEqualTo(3));
      });

      test('ink stays readable on the accent tint', () {
        expect(contrast(c.ink, accentTint), greaterThanOrEqualTo(4.5));
      });

      test('ink stays readable on the ink tint', () {
        expect(contrast(c.ink, inkTint), greaterThanOrEqualTo(4.5));
      });

      test('ink stays readable on both tints stacked', () {
        expect(contrast(c.ink, stacked), greaterThanOrEqualTo(4.5));
      });
    });
  }
}
