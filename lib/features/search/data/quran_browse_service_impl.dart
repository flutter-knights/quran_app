import 'package:quran/juz_data.dart' as jd;
import 'package:quran/quran.dart' as quran;

import '../domain/entities/juz_browse_entry.dart';
import '../domain/services/quran_browse_service.dart';

class QuranBrowseServiceImpl implements QuranBrowseService {
  @override
  int firstPageOfJuz(int juz) {
    final entry = jd.juz[juz - 1];
    final surahs = (entry['surahs'] as List).cast<int>();
    final firstSurah = surahs.first;
    final verses = entry['verses'] as Map;
    final startVerse = (verses[firstSurah] as List).first as int;
    return quran.getPageNumber(firstSurah, startVerse);
  }

  @override
  List<JuzBrowseEntry> juzEntries() {
    return List.generate(30, (i) {
      final n = i + 1;
      final surahs = (jd.juz[i]['surahs'] as List).cast<int>();
      return JuzBrowseEntry(
        number: n,
        firstPage: firstPageOfJuz(n),
        firstSurahArabicName: quran.getSurahNameArabic(surahs.first),
        lastSurahArabicName: quran.getSurahNameArabic(surahs.last),
      );
    });
  }
}
