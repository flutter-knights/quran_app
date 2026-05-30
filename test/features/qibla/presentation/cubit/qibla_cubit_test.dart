import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/core/usecases/usecase.dart';
import 'package:quran_app/features/home/domain/entities/location.dart';
import 'package:quran_app/features/home/domain/usecases/get_current_location.dart';
import 'package:quran_app/features/qibla/domain/entities/compass_reading.dart';
import 'package:quran_app/features/qibla/domain/entities/compass_rose.dart';
import 'package:quran_app/features/qibla/domain/entities/qibla_direction.dart';
import 'package:quran_app/features/qibla/domain/usecases/get_magnetic_declination.dart';
import 'package:quran_app/features/qibla/domain/usecases/get_qibla_direction.dart';
import 'package:quran_app/features/qibla/domain/usecases/watch_compass_heading.dart';
import 'package:quran_app/features/qibla/presentation/cubit/qibla_cubit.dart';

class _MockGetCurrentLocation extends Mock implements GetCurrentLocationUseCase {}
class _MockGetQiblaDirection extends Mock implements GetQiblaDirection {}
class _MockGetMagneticDeclination extends Mock implements GetMagneticDeclination {}
class _MockWatchCompassHeading extends Mock implements WatchCompassHeading {}

void main() {
  late _MockGetCurrentLocation getLocation;
  late _MockGetQiblaDirection getDirection;
  late _MockGetMagneticDeclination getDeclination;
  late _MockWatchCompassHeading watchHeading;

  final location = Location(latitude: 30.0444, longitude: 31.2357, city: 'Cairo', country: 'مصر');
  const direction = QiblaDirection(bearing: 136, distanceKm: 1287, rose: CompassRose.se);

  setUpAll(() {
    registerFallbackValue(NoParams());
    registerFallbackValue(
        DeclinationParams(latitude: 0, longitude: 0, date: DateTime(2024, 1, 1)));
    registerFallbackValue(Location(latitude: 0, longitude: 0));
  });

  setUp(() {
    getLocation = _MockGetCurrentLocation();
    getDirection = _MockGetQiblaDirection();
    getDeclination = _MockGetMagneticDeclination();
    watchHeading = _MockWatchCompassHeading();
    when(() => getDirection.call(any())).thenAnswer((_) async => direction);
    when(() => getDeclination.call(any())).thenAnswer((_) async => 4.0);
  });

  QiblaCubit build({
    Stream<CompassReading>? compass,
    bool rawIsTrue = false,
    Duration timeout = const Duration(milliseconds: 50),
  }) {
    when(() => watchHeading.call(any()))
        .thenAnswer((_) => compass ?? const Stream.empty());
    return QiblaCubit(
      getCurrentLocation: getLocation,
      getQiblaDirection: getDirection,
      getMagneticDeclination: getDeclination,
      watchCompassHeading: watchHeading,
      rawHeadingIsTrue: rawIsTrue,
      now: () => _epoch,
      sensorTimeout: timeout,
    );
  }

  blocTest<QiblaCubit, QiblaState>(
    'emits Loading then Loaded with a true-north heading (Android: +declination)',
    build: () {
      when(() => getLocation.call(any()))
          .thenAnswer((_) => Stream.value(Right(location)));
      return build(compass: Stream.value(const CompassReading(heading: 100, accuracy: 5)));
    },
    act: (c) => c.start(),
    wait: const Duration(milliseconds: 20),
    expect: () => [
      isA<QiblaLoading>(),
      isA<QiblaLoaded>().having((s) => s.hasCompass, 'hasCompass', true),
      isA<QiblaLoaded>()
          .having((s) => s.trueHeading, 'trueHeading', closeTo(104, 0.001))
          .having((s) => s.pointerAngle, 'pointerAngle', closeTo(32, 0.001)),
    ],
  );

  blocTest<QiblaCubit, QiblaState>(
    'emits Error when location fails',
    build: () {
      when(() => getLocation.call(any())).thenAnswer(
        (_) => Stream.value(const Left(LocationPermissionDeniedFailure('denied'))),
      );
      return build();
    },
    act: (c) => c.start(),
    expect: () => [
      isA<QiblaLoading>(),
      isA<QiblaError>().having(
        (s) => s.failure, 'failure', isA<LocationPermissionDeniedFailure>()),
    ],
  );

  blocTest<QiblaCubit, QiblaState>(
    'flips hasCompass=false when a null heading arrives',
    build: () {
      when(() => getLocation.call(any()))
          .thenAnswer((_) => Stream.value(Right(location)));
      return build(compass: Stream.value(const CompassReading(heading: null)));
    },
    act: (c) => c.start(),
    wait: const Duration(milliseconds: 20),
    expect: () => [
      isA<QiblaLoading>(),
      isA<QiblaLoaded>().having((s) => s.hasCompass, 'hasCompass', true),
      isA<QiblaLoaded>().having((s) => s.hasCompass, 'hasCompass', false),
    ],
  );

  blocTest<QiblaCubit, QiblaState>(
    'flips hasCompass=false when the sensor never emits (timeout)',
    build: () {
      when(() => getLocation.call(any()))
          .thenAnswer((_) => Stream.value(Right(location)));
      return build(compass: const Stream.empty());
    },
    act: (c) => c.start(),
    wait: const Duration(milliseconds: 120),
    expect: () => [
      isA<QiblaLoading>(),
      isA<QiblaLoaded>().having((s) => s.hasCompass, 'hasCompass', true),
      isA<QiblaLoaded>().having((s) => s.hasCompass, 'hasCompass', false),
    ],
  );
}

final _epoch = DateTime(2024, 1, 1);
