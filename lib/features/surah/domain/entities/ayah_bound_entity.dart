import '../../../quran_playback/domain/entities/ayah_identifier.dart';
import 'normalized_rect.dart';

class AyahBoundEntity {
  final AyahIdentifier ayah;
  final List<NormalizedRect> lines;

  const AyahBoundEntity({required this.ayah, required this.lines});
}
