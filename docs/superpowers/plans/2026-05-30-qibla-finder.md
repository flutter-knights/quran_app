# Qibla Finder Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Qibla finder, reachable from the Home quick-access grid, that shows a live compass needle pointing to the Kaaba (declination-corrected), with bearing, distance to Makkah, and location name — degrading to a numeric fallback when no magnetometer exists.

**Architecture:** New Clean Architecture feature module `lib/features/qibla/` mirroring `home`. Pure-Dart geometry (`QiblaCalculator`) + a declination use case (wraps the `geomag` package) + a compass-heading stream (wraps `flutter_compass`). `QiblaCubit` merges a location stream, the computed true-north Qibla bearing, magnetic declination, and live heading into a single `QiblaLoaded` state. Location is **reused** from the `home` feature's `GetCurrentLocationUseCase`. Errors use `Either<Failure, T>` (dartz); DI via GetIt; UI uses the app's `SurfaceCard` / `context.colorScheme` / `HugeIcon` conventions and the mockup layout (`Quran App (2).html`, screen 9).

**Tech Stack:** Flutter, flutter_bloc (Cubit), get_it, go_router, dartz, equatable, geolocator (existing), **flutter_compass** (new), **geomag** (new), skeletonizer, mocktail + bloc_test.

**North-reference decision (correctness-critical):** Qibla bearing is computed against **true north**. `flutter_compass` reports **true** heading on iOS (location on) and **magnetic** heading on Android. We normalize everything to true north: `trueHeading = rawIsTrue ? raw : (raw + declination)`, where `declination` (degrees east) comes from `geomag` at the user's location, and `rawIsTrue = Platform.isIOS`. The needle angle is `normalize(qiblaTrue − trueHeading)`.

**No-magnetometer detection (robust):** A device without a compass may emit a `null` heading **or never emit at all**. The cubit treats BOTH as "no compass": a `null`/absent heading sets `hasCompass = false`, and a `sensorTimeout` (default 4s) with no usable reading also flips to the fallback.

---

## File Structure

```
lib/features/qibla/
  domain/
    entities/qibla_direction.dart          # bearing + distanceKm value object
    entities/compass_reading.dart          # raw heading + accuracy
    entities/compass_rose.dart             # 8-point rose enum
    utils/qibla_calculator.dart            # pure math: bearing, distance, rose, heading conversion
    repositories/compass_repository.dart   # abstract heading stream
    usecases/get_qibla_direction.dart      # pure: Location -> QiblaDirection
    usecases/get_magnetic_declination.dart # wraps geomag
    usecases/watch_compass_heading.dart    # stream use case
  data/
    datasources/compass_data_source.dart   # wraps FlutterCompass.events
    repositories/compass_repository_impl.dart
  presentation/
    cubit/qibla_cubit.dart
    cubit/qibla_state.dart
    pages/qibla_page.dart
    pages/widgets/qibla_compass_dial.dart
    pages/widgets/qibla_status_pill.dart
    pages/widgets/qibla_degree_readout.dart
    pages/widgets/qibla_meta_cards.dart
    pages/widgets/qibla_fallback_card.dart
    pages/widgets/qibla_skeleton.dart
    utils/compass_rose_localization.dart
  qibla_di.dart

test/features/qibla/
  domain/utils/qibla_calculator_test.dart
  domain/usecases/get_qibla_direction_test.dart
  domain/usecases/get_magnetic_declination_test.dart
  data/repositories/compass_repository_impl_test.dart
  presentation/cubit/qibla_cubit_test.dart
```

**Modified:** `pubspec.yaml`, `lib/config/router/app_router.dart`, `lib/features/home/presentation/pages/widgets/quick_access_grid.dart`, `lib/core/di/dependency_injection.dart`, `lib/l10n/intl_en.arb`, `lib/l10n/intl_ar.arb`.

---

## Task 1: Add dependencies + smoke-compile (do this FIRST)

`flutter_compass` is lightly maintained — verify it builds before building on it.

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Add dependencies**

In `pubspec.yaml`, under `dependencies:` (alphabetical, near `geolocator`/`flutter_bloc`), add:

```yaml
  flutter_compass: ^0.8.1
  geomag: ^1.0.1
```

- [ ] **Step 2: Fetch**

Run: `flutter pub get`
Expected: resolves with no version conflict. If `flutter_compass: ^0.8.1` fails to resolve or later fails to compile, swap to a maintained fork `flutter_compass_plus` (same `FlutterCompass.events` / `CompassEvent` API) and note it here.

- [ ] **Step 3: Verify the two package APIs compile against our assumptions**

Create a throwaway file `lib/qibla_smoke.dart`:

```dart
// TEMP smoke test — delete after Step 5.
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geomag/geomag.dart';

void qiblaSmoke() {
  final Stream<CompassEvent?> events = FlutterCompass.events!;
  events.listen((CompassEvent? e) {
    final double? heading = e?.heading; // nullable degrees
    final double? accuracy = e?.accuracy;
    print('$heading $accuracy');
  });

  final GeoMagResult r = GeoMag().calculate(21.4225, 39.8262, 0, DateTime(2024, 1, 1));
  final double declinationEast = r.dec; // degrees east of true north
  print(declinationEast);
}
```

- [ ] **Step 4: Analyze**

Run: `flutter analyze lib/qibla_smoke.dart`
Expected: **No issues.** If `CompassEvent.heading`, `.accuracy`, `GeoMag().calculate(...)`, or `.dec` don't exist, fix the smoke file to match the real API and record the corrected signatures here before continuing (all later tasks depend on these exact symbols).

- [ ] **Step 5: Delete the smoke file & commit**

```bash
rm lib/qibla_smoke.dart
git add pubspec.yaml pubspec.lock
git commit -m "build(qibla): add flutter_compass + geomag deps"
```

---

## Task 2: Domain entities

**Files:**
- Create: `lib/features/qibla/domain/entities/qibla_direction.dart`
- Create: `lib/features/qibla/domain/entities/compass_reading.dart`
- Create: `lib/features/qibla/domain/entities/compass_rose.dart`

- [ ] **Step 1: Create the entities**

`qibla_direction.dart`:

```dart
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
```

`compass_reading.dart`:

```dart
import 'package:equatable/equatable.dart';

/// A raw heading sample from the device sensor. [heading] is null when the
/// device has no usable magnetometer.
class CompassReading extends Equatable {
  const CompassReading({this.heading, this.accuracy});

  /// Degrees clockwise from north (true on iOS, magnetic on Android), or null.
  final double? heading;

  /// Sensor accuracy in degrees (smaller is better), or null if unknown.
  final double? accuracy;

  bool get hasHeading => heading != null;

  @override
  List<Object?> get props => [heading, accuracy];
}
```

`compass_rose.dart`:

```dart
/// 8-point compass rose sectors, used to label the Qibla bearing.
enum CompassRose { n, ne, e, se, s, sw, w, nw }
```

- [ ] **Step 2: Analyze & commit**

```bash
flutter analyze lib/features/qibla/domain/entities
git add lib/features/qibla/domain/entities
git commit -m "feat(qibla): add QiblaDirection, CompassReading, CompassRose entities"
```

---

## Task 3: QiblaCalculator (pure geometry) — TDD

This is the correctness core. Pure functions, fully testable.

**Files:**
- Create: `lib/features/qibla/domain/utils/qibla_calculator.dart`
- Test: `test/features/qibla/domain/utils/qibla_calculator_test.dart`

- [ ] **Step 1: Write the failing test**

`test/features/qibla/domain/utils/qibla_calculator_test.dart`:

```dart
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/qibla/domain/utils/qibla_calculator_test.dart`
Expected: FAIL — `QiblaCalculator` is not defined.

- [ ] **Step 3: Write the implementation**

`lib/features/qibla/domain/utils/qibla_calculator.dart`:

```dart
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/qibla/domain/utils/qibla_calculator_test.dart`
Expected: PASS (all groups).

- [ ] **Step 5: Commit**

```bash
git add lib/features/qibla/domain/utils/qibla_calculator.dart test/features/qibla/domain/utils/qibla_calculator_test.dart
git commit -m "feat(qibla): add QiblaCalculator great-circle geometry (TDD)"
```

---

## Task 4: GetQiblaDirection use case (pure) — TDD

Pure math, cannot fail → returns `Future<QiblaDirection>` (no `Either`).

**Files:**
- Create: `lib/features/qibla/domain/usecases/get_qibla_direction.dart`
- Test: `test/features/qibla/domain/usecases/get_qibla_direction_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/qibla/domain/usecases/get_qibla_direction_test.dart`
Expected: FAIL — `GetQiblaDirection` undefined.

- [ ] **Step 3: Write the implementation**

```dart
import 'package:quran_app/core/usecases/usecase.dart';
import 'package:quran_app/features/home/domain/entities/location.dart';
import 'package:quran_app/features/qibla/domain/entities/qibla_direction.dart';
import 'package:quran_app/features/qibla/domain/utils/qibla_calculator.dart';

/// Pure computation: turns a [Location] into the Qibla bearing + distance.
/// Cannot fail, so it returns the value directly (no Either).
class GetQiblaDirection implements UseCase<QiblaDirection, Location> {
  @override
  Future<QiblaDirection> call(Location params) async {
    final bearing =
        QiblaCalculator.bearingToKaaba(params.latitude, params.longitude);
    final distance =
        QiblaCalculator.distanceToKaabaKm(params.latitude, params.longitude);
    return QiblaDirection(
      bearing: bearing,
      distanceKm: distance,
      rose: QiblaCalculator.roseFor(bearing),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/qibla/domain/usecases/get_qibla_direction_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/qibla/domain/usecases/get_qibla_direction.dart test/features/qibla/domain/usecases/get_qibla_direction_test.dart
git commit -m "feat(qibla): add GetQiblaDirection use case (TDD)"
```

---

## Task 5: GetMagneticDeclination use case (wraps geomag) — TDD

**Files:**
- Create: `lib/features/qibla/domain/usecases/get_magnetic_declination.dart`
- Test: `test/features/qibla/domain/usecases/get_magnetic_declination_test.dart`

- [ ] **Step 1: Write the failing test**

`geomag` is deterministic; we assert plausible global bounds plus a directional check (San Francisco has a strong easterly/positive declination; the Kaaba a small one). Tolerances are generous because bundled coefficients are WMM2020.

```dart
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/qibla/domain/usecases/get_magnetic_declination_test.dart`
Expected: FAIL — `GetMagneticDeclination` undefined.

- [ ] **Step 3: Write the implementation**

```dart
import 'package:equatable/equatable.dart';
import 'package:geomag/geomag.dart';
import 'package:quran_app/core/usecases/usecase.dart';

class DeclinationParams extends Equatable {
  const DeclinationParams({
    required this.latitude,
    required this.longitude,
    required this.date,
  });

  final double latitude;
  final double longitude;
  final DateTime date;

  @override
  List<Object?> get props => [latitude, longitude, date];
}

/// Magnetic declination (degrees east of true north) at a location, from the
/// World Magnetic Model via the `geomag` package. Pure computation.
class GetMagneticDeclination implements UseCase<double, DeclinationParams> {
  GetMagneticDeclination({GeoMag? geoMag}) : _geoMag = geoMag ?? GeoMag();

  final GeoMag _geoMag;

  @override
  Future<double> call(DeclinationParams params) async {
    final result = _geoMag.calculate(
      params.latitude,
      params.longitude,
      0, // altitude in feet
      params.date,
    );
    return result.dec;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/qibla/domain/usecases/get_magnetic_declination_test.dart`
Expected: PASS. If the SF bounds fail, log the actual value and widen to the nearest 0.5° — do not change the production code.

- [ ] **Step 5: Commit**

```bash
git add lib/features/qibla/domain/usecases/get_magnetic_declination.dart test/features/qibla/domain/usecases/get_magnetic_declination_test.dart
git commit -m "feat(qibla): add GetMagneticDeclination use case via geomag (TDD)"
```

---

## Task 6: CompassRepository + DataSource + Impl — TDD

**Files:**
- Create: `lib/features/qibla/domain/repositories/compass_repository.dart`
- Create: `lib/features/qibla/data/datasources/compass_data_source.dart`
- Create: `lib/features/qibla/data/repositories/compass_repository_impl.dart`
- Create: `lib/features/qibla/domain/usecases/watch_compass_heading.dart`
- Test: `test/features/qibla/data/repositories/compass_repository_impl_test.dart`

- [ ] **Step 1: Create the abstract repository**

`compass_repository.dart`:

```dart
import 'package:quran_app/features/qibla/domain/entities/compass_reading.dart';

abstract class CompassRepository {
  /// Emits a [CompassReading] per sensor sample. On devices without a
  /// magnetometer the stream may emit readings with a null heading or never
  /// emit at all — the cubit handles both.
  Stream<CompassReading> watchHeading();
}
```

- [ ] **Step 2: Create the data source**

`compass_data_source.dart` — thin integration glue over the plugin (the `FlutterCompass.events.map` line is an untested boundary; the mapping is trivial):

```dart
import 'package:flutter_compass/flutter_compass.dart';
import 'package:quran_app/features/qibla/domain/entities/compass_reading.dart';

class CompassDataSource {
  /// Defaults to the real plugin stream; injectable for tests.
  CompassDataSource({Stream<CompassEvent?>? events})
      : _events = events ?? FlutterCompass.events;

  final Stream<CompassEvent?>? _events;

  Stream<CompassReading> headingStream() {
    final source = _events;
    if (source == null) {
      // Plugin reports the platform has no compass support at all.
      return Stream.value(const CompassReading(heading: null));
    }
    return source.map(
      (e) => CompassReading(heading: e?.heading, accuracy: e?.accuracy),
    );
  }
}
```

- [ ] **Step 3: Create the repository impl**

`compass_repository_impl.dart`:

```dart
import 'package:quran_app/features/qibla/data/datasources/compass_data_source.dart';
import 'package:quran_app/features/qibla/domain/entities/compass_reading.dart';
import 'package:quran_app/features/qibla/domain/repositories/compass_repository.dart';

class CompassRepositoryImpl implements CompassRepository {
  CompassRepositoryImpl({required this.dataSource});

  final CompassDataSource dataSource;

  @override
  Stream<CompassReading> watchHeading() => dataSource.headingStream();
}
```

- [ ] **Step 4: Create the stream use case**

`watch_compass_heading.dart`:

```dart
import 'package:quran_app/core/usecases/stream_usecase.dart';
import 'package:quran_app/core/usecases/usecase.dart';
import 'package:quran_app/features/qibla/domain/entities/compass_reading.dart';
import 'package:quran_app/features/qibla/domain/repositories/compass_repository.dart';

class WatchCompassHeading extends StreamUseCase<CompassReading, NoParams> {
  WatchCompassHeading({required this.repository});

  final CompassRepository repository;

  @override
  Stream<CompassReading> call(NoParams params) => repository.watchHeading();
}
```

- [ ] **Step 5: Write the failing test**

`test/features/qibla/data/repositories/compass_repository_impl_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/features/qibla/data/datasources/compass_data_source.dart';
import 'package:quran_app/features/qibla/data/repositories/compass_repository_impl.dart';
import 'package:quran_app/features/qibla/domain/entities/compass_reading.dart';

class _MockCompassDataSource extends Mock implements CompassDataSource {}

void main() {
  late _MockCompassDataSource ds;
  late CompassRepositoryImpl repo;

  setUp(() {
    ds = _MockCompassDataSource();
    repo = CompassRepositoryImpl(dataSource: ds);
  });

  test('forwards the data source stream', () {
    when(() => ds.headingStream()).thenAnswer(
      (_) => Stream.fromIterable(const [
        CompassReading(heading: 90, accuracy: 5),
        CompassReading(heading: 91, accuracy: 5),
      ]),
    );

    expect(
      repo.watchHeading(),
      emitsInOrder(const [
        CompassReading(heading: 90, accuracy: 5),
        CompassReading(heading: 91, accuracy: 5),
      ]),
    );
  });

  test('passes through a null-heading reading (no magnetometer)', () {
    when(() => ds.headingStream()).thenAnswer(
      (_) => Stream.value(const CompassReading(heading: null)),
    );

    expect(
      repo.watchHeading(),
      emits(const CompassReading(heading: null)),
    );
  });
}
```

- [ ] **Step 6: Run test to verify it fails, then passes**

Run: `flutter test test/features/qibla/data/repositories/compass_repository_impl_test.dart`
Expected: FAIL first (types undefined) → after Steps 1-4 exist, PASS.

- [ ] **Step 7: Analyze & commit**

```bash
flutter analyze lib/features/qibla/domain/repositories lib/features/qibla/data lib/features/qibla/domain/usecases/watch_compass_heading.dart
git add lib/features/qibla/domain/repositories lib/features/qibla/data lib/features/qibla/domain/usecases/watch_compass_heading.dart test/features/qibla/data
git commit -m "feat(qibla): add CompassRepository, data source, impl + WatchCompassHeading (TDD)"
```

---

## Task 7: QiblaState + QiblaCubit — TDD

**Files:**
- Create: `lib/features/qibla/presentation/cubit/qibla_state.dart`
- Create: `lib/features/qibla/presentation/cubit/qibla_cubit.dart`
- Test: `test/features/qibla/presentation/cubit/qibla_cubit_test.dart`

- [ ] **Step 1: Write the state**

`qibla_state.dart`:

```dart
part of 'qibla_cubit.dart';

abstract class QiblaState extends Equatable {
  const QiblaState();
  @override
  List<Object?> get props => [];
}

class QiblaInitial extends QiblaState {
  const QiblaInitial();
}

class QiblaLoading extends QiblaState {
  const QiblaLoading();
}

class QiblaError extends QiblaState {
  const QiblaError(this.failure);
  final Failure failure;
  @override
  List<Object?> get props => [failure];
}

class QiblaLoaded extends QiblaState {
  const QiblaLoaded({
    required this.direction,
    required this.locationName,
    required this.hasCompass,
    this.trueHeading,
    this.accuracy,
  });

  final QiblaDirection direction;
  final String? locationName;

  /// false => no magnetometer; UI shows the numeric fallback.
  final bool hasCompass;

  /// Device heading already converted to TRUE north; null until first reading.
  final double? trueHeading;
  final double? accuracy;

  double? get pointerAngle => trueHeading == null
      ? null
      : QiblaCalculator.pointerAngle(direction.bearing, trueHeading!);

  bool get isAligned =>
      pointerAngle != null && QiblaCalculator.isAligned(pointerAngle!);

  /// Low-accuracy => prompt calibration (figure-8). >15 deg is unreliable.
  bool get needsCalibration => accuracy != null && accuracy! > 15;

  QiblaLoaded copyWith({double? trueHeading, double? accuracy, bool? hasCompass}) {
    return QiblaLoaded(
      direction: direction,
      locationName: locationName,
      hasCompass: hasCompass ?? this.hasCompass,
      trueHeading: trueHeading ?? this.trueHeading,
      accuracy: accuracy ?? this.accuracy,
    );
  }

  @override
  List<Object?> get props =>
      [direction, locationName, hasCompass, trueHeading, accuracy];
}
```

- [ ] **Step 2: Write the cubit**

`qibla_cubit.dart`:

```dart
import 'dart:async';
import 'dart:io' show Platform;

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/core/usecases/usecase.dart';
import 'package:quran_app/features/home/domain/entities/location.dart';
import 'package:quran_app/features/home/domain/usecases/get_current_location.dart';
import 'package:quran_app/features/qibla/domain/entities/compass_reading.dart';
import 'package:quran_app/features/qibla/domain/entities/qibla_direction.dart';
import 'package:quran_app/features/qibla/domain/usecases/get_magnetic_declination.dart';
import 'package:quran_app/features/qibla/domain/usecases/get_qibla_direction.dart';
import 'package:quran_app/features/qibla/domain/usecases/watch_compass_heading.dart';
import 'package:quran_app/features/qibla/domain/utils/qibla_calculator.dart';

part 'qibla_state.dart';

class QiblaCubit extends Cubit<QiblaState> {
  QiblaCubit({
    required this.getCurrentLocation,
    required this.getQiblaDirection,
    required this.getMagneticDeclination,
    required this.watchCompassHeading,
    DateTime Function()? now,
    bool? rawHeadingIsTrue,
    this.sensorTimeout = const Duration(seconds: 4),
  })  : _now = now ?? DateTime.now,
        _rawHeadingIsTrue = rawHeadingIsTrue ?? Platform.isIOS,
        super(const QiblaInitial());

  final GetCurrentLocationUseCase getCurrentLocation;
  final GetQiblaDirection getQiblaDirection;
  final GetMagneticDeclination getMagneticDeclination;
  final WatchCompassHeading watchCompassHeading;
  final Duration sensorTimeout;

  final DateTime Function() _now;
  final bool _rawHeadingIsTrue;

  StreamSubscription<dynamic>? _locationSub;
  StreamSubscription<CompassReading>? _compassSub;
  Timer? _sensorTimer;
  double _declination = 0;

  /// Entry point — call once when the page mounts.
  Future<void> start() async {
    emit(const QiblaLoading());
    await _locationSub?.cancel();
    _locationSub = getCurrentLocation(NoParams()).listen((result) {
      if (isClosed) return;
      result.fold(
        (failure) => emit(QiblaError(failure)),
        _onLocation,
      );
    });
  }

  /// Re-run the whole pipeline (recalibrate button).
  Future<void> recalibrate() => start();

  Future<void> _onLocation(Location location) async {
    final direction = await getQiblaDirection(location);
    _declination = await getMagneticDeclination(DeclinationParams(
      latitude: location.latitude,
      longitude: location.longitude,
      date: _now(),
    ));
    if (isClosed) return;

    emit(QiblaLoaded(
      direction: direction,
      locationName: _locationName(location),
      hasCompass: true, // optimistic; flipped false on null/timeout
    ));

    _listenToCompass();
  }

  void _listenToCompass() {
    _sensorTimer?.cancel();
    _compassSub?.cancel();

    // No reading within the timeout => treat as "no compass".
    _sensorTimer = Timer(sensorTimeout, () {
      final s = state;
      if (!isClosed && s is QiblaLoaded && s.trueHeading == null) {
        emit(s.copyWith(hasCompass: false));
      }
    });

    _compassSub = watchCompassHeading(NoParams()).listen((reading) {
      if (isClosed) return;
      final s = state;
      if (s is! QiblaLoaded) return;

      if (!reading.hasHeading) {
        _sensorTimer?.cancel();
        emit(s.copyWith(hasCompass: false));
        return;
      }

      _sensorTimer?.cancel();
      final trueHeading = QiblaCalculator.toTrueHeading(
        reading.heading!,
        declination: _declination,
        rawIsTrue: _rawHeadingIsTrue,
      );
      emit(s.copyWith(
        trueHeading: trueHeading,
        accuracy: reading.accuracy,
        hasCompass: true,
      ));
    });
  }

  String? _locationName(Location l) {
    final city = l.city ?? l.enCity;
    final country = l.country ?? l.enCountry;
    if (city != null && country != null) return '$city، $country';
    return city ?? country;
  }

  @override
  Future<void> close() {
    _locationSub?.cancel();
    _compassSub?.cancel();
    _sensorTimer?.cancel();
    return super.close();
  }
}
```

> Note: `copyWith` cannot null-out `trueHeading`; that's fine — once a real heading arrives we never go back to null. The timeout only fires while `trueHeading == null`.

- [ ] **Step 3: Write the failing test**

`test/features/qibla/presentation/cubit/qibla_cubit_test.dart`:

```dart
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
          .having((s) => s.trueHeading, 'trueHeading', closeTo(104, 0.001)) // 100 + 4
          .having((s) => s.pointerAngle, 'pointerAngle', closeTo(32, 0.001)), // 136 - 104
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
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/qibla/presentation/cubit/qibla_cubit_test.dart`
Expected: FAIL first → PASS once cubit/state compile.

- [ ] **Step 5: Commit**

```bash
git add lib/features/qibla/presentation/cubit test/features/qibla/presentation/cubit
git commit -m "feat(qibla): add QiblaCubit + state with declination-corrected heading (TDD)"
```

---

## Task 8: DI wiring

`GetCurrentLocationUseCase` exists but is **not** registered anywhere. Register it here (wired to the existing `LocationRepository` singleton) so the Qibla cubit can reuse it without touching `home`.

**Files:**
- Create: `lib/features/qibla/qibla_di.dart`
- Modify: `lib/core/di/dependency_injection.dart`

- [ ] **Step 1: Create `qibla_di.dart`**

```dart
import 'package:quran_app/core/di/dependency_injection.dart';
import 'package:quran_app/features/home/domain/repositories/location_repository.dart';
import 'package:quran_app/features/home/domain/usecases/get_current_location.dart';
import 'package:quran_app/features/qibla/data/datasources/compass_data_source.dart';
import 'package:quran_app/features/qibla/data/repositories/compass_repository_impl.dart';
import 'package:quran_app/features/qibla/domain/repositories/compass_repository.dart';
import 'package:quran_app/features/qibla/domain/usecases/get_magnetic_declination.dart';
import 'package:quran_app/features/qibla/domain/usecases/get_qibla_direction.dart';
import 'package:quran_app/features/qibla/domain/usecases/watch_compass_heading.dart';
import 'package:quran_app/features/qibla/presentation/cubit/qibla_cubit.dart';

void initQibla() {
  // Data sources
  sl.registerLazySingleton(() => CompassDataSource());

  // Repositories
  sl.registerLazySingleton<CompassRepository>(
    () => CompassRepositoryImpl(dataSource: sl()),
  );

  // Use cases
  sl.registerLazySingleton(
    () => GetCurrentLocationUseCase(locationRepository: sl<LocationRepository>()),
  );
  sl.registerLazySingleton(() => GetQiblaDirection());
  sl.registerLazySingleton(() => GetMagneticDeclination());
  sl.registerLazySingleton(() => WatchCompassHeading(repository: sl()));

  // Cubit
  sl.registerFactory(
    () => QiblaCubit(
      getCurrentLocation: sl(),
      getQiblaDirection: sl(),
      getMagneticDeclination: sl(),
      watchCompassHeading: sl(),
    ),
  );
}
```

- [ ] **Step 2: Call it from the bootstrap**

In `lib/core/di/dependency_injection.dart`, add the import and call `initQibla();` **after** `initHome();` (it depends on home's `LocationRepository`):

```dart
import 'package:quran_app/features/qibla/qibla_di.dart';
// ...
  initHome();
  initQibla();
```

- [ ] **Step 3: Analyze & commit**

```bash
flutter analyze lib/features/qibla/qibla_di.dart lib/core/di/dependency_injection.dart
git add lib/features/qibla/qibla_di.dart lib/core/di/dependency_injection.dart
git commit -m "feat(qibla): register Qibla feature in DI"
```

---

## Task 9: Localization strings

**Files:**
- Modify: `lib/l10n/intl_en.arb`, `lib/l10n/intl_ar.arb`

- [ ] **Step 1: Add keys to `intl_en.arb`** (before the closing brace; copy the existing comma style)

```json
  "qibla_screen_title": "Qibla",
  "qibla_app_bar_label": "Qibla Direction",
  "qibla_point_to_kaaba": "Point your phone toward the Kaaba",
  "qibla_aligned": "Aligned with the Qibla",
  "qibla_bearing_suffix": "Qibla bearing",
  "qibla_to_makkah": "To Makkah",
  "qibla_your_location": "Your location",
  "qibla_distance_km": "{km} km",
  "qibla_no_compass_title": "No compass on this device",
  "qibla_align_manually": "Face {deg}° from North to face the Qibla.",
  "qibla_calibrate_hint": "Wave your phone in a figure-8 to calibrate",
  "qibla_recalibrate": "Recalibrate",
  "compass_rose_n": "North",
  "compass_rose_ne": "North-East",
  "compass_rose_e": "East",
  "compass_rose_se": "South-East",
  "compass_rose_s": "South",
  "compass_rose_sw": "South-West",
  "compass_rose_w": "West",
  "compass_rose_nw": "North-West",
```

- [ ] **Step 2: Add the same keys to `intl_ar.arb`**

```json
  "qibla_screen_title": "القبلة",
  "qibla_app_bar_label": "اتجاه القبلة",
  "qibla_point_to_kaaba": "وجِّه هاتفك نحو الكعبة",
  "qibla_aligned": "في اتجاه القبلة",
  "qibla_bearing_suffix": "اتجاه القبلة",
  "qibla_to_makkah": "إلى مكة المكرمة",
  "qibla_your_location": "موقعك الحالي",
  "qibla_distance_km": "{km} كم",
  "qibla_no_compass_title": "لا يوجد بوصلة في هذا الجهاز",
  "qibla_align_manually": "اتجه نحو {deg}° من الشمال لمواجهة القبلة.",
  "qibla_calibrate_hint": "حرّك هاتفك على شكل ٨ لمعايرة البوصلة",
  "qibla_recalibrate": "إعادة المعايرة",
  "compass_rose_n": "شمال",
  "compass_rose_ne": "شمال شرق",
  "compass_rose_e": "شرق",
  "compass_rose_se": "جنوب شرق",
  "compass_rose_s": "جنوب",
  "compass_rose_sw": "جنوب غرب",
  "compass_rose_w": "غرب",
  "compass_rose_nw": "شمال غرب",
```

> If the ARB files use `@key` metadata blocks for placeholders, add metadata for `qibla_distance_km` and `qibla_align_manually` matching the existing convention (e.g. `"@qibla_align_manually": {"placeholders": {"deg": {}}}`). Check a neighbouring placeholder key first.

- [ ] **Step 3: Regenerate l10n** (per `.claude/rules/localization.md` / memory)

Run: `dart run intl_utils:generate`
Expected: `lib/generated/l10n.dart` now exposes `qibla_screen_title`, `compass_rose_se`, etc.

- [ ] **Step 4: Commit**

```bash
git add lib/l10n/intl_en.arb lib/l10n/intl_ar.arb lib/generated
git commit -m "feat(l10n): add Qibla finder strings"
```

---

## Task 10: Presentation — rose localization + small widgets

**Files:**
- Create: `lib/features/qibla/presentation/utils/compass_rose_localization.dart`
- Create: `lib/features/qibla/presentation/pages/widgets/qibla_status_pill.dart`
- Create: `lib/features/qibla/presentation/pages/widgets/qibla_degree_readout.dart`
- Create: `lib/features/qibla/presentation/pages/widgets/qibla_meta_cards.dart`

- [ ] **Step 1: Rose localization** (presentation layer, per `.claude/rules/localization.md`)

`compass_rose_localization.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:quran_app/features/qibla/domain/entities/compass_rose.dart';
import 'package:quran_app/generated/l10n.dart';

extension CompassRoseL10n on CompassRose {
  String localized(BuildContext context) {
    final s = S.of(context);
    switch (this) {
      case CompassRose.n:  return s.compass_rose_n;
      case CompassRose.ne: return s.compass_rose_ne;
      case CompassRose.e:  return s.compass_rose_e;
      case CompassRose.se: return s.compass_rose_se;
      case CompassRose.s:  return s.compass_rose_s;
      case CompassRose.sw: return s.compass_rose_sw;
      case CompassRose.w:  return s.compass_rose_w;
      case CompassRose.nw: return s.compass_rose_nw;
    }
  }
}

/// Renders an int using Arabic-Indic digits when the locale is Arabic, mirroring
/// the convention in mushaf_top_bar.dart.
String localizeDigits(BuildContext context, int n) {
  const arabic = ['٠','١','٢','٣','٤','٥','٦','٧','٨','٩'];
  final isAr = Localizations.localeOf(context).languageCode == 'ar';
  final s = n.toString();
  if (!isAr) return s;
  return s.split('').map((c) {
    final d = int.tryParse(c);
    return d == null ? c : arabic[d];
  }).join();
}
```

- [ ] **Step 2: Status pill**

`qibla_status_pill.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/generated/l10n.dart';

class QiblaStatusPill extends StatelessWidget {
  const QiblaStatusPill({
    super.key,
    required this.isAligned,
    required this.needsCalibration,
  });

  final bool isAligned;
  final bool needsCalibration;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final s = S.of(context);
    final aligned = isAligned && !needsCalibration;
    final color = aligned ? const Color(0xFF3D9E6E) : scheme.onSurfaceVariant;
    final label = needsCalibration
        ? s.qibla_calibrate_hint
        : aligned
            ? s.qibla_aligned
            : s.qibla_point_to_kaaba;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: aligned
            ? const Color(0x1F3D9E6E)
            : scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: context.cardBorder(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7, height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(label, style: TS.bold14.copyWith(color: color)),
        ],
      ),
    );
  }
}
```

> If `TS.bold14` doesn't exist, open `lib/config/theme/typography_styles.dart` and use the nearest 14px style (the recovery card uses `TS.regular14`/`TS.bold16`).

- [ ] **Step 3: Degree readout**

`qibla_degree_readout.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/features/qibla/domain/entities/compass_rose.dart';
import 'package:quran_app/features/qibla/presentation/utils/compass_rose_localization.dart';
import 'package:quran_app/generated/l10n.dart';

class QiblaDegreeReadout extends StatelessWidget {
  const QiblaDegreeReadout({super.key, required this.bearing, required this.rose});

  final double bearing;
  final CompassRose rose;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final deg = localizeDigits(context, bearing.round());
    return Column(
      children: [
        Text('$deg°',
            style: TS.bold16.copyWith(
              fontSize: 40, height: 1, color: scheme.onSurface,
            )),
        const SizedBox(height: 4),
        Text(
          '${rose.localized(context)} · ${S.of(context).qibla_bearing_suffix}',
          style: TS.regular14.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Meta cards**

`qibla_meta_cards.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/widgets/design/surface_card.dart';
import 'package:quran_app/features/qibla/presentation/utils/compass_rose_localization.dart';
import 'package:quran_app/generated/l10n.dart';

class QiblaMetaCards extends StatelessWidget {
  const QiblaMetaCards({
    super.key,
    required this.locationName,
    required this.distanceKm,
  });

  final String? locationName;
  final double distanceKm;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Row(
      children: [
        Expanded(child: _MetaCard(
          icon: HugeIcons.strokeRoundedLocation01,
          value: locationName ?? '—',
          label: s.qibla_your_location,
        )),
        const SizedBox(width: 10),
        Expanded(child: _MetaCard(
          icon: HugeIcons.strokeRoundedGlobe02,
          value: s.qibla_distance_km(localizeDigits(context, distanceKm.round())),
          label: s.qibla_to_makkah,
        )),
      ],
    );
  }
}

class _MetaCard extends StatelessWidget {
  const _MetaCard({required this.icon, required this.value, required this.label});

  final List<List<dynamic>> icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          HugeIcon(icon: icon, size: 18, color: scheme.secondary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TS.bold14.copyWith(color: scheme.onSurface)),
                Text(label, style: TS.regular12.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

> Verify `HugeIcons.strokeRoundedGlobe02` and `scheme.secondary` exist; if not, pick the nearest globe icon and `scheme.primary`. Use the nearest existing `TS` styles if `bold14`/`regular12` aren't defined.

- [ ] **Step 5: Analyze & commit**

```bash
flutter analyze lib/features/qibla/presentation/utils lib/features/qibla/presentation/pages/widgets/qibla_status_pill.dart lib/features/qibla/presentation/pages/widgets/qibla_degree_readout.dart lib/features/qibla/presentation/pages/widgets/qibla_meta_cards.dart
git add lib/features/qibla/presentation/utils lib/features/qibla/presentation/pages/widgets
git commit -m "feat(qibla): add rose localization, status pill, degree readout, meta cards"
```

---

## Task 11: Compass dial widget (CustomPaint + rotating needle)

**Files:**
- Create: `lib/features/qibla/presentation/pages/widgets/qibla_compass_dial.dart`

- [ ] **Step 1: Implement the dial**

Translates the mockup: static tick dial (6° steps; cardinal/30° longer), N/E/S/W letters, secondary-tinted N, centre hub, and a Qibla needle that rotates by `pointerAngle` (static when null/fallback). `AnimatedRotation` handles smoothing; turns are given in fractions of a full turn so 359°→0° animates the short way only when we keep the value continuous — we accept the simple wrap (a brief long-way spin at the 360 boundary is acceptable for a compass).

```dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:quran_app/config/theme/color_scheme.dart';

class QiblaCompassDial extends StatelessWidget {
  const QiblaCompassDial({
    super.key,
    required this.pointerAngle, // degrees; null => static (fallback)
    required this.size,
  });

  final double? pointerAngle;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final angle = (pointerAngle ?? 0) * math.pi / 180.0;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Dial face + ticks
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.surfaceContainer,
              border: context.cardBorder(),
            ),
            child: CustomPaint(
              painter: _DialPainter(
                tick: scheme.onSurface.withValues(alpha: 0.12),
                cardinal: scheme.onSurfaceVariant,
              ),
            ),
          ),
          // Cardinal letters
          _Letter('N', Alignment.topCenter, scheme.secondary),
          _Letter('E', Alignment.centerRight, scheme.onSurfaceVariant),
          _Letter('S', Alignment.bottomCenter, scheme.onSurfaceVariant),
          _Letter('W', Alignment.centerLeft, scheme.onSurfaceVariant),
          // Rotating needle
          AnimatedRotation(
            turns: angle / (2 * math.pi),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
            child: _Needle(size: size, color: scheme.primary, accent: scheme.secondary),
          ),
          // Hub
          Container(
            width: 16, height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.secondary,
              border: Border.all(color: scheme.surface, width: 3),
            ),
          ),
        ],
      ),
    );
  }
}

class _Letter extends StatelessWidget {
  const _Letter(this.text, this.alignment, this.color);
  final String text;
  final Alignment alignment;
  final Color color;
  @override
  Widget build(BuildContext context) => Align(
        alignment: alignment,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Text(text,
              style: TextStyle(fontWeight: FontWeight.w700, color: color, fontSize: 14)),
        ),
      );
}

class _Needle extends StatelessWidget {
  const _Needle({required this.size, required this.color, required this.accent});
  final double size;
  final Color color;
  final Color accent;
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        SizedBox(height: size * 0.08),
        // Kaaba marker
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accent, width: 2),
          ),
          child: const Icon(Icons.mosque, color: Color(0xFFC8A24A), size: 20),
        ),
        // Beam
        Container(
          width: 3, height: size * 0.25,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [accent, accent.withValues(alpha: 0)],
            ),
          ),
        ),
      ],
    );
  }
}

class _DialPainter extends CustomPainter {
  _DialPainter({required this.tick, required this.cardinal});
  final Color tick;
  final Color cardinal;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rOuter = size.width / 2 - 6;
    for (var deg = 0; deg < 360; deg += 6) {
      final isCardinal = deg % 90 == 0;
      final len = isCardinal ? 14.0 : (deg % 30 == 0 ? 10.0 : 6.0);
      final a = (deg - 90) * math.pi / 180.0;
      final p1 = center + Offset(math.cos(a), math.sin(a)) * rOuter;
      final p2 = center + Offset(math.cos(a), math.sin(a)) * (rOuter - len);
      final paint = Paint()
        ..color = isCardinal ? cardinal : tick
        ..strokeWidth = isCardinal ? 2 : 1.5;
      canvas.drawLine(p1, p2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DialPainter old) =>
      old.tick != tick || old.cardinal != cardinal;
}
```

> Verify `Icons.mosque` exists in the SDK; if not, use a HugeIcon Kaaba/mosque glyph or a simple `Icon(Icons.location_on)`.

- [ ] **Step 2: Analyze & commit**

```bash
flutter analyze lib/features/qibla/presentation/pages/widgets/qibla_compass_dial.dart
git add lib/features/qibla/presentation/pages/widgets/qibla_compass_dial.dart
git commit -m "feat(qibla): add compass dial with rotating Qibla needle"
```

---

## Task 12: Fallback card + skeleton

**Files:**
- Create: `lib/features/qibla/presentation/pages/widgets/qibla_fallback_card.dart`
- Create: `lib/features/qibla/presentation/pages/widgets/qibla_skeleton.dart`

- [ ] **Step 1: Fallback card** (shown when `hasCompass == false`)

```dart
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/widgets/design/surface_card.dart';
import 'package:quran_app/features/qibla/presentation/utils/compass_rose_localization.dart';
import 'package:quran_app/generated/l10n.dart';

class QiblaFallbackCard extends StatelessWidget {
  const QiblaFallbackCard({super.key, required this.bearing});
  final double bearing;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final s = S.of(context);
    final deg = localizeDigits(context, bearing.round());
    return SurfaceCard(
      child: Column(
        children: [
          HugeIcon(icon: HugeIcons.strokeRoundedCompass, color: scheme.primary, size: 30),
          const SizedBox(height: 12),
          Text(s.qibla_no_compass_title,
              textAlign: TextAlign.center, style: TS.bold16.copyWith(color: scheme.onSurface)),
          const SizedBox(height: 8),
          Text(s.qibla_align_manually(deg),
              textAlign: TextAlign.center,
              style: TS.regular14.copyWith(color: scheme.onSurface.withValues(alpha: 0.7))),
        ],
      ),
    );
  }
}
```

> Verify `HugeIcons.strokeRoundedCompass` exists; otherwise use `strokeRoundedNavigation03` or similar.

- [ ] **Step 2: Skeleton** (per `.claude/rules/loading-states.md` — `Skeletonizer`, not a spinner)

```dart
import 'package:flutter/material.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/features/qibla/domain/entities/compass_rose.dart';
import 'package:quran_app/features/qibla/presentation/pages/widgets/qibla_compass_dial.dart';
import 'package:quran_app/features/qibla/presentation/pages/widgets/qibla_degree_readout.dart';
import 'package:quran_app/features/qibla/presentation/pages/widgets/qibla_meta_cards.dart';
import 'package:skeletonizer/skeletonizer.dart';

class QiblaSkeleton extends StatelessWidget {
  const QiblaSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 24, 18, 24),
        child: Column(
          children: [
            QiblaCompassDial(pointerAngle: 0, size: 260),
            const SizedBox(height: 24),
            const QiblaDegreeReadout(bearing: 298, rose: CompassRose.nw),
            const SizedBox(height: 20),
            const QiblaMetaCards(locationName: 'Cairo, Egypt', distanceKm: 1234),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Analyze & commit**

```bash
flutter analyze lib/features/qibla/presentation/pages/widgets/qibla_fallback_card.dart lib/features/qibla/presentation/pages/widgets/qibla_skeleton.dart
git add lib/features/qibla/presentation/pages/widgets/qibla_fallback_card.dart lib/features/qibla/presentation/pages/widgets/qibla_skeleton.dart
git commit -m "feat(qibla): add no-compass fallback card and loading skeleton"
```

---

## Task 13: QiblaPage (assembles states) + widget test

**Files:**
- Create: `lib/features/qibla/presentation/pages/qibla_page.dart`
- Test: `test/features/qibla/presentation/pages/qibla_page_test.dart`

- [ ] **Step 1: Implement the page**

Mirrors `home_view.dart`'s recovery handling for location failures.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/features/home/presentation/pages/widgets/location_recovery_card.dart';
import 'package:quran_app/features/qibla/presentation/cubit/qibla_cubit.dart';
import 'package:quran_app/features/qibla/presentation/pages/widgets/qibla_compass_dial.dart';
import 'package:quran_app/features/qibla/presentation/pages/widgets/qibla_degree_readout.dart';
import 'package:quran_app/features/qibla/presentation/pages/widgets/qibla_fallback_card.dart';
import 'package:quran_app/features/qibla/presentation/pages/widgets/qibla_meta_cards.dart';
import 'package:quran_app/features/qibla/presentation/pages/widgets/qibla_skeleton.dart';
import 'package:quran_app/features/qibla/presentation/pages/widgets/qibla_status_pill.dart';
import 'package:quran_app/generated/l10n.dart';

class QiblaPage extends StatelessWidget {
  const QiblaPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final s = S.of(context);
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        title: Column(
          children: [
            Text(s.qibla_app_bar_label,
                style: TS.regular12.copyWith(color: scheme.onSurfaceVariant)),
            Text(s.qibla_screen_title,
                style: TS.bold16.copyWith(color: scheme.onSurface)),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: s.qibla_recalibrate,
            icon: const HugeIcon(icon: HugeIcons.strokeRoundedRefresh, size: 20),
            onPressed: () => context.read<QiblaCubit>().recalibrate(),
          ),
        ],
      ),
      body: BlocBuilder<QiblaCubit, QiblaState>(
        builder: (context, state) {
          if (state is QiblaLoading || state is QiblaInitial) {
            return const QiblaSkeleton();
          }
          if (state is QiblaError) {
            return _buildError(context, state.failure);
          }
          if (state is QiblaLoaded) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
              child: Column(
                children: [
                  QiblaStatusPill(
                    isAligned: state.isAligned,
                    needsCalibration: state.needsCalibration,
                  ),
                  const SizedBox(height: 18),
                  QiblaCompassDial(
                    pointerAngle: state.hasCompass ? state.pointerAngle : null,
                    size: 280,
                  ),
                  const SizedBox(height: 18),
                  QiblaDegreeReadout(
                    bearing: state.direction.bearing,
                    rose: state.direction.rose,
                  ),
                  const SizedBox(height: 16),
                  if (!state.hasCompass) ...[
                    QiblaFallbackCard(bearing: state.direction.bearing),
                    const SizedBox(height: 16),
                  ],
                  QiblaMetaCards(
                    locationName: state.locationName,
                    distanceKm: state.direction.distanceKm,
                  ),
                ],
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildError(BuildContext context, Failure failure) {
    final s = S.of(context);
    if (failure is LocationPermissionDeniedFailure) {
      return LocationRecoveryCard(
        actionLabel: s.home_locationCard_enable,
        onAction: () async {
          await Geolocator.requestPermission();
          if (context.mounted) context.read<QiblaCubit>().recalibrate();
        },
      );
    }
    if (failure is LocationPermissionDeniedForeverFailure) {
      return LocationRecoveryCard(
        actionLabel: s.home_locationCard_openSettings,
        onAction: () => Geolocator.openAppSettings(),
      );
    }
    if (failure is LocationServiceDisabledFailure) {
      return LocationRecoveryCard(
        actionLabel: s.home_locationCard_openSettings,
        onAction: () => Geolocator.openLocationSettings(),
      );
    }
    return Center(child: Text(failure.message));
  }
}
```

> Verify `HugeIcons.strokeRoundedRefresh` exists; otherwise use `Icons.refresh`. Confirm `TS.regular12` exists or substitute the nearest small style.

- [ ] **Step 2: Widget test (state routing)**

`test/features/qibla/presentation/pages/qibla_page_test.dart`:

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/features/qibla/domain/entities/compass_rose.dart';
import 'package:quran_app/features/qibla/domain/entities/qibla_direction.dart';
import 'package:quran_app/features/qibla/presentation/cubit/qibla_cubit.dart';
import 'package:quran_app/features/qibla/presentation/pages/qibla_page.dart';
import 'package:quran_app/features/qibla/presentation/pages/widgets/qibla_skeleton.dart';
import 'package:quran_app/features/qibla/presentation/pages/widgets/qibla_fallback_card.dart';
import 'package:quran_app/generated/l10n.dart';

class _MockQiblaCubit extends MockCubit<QiblaState> implements QiblaCubit {}

void main() {
  late _MockQiblaCubit cubit;
  setUp(() => cubit = _MockQiblaCubit());

  Widget host() => MaterialApp(
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.delegate.supportedLocales,
        home: BlocProvider<QiblaCubit>.value(value: cubit, child: const QiblaPage()),
      );

  testWidgets('shows skeleton while loading', (tester) async {
    when(() => cubit.state).thenReturn(const QiblaLoading());
    await tester.pumpWidget(host());
    expect(find.byType(QiblaSkeleton), findsOneWidget);
  });

  testWidgets('shows fallback card when hasCompass is false', (tester) async {
    when(() => cubit.state).thenReturn(const QiblaLoaded(
      direction: QiblaDirection(bearing: 136, distanceKm: 1287, rose: CompassRose.se),
      locationName: 'Cairo',
      hasCompass: false,
    ));
    await tester.pumpWidget(host());
    await tester.pump();
    expect(find.byType(QiblaFallbackCard), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run the widget test**

Run: `flutter test test/features/qibla/presentation/pages/qibla_page_test.dart`
Expected: PASS. (If `S.delegate` setup differs, copy the localization-delegate setup from an existing widget test in `test/`.)

- [ ] **Step 4: Commit**

```bash
git add lib/features/qibla/presentation/pages/qibla_page.dart test/features/qibla/presentation/pages/qibla_page_test.dart
git commit -m "feat(qibla): add QiblaPage assembling all states (+ widget test)"
```

---

## Task 14: Route + quick-access tile

**Files:**
- Modify: `lib/config/router/app_router.dart`
- Modify: `lib/features/home/presentation/pages/widgets/quick_access_grid.dart`

- [ ] **Step 1: Add the route path constant**

In `app_router.dart`, alongside the other `static const String ...Path` lines:

```dart
  static const String qiblaPath = "/qibla";
```

- [ ] **Step 2: Add the GoRoute**

Add an import at the top:

```dart
import 'package:quran_app/features/qibla/presentation/cubit/qibla_cubit.dart';
import 'package:quran_app/features/qibla/presentation/pages/qibla_page.dart';
```

Add this `GoRoute` to the `routes:` list (after `bookmarksPath`):

```dart
      GoRoute(
        path: qiblaPath,
        pageBuilder: GoTransitions.fade.withScale.build(
          builder: (context, state) => BlocProvider(
            create: (_) => sl<QiblaCubit>()..start(),
            child: const QiblaPage(),
          ),
        ),
      ),
```

- [ ] **Step 3: Add the quick-access tile**

In `quick_access_grid.dart`, add to the `children:` list (after the Settings tile):

```dart
        _QuickTile(
          icon: HugeIcons.strokeRoundedCompass,
          label: S.of(context).qibla_screen_title,
          onTap: () => context.push(AppRouter.qiblaPath),
        ),
```

> Verify `HugeIcons.strokeRoundedCompass` exists (same icon chosen in Task 12); if you substituted there, use the same here. The 4-column grid wraps the 5th tile to a second row (confirmed acceptable).

- [ ] **Step 4: Analyze & commit**

```bash
flutter analyze lib/config/router/app_router.dart lib/features/home/presentation/pages/widgets/quick_access_grid.dart
git add lib/config/router/app_router.dart lib/features/home/presentation/pages/widgets/quick_access_grid.dart
git commit -m "feat(qibla): add /qibla route and home quick-access tile"
```

---

## Task 15: Full verification

**Files:** none (verification only)

- [ ] **Step 1: Analyze the whole project**

Run: `flutter analyze`
Expected: **No issues** (or only pre-existing warnings unrelated to `lib/features/qibla`).

- [ ] **Step 2: Run the full test suite**

Run: `flutter test`
Expected: all tests pass, including the new `test/features/qibla/**` suites.

- [ ] **Step 3: Manual smoke (device/emulator)** — optional but recommended

Launch the app, open Home → tap the **Qibla** quick-access tile. Confirm:
- Skeleton appears, then the dial + degree + meta cards.
- On a real device the needle rotates as you turn the phone; status pill turns green near alignment.
- Deny location → recovery card appears; granting + recalibrate recovers.

- [ ] **Step 4: Final commit (if any analyzer fixes were needed)**

```bash
git add -A
git commit -m "chore(qibla): final verification fixes"
```

---

## Self-Review notes (for the executor)

- **True vs magnetic north** is handled in `QiblaCalculator.toTrueHeading` + the cubit's `rawHeadingIsTrue` flag (iOS=true, Android=magnetic+declination). Do not "simplify" this away.
- **No-compass** is detected by BOTH a null heading and a 4s timeout — keep both paths.
- `GetQiblaDirection` returns `QiblaDirection` directly (no `Either`) — it is pure and cannot fail.
- All user-facing strings go through `S.of(context)`; regenerate l10n after ARB edits.
- If `flutter_compass`/icon/`TS` symbols differ from what's written, fix to the real symbol and keep going — the logic and tests are the contract, the exact icon/style names are not.
