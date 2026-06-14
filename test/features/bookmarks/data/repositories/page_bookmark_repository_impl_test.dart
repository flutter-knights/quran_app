import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/core/errors/exceptions.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/features/bookmarks/data/datasources/local/page_bookmark_local_data_source.dart';
import 'package:quran_app/features/bookmarks/data/repositories/page_bookmark_repository_impl.dart';

class _MockDs extends Mock implements PageBookmarkLocalDataSource {}

void main() {
  late _MockDs ds;
  late PageBookmarkRepositoryImpl repo;

  setUp(() {
    ds = _MockDs();
    repo = PageBookmarkRepositoryImpl(dataSource: ds);
  });

  test('getAll returns Right(set)', () async {
    when(() => ds.getAll()).thenReturn({1, 2});
    final result = await repo.getAll();
    expect(result.isRight(), true);
    result.fold((_) {}, (s) => expect(s, {1, 2}));
  });

  test('toggle returns Right(true) when added', () async {
    when(() => ds.toggle(5)).thenAnswer((_) async => true);
    expect(await repo.toggle(5), const Right<Failure, bool>(true));
  });

  test('maps CacheException to Left(CacheFailure)', () async {
    when(() => ds.toggle(5)).thenThrow(CacheException('boom'));
    final r = await repo.toggle(5);
    expect(r.isLeft(), true);
    r.fold((f) => expect(f, isA<CacheFailure>()), (_) {});
  });
}
