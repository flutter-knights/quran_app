// test/features/search/search_quran_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/search/domain/entities/juz_browse_entry.dart';
import 'package:quran_app/features/search/domain/entities/search_result.dart';
import 'package:quran_app/features/search/domain/repositories/quran_search_index.dart';
import 'package:quran_app/features/search/domain/services/quran_browse_service.dart';
import 'package:quran_app/features/search/domain/usecases/search_quran.dart';

class _FakeIndex implements QuranSearchIndex {
  @override
  List<SurahResult> searchSurahNames(String nq) {
    if (nq.contains('رحمن') || nq.contains('rahman')) {
      return const [
        SurahResult(
          number: 55,
          arabicName: 'الرحمن',
          englishName: 'The Beneficent',
          ayahCount: 78,
          revelationPlace: 'Madinah',
          page: 531,
        ),
      ];
    }
    return const [];
  }

  @override
  ({List<AyahResult> results, int total}) searchAyahText(String nq,
      {int limit = 100}) {
    if (nq.contains('رحمن')) {
      return (
        results: const [
          AyahResult(
            surah: 1,
            ayah: 1,
            text: 'بسم الله الرحمان الرحيم',
            surahArabicName: 'الفاتحة',
            page: 1,
          ),
        ],
        total: 3,
      );
    }
    return (results: const <AyahResult>[], total: 0);
  }
}

class _FakeBrowse implements QuranBrowseService {
  @override
  int firstPageOfJuz(int juz) => juz * 20; // deterministic stub
  @override
  List<JuzBrowseEntry> juzEntries() => const [];
}

void main() {
  final sut = SearchQuran(_FakeIndex(), _FakeBrowse());

  test('empty query returns empty results', () {
    final r = sut('   ');
    expect(r.isEmpty, isTrue);
    expect(identical(r, SearchResults.empty), isTrue);
  });

  test('numeric query in page range adds a page suggestion', () {
    final r = sut('50');
    expect(r.suggestions, hasLength(1));
    expect(r.suggestions.first.kind, JumpKind.page);
    expect(r.suggestions.first.page, 50);
  });

  test('numeric query in juz range adds both page and juz suggestions', () {
    final r = sut('5');
    expect(r.suggestions.map((s) => s.kind),
        containsAll([JumpKind.page, JumpKind.juz]));
    final juz = r.suggestions.firstWhere((s) => s.kind == JumpKind.juz);
    expect(juz.page, 100); // _FakeBrowse.firstPageOfJuz(5) == 100
  });

  test('out-of-range number yields no suggestions', () {
    expect(sut('999').suggestions, isEmpty);
  });

  test('arabic text query returns grouped surah + ayah matches', () {
    final r = sut('الرحمن');
    expect(r.surahs.single.number, 55);
    expect(r.ayahs.single.surah, 1);
    expect(r.ayahTotalMatches, 3);
  });
}
