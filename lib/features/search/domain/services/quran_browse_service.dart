import '../entities/juz_browse_entry.dart';

abstract class QuranBrowseService {
  /// First mushaf page of the given juzʼ (1..30).
  int firstPageOfJuz(int juz);

  /// The 30 ajzaʼ, each with its first page and surah span (for browse mode).
  List<JuzBrowseEntry> juzEntries();
}
