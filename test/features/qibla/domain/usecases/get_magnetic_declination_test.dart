import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/qibla/domain/usecases/get_magnetic_declination.dart';

void main() {
  final usecase = GetMagneticDeclination();
  final date = DateTime(2024, 1, 1);

  test('returns a declination within global bounds', () async {
    final dec = await usecase(DeclinationParams(
        latitude: 21.4225, longitude: 39.8262, date: date));
    expect(dec, inInclusiveRange(-45.0, 45.0));
  });

  test('San Francisco has a positive (easterly) declination', () async {
    final dec = await usecase(DeclinationParams(
        latitude: 37.7749, longitude: -122.4194, date: date));
    expect(dec, greaterThan(8.0));
    expect(dec, lessThan(18.0));
  });
}
