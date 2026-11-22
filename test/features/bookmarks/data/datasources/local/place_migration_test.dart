import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/core/errors/exceptions.dart';
import 'package:quran/quran.dart' as quran;
import 'package:quran_app/features/bookmarks/data/datasources/local/place_migration.dart';
import 'package:quran_app/features/bookmarks/data/models/place_record_model.dart';
import 'package:quran_app/features/bookmarks/domain/entities/place.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';

class _MockBox extends Mock implements Box<PlaceRecordModel> {}

int pageOf(AyahIdentifier a) => quran.getPageNumber(a.surah, a.ayah);

const a4176 = AyahIdentifier(surah: 4, ayah: 176);

void main() {
  final now = DateTime(2026, 11, 21, 9);

  List<Place> plan({
    List<Object?> ayahKeys = const [],
    List<Object?> pages = const [],
    Map<int, AyahIdentifier> firstAyahs = const {},
  }) => PlaceMigration.plan(
    ayahKeys: ayahKeys,
    pages: pages,
    firstAyahs: firstAyahs,
    pageOf: pageOf,
    now: now,
  );

  group('plan', () {
    test('ayah bookmarks become saved ayat in stored order', () {
      final places = plan(ayahKeys: ['2:5', '3:8']);
      expect(places.map((p) => p.ayah), const [
        AyahIdentifier(surah: 2, ayah: 5),
        AyahIdentifier(surah: 3, ayah: 8),
      ]);
      expect(places.every((p) => p.slot == null && p.migrated), isTrue);
      expect(places[0].createdAt, now);
      expect(
        places[1].createdAt,
        now.subtract(const Duration(microseconds: 1)),
      );
      for (final p in places) {
        expect(p.updatedAt, p.createdAt);
        expect(p.id, p.createdAt.microsecondsSinceEpoch.toString());
      }
      expect(places.map((p) => p.page), [2, 50]);
    });

    test('banner entries are dropped', () {
      final places = plan(ayahKeys: ['5:0', '1:1']);
      expect(places.length, 1);
      expect(places.single.ayah, const AyahIdentifier(surah: 1, ayah: 1));
      expect(places.single.createdAt, now);
    });

    test('page bookmarks map to the first ayah on the page', () {
      final places = plan(pages: [106], firstAyahs: {106: a4176});
      expect(places.single.ayah, a4176);
      expect(places.single.page, 106);
    });

    test('a page with no resolvable ayah is dropped', () {
      expect(plan(pages: [106]), isEmpty);
    });

    test('an ayah in both lists is kept once', () {
      final places = plan(
        ayahKeys: ['4:176'],
        pages: [106],
        firstAyahs: {106: a4176},
      );
      expect(places.length, 1);
    });

    test('an ayah repeated in one list is kept once at its first position', () {
      final places = plan(ayahKeys: ['2:5', '3:8', '2:5']);
      expect(places.map((p) => p.ayah), const [
        AyahIdentifier(surah: 2, ayah: 5),
        AyahIdentifier(surah: 3, ayah: 8),
      ]);
      expect(places[0].createdAt, now);
      expect(
        places[1].createdAt,
        now.subtract(const Duration(microseconds: 1)),
      );
    });

    test('malformed entries are skipped', () {
      final places = plan(
        ayahKeys: ['x', 7, '2:', '2:999', '200:1', '2:5'],
        pages: ['12', 'abc'],
        firstAyahs: {12: const AyahIdentifier(surah: 2, ayah: 77)},
      );
      expect(places.map((p) => p.ayah), const [
        AyahIdentifier(surah: 2, ayah: 5),
        AyahIdentifier(surah: 2, ayah: 77),
      ]);
    });
  });

  test('parsePage and parseAyahKey', () {
    expect(PlaceMigration.parsePage(12), 12);
    expect(PlaceMigration.parsePage('12'), 12);
    expect(PlaceMigration.parsePage('abc'), isNull);
    expect(
      PlaceMigration.parseAyahKey('2:5'),
      const AyahIdentifier(surah: 2, ayah: 5),
    );
    expect(PlaceMigration.parseAyahKey('5:0'), isNull);
    expect(PlaceMigration.parseAyahKey('2:'), isNull);
    expect(PlaceMigration.parseAyahKey(7), isNull);
  });

  group('run', () {
    late Directory tempDir;
    late Box<PlaceRecordModel> places;
    late Box<bool> meta;
    late Box<List> ayahBookmarks;
    late Box<List> pageBookmarks;
    late PlaceMigration migration;

    Future<void> seed({
      List<Object?> ayahs = const ['2:5'],
      List<Object?> pages = const [106],
    }) async {
      await ayahBookmarks.put('all', ayahs);
      await pageBookmarks.put('all', pages);
    }

    PlaceRecordModel readerRecord(String id, int surah, int ayah) =>
        PlaceRecordModel(
          id: id,
          surah: surah,
          ayah: ayah,
          page: 1,
          createdAt: now,
          updatedAt: now,
        );

    setUpAll(() {
      Hive.registerAdapter(PlaceRecordModelAdapter());
    });

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('place_migration_test_');
      Hive.init(tempDir.path);
      places = await Hive.openBox<PlaceRecordModel>('places');
      meta = await Hive.openBox<bool>('places_meta');
      ayahBookmarks = await Hive.openBox<List>('ayah_bookmarks');
      pageBookmarks = await Hive.openBox<List>('page_bookmarks');
      migration = PlaceMigration(
        places: places,
        meta: meta,
        ayahBookmarks: ayahBookmarks,
        pageBookmarks: pageBookmarks,
        firstAyahOfPage: (p) async => {106: a4176}[p],
        pageOf: pageOf,
        now: () => now,
      );
    });

    tearDown(() async {
      await Hive.close();
      await tempDir.delete(recursive: true);
    });

    test('run writes the plan, sets the flag and returns the count', () async {
      await seed();
      expect(await migration.run(), 2);
      expect(places.length, 2);
      expect(meta.get('migratedV1'), isTrue);
    });

    test('a second run changes nothing', () async {
      await seed();
      await migration.run();
      final ids = places.keys.toSet();
      expect(await migration.run(), 0);
      expect(places.keys.toSet(), ids);
    });

    test('a run interrupted before the flag never duplicates', () async {
      await seed();
      await migration.run();
      await meta.delete('migratedV1');
      await places.put('r', readerRecord('r', 3, 8));
      await migration.run();
      expect(places.length, 3);
      expect(places.values.where((r) => r.migrated).length, 2);
    });

    test(
      'a reader save made after a failed run is not migrated again',
      () async {
        await seed();
        await migration.run();
        await meta.delete('migratedV1');
        final migrated = places.values.firstWhere((r) => r.ayah == 5);
        await places.delete(migrated.id);
        await places.put('r', readerRecord('r', 2, 5));
        await migration.run();
        final at25 = places.values.where((r) => r.surah == 2 && r.ayah == 5);
        expect(at25.length, 1);
        expect(at25.single.migrated, isFalse);
        expect(places.values.any((r) => r.surah == 4 && r.ayah == 176), isTrue);
        expect(places.length, 2);
      },
    );

    test('a count mismatch throws and leaves the flag unset', () async {
      await seed();
      final stub = _MockBox();
      when(() => stub.values).thenReturn(<PlaceRecordModel>[]);
      when(() => stub.deleteAll(any())).thenAnswer((_) async {});
      when(() => stub.putAll(any())).thenAnswer((_) async {});
      when(() => stub.containsKey(any())).thenReturn(false);
      final broken = PlaceMigration(
        places: stub,
        meta: meta,
        ayahBookmarks: ayahBookmarks,
        pageBookmarks: pageBookmarks,
        firstAyahOfPage: (p) async => {106: a4176}[p],
        pageOf: pageOf,
        now: () => now,
      );
      await expectLater(broken.run(), throwsA(isA<CacheException>()));
      expect(meta.get('migratedV1'), isNull);
    });

    test('old boxes are left intact', () async {
      await seed();
      await migration.run();
      expect(ayahBookmarks.get('all'), ['2:5']);
      expect(pageBookmarks.get('all'), [106]);
    });

    test('nothing to migrate still sets the flag', () async {
      expect(await migration.run(), 0);
      expect(meta.get('migratedV1'), isTrue);
    });
  });
}
