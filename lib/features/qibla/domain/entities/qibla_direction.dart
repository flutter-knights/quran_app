import 'package:equatable/equatable.dart';
import 'package:quran_app/features/qibla/domain/entities/compass_rose.dart';

/// Pure facts about the Qibla from a location: the true-north bearing toward
/// the Kaaba and the great-circle distance to Makkah.
class QiblaDirection extends Equatable {
  const QiblaDirection({
    required this.bearing,
    required this.distanceKm,
    required this.rose,
  });

  /// Degrees clockwise from TRUE north toward the Kaaba, in [0, 360).
  final double bearing;

  /// Great-circle distance to Makkah in kilometres.
  final double distanceKm;

  /// 8-point compass-rose sector for [bearing] (label aid).
  final CompassRose rose;

  @override
  List<Object?> get props => [bearing, distanceKm, rose];
}
