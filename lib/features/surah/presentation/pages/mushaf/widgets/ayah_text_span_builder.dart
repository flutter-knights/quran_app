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
    final List<InlineSpan> spans = [];
    int currentSurahIndex = 0;

    for (int i = 0; i < page.ayahs.length; i++) {
      if (page.surahHeadersIndexes.contains(i)) {
        spans.add(
          WidgetSpan(
            child: SizedBox(
              width: pageWidth,
              child: SurahHeader(
                name: page.surahNames[currentSurahIndex],
                surahNumber: 1, // TODO: inject real value
                verseCount: 1, // TODO: inject real value
              ),
            ),
          ),
        );

        if (page.showBasmalaList[currentSurahIndex]) {
          spans.add(BasmalaText(fontSize: fontSize, lineHeight: lineHeight));
        }

        currentSurahIndex++;
      }
      final ayahId = page.ayahIdentifiers[i];

      final bool isHighlighted =
          currentAyah != null &&
          currentAyah.surah == ayahId.surah &&
          currentAyah.ayah == ayahId.ayah;

      spans.add(
        TextSpan(
          locale: const Locale('ar'),
          text: page.ayahs[i],
          style: TextStyle(
            fontFamily: "QCF_P${pageNumber.toString().padLeft(3, "0")}",
            fontSize: fontSize,
            height: lineHeight / fontSize,
            color: isHighlighted
                ? context.colorScheme.onPrimary
                : context.colorScheme.onSurface,
            backgroundColor: isHighlighted ? context.colorScheme.primary : null,
          ),
        ),
      );
    }

    return spans;
  }
}
