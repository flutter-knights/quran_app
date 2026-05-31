import '../entities/search_result.dart';

abstract class QuranSearchIndex {
  /// [normalizedQuery] is already normalized via normalizeArabic and non-empty.
  List<SurahResult> searchSurahNames(String normalizedQuery);

  /// Returns up to [limit] ayah matches plus the total match count (for the
  /// "+N more" footer).
  ({List<AyahResult> results, int total}) searchAyahText(
    String normalizedQuery, {
    int limit,
  });
}
