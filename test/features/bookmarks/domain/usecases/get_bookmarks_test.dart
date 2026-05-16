import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/features/bookmarks/domain/repositories/bookmark_repository.dart';
import 'package:quran_app/features/bookmarks/domain/usecases/get_bookmarks.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';

class _MockRepo extends Mock implements BookmarkRepository {}

void main() {
  late _MockRepo repo;
  late GetBookmarks usecase;

  setUp(() {
    repo = _MockRepo();
    usecase = GetBookmarks(repo);
  });

  test('delegates to repository.getAll', () async {
    final set = {const AyahIdentifier(surah: 1, ayah: 1)};
    when(() => repo.getAll()).thenAnswer((_) async => Right(set));

    final result = await usecase();

    expect(result, Right<Failure, Set<AyahIdentifier>>(set));
    verify(() => repo.getAll()).called(1);
  });

  test('propagates failure', () async {
    when(() => repo.getAll())
        .thenAnswer((_) async => const Left(CacheFailure('boom')));

    final result = await usecase();

    expect(result.isLeft(), isTrue);
  });
}
