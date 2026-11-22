import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:quran_app/core/errors/exceptions.dart';
import 'package:quran_app/features/tafsir/data/datasources/local/tafsir_local_data_source.dart';
import 'package:quran_app/features/tafsir/domain/entities/tafsir.dart';

void main() {
  late Box<String> box;
  late TafsirLocalDataSource source;
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tafsir_local_test_');
    Hive.init(tempDir.path);
    box = await Hive.openBox<String>('tafsir_test_${tempDir.path.hashCode}');
    source = TafsirLocalDataSource(box: box);
  });

  tearDown(() async {
    if (box.isOpen) await box.close();
    await tempDir.delete(recursive: true);
  });

  test('a missing ayah reads null', () {
    expect(source.get(2, 255), isNull);
  });

  test('putAll stores each ayah under muyassar:s:a', () async {
    await source.putAll(const [
      Tafsir(surah: 2, ayah: 255, text: 'آية الكرسي'),
      Tafsir(surah: 2, ayah: 256, text: 'لا إكراه'),
    ]);

    expect(box.get('muyassar:2:255'), 'آية الكرسي');
    expect(box.get('muyassar:2:256'), 'لا إكراه');
  });

  test('get returns the stored text', () async {
    await source.putAll(const [Tafsir(surah: 1, ayah: 1, text: 'بسم الله')]);

    expect(source.get(1, 1), 'بسم الله');
  });

  test('a failed write throws CacheException', () async {
    await box.close();

    expect(
      source.putAll(const [Tafsir(surah: 1, ayah: 1, text: 'x')]),
      throwsA(isA<CacheException>()),
    );
  });
}
