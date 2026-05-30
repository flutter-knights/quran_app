# Qibla Finder — Design Spec

**Date:** 2026-05-30
**Status:** Approved (pending spec review)
**Feature module:** `lib/features/qibla/`

## 1. Summary

A Qibla finder reachable from the home **Quick Access** grid. It shows a live compass
needle pointing toward the Kaaba using the device magnetometer, plus the Qibla bearing in
degrees, the great-circle distance to Makkah, and the user's current location name.

When a device has **no usable magnetometer**, the screen degrades gracefully to a static
numeric bearing ("face 298° from North") with manual-alignment guidance — it does **not**
present an error. Location permission/service failures **do** surface as recoverable errors.

## 2. Key technical reality (why this design)

- The **magnetometer/compass** tells the phone which way it is pointing → enables a live
  rotating needle.
- **Location (GPS) is always required** regardless of compass: it is used to *compute* the
  Qibla bearing (a fixed great-circle angle from true north toward the Kaaba) and the
  distance.
- Therefore the real fork is **"live needle (has magnetometer)" vs "static numeric/guidance
  (no magnetometer)"** — not "gyro vs GPS". Location is reused in both branches.

## 3. Decisions (locked)

| Decision | Choice |
| --- | --- |
| Compass logic | `flutter_compass` for heading + our own bearing/distance math (full control, testable). |
| No-magnetometer fallback | Numeric bearing + manual-alignment guidance (no maps dependency). |
| Extra info shown | Bearing in degrees, distance to Kaaba, current location name, low-accuracy calibration hint. |
| UI source | The provided mockup (`Quran App (2).html`, screen 9 "Qibla Compass"), translated into the app's real widget/theming conventions. |

If `flutter_compass` fails to build on the current Flutter version, swap to a maintained
fork (e.g. `flutter_compass_v2`) — same surface, isolated behind `CompassDataSource`.

## 4. Architecture

New Clean Architecture feature module mirroring `home`. Layer boundaries per
`.claude/rules/architecture.md`. State via `Cubit`; DI via GetIt (`sl`); errors via
`Either<Failure, T>` (dartz).

### 4.1 Domain (`lib/features/qibla/domain/`)

- **Entities**
  - `QiblaDirection` — `double bearing` (degrees from **true north** toward Kaaba),
    `double distanceKm`. Pure value object.
  - `CompassReading` — `double? heading` (degrees), `double? accuracy`. `heading == null`
    ⇒ device has no usable magnetometer.
- **`QiblaCalculator`** (pure Dart, no I/O) — Kaaba at `21.4225°N, 39.8262°E`.
  - `bearing(lat, lon)` → great-circle initial bearing:
    `θ = atan2(sin Δλ · cos φ2, cos φ1 · sin φ2 − sin φ1 · cos φ2 · cos Δλ)`, then
    `(deg(θ) + 360) mod 360`.
  - `distanceKm(lat, lon)` → haversine, Earth radius 6371 km.
  - `compassRose(bearing)` → one of N/NE/E/SE/S/SW/W/NW (8-point) for the label.
- **Repository** `CompassRepository` (abstract):
  - `Stream<CompassReading> watchHeading()` — emits `CompassReading(heading: null)` when no sensor.
- **Use cases**
  - `GetQiblaDirection` (`UseCase<QiblaDirection, Location>`) — pure computation wrapper around
    `QiblaCalculator`; returns `Right(QiblaDirection)`.
  - `WatchCompassHeading` (`StreamUseCase<CompassReading, NoParams>`) → `CompassRepository.watchHeading()`.
  - **Location is reused** from the existing `home` feature via `GetCurrentLocationUseCase`
    (already a GetIt singleton). No duplication of geolocation.

### 4.2 Data (`lib/features/qibla/data/`)

- **`CompassDataSource`** — wraps `flutter_compass`:
  - `Stream<CompassReading> headingStream()` from `FlutterCompass.events`, mapping
    `CompassEvent.heading` (null when unavailable) and `.accuracy`.
- **`CompassRepositoryImpl`** implements `CompassRepository`, maps the data-source stream to
  `CompassReading`, swallows/streams gracefully (no sensor ⇒ a single `heading: null` reading).

### 4.3 Presentation (`lib/features/qibla/presentation/`)

- **`QiblaCubit` / `QiblaState`**
  - States: `QiblaInitial`, `QiblaLoading`, `QiblaLoaded`, `QiblaError(Failure)`.
  - `QiblaLoaded` fields: `double bearing`, `double distanceKm`, `String? locationName`,
    `double? heading`, `double? accuracy`, `bool hasCompass`, plus derived
    `double? pointerAngle` (`(bearing − heading)` normalized to `[0,360)`) and `bool isAligned`
    (`pointerAngle` within ±5° of 0/360).
  - Flow: subscribe to `GetCurrentLocationUseCase` → on `Right(location)` compute
    `GetQiblaDirection` → subscribe to `WatchCompassHeading`, merging heading into state.
    On `Left(failure)` → `QiblaError`.
  - `recalibrate()` re-triggers the location+heading subscriptions.
  - Cancels stream subscriptions in `close()`.
- **Widgets** (`presentation/pages/` + `pages/widgets/`)
  - `QiblaPage` — `BlocProvider(sl<QiblaCubit>())`, `BlocBuilder` switching on state.
  - `QiblaCompassDial` — `CustomPaint` dial (ticks every 6°, cardinal/30° lengths per mockup,
    N/E/S/W letters, center hub) + rotating needle (`AnimatedRotation`, wrap-safe) with Kaaba
    glyph + fading beam. Static dial, rotating needle (matches mockup).
  - `QiblaStatusPill` — "point toward the Kaaba" → green `aligned` when `isAligned`; becomes
    calibration hint when `accuracy` is low.
  - `QiblaDegreeReadout` — large bearing number (Arabic-Indic numerals in AR locale) + rose
    label.
  - `QiblaMetaCards` — two cards: location name, distance to Makkah.
  - `QiblaFallbackCard` — shown when `hasCompass == false`: static beam at bearing + "face X°
    from North manually" guidance.
  - `QiblaSkeleton` — `Skeletonizer` mirroring dial + readout + meta cards (per
    `.claude/rules/loading-states.md`).
  - Error state reuses the existing `location_recovery_card` pattern from `home`.
- **Localization util** — `presentation/utils/` for any enum/`.localized()` helpers (never in
  domain, per `.claude/rules/localization.md`).

### 4.4 DI (`lib/features/qibla/qibla_di.dart`)

`initQibla()` registers:
- `CompassDataSource` — lazy singleton.
- `CompassRepository` → `CompassRepositoryImpl` — lazy singleton.
- `GetQiblaDirection`, `WatchCompassHeading` — lazy singletons.
- `QiblaCubit` — **factory**.

Called from `core/di/dependency_injection.dart` after `initHome()` (depends on home's
`GetCurrentLocationUseCase`).

### 4.5 Routing & entry point

- `app_router.dart`: add `static const String qiblaPath = "/qibla";` and a `GoRoute` rendering
  `QiblaPage`.
- `quick_access_grid.dart`: add a **5th tile** (compass/navigation `HugeIcon`, label
  "القبلة / Qibla") → `context.push(AppRouter.qiblaPath)`. The `crossAxisCount: 4` grid wraps
  to a second row cleanly.

## 5. Dependencies

- Add `flutter_compass` (latest, or maintained fork) to `pubspec.yaml`.
- iOS true-north heading needs location usage description — already present for `geolocator`.
  Android magnetometer needs no extra manifest permission.

## 6. Error handling

| Condition | Behaviour |
| --- | --- |
| Location service disabled | `Left(LocationServiceDisabledFailure)` → recovery card. |
| Location permission denied / denied-forever | recovery card with settings affordance (existing pattern). |
| No magnetometer | **Not an error.** `hasCompass = false` → static numeric fallback. |
| Low sensor accuracy | status pill becomes calibration hint. |

## 7. Localization

New ar/en ARB keys (regenerate via `dart run intl_utils:generate`):
`qibla_screen_title`, `qibla_app_bar_label`, `qibla_point_to_kaaba`, `qibla_aligned`,
`qibla_bearing_label`, `qibla_to_makkah`, `qibla_your_location`,
`qibla_no_compass_message`, `qibla_align_manually`, `qibla_calibrate_hint`,
plus the 8 compass-rose names.

## 8. Testing (TDD)

- **`QiblaCalculator`** — known coordinates → known bearing/distance (e.g. Cairo→Makkah ≈
  136°; verify rose names; antipodal/edge cases). Pure, fast.
- **`GetQiblaDirection`** — returns `Right(QiblaDirection)` for a given `Location`.
- **`CompassRepositoryImpl`** — maps a fake heading stream to `CompassReading`; null-heading
  path when no sensor.
- **`QiblaCubit`** (`bloc_test`) — loading→loaded; location-denied→error;
  no-compass→`hasCompass=false`; heading updates recompute `pointerAngle`/`isAligned`.

## 9. Out of scope (YAGNI)

- Map-based Qibla view.
- AR camera overlay.
- Manual location override (reuses existing location pipeline only).
- Persisting/caching Qibla bearing (cheap to recompute from cached location).

## 10. File manifest

```
lib/features/qibla/
  domain/
    entities/qibla_direction.dart
    entities/compass_reading.dart
    utils/qibla_calculator.dart
    repositories/compass_repository.dart
    usecases/get_qibla_direction.dart
    usecases/watch_compass_heading.dart
  data/
    datasources/compass_data_source.dart
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
  data/repositories/compass_repository_impl_test.dart
  presentation/cubit/qibla_cubit_test.dart
```

Modified: `lib/config/router/app_router.dart`,
`lib/features/home/presentation/pages/widgets/quick_access_grid.dart`,
`lib/core/di/dependency_injection.dart`, `pubspec.yaml`, `lib/l10n/intl_*.arb`.
