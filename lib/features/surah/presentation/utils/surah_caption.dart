import 'package:flutter/widgets.dart';
import 'package:quran/quran.dart' as quran;
import 'package:quran_app/core/helper%20functions/locale_helpers.dart';
import 'package:quran_app/core/localization/pending_s.dart';
import 'package:quran_app/generated/l10n.dart';

String surahCaption(BuildContext context, int surah) {
  final strings = S.of(context);
  return PendingS.of(context).mushaf_surahCaption(
    quran.getPlaceOfRevelation(surah) == 'Makkah'
        ? strings.makkiyya
        : strings.madaniyya,
    strings.ayahs_count(quran.getVerseCount(surah).toLocalized(context)),
  );
}
