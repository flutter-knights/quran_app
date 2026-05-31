import 'package:flutter/material.dart';
import 'package:quran_app/core/constants/mushaf_paper.dart';

class MushafPaperColors {
  const MushafPaperColors({
    required this.background,
    required this.ink,
    required this.accent,
  });
  final Color background; // page fill
  final Color ink;        // body srcIn tint
  final Color accent;     // accent (frame + rosettes + glyph) srcIn tint
}

extension MushafPaperX on MushafPaper {
  /// Arabic display label for the reading-settings sheet.
  String get label => switch (this) {
        MushafPaper.cream => 'كريمي',
        MushafPaper.sepia => 'سيبيا',
        MushafPaper.green => 'أخضر',
        MushafPaper.gray => 'رمادي',
        MushafPaper.night => 'ليلي',
        MushafPaper.slateNight => 'ليلي أزرق',
      };

  bool get isDark => this == MushafPaper.night || this == MushafPaper.slateNight;

  MushafPaperColors get colors => switch (this) {
        MushafPaper.cream => const MushafPaperColors(
            background: Color(0xFFFBF4E3),
            ink: Color(0xFF2A2419),
            accent: Color(0xFF2E5244)),
        MushafPaper.sepia => const MushafPaperColors(
            background: Color(0xFFEDE0C4),
            ink: Color(0xFF3A2A14),
            accent: Color(0xFF8A6D3B)),
        MushafPaper.green => const MushafPaperColors(
            background: Color(0xFFE2EBE2),
            ink: Color(0xFF1B3A26),
            accent: Color(0xFF3C7A55)),
        MushafPaper.gray => const MushafPaperColors(
            background: Color(0xFFE8E6E1),
            ink: Color(0xFF33302A),
            accent: Color(0xFF6B6456)),
        MushafPaper.night => const MushafPaperColors(
            background: Color(0xFF14161A),
            ink: Color(0xFFE8D9A8),
            accent: Color(0xFFC9A227)),
        MushafPaper.slateNight => const MushafPaperColors(
            background: Color(0xFF10141A),
            ink: Color(0xFFD6E2EC),
            accent: Color(0xFF4878A0)),
      };
}
