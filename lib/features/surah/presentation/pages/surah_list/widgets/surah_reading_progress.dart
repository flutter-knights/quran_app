import 'package:quran/quran.dart' as quran;
import 'package:quran_app/features/surah/domain/entities/last_read.dart';

/// Reading progress expressed relative to the *current surah* (not the whole
/// 604-page mushaf). Ayah-based when the last-read ayah is known, else derived
/// from the page's position within the surah's page range.
class SurahProgress {
  final int surahNumber;
  final String surahArabicName;
  final int page;
  final bool ayahBased;
  final int? ayahCurrent; // null when page-based
  final int ayahTotal; // total ayahs in the surah
  final double fraction; // 0..1

  const SurahProgress({
    required this.surahNumber,
    required this.surahArabicName,
    required this.page,
    required this.ayahBased,
    required this.ayahCurrent,
    required this.ayahTotal,
    required this.fraction,
  });
}

SurahProgress computeSurahProgress(LastRead last) {
  final hasAyah = last.ayah != null && last.ayah!.ayah > 0;
  final surah = hasAyah ? last.ayah!.surah : _firstSurahOfPage(last.page);
  final total = quran.getVerseCount(surah);

  if (hasAyah) {
    final current = last.ayah!.ayah.clamp(1, total);
    return SurahProgress(
      surahNumber: surah,
      surahArabicName: quran.getSurahNameArabic(surah),
      page: last.page,
      ayahBased: true,
      ayahCurrent: current,
      ayahTotal: total,
      fraction: current / total,
    );
  }

  final firstPage = quran.getPageNumber(surah, 1);
  final lastPage = quran.getPageNumber(surah, total);
  final span = (lastPage - firstPage + 1).clamp(1, 604);
  final pos = (last.page - firstPage + 1).clamp(1, span);
  return SurahProgress(
    surahNumber: surah,
    surahArabicName: quran.getSurahNameArabic(surah),
    page: last.page,
    ayahBased: false,
    ayahCurrent: null,
    ayahTotal: total,
    fraction: pos / span,
  );
}

int _firstSurahOfPage(int page) {
  final data = quran.getPageData(page).cast<Map>();
  final valid = data.firstWhere(
    (e) => !(e['start'] == 0 && e['end'] == 0),
    orElse: () => const {},
  );
  return (valid['surah'] as int?) ?? 1;
}
