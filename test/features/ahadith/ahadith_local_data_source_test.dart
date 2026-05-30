import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/features/ahadith/data/datasources/local/ahadith_local_data_source.dart';
import 'package:quran_app/features/ahadith/data/models/hadith_hive_model.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith.dart';

class _MockBox extends Mock implements Box<HadithHiveModel> {}

HadithHiveModel _model(String number, int page) => HadithHiveModel(
      hadithNumber: number,
      englishHadith: 'en',
      arabicHadith: 'ar',
      englishNarrator: '',
      arabicHeader: '',
      englishHeader: '',
      status: 'sahih',
      pageNumber: page,
      bookSlug: 'sahih-bukhari',
      chapterId: 1,
    );

HadithHiveModel _modelFull(
  String number, {
  int chapterId = 1,
  String status = 'sahih',
  String english = 'en',
}) =>
    HadithHiveModel(
      hadithNumber: number,
      englishHadith: english,
      arabicHadith: 'ar',
      englishNarrator: '',
      arabicHeader: '',
      englishHeader: '',
      status: status,
      pageNumber: 1,
      bookSlug: 'sahih-bukhari',
      chapterId: chapterId,
    );

void main() {
  late _MockBox box;
  late AhadithLocalDataSource sut;

  setUp(() {
    box = _MockBox();
    sut = AhadithLocalDataSource(hadithBox: box);
    // Default: nothing cached unless a specific key is stubbed below.
    when(() => box.get(any())).thenReturn(null);
    when(() => box.keys).thenReturn(const <dynamic>[]);
  });

  group('getAhadithByNumbers', () {
    test('finds a hadith via the page-estimate fast path', () {
      // 150 -> estimatedPage 2, probes pages 1..3.
      when(() => box.get('sahih-bukhari_2_150')).thenReturn(_model('150', 2));

      final result = sut.getAhadithByNumbers(['150'], 'sahih-bukhari');

      expect(result.missing, isEmpty);
      expect(result.found.single.hadithNumber, '150');
      // Fast path hit -> no full key scan needed.
      verifyNever(() => box.keys);
    });

    test(
        'falls back to a key scan when the cached page is outside the estimate',
        () {
      // 50 -> estimatedPage 1, probes pages 1..2 only. It is actually cached
      // on page 5 (non-sequential numbering), so the fast path misses.
      when(() => box.get('sahih-bukhari_5_50')).thenReturn(_model('50', 5));
      when(() => box.keys).thenReturn(['sahih-bukhari_5_50']);

      final result = sut.getAhadithByNumbers(['50'], 'sahih-bukhari');

      expect(result.missing, isEmpty);
      expect(result.found.single.hadithNumber, '50');
    });

    test('reports genuinely absent numbers as missing', () {
      when(() => box.keys).thenReturn(['sahih-bukhari_1_1']);
      when(() => box.get('sahih-bukhari_1_1')).thenReturn(_model('1', 1));

      final result = sut.getAhadithByNumbers(['999'], 'sahih-bukhari');

      expect(result.found, isEmpty);
      expect(result.missing, ['999']);
    });

    test('scan ignores keys belonging to other books', () {
      // 50 not in this book's fast-path window; only another book has it.
      when(() => box.keys).thenReturn(['sahih-muslim_1_50']);
      when(() => box.get('sahih-muslim_1_50')).thenReturn(
        HadithHiveModel(
          hadithNumber: '50',
          englishHadith: 'en',
          arabicHadith: 'ar',
          englishNarrator: '',
          arabicHeader: '',
          englishHeader: '',
          status: 'sahih',
          pageNumber: 1,
          bookSlug: 'sahih-muslim',
          chapterId: 1,
        ),
      );

      final result = sut.getAhadithByNumbers(['50'], 'sahih-bukhari');

      expect(result.found, isEmpty);
      expect(result.missing, ['50']);
    });
  });

  group('getSearchedHadiths with filters', () {
    test('excludes hadith from other chapters', () {
      final keys = [
        'sahih-bukhari_1_1',
        'sahih-bukhari_1_2',
        'sahih-bukhari_1_3',
      ];
      when(() => box.keys).thenReturn(keys);
      when(() => box.get('sahih-bukhari_1_1'))
          .thenReturn(_modelFull('1', chapterId: 5, english: 'prayer one'));
      when(() => box.get('sahih-bukhari_1_2'))
          .thenReturn(_modelFull('2', chapterId: 9, english: 'prayer two'));
      when(() => box.get('sahih-bukhari_1_3'))
          .thenReturn(_modelFull('3', chapterId: 5, english: 'prayer three'));

      final result = sut.getSearchedHadiths(
        'prayer',
        'sahih-bukhari',
        chapterId: 5,
      );

      expect(result.map((h) => h.hadithNumber).toSet(), {'1', '3'});
    });

    test('returns in-chapter matches beyond the page cap (filter before cap)', () {
      // 105 text-matching hadith: numbers 1..100 in chapter 9, 101..105 in
      // chapter 5. Querying chapter 5 must return all five (101..105), even
      // though they sit past kPageLimit (100) in iteration order. With the old
      // filter-after-cap order, take(100) would keep only the chapter-9 hadith
      // and the chapter-5 matches would be lost.
      final keys = [for (int n = 1; n <= 105; n++) 'sahih-bukhari_1_$n'];
      when(() => box.keys).thenReturn(keys);
      when(() => box.get(any())).thenAnswer((invocation) {
        final key = invocation.positionalArguments.first as String;
        final n = int.parse(key.split('_').last);
        return _modelFull('$n', chapterId: n <= 100 ? 9 : 5, english: 'prayer $n');
      });

      final result = sut.getSearchedHadiths(
        'prayer',
        'sahih-bukhari',
        chapterId: 5,
      );

      expect(
        result.map((h) => h.hadithNumber).toSet(),
        {'101', '102', '103', '104', '105'},
      );
    });

    test('filters by status', () {
      final keys = ['sahih-bukhari_1_1', 'sahih-bukhari_1_2'];
      when(() => box.keys).thenReturn(keys);
      when(() => box.get('sahih-bukhari_1_1'))
          .thenReturn(_modelFull('1', status: 'sahih', english: 'prayer one'));
      when(() => box.get('sahih-bukhari_1_2'))
          .thenReturn(_modelFull('2', status: 'daeef', english: 'prayer two'));

      final result = sut.getSearchedHadiths(
        'prayer',
        'sahih-bukhari',
        status: HadithStatus.daeef,
      );

      expect(result.map((h) => h.hadithNumber).single, '2');
    });
  });
}
