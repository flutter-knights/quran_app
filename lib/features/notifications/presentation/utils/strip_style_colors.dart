import 'package:flutter/painting.dart';
import 'package:quran_app/config/theme/app_palette.dart';
import 'package:quran_app/core/constants/color_palette.dart';
import 'package:quran_app/features/notifications/domain/entities/strip_render_style.dart';
import 'package:quran_app/features/notifications/domain/entities/strip_style.dart';

const _pillTextDay = Color(0xFFFFFFFF);
const _pillTextNight = Color(0xFF121413);

Color stripHighlightSwatch(
  StripHighlight h,
  ColorPalette palette, {
  bool night = false,
}) {
  final (day, dark) = switch (h) {
    StripHighlight.app => (palette.primary, _appNight(palette)),
    StripHighlight.darkGreen => (
      const Color(0xFF4A7C6A),
      const Color(0xFF8FC4AE),
    ),
    StripHighlight.emerald => (
      const Color(0xFF1E7A57),
      const Color(0xFF7FD1AE),
    ),
    StripHighlight.blue => (const Color(0xFF2F5F98), const Color(0xFF8EBBE3)),
    StripHighlight.indigo => (const Color(0xFF4B4FA6), const Color(0xFFA9ABEB)),
    StripHighlight.maroon => (const Color(0xFF9A3B3B), const Color(0xFFE7A3A3)),
    StripHighlight.bronze => (const Color(0xFF8A5A14), const Color(0xFFDDB77A)),
  };
  return night ? dark : day;
}

Color? stripBackgroundSwatch(StripBackground b, {bool night = false}) {
  final pair = switch (b) {
    StripBackground.auto => null,
    StripBackground.mint => (const Color(0xFFE3EFEA), const Color(0xFF16302A)),
    StripBackground.sand => (const Color(0xFFF3ECDD), const Color(0xFF2E2A20)),
    StripBackground.sky => (const Color(0xFFE3ECF5), const Color(0xFF1B2735)),
    StripBackground.rose => (const Color(0xFFF4E4E6), const Color(0xFF33201F)),
  };
  if (pair == null) return null;
  return night ? pair.$2 : pair.$1;
}

StripRenderStyle stripRenderStyle(StripStyle style, ColorPalette palette) =>
    StripRenderStyle(
      expanded: style.expanded,
      countdown: style.showCountdown,
      highlightDay: stripHighlightSwatch(style.highlight, palette).toARGB32(),
      highlightNight: stripHighlightSwatch(
        style.highlight,
        palette,
        night: true,
      ).toARGB32(),
      pillTextDay: _pillTextDay.toARGB32(),
      pillTextNight: _pillTextNight.toARGB32(),
      backgroundDay: stripBackgroundSwatch(style.background)?.toARGB32(),
      backgroundNight: stripBackgroundSwatch(
        style.background,
        night: true,
      )?.toARGB32(),
      shape: style.shape.name,
    );

Color _appNight(ColorPalette palette) => switch (palette) {
  ColorPalette.neutralDark ||
  ColorPalette.neutralLight => const Color(0xFF93BAA8),
  ColorPalette.slateDark || ColorPalette.slateLight => const Color(0xFF8DB5CC),
};
