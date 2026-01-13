import 'package:flutter/material.dart';

import 'package:quran_app/features/surah/domain/entities/mushaf_page_entity.dart';
import '../../../../../../config/theme/color_scheme.dart';
import '../../../../../quran_playback/domain/entities/ayah_identifier.dart';
import 'basmala_text.dart';
import 'surah_header.dart';

class AyahTextSpanBuilder {
  static List<InlineSpan> build({
    required BuildContext context,
    required MushafPageEntity page,
    required int pageNumber,
    required double fontSize,
    required double lineHeight,
    required double pageWidth,
    required AyahIdentifier? currentAyah,
  }) {
    final spans = <InlineSpan>[];

    final headerIndexes = page.surahHeadersIndexes.toSet();
    final basmalaIndexes = page.basmalaIndexes.toSet();

    int currentSurahIndex = 0;

    final normalStyle = TextStyle(
      fontFamily: "QCF_P${pageNumber.toString().padLeft(3, "0")}",
      fontSize: fontSize,
      height: lineHeight / fontSize,
      color: context.colorScheme.onSurface,
    );

    final highlightedStyle = normalStyle.copyWith(
      color: context.colorScheme.onPrimary,
      backgroundColor: context.colorScheme.primary,
    );

    for (int i = 0; i <= page.ayahs.length; i++) {
      // -------- SURAH HEADER --------
      if (headerIndexes.contains(i)) {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: SurahHeader(
              name: page.surahNames[currentSurahIndex],
              surahNumber: 1,
              verseCount: 1,
              fontSize: fontSize,
              lineHeight: lineHeight,
            ),
          ),
        );
        currentSurahIndex++;
      }

      // -------- BASMALA --------
      if (basmalaIndexes.contains(i)) {
        spans.add(
          BasmalaText(
            fontSize: fontSize,
            lineHeight: lineHeight,
            color: context.colorScheme.onSurface,
          ),
        );
      }

      // -------- AYAH TEXT --------
      if (i < page.ayahs.length) {
        final ayahId = page.ayahIdentifiers[i];
        final isHighlighted =
            currentAyah != null &&
            currentAyah.surah == ayahId.surah &&
            currentAyah.ayah == ayahId.ayah;

        spans.add(
          TextSpan(
            locale: const Locale('ar'),
            text: page.ayahs[i],
            style: isHighlighted ? highlightedStyle : normalStyle,
          ),
        );
      }
    }

    return spans;
  }
}
