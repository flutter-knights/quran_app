import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/core/errors/exceptions.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/features/bookmarks/data/datasources/local/place_migration.dart';
import 'package:quran_app/features/bookmarks/data/datasources/local/places_local_data_source.dart';
import 'package:quran_app/features/bookmarks/data/repositories/places_repository_impl.dart';
import 'package:quran_app/features/bookmarks/domain/entities/place.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';

class _MockDataSource extends Mock implements PlacesLocalDataSource {}

class _MockMigration extends Mock implements PlaceMigration {}

void main() {
  late _MockDataSource dataSource;
  late _MockMigration migration;
  late PlacesRepositoryImpl repo;

  final place = Place(
    id: 'a',
    ayah: const AyahIdentifier(surah: 2, ayah: 5),
    page: 2,
    createdAt: DateTime(2026, 11, 21),
    updatedAt: DateTime(2026, 11, 21),
  );

  setUp(() {
    dataSource = _MockDataSource();
    migration = _MockMigration();
    repo = PlacesRepositoryImpl(dataSource: dataSource, migration: migration);
  });

  test('getAll wraps the list in Right', () async {
    when(() => dataSource.getAll()).thenReturn([place]);
    expect((await repo.getAll()).getOrElse(() => []), [place]);
  });

  test('a throw on getAll becomes a Failure', () async {
    when(() => dataSource.getAll()).thenThrow(StateError('bad'));
    expect((await repo.getAll()).isLeft(), isTrue);
  });

  test('save and remove return Right(unit) on success', () async {
    when(() => dataSource.save(place)).thenAnswer((_) async {});
    when(() => dataSource.remove('a')).thenAnswer((_) async {});
    expect(await repo.save(place), const Right(unit));
    expect(await repo.remove('a'), const Right(unit));
  });

  test('a CacheException on save becomes CacheFailure', () async {
    when(() => dataSource.save(place)).thenThrow(CacheException('boom'));
    final result = await repo.save(place);
    expect(result.fold((f) => f, (_) => null), isA<CacheFailure>());
  });

  test(
    'an unexpected error on remove becomes a Failure, never a throw',
    () async {
      when(() => dataSource.remove('a')).thenThrow(StateError('bad'));
      final result = await repo.remove('a');
      expect(result.isLeft(), isTrue);
    },
  );

  test('migrate maps a throw from the migration to a Failure', () async {
    when(() => migration.run()).thenThrow(StateError('bad'));
    expect((await repo.migrate()).isLeft(), isTrue);
  });

  test('a CacheException on migrate becomes CacheFailure', () async {
    when(() => migration.run()).thenThrow(CacheException('count'));
    final result = await repo.migrate();
    expect(result.fold((f) => f, (_) => null), isA<CacheFailure>());
  });

  test('migrate returns Right(unit) on success', () async {
    when(() => migration.run()).thenAnswer((_) async => 2);
    expect(await repo.migrate(), const Right(unit));
  });
}
