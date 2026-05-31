// test/features/search/search_cubit_test.dart
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/search/domain/entities/juz_browse_entry.dart';
import 'package:quran_app/features/search/domain/entities/search_result.dart';
import 'package:quran_app/features/search/domain/repositories/quran_search_index.dart';
import 'package:quran_app/features/search/domain/services/quran_browse_service.dart';
import 'package:quran_app/features/search/domain/usecases/search_quran.dart';
import 'package:quran_app/features/search/presentation/cubit/search_cubit.dart';
import 'package:quran_app/features/search/presentation/cubit/search_state.dart';

class _FakeIndex implements QuranSearchIndex {
  @override
  List<SurahResult> searchSurahNames(String nq) => const [
        SurahResult(
          number: 55,
          arabicName: 'الرحمن',
          englishName: 'The Beneficent',
          ayahCount: 78,
          revelationPlace: 'Madinah',
          page: 531,
        ),
      ];
  @override
  ({List<AyahResult> results, int total}) searchAyahText(String nq,
          {int limit = 100}) =>
      (results: const <AyahResult>[], total: 0);
}

class _FakeBrowse implements QuranBrowseService {
  @override
  int firstPageOfJuz(int juz) => 1;
  @override
  List<JuzBrowseEntry> juzEntries() => const [];
}

void main() {
  SearchCubit build() => SearchCubit(SearchQuran(_FakeIndex(), _FakeBrowse()));

  blocTest<SearchCubit, SearchState>(
    'non-empty query emits searching then results after debounce',
    build: build,
    act: (c) => c.queryChanged('rahman'),
    wait: const Duration(milliseconds: 350),
    expect: () => [
      isA<SearchState>()
          .having((s) => s.query, 'query', 'rahman')
          .having((s) => s.isSearching, 'isSearching', true),
      isA<SearchState>()
          .having((s) => s.isSearching, 'isSearching', false)
          .having((s) => s.results.surahs.single.number, 'surah', 55),
    ],
  );

  blocTest<SearchCubit, SearchState>(
    'empty query emits idle immediately',
    build: build,
    act: (c) => c.queryChanged('   '),
    expect: () => [
      isA<SearchState>()
          .having((s) => s.query, 'query', '')
          .having((s) => s.results.isEmpty, 'empty', true),
    ],
  );
}
