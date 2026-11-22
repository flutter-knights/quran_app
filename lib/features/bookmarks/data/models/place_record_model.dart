import 'package:hive_ce/hive.dart';

import '../../../quran_playback/domain/entities/ayah_identifier.dart';
import '../../domain/entities/fasil_slot.dart';
import '../../domain/entities/place.dart';

part 'place_record_model.g.dart';

@HiveType(typeId: 6)
class PlaceRecordModel extends HiveObject {
  PlaceRecordModel({
    required this.id,
    required this.surah,
    required this.ayah,
    required this.page,
    this.slot,
    this.name,
    required this.createdAt,
    required this.updatedAt,
    this.migrated = false,
  });

  factory PlaceRecordModel.fromEntity(Place place) => PlaceRecordModel(
    id: place.id,
    surah: place.ayah.surah,
    ayah: place.ayah.ayah,
    page: place.page,
    slot: place.slot?.index,
    name: place.name,
    createdAt: place.createdAt,
    updatedAt: place.updatedAt,
    migrated: place.migrated,
  );

  @HiveField(0)
  String id;

  @HiveField(1)
  int surah;

  @HiveField(2)
  int ayah;

  @HiveField(3)
  int page;

  @HiveField(4)
  int? slot;

  @HiveField(5)
  String? name;

  @HiveField(6)
  DateTime createdAt;

  @HiveField(7)
  DateTime updatedAt;

  @HiveField(8)
  bool migrated;

  Place toEntity() => Place(
    id: id,
    ayah: AyahIdentifier(surah: surah, ayah: ayah),
    page: page,
    slot: slot != null && slot! >= 0 && slot! < FasilSlot.values.length
        ? FasilSlot.values[slot!]
        : null,
    name: name,
    createdAt: createdAt,
    updatedAt: updatedAt,
    migrated: migrated,
  );
}
