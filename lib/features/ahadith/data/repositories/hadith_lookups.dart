import 'package:quran_app/features/ahadith/domain/entities/chapter.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith.dart';

/// Builds, per book slug, a map of API chapter id -> [Chapter] from the bundled
/// `all_chapters.json` structure. Shared by the ahadith and search repositories.
Map<String, Map<int, Chapter>> generateChapterLookups(Map<String, dynamic> raw) {
  return raw.map((bookSlug, chaptersList) {
    final list = chaptersList as List<dynamic>;
    final lookup = {
      for (var item in list)
        item['id'] as int: Chapter(
          id: item['id'],
          chapterNumber: item['chapterNumber'],
          chapterArabic: item['chapterArabic'],
          chapterEnglish: item['chapterEnglish'],
        ),
    };
    return MapEntry(bookSlug, lookup);
  });
}

/// The API's `status` query-param spelling for each grade (note the back-tick in
/// `Da`eef`).
const Map<HadithStatus, String> hadithStatusApiValue = {
  HadithStatus.sahih: 'Sahih',
  HadithStatus.hasan: 'Hasan',
  HadithStatus.daeef: 'Da`eef',
};
