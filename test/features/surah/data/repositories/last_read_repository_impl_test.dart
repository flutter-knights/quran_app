import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/surah/data/datasources/last_read_local_data_source.dart';
import 'package:quran_app/features/surah/data/models/last_read_hive_model.dart';
import 'package:quran_app/features/surah/data/repositories/last_read_repository_impl.dart';
import 'package:quran_app/features/surah/domain/entities/last_read.dart';

void main() {
  late Box<LastReadHiveModel> box;
  late LastReadRepositoryImpl repo;
  late Directory tempDir;

  setUpAll(() {
    Hive.registerAdapter(LastReadHiveModelAdapter());
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('last_read_test_');
    Hive.init(tempDir.path);
    box = await Hive.openBox<LastReadHiveModel>(
        'last_read_test_${tempDir.path.hashCode}');
    final ds = LastReadLocalDataSource(box: box);
    repo = LastReadRepositoryImpl(local: ds);
  });

  tearDown(() async {
    await box.close();
    await tempDir.delete(recursive: true);
  });

  test('save then get round-trips with ayah', () async {
    const value = LastRead(
      page: 42,
      ayah: AyahIdentifier(surah: 2, ayah: 5),
    );
    await repo.save(value);
    final got = await repo.get();
    expect(got, value);
  });

  test('save then get round-trips without ayah', () async {
    const value = LastRead(page: 42);
    await repo.save(value);
    final got = await repo.get();
    expect(got, value);
  });

  test('get returns null when nothing saved', () async {
    expect(await repo.get(), isNull);
  });

  test('watch emits on save', () async {
    final emissions = <LastRead?>[];
    final sub = repo.watch().listen(emissions.add);
    await repo.save(const LastRead(page: 1));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await sub.cancel();
    expect(emissions, isNotEmpty);
    expect(emissions.last, const LastRead(page: 1));
  });
}
