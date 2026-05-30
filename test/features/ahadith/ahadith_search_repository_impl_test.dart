import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/features/ahadith/data/datasources/local/ahadith_arabic_search_local_data_source.dart';
import 'package:quran_app/features/ahadith/data/datasources/local/ahadith_local_data_source.dart';
import 'package:quran_app/features/ahadith/data/datasources/remote/ahadith_remote_data_source.dart';
import 'package:quran_app/features/ahadith/data/repositories/ahadith_search_repository_impl.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith.dart';

class _MockArabicSearch extends Mock
    implements AhadithArabicSearchLocalDataSource {}

class _MockLocal extends Mock implements AhadithLocalDataSource {}

class _MockRemote extends Mock implements AhadithRemoteDataSource {}

Hadith _h(String number) => Hadith(
      hadithNumber: number,
      englishHadith: 'en',
      arabicHadith: 'ar',
      englishNarrator: '',
      englishHeader: '',
      arabicHeader: '',
      status: HadithStatus.sahih,
      chapterId: 1,
    );

Hadith _hFull(
  String number, {
  required HadithStatus status,
  required int chapterId,
}) =>
    Hadith(
      hadithNumber: number,
      englishHadith: 'en',
      arabicHadith: 'ar',
      englishNarrator: '',
      englishHeader: '',
      arabicHeader: '',
      status: status,
      chapterId: chapterId,
    );

void main() {
  late _MockArabicSearch arabic;
  late _MockLocal local;
  late _MockRemote remote;
  late AhadithSearchRepositoryImpl sut;

  const slug = 'sahih-bukhari';
  const arabicQuery = 'الصلاة'; // triggers the Arabic branch

  setUpAll(() {
    registerFallbackValue(<String>[]);
  });

  setUp(() {
    arabic = _MockArabicSearch();
    local = _MockLocal();
    remote = _MockRemote();
    sut = AhadithSearchRepositoryImpl(
      arabicSearchDataSource: arabic,
      ahadithLocalDataSource: local,
      ahadithRemoteDataSource: remote,
      allChapters: const {
        'sahih-bukhari': [
          {
            'id': 5,
            'chapterNumber': 17,
            'chapterArabic': 'الوضوء',
            'chapterEnglish': 'Ablutions',
          },
        ],
      },
    );
  });

  group('searchHadiths (Arabic, online) — partial vs error', () {
    test('returns local matches when the remote fetch fails but some exist',
        () async {
      when(() => arabic.getSearchedHadithsNumbers(
            query: any(named: 'query'),
            status: any(named: 'status'),
            chapterId: any(named: 'chapterId'),
          )).thenAnswer((_) async => ['1', '2']);
      when(() => local.getAhadithByNumbers(any(), any()))
          .thenReturn((found: [_h('1')], missing: ['2']));
      when(() => remote.getAhadithByNumbers(any(), any())).thenThrow(
        DioException(requestOptions: RequestOptions(path: '')),
      );

      final result = await sut.searchHadiths(
        query: arabicQuery,
        bookSlug: slug,
        isDownloaded: false,
      );

      result.fold(
        (f) => fail('expected partial Right, got Left($f)'),
        (list) => expect(list.map((h) => h.hadithNumber), ['1']),
      );
    });

    test('surfaces a Left when the remote fails and there are no local matches',
        () async {
      when(() => arabic.getSearchedHadithsNumbers(
            query: any(named: 'query'),
            status: any(named: 'status'),
            chapterId: any(named: 'chapterId'),
          )).thenAnswer((_) async => ['1', '2']);
      when(() => local.getAhadithByNumbers(any(), any()))
          .thenReturn((found: <Hadith>[], missing: ['1', '2']));
      when(() => remote.getAhadithByNumbers(any(), any())).thenThrow(
        DioException(requestOptions: RequestOptions(path: '')),
      );

      final result = await sut.searchHadiths(
        query: arabicQuery,
        bookSlug: slug,
        isDownloaded: false,
      );

      expect(result.isLeft(), isTrue);
      result.fold((f) => expect(f, isA<UnknownFailure>()), (_) {});
    });

    test('does not hit the network when the book is downloaded', () async {
      when(() => arabic.getSearchedHadithsNumbers(
            query: any(named: 'query'),
            status: any(named: 'status'),
            chapterId: any(named: 'chapterId'),
          )).thenAnswer((_) async => ['1', '2']);
      when(() => local.getAhadithByNumbers(any(), any()))
          .thenReturn((found: [_h('1')], missing: ['2']));

      final result = await sut.searchHadiths(
        query: arabicQuery,
        bookSlug: slug,
        isDownloaded: true,
      );

      result.fold(
        (f) => fail('expected Right, got Left($f)'),
        (list) => expect(list.map((h) => h.hadithNumber), ['1']),
      );
      verifyNever(() => remote.getAhadithByNumbers(any(), any()));
    });
  });

  group('searchHadiths (Arabic, downloaded) — in-memory filter', () {
    test('filters Arabic results in-memory by status and chapter', () async {
      when(() => arabic.getSearchedHadithsNumbers(
            query: any(named: 'query'),
            status: any(named: 'status'),
            chapterId: any(named: 'chapterId'),
          )).thenAnswer((_) async => ['1', '2', '3']);
      when(() => local.getAhadithByNumbers(any(), any())).thenReturn((
        found: [
          _hFull('1', status: HadithStatus.sahih, chapterId: 5),
          _hFull('2', status: HadithStatus.daeef, chapterId: 5),
          _hFull('3', status: HadithStatus.sahih, chapterId: 9),
        ],
        missing: <String>[],
      ));

      final result = await sut.searchHadiths(
        query: arabicQuery,
        bookSlug: slug,
        isDownloaded: true,
        status: HadithStatus.sahih,
        chapterId: 5,
      );

      result.fold(
        (f) => fail('expected Right, got Left($f)'),
        (list) => expect(list.map((h) => h.hadithNumber), ['1']),
      );
    });
  });

  group('searchHadiths (English, downloaded) — forwards filter to local', () {
    test('passes status + chapterId to the local search', () async {
      when(() => local.getSearchedHadiths(
            any(),
            any(),
            status: any(named: 'status'),
            chapterId: any(named: 'chapterId'),
          )).thenReturn([_h('1')]);

      final result = await sut.searchHadiths(
        query: 'prayer',
        bookSlug: slug,
        isDownloaded: true,
        status: HadithStatus.hasan,
        chapterId: 5,
      );

      expect(result.isRight(), isTrue);
      verify(() => local.getSearchedHadiths(
            'prayer',
            slug,
            status: HadithStatus.hasan,
            chapterId: 5,
          )).called(1);
    });
  });

  group('searchHadiths (English, online) — forwards filter to API', () {
    const englishQuery = 'prayer';

    test('passes status + chapterNumber derived from chapterId', () async {
      when(() => remote.getSearchedHadiths(
            any(),
            any(),
            status: any(named: 'status'),
            chapterNumber: any(named: 'chapterNumber'),
          )).thenAnswer((_) async => [_h('1')]);

      final result = await sut.searchHadiths(
        query: englishQuery,
        bookSlug: slug,
        isDownloaded: false,
        status: HadithStatus.daeef,
        chapterId: 5,
      );

      expect(result.isRight(), isTrue);
      verify(() => remote.getSearchedHadiths(
            englishQuery,
            slug,
            status: 'Da`eef',
            chapterNumber: 17, // id 5 -> chapterNumber 17 via allChapters lookup
          )).called(1);
    });
  });
}
