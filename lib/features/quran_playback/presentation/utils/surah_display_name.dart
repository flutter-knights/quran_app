import 'package:flutter/widgets.dart';
import 'package:quran/quran.dart' as quran;
import 'package:quran_app/core/helper functions/locale_helpers.dart';

String surahDisplayName(BuildContext context, int surah) => context.isArabic
    ? quran.getSurahNameArabic(surah)
    : quran.getSurahName(surah);
