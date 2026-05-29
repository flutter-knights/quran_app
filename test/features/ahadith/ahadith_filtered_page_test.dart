import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/features/ahadith/data/datasources/local/ahadith_local_data_source.dart';
import 'package:quran_app/features/ahadith/data/datasources/remote/ahadith_remote_data_source.dart';
import 'package:quran_app/features/ahadith/data/repositories/ahadith_repository_impl.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith_page.dart';

class _MockLocal extends Mock implements AhadithLocalDataSource {}

class _MockRemote extends Mock implements AhadithRemoteDataSource {}

HadithPage _page() => HadithPage(
      ahadithList: [
        Hadith(
          hadithNumber: '12',
          englishHadith: 'en',
          arabicHadith: 'ar',
          englishNarrator: '',
          englishHeader: '',
          arabicHeader: '',
          status: HadithStatus.daeef,
          chapterId: 10,
        ),
      ],
      currentPage: 1,
      lastPage: true,
    );

void main() {
  late _MockLocal local;
  late _MockRemote remote;
  late AhadithRepositoryImpl sut;

  setUpAll(() {
    registerFallbackValue(_page());
  });

  setUp(() {
    local = _MockLocal();
    remote = _MockRemote();
    sut = AhadithRepositoryImpl(
      ahadithLocalDataSource: local,
      ahadithRemoteDataSource: remote,
      allChapters: const {
        'sahih-bukhari': [
          {
            'id': 10,
            'chapterNumber': 3,
            'chapterArabic': 'باب',
            'chapterEnglish': 'Chapter',
          },
        ],
      },
    );
  });

  test('maps daeef status to the API value and chapterId to chapterNumber',
      () async {
    when(
      () => remote.getFilteredAhadithPage(
        any(),
        any(),
        status: any(named: 'status'),
        chapterNumber: any(named: 'chapterNumber'),
      ),
    ).thenAnswer((_) async => _page());

    final result = await sut.getFilteredAhadithPage(
      pageNumber: 1,
      bookSlug: 'sahih-bukhari',
      status: HadithStatus.daeef,
      chapterId: 10,
    );

    expect(result.isRight(), isTrue);
    // Da`eef uses a backtick; chapterId 10 -> chapterNumber 3.
    verify(
      () => remote.getFilteredAhadithPage(
        1,
        'sahih-bukhari',
        status: 'Da`eef',
        chapterNumber: 3,
      ),
    ).called(1);
    // Filtered pages must never pollute the full-page cache.
    verifyNever(() => local.cachePage(any(), any(), any()));
  });

  group('getBookStatuses', () {
    test('Sahih-only collections expose just sahih', () {
      expect(sut.getBookStatuses('sahih-bukhari'), {HadithStatus.sahih});
      expect(sut.getBookStatuses('sahih-muslim'), {HadithStatus.sahih});
    });

    test('mixed collections expose their grades', () {
      expect(sut.getBookStatuses('sunan-nasai'), {
        HadithStatus.sahih,
        HadithStatus.hasan,
        HadithStatus.daeef,
      });
      expect(sut.getBookStatuses('al-tirmidhi'),
          {HadithStatus.sahih, HadithStatus.daeef});
    });

    test('unknown book falls back to all grades', () {
      expect(sut.getBookStatuses('unknown'), {
        HadithStatus.sahih,
        HadithStatus.hasan,
        HadithStatus.daeef,
      });
    });
  });

  test('decorates results with the matching chapter', () async {
    when(
      () => remote.getFilteredAhadithPage(
        any(),
        any(),
        status: any(named: 'status'),
        chapterNumber: any(named: 'chapterNumber'),
      ),
    ).thenAnswer((_) async => _page());

    final result = await sut.getFilteredAhadithPage(
      pageNumber: 1,
      bookSlug: 'sahih-bukhari',
      status: HadithStatus.daeef,
    );

    result.fold(
      (f) => fail('expected Right'),
      (page) => expect(page.ahadithList.first.chapter?.chapterNumber, 3),
    );
  });
}
