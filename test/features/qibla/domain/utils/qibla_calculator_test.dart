import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/qibla/domain/entities/compass_rose.dart';
import 'package:quran_app/features/qibla/domain/utils/qibla_calculator.dart';

void main() {
  group('bearingToKaaba', () {
    test('Cairo -> Makkah is roughly south-east (~136 deg)', () {
      final b = QiblaCalculator.bearingToKaaba(30.0444, 31.2357);
      expect(b, closeTo(136.1, 1.5));
    });

    test('result is always normalized to [0, 360)', () {
      final b = QiblaCalculator.bearingToKaaba(-33.8688, 151.2093); // Sydney
      expect(b, inInclusiveRange(0, 360));
      expect(b, lessThan(360));
      expect(b, closeTo(278, 2)); // ~277.5° west-northwest toward Makkah
    });
  });

  group('distanceToKaabaKm', () {
    test('Cairo -> Makkah is ~1287 km', () {
      final d = QiblaCalculator.distanceToKaabaKm(30.0444, 31.2357);
      expect(d, closeTo(1287, 25));
    });

    test('distance at the Kaaba itself is ~0', () {
      final d = QiblaCalculator.distanceToKaabaKm(21.4225, 39.8262);
      expect(d, closeTo(0, 1));
    });
  });

  group('roseFor', () {
    test('maps degrees to 8-point sectors', () {
      expect(QiblaCalculator.roseFor(0), CompassRose.n);
      expect(QiblaCalculator.roseFor(45), CompassRose.ne);
      expect(QiblaCalculator.roseFor(136), CompassRose.se);
      expect(QiblaCalculator.roseFor(315), CompassRose.nw);
      expect(QiblaCalculator.roseFor(359), CompassRose.n); // wraps
    });
  });

  group('normalize', () {
    test('wraps negatives and >360 into [0,360)', () {
      expect(QiblaCalculator.normalize(-10), closeTo(350, 1e-9));
      expect(QiblaCalculator.normalize(370), closeTo(10, 1e-9));
      expect(QiblaCalculator.normalize(360), closeTo(0, 1e-9));
    });
  });

  group('toTrueHeading', () {
    test('iOS heading is already true -> declination ignored', () {
      expect(
        QiblaCalculator.toTrueHeading(100, declination: 12, rawIsTrue: true),
        closeTo(100, 1e-9),
      );
    });

    test('Android magnetic heading -> add east declination', () {
      expect(
        QiblaCalculator.toTrueHeading(100, declination: 12, rawIsTrue: false),
        closeTo(112, 1e-9),
      );
    });

    test('wraps past 360', () {
      expect(
        QiblaCalculator.toTrueHeading(355, declination: 10, rawIsTrue: false),
        closeTo(5, 1e-9),
      );
    });
  });

  group('pointerAngle / isAligned', () {
    test('pointerAngle = normalize(bearing - trueHeading)', () {
      expect(QiblaCalculator.pointerAngle(136, 100), closeTo(36, 1e-9));
      expect(QiblaCalculator.pointerAngle(10, 350), closeTo(20, 1e-9));
    });

    test('aligned within +/-5 deg of 0', () {
      expect(QiblaCalculator.isAligned(3), isTrue);
      expect(QiblaCalculator.isAligned(357), isTrue);
      expect(QiblaCalculator.isAligned(10), isFalse);
    });
  });
}
