import 'package:flutter/widgets.dart';
import 'package:quran/quran.dart' as quran;

import '../../../../core/helper functions/locale_helpers.dart';
import '../../../../generated/l10n.dart';
import '../../../quran_playback/domain/entities/ayah_identifier.dart';

String ayahVerseText(AyahIdentifier ayah) {
  final verse = quran.getVerse(ayah.surah, ayah.ayah);
  final hasBasmala = ayah.ayah == 1 && ayah.surah != 1 && ayah.surah != 9;
  if (!hasBasmala) return verse;
  return verse.split(RegExp(r'\s+')).skip(4).join(' ').trim();
}

String ayahShareText(BuildContext context, AyahIdentifier ayah) =>
    '${ayahVerseText(ayah)} — ${S.of(context).ayah_label(surahDisplayName(context, ayah.surah), ayah.ayah.toLocalized(context))}';
