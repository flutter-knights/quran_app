import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/features/bookmarks/domain/repositories/bookmark_repository.dart';
import 'package:quran_app/features/bookmarks/domain/usecases/toggle_bookmark.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';

class _MockRepo extends Mock implements BookmarkRepository {}

void main() {
  late _MockRepo repo;
  late ToggleBookmark usecase;

  const ayah = AyahIdentifier(surah: 2, ayah: 255);

  setUpAll(() {
    registerFallbackValue(ayah);
  });

  setUp(() {
    repo = _MockRepo();
    usecase = ToggleBookmark(repo);
  });

  test('delegates to repository.toggle and returns new state', () async {
    when(() => repo.toggle(any())).thenAnswer((_) async => const Right(true));

    final result = await usecase(ayah);

    expect(result, const Right<Failure, bool>(true));
    verify(() => repo.toggle(ayah)).called(1);
  });

  test('propagates failure', () async {
    when(() => repo.toggle(any()))
        .thenAnswer((_) async => const Left(CacheFailure('boom')));

    final result = await usecase(ayah);

    expect(result.isLeft(), isTrue);
  });
}
