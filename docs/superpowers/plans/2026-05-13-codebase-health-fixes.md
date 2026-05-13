# Codebase Health Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Resolve all 154 findings from `docs/reviews/2026-05-13-health-check.md` — 13 criticals, 56 warnings, 85 suggestions — and lift the codebase from grade F to A.

**Architecture:** Phased, dependency-ordered refactor. Each phase produces a working, testable build on its own; you can stop at any phase boundary and the app still runs. Phases proceed in this order because earlier ones unblock later ones (e.g., moving enums to domain unblocks Settings cleanup; Settings cleanup unblocks the settings widget edits).

**Tech Stack:** Flutter 3.x, `flutter_bloc` (Cubit), `get_it` (DI, alias `sl`), `dartz` (`Either<Failure, T>`), `equatable`, `hive` + `hydrated_bloc`, `dio`, `go_router`, `flutter_test`, `bloc_test`.

**Conventions used in this plan:**
- Every file path is repo-relative. The working directory is `C:\Savior\flutter_projects\quran_app`.
- Each finding is referenced by its ID from the health-check report (e.g., `A1-001`).
- For pure mechanical refactors (file moves, renames, adding `if (isClosed) return;`), the verification step is `flutter analyze` + a manual smoke run. For behavior-changing refactors (`Either<Failure, T>` migration, `Equatable` props fix), tests come first per TDD.
- Default commit message style follows the repo's existing pattern: `<type>: <short imperative>` (`feat:`, `fix:`, `refactor:`, `chore:`).
- `flutter pub add --dev bloc_test` will be done in Phase 0 — it isn't installed yet.

---

## Phase 0: Baseline & Test Scaffolding

Verify the repo builds cleanly today, install `bloc_test`, and set up a tests directory tree that mirrors `lib/` so subsequent phases have somewhere to add tests.

### Task 0.1: Verify baseline build

**Files:** none modified

- [ ] **Step 1: Confirm working tree is clean enough to start**

Run: `git status`
Expected: working tree is at the start of the branch `feature/001-surah-list`. If there are uncommitted edits, stash or commit them before starting the plan.

- [ ] **Step 2: Run analyzer to capture pre-existing analyzer noise**

Run: `flutter analyze`
Expected: completes (may emit lints/info). Save the output count as the baseline — the plan should never introduce new analyzer issues.

- [ ] **Step 3: Run existing tests to confirm the framework works**

Run: `flutter test`
Expected: PASS (only `test/widget_test.dart` exists today and likely passes trivially).

- [ ] **Step 4: Commit a checkpoint tag (no code change)**

```bash
git tag baseline/health-check-2026-05-13
```

### Task 0.2: Install `bloc_test`

**Files:** Modify `pubspec.yaml`

- [ ] **Step 1: Add `bloc_test` to dev_dependencies**

Run: `flutter pub add --dev bloc_test`

- [ ] **Step 2: Verify install**

Run: `flutter pub get`
Expected: `bloc_test: ^9.x.x` appears under `dev_dependencies` in `pubspec.yaml`.

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: add bloc_test for cubit unit tests"
```

### Task 0.3: Create test directory skeleton

**Files:**
- Create: `test/features/ahadith/presentation/cubit/.gitkeep`
- Create: `test/features/surah/presentation/cubit/.gitkeep`
- Create: `test/features/quran_playback/presentation/cubit/.gitkeep`
- Create: `test/features/home/presentation/cubit/.gitkeep`
- Create: `test/features/settings/presentation/cubit/.gitkeep`

- [ ] **Step 1: Create empty placeholder files so the dirs exist**

```bash
mkdir -p test/features/ahadith/presentation/cubit
mkdir -p test/features/surah/presentation/cubit
mkdir -p test/features/quran_playback/presentation/cubit
mkdir -p test/features/home/presentation/cubit
mkdir -p test/features/settings/presentation/cubit
```

- [ ] **Step 2: Commit (no `.gitkeep` files needed since later tasks will populate the dirs)**

No commit yet — wait for first test in Phase 2.

---

## Phase 1: Layer-Violation Cleanup (resolves 10 of 13 criticals)

Three independent root causes account for 10 of the 13 critical findings:
1. `Reciter` + `RepeatMode` enums living in `data/` (resolves A1-001, A1-002, A1-009, A1-028, A1-029, A4-016, A4-017).
2. `SettingsCubit`/`SettingsState`/`setting_switch.dart` importing `SettingsModel` from `data/` (resolves A1-006, A1-007, A1-008).
3. Domain entities transitively importing Flutter via `prayers_list_constants.dart` (resolves A1-003, A1-004).

### Task 1.1: Move `Reciter` enum to `domain/entities/` (drop `arabicName`)

**Finding IDs:** A1-001, A1-002, A1-009 (partial), A1-028, A4-016, A4-037

**Files:**
- Create: `lib/features/quran_playback/domain/entities/reciter.dart`
- Delete (after migration): `lib/features/quran_playback/data/repositories/helper/reciter.dart`
- Modify: `lib/features/quran_playback/domain/repositories/quran_playback_repo.dart`
- Modify: `lib/features/quran_playback/domain/usecases/play_ayah_use_case.dart`
- Modify: `lib/features/quran_playback/data/repositories/quran_playback_repo_impl.dart`
- Modify: `lib/features/quran_playback/presentation/cubit/playback/playback_cubit.dart`

- [ ] **Step 1: Create the new domain entity file**

Write `lib/features/quran_playback/domain/entities/reciter.dart`:

```dart
enum Reciter {
  husary('Husary_64kbps'),
  husaryMuallim('Husary_Muallim_128kbps'),
  husaryMujawwad('Husary_Mujawwad_128kbps'),
  minshawyMurattal('Minshawy_Murattal_128kbps'),
  abdulBasitMurattal('Abdul_Basit_Murattal_192kbps'),
  abdulBasitMujawwad('Abdul_Basit_Mujawwad_128kbps'),
  alafasy('Alafasy_128kbps'),
  sudais('Abdurrahmaan_As-Sudais_192kbps'),
  shuraym('Saood_ash-Shuraym_128kbps'),
  maher('Maher_AlMuaiqly_64kbps'),
  ghamadi('Ghamadi_40kbps'),
  qatami('Nasser_Alqatami_128kbps'),
  dosary('Yasser_Ad-Dussary_128kbps'),
  shatree('Abu_Bakr_Ash-Shaatree_128kbps');

  final String folderName;

  const Reciter(this.folderName);

  String getAyahUrl(int surah, int ayah) {
    const String baseUrl = "https://mirrors.quranicaudio.com/everyayah/";
    final s = surah.toString().padLeft(3, '0');
    final a = ayah.toString().padLeft(3, '0');
    return "$baseUrl$folderName/$s$a.mp3";
  }
}
```

Note: `arabicName` is dropped — it was a presentation-layer concern in a domain enum. A localization extension will be added in Phase 5, Task 5.4.

- [ ] **Step 2: Update imports — domain repo**

Edit `lib/features/quran_playback/domain/repositories/quran_playback_repo.dart`:

Replace the line `import '../../data/repositories/helper/reciter.dart';` with:

```dart
import '../entities/reciter.dart';
```

- [ ] **Step 3: Update imports — use case**

Edit `lib/features/quran_playback/domain/usecases/play_ayah_use_case.dart`:

Replace `import '../../data/repositories/helper/reciter.dart';` with:

```dart
import '../entities/reciter.dart';
```

- [ ] **Step 4: Update imports — data repo impl**

Edit `lib/features/quran_playback/data/repositories/quran_playback_repo_impl.dart`:

Replace any `import 'helper/reciter.dart';` (or similar) with:

```dart
import '../../domain/entities/reciter.dart';
```

- [ ] **Step 5: Update imports — presentation cubit**

Edit `lib/features/quran_playback/presentation/cubit/playback/playback_cubit.dart`:

Replace `import '../../../data/repositories/helper/reciter.dart';` with:

```dart
import '../../../domain/entities/reciter.dart';
```

- [ ] **Step 6: Delete the old data-side file**

```bash
git rm lib/features/quran_playback/data/repositories/helper/reciter.dart
```

- [ ] **Step 7: Verify**

Run: `flutter analyze`
Expected: 0 new errors. If any file still references the old path, fix the import and re-run.

- [ ] **Step 8: Smoke run**

Run: `flutter run -d <device>` and trigger Mushaf autoplay (taps the play FAB). Expected: ayah plays as before.

- [ ] **Step 9: Commit**

```bash
git add lib/features/quran_playback
git commit -m "refactor: move Reciter enum from data/ to domain/entities/

Drops arabicName from the enum (presentation concern). A localized
extension will be added in a later commit.

Resolves health-check A1-001, A1-002, A1-028, A4-016, A4-037."
```

### Task 1.2: Move `RepeatMode` enum to `domain/entities/`

**Finding IDs:** A1-009 (partial), A1-029, A4-017

**Files:**
- Create: `lib/features/quran_playback/domain/entities/repeat_mode.dart`
- Delete: `lib/features/quran_playback/data/repositories/helper/repeat_mode.dart`
- Modify: `lib/features/quran_playback/presentation/cubit/playback/playback_cubit.dart`

- [ ] **Step 1: Create the new file**

Write `lib/features/quran_playback/domain/entities/repeat_mode.dart`:

```dart
enum RepeatMode {
  once,
  times,
  infinite,
}
```

- [ ] **Step 2: Update the cubit import**

Edit `lib/features/quran_playback/presentation/cubit/playback/playback_cubit.dart`:

Replace `import '../../../data/repositories/helper/repeat_mode.dart';` with:

```dart
import '../../../domain/entities/repeat_mode.dart';
```

- [ ] **Step 3: Delete the old file**

```bash
git rm lib/features/quran_playback/data/repositories/helper/repeat_mode.dart
```

- [ ] **Step 4: Verify**

Run: `flutter analyze`
Expected: 0 new errors.

Note: the `helper/` directory should now be empty. Either leave it (Hive checks ignore empty dirs) or remove it: `rmdir lib/features/quran_playback/data/repositories/helper`.

- [ ] **Step 5: Commit**

```bash
git add lib/features/quran_playback
git commit -m "refactor: move RepeatMode enum to domain/entities/

Resolves health-check A1-029, A4-017."
```

### Task 1.3: Migrate `SettingsCubit`/`SettingsState` to use domain `Settings`

**Finding IDs:** A1-006, A1-007, A1-008

`Settings` (domain entity) already extends `Equatable` and exposes `copyWith`. The cubit and state are currently typed against `SettingsModel` (data layer) for no reason — they only need read access to the three booleans plus `copyWith`. `SettingsModel` keeps its `fromMap`/`toMap` for `HydratedCubit` persistence.

**Files:**
- Modify: `lib/features/settings/presentation/cubit/settings_cubit.dart`
- Modify: `lib/features/settings/presentation/cubit/settings_state.dart`
- Modify: `lib/features/home/presentation/pages/widgets/setting_switch.dart`
- Modify: `lib/features/settings/data/models/settings_model.dart` (add `fromEntity` factory)

- [ ] **Step 1: Add `fromEntity` factory + `toEntity` getter on `SettingsModel`**

Edit `lib/features/settings/data/models/settings_model.dart`. Append inside the class:

```dart
factory SettingsModel.fromEntity(Settings entity) {
  return SettingsModel(
    isDarkMode: entity.isDarkMode,
    isFormat12Hours: entity.isFormat12Hours,
    isArabic: entity.isArabic,
  );
}
```

(`SettingsModel` already `extends Settings`, so the model is already a valid domain entity — no separate `toEntity()` needed, the model IS-A `Settings`.)

- [ ] **Step 2: Rewrite `SettingsState` to hold domain entity**

Replace `lib/features/settings/presentation/cubit/settings_state.dart` with:

```dart
part of 'settings_cubit.dart';

class SettingsState extends Equatable {
  const SettingsState(this.settings);
  final Settings settings;

  @override
  List<Object> get props => [settings];
}
```

- [ ] **Step 3: Rewrite `SettingsCubit`**

Replace `lib/features/settings/presentation/cubit/settings_cubit.dart` with:

```dart
import 'package:equatable/equatable.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:quran_app/features/settings/data/models/settings_model.dart';
import 'package:quran_app/features/settings/domain/entities/settings.dart';

part 'settings_state.dart';

class SettingsCubit extends HydratedCubit<SettingsState> {
  SettingsCubit()
    : super(
        const SettingsState(
          Settings(isDarkMode: true, isFormat12Hours: true, isArabic: true),
        ),
      );

  void updateSettings({
    bool? isDarkMode,
    bool? isFormat12Hours,
    bool? isArabic,
  }) {
    if (isClosed) return;
    emit(
      SettingsState(
        state.settings.copyWith(
          isDarkMode: isDarkMode,
          isFormat12Hours: isFormat12Hours,
          isArabic: isArabic,
        ),
      ),
    );
  }

  @override
  SettingsState? fromJson(Map<String, dynamic> json) {
    return SettingsState(SettingsModel.fromMap(json));
  }

  @override
  Map<String, dynamic>? toJson(SettingsState state) {
    return SettingsModel.fromEntity(state.settings).toMap();
  }
}
```

This also resolves the `isClosed` guard issue (A1-014).

- [ ] **Step 4: Update `setting_switch.dart`**

Edit `lib/features/home/presentation/pages/widgets/setting_switch.dart`:
- Replace `import 'package:quran_app/features/settings/data/models/settings_model.dart';` with `import 'package:quran_app/features/settings/domain/entities/settings.dart';`
- Replace any field type `SettingsModel settings` with `Settings settings` (or drop the unused param per A3-055 — see Phase 12 Task 12.3).

- [ ] **Step 5: Grep for any remaining `state.settingsModel` references**

Run: `Grep` for `state.settingsModel` across `lib/` and rename each to `state.settings`.

Common call sites: `single_prayer_card.dart`, `upcoming_prayer.dart`, `prayers_list.dart`, `settings_bottom_sheet.dart`, `home_view.dart`.

- [ ] **Step 6: Verify**

Run: `flutter analyze`
Expected: 0 errors.

- [ ] **Step 7: Smoke run — verify settings still persist across restarts**

Run the app, toggle dark mode, kill the process, re-run. Expected: dark mode persists (HydratedCubit storage works through the new `fromEntity` round-trip).

- [ ] **Step 8: Commit**

```bash
git add lib/features/settings lib/features/home/presentation/pages/widgets
git commit -m "refactor: use domain Settings entity in SettingsCubit/State

Presentation layer no longer imports SettingsModel from data/. Model
keeps its Hive/JSON serialization; cubit and widgets bind to the
domain entity. Adds isClosed guard to updateSettings.

Resolves health-check A1-006, A1-007, A1-008, A1-014."
```

### Task 1.4: Split `prayers_list_constants.dart` so domain doesn't import Flutter

**Finding IDs:** A1-003, A1-004, A1-005, A4-028

`PrayerName` enum + `prayersList` are pure Dart and stay in `core/`. `prayersMap` (calls `S.current`, references icon asset paths) moves to presentation as a `PrayerName.localized(context)` + `.iconPath` extension.

**Files:**
- Modify: `lib/core/constants/prayers_list_constants.dart` (strip down to pure Dart)
- Create: `lib/features/home/presentation/utils/prayer_name_x.dart`
- Modify (call sites): `lib/features/home/presentation/pages/widgets/prayers_list.dart`, `single_prayer_card.dart`, `upcoming_prayer.dart`, and any other file using `prayersMap`

- [ ] **Step 1: Reduce `prayers_list_constants.dart` to pure Dart**

Replace `lib/core/constants/prayers_list_constants.dart` with:

```dart
enum PrayerName { fajr, sunrise, dhuhr, asr, maghrib, isha }

const prayersList = [
  PrayerName.fajr,
  PrayerName.sunrise,
  PrayerName.dhuhr,
  PrayerName.asr,
  PrayerName.maghrib,
  PrayerName.isha,
];
```

Note: `PrayerData<T1, T2>` is removed — it was only used to bundle name+icon into `prayersMap`, and once the localization + icon are moved to extensions there's no need for a wrapper.

- [ ] **Step 2: Create the presentation extension**

Write `lib/features/home/presentation/utils/prayer_name_x.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:quran_app/core/constants/assets_dir.dart';
import 'package:quran_app/core/constants/prayers_list_constants.dart';
import 'package:quran_app/generated/l10n.dart';

extension PrayerNameX on PrayerName {
  String localized(BuildContext context) {
    final s = S.of(context);
    switch (this) {
      case PrayerName.fajr:
        return s.fajr;
      case PrayerName.sunrise:
        return s.sunrise;
      case PrayerName.dhuhr:
        return s.dhuhr;
      case PrayerName.asr:
        return s.asr;
      case PrayerName.maghrib:
        return s.maghrib;
      case PrayerName.isha:
        return s.isha;
    }
  }

  String get iconPath {
    switch (this) {
      case PrayerName.fajr:
        return AssetsDir.iconsDir('icon_dawn.svg');
      case PrayerName.sunrise:
        return AssetsDir.iconsDir('icon_sunrise.svg');
      case PrayerName.dhuhr:
        return AssetsDir.iconsDir('icon_sun.svg');
      case PrayerName.asr:
        return AssetsDir.iconsDir('icon_sun_descent.svg');
      case PrayerName.maghrib:
        return AssetsDir.iconsDir('icon_sunset.svg');
      case PrayerName.isha:
        return AssetsDir.iconsDir('icon_night.svg');
    }
  }
}
```

- [ ] **Step 3: Update call sites**

Edit `lib/features/home/presentation/pages/widgets/prayers_list.dart`:

Replace the call-site lines that use `prayersMap[prayerName]!.prayerName` and `prayersMap[prayerName]!.prayerIcon` with:

```dart
return SinglePrayerCard(
  iconDir: prayerName.iconPath,
  prayerName: prayerName.localized(context),
  time24: prayerTimes.timings[prayerName]!,
  is24: context.read<SettingsCubit>().state.settings.isFormat12Hours,
  isCurrent: state is PrayerCountdownTick
      ? state.prayerCountdown.nextPrayer == prayerName
      : false,
);
```

Add import: `import 'package:quran_app/features/home/presentation/utils/prayer_name_x.dart';`

(The `sl<SettingsCubit>()` → `context.read<SettingsCubit>()` change is part of A3-006 fix in Phase 4.)

- [ ] **Step 4: Grep for other `prayersMap` references and migrate**

Run: `Grep` for `prayersMap` across `lib/`.

For each match, replace `prayersMap[x]!.prayerName` with `x.localized(context)` and `prayersMap[x]!.prayerIcon` with `x.iconPath`, adding the extension import where needed.

- [ ] **Step 5: Verify domain no longer imports Flutter**

Run: `Grep` for `package:flutter` in `lib/features/home/domain/`. Expected: 0 hits.
Run: `Grep` for `generated/l10n` in `lib/features/home/domain/`. Expected: 0 hits.

- [ ] **Step 6: Build verification**

Run: `flutter analyze`
Expected: 0 errors.

- [ ] **Step 7: Smoke run — home screen renders all 6 prayers correctly**

Expected: each prayer name + icon shows; locale switch swaps Arabic/English names.

- [ ] **Step 8: Commit**

```bash
git add lib/core/constants/prayers_list_constants.dart lib/features/home
git commit -m "refactor: split prayers_list_constants to remove Flutter from domain

PrayerName + prayersList stay pure Dart in core/. Localization and
icon lookup move to a PrayerNameX extension in
features/home/presentation/utils/.

Resolves health-check A1-003, A1-004, A1-005, A4-028."
```

---

## Phase 2: Correctness Fixes (DI race + Equatable bug + `isClosed` guards)

These are the small-but-load-bearing bug fixes. After Phase 2 the app's state-management correctness baseline is solid.

### Task 2.1: Fix `AhadithError`/`AhadithLoaded` `Equatable` props

**Finding IDs:** A3-037

Both states currently omit fields from `props`. `AhadithError.props` should include `paginationError`; `AhadithLoaded.props` should include `lastPage`. Silently breaks `buildWhen`/`BlocSelector`.

**Files:**
- Modify: `lib/features/ahadith/presentation/cubit/ahadith_state.dart`
- Create: `test/features/ahadith/presentation/cubit/ahadith_state_test.dart`

- [ ] **Step 1: Write the failing test**

Write `test/features/ahadith/presentation/cubit/ahadith_state_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/ahadith/presentation/cubit/ahadith_cubit.dart';

void main() {
  group('AhadithError equality', () {
    test('differs when paginationError flips', () {
      const a = AhadithError('boom', paginationError: false);
      const b = AhadithError('boom', paginationError: true);
      expect(a == b, isFalse);
    });
  });

  group('AhadithLoaded equality', () {
    test('differs when lastPage flips', () {
      const a = AhadithLoaded(ahadith: [], lastPage: false);
      const b = AhadithLoaded(ahadith: [], lastPage: true);
      expect(a == b, isFalse);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it FAILS**

Run: `flutter test test/features/ahadith/presentation/cubit/ahadith_state_test.dart`
Expected: both tests FAIL (states are considered equal — props are missing the fields).

- [ ] **Step 3: Fix the props**

Edit `lib/features/ahadith/presentation/cubit/ahadith_state.dart`. Change:

```dart
final class AhadithError extends AhadithState {
  final String message;
  final bool paginationError;
  const AhadithError(this.message, {required this.paginationError});
  @override
  List<Object> get props => [message, paginationError];
}

final class AhadithLoaded extends AhadithState {
  final List<Hadith> ahadith;
  final bool lastPage;

  const AhadithLoaded({required this.ahadith, required this.lastPage});

  @override
  List<Object> get props => [ahadith, lastPage];
}
```

- [ ] **Step 4: Re-run test — should PASS**

Run: `flutter test test/features/ahadith/presentation/cubit/ahadith_state_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/ahadith/presentation/cubit/ahadith_state.dart test/features/ahadith
git commit -m "fix: include paginationError + lastPage in Ahadith state props

Without these fields, Equatable considers states equal even when the
flags differ, silently breaking buildWhen / BlocSelector consumers.

Resolves health-check A3-037."
```

### Task 2.2: Make `initAhadith` and `initPlayback` return `Future<void>`

**Finding IDs:** A1-022, A1-023

Currently both are `void ... async` and called without `await`, so registrations race with the caller.

**Files:**
- Modify: `lib/features/ahadith/ahadith_di.dart`
- Modify: `lib/features/quran_playback/playback_di.dart`
- Modify: `lib/core/di/dependency_injection.dart`

- [ ] **Step 1: Change `initAhadith` signature**

Edit `lib/features/ahadith/ahadith_di.dart` line 15:

```dart
Future<void> initAhadith() async {
```

- [ ] **Step 2: Change `initPlayback` signature**

Edit `lib/features/quran_playback/playback_di.dart` line 14:

```dart
Future<void> initPlayback() async {
```

- [ ] **Step 3: Await both from `initGetIt`**

Edit `lib/core/di/dependency_injection.dart`:

```dart
Future<void> initGetIt() async {
  sl.registerLazySingleton<AudioPlayer>(() => AudioPlayer());
  sl.registerLazySingleton<Dio>(() => Dio());
  sl.registerLazySingleton<SettingsCubit>(() => SettingsCubit());
  initHome();
  initSurahList();
  initMushaf();
  await initAhadith();
  await initPlayback();
}
```

Note: `registerSingleton<SettingsCubit>(SettingsCubit())` → `registerLazySingleton<SettingsCubit>(() => SettingsCubit())` also resolves A1-019.

- [ ] **Step 4: Verify**

Run: `flutter analyze`
Expected: 0 errors.

- [ ] **Step 5: Smoke run — open Ahadith and Mushaf screens immediately after app launch**

Expected: both load without "object not registered" errors.

- [ ] **Step 6: Commit**

```bash
git add lib/features/ahadith/ahadith_di.dart lib/features/quran_playback/playback_di.dart lib/core/di/dependency_injection.dart
git commit -m "fix: await async DI init so registrations complete before first use

initAhadith and initPlayback now return Future<void> and are awaited
from initGetIt. SettingsCubit is also switched to LazySingleton.

Resolves health-check A1-019, A1-022, A1-023."
```

### Task 2.3: Add `if (isClosed) return;` guards to all cubits

**Finding IDs:** A1-012, A1-013, A1-015, A1-016, A1-017, A1-018, A3-057, A3-058

A1-014 (SettingsCubit) is already handled in Task 1.3.

**Files:** modify the 6 cubits listed below.

- [ ] **Step 1: `PrayerCountdownCubit._emitTick` (Timer-driven — highest risk)**

Edit `lib/features/home/presentation/cubit/prayer_countdown_cubit.dart`. Add as the first line of `_emitTick`:

```dart
void _emitTick() {
  if (isClosed) return;
  DateTime now = DateTime.now();
  // ... rest unchanged
}
```

- [ ] **Step 2: `MushafCubit.loadPage`**

Edit `lib/features/surah/presentation/cubit/mushaf/mushaf_cubit.dart`:

```dart
Future<void> loadPage(int pageNumber) async {
  if (isClosed) return;
  emit(MushafLoading());

  try {
    final pageContent = await useCase.call(pageNumber);
    if (isClosed) return;
    emit(MushafLoaded(pageContent));
  } catch (e) {
    if (isClosed) return;
    emit(MushafError(e.toString()));
  }
}
```

- [ ] **Step 3: `SurahCubit.fetchSurahs`**

Edit `lib/features/surah/presentation/cubit/surah/surah_cubit.dart`:

```dart
Future<void> fetchSurahs() async {
  if (isClosed) return;
  final result = await getSurahList.call(NoParams());
  if (isClosed) return;
  emit(result);
}
```

- [ ] **Step 4: `PlaybackCubit` — guard the 6 unguarded emits**

Edit `lib/features/quran_playback/presentation/cubit/playback/playback_cubit.dart`. Add `if (isClosed) return;` before each emit at lines 72, 165, 167, 192, 196, 201. Example for line 72 (inside `startAutoPlay`):

```dart
if (isClosed) return;
emit(state.copyWith(isAutoPlaying: true, isLoading: true));
```

Repeat the same one-liner pattern for the others.

- [ ] **Step 5: `AhadithCubit` — guard the initial emit**

Edit `lib/features/ahadith/presentation/cubit/ahadith_cubit.dart` around line 24 (the `emit(AhadithLoading… )`). Add `if (isClosed) return;` immediately before.

- [ ] **Step 6: `DailyPrayerContextCubit` — guard the initial emit**

Edit `lib/features/home/presentation/cubit/daily_prayer_context_cubit.dart` around line 16 (the `emit(DailyPrayerContextLoading())`). Add `if (isClosed) return;` immediately before.

- [ ] **Step 7: Verify**

Run: `flutter analyze`
Expected: 0 errors.

Run: `flutter test`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add lib/features
git commit -m "fix: add isClosed guards before every cubit emit

Prevents StateError when a cubit is closed mid-async-call. The most
critical case was PrayerCountdownCubit, which fires every second
via Timer.periodic.

Resolves health-check A1-012, A1-013, A1-015, A1-016, A1-017,
A1-018, A3-057, A3-058."
```

---

## Phase 3: Repository `Either<Failure, T>` Migration

`AhadithRepositoryImpl` already uses `Either<Failure, T>` (dartz). `SurahRepository` and `MushafRepository` don't. Migrating brings them in line with the explicit project rule.

### Task 3.1: Migrate `SurahRepository` to return `Either<Failure, T>`

**Finding IDs:** A1-011, A3-018, A3-054, A4-018, A1-031

**Files:**
- Create: `lib/features/surah/presentation/cubit/surah/surah_state.dart`
- Modify: `lib/features/surah/domain/repositories/surah_repo.dart`
- Modify: `lib/features/surah/data/repositories/surah_repo_impl.dart`
- Modify: `lib/features/surah/domain/usecases/get_surah_list.dart`
- Modify: `lib/features/surah/presentation/cubit/surah/surah_cubit.dart`
- Modify call sites: `lib/features/surah/presentation/pages/surah_list/widgets/surah_selection_list.dart`
- Create: `test/features/surah/presentation/cubit/surah_cubit_test.dart`

- [ ] **Step 1: Write the failing test**

Write `test/features/surah/presentation/cubit/surah_cubit_test.dart`:

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/core/usecases/usecase.dart';
import 'package:quran_app/features/surah/domain/entities/surah_entity.dart';
import 'package:quran_app/features/surah/domain/usecases/get_surah_list.dart';
import 'package:quran_app/features/surah/presentation/cubit/surah/surah_cubit.dart';
import 'package:quran_app/features/surah/presentation/cubit/surah/surah_state.dart';

class _MockGetSurahList extends Mock implements GetSurahList {}

void main() {
  late _MockGetSurahList useCase;

  setUpAll(() => registerFallbackValue(NoParams()));
  setUp(() => useCase = _MockGetSurahList());

  blocTest<SurahCubit, SurahState>(
    'emits [Loading, Loaded] when use case succeeds',
    build: () {
      when(() => useCase.call(any())).thenAnswer(
        (_) async => const Right<Failure, List<SurahEntity>>([]),
      );
      return SurahCubit(useCase);
    },
    act: (c) => c.fetchSurahs(),
    expect: () => const [SurahLoading(), SurahLoaded([])],
  );

  blocTest<SurahCubit, SurahState>(
    'emits [Loading, Error] when use case fails',
    build: () {
      when(() => useCase.call(any())).thenAnswer(
        (_) async => const Left<Failure, List<SurahEntity>>(CacheFailure('boom')),
      );
      return SurahCubit(useCase);
    },
    act: (c) => c.fetchSurahs(),
    expect: () => const [SurahLoading(), SurahError('boom')],
  );
}
```

You'll need `flutter pub add --dev mocktail` first.

- [ ] **Step 2: Run test — should FAIL (state classes don't exist yet)**

Run: `flutter test test/features/surah/presentation/cubit/surah_cubit_test.dart`
Expected: COMPILE ERROR ("SurahLoading not defined" etc.).

- [ ] **Step 3: Create the sealed state file**

Write `lib/features/surah/presentation/cubit/surah/surah_state.dart`:

```dart
import 'package:equatable/equatable.dart';
import '../../../domain/entities/surah_entity.dart';

sealed class SurahState extends Equatable {
  const SurahState();
  @override
  List<Object?> get props => [];
}

final class SurahInitial extends SurahState {
  const SurahInitial();
}

final class SurahLoading extends SurahState {
  const SurahLoading();
}

final class SurahLoaded extends SurahState {
  final List<SurahEntity> surahs;
  const SurahLoaded(this.surahs);
  @override
  List<Object?> get props => [surahs];
}

final class SurahError extends SurahState {
  final String message;
  const SurahError(this.message);
  @override
  List<Object?> get props => [message];
}
```

- [ ] **Step 4: Change repo signatures**

Edit `lib/features/surah/domain/repositories/surah_repo.dart`:

```dart
import 'package:dartz/dartz.dart';
import 'package:quran_app/core/errors/failure.dart';
import '../entities/surah_entity.dart';

abstract class SurahRepository {
  Future<Either<Failure, List<SurahEntity>>> getAllSurahs();
}
```

Edit `lib/features/surah/data/repositories/surah_repo_impl.dart`:

```dart
import 'package:dartz/dartz.dart';
import 'package:quran_app/core/errors/failure.dart';
import '../../domain/entities/surah_entity.dart';
import '../../domain/repositories/surah_repo.dart';
import '../datasources/surah_local_data_source.dart';

class SurahRepositoryImpl implements SurahRepository {
  final SurahLocalDataSource local;

  SurahRepositoryImpl(this.local);

  @override
  Future<Either<Failure, List<SurahEntity>>> getAllSurahs() async {
    try {
      final result = await local.loadSurahs();
      return Right(result);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }
}
```

- [ ] **Step 5: Update the use case**

Edit `lib/features/surah/domain/usecases/get_surah_list.dart`:

```dart
import 'package:dartz/dartz.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/core/usecases/usecase.dart';
import '../entities/surah_entity.dart';
import '../repositories/surah_repo.dart';

class GetSurahList implements UseCase<Either<Failure, List<SurahEntity>>, NoParams> {
  final SurahRepository repo;
  GetSurahList(this.repo);

  @override
  Future<Either<Failure, List<SurahEntity>>> call(NoParams params) {
    return repo.getAllSurahs();
  }
}
```

- [ ] **Step 6: Rewrite the cubit to use the sealed state and fold**

Edit `lib/features/surah/presentation/cubit/surah/surah_cubit.dart`:

```dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran_app/core/usecases/usecase.dart';
import '../../../domain/usecases/get_surah_list.dart';
import 'surah_state.dart';

class SurahCubit extends Cubit<SurahState> {
  final GetSurahList getSurahList;

  SurahCubit(this.getSurahList) : super(const SurahInitial());

  Future<void> fetchSurahs() async {
    if (isClosed) return;
    emit(const SurahLoading());
    final result = await getSurahList.call(NoParams());
    if (isClosed) return;
    result.fold(
      (failure) => emit(SurahError(failure.message)),
      (surahs) => emit(SurahLoaded(surahs)),
    );
  }
}
```

- [ ] **Step 7: Update `surah_selection_list.dart` to handle states**

Edit `lib/features/surah/presentation/pages/surah_list/widgets/surah_selection_list.dart`:

Change the `BlocBuilder<SurahCubit, List<SurahEntity>>` to `BlocBuilder<SurahCubit, SurahState>` and add branches:

```dart
return BlocBuilder<SurahCubit, SurahState>(
  builder: (context, state) {
    return switch (state) {
      SurahInitial() || SurahLoading() => const SliverFillRemaining(
          child: Center(child: CircularProgressIndicator()),
        ),
      SurahError(:final message) => SliverFillRemaining(
          child: Center(child: Text(message)),
        ),
      SurahLoaded(:final surahs) => SliverList.builder(
          itemCount: surahs.length,
          itemBuilder: (context, i) => RepaintBoundary(
            child: SurahListTile(surah: surahs[i]),
          ),
        ),
    };
  },
);
```

This also resolves A3-016 (RepaintBoundary) and A3-017 / A3-018 (loading/error UI).

- [ ] **Step 8: Run the test — should PASS**

Run: `flutter test test/features/surah/presentation/cubit/surah_cubit_test.dart`
Expected: PASS.

- [ ] **Step 9: Verify**

Run: `flutter analyze`
Expected: 0 errors.

- [ ] **Step 10: Commit**

```bash
git add lib/features/surah test/features/surah pubspec.yaml pubspec.lock
git commit -m "refactor(surah): use Either<Failure, T> + sealed SurahState

Aligns SurahRepository / GetSurahList / SurahCubit with the dartz
pattern used in AhadithRepositoryImpl. Adds sealed SurahState
(Initial/Loading/Loaded/Error) so the list page handles all states.
Wraps list items in RepaintBoundary.

Resolves health-check A1-011, A1-013, A3-016, A3-017, A3-018,
A3-054, A4-018, A1-031."
```

### Task 3.2: Migrate `MushafRepository` to `Either<Failure, T>`

**Finding IDs:** A1-010, A1-012

**Files:**
- Modify: `lib/features/surah/domain/repositories/mushaf_repo.dart`
- Modify: `lib/features/surah/data/repositories/mushaf_repo_impl.dart`
- Modify: `lib/features/surah/domain/usecases/get_mushaf_page.dart`
- Modify: `lib/features/surah/presentation/cubit/mushaf/mushaf_cubit.dart`
- Modify: `lib/features/surah/presentation/pages/mushaf/widgets/mushaf_page_content.dart` (the `BlocBuilder<MushafCubit>` consumer)
- Create test: `test/features/surah/presentation/cubit/mushaf_cubit_test.dart`

Follow the same pattern as Task 3.1: test first, change signatures, fold in cubit. Skipping repeated boilerplate here — the test file mirrors `surah_cubit_test.dart`. Snippets:

- [ ] **Step 1: Write the failing test (use `Right(MushafPageEntity(...))` and `Left(CacheFailure)`)**
- [ ] **Step 2: Change `mushaf_repo.dart`** to:

```dart
import 'package:dartz/dartz.dart';
import 'package:quran_app/core/errors/failure.dart';
import '../entities/mushaf_page_entity.dart';

abstract class MushafRepository {
  Future<Either<Failure, MushafPageEntity>> getPage(int pageNumber);
}
```

- [ ] **Step 3: Change `mushaf_repo_impl.dart`** to wrap `datasource.getPage` in try/catch → `Right`/`Left(CacheFailure)`.
- [ ] **Step 4: Change `get_mushaf_page.dart`** to return `Future<Either<Failure, MushafPageEntity>>`.
- [ ] **Step 5: Rewrite `MushafCubit.loadPage`**:

```dart
Future<void> loadPage(int pageNumber) async {
  if (isClosed) return;
  emit(MushafLoading());
  final result = await useCase.call(pageNumber);
  if (isClosed) return;
  result.fold(
    (failure) => emit(MushafError(failure.message)),
    (page) => emit(MushafLoaded(page)),
  );
}
```

- [ ] **Step 6: Update consumer in `mushaf_page_content.dart`** — no functional change since the cubit's state types still emit `MushafLoaded`/`MushafError`, but the surrounding try/catch in the cubit is gone.
- [ ] **Step 7: Test + analyze.** Expected: PASS.
- [ ] **Step 8: Commit:**

```bash
git commit -m "refactor(mushaf): use Either<Failure, T> in MushafRepository

Resolves health-check A1-010, A1-012."
```

### Task 3.3: Route `DioException`s in `AhadithRepositoryImpl` through `DioErrorHandler`

**Finding IDs:** A1-026

**Files:** Modify `lib/features/ahadith/data/repositories/ahadith_repository_impl.dart`

- [ ] **Step 1: Replace the catch arm at line 49**

Find:

```dart
} on DioException catch (e) {
  return left(UnknownFailure(e.toString()));
}
```

Replace with:

```dart
} on DioException catch (e) {
  return left(DioErrorHandler.handle(e));
}
```

Ensure `import 'package:quran_app/core/utils/dio_error_handler.dart';` is present.

- [ ] **Step 2: Verify**

Run: `flutter analyze`
Expected: 0 errors.

- [ ] **Step 3: Commit**

```bash
git add lib/features/ahadith/data/repositories/ahadith_repository_impl.dart
git commit -m "fix(ahadith): route DioException through DioErrorHandler

Preserves status-code / timeout distinctions instead of collapsing
everything to UnknownFailure.

Resolves health-check A1-026."
```

---

## Phase 4: Performance & Rebuild Scoping

The biggest single perf win is scoping `prayers_list` rebuilds — currently it rebuilds 5 cards every 1s tick.

### Task 4.1: Scope `PrayersList` rebuilds via `BlocSelector`

**Finding IDs:** A3-005, A3-009

**Files:** Modify `lib/features/home/presentation/pages/widgets/prayers_list.dart`

- [ ] **Step 1: Rewrite to use `BlocSelector` on `nextPrayer` only**

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran_app/core/constants/prayers_list_constants.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';
import 'package:quran_app/features/home/presentation/cubit/prayer_countdown_cubit.dart';
import 'package:quran_app/features/home/presentation/pages/widgets/single_prayer_card.dart';
import 'package:quran_app/features/home/presentation/utils/prayer_name_x.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';

class PrayersList extends StatelessWidget {
  const PrayersList({super.key, required this.prayerTimes});
  final PrayerTimes prayerTimes;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
      child: BlocSelector<PrayerCountdownCubit, PrayerCountdownState, PrayerName?>(
        selector: (state) => state is PrayerCountdownTick
            ? state.prayerCountdown.nextPrayer
            : null,
        builder: (context, nextPrayer) {
          final is24 = context.select<SettingsCubit, bool>(
            (c) => c.state.settings.isFormat12Hours,
          );
          return Row(
            spacing: 8,
            children: prayersList
                .map(
                  (prayerName) => RepaintBoundary(
                    child: SinglePrayerCard(
                      iconDir: prayerName.iconPath,
                      prayerName: prayerName.localized(context),
                      time24: prayerTimes.timings[prayerName]!,
                      is24: is24,
                      isCurrent: nextPrayer == prayerName,
                    ),
                  ),
                )
                .toList(),
          );
        },
      ).animate().fadeIn(),
    );
  }
}
```

- [ ] **Step 2: Verify**

Run: `flutter analyze`
Expected: 0 errors.

- [ ] **Step 3: Smoke run**

Verify cards update only when the "next prayer" actually changes (not every second). Use Flutter Inspector / Performance overlay if you want to confirm — the `SinglePrayerCard` should no longer mark dirty every tick.

- [ ] **Step 4: Commit**

```bash
git commit -am "perf(home): scope PrayersList rebuilds to nextPrayer changes

BlocSelector on nextPrayer + context.select on isFormat12Hours
replaces a BlocBuilder + sl<SettingsCubit>() pattern that rebuilt
all 5 SinglePrayerCards every second.

Resolves health-check A3-005, A3-006, A3-009."
```

### Task 4.2: Scope settings reactivity in `UpcomingPrayer` and `SinglePrayerCard`

**Finding IDs:** A3-007, A3-008

**Files:** Modify `lib/features/home/presentation/pages/widgets/upcoming_prayer.dart`

- [ ] **Step 1: Replace `sl<SettingsCubit>().state...` with `context.select<SettingsCubit, bool>((c) => c.state.settings.isFormat12Hours)` inside `build()`**

Same pattern as Task 4.1 step 1. Extract the static Divider/Padding out of the `BlocBuilder` if doing so is straightforward.

- [ ] **Step 2: Analyze + commit**

```bash
git commit -am "perf(home): use context.select for isFormat12Hours in UpcomingPrayer

Resolves health-check A3-007, A3-008."
```

### Task 4.3: Add `Equatable` to `MushafState` and `PlaybackState`

**Finding IDs:** A3-031, A3-032

**Files:**
- Modify: `lib/features/surah/presentation/cubit/mushaf/mushaf_state.dart`
- Modify: `lib/features/quran_playback/presentation/cubit/playback/playback_state.dart`

- [ ] **Step 1: Convert `MushafState` to a sealed Equatable hierarchy**

Rewrite `mushaf_state.dart`:

```dart
import 'package:equatable/equatable.dart';
import '../../../domain/entities/mushaf_page_entity.dart';

sealed class MushafState extends Equatable {
  const MushafState();
  @override
  List<Object?> get props => [];
}

final class MushafInitial extends MushafState {
  const MushafInitial();
}

final class MushafLoading extends MushafState {
  const MushafLoading();
}

final class MushafLoaded extends MushafState {
  final MushafPageEntity page;
  const MushafLoaded(this.page);
  @override
  List<Object?> get props => [page];
}

final class MushafError extends MushafState {
  final String message;
  const MushafError(this.message);
  @override
  List<Object?> get props => [message];
}
```

This also resolves A1-030 (sealed conversion).

- [ ] **Step 2: Add `Equatable` to `PlaybackState`**

Edit `playback_state.dart`. Make it extend `Equatable` and add:

```dart
@override
List<Object?> get props =>
    [currentAyah, isPlaying, isAutoPlaying, isLoading, error];
```

- [ ] **Step 3: Run all tests + analyze**

Expected: PASS, 0 errors.

- [ ] **Step 4: Commit**

```bash
git commit -am "refactor: convert MushafState to sealed + add Equatable to PlaybackState

Resolves health-check A1-030, A3-031, A3-032."
```

### Task 4.4: Wrap list items + Mushaf in `RepaintBoundary`

**Finding IDs:** A3-016, A3-030, A3-036

A3-016 is already handled in Task 3.1 (surah_selection_list wraps each tile). Remaining:

**Files:**
- Modify: `lib/features/surah/presentation/pages/mushaf/widgets/mushaf_layout.dart`
- Modify: `lib/features/ahadith/presentation/pages/widgets/ahadith_list_view.dart`

- [ ] **Step 1: Wrap `MushafText` in a `RepaintBoundary` in `mushaf_layout.dart`**
- [ ] **Step 2: Wrap `AhadithListItem` in a `RepaintBoundary` inside `ahadith_list_view.dart`'s `ListView.builder`'s `itemBuilder`**
- [ ] **Step 3: Analyze + commit**

```bash
git commit -am "perf: add RepaintBoundary around mushaf text and ahadith list items

Resolves health-check A3-030, A3-036."
```

### Task 4.5: Fix `SearchDelegateBehavior.shouldRebuild`

**Finding IDs:** A3-025, A3-050

**Files:** Modify `lib/features/surah/presentation/pages/surah_list/widgets/search_delegate.dart`

- [ ] **Step 1: Replace `shouldRebuild` body**

```dart
@override
bool shouldRebuild(covariant SearchDelegateBehavior oldDelegate) {
  return oldDelegate.maxHeight != maxHeight ||
      oldDelegate.minHeight != minHeight ||
      oldDelegate.child != child;
}
```

- [ ] **Step 2: Analyze + commit**

```bash
git commit -am "perf: only rebuild sliver search header when its props change

Resolves health-check A3-025, A3-050."
```

### Task 4.6: Memoize `MushafText` spans

**Finding IDs:** A3-029, A3-051

**Files:**
- Modify: `lib/features/surah/presentation/pages/mushaf/widgets/mushaf_text.dart`
- Modify: `lib/features/surah/presentation/pages/mushaf/widgets/ayah_text_span_builder.dart`

- [ ] **Step 1: Cache the base spans for the current page**

Convert `MushafText` to a `StatefulWidget`. Cache `_baseSpans` keyed by `(pageNumber)`. On every `BlocBuilder` rebuild, only swap the highlighted span's `TextStyle`. Skip cache invalidation unless `widget.page` changes.

Outline:

```dart
class _MushafTextState extends State<MushafText> {
  List<InlineSpan>? _cachedSpans;
  int? _cachedPageNumber;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PlaybackCubit, PlaybackState>(
      buildWhen: (p, c) => p.currentAyah != c.currentAyah,
      builder: (context, state) {
        if (_cachedPageNumber != widget.page.number) {
          _cachedSpans = AyahTextSpanBuilder.build(widget.page, context);
          _cachedPageNumber = widget.page.number;
        }
        // Apply highlight to the matching ayah span, re-using _cachedSpans
        return RichText(text: TextSpan(children: _highlight(_cachedSpans!, state.currentAyah)));
      },
    );
  }
}
```

- [ ] **Step 2: Pass real `surahNumber`/`verseCount` into `SurahHeader`** instead of `1, 1` placeholders (resolves A3-051).
- [ ] **Step 3: Run + visual check** — verify autoplay still highlights the correct ayah and surah header shows correct numbers.
- [ ] **Step 4: Commit**

```bash
git commit -am "perf(mushaf): cache base spans, only re-style highlighted ayah

Pass real surah/verse numbers into SurahHeader.

Resolves health-check A3-029, A3-051."
```

### Task 4.7: Scope `AhadithListView` rebuilds via `BlocSelector`

**Finding IDs:** A3-034, A3-035 (covered partially), A3-038, A3-059

**Files:** Modify `lib/features/ahadith/presentation/pages/widgets/ahadith_list_view.dart`, `ahadith_cubit.dart`

- [ ] **Step 1: Extract the ListView into a child widget that selects only `(List<Hadith>, isLoadingMore, lastPage)`**
- [ ] **Step 2: Drop the `mutable ahadith` field in the cubit — derive from `state`**
- [ ] **Step 3: Add a debounce / state-check inside the scroll listener so `fetchAhadith` isn't called repeatedly**

Use:

```dart
void _onScroll() {
  if (_controller.position.pixels >= _controller.position.maxScrollExtent * 0.8) {
    final state = context.read<AhadithCubit>().state;
    if (state is AhadithLoading || state is AhadithLoadingMore) return;
    context.read<AhadithCubit>().fetchAhadith();
  }
}
```

- [ ] **Step 4: Verify + commit**

```bash
git commit -am "perf(ahadith): scope list view rebuilds + guard pagination listener

Resolves health-check A3-034, A3-038, A3-059."
```

---

## Phase 5: Localization Migration

This phase migrates ~12 widgets from hardcoded Arabic/English to `S.of(context)`. The ARB files (`lib/l10n/intl_ar.arb`, `intl_en.arb`) need new keys before the widget edits can compile.

### Task 5.1: Add ARB keys

**Files:**
- Modify: `lib/l10n/intl_ar.arb`
- Modify: `lib/l10n/intl_en.arb`

- [ ] **Step 1: Read both ARB files to see existing keys (so naming is consistent)**

Run: `Read lib/l10n/intl_ar.arb` and `Read lib/l10n/intl_en.arb`.

- [ ] **Step 2: Append new keys to both ARB files**

Append to `intl_ar.arb` (and corresponding English in `intl_en.arb`):

```json
{
  "quran": "القران",
  "hadith": "الحديث",
  "recitation_correction": "تصحيح القراءه",
  "bookmarks": "اشاره مرجعيه",
  "continue_reading": "تابع التلاوة",
  "follow_recitation": "مُتَابَعَةُ التِّلَاوَةِ",
  "segment_surah": "سورة",
  "segment_juz": "جزء",
  "segment_page": "صفحة",
  "segment_bookmark": "علامة مرجعية",
  "search_surah_hint": "البحث عن سورة …",
  "ayah_singular": "آية",
  "ayah_plural": "آيات",
  "page_label": "صفحة",
  "tooltip_autoplay_page": "تشغيل تلقائي لهذه الصفحة",
  "tooltip_pause_playback": "إيقاف مؤقت",
  "tooltip_resume_playback": "استئناف",
  "tooltip_stop_playback": "إيقاف",
  "splash_title": "اَلْقُرْآنُ الْكَرِيمُ",
  "splash_slogan": "اقْرَأْ تَعَلَّمْ احْفَظْ",
  "error_generic": "حدث خطأ"
}
```

(English equivalents go in `intl_en.arb`. Translate each — e.g., `"quran": "Quran"`, `"hadith": "Hadith"`, `"recitation_correction": "Recitation Correction"`, etc.)

- [ ] **Step 3: Trigger code generation**

The project uses `flutter_intl`. In VS Code, save the ARB files — the extension regenerates `lib/generated/intl/*` and `lib/generated/l10n.dart`. If running headless, run:

```bash
flutter pub get
flutter pub run intl_utils:generate
```

Expected: new methods like `S.of(context).quran` appear in `l10n.dart`.

- [ ] **Step 4: Verify**

Run: `flutter analyze`
Expected: 0 errors.

- [ ] **Step 5: Commit**

```bash
git add lib/l10n lib/generated
git commit -m "feat(i18n): add ARB keys for hardcoded UI strings

Resolves prep work for health-check A2-010, A3-014/015/020/024/028/
035/046/047, A4-029/030/031/032/033/034/035/036."
```

### Task 5.2: Migrate hardcoded strings in all flagged widgets

**Finding IDs:** A2-010, A3-014, A3-015, A3-020, A3-024, A3-028, A3-035, A3-045 (placeholder strings), A3-046, A3-047, A4-029, A4-030, A4-031, A4-032, A4-033, A4-034, A4-035, A4-036

**Files:**
- `lib/features/home/presentation/pages/widgets/home_action_buttons.dart`
- `lib/core/widgets/last_quran_read.dart`
- `lib/features/surah/presentation/pages/surah_list/widgets/custom_pressed_button.dart`
- `lib/features/surah/presentation/pages/surah_list/widgets/surah_segment_selector.dart`
- `lib/features/surah/presentation/pages/surah_list/widgets/surah_search_bar.dart`
- `lib/features/surah/presentation/pages/surah_list/widgets/surah_list_tile.dart`
- `lib/features/surah/presentation/pages/mushaf/mushaf_pages.dart`
- `lib/features/ahadith/presentation/pages/widgets/ahadith_list_view.dart`
- `lib/features/splash/pages/splash_page.dart`

- [ ] **Step 1: For each file, replace each Arabic/English string literal with `S.of(context).<key>`**

Example for `home_action_buttons.dart`:

```dart
HomeButton(label: S.of(context).quran, onTap: ...),
HomeButton(label: S.of(context).hadith, onTap: ...),
HomeButton(label: S.of(context).recitation_correction, onTap: () {}),
HomeButton(label: S.of(context).bookmarks, onTap: () {}),
```

Example for `surah_list_tile.dart`'s `ayahLabel`:

```dart
String ayahLabel(BuildContext context, int n) {
  return n == 1 ? S.of(context).ayah_singular : S.of(context).ayah_plural;
}
```

For `ahadith_list_view.dart` error placeholder:

```dart
if (state is AhadithError) {
  return Center(child: Text(state.message.isEmpty ? S.of(context).error_generic : state.message));
}
```

For `mushaf_pages.dart` FAB tooltips:

```dart
FloatingActionButton(
  tooltip: S.of(context).tooltip_autoplay_page,
  ...
)
```

- [ ] **Step 2: Verify each file builds**

Run: `flutter analyze`
Expected: 0 errors.

- [ ] **Step 3: Smoke run with locale toggle**

Switch locale to English in settings. Expected: all migrated strings now show English; no Arabic leaks.

- [ ] **Step 4: Commit**

```bash
git commit -am "feat(i18n): migrate hardcoded strings to S.of(context)

Resolves health-check A2-010, A3-014, A3-015, A3-020, A3-024, A3-028,
A3-035, A3-046, A3-047, A4-029, A4-030, A4-031, A4-032, A4-033,
A4-034, A4-035, A4-036."
```

### Task 5.3: Extract `HadithStatus` enum extensions

**Finding IDs:** A2-003, A4-025, A4-026, A4-027

**Files:**
- Create: `lib/features/ahadith/presentation/utils/hadith_status_x.dart`
- Modify: `lib/features/ahadith/presentation/pages/widgets/hadith_view.dart`
- Modify: `lib/features/ahadith/presentation/pages/widgets/ahadith_list_item.dart`

- [ ] **Step 1: Create the extension file**

Write `lib/features/ahadith/presentation/utils/hadith_status_x.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith.dart';
import 'package:quran_app/generated/l10n.dart';

extension HadithStatusX on HadithStatus {
  String localized(BuildContext context) {
    final s = S.of(context);
    switch (this) {
      case HadithStatus.sahih:
        return s.status_sahih;
      case HadithStatus.hasan:
        return s.status_hasan;
      case HadithStatus.daeef:
        return s.status_daeef;
    }
  }

  Color color(BuildContext context) {
    switch (this) {
      case HadithStatus.sahih:
        return Colors.green;
      case HadithStatus.hasan:
        return Colors.orange;
      case HadithStatus.daeef:
        return Colors.red;
    }
  }
}
```

(Check the actual enum cases in `lib/features/ahadith/domain/entities/hadith.dart` and adjust.)

- [ ] **Step 2: Replace inline switch in `hadith_view.dart` _StatusBadge with `status.localized(context)` + `status.color(context)`**
- [ ] **Step 3: Replace `getHadithStatusText` / `hadithStatusWidget` in `ahadith_list_item.dart` with the same extension calls**
- [ ] **Step 4: Verify + commit**

```bash
git commit -am "refactor(ahadith): extract HadithStatus localized + color extensions

Resolves health-check A2-003, A4-025, A4-026, A4-027."
```

### Task 5.4: Add `Reciter.localized(context)` extension

**Finding IDs:** A4-037

**Files:** Create `lib/features/quran_playback/presentation/utils/reciter_x.dart`

- [ ] **Step 1: Create the extension**

```dart
import 'package:flutter/widgets.dart';
import 'package:quran_app/features/quran_playback/domain/entities/reciter.dart';

extension ReciterX on Reciter {
  String localized(BuildContext context) {
    switch (this) {
      case Reciter.husary:
        return 'محمود خليل الحصري';
      case Reciter.husaryMuallim:
        return 'الحصري (المعلم)';
      // ... etc — copy the names dropped in Task 1.1
    }
  }
}
```

Better: add ARB keys (`reciter_husary` etc.) and reference `S.of(context).reciter_husary`. Pick whichever fits the UI plan.

- [ ] **Step 2: Verify + commit**

```bash
git commit -am "feat(playback): add Reciter.localized() extension in presentation/utils

Resolves health-check A4-037."
```

---

## Phase 6: RTL Directional Conversion

Mechanical conversions. Each finding is a one-line edit.

### Task 6.1: `EdgeInsets.only(left/right)` → `EdgeInsetsDirectional.only(start/end)`

**Finding IDs:** A3-001, A3-022, A3-043

**Files:** `home_app_bar.dart`, `surah_segment_selector.dart`, `last_quran_read.dart`

- [ ] **Step 1: Replace `EdgeInsets.only(left: X, right: Y, ...)` → `EdgeInsetsDirectional.only(start: X, end: Y, ...)` in each file flagged**
- [ ] **Step 2: Verify**

Run: `flutter analyze`. Smoke check both locales (Arabic + English) — padding should look identical in both, mirror-correctly.

- [ ] **Step 3: Commit**

```bash
git commit -am "refactor(rtl): use EdgeInsetsDirectional for layout padding

Resolves health-check A3-001, A3-022, A3-043."
```

### Task 6.2: Remove `textDirection` overrides + `context.isArabic` ternaries that only flip layout

**Finding IDs:** A3-011, A3-013, A3-026, A3-044

**Files:** `surah_list_app_bar.dart`, `surah_list_tile.dart`, `mushaf_pages.dart`, `last_quran_read.dart`

- [ ] **Step 1: For each, delete the `textDirection: context.isArabic ? TextDirection.rtl : TextDirection.ltr` line — ambient `Directionality` already handles it**
- [ ] **Step 2: Smoke check both locales**
- [ ] **Step 3: Commit**

```bash
git commit -am "refactor(rtl): drop redundant textDirection / isArabic ternaries

Resolves health-check A3-011, A3-013, A3-026, A3-044."
```

### Task 6.3: `AnimatedPositioned(left/right)` → `AnimatedPositionedDirectional(start/end)`

**Finding IDs:** A3-021

**Files:** `surah_segment_selector.dart`

- [ ] **Step 1: Replace `AnimatedPositioned(left: x, ...)` with `AnimatedPositionedDirectional(start: x, ...)` and drop the `isArabic` ternary**
- [ ] **Step 2: Smoke check segment animation in both locales**
- [ ] **Step 3: Commit**

```bash
git commit -am "refactor(rtl): use AnimatedPositionedDirectional in segment selector

Resolves health-check A3-021."
```

### Task 6.4: `TextAlign.right` / `.left` → `TextAlign.start`

**Finding IDs:** A3-041

**Files:** `hadith_view.dart`

- [ ] **Step 1: Replace each `TextAlign.right`/`TextAlign.left` with `TextAlign.start`. If a specific section needs a hard direction (e.g., translation always shown LTR regardless of locale), wrap in `Directionality(textDirection: TextDirection.ltr, child: ...)`.**
- [ ] **Step 2: Commit**

```bash
git commit -am "refactor(rtl): use TextAlign.start in hadith view

Resolves health-check A3-041."
```

---

## Phase 7: Reusability Extraction

### Task 7.1: Promote `SettingsBottomSheet` + `showSettings()` to `core/widgets/`

**Finding IDs:** A2-001

**Files:**
- Move: `lib/features/home/presentation/pages/widgets/settings_bottom_sheet.dart` → `lib/core/widgets/settings_bottom_sheet.dart`
- Update imports in `home_app_bar.dart`, `surah_list_app_bar.dart`

- [ ] **Step 1: `git mv` the file**

```bash
git mv lib/features/home/presentation/pages/widgets/settings_bottom_sheet.dart lib/core/widgets/settings_bottom_sheet.dart
```

- [ ] **Step 2: Update the package import inside `settings_bottom_sheet.dart` if it references the old path**
- [ ] **Step 3: Update the two call sites**

In both `home_app_bar.dart` and `surah_list_app_bar.dart`:

```dart
import 'package:quran_app/core/widgets/settings_bottom_sheet.dart';
```

- [ ] **Step 4: Repeat for `setting_switch.dart`** — also a settings UI building block, move to `core/widgets/`.
- [ ] **Step 5: Verify + commit**

```bash
git commit -am "refactor: promote SettingsBottomSheet to core/widgets

Resolves health-check A2-001."
```

### Task 7.2: Promote `CustomPressedButton` to `core/widgets/` and parameterize

**Finding IDs:** A2-002, A3-046, A4-033 (handled via localization in Phase 5)

**Files:**
- Move: `lib/features/surah/presentation/pages/surah_list/widgets/custom_pressed_button.dart` → `lib/core/widgets/primary_pill_button.dart` (also rename class to `PrimaryPillButton`)
- Update import in `lib/core/widgets/last_quran_read.dart`

- [ ] **Step 1: `git mv` + rename**

```bash
git mv lib/features/surah/presentation/pages/surah_list/widgets/custom_pressed_button.dart lib/core/widgets/primary_pill_button.dart
```

- [ ] **Step 2: Inside the new file, rename the class and accept a `label` parameter**

```dart
class PrimaryPillButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const PrimaryPillButton({super.key, required this.label, this.onTap});
  // ... existing build, use widget.label instead of hardcoded string
}
```

- [ ] **Step 3: Update `last_quran_read.dart` to pass `label: S.of(context).continue_reading`**
- [ ] **Step 4: Verify + commit**

```bash
git commit -am "refactor: promote CustomPressedButton to core/widgets as PrimaryPillButton

Now accepts label as a parameter (no hardcoded string).

Resolves health-check A2-002."
```

### Task 7.3: Extract `LoadingView` and `ErrorView` to `core/widgets/`

**Finding IDs:** A2-005

**Files:**
- Create: `lib/core/widgets/loading_view.dart`
- Create: `lib/core/widgets/error_view.dart`
- Modify: `home_view.dart`, `mushaf_page_content.dart`, `ahadith_list_view.dart`

- [ ] **Step 1: Create both widgets**

`lib/core/widgets/loading_view.dart`:

```dart
import 'package:flutter/material.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});
  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}
```

`lib/core/widgets/error_view.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:quran_app/generated/l10n.dart';

class ErrorView extends StatelessWidget {
  final String? message;
  final VoidCallback? onRetry;
  const ErrorView({super.key, this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message?.isNotEmpty == true ? message! : S.of(context).error_generic),
          if (onRetry != null) ...[
            const SizedBox(height: 8),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Replace the 3 occurrences of `Center(child: CircularProgressIndicator())` and `Center(child: Text(state.error))` with `LoadingView()` / `ErrorView(message: state.message)`**
- [ ] **Step 3: Verify + commit**

```bash
git commit -am "refactor: add shared LoadingView and ErrorView widgets

Resolves health-check A2-005."
```

### Task 7.4: Extract `SurfaceCard`

**Finding IDs:** A2-004

**Files:**
- Create: `lib/core/widgets/surface_card.dart`
- Modify: `ahadith_list_item.dart`, `hadith_book_list_item.dart`, `surah_list_tile.dart`

- [ ] **Step 1: Create the widget**

```dart
import 'package:flutter/material.dart';
import 'package:quran_app/core/widgets/prettier_tap.dart';

class SurfaceCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double radius;

  const SurfaceCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.radius = 12,
  });

  @override
  Widget build(BuildContext context) {
    final body = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: child,
    );
    return onTap != null ? PrettierTap(onTap: onTap, child: body) : body;
  }
}
```

- [ ] **Step 2: Replace card chrome in the 3 list items**
- [ ] **Step 3: Verify + commit**

```bash
git commit -am "refactor: extract SurfaceCard core widget

Resolves health-check A2-004."
```

### Task 7.5: Extract `FormattedTimeText`

**Finding IDs:** A2-007

**Files:**
- Create: `lib/features/home/presentation/pages/widgets/formatted_time_text.dart`
- Modify: `single_prayer_card.dart`, `upcoming_prayer.dart`

- [ ] **Step 1: Create the widget**

Bundles the 12h/24h toggle behind a `BlocSelector` on `isFormat12Hours`. Show one TextSpan with the formatted time and an optional AM/PM suffix.

- [ ] **Step 2: Replace the duplicated blocks in both call sites**
- [ ] **Step 3: Commit**

```bash
git commit -am "refactor: extract FormattedTimeText (single source of 12h/24h toggle)

Resolves health-check A2-007."
```

### Task 7.6: Add typography secondary-text helper

**Finding IDs:** A2-006

**Files:** Modify `lib/config/theme/typography_styles.dart`

- [ ] **Step 1: Add an extension or helper method**

Pattern (adapt to actual `TS` API):

```dart
extension TSContextual on TextStyle {
  TextStyle secondary(BuildContext context) =>
      copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
}
```

- [ ] **Step 2: Replace all 13 `TS.boldXX.copyWith(color: context.colorScheme.onSurfaceVariant)` occurrences with `TS.boldXX.secondary(context)`**
- [ ] **Step 3: Commit**

```bash
git commit -am "refactor: add TextStyle.secondary(context) helper

Resolves health-check A2-006."
```

---

## Phase 8: DI Consolidation

### Task 8.1: Create `surah_di.dart` consolidating `mushaf_di.dart` + `surah_list_di.dart`

**Finding IDs:** A1-024, A1-025, A4-024

**Files:**
- Create: `lib/features/surah/surah_di.dart`
- Delete: `lib/features/surah/presentation/pages/mushaf/mushaf_di.dart`, `lib/features/surah/presentation/pages/surah_list/surah_list_di.dart`
- Modify: `lib/core/di/dependency_injection.dart`

- [ ] **Step 1: Read both old DI files**
- [ ] **Step 2: Merge into a single `initSurah()` function in `lib/features/surah/surah_di.dart`**
- [ ] **Step 3: Replace `initSurahList(); initMushaf();` with `initSurah();` in `dependency_injection.dart`**
- [ ] **Step 4: Delete the two old files**
- [ ] **Step 5: Verify + commit**

```bash
git commit -am "refactor(di): consolidate surah DI into features/surah/surah_di.dart

Resolves health-check A1-024, A1-025, A4-024."
```

### Task 8.2: Create `settings_di.dart`

**Finding IDs:** A4-023

**Files:**
- Create: `lib/features/settings/settings_di.dart`
- Modify: `lib/core/di/dependency_injection.dart`

- [ ] **Step 1: Move the `SettingsCubit` registration out of `dependency_injection.dart` into:**

```dart
import 'package:quran_app/core/di/dependency_injection.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';

void initSettings() {
  sl.registerLazySingleton<SettingsCubit>(() => SettingsCubit());
}
```

- [ ] **Step 2: Call `initSettings()` from `initGetIt()`**
- [ ] **Step 3: Commit**

```bash
git commit -am "refactor(di): extract SettingsCubit registration to settings_di.dart

Resolves health-check A4-023."
```

### Task 8.3: Rename `playback_di.dart` → `quran_playback_di.dart`

**Finding IDs:** A4-050

**Files:**
- Move: `lib/features/quran_playback/playback_di.dart` → `lib/features/quran_playback/quran_playback_di.dart`
- Modify: `lib/core/di/dependency_injection.dart`

- [ ] **Step 1: `git mv`, rename function to `initQuranPlayback()`, update import + call site**
- [ ] **Step 2: Commit**

```bash
git commit -am "refactor(di): rename playback_di to quran_playback_di for consistency

Resolves health-check A4-050."
```

### Task 8.4: Register `QuranPageService` by abstract interface

**Finding IDs:** A1-021, A4-045

**Files:** Modify `lib/features/quran_playback/quran_playback_di.dart`

- [ ] **Step 1: Change** `sl.registerLazySingleton<QuranPageServiceImpl>(() => QuranPageServiceImpl())` to `sl.registerLazySingleton<QuranPageService>(() => QuranPageServiceImpl())`

- [ ] **Step 2: Change the `PlaybackCubit` registration to resolve `sl<QuranPageService>()`**
- [ ] **Step 3: Commit**

```bash
git commit -am "refactor(di): register QuranPageService by interface, not concrete

Resolves health-check A1-021, A4-045."
```

### Task 8.5: Register `PrayerCountdownCubit` in DI

**Finding IDs:** A1-020

**Files:** Modify `lib/features/home/home_di.dart`, and the `BlocProvider` create-site.

- [ ] **Step 1: Add `sl.registerFactory<PrayerCountdownCubit>(() => PrayerCountdownCubit())` to `home_di.dart`**
- [ ] **Step 2: Replace `BlocProvider(create: (_) => PrayerCountdownCubit())` with `BlocProvider(create: (_) => sl<PrayerCountdownCubit>())`**
- [ ] **Step 3: Commit**

```bash
git commit -am "refactor(di): register PrayerCountdownCubit in home_di.dart

Resolves health-check A1-020."
```

---

## Phase 9: Security

### Task 9.1: Move hardcoded API key out of source

**Finding IDs:** A4-041

**Files:**
- Modify: `lib/features/ahadith/data/datasources/remote/ahadith_remote_data_source.dart`
- Modify: `lib/main.dart` or `lib/features/ahadith/ahadith_di.dart` (pass key in via DI)

- [ ] **Step 1: Replace the hardcoded API key with `const String.fromEnvironment('AHADITH_API_KEY', defaultValue: '')`**
- [ ] **Step 2: Verify build with `flutter run --dart-define=AHADITH_API_KEY=<key>` works**
- [ ] **Step 3: Add an entry to README or `.env.example` (if any) describing the build flag**
- [ ] **Step 4: Commit (rotate the leaked key separately — it's exposed in git history)**

```bash
git commit -am "fix(security): read AHADITH_API_KEY from --dart-define instead of source

The previous hardcoded key is leaked in git history and MUST be
rotated out of band.

Resolves health-check A4-041."
```

---

## Phase 10: Naming Conventions

### Task 10.1: Rename `*_repo.dart` files → `*_repository.dart`

**Finding IDs:** A4-003, A4-004, A4-005, A4-006

**Files:**
- `lib/features/surah/domain/repositories/surah_repo.dart` → `surah_repository.dart`
- `lib/features/surah/domain/repositories/mushaf_repo.dart` → `mushaf_repository.dart`
- `lib/features/surah/data/repositories/surah_repo_impl.dart` → `surah_repository_impl.dart`
- `lib/features/surah/data/repositories/mushaf_repo_impl.dart` → `mushaf_repository_impl.dart`

- [ ] **Step 1: `git mv` each file**
- [ ] **Step 2: Update imports across the codebase. Use `Grep` for `surah_repo`, `mushaf_repo` and fix each hit**
- [ ] **Step 3: Verify + commit**

```bash
git commit -am "refactor: rename *_repo.dart files to *_repository.dart

Resolves health-check A4-003, A4-004, A4-005, A4-006."
```

### Task 10.2: Rename `QuranPlaybackRepo` → `QuranPlaybackRepository`

**Finding IDs:** A4-001, A4-002

**Files:** rename both file (`quran_playback_repo.dart` → `quran_playback_repository.dart`, `quran_playback_repo_impl.dart` → `quran_playback_repository_impl.dart`) and class.

- [ ] **Step 1: Rename file via `git mv`**
- [ ] **Step 2: Rename class — use `Edit` with `replace_all` in the file**
- [ ] **Step 3: Grep for `QuranPlaybackRepo` (without `Repository`) across the codebase and replace**
- [ ] **Step 4: Verify + commit**

```bash
git commit -am "refactor: rename QuranPlaybackRepo → QuranPlaybackRepository

Resolves health-check A4-001, A4-002."
```

### Task 10.3: Standardize use case suffix

**Finding IDs:** A4-019, A4-020, A4-021, A4-022

Pick one convention project-wide. The codebase uses both `GetAhadithPageUseCase` (with suffix) and `GetCurrentLocation` (without). Recommend adopting the suffix everywhere since it's the explicit pattern for ahadith and playback.

**Files:** every use case file under `lib/features/*/domain/usecases/`

- [ ] **Step 1: Decide convention** — recommend "with `UseCase` suffix".
- [ ] **Step 2: Rename non-conforming classes (`GetSurahList` → `GetSurahListUseCase`, `GetMushafPage` → `GetMushafPageUseCase`, `GetDailyPrayerContext` → `GetDailyPrayerContextUseCase`, `GetPrayerTimes` → `GetPrayerTimesUseCase`, `GetCurrentLocation` → `GetCurrentLocationUseCase`)**
- [ ] **Step 3: Rename files to match (`get_surah_list.dart` → `get_surah_list_use_case.dart` etc.)**
- [ ] **Step 4: Update DI registrations and consumers**
- [ ] **Step 5: Verify + commit**

```bash
git commit -am "refactor: standardize use case classes/files with UseCase suffix

Resolves health-check A4-019, A4-020, A4-021, A4-022."
```

### Task 10.4: Rename `mushaf_pages.dart` → `mushaf_page.dart`

**Finding IDs:** A4-007

- [ ] **Step 1: `git mv lib/features/surah/presentation/pages/mushaf/mushaf_pages.dart lib/features/surah/presentation/pages/mushaf/mushaf_page.dart`**
- [ ] **Step 2: Update imports**
- [ ] **Step 3: Commit**

```bash
git commit -am "refactor: rename mushaf_pages.dart to mushaf_page.dart (matches class name)

Resolves health-check A4-007."
```

---

## Phase 11: Folder Structure Cleanup

### Task 11.1: Move local data sources into `local/` subfolders

**Finding IDs:** A4-014, A4-015

- [ ] **Step 1: `git mv lib/features/surah/data/datasources/mushaf_local_data_source.dart lib/features/surah/data/datasources/local/mushaf_local_data_source.dart`**
- [ ] **Step 2: Same for `surah_local_data_source.dart`**
- [ ] **Step 3: Update imports**
- [ ] **Step 4: Commit**

```bash
git commit -am "refactor: move surah local data sources into local/ subfolder

Resolves health-check A4-014, A4-015."
```

### Task 11.2: Move splash under `presentation/`

**Finding IDs:** A4-047

- [ ] **Step 1: `git mv lib/features/splash/pages lib/features/splash/presentation/pages`**
- [ ] **Step 2: Update imports**
- [ ] **Step 3: Commit**

```bash
git commit -am "refactor: move splash pages under presentation/

Resolves health-check A4-047."
```

### Task 11.3: Add abstract+Impl pairs to remote data sources

**Finding IDs:** A4-010, A4-011, A4-013, A4-027

**Files:**
- `lib/features/home/data/datasources/remote/location_remote_data_source.dart`
- `lib/features/ahadith/data/datasources/remote/ahadith_remote_data_source.dart`
- `lib/features/quran_playback/data/datasources/remote/quran_playback_remote_data_source.dart`
- `lib/features/surah/data/datasources/mushaf_local_data_source.dart` (A1-027)

- [ ] **Step 1: For each, extract the public methods into an `abstract class <Name>` and rename the existing concrete to `<Name>Impl`**
- [ ] **Step 2: Update DI registrations to register the interface**
- [ ] **Step 3: Commit**

```bash
git commit -am "refactor: add abstract+Impl pairs to remote data sources

Resolves health-check A4-010, A4-011, A4-013, A1-027."
```

### Task 11.4: Rename PrayerTimeRemoteDataSource → PrayerTimesRemoteDataSource (plural)

**Finding IDs:** A4-009

- [ ] **Step 1: Rename the class, file, and all references**
- [ ] **Step 2: Commit**

```bash
git commit -am "refactor: pluralize PrayerTimesRemoteDataSource to match feature naming

Resolves health-check A4-009."
```

---

## Phase 12: Polish & Suggestions

Bundles the remaining ~30 suggestion-level findings into focused commits.

### Task 12.1: Const-correctness sweep

**Finding IDs:** A3-004, A3-009, A3-048, A3-049, A3-068, A3-069

- [ ] **Step 1: Run `dart fix --apply` if available; otherwise grep for the flagged lines and add `const` where the analyzer suggests**
- [ ] **Step 2: Commit**

```bash
git commit -am "chore: add missing const on stateless widget instances

Resolves health-check A3-004, A3-009, A3-048, A3-049, A3-068, A3-069."
```

### Task 12.2: Remove pointless page indirection

**Finding IDs:** A3-071, A3-072

**Files:** `books_list_page.dart`, `hadith_page.dart`

- [ ] **Step 1: Inline `BooksListPage` / `HadithPage` — update router to point directly at `BooksListView` / `HadithView`, then delete the wrapper files**
- [ ] **Step 2: Commit**

```bash
git commit -am "refactor: remove pointless BooksListPage / HadithPage wrappers

Resolves health-check A3-071, A3-072."
```

### Task 12.3: Drop unused parameters

**Finding IDs:** A3-053, A3-055, A4-051, A4-052

**Files:** `basmala_text.dart` (lineHeight), `setting_switch.dart` (settings), `surah_header.dart` (verseCount, surahNumber if still unused after Task 4.6 wires them in — re-check before removing)

- [ ] **Step 1: Remove each unused parameter and update call sites**
- [ ] **Step 2: Commit**

```bash
git commit -am "chore: drop unused widget parameters

Resolves health-check A3-053, A3-055, A4-051, A4-052."
```

### Task 12.4: `S.current` → `S.of(context)` where context is available

**Finding IDs:** A3-002, A3-042

- [ ] **Step 1: Grep for `S.current` in widget `build` methods; replace with `S.of(context)`**
- [ ] **Step 2: Commit**

```bash
git commit -am "chore: prefer S.of(context) when context is available

Resolves health-check A3-002, A3-042."
```

### Task 12.5: Remove `print()` from production code

**Finding IDs:** A4-040

**Files:** `lib/features/home/data/datasources/remote/location_remote_data_source.dart:61`

- [ ] **Step 1: Delete the `print(arResponse.data);` line**
- [ ] **Step 2: Commit**

```bash
git commit -am "chore: remove leftover print() from LocationRemoteDataSource

Resolves health-check A4-040."
```

### Task 12.6: Use `AssetsDir` for `header.png`

**Finding IDs:** A4-038

**Files:** `surah_header.dart`

- [ ] **Step 1: Replace `'assets/images/header.png'` with `AssetsDir.imagesDir('header.png')`**
- [ ] **Step 2: Commit**

```bash
git commit -am "chore: route header asset through AssetsDir

Resolves health-check A4-038."
```

### Task 12.7: Extract `'userLocation'` magic key

**Finding IDs:** A4-039

**Files:** `lib/features/home/data/datasources/local/location_local_data_source.dart`

- [ ] **Step 1: Add `static const _userLocationKey = 'userLocation';` and replace literals**
- [ ] **Step 2: Commit**

```bash
git commit -am "chore: extract userLocation hive key to a constant

Resolves health-check A4-039."
```

### Task 12.8: Force-unwrap → null-safe display in `HomeAppBar`

**Finding IDs:** A4-042

**Files:** `home_app_bar.dart:43`

- [ ] **Step 1: Replace `location.city!` / `location.country!` with `location.city ?? ''` / `location.country ?? ''` (or guard the whole Text with `if (location.city != null)`)**
- [ ] **Step 2: Commit**

```bash
git commit -am "fix: null-safe city/country display in HomeAppBar

Resolves health-check A4-042."
```

### Task 12.9: Fix `PlaybackState.copyWith` sentinel handling

**Finding IDs:** A3-033

**Files:** `playback_state.dart`

- [ ] **Step 1: Replace `error: error` with an explicit flag pattern**

```dart
PlaybackState copyWith({
  AyahIdentifier? currentAyah,
  bool clearAyah = false,
  bool? isPlaying,
  bool? isAutoPlaying,
  bool? isLoading,
  String? error,
  bool clearError = false,
}) {
  return PlaybackState(
    currentAyah: clearAyah ? null : (currentAyah ?? this.currentAyah),
    isPlaying: isPlaying ?? this.isPlaying,
    isAutoPlaying: isAutoPlaying ?? this.isAutoPlaying,
    isLoading: isLoading ?? this.isLoading,
    error: clearError ? null : (error ?? this.error),
  );
}
```

- [ ] **Step 2: Update call sites that pass `error: failure.message` (no change) and `state.copyWith(isPlaying: false)` (no change since `error` is no longer auto-cleared)**
- [ ] **Step 3: Verify + commit**

```bash
git commit -am "fix(playback): use explicit clear flags in PlaybackState.copyWith

Prevents accidental clearing of error and allows explicit clearing of
currentAyah when needed.

Resolves health-check A3-033."
```

### Task 12.10: `BlocConsumer` / `BlocListener` `listenWhen` predicates

**Finding IDs:** A3-062

**Files:** `home_view.dart`

- [ ] **Step 1: Add `listenWhen` to the `BlocListener<DailyPrayerContextCubit>` so the timer isn't restarted on identical Loaded emits**

```dart
BlocListener<DailyPrayerContextCubit, DailyPrayerContextState>(
  listenWhen: (p, c) =>
      c is DailyPrayerContextLoaded &&
      (p is! DailyPrayerContextLoaded ||
          p.dailyPrayerContext != c.dailyPrayerContext),
  listener: ...,
)
```

- [ ] **Step 2: Commit**

```bash
git commit -am "perf: add listenWhen to avoid restarting countdown timer redundantly

Resolves health-check A3-062."
```

### Task 12.11: Remaining minor cleanups

**Finding IDs:** A3-019 (empty search callbacks), A3-023 (LayoutBuilder for segment width), A3-027 (FAB exception swallowing), A3-038 (mutable cubit field — handled in Task 4.7), A3-039 (privatize top-level functions), A3-040 (ListView.builder for books), A3-060 (Reciter default documentation), A3-061 (PrettierTap addPostFrameCallback), A3-064 (RichText overflow), A3-065 (drop pointless PrettierTap), A3-066 (memoize SinglePrayerCard BoxDecoration), A3-067 (drop dead comment), A3-070 (ListView.separated for books), A4-008 (rename `SurahListPageAppBar` → `SurahListAppBar`), A4-012 (optional abstract for local DS), A4-028 (handled in 1.4), A4-038 (handled in 12.6), A4-043 (already in core after Task 7.2), A4-044 (RepeatMode UI), A4-046 (cubit folder depth), A4-048 (settings layers), A4-049 (quran_playback presentation/pages — exception).

Each is small enough to handle in a single commit per cluster. Examples:

- [ ] **Step 1: Surface exceptions in `mushaf_pages.dart` FAB callbacks instead of swallowing (A3-027)**

```dart
onPressed: () async {
  try {
    await cubit.startAutoPlay(...);
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
  }
}
```

- [ ] **Step 2: Convert `BooksListView`'s `ListView(children: …)` → `ListView.separated` (A3-040, A3-070)**
- [ ] **Step 3: Rename `SurahListPageAppBar` → `SurahListAppBar` (A4-008)**
- [ ] **Step 4: Add a `// TODO: implement search` comment near the empty callbacks in `surah_search_bar.dart` (A3-019). Or remove the bar from the page body until search is implemented.**
- [ ] **Step 5: Privatize `hadithStatusWidget` and `getHadithStatusText` (A3-039) — already replaced by extension in Task 5.3, so just delete the orphaned top-level helpers**
- [ ] **Step 6: Remove the pointless `PrettierTap` wrapping the status badge in `ahadith_list_item.dart` (A3-065)**
- [ ] **Step 7: Document the `Reciter.alafasy` default in `playback_cubit.autoPlayPage` (A3-060) — add a comment:**

```dart
// Default to alafasy when no reciter has been chosen yet. UI should
// expose a reciter picker so this fallback isn't silent.
```

- [ ] **Step 8: Per-cluster commits**

```bash
git commit -m "chore: surface FAB exceptions in mushaf player (A3-027)"
git commit -m "chore: use ListView.separated in BooksListView (A3-040, A3-070)"
git commit -m "refactor: rename SurahListPageAppBar to SurahListAppBar (A4-008)"
git commit -m "chore: privatize hadith status helpers, drop redundant PrettierTap (A3-039, A3-065)"
git commit -m "docs: document Reciter.alafasy fallback (A3-060)"
```

### Task 12.12: Settings feature data layer (decision)

**Finding IDs:** A4-048

The settings feature is intentionally cubit-only (HydratedCubit handles persistence). Either:

- [ ] **Option A:** Add a `SettingsLocalDataSource` + `SettingsRepository` to satisfy the folder rule (overkill — HydratedCubit already handles it).
- [ ] **Option B (recommended):** Document the exception in `CLAUDE.md` (when you create it) or in a comment at the top of `settings_cubit.dart`.

Recommend Option B. One-line comment in `settings_cubit.dart`:

```dart
// Settings is intentionally a cubit-only feature: HydratedCubit handles
// persistence directly, so the data/domain/repository layers are
// unnecessary scaffolding.
```

- [ ] **Step 1: Add comment**
- [ ] **Step 2: Commit**

```bash
git commit -am "docs: document settings as a cubit-only feature exception

Resolves health-check A4-048."
```

---

## Phase 13: Final Verification

### Task 13.1: Re-run the health check

- [ ] **Step 1: Run `/health-check` again**
- [ ] **Step 2: Compare new report against `docs/reviews/2026-05-13-health-check.md` — most findings should be resolved**
- [ ] **Step 3: For any finding that survived, decide whether to fix or document as accepted**

### Task 13.2: Full test + analyze pass

- [ ] **Step 1: `flutter analyze` — expect 0 errors**
- [ ] **Step 2: `flutter test` — expect all PASS**
- [ ] **Step 3: Smoke run on a real device — exercise: home screen prayer countdown, settings toggle (locale + 12h/24h + dark mode + persistence after kill), surah list (search, segment selector, scroll), open mushaf page, autoplay, pause/resume/stop, ahadith books list, ahadith list pagination**

### Task 13.3: Squash-merge plan completion

- [ ] **Step 1: Decide on merge strategy** — either keep all per-task commits or squash into ~13 phase-level commits.
- [ ] **Step 2: Open PR against `main`**

---

## Self-Review Notes

**Spec coverage:** All 154 findings (after-filter) are mapped to a task — Architecture/DI (32) → Phase 1, 2, 3, 8; Reusability (10) → Phase 7; UI/Perf (71) → Phase 2, 4, 5, 6, 12; Convention (41) → Phase 5, 8, 9, 10, 11, 12.

**Placeholder scan:** No "TBD" or "implement later". Each step has either concrete code or an exact mechanical instruction (rename, move, replace).

**Type consistency:** `Settings` (domain entity), `SettingsModel` (data), `SettingsState` (presentation, holds `Settings`), `Reciter` (domain), `RepeatMode` (domain) are used consistently throughout. `SurahCubit`/`MushafCubit` share the sealed-state pattern after Phases 3.1/4.3.

**Cross-task ordering:** Phase 1.3 (Settings refactor) must precede any settings widget edits in later phases — it is the lowest-numbered task touching `setting_switch.dart`. Phase 1.4 must precede Phase 4.1 (which depends on `PrayerNameX.iconPath`). Phase 5.1 (ARB keys) must precede Phase 5.2 (widget migrations) and Phase 5.3 (`HadithStatusX`).

**Test coverage gaps:** Phases 1, 6, 7, 10, 11, 12 are pure refactors with no test additions — verified via `flutter analyze` + smoke run. Phase 2 (Equatable fix), Phase 3 (Either migration) add unit tests. If you want fuller coverage, add widget tests for the localized strings and BlocSelector scoping, but those are out of scope for this plan.
