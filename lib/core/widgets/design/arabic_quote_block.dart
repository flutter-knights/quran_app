import 'package:flutter/material.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/widgets/design/surface_card.dart';

/// `SurfaceCard` with primary leading accent + Amiri Quran text, line-height 2.1.
/// Generic — works for hadith Arabic text, ayah text, du'a text, etc.
class ArabicQuoteBlock extends StatelessWidget {
  const ArabicQuoteBlock(this.text, {super.key, this.fontSize = 23});

  final String text;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      accentColor: scheme.primary,
      child: Text(
        text,
        textAlign: TextAlign.right,
        textDirection: TextDirection.rtl,
        style: TS.regular16.scheherazade.copyWith(
          fontSize: fontSize,
          height: 2.1,
          color: scheme.onSurface,
        ),
      ),
    );
  }
}
