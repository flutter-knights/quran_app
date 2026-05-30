import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/features/ahadith/data/datasources/local/ahadith_local_data_source.dart';
import 'package:quran_app/features/ahadith/data/models/hadith_hive_model.dart';

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
}
