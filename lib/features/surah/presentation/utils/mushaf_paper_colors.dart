import 'package:flutter/material.dart';
import 'package:quran_app/core/constants/mushaf_paper.dart';

class MushafPaperColors {
  const MushafPaperColors({
    required this.background,
    required this.ink,
    required this.accent,
  });
  final Color background; // page fill
  final Color ink; // body srcIn tint
  final Color accent; // accent (frame + rosettes + glyph) srcIn tint

  Color get ink2 => Color.alphaBlend(ink.withValues(alpha: 0.78), background);
  Color get leaf => Color.alphaBlend(ink.withValues(alpha: 0.06), background);
}

extension MushafPaperX on MushafPaper {
  bool get isDark =>
      this == MushafPaper.night || this == MushafPaper.slateNight;

  MushafPaperColors get colors => switch (this) {
    MushafPaper.cream => const MushafPaperColors(
      background: Color(0xFFFDF7E8),
      ink: Color(0xFF1B1A17),
      accent: Color(0xFF9A7B3C),
    ),
    MushafPaper.sepia => const MushafPaperColors(
      background: Color(0xFFF3E6C9),
      ink: Color(0xFF2B2116),
      accent: Color(0xFF8A5A2B),
    ),
    MushafPaper.green => const MushafPaperColors(
      background: Color(0xFFEEF3E8),
      ink: Color(0xFF18231B),
      accent: Color(0xFF2F6E55),
    ),
    MushafPaper.gray => const MushafPaperColors(
      background: Color(0xFFFAFAF7),
      ink: Color(0xFF161616),
      accent: Color(0xFF1F5E7A),
    ),
    MushafPaper.night => const MushafPaperColors(
      background: Color(0xFF141210),
      ink: Color(0xFFECE3CF),
      accent: Color(0xFFC9A45A),
    ),
    MushafPaper.slateNight => const MushafPaperColors(
      background: Color(0xFF0F141A),
      ink: Color(0xFFDCE5EC),
      accent: Color(0xFF6E9CC4),
    ),
  };
}
