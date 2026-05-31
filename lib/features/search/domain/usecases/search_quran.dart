// lib/features/search/domain/usecases/search_quran.dart
import 'package:quran_app/core/helper%20functions/arabic_normalizer.dart';

import '../entities/search_result.dart';
import '../repositories/quran_search_index.dart';
import '../services/quran_browse_service.dart';

/// Comprehensive Quran search: number-jump suggestions (page/juzʼ), surah-name
/// matches, and ayah-text matches, grouped into [SearchResults].
class SearchQuran {
  final QuranSearchIndex _index;
  final QuranBrowseService _browse;
  const SearchQuran(this._index, this._browse);

  static const int ayahLimit = 100;

  SearchResults call(String rawQuery) {
    final trimmed = rawQuery.trim();
    if (trimmed.isEmpty) return SearchResults.empty;

    final suggestions = _numberJump(trimmed);
    final nq = normalizeArabic(trimmed);
    if (nq.isEmpty) {
      return SearchResults(
        suggestions: suggestions,
        surahs: const [],
        ayahs: const [],
        ayahTotalMatches: 0,
      );
    }
    final surahs = _index.searchSurahNames(nq);
    final ayah = _index.searchAyahText(nq, limit: ayahLimit);
    return SearchResults(
      suggestions: suggestions,
      surahs: surahs,
      ayahs: ayah.results,
      ayahTotalMatches: ayah.total,
    );
  }

  List<JumpSuggestion> _numberJump(String query) {
    final n = int.tryParse(query);
    if (n == null) return const [];
    final out = <JumpSuggestion>[];
    if (n >= 1 && n <= 604) {
      out.add(JumpSuggestion(kind: JumpKind.page, number: n, page: n));
    }
    if (n >= 1 && n <= 30) {
      out.add(JumpSuggestion(
        kind: JumpKind.juz,
        number: n,
        page: _browse.firstPageOfJuz(n),
      ));
    }
    return out;
  }
}
