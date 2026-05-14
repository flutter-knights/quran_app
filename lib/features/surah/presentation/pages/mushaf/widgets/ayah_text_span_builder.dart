import 'package:flutter/material.dart';

import '../../../../../../config/theme/color_scheme.dart';
import '../../../../../quran_playback/domain/entities/ayah_identifier.dart';
import '../../../../domain/entities/mushaf_page_entity.dart';
import 'basmala_text.dart';
import 'surah_header.dart';

class AyahTextSpanBuilder {
  /// Builds the static span tree for a page. Highlight is applied separately
  /// via [buildHighlightOverlay] so ayah-tick rebuilds don't recreate this list.
  static List<InlineSpan> buildBase({
    required BuildContext context,
    required MushafPageEntity page,
    required int pageNumber,
    required double fontSize,
    required double lineHeight,
    required double pageWidth,
    required TextStyle normalStyle,
  }) {
    final spans = <InlineSpan>[];
    final headerIndexes = page.surahHeadersIndexes.toSet();
    final basmalaIndexes = page.basmalaIndexes.toSet();
    var currentSurahIndex = 0;

    for (int i = 0; i <= page.ayahs.length; i++) {
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

      if (basmalaIndexes.contains(i)) {
        spans.add(
          BasmalaText(
            fontSize: fontSize,
            lineHeight: lineHeight,
            color: context.colorScheme.onSurface,
          ),
        );
      }

      if (i < page.ayahs.length) {
        spans.add(
          TextSpan(
            locale: const Locale('ar'),
            text: page.ayahs[i],
            style: normalStyle,
          ),
        );
      }
    }

    return spans;
  }

  /// Returns a new list with the matching ayah's TextSpan replaced by a
  /// highlighted copy. Returns [baseSpans] by identity when [currentAyah] is
  /// null or not present on [page], so callers can skip relayout.
  static List<InlineSpan> buildHighlightOverlay({
    required List<InlineSpan> baseSpans,
    required MushafPageEntity page,
    required AyahIdentifier? currentAyah,
    required TextStyle highlightedStyle,
    required TextStyle normalStyle,
  }) {
    if (currentAyah == null) return baseSpans;
    final ayahIndex = page.ayahIdentifiers.indexWhere(
      (a) => a.surah == currentAyah.surah && a.ayah == currentAyah.ayah,
    );
    if (ayahIndex < 0) return baseSpans;

    final headerIndexes = page.surahHeadersIndexes.toSet();
    final basmalaIndexes = page.basmalaIndexes.toSet();

    var pos = 0;
    for (int i = 0; i <= page.ayahs.length; i++) {
      if (headerIndexes.contains(i)) pos++;
      if (basmalaIndexes.contains(i)) pos++;
      if (i < page.ayahs.length) {
        if (i == ayahIndex) break;
        pos++;
      }
    }

    final original = baseSpans[pos];
    if (original is! TextSpan) return baseSpans;
    final replacement = TextSpan(
      locale: const Locale('ar'),
      text: original.text,
      style: highlightedStyle,
    );
    final result = List<InlineSpan>.of(baseSpans);
    result[pos] = replacement;
    return result;
  }
}
