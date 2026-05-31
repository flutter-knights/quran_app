import 'package:quran/quran.dart' as quran;

/// What the printed header band displays for a page.
class PrintedChromeData {
  const PrintedChromeData({
    required this.surahNumber,
    required this.juzNumber,
    required this.surahGlyphName,
    required this.juzGlyphName,
  });

  final int surahNumber;
  final int juzNumber;

  /// QCF glyph string (render with the `QCF2BSML` font family). Falls back to
  /// the plain Arabic surah name if the glyph map throws for this number.
  final String surahGlyphName;
  final String juzGlyphName;
}

/// Resolves the surah + juz shown on [pageNumber]'s printed header band, using
/// the page's leading ayah (the physical-mushaf convention).
PrintedChromeData resolvePrintedChrome(int pageNumber) {
  final data = quran.getPageData(pageNumber); // [{surah, start, end}, ...]
  final firstSurah = data.isNotEmpty ? data.first['surah'] as int : 1;
  final firstStart = data.isNotEmpty ? data.first['start'] as int : 1;
  // Basmala marker is start==0; treat as ayah 1 for juz lookup.
  final firstAyah = firstStart == 0 ? 1 : firstStart;
  final juz = quran.getJuzNumber(firstSurah, firstAyah);

  String surahGlyph;
  try {
    surahGlyph = quran.getQcfSurahName(firstSurah);
  } catch (_) {
    surahGlyph = quran.getSurahNameArabic(firstSurah);
  }
  String juzGlyph;
  try {
    juzGlyph = quran.getQcfJuzName(juz);
  } catch (_) {
    juzGlyph = 'الجزء $juz';
  }

  return PrintedChromeData(
    surahNumber: firstSurah,
    juzNumber: juz,
    surahGlyphName: surahGlyph,
    juzGlyphName: juzGlyph,
  );
}
