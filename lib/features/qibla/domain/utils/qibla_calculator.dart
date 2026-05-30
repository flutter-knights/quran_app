import 'dart:math' as math;

import 'package:quran_app/features/qibla/domain/entities/compass_rose.dart';

/// Pure great-circle geometry for the Qibla. No I/O, no Flutter.
abstract class QiblaCalculator {
  /// Kaaba coordinates (decimal degrees).
  static const double kaabaLat = 21.4225;
  static const double kaabaLon = 39.8262;
  static const double _earthRadiusKm = 6371.0;
  static const double _alignThresholdDeg = 5.0;

  static double _rad(double deg) => deg * math.pi / 180.0;
  static double _deg(double rad) => rad * 180.0 / math.pi;

  /// Normalizes any angle in degrees into [0, 360).
  static double normalize(double deg) {
    final m = deg % 360.0;
    return m < 0 ? m + 360.0 : m;
  }

  /// Initial great-circle bearing (degrees clockwise from TRUE north) from
  /// (lat, lon) to the Kaaba.
  static double bearingToKaaba(double lat, double lon) {
    final phi1 = _rad(lat);
    final phi2 = _rad(kaabaLat);
    final dLambda = _rad(kaabaLon - lon);
    final y = math.sin(dLambda) * math.cos(phi2);
    final x = math.cos(phi1) * math.sin(phi2) -
        math.sin(phi1) * math.cos(phi2) * math.cos(dLambda);
    return normalize(_deg(math.atan2(y, x)));
  }

  /// Haversine distance in km from (lat, lon) to the Kaaba.
  static double distanceToKaabaKm(double lat, double lon) {
    final phi1 = _rad(lat);
    final phi2 = _rad(kaabaLat);
    final dPhi = _rad(kaabaLat - lat);
    final dLambda = _rad(kaabaLon - lon);
    final a = math.sin(dPhi / 2) * math.sin(dPhi / 2) +
        math.cos(phi1) * math.cos(phi2) *
            math.sin(dLambda / 2) * math.sin(dLambda / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return _earthRadiusKm * c;
  }

  /// Maps a bearing to its 8-point compass-rose sector.
  static CompassRose roseFor(double bearing) {
    final b = normalize(bearing);
    final index = ((b + 22.5) ~/ 45) % 8;
    return CompassRose.values[index];
  }

  /// Converts a raw sensor heading to a TRUE-north heading. On iOS the heading
  /// is already true; on Android it is magnetic and must be offset by the local
  /// magnetic declination (degrees east).
  static double toTrueHeading(
    double rawHeading, {
    required double declination,
    required bool rawIsTrue,
  }) {
    final trueHeading = rawIsTrue ? rawHeading : rawHeading + declination;
    return normalize(trueHeading);
  }

  /// Angle the needle must rotate so it points at the Qibla, given a true
  /// bearing and a true heading.
  static double pointerAngle(double bearing, double trueHeading) =>
      normalize(bearing - trueHeading);

  /// True when the device is pointing within +/-5 deg of the Qibla.
  static bool isAligned(double pointerAngle) {
    final p = normalize(pointerAngle);
    return p <= _alignThresholdDeg || p >= 360 - _alignThresholdDeg;
  }
}
