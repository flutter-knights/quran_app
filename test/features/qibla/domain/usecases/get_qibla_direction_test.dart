import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/home/domain/entities/location.dart';
import 'package:quran_app/features/qibla/domain/entities/compass_rose.dart';
import 'package:quran_app/features/qibla/domain/usecases/get_qibla_direction.dart';

void main() {
  final usecase = GetQiblaDirection();

  test('computes bearing, distance and rose for a location', () async {
    final result = await usecase(Location(latitude: 30.0444, longitude: 31.2357));
    expect(result.bearing, closeTo(136.1, 1.5));
    expect(result.distanceKm, closeTo(1287, 25));
    expect(result.rose, CompassRose.se);
  });
}
