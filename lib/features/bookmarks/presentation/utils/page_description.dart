import 'package:quran/quran.dart' as quran;
import 'package:quran_app/core/helper%20functions/numeral_helpers.dart';

/// Human-readable description of the surah(s) + ayah range(s) on a Mushaf page,
/// e.g. "Al-Baqarah 30–48" / "البقرة ٣٠–٤٨". Skips the basmala pseudo-range
/// (`start == end == 0`). Numerals follow [localeCode] ('ar' → Arabic-Indic).
String describePage(int page, {required String localeCode}) {
  final data = quran.getPageData(page).cast<Map>();
  final parts = <String>[];
  for (final e in data) {
    final start = e['start'] as int;
    final end = e['end'] as int;
    if (start == 0 && end == 0) continue; // basmala marker
    final surah = e['surah'] as int;
    final name = localeCode == 'ar'
        ? quran.getSurahNameArabic(surah)
        : quran.getSurahName(surah);
    final s = start.toString().toIndicNumerals(localeCode);
    final en = end.toString().toIndicNumerals(localeCode);
    parts.add(start == end ? '$name $s' : '$name $s–$en');
  }
  if (parts.isEmpty) {
    final surah = data.isNotEmpty ? data.first['surah'] as int : 1;
    return localeCode == 'ar'
        ? quran.getSurahNameArabic(surah)
        : quran.getSurahName(surah);
  }
  return parts.join(localeCode == 'ar' ? '، ' : ', ');
}
