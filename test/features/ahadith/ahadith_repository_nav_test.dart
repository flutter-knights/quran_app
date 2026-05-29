import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/features/ahadith/data/datasources/local/ahadith_local_data_source.dart';
import 'package:quran_app/features/ahadith/data/datasources/remote/ahadith_remote_data_source.dart';
import 'package:quran_app/features/ahadith/data/repositories/ahadith_repository_impl.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith_page.dart';

class _MockLocal extends Mock implements AhadithLocalDataSource {}

class _MockRemote extends Mock implements AhadithRemoteDataSource {}

Hadith _h(String number) => Hadith(
      hadithNumber: number,
      englishHadith: '',
      arabicHadith: '',
      englishNarrator: '',
      englishHeader: '',
      arabicHeader: '',
      status: HadithStatus.sahih,
      chapterId: 1,
    );

/// A densely-numbered page: page p holds numbers (p-1)*100+1 .. p*100.
HadithPage _numericPage(int p) => HadithPage(
      ahadithList: [
        for (var i = (p - 1) * 100 + 1; i <= p * 100; i++) _h('$i'),
      ],
      currentPage: p,
      lastPage: false,
    );

void main() {
  late _MockLocal local;
  late _MockRemote remote;
  late AhadithRepositoryImpl sut;

  setUp(() {
    local = _MockLocal();
    remote = _MockRemote();
    sut = AhadithRepositoryImpl(
      ahadithLocalDataSource: local,
      ahadithRemoteDataSource: remote,
      allChapters: const {},
    );
  });

  group('estimate fast path (bounded reads, no page-1 scan)', () {
    test('next of a deep hadith reads only a few pages', () async {
      var reads = 0;
      when(() => local.getCachedPage(any(), any())).thenAnswer((inv) {
        reads++;
        return _numericPage(inv.positionalArguments[0] as int);
      });

      final result = await sut.getNextHadith(
        bookSlug: 'sahih-bukhari',
        currentHadithNumber: '5000',
      );

      result.fold(
        (f) => fail('expected Right, got Left($f)'),
        (h) => expect(h?.hadithNumber, '5001'),
      );
      // Estimate page 50 (+ probe 49 + rollover 51) — nowhere near 50 pages.
      expect(reads, lessThanOrEqualTo(4));
    });

    test('previous of a deep hadith reads only a few pages', () async {
      var reads = 0;
      when(() => local.getCachedPage(any(), any())).thenAnswer((inv) {
        reads++;
        return _numericPage(inv.positionalArguments[0] as int);
      });

      final result = await sut.getPreviousHadith(
        bookSlug: 'sahih-bukhari',
        currentHadithNumber: '5000',
      );

      result.fold(
        (f) => fail('expected Right, got Left($f)'),
        (h) => expect(h?.hadithNumber, '4999'),
      );
      expect(reads, lessThanOrEqualTo(4));
    });
  });

  group('fallback full scan (estimate cannot apply)', () {
    test('non-numeric numbering still resolves the next hadith', () async {
      // Estimate can't be computed from '7b', so it must fall back to the scan.
      when(() => local.getCachedPage(1, 'sahih-bukhari')).thenReturn(
        HadithPage(
          ahadithList: [_h('7a'), _h('7b'), _h('7c')],
          currentPage: 1,
          lastPage: true,
        ),
      );

      final result = await sut.getNextHadith(
        bookSlug: 'sahih-bukhari',
        currentHadithNumber: '7b',
      );

      result.fold(
        (f) => fail('expected Right, got Left($f)'),
        (h) => expect(h?.hadithNumber, '7c'),
      );
    });

    test('non-numeric numbering still resolves the previous hadith', () async {
      when(() => local.getCachedPage(1, 'sahih-bukhari')).thenReturn(
        HadithPage(
          ahadithList: [_h('7a'), _h('7b'), _h('7c')],
          currentPage: 1,
          lastPage: true,
        ),
      );

      final result = await sut.getPreviousHadith(
        bookSlug: 'sahih-bukhari',
        currentHadithNumber: '7b',
      );

      result.fold(
        (f) => fail('expected Right, got Left($f)'),
        (h) => expect(h?.hadithNumber, '7a'),
      );
    });
  });
}
