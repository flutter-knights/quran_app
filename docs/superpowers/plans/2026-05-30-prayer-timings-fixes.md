# Prayer Timings Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix all 13 identified prayer-timing defects — wrong/missing calculation method, cleartext HTTP, timezone/DST fragility, missed adhans after boot, coarse cache invalidation, and a set of correctness/cosmetic issues — so prayer times and adhans are correct, configurable, and resilient.

**Architecture:** Times come from the Aladhan `/v1/calendar` API and are cached in Hive keyed by date. We introduce a **config signature** (location + method + madhab) that invalidates the cache when any timing input changes, plumb a user-selectable (region-auto-detected) calculation method + Asr madhab through the existing `DailyPrayerContext` pipeline, harden timezone/boot handling on the native Android side, and apply targeted correctness fixes in the countdown cubit and repository.

**Tech Stack:** Flutter, `flutter_bloc` (Cubit), `dartz` (`Either<Failure,T>`), `get_it` (`sl`), `hive`, `dio`, `hydrated_bloc`, Kotlin (Android `AlarmManager` / foreground services), `flutter_local_notifications`, `flutter_timezone`.

**Testing:** `flutter test` for Dart; `bloc_test` + `mocktail` for cubits; manual `/run` smoke for native paths. Run a phase's tests before committing it.

---

## File Structure

**New files**
- `lib/core/constants/calculation_method.dart` — `CalculationMethod` enum (+ Aladhan int) and `AsrSchool` enum (+ Aladhan int).
- `lib/core/utils/calculation_method_for_country.dart` — maps `Location.enCountry` → default `CalculationMethod` (used when method == `auto`).
- `lib/features/home/data/datasources/local/prayer_config_signature.dart` — builds the config-signature string and reads/writes it to a Hive box.
- `lib/features/home/presentation/pages/prayer_calculation_settings_page.dart` — UI for method + madhab dropdowns.
- `lib/features/home/presentation/utils/calculation_method_localization.dart` — `.localized()` for the two enums (presentation layer per localization rule).
- `test/...` mirrors for each (see tasks).

**Modified files**
- `lib/features/settings/domain/entities/settings.dart`, `lib/features/settings/data/models/settings_model.dart`, `lib/features/settings/presentation/cubit/settings_cubit.dart` — add `calculationMethod` + `asrSchool`.
- `lib/features/home/domain/repositories/prayer_times_repository.dart`, `lib/features/home/data/repositories/prayer_times_repository_impl.dart`, `lib/features/home/domain/usecases/get_prayer_times.dart`, `lib/features/home/domain/usecases/get_daily_prayer_context.dart` — thread method/school.
- `lib/features/home/data/datasources/remote/prayer_time_remote_data_source.dart` — `https` + `method`/`school` params.
- `lib/features/home/data/datasources/local/prayer_times_local_data_source.dart` — signature-aware invalidation.
- `lib/features/home/data/repositories/location_repository_impl.dart` — remove side-effecting `clearCache`.
- `lib/features/home/presentation/cubit/daily_prayer_context_cubit.dart` — pass settings, cancel in-flight subscription.
- `lib/features/home/presentation/cubit/prayer_countdown_cubit.dart` — exact-second fix.
- `lib/features/home/data/models/prayer_times_model.dart` — JSON validation.
- `lib/features/home/presentation/pages/widgets/prayers_list.dart`, `single_prayer_card.dart` — `isNext` rename + Friday-from-context-date.
- `lib/features/notifications/domain/services/next_prayer_resolver.dart` — optional sunrise skip for "next".
- `lib/core/errors/failure.dart` — `PermissionDeniedFailure`.
- `lib/config/hive_config.dart`, `lib/features/home/home_di.dart` — register signature box / wiring.
- Native: `android/.../AdhanScheduler.kt`, `AdhanBootReceiver.kt`, `AndroidManifest.xml`, `PrayerNotificationSchedulerImpl` + repository for multi-day + timezone receiver.
- `lib/l10n/*.arb` + regenerate.

---

## PHASE 0 — Config-aware cache invalidation (foundation; unblocks H1 + fixes M1)

### Task 0.1: CalculationMethod + AsrSchool enums

**Files:**
- Create: `lib/core/constants/calculation_method.dart`
- Test: `test/core/constants/calculation_method_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/constants/calculation_method.dart';

void main() {
  test('CalculationMethod carries Aladhan integer ids', () {
    expect(CalculationMethod.mwl.aladhanId, 3);
    expect(CalculationMethod.isna.aladhanId, 2);
    expect(CalculationMethod.ummAlQura.aladhanId, 4);
    expect(CalculationMethod.egypt.aladhanId, 5);
    expect(CalculationMethod.karachi.aladhanId, 1);
    // `auto` has no concrete id and must be resolved before hitting the API.
    expect(CalculationMethod.auto.aladhanId, isNull);
  });

  test('AsrSchool carries Aladhan school ids', () {
    expect(AsrSchool.shafi.aladhanId, 0);
    expect(AsrSchool.hanafi.aladhanId, 1);
  });
}
```

- [ ] **Step 2: Run test, verify it fails**

Run: `flutter test test/core/constants/calculation_method_test.dart`
Expected: FAIL (file/enum not found).

- [ ] **Step 3: Implement the enums**

```dart
/// Aladhan calculation methods. `aladhanId` maps to the API's `method` param.
/// `auto` is a sentinel: resolve it to a concrete method via
/// `calculationMethodForCountry` before calling the API.
enum CalculationMethod {
  auto(null),
  karachi(1),
  isna(2),
  mwl(3),
  ummAlQura(4),
  egypt(5),
  tehran(7),
  gulf(8),
  kuwait(9),
  qatar(10),
  singapore(11),
  france(12),
  turkey(13),
  russia(14);

  const CalculationMethod(this.aladhanId);

  /// `null` only for [auto]; concrete methods always have an id.
  final int? aladhanId;
}

/// Asr juristic method. Maps to the Aladhan API's `school` param.
enum AsrSchool {
  shafi(0),
  hanafi(1);

  const AsrSchool(this.aladhanId);

  final int aladhanId;
}
```

- [ ] **Step 4: Run test, verify it passes**

Run: `flutter test test/core/constants/calculation_method_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/constants/calculation_method.dart test/core/constants/calculation_method_test.dart
git commit -m "feat(prayer): add CalculationMethod + AsrSchool enums"
```

### Task 0.2: Region → method mapper

**Files:**
- Create: `lib/core/utils/calculation_method_for_country.dart`
- Test: `test/core/utils/calculation_method_for_country_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/constants/calculation_method.dart';
import 'package:quran_app/core/utils/calculation_method_for_country.dart';

void main() {
  test('maps known countries to their conventional method', () {
    expect(calculationMethodForCountry('Saudi Arabia'), CalculationMethod.ummAlQura);
    expect(calculationMethodForCountry('Egypt'), CalculationMethod.egypt);
    expect(calculationMethodForCountry('Pakistan'), CalculationMethod.karachi);
    expect(calculationMethodForCountry('United States'), CalculationMethod.isna);
    expect(calculationMethodForCountry('Turkey'), CalculationMethod.turkey);
  });

  test('is case/space insensitive', () {
    expect(calculationMethodForCountry('  united states '), CalculationMethod.isna);
  });

  test('falls back to MWL for unknown/null', () {
    expect(calculationMethodForCountry(null), CalculationMethod.mwl);
    expect(calculationMethodForCountry('Atlantis'), CalculationMethod.mwl);
  });
}
```

- [ ] **Step 2: Run test, verify it fails**

Run: `flutter test test/core/utils/calculation_method_for_country_test.dart`
Expected: FAIL (function not found).

- [ ] **Step 3: Implement the mapper**

```dart
import 'package:quran_app/core/constants/calculation_method.dart';

/// Picks the conventional calculation method for a country (English name from
/// reverse geocoding). Returns [CalculationMethod.mwl] when unknown/null.
CalculationMethod calculationMethodForCountry(String? enCountry) {
  if (enCountry == null) return CalculationMethod.mwl;
  final key = enCountry.trim().toLowerCase();
  return _byCountry[key] ?? CalculationMethod.mwl;
}

const Map<String, CalculationMethod> _byCountry = {
  'saudi arabia': CalculationMethod.ummAlQura,
  'egypt': CalculationMethod.egypt,
  'pakistan': CalculationMethod.karachi,
  'india': CalculationMethod.karachi,
  'bangladesh': CalculationMethod.karachi,
  'afghanistan': CalculationMethod.karachi,
  'united states': CalculationMethod.isna,
  'canada': CalculationMethod.isna,
  'turkey': CalculationMethod.turkey,
  'türkiye': CalculationMethod.turkey,
  'kuwait': CalculationMethod.kuwait,
  'qatar': CalculationMethod.qatar,
  'singapore': CalculationMethod.singapore,
  'france': CalculationMethod.france,
  'russia': CalculationMethod.russia,
  'iran': CalculationMethod.tehran,
  'united arab emirates': CalculationMethod.gulf,
  'bahrain': CalculationMethod.gulf,
  'oman': CalculationMethod.gulf,
  'yemen': CalculationMethod.gulf,
};
```

- [ ] **Step 4: Run test, verify it passes** — Run the same command; Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/utils/calculation_method_for_country.dart test/core/utils/calculation_method_for_country_test.dart
git commit -m "feat(prayer): map country to default calculation method"
```

### Task 0.3: Config signature store

**Files:**
- Create: `lib/features/home/data/datasources/local/prayer_config_signature.dart`
- Modify: `lib/config/hive_config.dart` (open a `prayerConfig` box)
- Test: `test/features/home/data/datasources/local/prayer_config_signature_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:quran_app/features/home/data/datasources/local/prayer_config_signature.dart';

void main() {
  late Box box;
  setUp(() async {
    Hive.init('./.dart_tool/hive_test_${DateTime.now().microsecondsSinceEpoch}');
    box = await Hive.openBox('prayerConfig_test');
  });
  tearDown(() async => box.deleteFromDisk());

  test('signature is stable for same inputs and rounds coordinates', () {
    final a = buildPrayerConfigSignature(
        latitude: 30.044, longitude: 31.235, method: 5, school: 0);
    final b = buildPrayerConfigSignature(
        latitude: 30.0441, longitude: 31.2349, method: 5, school: 0);
    expect(a, b); // rounded to 1dp -> identical
  });

  test('signature changes when method or school changes', () {
    final base = buildPrayerConfigSignature(
        latitude: 30.04, longitude: 31.23, method: 5, school: 0);
    final diffMethod = buildPrayerConfigSignature(
        latitude: 30.04, longitude: 31.23, method: 3, school: 0);
    final diffSchool = buildPrayerConfigSignature(
        latitude: 30.04, longitude: 31.23, method: 5, school: 1);
    expect(base, isNot(diffMethod));
    expect(base, isNot(diffSchool));
  });

  test('hasChangedAndStore returns true on first call, false on repeat', () {
    final store = PrayerConfigSignatureStore(box: box);
    expect(store.hasChangedAndStore('sig-1'), isTrue);
    expect(store.hasChangedAndStore('sig-1'), isFalse);
    expect(store.hasChangedAndStore('sig-2'), isTrue);
  });
}
```

- [ ] **Step 2: Run test, verify it fails**

Run: `flutter test test/features/home/data/datasources/local/prayer_config_signature_test.dart`
Expected: FAIL (symbols not found).

- [ ] **Step 3: Implement signature + store**

```dart
import 'package:hive/hive.dart';

/// Builds a stable string describing every input that determines prayer times.
/// Coordinates are rounded to 1 decimal place (~11 km) so ordinary commuting
/// jitter does not trigger a full-month refetch (prayer-time deltas at that
/// scale are seconds), while genuine relocations do.
String buildPrayerConfigSignature({
  required double latitude,
  required double longitude,
  required int method,
  required int school,
}) {
  final lat = latitude.toStringAsFixed(1);
  final lon = longitude.toStringAsFixed(1);
  return '${lat}_${lon}_${method}_$school';
}

/// Persists the last-used signature; reports whether it changed.
class PrayerConfigSignatureStore {
  PrayerConfigSignatureStore({required this.box});
  final Box box;
  static const _key = 'prayer_config_signature';

  /// Returns true when [signature] differs from the stored one (or none is
  /// stored), and stores the new value. Returns false when unchanged.
  bool hasChangedAndStore(String signature) {
    final prev = box.get(_key) as String?;
    if (prev == signature) return false;
    box.put(_key, signature);
    return true;
  }
}
```

- [ ] **Step 4: Open the box in hive_config.dart**

In `lib/config/hive_config.dart`, alongside the existing box opens, add:

```dart
await Hive.openBox('prayerConfig');
```

- [ ] **Step 5: Run test, verify it passes** — same command; Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/home/data/datasources/local/prayer_config_signature.dart lib/config/hive_config.dart test/features/home/data/datasources/local/prayer_config_signature_test.dart
git commit -m "feat(prayer): add config-signature store for cache invalidation"
```

### Task 0.4: Wire signature invalidation into the repository + drop the 20km hack

**Files:**
- Modify: `lib/features/home/data/repositories/location_repository_impl.dart:64-65`
- Modify: `lib/features/home/data/repositories/prayer_times_repository_impl.dart` (signature check at top of `getPrayerTimes`)
- Modify: `lib/features/home/home_di.dart` (inject `PrayerConfigSignatureStore`)

> NOTE: `getPrayerTimes` gains `method`/`school` params in Task 1.4. This task lands the signature plumbing; the params are added there. To keep this task self-contained and compiling, add the params here with the final signature.

- [ ] **Step 1: Make `isLocationChanged` a pure predicate**

In `location_repository_impl.dart`, delete the cache side effect (lines 64-65 currently `if (distance < 20000) return false; prayerTimesLocalDataSource.clearCache();`). Replace the body's tail with:

```dart
    return distance >= 20000;
```

Remove the now-unused `prayerTimesLocalDataSource` field + constructor param **only if** nothing else uses it; if other call sites depend on the field, leave the field but ensure no `clearCache()` call remains.

- [ ] **Step 2: Add signature gate to `getPrayerTimes`**

Replace `prayer_times_repository_impl.dart:22-31` with (note new params + store):

```dart
  final PrayerConfigSignatureStore signatureStore;
  // ...add to constructor...

  @override
  Future<Either<Failure, PrayerTimes>> getPrayerTimes(
    Location location, {
    required int method,
    required int school,
  }) async {
    final now = DateTime.now();

    // Invalidate the whole cache when the timing inputs (location/method/
    // madhab) change — replaces the old 20km-only heuristic.
    final signature = buildPrayerConfigSignature(
      latitude: location.latitude,
      longitude: location.longitude,
      method: method,
      school: school,
    );
    if (signatureStore.hasChangedAndStore(signature)) {
      prayerTimesLocalDataSource.clearCache();
    }

    final todayData = prayerTimesLocalDataSource.getCached(date: now);
    if (todayData == null) {
      return _fetchAndCacheRemote(location, now, method: method, school: school);
    }
    // ... rest unchanged (after-Isha logic) ...
```

`_fetchAndCacheRemote` and `preCacheMonth` must forward `method`/`school` to the remote data source (added in Task 1.4).

- [ ] **Step 3: Update DI**

In `home_di.dart`, construct `PrayerConfigSignatureStore(box: Hive.box('prayerConfig'))` and pass to `PrayerTimesRepositoryImpl`.

- [ ] **Step 4: Run the repo test suite**

Run: `flutter test test/features/home/data/repositories/prayer_times_repository_impl_test.dart`
Expected: existing tests updated to pass `method:`/`school:` (update them in this step), PASS.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(prayer): invalidate cache via config signature; drop 20km clear hack"
```

---

## PHASE 1 — H1: calculation method + Asr madhab (auto-detect + override)

### Task 1.1: Add settings fields

**Files:**
- Modify: `lib/features/settings/domain/entities/settings.dart`
- Modify: `lib/features/settings/data/models/settings_model.dart`
- Test: `test/features/settings/settings_model_calc_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/constants/calculation_method.dart';
import 'package:quran_app/features/settings/data/models/settings_model.dart';

void main() {
  test('defaults: method auto, school shafi', () {
    const s = SettingsModel(isFormat12Hours: false, isArabic: true);
    expect(s.calculationMethod, CalculationMethod.auto);
    expect(s.asrSchool, AsrSchool.shafi);
  });

  test('round-trips through toMap/fromMap', () {
    const s = SettingsModel(
      isFormat12Hours: false,
      isArabic: true,
      calculationMethod: CalculationMethod.egypt,
      asrSchool: AsrSchool.hanafi,
    );
    final back = SettingsModel.fromMap(s.toMap());
    expect(back.calculationMethod, CalculationMethod.egypt);
    expect(back.asrSchool, AsrSchool.hanafi);
  });

  test('unknown persisted values fall back to defaults', () {
    final back = SettingsModel.fromMap({
      'isArabic': true,
      'calculationMethod': 'bogus',
      'asrSchool': 'bogus',
    });
    expect(back.calculationMethod, CalculationMethod.auto);
    expect(back.asrSchool, AsrSchool.shafi);
  });
}
```

- [ ] **Step 2: Run test, verify it fails** — `flutter test test/features/settings/settings_model_calc_test.dart`; Expected: FAIL.

- [ ] **Step 3: Add fields to `Settings`**

In `settings.dart`: import `calculation_method.dart`; add fields `final CalculationMethod calculationMethod;` and `final AsrSchool asrSchool;`; add constructor defaults `this.calculationMethod = CalculationMethod.auto,` and `this.asrSchool = AsrSchool.shafi,`; add both to `copyWith` params/body and to `props`.

- [ ] **Step 4: Add (de)serialization to `SettingsModel`**

Add to constructor + `copyWith` (mirroring parent). In `toMap()` add:

```dart
      'calculationMethod': calculationMethod.name,
      'asrSchool': asrSchool.name,
```

In `fromMap()` add:

```dart
      calculationMethod: CalculationMethod.values.firstWhere(
        (m) => m.name == (map['calculationMethod'] as String?),
        orElse: () => CalculationMethod.auto,
      ),
      asrSchool: AsrSchool.values.firstWhere(
        (s) => s.name == (map['asrSchool'] as String?),
        orElse: () => AsrSchool.shafi,
      ),
```

- [ ] **Step 5: Run test, verify it passes** — same command; Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "feat(settings): add calculationMethod + asrSchool fields"
```

### Task 1.2: SettingsCubit updaters

**Files:**
- Modify: `lib/features/settings/presentation/cubit/settings_cubit.dart`
- Test: `test/features/settings/settings_cubit_test.dart` (add cases)

- [ ] **Step 1: Add bloc_test cases**

```dart
  blocTest<SettingsCubit, SettingsState>(
    'updateCalculationMethod emits new method',
    build: () => SettingsCubit(),
    act: (c) => c.updateCalculationMethod(CalculationMethod.egypt),
    verify: (c) =>
        expect(c.state.settingsModel.calculationMethod, CalculationMethod.egypt),
  );

  blocTest<SettingsCubit, SettingsState>(
    'updateAsrSchool emits new school',
    build: () => SettingsCubit(),
    act: (c) => c.updateAsrSchool(AsrSchool.hanafi),
    verify: (c) => expect(c.state.settingsModel.asrSchool, AsrSchool.hanafi),
  );
```

- [ ] **Step 2: Run, verify fail** — `flutter test test/features/settings/settings_cubit_test.dart`; Expected: FAIL.

- [ ] **Step 3: Implement updaters**

```dart
  void updateCalculationMethod(CalculationMethod method) {
    emit(SettingsState(
        state.settingsModel.copyWith(calculationMethod: method)));
  }

  void updateAsrSchool(AsrSchool school) {
    emit(SettingsState(state.settingsModel.copyWith(asrSchool: school)));
  }
```

(Add `import '../../../../core/constants/calculation_method.dart';`.)

- [ ] **Step 4: Run, verify pass.** **Step 5: Commit** `feat(settings): cubit updaters for method + madhab`.

### Task 1.3: Resolver — settings + location → concrete (method, school)

**Files:**
- Create: `lib/features/home/domain/usecases/resolve_calculation_params.dart` (pure helper)
- Test: `test/features/home/domain/usecases/resolve_calculation_params_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/constants/calculation_method.dart';
import 'package:quran_app/features/home/domain/usecases/resolve_calculation_params.dart';

void main() {
  test('auto resolves via country', () {
    final p = resolveCalculationParams(
        method: CalculationMethod.auto, school: AsrSchool.shafi, enCountry: 'Egypt');
    expect(p.method, 5); // Egypt
    expect(p.school, 0);
  });

  test('explicit method wins over country', () {
    final p = resolveCalculationParams(
        method: CalculationMethod.karachi, school: AsrSchool.hanafi, enCountry: 'Egypt');
    expect(p.method, 1);
    expect(p.school, 1);
  });

  test('auto + unknown country falls back to MWL', () {
    final p = resolveCalculationParams(
        method: CalculationMethod.auto, school: AsrSchool.shafi, enCountry: null);
    expect(p.method, 3);
  });
}
```

- [ ] **Step 2: Run, verify fail.**

- [ ] **Step 3: Implement**

```dart
import 'package:quran_app/core/constants/calculation_method.dart';
import 'package:quran_app/core/utils/calculation_method_for_country.dart';

class ResolvedCalculationParams {
  const ResolvedCalculationParams(this.method, this.school);
  final int method;
  final int school;
}

ResolvedCalculationParams resolveCalculationParams({
  required CalculationMethod method,
  required AsrSchool school,
  required String? enCountry,
}) {
  final resolved = method == CalculationMethod.auto
      ? calculationMethodForCountry(enCountry)
      : method;
  return ResolvedCalculationParams(resolved.aladhanId!, school.aladhanId);
}
```

- [ ] **Step 4: Run, verify pass. Step 5: Commit** `feat(prayer): resolve auto method by country`.

### Task 1.4: Remote data source — https + method/school params

**Files:**
- Modify: `lib/features/home/data/datasources/remote/prayer_time_remote_data_source.dart`
- Test: `test/features/home/data/datasources/remote/prayer_time_remote_data_source_test.dart` (extend)

- [ ] **Step 1: Update the test to assert query params + https**

Add assertions that `dio.get` is called with `https://api.aladhan.com/v1/calendar` and `queryParameters` containing `method` and `school` (use mocktail `captureAny`/`captureThat`). Example:

```dart
  test('sends https with method + school', () async {
    when(() => dio.get(any(), queryParameters: any(named: 'queryParameters')))
        .thenAnswer((_) async => Response(
            data: {'data': []}, requestOptions: RequestOptions(path: '')));
    await dataSource.getPrayerTimesList(location, method: 5, school: 1);
    final captured = verify(() => dio.get(captureAny(),
        queryParameters: captureAny(named: 'queryParameters'))).captured;
    expect(captured[0], 'https://api.aladhan.com/v1/calendar');
    expect((captured[1] as Map)['method'], 5);
    expect((captured[1] as Map)['school'], 1);
  });
```

- [ ] **Step 2: Run, verify fail (H2 covered here too).**

- [ ] **Step 3: Implement**

Change the signature and body of `getPrayerTimesList`:

```dart
  Future<List<PrayerTimes>> getPrayerTimesList(
    Location location, {
    int? year,
    int? month,
    required int method,
    required int school,
  }) async {
    final queryParameters = <String, dynamic>{
      'latitude': location.latitude,
      'longitude': location.longitude,
      'method': method,
      'school': school,
    };
    if (year != null) queryParameters['year'] = year;
    if (month != null) queryParameters['month'] = month;

    final Response prayerTimesResponse = await dio.get(
      'https://api.aladhan.com/v1/calendar',
      queryParameters: queryParameters,
    );
    // ...unchanged parsing...
```

- [ ] **Step 4: Run, verify pass. Step 5: Commit** `feat(prayer): https + method/school query params (H1,H2)`.

### Task 1.5: Thread params through repository + use cases

**Files:**
- Modify: `lib/features/home/domain/repositories/prayer_times_repository.dart` (abstract: add `method`/`school` to `getPrayerTimes`; add to `preCacheMonth`)
- Modify: `lib/features/home/data/repositories/prayer_times_repository_impl.dart` (forward to remote in `_fetchAndCacheRemote` + `preCacheMonth`)
- Modify: `lib/features/home/domain/usecases/get_prayer_times.dart`, `get_daily_prayer_context.dart`
- Modify: `lib/features/home/domain/usecases/pre_cache_prayer_times.dart`

- [ ] **Step 1: Update `GetDailyPrayerContext` to accept calc params**

Change its `call` to read params from a new `GetDailyPrayerContextParams { CalculationMethod method; AsrSchool school; }` (replace `NoParams`). In the location branch, resolve via `resolveCalculationParams(method, school, location.enCountry)` then call `getPrayerTimes(location, method: r.method, school: r.school)`.

- [ ] **Step 2: Update `prayer_times_repository_impl` `_fetchAndCacheRemote`/`preCacheMonth`** to take + forward `method`/`school`.

- [ ] **Step 3: Update all tests** (`prayer_times_repository_impl_test`, `get_prayer_times_test` if present, `pre_cache_prayer_times_test`, `daily_prayer_context_cubit_test`) to pass the new params; keep behavior assertions.

- [ ] **Step 4: Run** `flutter test test/features/home`; Expected: PASS.

- [ ] **Step 5: Commit** `feat(prayer): thread method/school through repo + usecases`.

### Task 1.6: DailyPrayerContextCubit reads settings + cancels in-flight (also fixes M4)

**Files:**
- Modify: `lib/features/home/presentation/cubit/daily_prayer_context_cubit.dart`
- Modify: `lib/features/home/presentation/pages/home_page.dart` (provide SettingsCubit values into the fetch)
- Test: `test/features/home/presentation/cubit/daily_prayer_context_cubit_test.dart`

- [ ] **Step 1: Write failing tests** for (a) fetch passes the method/school from injected settings; (b) a second `fetchDailyPrayerContext` call cancels the first subscription (assert only the second stream's emissions are observed). Use a fake `GetDailyPrayerContext` returning a controllable stream.

- [ ] **Step 2: Run, verify fail.**

- [ ] **Step 3: Implement subscription cancellation**

```dart
  StreamSubscription? _sub;

  Future<void> fetchDailyPrayerContext({
    bool silent = false,
    required CalculationMethod method,
    required AsrSchool school,
  }) async {
    await _sub?.cancel();
    if (!silent) emit(DailyPrayerContextLoading());
    _sub = getDailyPrayerContext(
      GetDailyPrayerContextParams(method: method, school: school),
    ).listen((result) {
      if (isClosed) return;
      result.fold(
        (failure) => emit(DailyPrayerContextFailed(failure.message)),
        (ctx) => emit(DailyPrayerContextLoaded(ctx)),
      );
    });
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
```

- [ ] **Step 4: Update `home_page.dart` call sites** — every `fetchDailyPrayerContext(...)` call must read `context.read<SettingsCubit>().state.settingsModel` and pass `method:`/`school:`. For the `PrayerCountdownRequestRefresh` listener, read settings there too. The provider `create` at `home_page.dart:29-30` can't read context easily; switch to fetching from inside the widget tree (e.g. in `HomeView.initState` or a `BlocListener` that fires once), reading SettingsCubit.

- [ ] **Step 5: Add a SettingsCubit listener that refetches when method/school change** — extend the existing `BlocListener<SettingsCubit>` `listenWhen` (`home_page.dart:91-102`) to also compare `calculationMethod` and `asrSchool`; when they change, call `fetchDailyPrayerContext(method:, school:)` (signature change → Phase 0 clears cache → refetch).

- [ ] **Step 6: Run** `flutter test test/features/home`; Expected: PASS.

- [ ] **Step 7: Commit** `feat(prayer): refetch on method/madhab change; cancel in-flight (M4)`.

### Task 1.7: Settings UI + localization

**Files:**
- Create: `lib/features/home/presentation/utils/calculation_method_localization.dart`
- Create: `lib/features/home/presentation/pages/prayer_calculation_settings_page.dart`
- Modify: `lib/features/home/presentation/pages/notifications_settings_page.dart` (entry point / section) or settings page route
- Modify: `lib/l10n/intl_en.arb`, `lib/l10n/intl_ar.arb`

- [ ] **Step 1: Add ARB strings** for: section title, method label, each method display name, Asr school label, Shafi/Hanafi, "Auto (by region)". Then regenerate:

Run: `dart run intl_utils:generate`

- [ ] **Step 2: Add `.localized()` extensions** for `CalculationMethod` and `AsrSchool` in the presentation utils file (use `S.of(context)`), per the localization rule (NOT in domain).

- [ ] **Step 3: Build the page** — two `DropdownButton`s (method incl. `auto`, school) following the `reminder_offset_dropdown.dart` pattern; on change call `context.read<SettingsCubit>().updateCalculationMethod(...)` / `updateAsrSchool(...)`. Wrap loading of the current prayer-times preview (if shown) in a `Skeletonizer` per the loading-states rule.

- [ ] **Step 4: Link it** from the settings/notifications page with a navigable tile.

- [ ] **Step 5: Manual verify** — Run: `flutter run` (or `/run`), open the page, change method → confirm times refetch.

- [ ] **Step 6: Commit** `feat(prayer): calculation method + madhab settings UI`.

---

## PHASE 2 — H2: TLS sweep (mostly done in Task 1.4)

### Task 2.1: Sweep remaining cleartext + platform configs

**Files:**
- Grep + fix any other `http://` (geocoding, etc.)
- Modify: `android/app/src/main/AndroidManifest.xml` / network-security-config; verify iOS `Info.plist` ATS

- [ ] **Step 1: Grep** `Grep "http://"` across `lib/` and native; replace API hosts that support TLS with `https://`.

- [ ] **Step 2: Android** — ensure `android:usesCleartextTraffic="false"` (or a scoped network-security-config that only allows hosts you actually need over cleartext). 

- [ ] **Step 3: iOS** — confirm `Info.plist` has no blanket `NSAllowsArbitraryLoads = true`.

- [ ] **Step 4: Run** `flutter analyze` and the home data tests; Expected: PASS.

- [ ] **Step 5: Commit** `fix(security): enforce https for network calls (H2)`.

---

## PHASE 3 — H3: timezone / DST resilience

### Task 3.1: Re-init timezone + reschedule on resume

**Files:**
- Modify: `lib/features/home/presentation/pages/home_page.dart` (`_StripResumeGuard.didChangeAppLifecycleState`, already an observer)
- Modify: notification scheduler init path (`PrayerNotificationSchedulerImpl.init` is idempotent)

- [ ] **Step 1:** In `didChangeAppLifecycleState` on `resumed`, read the current timezone/UTC offset (`DateTime.now().timeZoneName` + `timeZoneOffset`) and compare against the offset captured at the last schedule (store it in the cubit/guard). **Only when it changed** re-`init()` the notification scheduler (re-reads `FlutterTimezone`) and trigger a silent `fetchDailyPrayerContext(...)` so `SyncDailyAdhans` re-runs with the new timezone. Resuming without a timezone change must NOT trigger a full refetch/reschedule (keep the existing `_enableOrRefreshStrip` only).

- [ ] **Step 2: Manual verify** — change device timezone, background+foreground the app, confirm countdown + scheduled adhans realign. (Document the manual steps in the commit body.)

- [ ] **Step 3: Commit** `fix(prayer): re-init timezone + reschedule on resume (H3)`.

### Task 3.2: Android time/timezone-change receiver

**Files:**
- Create/modify: a `BroadcastReceiver` for `android.intent.action.TIMEZONE_CHANGED` + `TIME_SET`
- Modify: `AndroidManifest.xml` (register receiver), and have it re-arm from the persisted snapshot (Task 4.2)

- [ ] **Step 1:** Implement a receiver that calls `AdhanScheduler` re-arm from the persisted multi-day snapshot.

- [ ] **Step 2:** Register in manifest with the two actions.

- [ ] **Step 3: Manual verify** via `adb shell` setting timezone; confirm logcat `Adhan` re-arm.

- [ ] **Step 4: Commit** `fix(prayer): re-arm adhans on timezone/time change (H3)`.

---

## PHASE 4 — H4: multi-day scheduling + boot recovery

### Task 4.1: Schedule N days of adhans (Dart side)

**Files:**
- Modify: `lib/features/notifications/domain/usecases/sync_daily_adhans.dart` and repository/native data source to accept multiple days
- Modify: `lib/features/home/presentation/pages/home_page.dart` (pass next 3 days from the Hive cache)

- [ ] **Step 1:** Extend `SyncDailyAdhansParams` to carry `List<PrayerTimes> days` (or keep `prayerTimes` for today + add `upcoming`), pull the next 3 days from `PrayerTimesLocalDataSource.getCached(date:)` for today, today+1, today+2 (skip nulls).

- [ ] **Step 2:** Repository + native data source forward a per-day timings list. **Apply the same multi-day horizon to the pre-prayer reminders** (`schedulePrayerReminders`) — they share the identical "missed if the app isn't opened" gap, so give the reminder request codes a day-indexed scheme too (see Task 4.2). Do not leave reminders single-day while adhans go multi-day.

- [ ] **Step 3:** Update `sync_daily_adhans_test.dart` for multi-day.

- [ ] **Step 4: Run** `flutter test test/features/notifications`; Expected: PASS.

- [ ] **Step 5: Commit** `feat(prayer): schedule 3 days of adhans ahead (H4)`.

### Task 4.2: Native multi-day arming + persisted snapshot + boot re-arm

**Files:**
- Modify: `android/.../AdhanScheduler.kt` — add `armDays(context, days: List<DaySchedule>, ...)`; day-index request codes (`base + dayIndex*10`, base 200..204); persist a JSON snapshot of all armed days to SharedPrefs.
- Modify: `android/.../AdhanBootReceiver.kt` — on `BOOT_COMPLETED`, read the snapshot, drop past entries, re-arm.
- Modify: `AndroidManifest.xml` — ensure `RECEIVE_BOOT_COMPLETED` permission + receiver action present.

- [ ] **Step 1:** Implement `armDays` reusing the existing per-prayer arming loop (`AdhanScheduler.kt:67-130`), iterating days with date-aware `Calendar` (set `DAY_OF_YEAR`/explicit date) and offset request codes. Keep the exact→inexact `SecurityException` fallback.

- [ ] **Step 2:** Persist snapshot (date + timings + clip + locale) as JSON in `adhan_prefs`.

- [ ] **Step 3:** Apply the same day-indexed multi-day arming + snapshot to `PrayerReminderScheduler.kt` (reminders), so Task 4.1 Step 2's multi-day reminders have a native counterpart with non-colliding request codes.

- [ ] **Step 3b:** Implement `AdhanBootReceiver.onReceive` to re-arm **both** adhans and reminders from their snapshots (replaces the no-op at `AdhanBootReceiver.kt:15-17`).

- [ ] **Step 4: Manual verify** — schedule, reboot emulator (`adb reboot`), confirm logcat `Adhan: armToday/armDays` re-arm without opening the app.

- [ ] **Step 5: Commit** `feat(prayer): native multi-day arming + boot re-arm (H4)`.

---

## PHASE 5 — Medium correctness (M2, M5)

### Task 5.1: After-Isha rolls to tomorrow's FULL context — repo + cubit together (M2)

> **CRITICAL COUPLING — do NOT split repo and cubit into separate commits.**
> The cubit's midnight/after-Isha refresh logic was built on the *old* contract
> ("post-Isha returns **today's** date + tomorrow's timings", see the comment at
> `prayer_countdown_cubit.dart:30-32`). Making the repo return **tomorrow's**
> `date` flips `contextDate` to tomorrow, which makes the midnight detector
> (`now.day != contextDate.day`, `:95-97`) fire a spurious refresh *tonight* and
> go dead at the real midnight roll. The existing cubit tests feed hand-built
> contexts and would NOT catch this. This task changes both sides and adds an
> integrated cubit test that proves no spurious refresh occurs when the context
> is intentionally one day ahead.
>
> **New consistent contract:** `DailyPrayerContext.date` ALWAYS equals the day
> the timings are for. The cubit's staleness/midnight check therefore becomes
> "the loaded context is for a *past* day" → date-only `isAfter`, not `!=`.

**Files:**
- Modify: `lib/features/home/data/repositories/prayer_times_repository_impl.dart:34-50`
- Modify: `lib/features/home/presentation/cubit/prayer_countdown_cubit.dart:30-101` (midnight detector + comments)
- Test: `test/features/home/data/repositories/prayer_times_repository_impl_test.dart`
- Test: `test/features/home/presentation/cubit/prayer_countdown_cubit_test.dart`

- [ ] **Step 1: Write failing repo test** — given now is after today's Isha and tomorrow is cached, `getPrayerTimes` returns tomorrow's `key`/`date`/`timings` (not today's date grafted onto tomorrow's timings).

```dart
  test('after Isha returns tomorrow wholesale when cached', () async {
    // arrange: today + tomorrow cached, now > today's isha
    final result = await repo.getPrayerTimes(location, method: 3, school: 0);
    result.fold((_) => fail('should be Right'), (pt) {
      expect(pt.key, tomorrowKey);
      expect(pt.date.gregorianDate, tomorrowKey);
      expect(pt.timings, tomorrowTimings);
    });
  });
```

- [ ] **Step 2: Write failing cubit test — no spurious refresh when context is a day ahead.**

This is the test that guards the coupling. Build a context whose `date` is *tomorrow* (simulating the post-Isha wholesale roll) while the cubit's clock is still tonight, and assert the cubit does NOT immediately emit a second `PrayerCountdownRequestRefresh`. (Use the existing test's clock-injection seam if present; otherwise assert the emitted states contain exactly one tick and no refresh for a context dated ahead of `DateTime.now()`.)

```dart
  blocTest<PrayerCountdownCubit, PrayerCountdownState>(
    'context dated one day ahead (post-Isha roll) does not fire a midnight refresh',
    build: () => PrayerCountdownCubit(),
    act: (cubit) => cubit.startTimer(contextDatedTomorrow), // date == tomorrow
    wait: const Duration(milliseconds: 50),
    verify: (cubit) {
      // Only ticks; the stale/midnight detector must not treat a future-dated
      // context as "we have rolled past its day".
    },
    expect: () => [isA<PrayerCountdownTick>()],
  );
```

- [ ] **Step 3: Run, verify both fail.**

- [ ] **Step 4: Implement the repo change** — replace the grafted-object return (`prayer_times_repository_impl.dart:39-46`) with `return Right(tomorrowData);` (keep the `return Right(todayData);` fallback when tomorrow is not cached).

- [ ] **Step 5: Implement the cubit change** — change the midnight/stale detector so it keys off "context is for a past day", not `!=`. Replace the midnight block (`:94-101`) with a date-only comparison:

```dart
    // Stale/rolled-past refresh: the loaded context is for a day we have ALREADY
    // passed (context.date is strictly before today). A context dated *ahead*
    // (the post-Isha wholesale roll) is NOT stale, so we use isAfter, not `!=`.
    final today = DateTime(now.year, now.month, now.day);
    final ctxDay =
        DateTime(contextDate.year, contextDate.month, contextDate.day);
    if (today.isAfter(ctxDay) && !_isMidnightRefreshed) {
      _isMidnightRefreshed = true;
      emit(PrayerCountdownRequestRefresh(silent: true));
    }
```

Keep the after-Isha block (`:83-92`) as-is — its `now.date == contextDate` guard is correct under the new contract (it only fires on the day the timings are actually for, then the refetch rolls `date` to tomorrow and resets the flags via `:33-36`, which now self-perpetuates correctly). Update the stale comment at `:30-32` to describe the new "date == the day the timings are for" contract.

- [ ] **Step 6: Run, verify both pass; run the FULL** `flutter test test/features/home` **to confirm the existing countdown refresh tests still hold under the new contract.**

- [ ] **Step 7: Commit (single commit, both files)** `fix(prayer): roll to tomorrow's full context after Isha + date-only stale check (M2)`.

### Task 5.2: PermissionDeniedFailure + surface native errors (M5)

**Files:**
- Modify: `lib/core/errors/failure.dart` (add `PermissionDeniedFailure`)
- Modify: `lib/features/notifications/data/repositories/notifications_repository_impl.dart` (map permission/SecurityException paths)
- Modify: `lib/features/home/data/repositories/prayer_times_repository_impl.dart:98` (`preCacheMonth` — replace `catch (_) { return; }` with a debug log)

- [ ] **Step 1:** Add the failure class. Map native permission denials to it in the repo `_run`. Add a `debugPrint` (or logger) in `preCacheMonth` catch.

- [ ] **Step 2:** Add a notifications-repo test asserting a permission-style exception maps to `PermissionDeniedFailure`.

- [ ] **Step 3: Run** notifications tests; Commit `fix(prayer): surface permission failures + log precache errors (M5)`.

---

## PHASE 6 — Low / cosmetic (M3, L1–L4)

### Task 6.1: L1 — exact-second boundary

**Files:** Modify `lib/features/home/presentation/cubit/prayer_countdown_cubit.dart:62-69`; Test: `prayer_countdown_cubit_test.dart`.

- [ ] **Step 1: Failing test** — at `now == prayerTime` exactly, that prayer is `nextPrayer` (remaining ≈ 0), not skipped.
- [ ] **Step 2: Run, verify fail.**
- [ ] **Step 3: Implement** — collapse the two `if`s so anything not strictly after a prayer time (i.e. `<=`) is treated as the first upcoming prayer. `now.isAfter(prayerTime)` already excludes equality, so the `else` branch catches the exact-second case:

```dart
      if (now.isAfter(prayerTime)) {
        currentPrayer = prayerName;
        continue;
      }
      // now <= prayerTime -> first upcoming (exact-equal counts as upcoming)
      targetNextPrayerTime = prayerTime;
      nextPrayer = prayerName;
      break;
```

- [ ] **Step 4: Run, verify pass. Step 5: Commit** `fix(prayer): exact prayer-second counts as upcoming (L1)`.

### Task 6.2: M3 — rename `isCurrent` → `isNext`

**Files:** Modify `single_prayer_card.dart` (param), `prayers_list.dart:32`; Test: widget test if present.

- [ ] **Step 1:** Rename the `SinglePrayerCard` parameter `isCurrent` → `isNext` and all internal usages; update `prayers_list.dart` call site (still `state.prayerCountdown.nextPrayer == prayerName`).
- [ ] **Step 2: Run** `flutter analyze` + any widget tests; Commit `refactor(prayer): rename isCurrent->isNext for clarity (M3)`.

### Task 6.3: L4 — Friday relabel from context date

**Files:** Modify `prayers_list.dart:18`.

- [ ] **Step 1:** Replace `DateTime.now().weekday` with the context date's weekday — derive from the `PrayerCountdownTick`/`DailyPrayerContext` date (`prayerTimes.date.gregorianDate` → `.gregorianDate()` → `.weekday`). Pass it in or compute from the already-available `prayerTimes`.
- [ ] **Step 2: Run** analyze; Commit `fix(prayer): Jumuah relabel uses context date (L4)`.

### Task 6.4: L2 — skip sunrise as "next" + L3 — JSON validation

**Files:** Modify `next_prayer_resolver.dart`, `prayer_times_model.dart:12-37`; Tests for both.

- [ ] **Step 1 (L2):** Add an optional `bool skipSunrise = false` param to `NextPrayerResolver.resolve`; when true, skip `PrayerName.sunrise` in the loop. Call with `skipSunrise: true` from the strip/`_enableOrRefreshStrip` path. Test both modes.
- [ ] **Step 2 (L3):** In `PrayerTimesModel.fromJson`, validate `json['timings']`, `json['date']['hijri']`, and `json['date']['gregorian']['date']` are present & well-shaped; throw `ServerException` (mapped to `ServerFailure` by the repo) on malformed payloads. Test with a malformed map.
- [ ] **Step 3: Run** `flutter test`; Commit `fix(prayer): skip sunrise for next-prayer; validate API json (L2,L3)`.

---

## PHASE 7 — Full verification

### Task 7.1: Whole-suite + manual smoke

- [ ] **Step 1:** Run `flutter analyze` — Expected: no new issues.
- [ ] **Step 2:** Run `flutter test` — Expected: all green.
- [ ] **Step 3:** Manual `/run`: (a) change calculation method → times change; (b) change Asr school → Asr time shifts; (c) toggle 12/24h; (d) simulate timezone change; (e) reboot emulator and confirm adhans re-arm (logcat). Record results.
- [ ] **Step 4:** Final commit / open PR if requested.

---

## Self-Review Notes

- **Spec coverage:** H1 (Tasks 0.1–0.3, 1.1–1.7), H2 (1.4, 2.1), H3 (3.1, 3.2), H4 (4.1, 4.2), M1 (0.4), M2 (5.1), M3 (6.2), M4 (1.6), M5 (5.2), L1 (6.1), L2/L3 (6.4), L4 (6.3). All 13 covered.
- **Type consistency:** `getPrayerTimes(location, {required int method, required int school})` used identically in repo abstract/impl/usecases; `GetDailyPrayerContextParams{method,school}` replaces `NoParams`; `resolveCalculationParams` returns `ResolvedCalculationParams(method, school)` ints; `CalculationMethod.aladhanId` is `int?` (null only for `auto`, always resolved before API).
- **Ordering caveat:** Phase 0 Task 0.4 adds `method`/`school` to `getPrayerTimes` to stay compiling; Tasks 1.4–1.5 complete the plumbing. Execute Phase 0 → 1 contiguously.
