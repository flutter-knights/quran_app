import 'package:equatable/equatable.dart';

import '../../../quran_playback/domain/entities/ayah_identifier.dart';
import 'fasil_slot.dart';

class Place extends Equatable {
  const Place({
    required this.id,
    required this.ayah,
    required this.page,
    this.slot,
    this.name,
    required this.createdAt,
    required this.updatedAt,
    this.migrated = false,
  });

  final String id;
  final AyahIdentifier ayah;
  final int page;
  final FasilSlot? slot;
  final String? name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool migrated;

  Place copyWith({
    AyahIdentifier? ayah,
    int? page,
    String? name,
    bool clearName = false,
    DateTime? updatedAt,
  }) => Place(
    id: id,
    ayah: ayah ?? this.ayah,
    page: page ?? this.page,
    slot: slot,
    name: clearName ? null : name ?? this.name,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    migrated: migrated,
  );

  @override
  List<Object?> get props => [
    id,
    ayah,
    page,
    slot,
    name,
    createdAt,
    updatedAt,
    migrated,
  ];
}
