import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:quran_app/features/bookmarks/data/models/place_record_model.dart';
import 'package:quran_app/features/bookmarks/domain/entities/fasil_slot.dart';
import 'package:quran_app/features/bookmarks/domain/entities/place.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';

void main() {
  late Directory tempDir;

  final fasil = Place(
    id: 'a',
    ayah: const AyahIdentifier(surah: 2, ayah: 5),
    page: 2,
    slot: FasilSlot.hifz,
    name: 'حفظ رمضان',
    createdAt: DateTime(2026, 11, 21, 9, 40),
    updatedAt: DateTime(2026, 11, 22, 6, 10),
  );

  setUpAll(() {
    Hive.registerAdapter(PlaceRecordModelAdapter());
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('place_record_test_');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  test('round-trips a فاصل through the entity', () {
    expect(PlaceRecordModel.fromEntity(fasil).toEntity(), fasil);
  });

  test('a record with no slot is a saved ayah', () {
    final saved = Place(
      id: 'b',
      ayah: const AyahIdentifier(surah: 1, ayah: 2),
      page: 1,
      createdAt: DateTime(2026, 11, 21),
      updatedAt: DateTime(2026, 11, 21),
      migrated: true,
    );
    final back = PlaceRecordModel.fromEntity(saved).toEntity();
    expect(back.slot, isNull);
    expect(back, saved);
  });

  test('an unknown slot index reads as a saved ayah', () {
    final record = PlaceRecordModel.fromEntity(fasil)..slot = 7;
    expect(record.toEntity().slot, isNull);
  });

  test('survives a box close and reopen', () async {
    var box = await Hive.openBox<PlaceRecordModel>('places_rt');
    await box.put('a', PlaceRecordModel.fromEntity(fasil));
    await box.close();
    box = await Hive.openBox<PlaceRecordModel>('places_rt');
    expect(box.get('a')!.toEntity(), fasil);
  });
}
