import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:quran_app/features/bookmarks/data/datasources/local/places_local_data_source.dart';
import 'package:quran_app/features/bookmarks/data/models/place_record_model.dart';
import 'package:quran_app/features/bookmarks/domain/entities/place.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';

Place place(String id, int ayah) => Place(
  id: id,
  ayah: AyahIdentifier(surah: 2, ayah: ayah),
  page: 2,
  createdAt: DateTime(2026, 11, 21),
  updatedAt: DateTime(2026, 11, 21),
);

void main() {
  late Box<PlaceRecordModel> box;
  late PlacesLocalDataSource dataSource;
  late Directory tempDir;

  setUpAll(() {
    Hive.registerAdapter(PlaceRecordModelAdapter());
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('places_ds_test_');
    Hive.init(tempDir.path);
    box = await Hive.openBox<PlaceRecordModel>('places_ds');
    dataSource = PlacesLocalDataSource(box: box);
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  test('starts empty', () {
    expect(dataSource.getAll(), isEmpty);
  });

  test('save then getAll returns the place', () async {
    await dataSource.save(place('a', 5));
    expect(dataSource.getAll(), [place('a', 5)]);
  });

  test('saving the same id replaces it', () async {
    await dataSource.save(place('a', 5));
    await dataSource.save(place('a', 9));
    expect(dataSource.getAll(), [place('a', 9)]);
  });

  test('remove deletes by id', () async {
    await dataSource.save(place('a', 5));
    await dataSource.save(place('b', 6));
    await dataSource.remove('a');
    expect(dataSource.getAll(), [place('b', 6)]);
  });

  test('remove of an unknown id is a no-op', () async {
    await dataSource.save(place('a', 5));
    await dataSource.remove('zzz');
    expect(dataSource.getAll(), [place('a', 5)]);
  });
}
