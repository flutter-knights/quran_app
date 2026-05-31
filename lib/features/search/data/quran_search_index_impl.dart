// lib/features/search/data/quran_search_index_impl.dart
import 'package:quran/quran.dart' as quran;
import 'package:quran/quran_text.dart' as display_text;
import 'package:quran/quran_text_normal.dart' as corpus;
import 'package:quran_app/core/helper%20functions/arabic_normalizer.dart';

import '../domain/entities/search_result.dart';
import '../domain/repositories/quran_search_index.dart';

class _IndexedAyah {
  final int surah;
  final int ayah;
  final String text;
  final String norm;
  const _IndexedAyah(this.surah, this.ayah, this.text, this.norm);
}

/// In-memory normalized index over the 6,236-ayah corpus + the 114 surahs.
/// Built once (registered as a lazy singleton). Ayah pages are computed lazily
/// per match (≤ limit) to avoid a 6k× page lookup at build time.
class QuranSearchIndexImpl implements QuranSearchIndex {
  QuranSearchIndexImpl._(this._ayahs, this._surahs, this._surahNorms);

  final List<_IndexedAyah> _ayahs;
  final List<SurahResult> _surahs;
  final List<String> _surahNorms; // parallel to _surahs: "arabic english number"

  factory QuranSearchIndexImpl.build() {
    final ayahs = <_IndexedAyah>[];
    for (final raw in corpus.quran_text_normal) {
      final e = raw as Map;
      final s = e['surah_number'] as int;
      final a = e['verse_number'] as int;
      final t = e['content'] as String;
      final display = display_text.quranData[s]?[a] ?? t;
      ayahs.add(_IndexedAyah(s, a, display, normalizeArabic(t)));
    }

    final surahs = <SurahResult>[];
    final surahNorms = <String>[];
    for (int id = 1; id <= 114; id++) {
      final ar = quran.getSurahNameArabic(id);
      final en = quran.getSurahNameEnglish(id);
      surahs.add(SurahResult(
        number: id,
        arabicName: ar,
        englishName: en,
        ayahCount: quran.getVerseCount(id),
        revelationPlace: quran.getPlaceOfRevelation(id),
        page: quran.getPageNumber(id, 1),
      ));
      surahNorms.add('${normalizeArabic(ar)} ${en.toLowerCase()} $id');
    }
    return QuranSearchIndexImpl._(ayahs, surahs, surahNorms);
  }

  @override
  List<SurahResult> searchSurahNames(String nq) {
    final out = <SurahResult>[];
    for (int i = 0; i < _surahs.length; i++) {
      if (_surahNorms[i].contains(nq)) out.add(_surahs[i]);
    }
    return out;
  }

  @override
  ({List<AyahResult> results, int total}) searchAyahText(String nq,
      {int limit = 100}) {
    final results = <AyahResult>[];
    int total = 0;
    for (final a in _ayahs) {
      if (!a.norm.contains(nq)) continue;
      total++;
      if (results.length < limit) {
        results.add(AyahResult(
          surah: a.surah,
          ayah: a.ayah,
          text: a.text,
          surahArabicName: quran.getSurahNameArabic(a.surah),
          page: quran.getPageNumber(a.surah, a.ayah),
        ));
      }
    }
    return (results: results, total: total);
  }
}
