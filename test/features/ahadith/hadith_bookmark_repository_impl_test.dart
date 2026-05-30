import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/core/errors/exceptions.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/features/ahadith/data/datasources/local/hadith_bookmark_local_data_source.dart';
import 'package:quran_app/features/ahadith/data/repositories/hadith_bookmark_repository_impl.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith_bookmark.dart';

class _MockDataSource extends Mock implements HadithBookmarkLocalDataSource {}

void main() {
  late _MockDataSource dataSource;
  late HadithBookmarkRepositoryImpl sut;

  const bookmark = HadithBookmark(bookSlug: 'bukhari', hadithNumber: '42');

  setUpAll(() {
    registerFallbackValue(bookmark);
  });

  setUp(() {
    dataSource = _MockDataSource();
    sut = HadithBookmarkRepositoryImpl(dataSource: dataSource);
  });

  group('getAll', () {
    test('wraps result in Right', () async {
      when(() => dataSource.getAll()).thenReturn({bookmark});

      final result = await sut.getAll();

      result.fold((l) => fail('expected Right'), (set) => expect(set, {bookmark}));
    });

    test('maps CacheException to Left(CacheFailure)', () async {
      when(() => dataSource.getAll()).thenThrow(CacheException('boom'));

      final result = await sut.getAll();

      result.fold((l) => expect(l, isA<CacheFailure>()), (_) => fail('expected Left'));
    });
  });

  group('toggle', () {
    test('returns Right(true) on add, Right(false) on remove', () async {
      when(() => dataSource.toggle(any())).thenAnswer((_) async => true);
      final add = await sut.toggle(bookmark);
      add.fold((l) => fail('expected Right'), (v) => expect(v, isTrue));

      when(() => dataSource.toggle(any())).thenAnswer((_) async => false);
      final rem = await sut.toggle(bookmark);
      rem.fold((l) => fail('expected Right'), (v) => expect(v, isFalse));
    });

    test('maps CacheException to Left(CacheFailure)', () async {
      when(() => dataSource.toggle(any())).thenThrow(CacheException('boom'));

      final result = await sut.toggle(bookmark);

      result.fold((l) => expect(l, isA<CacheFailure>()), (_) => fail('expected Left'));
    });
  });
}
