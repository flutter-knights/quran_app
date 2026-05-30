import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/features/ahadith/data/datasources/local/daily_hadith_local_data_source.dart';
import 'package:quran_app/features/ahadith/data/datasources/remote/ahadith_remote_data_source.dart';
import 'package:quran_app/features/ahadith/data/models/hadith_hive_model.dart';
import 'package:quran_app/features/ahadith/data/repositories/daily_hadith_repository_impl.dart';
import 'package:quran_app/features/ahadith/domain/entities/chapter.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith.dart';
import 'package:quran_app/features/ahadith/domain/repositories/ahadith_repository.dart';
import 'package:quran_app/features/ahadith/domain/usecases/daily_hadith_selector.dart';

class _MockRemote extends Mock implements AhadithRemoteDataSource {}

class _MockLocal extends Mock implements DailyHadithLocalDataSource {}

class _MockAhadithRepo extends Mock implements AhadithRepository {}

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

HadithHiveModel _model(String number, String slug) => HadithHiveModel(
      hadithNumber: number,
      englishHadith: 'en',
      arabicHadith: 'ar',
      englishNarrator: '',
      arabicHeader: '',
      englishHeader: '',
      status: 'sahih',
      pageNumber: 0,
      bookSlug: slug,
      chapterId: 1,
    );

void main() {
  late _MockRemote remote;
  late _MockLocal local;
  late _MockAhadithRepo ahadithRepo;
  late DailyHadithRepositoryImpl sut;

  final date = DateTime.utc(2026, 5, 29);

  setUpAll(() {
    registerFallbackValue(_model('1', 'sahih-bukhari'));
  });

  setUp(() {
    remote = _MockRemote();
    local = _MockLocal();
    ahadithRepo = _MockAhadithRepo();
    when(() => ahadithRepo.getBookChapters(any())).thenReturn(const <Chapter>[]);
    sut = DailyHadithRepositoryImpl(
      remote: remote,
      local: local,
      ahadithRepository: ahadithRepo,
    );
  });

  test('returns the cached hadith without hitting the network', () async {
    when(() => local.get(any())).thenReturn(_model('77', 'sahih-muslim'));

    final result = await sut.getDailyHadith(date);

    result.fold(
      (f) => fail('expected Right, got Left($f)'),
      (data) {
        expect(data.hadith.hadithNumber, '77');
        expect(data.bookSlug, 'sahih-muslim');
      },
    );
    verifyNever(() => remote.getAhadithByNumbers(any(), any()));
  });

  test('fetches, caches, and returns when nothing is cached', () async {
    when(() => local.get(any())).thenReturn(null);
    when(() => local.put(any(), any())).thenAnswer((_) async {});
    when(() => remote.getAhadithByNumbers(any(), any()))
        .thenAnswer((_) async => [_h('123')]);

    final result = await sut.getDailyHadith(date);

    result.fold(
      (f) => fail('expected Right, got Left($f)'),
      (data) => expect(data.hadith.hadithNumber, '123'),
    );
    verify(() => local.put(DailyHadithSelector.dateKey(date), any())).called(1);
  });

  test('rerolls when a picked number returns no hadith', () async {
    when(() => local.get(any())).thenReturn(null);
    when(() => local.put(any(), any())).thenAnswer((_) async {});
    var calls = 0;
    when(() => remote.getAhadithByNumbers(any(), any())).thenAnswer((_) async {
      calls++;
      return calls < 3 ? <Hadith>[] : [_h('555')];
    });

    final result = await sut.getDailyHadith(date);

    expect(calls, 3);
    result.fold(
      (f) => fail('expected Right, got Left($f)'),
      (data) => expect(data.hadith.hadithNumber, '555'),
    );
  });

  test('maps a network error to Left', () async {
    when(() => local.get(any())).thenReturn(null);
    when(() => remote.getAhadithByNumbers(any(), any())).thenThrow(
      DioException(requestOptions: RequestOptions(path: '')),
    );

    final result = await sut.getDailyHadith(date);

    expect(result.isLeft(), isTrue);
    result.fold((f) => expect(f, isA<UnknownFailure>()), (_) {});
  });

  test('returns Left when all reroll attempts come back empty', () async {
    when(() => local.get(any())).thenReturn(null);
    when(() => remote.getAhadithByNumbers(any(), any()))
        .thenAnswer((_) async => <Hadith>[]);

    final result = await sut.getDailyHadith(date);

    expect(result.isLeft(), isTrue);
  });
}
