import '../../../quran_playback/domain/entities/ayah_identifier.dart';
import '../../domain/entities/ayah_bound_entity.dart';
import '../../domain/entities/mushaf_page_entity.dart';
import '../../domain/entities/normalized_rect.dart';

class MushafPageModel extends MushafPageEntity {
  const MushafPageModel({
    required super.pageNumber,
    required super.ayahs,
  });

  factory MushafPageModel.fromJson(Map<String, dynamic> json) {
    final ayahs = (json['ayahs'] as List)
        .cast<Map<String, dynamic>>()
        .map(_ayahFromJson)
        .toList(growable: false);
    return MushafPageModel(
      pageNumber: json['page'] as int,
      ayahs: ayahs,
    );
  }

  static AyahBoundEntity _ayahFromJson(Map<String, dynamic> json) {
    return AyahBoundEntity(
      ayah: AyahIdentifier(
        surah: json['surah'] as int,
        ayah: json['ayah'] as int,
      ),
      lines: (json['lines'] as List)
          .cast<Map<String, dynamic>>()
          .map(_rectFromJson)
          .toList(growable: false),
    );
  }

  static NormalizedRect _rectFromJson(Map<String, dynamic> json) {
    return NormalizedRect(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      w: (json['w'] as num).toDouble(),
      h: (json['h'] as num).toDouble(),
    );
  }
}
