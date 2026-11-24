import 'package:flutter/widgets.dart';
import 'package:quran/quran.dart' as quran;

import '../../../../core/helper functions/locale_helpers.dart';
import '../../../../core/helper functions/numeral_helpers.dart';
import '../../../../core/localization/pending_s.dart';
import '../../../../generated/l10n.dart';
import '../../../quran_playback/domain/entities/ayah_identifier.dart';
import '../../../quran_playback/domain/entities/reciter.dart';

String ayahVerseText(AyahIdentifier ayah) {
  final verse = quran.getVerse(ayah.surah, ayah.ayah);
  final hasBasmala = ayah.ayah == 1 && ayah.surah != 1 && ayah.surah != 9;
  if (!hasBasmala) return verse;
  return verse.split(RegExp(r'\s+')).skip(4).join(' ').trim();
}

String ayahLabel(BuildContext context, AyahIdentifier ayah, S s) =>
    s.ayah_label(
      surahDisplayName(context, ayah.surah),
      ayah.ayah.toLocalized(context),
    );

String reelShareLabel(BuildContext context, AyahIdentifier first, int count) =>
    count == 1
    ? ayahLabel(context, first, S.of(context))
    : PendingS.of(context).ayah_range_label(
        surahDisplayName(context, first.surah),
        first.ayah.toLocalized(context),
        (first.ayah + count - 1).toLocalized(context),
      );

String ayahShareText(BuildContext context, AyahIdentifier ayah) =>
    '${ayahVerseText(ayah)} — ${ayahLabel(context, ayah, S.of(context))}';

String reelFooter(Reciter reciter, AyahIdentifier first, int count) {
  final last = first.ayah + count - 1;
  final range = count == 1 ? '${first.ayah}' : '${first.ayah}–$last';
  final surah = PendingS.forLanguage(
    'ar',
  ).mushaf_surahTitle(quran.getSurahNameArabic(first.surah));
  return '${reciter.arabicName} · $surah ${range.toIndicNumerals('ar')}';
}
