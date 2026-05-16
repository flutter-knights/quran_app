import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/core/errors/exceptions.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/features/bookmarks/data/datasources/local/bookmark_local_data_source.dart';
import 'package:quran_app/features/bookmarks/data/repositories/bookmark_repository_impl.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';

class _MockDS extends Mock implements BookmarkLocalDataSource {}

void main() {
  late _MockDS ds;
  late BookmarkRepositoryImpl repo;
  const ayah = AyahIdentifier(surah: 2, ayah: 255);

  setUpAll(() {
    registerFallbackValue(ayah);
  });

  setUp(() {
    ds = _MockDS();
    repo = BookmarkRepositoryImpl(dataSource: ds);
  });

  group('getAll', () {
    test('wraps data source result in Right', () async {
      final theSet = {ayah};
      when(() => ds.getAll()).thenReturn(theSet);

      final result = await repo.getAll();

      expect(result, Right<Failure, Set<AyahIdentifier>>(theSet));
    });

    test('maps thrown exception to Left(CacheFailure)', () async {
      when(() => ds.getAll()).thenThrow(CacheException('boom'));

      final result = await repo.getAll();

      expect(result.isLeft(), isTrue);
      result.fold((f) => expect(f, isA<CacheFailure>()), (_) => fail('not Right'));
    });
  });

  group('toggle', () {
    test('returns Right(true) when newly added', () async {
      when(() => ds.toggle(surah: ayah.surah, ayah: ayah.ayah))
          .thenAnswer((_) async => true);

      final result = await repo.toggle(ayah);

      expect(result, const Right<Failure, bool>(true));
    });

    test('maps exception to Left(CacheFailure)', () async {
      when(() => ds.toggle(surah: ayah.surah, ayah: ayah.ayah))
          .thenThrow(CacheException('boom'));

      final result = await repo.toggle(ayah);

      expect(result.isLeft(), isTrue);
    });
  });

  group('isBookmarked', () {
    test('returns membership of the cached set', () async {
      when(() => ds.getAll()).thenReturn({ayah});

      final yes = await repo.isBookmarked(ayah);
      final no = await repo.isBookmarked(const AyahIdentifier(surah: 1, ayah: 1));

      expect(yes, const Right<Failure, bool>(true));
      expect(no, const Right<Failure, bool>(false));
    });
  });
}
