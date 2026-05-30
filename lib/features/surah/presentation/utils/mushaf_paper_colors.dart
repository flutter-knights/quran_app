import 'package:flutter/material.dart';
import 'package:quran_app/core/constants/mushaf_paper.dart';

class MushafPaperColors {
  const MushafPaperColors({required this.background, required this.ink, required this.accent});
  final Color background; // page fill
  final Color ink;        // body srcIn tint
  final Color accent;     // accent (frame + rosettes) srcIn tint
}

extension MushafPaperX on MushafPaper {
  /// Arabic display label for the bottom-bar swatch tooltip.
  String get label => switch (this) {
        MushafPaper.defaultPaper => 'افتراضي',
        MushafPaper.parchment => 'رق',
        MushafPaper.night => 'ليلي',
        MushafPaper.sky => 'سماوي',
        MushafPaper.mint => 'نعناعي',
      };

  MushafPaperColors colors(ColorScheme scheme, {required Color mushafBg}) {
    switch (this) {
      case MushafPaper.defaultPaper:
        return MushafPaperColors(background: mushafBg, ink: scheme.onSurface, accent: scheme.secondary);
      case MushafPaper.parchment:
        return const MushafPaperColors(background: Color(0xFFF0E6D2), ink: Color(0xFF3A2A14), accent: Color(0xFF8A6D3B));
      case MushafPaper.night:
        return const MushafPaperColors(background: Color(0xFF0D0F12), ink: Color(0xFFE8D9A8), accent: Color(0xFFC9A227));
      case MushafPaper.sky:
        return const MushafPaperColors(background: Color(0xFFEAF1F7), ink: Color(0xFF1A3550), accent: Color(0xFF3C6E9E));
      case MushafPaper.mint:
        return const MushafPaperColors(background: Color(0xFFE4EDE4), ink: Color(0xFF1B3A26), accent: Color(0xFF3C7A55));
    }
  }
}
