# Pinned Prayer Notification — Dart Foundation (Plan A)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up the Dart-side `lib/features/notifications/` feature module (entities, repository, use cases, MethodChannel surface, DI, Settings field) so a follow-up plan (Plan B — Android native) can plug in without changing any of this Dart code.

**Architecture:** A new feature under `lib/features/notifications/` with the standard Clean Architecture layout (domain/data/presentation + `notifications_di.dart`). The `NotificationsRepository` exposes strip + adhan operations. For Plan A only, the data source uses `MethodChannel` but returns `Left(PlatformNotSupportedFailure)` for every call (the channel handler doesn't exist yet on either platform). The adhan-scheduling path delegates to the existing `PrayerNotificationScheduler` so per-prayer adhans keep firing exactly as today. The Settings toggle exists in `SettingsCubit` and persists in Hydrated storage, but the UI switch is hidden behind a build-time flag (`kEnablePinnedStripUi = false`) until Plan B is ready.

**Tech Stack:** Flutter / Dart, `flutter_bloc`, `hydrated_bloc`, `get_it`, `dartz` (`Either<Failure, Unit>`), `mocktail`, `bloc_test`, MethodChannel via `flutter/services.dart`.

**Sister documents:**
- Spec: `docs/superpowers/specs/2026-05-23-pinned-prayer-notification-design.md`
- Plan B (Android native): not yet written; produced after Plan A merges.
- Plan C (iOS Live Activity + adhan rewrite): not yet written.

**Test command:** `flutter test` for the whole suite, `flutter test test/path/to/file.dart` for a single file. Run from project root (`D:\flutter_projects\quran_app`).

**Commit style:** This repo uses Conventional Commits scoped by feature: `feat(notifications): ...`, `test(notifications): ...`, `refactor(settings): ...`. Every task ends with a commit. Co-Authored-By trailer is optional — keep or omit to match local norm.

---

## File structure (new + modified)

**Created in this plan:**

```
lib/features/notifications/
├── domain/
│   ├── entities/
│   │   ├── adhan_audio_settings.dart
│   │   ├── prayer_cell.dart
│   │   └── prayer_strip_state.dart
│   ├── repositories/
│   │   └── notifications_repository.dart
│   ├── usecases/
│   │   ├── disable_prayer_strip.dart
│   │   ├── enable_prayer_strip.dart
│   │   ├── refresh_prayer_strip.dart
│   │   └── sync_daily_adhans.dart
│   └── builders/
│       └── prayer_strip_state_builder.dart
├── data/
│   ├── datasources/
│   │   └── notifications_native_data_source.dart
│   └── repositories/
│       └── notifications_repository_impl.dart
└── notifications_di.dart

lib/core/helper functions/numeral_helpers.dart  # pure-Dart numeral conversion
lib/core/constants/feature_flags.dart           # build-time UI gate

test/features/notifications/                    # full mirror tree
├── domain/
│   ├── entities/{adhan_audio_settings,prayer_cell,prayer_strip_state}_test.dart
│   ├── usecases/{disable,enable,refresh}_prayer_strip_test.dart
│   ├── usecases/sync_daily_adhans_test.dart
│   └── builders/prayer_strip_state_builder_test.dart
└── data/
    ├── datasources/notifications_native_data_source_test.dart
    └── repositories/notifications_repository_impl_test.dart

test/core/helper functions/numeral_helpers_test.dart
```

**Modified in this plan:**

```
lib/core/errors/failure.dart                                       # new failure types
lib/core/di/dependency_injection.dart                              # call initNotifications()
lib/features/settings/domain/entities/settings.dart                # new bool field
lib/features/settings/data/models/settings_model.dart              # round-trip new field
lib/features/settings/presentation/cubit/settings_cubit.dart       # new method
lib/features/home/presentation/pages/home_page.dart                # wire new use cases
lib/l10n/intl_en.arb                                               # toggle copy
lib/l10n/intl_ar.arb                                               # toggle copy
test/features/settings/settings_cubit_test.dart                    # cover new field
```

**Deleted in this plan:**

```
lib/features/home/domain/usecases/schedule_prayer_notifications.dart
test/features/home/domain/usecases/schedule_prayer_notifications_test.dart
```

**Untouched (kept as fallback per advisor's note):**

```
lib/core/notifications/prayer_notification_scheduler.dart
lib/core/notifications/prayer_notification_scheduler_impl.dart
```

These stay alive because Plan A's `NotificationsRepositoryImpl` injects the scheduler and delegates `scheduleDailyAdhans` to it. Plan B / Plan C remove them once native paths are live on both platforms.

---

## Phase A1 — Settings field plumbing

### Task 1: Add `isPrayerStripPinned` to `Settings` entity

**Files:**
- Modify: `lib/features/settings/domain/entities/settings.dart`

- [ ] **Step 1: Modify the entity**

Replace the file's contents with:

```dart
import 'package:equatable/equatable.dart';

import '../../../quran_playback/domain/entities/reciter.dart';

class Settings extends Equatable {
  final bool isDarkMode;
  final bool isFormat12Hours;
  final bool isArabic;
  final double playbackSpeed;
  final Reciter defaultReciter;
  final bool isPrayerStripPinned;

  const Settings({
    required this.isDarkMode,
    required this.isFormat12Hours,
    required this.isArabic,
    this.playbackSpeed = 1.0,
    this.defaultReciter = Reciter.alafasy,
    this.isPrayerStripPinned = false,
  });

  Settings copyWith({
    bool? isDarkMode,
    bool? isFormat12Hours,
    bool? isArabic,
    double? playbackSpeed,
    Reciter? defaultReciter,
    bool? isPrayerStripPinned,
  }) {
    return Settings(
      isArabic: isArabic ?? this.isArabic,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      isFormat12Hours: isFormat12Hours ?? this.isFormat12Hours,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      defaultReciter: defaultReciter ?? this.defaultReciter,
      isPrayerStripPinned: isPrayerStripPinned ?? this.isPrayerStripPinned,
    );
  }

  @override
  List<Object?> get props => [
        isArabic,
        isDarkMode,
        isFormat12Hours,
        playbackSpeed,
        defaultReciter,
        isPrayerStripPinned,
      ];
}
```

- [ ] **Step 2: Run analyzer to verify no breakage**

Run: `flutter analyze lib/features/settings`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/features/settings/domain/entities/settings.dart
git commit -m "feat(settings): add isPrayerStripPinned field to Settings entity"
```

---

### Task 2: Update `SettingsModel` to round-trip the new field

**Files:**
- Modify: `lib/features/settings/data/models/settings_model.dart`
- Modify: `test/features/settings/settings_cubit_test.dart`

- [ ] **Step 1: Write the failing test**

In `test/features/settings/settings_cubit_test.dart`, add this test inside `void main() { ... }`, after the existing `toMap / fromMap round-trips new fields` test:

```dart
  test('toMap / fromMap round-trips isPrayerStripPinned', () {
    final model = SettingsModel(
      isDarkMode: true,
      isFormat12Hours: false,
      isArabic: true,
      playbackSpeed: 1.0,
      defaultReciter: Reciter.alafasy,
      isPrayerStripPinned: true,
    );
    final round = SettingsModel.fromMap(model.toMap());
    expect(round.isPrayerStripPinned, true);
  });

  test('fromMap defaults isPrayerStripPinned to false when missing', () {
    final round = SettingsModel.fromMap({
      'isArabic': true,
      'isDarkMode': true,
      'isFormat12Hours': true,
      'playbackSpeed': 1.0,
      'defaultReciter': 'alafasy',
    });
    expect(round.isPrayerStripPinned, false);
  });
```

- [ ] **Step 2: Run the new tests to verify they fail**

Run: `flutter test test/features/settings/settings_cubit_test.dart --plain-name "isPrayerStripPinned"`
Expected: 2 failing tests — `SettingsModel` constructor doesn't accept the new field, or `toMap`/`fromMap` doesn't handle it.

- [ ] **Step 3: Update the model**

Replace `lib/features/settings/data/models/settings_model.dart` with:

```dart
import 'package:quran_app/features/quran_playback/domain/entities/reciter.dart';
import 'package:quran_app/features/settings/domain/entities/settings.dart';

class SettingsModel extends Settings {
  const SettingsModel({
    required super.isDarkMode,
    required super.isFormat12Hours,
    required super.isArabic,
    super.playbackSpeed,
    super.defaultReciter,
    super.isPrayerStripPinned,
  });

  @override
  SettingsModel copyWith({
    bool? isDarkMode,
    bool? isFormat12Hours,
    bool? isArabic,
    double? playbackSpeed,
    Reciter? defaultReciter,
    bool? isPrayerStripPinned,
  }) {
    return SettingsModel(
      isArabic: isArabic ?? this.isArabic,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      isFormat12Hours: isFormat12Hours ?? this.isFormat12Hours,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      defaultReciter: defaultReciter ?? this.defaultReciter,
      isPrayerStripPinned: isPrayerStripPinned ?? this.isPrayerStripPinned,
    );
  }

  factory SettingsModel.fromMap(Map<String, dynamic> map) {
    return SettingsModel(
      isArabic: map['isArabic'] ?? true,
      isDarkMode: map['isDarkMode'] ?? true,
      isFormat12Hours: map['isFormat12Hours'] ?? true,
      playbackSpeed: (map['playbackSpeed'] as num?)?.toDouble() ?? 1.0,
      defaultReciter: Reciter.values.firstWhere(
        (r) => r.name == (map['defaultReciter'] as String?),
        orElse: () => Reciter.alafasy,
      ),
      isPrayerStripPinned: map['isPrayerStripPinned'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'isArabic': isArabic,
      'isDarkMode': isDarkMode,
      'isFormat12Hours': isFormat12Hours,
      'playbackSpeed': playbackSpeed,
      'defaultReciter': defaultReciter.name,
      'isPrayerStripPinned': isPrayerStripPinned,
    };
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/features/settings/settings_cubit_test.dart`
Expected: all settings tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/settings/data/models/settings_model.dart test/features/settings/settings_cubit_test.dart
git commit -m "feat(settings): round-trip isPrayerStripPinned in SettingsModel"
```

---

### Task 3: Add `updatePrayerStripPinned` to `SettingsCubit`

**Files:**
- Modify: `lib/features/settings/presentation/cubit/settings_cubit.dart`
- Modify: `test/features/settings/settings_cubit_test.dart`

- [ ] **Step 1: Write the failing test**

Add this `blocTest` inside `void main() { ... }` in `test/features/settings/settings_cubit_test.dart`:

```dart
  blocTest<SettingsCubit, SettingsState>(
    'updatePrayerStripPinned(true) emits new state with flag true',
    build: () => SettingsCubit(),
    act: (c) => c.updatePrayerStripPinned(true),
    expect: () => [
      isA<SettingsState>().having(
        (s) => s.settingsModel.isPrayerStripPinned,
        'isPrayerStripPinned',
        true,
      ),
    ],
  );

  blocTest<SettingsCubit, SettingsState>(
    'updatePrayerStripPinned(false) emits new state with flag false',
    build: () => SettingsCubit()..updatePrayerStripPinned(true),
    act: (c) => c.updatePrayerStripPinned(false),
    expect: () => [
      isA<SettingsState>().having(
        (s) => s.settingsModel.isPrayerStripPinned,
        'isPrayerStripPinned',
        false,
      ),
    ],
  );
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/settings/settings_cubit_test.dart --plain-name "updatePrayerStripPinned"`
Expected: 2 failing tests — method `updatePrayerStripPinned` is undefined.

- [ ] **Step 3: Add the method**

In `lib/features/settings/presentation/cubit/settings_cubit.dart`, add this method inside `SettingsCubit` class, after `updateDefaultReciter`:

```dart
  void updatePrayerStripPinned(bool value) {
    emit(
      SettingsState(state.settingsModel.copyWith(isPrayerStripPinned: value)),
    );
  }
```

Note: side effects (calling the use cases) are wired separately in Task 19 from `home_page.dart`. Keeping the cubit method side-effect-free here keeps the unit test trivial.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/features/settings/settings_cubit_test.dart`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/settings/presentation/cubit/settings_cubit.dart test/features/settings/settings_cubit_test.dart
git commit -m "feat(settings): add updatePrayerStripPinned to SettingsCubit"
```

---

## Phase A2 — New failure types

### Task 4: Add notification-specific failure classes

**Files:**
- Modify: `lib/core/errors/failure.dart`

These are simple data classes; no separate test file needed — they get exercised by the repository tests later. Just verify they compile.

- [ ] **Step 1: Append the new failures**

At the end of `lib/core/errors/failure.dart` (after `CacheFailure`), append:

```dart
class PermissionDeniedFailure extends Failure {
  const PermissionDeniedFailure(super.message);
}

class NoPrayerDataFailure extends Failure {
  const NoPrayerDataFailure(super.message);
}

class PlatformNotSupportedFailure extends Failure {
  const PlatformNotSupportedFailure(super.message);
}

class UnknownNotificationFailure extends Failure {
  const UnknownNotificationFailure(super.message);
}
```

- [ ] **Step 2: Verify the analyzer is clean**

Run: `flutter analyze lib/core/errors`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/core/errors/failure.dart
git commit -m "feat(errors): add notification-related failure types"
```

---

## Phase A3 — Domain entities

### Task 5: Create `PrayerCell` entity

**Files:**
- Create: `lib/features/notifications/domain/entities/prayer_cell.dart`
- Create: `test/features/notifications/domain/entities/prayer_cell_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/features/notifications/domain/entities/prayer_cell_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_cell.dart';

void main() {
  test('equal cells with same label and time are equal', () {
    const a = PrayerCell(label: 'الفجر', timeFormatted: '٤:١٥');
    const b = PrayerCell(label: 'الفجر', timeFormatted: '٤:١٥');
    expect(a, b);
  });

  test('cells with different labels are not equal', () {
    const a = PrayerCell(label: 'الفجر', timeFormatted: '٤:١٥');
    const b = PrayerCell(label: 'الظهر', timeFormatted: '٤:١٥');
    expect(a == b, false);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/notifications/domain/entities/prayer_cell_test.dart`
Expected: FAIL — `prayer_cell.dart` doesn't exist.

- [ ] **Step 3: Create the entity**

Create `lib/features/notifications/domain/entities/prayer_cell.dart`:

```dart
import 'package:equatable/equatable.dart';

class PrayerCell extends Equatable {
  final String label;
  final String timeFormatted;

  const PrayerCell({required this.label, required this.timeFormatted});

  @override
  List<Object?> get props => [label, timeFormatted];
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/notifications/domain/entities/prayer_cell_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/notifications/domain/entities/prayer_cell.dart test/features/notifications/domain/entities/prayer_cell_test.dart
git commit -m "feat(notifications): add PrayerCell entity"
```

---

### Task 6: Create `PrayerStripState` entity

**Files:**
- Create: `lib/features/notifications/domain/entities/prayer_strip_state.dart`
- Create: `test/features/notifications/domain/entities/prayer_strip_state_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/features/notifications/domain/entities/prayer_strip_state_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_cell.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_strip_state.dart';

void main() {
  final fajr = const PrayerCell(label: 'Fajr', timeFormatted: '4:15');
  final sunrise = const PrayerCell(label: 'Sunrise', timeFormatted: '5:07');

  test('equality holds for identical states', () {
    final a = PrayerStripState(
      cells: [fajr, sunrise],
      nextPrayerIndex: 0,
      hijriDateLabel: '5 Dhul-Hijjah',
      localeCode: 'en',
      isFriday: false,
    );
    final b = PrayerStripState(
      cells: [fajr, sunrise],
      nextPrayerIndex: 0,
      hijriDateLabel: '5 Dhul-Hijjah',
      localeCode: 'en',
      isFriday: false,
    );
    expect(a, b);
  });

  test('different nextPrayerIndex breaks equality', () {
    final a = PrayerStripState(
      cells: [fajr, sunrise],
      nextPrayerIndex: 0,
      hijriDateLabel: '5 Dhul-Hijjah',
      localeCode: 'en',
      isFriday: false,
    );
    final b = a.copyWith(nextPrayerIndex: 1);
    expect(a == b, false);
  });

  test('toJson produces a map with all fields and is deserializable by fromJson', () {
    final s = PrayerStripState(
      cells: [fajr, sunrise],
      nextPrayerIndex: 1,
      hijriDateLabel: '5 ذو الحجة',
      localeCode: 'ar',
      isFriday: true,
    );
    final round = PrayerStripState.fromJson(s.toJson());
    expect(round, s);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/notifications/domain/entities/prayer_strip_state_test.dart`
Expected: FAIL — file does not exist.

- [ ] **Step 3: Create the entity**

Create `lib/features/notifications/domain/entities/prayer_strip_state.dart`:

```dart
import 'package:equatable/equatable.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_cell.dart';

class PrayerStripState extends Equatable {
  final List<PrayerCell> cells;
  final int nextPrayerIndex;
  final String hijriDateLabel;
  final String localeCode;
  final bool isFriday;

  const PrayerStripState({
    required this.cells,
    required this.nextPrayerIndex,
    required this.hijriDateLabel,
    required this.localeCode,
    required this.isFriday,
  });

  PrayerStripState copyWith({
    List<PrayerCell>? cells,
    int? nextPrayerIndex,
    String? hijriDateLabel,
    String? localeCode,
    bool? isFriday,
  }) {
    return PrayerStripState(
      cells: cells ?? this.cells,
      nextPrayerIndex: nextPrayerIndex ?? this.nextPrayerIndex,
      hijriDateLabel: hijriDateLabel ?? this.hijriDateLabel,
      localeCode: localeCode ?? this.localeCode,
      isFriday: isFriday ?? this.isFriday,
    );
  }

  Map<String, Object> toJson() => {
        'cells': cells
            .map((c) => {'label': c.label, 'time': c.timeFormatted})
            .toList(),
        'nextPrayerIndex': nextPrayerIndex,
        'hijriDateLabel': hijriDateLabel,
        'localeCode': localeCode,
        'isFriday': isFriday,
      };

  factory PrayerStripState.fromJson(Map<String, Object?> json) {
    final rawCells = (json['cells'] as List).cast<Map<String, Object?>>();
    return PrayerStripState(
      cells: rawCells
          .map((m) => PrayerCell(
                label: m['label'] as String,
                timeFormatted: m['time'] as String,
              ))
          .toList(),
      nextPrayerIndex: json['nextPrayerIndex'] as int,
      hijriDateLabel: json['hijriDateLabel'] as String,
      localeCode: json['localeCode'] as String,
      isFriday: json['isFriday'] as bool,
    );
  }

  @override
  List<Object?> get props =>
      [cells, nextPrayerIndex, hijriDateLabel, localeCode, isFriday];
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/notifications/domain/entities/prayer_strip_state_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/notifications/domain/entities/prayer_strip_state.dart test/features/notifications/domain/entities/prayer_strip_state_test.dart
git commit -m "feat(notifications): add PrayerStripState entity with JSON round-trip"
```

---

### Task 7: Create `AdhanAudioSettings` entity

**Files:**
- Create: `lib/features/notifications/domain/entities/adhan_audio_settings.dart`
- Create: `test/features/notifications/domain/entities/adhan_audio_settings_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/features/notifications/domain/entities/adhan_audio_settings_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/features/notifications/domain/entities/adhan_audio_settings.dart';

void main() {
  test('default settings expose fajr_adhan for fajr, normal_adhan elsewhere', () {
    final s = AdhanAudioSettings.defaults();
    expect(s.clipAssetByPrayer[PrayerName.fajr], 'fajr_adhan');
    expect(s.clipAssetByPrayer[PrayerName.dhuhr], 'normal_adhan');
    expect(s.volume, 1.0);
  });

  test('equality holds for identical settings', () {
    final a = AdhanAudioSettings.defaults();
    final b = AdhanAudioSettings.defaults();
    expect(a, b);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/notifications/domain/entities/adhan_audio_settings_test.dart`
Expected: FAIL — file missing.

- [ ] **Step 3: Create the entity**

Create `lib/features/notifications/domain/entities/adhan_audio_settings.dart`:

```dart
import 'package:equatable/equatable.dart';
import 'package:quran_app/core/constants/prayer_name.dart';

class AdhanAudioSettings extends Equatable {
  final Map<PrayerName, String> clipAssetByPrayer;
  final double volume;

  const AdhanAudioSettings({
    required this.clipAssetByPrayer,
    this.volume = 1.0,
  });

  factory AdhanAudioSettings.defaults() => const AdhanAudioSettings(
        clipAssetByPrayer: {
          PrayerName.fajr: 'fajr_adhan',
          PrayerName.sunrise: 'normal_adhan',
          PrayerName.dhuhr: 'normal_adhan',
          PrayerName.asr: 'normal_adhan',
          PrayerName.maghrib: 'normal_adhan',
          PrayerName.isha: 'normal_adhan',
        },
      );

  @override
  List<Object?> get props => [clipAssetByPrayer, volume];
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/notifications/domain/entities/adhan_audio_settings_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/notifications/domain/entities/adhan_audio_settings.dart test/features/notifications/domain/entities/adhan_audio_settings_test.dart
git commit -m "feat(notifications): add AdhanAudioSettings entity with defaults"
```

---

## Phase A4 — Numeral helper (pure Dart)

### Task 8: Extract pure-Dart Arabic-Indic numeral converter

**Files:**
- Create: `lib/core/helper functions/numeral_helpers.dart`
- Create: `test/core/helper functions/numeral_helpers_test.dart`

Existing `lib/core/helper functions/locale_helpers.dart` does this conversion but requires `BuildContext`. The state builder runs in domain code with no context, so we need a context-free version. Add a new file; do **not** modify `locale_helpers.dart` (which is presentation-bound and used widely).

- [ ] **Step 1: Write the failing test**

Create `test/core/helper functions/numeral_helpers_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/helper%20functions/numeral_helpers.dart';

void main() {
  group('toIndicNumerals', () {
    test('converts ASCII digits to Arabic-Indic for ar locale', () {
      expect('4:15'.toIndicNumerals('ar'), '٤:١٥');
      expect('12:52'.toIndicNumerals('ar'), '١٢:٥٢');
      expect('0'.toIndicNumerals('ar'), '٠');
    });

    test('returns input unchanged for non-Arabic locales', () {
      expect('4:15'.toIndicNumerals('en'), '4:15');
      expect('12:52'.toIndicNumerals('fr'), '12:52');
    });

    test('returns input unchanged for empty input', () {
      expect(''.toIndicNumerals('ar'), '');
    });

    test('preserves non-digit characters', () {
      expect('Fajr 4:15 AM'.toIndicNumerals('ar'), 'Fajr ٤:١٥ AM');
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test "test/core/helper functions/numeral_helpers_test.dart"`
Expected: FAIL — file does not exist.

- [ ] **Step 3: Create the helper**

Create `lib/core/helper functions/numeral_helpers.dart`:

```dart
extension NumeralExtension on String {
  /// Pure-Dart Arabic-Indic numeral conversion.
  /// Returns `this` unchanged unless [localeCode] is `'ar'`.
  /// Used by domain-layer code that has no `BuildContext`.
  String toIndicNumerals(String localeCode) {
    if (localeCode != 'ar') return this;
    const ascii = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const indic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    var out = this;
    for (var i = 0; i < ascii.length; i++) {
      out = out.replaceAll(ascii[i], indic[i]);
    }
    return out;
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test "test/core/helper functions/numeral_helpers_test.dart"`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add "lib/core/helper functions/numeral_helpers.dart" "test/core/helper functions/numeral_helpers_test.dart"
git commit -m "feat(core): add pure-Dart Arabic-Indic numeral helper"
```

---

## Phase A5 — State builder

### Task 9: Create `PrayerStripStateBuilder`

**Files:**
- Create: `lib/features/notifications/domain/builders/prayer_strip_state_builder.dart`
- Create: `test/features/notifications/domain/builders/prayer_strip_state_builder_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/features/notifications/domain/builders/prayer_strip_state_builder_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';
import 'package:quran_app/features/notifications/domain/builders/prayer_strip_state_builder.dart';

void main() {
  // Friday May 22 2026 — used for the isFriday test.
  final pt = PrayerTimes(
    key: '22-05-2026',
    timings: {
      PrayerName.fajr: '04:15',
      PrayerName.sunrise: '05:07',
      PrayerName.dhuhr: '12:52',
      PrayerName.asr: '16:28',
      PrayerName.maghrib: '19:46',
      PrayerName.isha: '21:16',
    },
    date: Date(
      month: 'ذو الحجة',
      weekDay: 'الجمعة',
      day: '5',
      year: '1447',
      enMonth: 'Dhul-Hijjah',
      enWeekDay: 'Friday',
      gregorianDate: '22-05-2026',
    ),
  );

  group('PrayerStripStateBuilder.build', () {
    test('produces 6 cells in Fajr→Isha order', () {
      final s = PrayerStripStateBuilder.build(
        prayerTimes: pt,
        nextPrayer: PrayerName.fajr,
        localeCode: 'en',
        isFriday: false,
      );
      expect(s.cells.length, 6);
      expect(s.cells[0].label, 'Fajr');
      expect(s.cells[5].label, 'Isha');
    });

    test('Arabic locale uses Arabic-Indic numerals in times', () {
      final s = PrayerStripStateBuilder.build(
        prayerTimes: pt,
        nextPrayer: PrayerName.fajr,
        localeCode: 'ar',
        isFriday: false,
      );
      expect(s.cells[0].timeFormatted, '٠٤:١٥');
    });

    test('English locale leaves times as ASCII', () {
      final s = PrayerStripStateBuilder.build(
        prayerTimes: pt,
        nextPrayer: PrayerName.fajr,
        localeCode: 'en',
        isFriday: false,
      );
      expect(s.cells[0].timeFormatted, '04:15');
    });

    test('isFriday=true swaps Dhuhr label to Jumu\'ah / الجمعة', () {
      final ar = PrayerStripStateBuilder.build(
        prayerTimes: pt,
        nextPrayer: PrayerName.dhuhr,
        localeCode: 'ar',
        isFriday: true,
      );
      expect(ar.cells[2].label, 'الجمعة');

      final en = PrayerStripStateBuilder.build(
        prayerTimes: pt,
        nextPrayer: PrayerName.dhuhr,
        localeCode: 'en',
        isFriday: true,
      );
      expect(en.cells[2].label, "Jumu'ah");
    });

    test('isFriday=false keeps Dhuhr label as Dhuhr / الظهر', () {
      final ar = PrayerStripStateBuilder.build(
        prayerTimes: pt,
        nextPrayer: PrayerName.dhuhr,
        localeCode: 'ar',
        isFriday: false,
      );
      expect(ar.cells[2].label, 'الظهر');
    });

    test('nextPrayerIndex matches nextPrayer position in fixed order', () {
      final s = PrayerStripStateBuilder.build(
        prayerTimes: pt,
        nextPrayer: PrayerName.maghrib,
        localeCode: 'en',
        isFriday: false,
      );
      expect(s.nextPrayerIndex, 4);
    });

    test('hijriDateLabel uses Arabic month name for ar locale', () {
      final s = PrayerStripStateBuilder.build(
        prayerTimes: pt,
        nextPrayer: PrayerName.fajr,
        localeCode: 'ar',
        isFriday: false,
      );
      expect(s.hijriDateLabel, '٥ ذو الحجة');
    });

    test('hijriDateLabel uses English month name for en locale', () {
      final s = PrayerStripStateBuilder.build(
        prayerTimes: pt,
        nextPrayer: PrayerName.fajr,
        localeCode: 'en',
        isFriday: false,
      );
      expect(s.hijriDateLabel, '5 Dhul-Hijjah');
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/notifications/domain/builders/prayer_strip_state_builder_test.dart`
Expected: FAIL — `prayer_strip_state_builder.dart` does not exist.

- [ ] **Step 3: Create the builder**

Create `lib/features/notifications/domain/builders/prayer_strip_state_builder.dart`:

```dart
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/core/helper%20functions/numeral_helpers.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_cell.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_strip_state.dart';

/// Fixed Fajr→Isha render order. Independent of localization.
const _renderOrder = <PrayerName>[
  PrayerName.fajr,
  PrayerName.sunrise,
  PrayerName.dhuhr,
  PrayerName.asr,
  PrayerName.maghrib,
  PrayerName.isha,
];

const _labelsAr = <PrayerName, String>{
  PrayerName.fajr: 'الفجر',
  PrayerName.sunrise: 'الشروق',
  PrayerName.dhuhr: 'الظهر',
  PrayerName.asr: 'العصر',
  PrayerName.maghrib: 'المغرب',
  PrayerName.isha: 'العشاء',
};

const _labelsEn = <PrayerName, String>{
  PrayerName.fajr: 'Fajr',
  PrayerName.sunrise: 'Sunrise',
  PrayerName.dhuhr: 'Dhuhr',
  PrayerName.asr: 'Asr',
  PrayerName.maghrib: 'Maghrib',
  PrayerName.isha: 'Isha',
};

const _jumuahLabelAr = 'الجمعة';
const _jumuahLabelEn = "Jumu'ah";

/// Builds a [PrayerStripState] snapshot from today's prayer times.
///
/// Pure Dart — no Flutter dependency. Time strings come from the prayer-times
/// service as `HH:mm` 24-hour strings; the builder applies Arabic-Indic
/// numeral conversion for `localeCode == 'ar'` but does **not** apply the
/// user's 12-hour preference. (The strip always shows 24-hour times, matching
/// the reference design.)
class PrayerStripStateBuilder {
  const PrayerStripStateBuilder._();

  static PrayerStripState build({
    required PrayerTimes prayerTimes,
    required PrayerName nextPrayer,
    required String localeCode,
    required bool isFriday,
  }) {
    final labels = localeCode == 'ar' ? _labelsAr : _labelsEn;
    final jumuah = localeCode == 'ar' ? _jumuahLabelAr : _jumuahLabelEn;

    final cells = _renderOrder.map((p) {
      final rawLabel = labels[p]!;
      final label = (isFriday && p == PrayerName.dhuhr) ? jumuah : rawLabel;
      final time = (prayerTimes.timings[p] ?? '').toIndicNumerals(localeCode);
      return PrayerCell(label: label, timeFormatted: time);
    }).toList();

    final nextIndex = _renderOrder.indexOf(nextPrayer);

    final monthName =
        localeCode == 'ar' ? prayerTimes.date.month : prayerTimes.date.enMonth;
    final dayPart = prayerTimes.date.day.toIndicNumerals(localeCode);
    final hijriLabel = '$dayPart $monthName';

    return PrayerStripState(
      cells: cells,
      nextPrayerIndex: nextIndex < 0 ? 0 : nextIndex,
      hijriDateLabel: hijriLabel,
      localeCode: localeCode,
      isFriday: isFriday,
    );
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/notifications/domain/builders/prayer_strip_state_builder_test.dart`
Expected: PASS (8 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/notifications/domain/builders/prayer_strip_state_builder.dart test/features/notifications/domain/builders/prayer_strip_state_builder_test.dart
git commit -m "feat(notifications): add PrayerStripStateBuilder (localized, Friday-aware)"
```

---

## Phase A6 — Repository contract

### Task 10: Define `NotificationsRepository` abstract contract

**Files:**
- Create: `lib/features/notifications/domain/repositories/notifications_repository.dart`

No test for an abstract class; coverage comes via use case + impl tests later.

- [ ] **Step 1: Create the contract**

Create `lib/features/notifications/domain/repositories/notifications_repository.dart`:

```dart
import 'package:dartz/dartz.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';
import 'package:quran_app/features/notifications/domain/entities/adhan_audio_settings.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_strip_state.dart';

/// Single facade for all notification work — pinned strip + adhan playback.
///
/// All methods return `Either<Failure, Unit>`. A `PlatformNotSupportedFailure`
/// is returned for capabilities not yet implemented on the current platform
/// (notably the pinned strip while only Plan A is shipped). Callers should
/// treat that failure as "feature unavailable on this device" — not as an
/// error to surface to the user, unless explicitly initiated by user action
/// such as toggling the Settings switch.
abstract class NotificationsRepository {
  /// Shows the pinned prayer-times strip with the given snapshot.
  Future<Either<Failure, Unit>> enableStrip(PrayerStripState state);

  /// Hides the pinned strip. Idempotent — safe to call when nothing is shown.
  Future<Either<Failure, Unit>> disableStrip();

  /// Re-renders the pinned strip with a new snapshot (e.g., locale change,
  /// midnight rollover, prayer-time crossing). No-op if the strip is hidden.
  Future<Either<Failure, Unit>> refreshStrip(PrayerStripState state);

  /// Schedules today's per-prayer adhan notifications. Replaces any
  /// previously scheduled set.
  Future<Either<Failure, Unit>> scheduleDailyAdhans({
    required PrayerTimes prayerTimes,
    required AdhanAudioSettings audio,
  });

  /// Cancels all scheduled adhan notifications.
  Future<Either<Failure, Unit>> cancelAllAdhans();
}
```

- [ ] **Step 2: Analyzer check**

Run: `flutter analyze lib/features/notifications`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/features/notifications/domain/repositories/notifications_repository.dart
git commit -m "feat(notifications): add NotificationsRepository contract"
```

---

## Phase A7 — Use cases

Each use case is a thin wrapper that follows the existing `UseCase<T, P>` pattern from `lib/core/usecases/usecase.dart`.

### Task 11: `EnablePrayerStrip` use case

**Files:**
- Create: `lib/features/notifications/domain/usecases/enable_prayer_strip.dart`
- Create: `test/features/notifications/domain/usecases/enable_prayer_strip_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/features/notifications/domain/usecases/enable_prayer_strip_test.dart`:

```dart
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_cell.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_strip_state.dart';
import 'package:quran_app/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:quran_app/features/notifications/domain/usecases/enable_prayer_strip.dart';

class _MockRepo extends Mock implements NotificationsRepository {}

void main() {
  late _MockRepo repo;
  late EnablePrayerStrip useCase;

  final state = PrayerStripState(
    cells: const [PrayerCell(label: 'Fajr', timeFormatted: '4:15')],
    nextPrayerIndex: 0,
    hijriDateLabel: '5 Dhul-Hijjah',
    localeCode: 'en',
    isFriday: false,
  );

  setUp(() {
    repo = _MockRepo();
    useCase = EnablePrayerStrip(repository: repo);
    registerFallbackValue(state);
  });

  test('delegates to repository.enableStrip with given state', () async {
    when(() => repo.enableStrip(any()))
        .thenAnswer((_) async => const Right(unit));
    final result =
        await useCase.call(EnablePrayerStripParams(state: state));
    expect(result.isRight(), true);
    verify(() => repo.enableStrip(state)).called(1);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/notifications/domain/usecases/enable_prayer_strip_test.dart`
Expected: FAIL — use case file does not exist.

- [ ] **Step 3: Create the use case**

Create `lib/features/notifications/domain/usecases/enable_prayer_strip.dart`:

```dart
import 'package:dartz/dartz.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/core/usecases/usecase.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_strip_state.dart';
import 'package:quran_app/features/notifications/domain/repositories/notifications_repository.dart';

class EnablePrayerStripParams {
  final PrayerStripState state;
  const EnablePrayerStripParams({required this.state});
}

class EnablePrayerStrip
    extends UseCase<Either<Failure, Unit>, EnablePrayerStripParams> {
  final NotificationsRepository repository;
  EnablePrayerStrip({required this.repository});

  @override
  Future<Either<Failure, Unit>> call(EnablePrayerStripParams params) =>
      repository.enableStrip(params.state);
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/notifications/domain/usecases/enable_prayer_strip_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/notifications/domain/usecases/enable_prayer_strip.dart test/features/notifications/domain/usecases/enable_prayer_strip_test.dart
git commit -m "feat(notifications): add EnablePrayerStrip use case"
```

---

### Task 12: `DisablePrayerStrip` use case

**Files:**
- Create: `lib/features/notifications/domain/usecases/disable_prayer_strip.dart`
- Create: `test/features/notifications/domain/usecases/disable_prayer_strip_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/features/notifications/domain/usecases/disable_prayer_strip_test.dart`:

```dart
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/core/usecases/usecase.dart';
import 'package:quran_app/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:quran_app/features/notifications/domain/usecases/disable_prayer_strip.dart';

class _MockRepo extends Mock implements NotificationsRepository {}

void main() {
  late _MockRepo repo;
  late DisablePrayerStrip useCase;

  setUp(() {
    repo = _MockRepo();
    useCase = DisablePrayerStrip(repository: repo);
  });

  test('delegates to repository.disableStrip', () async {
    when(() => repo.disableStrip()).thenAnswer((_) async => const Right(unit));
    final result = await useCase.call(NoParams());
    expect(result.isRight(), true);
    verify(() => repo.disableStrip()).called(1);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/notifications/domain/usecases/disable_prayer_strip_test.dart`
Expected: FAIL.

- [ ] **Step 3: Create the use case**

Create `lib/features/notifications/domain/usecases/disable_prayer_strip.dart`:

```dart
import 'package:dartz/dartz.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/core/usecases/usecase.dart';
import 'package:quran_app/features/notifications/domain/repositories/notifications_repository.dart';

class DisablePrayerStrip extends UseCase<Either<Failure, Unit>, NoParams> {
  final NotificationsRepository repository;
  DisablePrayerStrip({required this.repository});

  @override
  Future<Either<Failure, Unit>> call(NoParams params) =>
      repository.disableStrip();
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/notifications/domain/usecases/disable_prayer_strip_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/notifications/domain/usecases/disable_prayer_strip.dart test/features/notifications/domain/usecases/disable_prayer_strip_test.dart
git commit -m "feat(notifications): add DisablePrayerStrip use case"
```

---

### Task 13: `RefreshPrayerStrip` use case

**Files:**
- Create: `lib/features/notifications/domain/usecases/refresh_prayer_strip.dart`
- Create: `test/features/notifications/domain/usecases/refresh_prayer_strip_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/features/notifications/domain/usecases/refresh_prayer_strip_test.dart`:

```dart
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_cell.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_strip_state.dart';
import 'package:quran_app/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:quran_app/features/notifications/domain/usecases/refresh_prayer_strip.dart';

class _MockRepo extends Mock implements NotificationsRepository {}

void main() {
  late _MockRepo repo;
  late RefreshPrayerStrip useCase;

  final state = PrayerStripState(
    cells: const [PrayerCell(label: 'Fajr', timeFormatted: '4:15')],
    nextPrayerIndex: 0,
    hijriDateLabel: '5 Dhul-Hijjah',
    localeCode: 'en',
    isFriday: false,
  );

  setUp(() {
    repo = _MockRepo();
    useCase = RefreshPrayerStrip(repository: repo);
    registerFallbackValue(state);
  });

  test('delegates to repository.refreshStrip with given state', () async {
    when(() => repo.refreshStrip(any()))
        .thenAnswer((_) async => const Right(unit));
    final result =
        await useCase.call(RefreshPrayerStripParams(state: state));
    expect(result.isRight(), true);
    verify(() => repo.refreshStrip(state)).called(1);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/notifications/domain/usecases/refresh_prayer_strip_test.dart`
Expected: FAIL.

- [ ] **Step 3: Create the use case**

Create `lib/features/notifications/domain/usecases/refresh_prayer_strip.dart`:

```dart
import 'package:dartz/dartz.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/core/usecases/usecase.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_strip_state.dart';
import 'package:quran_app/features/notifications/domain/repositories/notifications_repository.dart';

class RefreshPrayerStripParams {
  final PrayerStripState state;
  const RefreshPrayerStripParams({required this.state});
}

class RefreshPrayerStrip
    extends UseCase<Either<Failure, Unit>, RefreshPrayerStripParams> {
  final NotificationsRepository repository;
  RefreshPrayerStrip({required this.repository});

  @override
  Future<Either<Failure, Unit>> call(RefreshPrayerStripParams params) =>
      repository.refreshStrip(params.state);
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/notifications/domain/usecases/refresh_prayer_strip_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/notifications/domain/usecases/refresh_prayer_strip.dart test/features/notifications/domain/usecases/refresh_prayer_strip_test.dart
git commit -m "feat(notifications): add RefreshPrayerStrip use case"
```

---

### Task 14: `SyncDailyAdhans` use case

**Files:**
- Create: `lib/features/notifications/domain/usecases/sync_daily_adhans.dart`
- Create: `test/features/notifications/domain/usecases/sync_daily_adhans_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/features/notifications/domain/usecases/sync_daily_adhans_test.dart`:

```dart
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';
import 'package:quran_app/features/notifications/domain/entities/adhan_audio_settings.dart';
import 'package:quran_app/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:quran_app/features/notifications/domain/usecases/sync_daily_adhans.dart';

class _MockRepo extends Mock implements NotificationsRepository {}

void main() {
  late _MockRepo repo;
  late SyncDailyAdhans useCase;

  final pt = PrayerTimes(
    key: '22-05-2026',
    timings: {
      PrayerName.fajr: '04:15',
      PrayerName.sunrise: '05:07',
      PrayerName.dhuhr: '12:52',
      PrayerName.asr: '16:28',
      PrayerName.maghrib: '19:46',
      PrayerName.isha: '21:16',
    },
    date: Date(
      month: 'ذو الحجة',
      weekDay: 'الجمعة',
      day: '5',
      year: '1447',
      enMonth: 'Dhul-Hijjah',
      enWeekDay: 'Friday',
      gregorianDate: '22-05-2026',
    ),
  );

  setUp(() {
    repo = _MockRepo();
    useCase = SyncDailyAdhans(repository: repo);
    registerFallbackValue(pt);
    registerFallbackValue(AdhanAudioSettings.defaults());
  });

  test('delegates to repo.scheduleDailyAdhans with defaults when no audio override',
      () async {
    when(() => repo.scheduleDailyAdhans(
          prayerTimes: any(named: 'prayerTimes'),
          audio: any(named: 'audio'),
        )).thenAnswer((_) async => const Right(unit));

    final result =
        await useCase.call(SyncDailyAdhansParams(prayerTimes: pt));

    expect(result.isRight(), true);
    verify(() => repo.scheduleDailyAdhans(
          prayerTimes: pt,
          audio: AdhanAudioSettings.defaults(),
        )).called(1);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/notifications/domain/usecases/sync_daily_adhans_test.dart`
Expected: FAIL.

- [ ] **Step 3: Create the use case**

Create `lib/features/notifications/domain/usecases/sync_daily_adhans.dart`:

```dart
import 'package:dartz/dartz.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/core/usecases/usecase.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';
import 'package:quran_app/features/notifications/domain/entities/adhan_audio_settings.dart';
import 'package:quran_app/features/notifications/domain/repositories/notifications_repository.dart';

class SyncDailyAdhansParams {
  final PrayerTimes prayerTimes;
  final AdhanAudioSettings? audio;
  const SyncDailyAdhansParams({required this.prayerTimes, this.audio});
}

class SyncDailyAdhans
    extends UseCase<Either<Failure, Unit>, SyncDailyAdhansParams> {
  final NotificationsRepository repository;
  SyncDailyAdhans({required this.repository});

  @override
  Future<Either<Failure, Unit>> call(SyncDailyAdhansParams params) =>
      repository.scheduleDailyAdhans(
        prayerTimes: params.prayerTimes,
        audio: params.audio ?? AdhanAudioSettings.defaults(),
      );
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/notifications/domain/usecases/sync_daily_adhans_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/notifications/domain/usecases/sync_daily_adhans.dart test/features/notifications/domain/usecases/sync_daily_adhans_test.dart
git commit -m "feat(notifications): add SyncDailyAdhans use case"
```

---

## Phase A8 — Native data source (MethodChannel facade)

### Task 15: Create `NotificationsNativeDataSource`

**Files:**
- Create: `lib/features/notifications/data/datasources/notifications_native_data_source.dart`
- Create: `test/features/notifications/data/datasources/notifications_native_data_source_test.dart`

The data source is two things: a thin abstract surface (`NotificationsNativeDataSource`) and a concrete `MethodChannel`-backed impl (`NotificationsNativeDataSourceImpl`). In Plan A the channel has no native handler — every call throws `MissingPluginException`. The impl catches that and returns a `Failure` rather than letting it bubble.

- [ ] **Step 1: Write the failing test**

Create `test/features/notifications/data/datasources/notifications_native_data_source_test.dart`:

```dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/notifications/data/datasources/notifications_native_data_source.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_cell.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_strip_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(NotificationsNativeDataSourceImpl.channelName);
  late List<MethodCall> calls;
  late NotificationsNativeDataSourceImpl ds;

  final state = PrayerStripState(
    cells: const [PrayerCell(label: 'Fajr', timeFormatted: '4:15')],
    nextPrayerIndex: 0,
    hijriDateLabel: '5 Dhul-Hijjah',
    localeCode: 'en',
    isFriday: false,
  );

  setUp(() {
    calls = [];
    ds = NotificationsNativeDataSourceImpl();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('enableStrip invokes the channel with the right method + state JSON',
      () async {
    await ds.enableStrip(state);
    expect(calls.length, 1);
    expect(calls.single.method, 'enableStrip');
    final args = calls.single.arguments as Map;
    expect(args['nextPrayerIndex'], 0);
    expect(args['localeCode'], 'en');
  });

  test('disableStrip invokes the channel', () async {
    await ds.disableStrip();
    expect(calls.single.method, 'disableStrip');
  });

  test('refreshStrip invokes the channel', () async {
    await ds.refreshStrip(state);
    expect(calls.single.method, 'refreshStrip');
  });

  test('scheduleDailyAdhans invokes the channel with timings + audio map',
      () async {
    await ds.scheduleDailyAdhans(
      timingsByPrayer: const {'fajr': '04:15', 'isha': '21:16'},
      clipAssetByPrayer: const {'fajr': 'fajr_adhan', 'isha': 'normal_adhan'},
      volume: 1.0,
    );
    expect(calls.single.method, 'scheduleDailyAdhans');
    final args = calls.single.arguments as Map;
    expect(args['timings'], {'fajr': '04:15', 'isha': '21:16'});
    expect(args['volume'], 1.0);
  });

  test('cancelAllAdhans invokes the channel', () async {
    await ds.cancelAllAdhans();
    expect(calls.single.method, 'cancelAllAdhans');
  });

  test('throws PlatformNotImplementedException when native side is missing',
      () async {
    // Removing the mock makes the call raise MissingPluginException internally;
    // the data source wraps that as a `PlatformNotImplementedException`.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    expect(
      () => ds.disableStrip(),
      throwsA(isA<PlatformNotImplementedException>()),
    );
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/notifications/data/datasources/notifications_native_data_source_test.dart`
Expected: FAIL — data source does not exist.

- [ ] **Step 3: Create the data source**

Create `lib/features/notifications/data/datasources/notifications_native_data_source.dart`:

```dart
import 'package:flutter/services.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_strip_state.dart';

/// Thrown when the native side has not registered a handler for a channel
/// method. The repository maps this to `PlatformNotSupportedFailure`.
class PlatformNotImplementedException implements Exception {
  final String method;
  const PlatformNotImplementedException(this.method);
  @override
  String toString() =>
      'PlatformNotImplementedException: no native handler for "$method"';
}

abstract class NotificationsNativeDataSource {
  Future<void> enableStrip(PrayerStripState state);
  Future<void> disableStrip();
  Future<void> refreshStrip(PrayerStripState state);
  Future<void> scheduleDailyAdhans({
    required Map<String, String> timingsByPrayer,
    required Map<String, String> clipAssetByPrayer,
    required double volume,
  });
  Future<void> cancelAllAdhans();
}

class NotificationsNativeDataSourceImpl implements NotificationsNativeDataSource {
  static const channelName = 'quran_app/notifications';
  static const MethodChannel _channel = MethodChannel(channelName);

  Future<void> _invoke(String method, [Object? arguments]) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on MissingPluginException {
      throw PlatformNotImplementedException(method);
    }
  }

  @override
  Future<void> enableStrip(PrayerStripState state) =>
      _invoke('enableStrip', state.toJson());

  @override
  Future<void> disableStrip() => _invoke('disableStrip');

  @override
  Future<void> refreshStrip(PrayerStripState state) =>
      _invoke('refreshStrip', state.toJson());

  @override
  Future<void> scheduleDailyAdhans({
    required Map<String, String> timingsByPrayer,
    required Map<String, String> clipAssetByPrayer,
    required double volume,
  }) =>
      _invoke('scheduleDailyAdhans', {
        'timings': timingsByPrayer,
        'clips': clipAssetByPrayer,
        'volume': volume,
      });

  @override
  Future<void> cancelAllAdhans() => _invoke('cancelAllAdhans');
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/notifications/data/datasources/notifications_native_data_source_test.dart`
Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/notifications/data/datasources/notifications_native_data_source.dart test/features/notifications/data/datasources/notifications_native_data_source_test.dart
git commit -m "feat(notifications): add NotificationsNativeDataSource MethodChannel facade"
```

---

## Phase A9 — Repository implementation

### Task 16: Create `NotificationsRepositoryImpl`

**Files:**
- Create: `lib/features/notifications/data/repositories/notifications_repository_impl.dart`
- Create: `test/features/notifications/data/repositories/notifications_repository_impl_test.dart`

The impl wires the native data source for strip ops and delegates adhan scheduling to the **existing** `PrayerNotificationScheduler` (kept alive until Plans B/C land). When the native side isn't ready (Plan A), strip ops return `Left(PlatformNotSupportedFailure)`; adhan ops still succeed because the existing scheduler works on both platforms.

- [ ] **Step 1: Write the failing test**

Create `test/features/notifications/data/repositories/notifications_repository_impl_test.dart`:

```dart
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/core/notifications/prayer_notification_scheduler.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';
import 'package:quran_app/features/notifications/data/datasources/notifications_native_data_source.dart';
import 'package:quran_app/features/notifications/data/repositories/notifications_repository_impl.dart';
import 'package:quran_app/features/notifications/domain/entities/adhan_audio_settings.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_cell.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_strip_state.dart';

class _MockNative extends Mock implements NotificationsNativeDataSource {}

class _MockLegacyScheduler extends Mock implements PrayerNotificationScheduler {}

void main() {
  late _MockNative native;
  late _MockLegacyScheduler scheduler;
  late NotificationsRepositoryImpl repo;

  final state = PrayerStripState(
    cells: const [PrayerCell(label: 'Fajr', timeFormatted: '4:15')],
    nextPrayerIndex: 0,
    hijriDateLabel: '5 Dhul-Hijjah',
    localeCode: 'en',
    isFriday: false,
  );

  final pt = PrayerTimes(
    key: '22-05-2026',
    timings: {
      PrayerName.fajr: '04:15',
      PrayerName.sunrise: '05:07',
      PrayerName.dhuhr: '12:52',
      PrayerName.asr: '16:28',
      PrayerName.maghrib: '19:46',
      PrayerName.isha: '21:16',
    },
    date: Date(
      month: 'ذو الحجة',
      weekDay: 'الجمعة',
      day: '5',
      year: '1447',
      enMonth: 'Dhul-Hijjah',
      enWeekDay: 'Friday',
      gregorianDate: '22-05-2026',
    ),
  );

  setUp(() {
    native = _MockNative();
    scheduler = _MockLegacyScheduler();
    repo = NotificationsRepositoryImpl(native: native, legacyScheduler: scheduler);
    registerFallbackValue(state);
    registerFallbackValue(pt);
  });

  group('enableStrip', () {
    test('returns Right(unit) when native call succeeds', () async {
      when(() => native.enableStrip(any())).thenAnswer((_) async {});
      final r = await repo.enableStrip(state);
      expect(r, const Right(unit));
    });

    test('returns Left(PlatformNotSupportedFailure) on PlatformNotImplemented',
        () async {
      when(() => native.enableStrip(any()))
          .thenThrow(const PlatformNotImplementedException('enableStrip'));
      final r = await repo.enableStrip(state);
      expect(r.isLeft(), true);
      r.fold((f) => expect(f, isA<PlatformNotSupportedFailure>()), (_) {});
    });

    test('returns Left(UnknownNotificationFailure) on unknown exception',
        () async {
      when(() => native.enableStrip(any())).thenThrow(Exception('boom'));
      final r = await repo.enableStrip(state);
      r.fold((f) => expect(f, isA<UnknownNotificationFailure>()), (_) {});
    });
  });

  group('scheduleDailyAdhans', () {
    test('delegates to legacy scheduler and returns Right(unit) on success',
        () async {
      when(() => scheduler.scheduleDailyPrayerNotifications(any()))
          .thenAnswer((_) async {});
      final r = await repo.scheduleDailyAdhans(
        prayerTimes: pt,
        audio: AdhanAudioSettings.defaults(),
      );
      expect(r, const Right(unit));
      verify(() => scheduler.scheduleDailyPrayerNotifications(pt)).called(1);
    });

    test('returns Left(UnknownNotificationFailure) when scheduler throws',
        () async {
      when(() => scheduler.scheduleDailyPrayerNotifications(any()))
          .thenThrow(Exception('boom'));
      final r = await repo.scheduleDailyAdhans(
        prayerTimes: pt,
        audio: AdhanAudioSettings.defaults(),
      );
      r.fold((f) => expect(f, isA<UnknownNotificationFailure>()), (_) {});
    });
  });

  test('cancelAllAdhans delegates to legacy scheduler', () async {
    when(() => scheduler.cancelAllPrayerNotifications())
        .thenAnswer((_) async {});
    final r = await repo.cancelAllAdhans();
    expect(r, const Right(unit));
    verify(() => scheduler.cancelAllPrayerNotifications()).called(1);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/notifications/data/repositories/notifications_repository_impl_test.dart`
Expected: FAIL — repo impl does not exist.

- [ ] **Step 3: Create the repository impl**

Create `lib/features/notifications/data/repositories/notifications_repository_impl.dart`:

```dart
import 'package:dartz/dartz.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/core/notifications/prayer_notification_scheduler.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';
import 'package:quran_app/features/notifications/data/datasources/notifications_native_data_source.dart';
import 'package:quran_app/features/notifications/domain/entities/adhan_audio_settings.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_strip_state.dart';
import 'package:quran_app/features/notifications/domain/repositories/notifications_repository.dart';

class NotificationsRepositoryImpl implements NotificationsRepository {
  final NotificationsNativeDataSource native;
  final PrayerNotificationScheduler legacyScheduler;

  NotificationsRepositoryImpl({
    required this.native,
    required this.legacyScheduler,
  });

  Future<Either<Failure, Unit>> _run(Future<void> Function() body) async {
    try {
      await body();
      return const Right(unit);
    } on PlatformNotImplementedException {
      return const Left(PlatformNotSupportedFailure(
        'Pinned prayer strip is not implemented on this platform yet.',
      ));
    } catch (e) {
      return Left(UnknownNotificationFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> enableStrip(PrayerStripState state) =>
      _run(() => native.enableStrip(state));

  @override
  Future<Either<Failure, Unit>> disableStrip() =>
      _run(() => native.disableStrip());

  @override
  Future<Either<Failure, Unit>> refreshStrip(PrayerStripState state) =>
      _run(() => native.refreshStrip(state));

  @override
  Future<Either<Failure, Unit>> scheduleDailyAdhans({
    required PrayerTimes prayerTimes,
    required AdhanAudioSettings audio,
  }) =>
      _run(() => legacyScheduler.scheduleDailyPrayerNotifications(prayerTimes));

  @override
  Future<Either<Failure, Unit>> cancelAllAdhans() =>
      _run(() => legacyScheduler.cancelAllPrayerNotifications());
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/notifications/data/repositories/notifications_repository_impl_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/notifications/data/repositories/notifications_repository_impl.dart test/features/notifications/data/repositories/notifications_repository_impl_test.dart
git commit -m "feat(notifications): add NotificationsRepositoryImpl (legacy scheduler fallback)"
```

---

## Phase A10 — Dependency injection

### Task 17: Create `notifications_di.dart` and register from core

**Files:**
- Create: `lib/features/notifications/notifications_di.dart`
- Modify: `lib/core/di/dependency_injection.dart`

- [ ] **Step 1: Create the DI module**

Create `lib/features/notifications/notifications_di.dart`:

```dart
import 'package:quran_app/core/di/dependency_injection.dart';
import 'package:quran_app/core/notifications/prayer_notification_scheduler.dart';
import 'package:quran_app/features/notifications/data/datasources/notifications_native_data_source.dart';
import 'package:quran_app/features/notifications/data/repositories/notifications_repository_impl.dart';
import 'package:quran_app/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:quran_app/features/notifications/domain/usecases/disable_prayer_strip.dart';
import 'package:quran_app/features/notifications/domain/usecases/enable_prayer_strip.dart';
import 'package:quran_app/features/notifications/domain/usecases/refresh_prayer_strip.dart';
import 'package:quran_app/features/notifications/domain/usecases/sync_daily_adhans.dart';

/// Registers Dart-side dependencies for the notifications feature.
/// The legacy `PrayerNotificationScheduler` must already be registered
/// (this happens in `initHome()`).
void initNotifications() {
  sl.registerLazySingleton<NotificationsNativeDataSource>(
    () => NotificationsNativeDataSourceImpl(),
  );
  sl.registerLazySingleton<NotificationsRepository>(
    () => NotificationsRepositoryImpl(
      native: sl(),
      legacyScheduler: sl<PrayerNotificationScheduler>(),
    ),
  );
  sl.registerLazySingleton(() => EnablePrayerStrip(repository: sl()));
  sl.registerLazySingleton(() => DisablePrayerStrip(repository: sl()));
  sl.registerLazySingleton(() => RefreshPrayerStrip(repository: sl()));
  sl.registerLazySingleton(() => SyncDailyAdhans(repository: sl()));
}
```

- [ ] **Step 2: Wire it into the core DI**

Modify `lib/core/di/dependency_injection.dart`. The current file is:

```dart
import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:just_audio/just_audio.dart';
import 'package:quran_app/features/ahadith/ahadith_di.dart';
import 'package:quran_app/features/bookmarks/bookmarks_di.dart';
import 'package:quran_app/features/home/home_di.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';

import '../../features/quran_playback/playback_di.dart';
import '../../features/surah/presentation/pages/mushaf/mushaf_di.dart';
import '../../features/surah/last_read_di.dart';
import '../../features/surah/presentation/pages/surah_list/surah_list_di.dart';

final sl = GetIt.instance;

Future<void> initGetIt() async {
  sl.registerLazySingleton<AudioPlayer>(() => AudioPlayer());
  sl.registerLazySingleton<Dio>(() => Dio());
  sl.registerSingleton<SettingsCubit>(SettingsCubit());
  initHome();
  initSurahList();
  initMushaf();
  initAhadith();
  initPlayback();
  initBookmarks();
  initLastRead();
}
```

Add the import (alphabetically) and the `initNotifications()` call **after** `initHome()` so the legacy scheduler is registered first:

```dart
import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:just_audio/just_audio.dart';
import 'package:quran_app/features/ahadith/ahadith_di.dart';
import 'package:quran_app/features/bookmarks/bookmarks_di.dart';
import 'package:quran_app/features/home/home_di.dart';
import 'package:quran_app/features/notifications/notifications_di.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';

import '../../features/quran_playback/playback_di.dart';
import '../../features/surah/presentation/pages/mushaf/mushaf_di.dart';
import '../../features/surah/last_read_di.dart';
import '../../features/surah/presentation/pages/surah_list/surah_list_di.dart';

final sl = GetIt.instance;

Future<void> initGetIt() async {
  sl.registerLazySingleton<AudioPlayer>(() => AudioPlayer());
  sl.registerLazySingleton<Dio>(() => Dio());
  sl.registerSingleton<SettingsCubit>(SettingsCubit());
  initHome();
  initNotifications();
  initSurahList();
  initMushaf();
  initAhadith();
  initPlayback();
  initBookmarks();
  initLastRead();
}
```

- [ ] **Step 3: Verify analyzer is clean**

Run: `flutter analyze lib/core/di lib/features/notifications`
Expected: `No issues found!`

- [ ] **Step 4: Run all notifications tests**

Run: `flutter test test/features/notifications`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/notifications/notifications_di.dart lib/core/di/dependency_injection.dart
git commit -m "feat(notifications): register notifications feature in DI"
```

---

## Phase A11 — UI gate + l10n + Settings switch

### Task 18: Add a build-time feature flag for the Settings UI

**Files:**
- Create: `lib/core/constants/feature_flags.dart`

In Plan A we keep the Settings toggle visible **off** by default. We could just hide the new tile in the Settings sheet, but a flag is cleaner because Plan B can flip it in one place to expose the UI everywhere.

- [ ] **Step 1: Create the flag file**

Create `lib/core/constants/feature_flags.dart`:

```dart
/// Build-time flags that gate UI for in-progress features.
///
/// Once a feature's native side ships, flip its flag to `true` and remove
/// any conditional rendering that depended on it.
class FeatureFlags {
  const FeatureFlags._();

  /// Shows the "Pinned prayer times" toggle in the Settings sheet.
  /// Flip to `true` when Plan B (Android native pinned strip) lands.
  static const bool pinnedPrayerStripUi = false;
}
```

- [ ] **Step 2: Analyzer check**

Run: `flutter analyze lib/core/constants/feature_flags.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/core/constants/feature_flags.dart
git commit -m "chore(core): add FeatureFlags with pinnedPrayerStripUi gate"
```

---

### Task 19: Add l10n strings for the Settings toggle

**Files:**
- Modify: `lib/l10n/intl_en.arb`
- Modify: `lib/l10n/intl_ar.arb`

The user's environment uses the `flutter_intl` IDE extension to auto-generate `lib/generated/l10n.dart` on ARB save. If running outside the IDE, run the generator manually.

- [ ] **Step 1: Add the English strings**

In `lib/l10n/intl_en.arb`, add these entries inside the top-level JSON object (e.g., near the other Settings strings such as `"arabicLanguage"`):

```json
  "pinnedPrayerTimes": "Pinned prayer times",
  "pinnedPrayerTimesSubtitle": "Show today's prayers in your notification shade.",
```

- [ ] **Step 2: Add the Arabic strings**

In `lib/l10n/intl_ar.arb`, add the matching entries:

```json
  "pinnedPrayerTimes": "أوقات الصلاة المثبتة",
  "pinnedPrayerTimesSubtitle": "اعرض صلوات اليوم في شريط الإشعارات",
```

- [ ] **Step 3: Regenerate `lib/generated/l10n.dart`**

If using the `flutter_intl` VS Code / Android Studio extension: save both ARB files. The extension watches and regenerates automatically.

If running CLI: `flutter pub run intl_utils:generate`
Expected: `lib/generated/l10n.dart` now contains `S.current.pinnedPrayerTimes` and `S.current.pinnedPrayerTimesSubtitle`.

- [ ] **Step 4: Verify analyzer**

Run: `flutter analyze lib/generated/l10n.dart`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/l10n/intl_en.arb lib/l10n/intl_ar.arb lib/generated
git commit -m "feat(i18n): add pinned-prayer-times Settings strings"
```

---

### Task 20: Add the Settings toggle (gated by FeatureFlags)

**Files:**
- Modify: `lib/features/home/presentation/pages/widgets/settings_bottom_sheet.dart`

The toggle is rendered only when `FeatureFlags.pinnedPrayerStripUi == true`. In Plan A the flag is `false`, so the tile is invisible. Plan B flips the flag.

- [ ] **Step 1: Modify the settings sheet**

Open `lib/features/home/presentation/pages/widgets/settings_bottom_sheet.dart`. Add an import at the top:

```dart
import 'package:quran_app/core/constants/feature_flags.dart';
```

Inside the `Column.children` (after the `arabicLanguage` SettingSwitch and before the trailing `Gap(48)`), insert:

```dart
              if (FeatureFlags.pinnedPrayerStripUi)
                SettingSwitch(
                  settings: settings,
                  settingTitle: S.current.pinnedPrayerTimes,
                  icons: const [
                    HugeIcons.strokeRoundedNotification01,
                    HugeIcons.strokeRoundedNotificationOff01,
                  ],
                  value: settings.isPrayerStripPinned,
                  action: () => sl<SettingsCubit>().updatePrayerStripPinned(
                    !settings.isPrayerStripPinned,
                  ),
                ),
```

The icon constants `HugeIcons.strokeRoundedNotification01` / `…NotificationOff01` already exist in the `hugeicons` package (line 53 of `pubspec.yaml`). If the analyzer flags them as unknown, substitute any pair of available `HugeIcons` constants (`strokeRoundedBell01` / `strokeRoundedBellOff01`, for example).

- [ ] **Step 2: Verify analyzer**

Run: `flutter analyze lib/features/home/presentation/pages/widgets/settings_bottom_sheet.dart`
Expected: `No issues found!`

- [ ] **Step 3: Smoke run**

Run: `flutter test` (no new tests for this UI change, but full suite must still pass)
Expected: all PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/features/home/presentation/pages/widgets/settings_bottom_sheet.dart
git commit -m "feat(settings): add pinned-prayer-times toggle (gated by feature flag)"
```

---

## Phase A12 — Wire-up + dead-code removal

### Task 21: Wire `SyncDailyAdhans` into `home_page.dart`

**Files:**
- Modify: `lib/features/home/presentation/pages/home_page.dart`

The home page already has a `BlocListener<DailyPrayerContextCubit>` that calls `SchedulePrayerNotifications` when prayer-times load. We want **the same trigger point** to also call the new `SyncDailyAdhans`. Plan B will additionally wire `EnablePrayerStrip` / `RefreshPrayerStrip` here once the toggle is exposed.

For Plan A we only swap the call so the existing notification scheduling now goes through the new repository (which still delegates to the legacy scheduler — behavior unchanged).

- [ ] **Step 1: Replace the listener body**

In `lib/features/home/presentation/pages/home_page.dart`, find the existing block (around lines 51–63 — confirm with `grep -n SchedulePrayerNotifications`):

```dart
          BlocListener<DailyPrayerContextCubit, DailyPrayerContextState>(
            listenWhen: (_, s) => s is DailyPrayerContextLoaded,
            listener: (context, state) {
              final loaded = state as DailyPrayerContextLoaded;
              unawaited(
                sl<SchedulePrayerNotifications>().call(
                  SchedulePrayerNotificationsParams(
                    prayerTimes: loaded.dailyPrayerContext.prayerTimes,
                  ),
                ),
              );
            },
          ),
```

Replace with:

```dart
          BlocListener<DailyPrayerContextCubit, DailyPrayerContextState>(
            listenWhen: (_, s) => s is DailyPrayerContextLoaded,
            listener: (context, state) {
              final loaded = state as DailyPrayerContextLoaded;
              unawaited(
                sl<SyncDailyAdhans>().call(
                  SyncDailyAdhansParams(
                    prayerTimes: loaded.dailyPrayerContext.prayerTimes,
                  ),
                ),
              );
            },
          ),
```

- [ ] **Step 2: Update imports in the same file**

Remove the import:

```dart
import 'package:quran_app/features/home/domain/usecases/schedule_prayer_notifications.dart';
```

Add the import (sort alphabetically with the other `features/` imports):

```dart
import 'package:quran_app/features/notifications/domain/usecases/sync_daily_adhans.dart';
```

- [ ] **Step 3: Verify analyzer**

Run: `flutter analyze lib/features/home/presentation/pages/home_page.dart`
Expected: `No issues found!`

- [ ] **Step 4: Run home tests**

Run: `flutter test test/features/home`
Expected: existing home tests still PASS. (We're about to delete the schedule_prayer_notifications test in Task 22.)

- [ ] **Step 5: Commit**

```bash
git add lib/features/home/presentation/pages/home_page.dart
git commit -m "refactor(home): route prayer scheduling through SyncDailyAdhans"
```

---

### Task 22: Remove dead `SchedulePrayerNotifications` use case + test + DI

**Files:**
- Delete: `lib/features/home/domain/usecases/schedule_prayer_notifications.dart`
- Delete: `test/features/home/domain/usecases/schedule_prayer_notifications_test.dart`
- Modify: `lib/features/home/home_di.dart`

The wrapper use case is no longer called. The underlying `PrayerNotificationScheduler` registration **stays** — `NotificationsRepositoryImpl` depends on it.

- [ ] **Step 1: Delete the use case file**

Run: `git rm lib/features/home/domain/usecases/schedule_prayer_notifications.dart`
Expected: file removed; staged.

- [ ] **Step 2: Delete its test file**

Run: `git rm test/features/home/domain/usecases/schedule_prayer_notifications_test.dart`
Expected: file removed; staged.

- [ ] **Step 3: Remove the DI registration**

In `lib/features/home/home_di.dart`, remove these two lines:

```dart
import 'package:quran_app/features/home/domain/usecases/schedule_prayer_notifications.dart';
```

and at the bottom of `initHome()`:

```dart
  sl.registerLazySingleton(
    () => SchedulePrayerNotifications(scheduler: sl()),
  );
```

The `PrayerNotificationScheduler` + `PrayerNotificationSchedulerImpl` lines just above must stay.

- [ ] **Step 4: Verify analyzer**

Run: `flutter analyze lib/features/home`
Expected: `No issues found!`

- [ ] **Step 5: Run full test suite**

Run: `flutter test`
Expected: all PASS, including notifications + home + settings.

- [ ] **Step 6: Commit**

```bash
git add lib/features/home/home_di.dart
git commit -m "chore(home): remove dead SchedulePrayerNotifications wrapper"
```

---

### Task 23: Final verification + analyzer sweep

- [ ] **Step 1: Full analyzer**

Run: `flutter analyze`
Expected: `No issues found!` across the whole project.

- [ ] **Step 2: Full test suite**

Run: `flutter test`
Expected: every test PASSes. Print a count of passing tests for confidence.

- [ ] **Step 3: Confirm git status is clean**

Run: `git status`
Expected: working tree clean. (The unrelated pre-existing modifications to `linux/`, `macos/`, `windows/` generated plugin files may still show as modified — that's fine; they were not introduced by Plan A.)

- [ ] **Step 4: List the new test files for the record**

Run: `git log --oneline feature/004-pinned-prayer-notification ^main`
Expected: ~22 commits from this plan, all on the `feature/004-pinned-prayer-notification` branch.

- [ ] **Step 5: No commit needed for this task — it's a verification step.**

---

## Self-review

**Spec coverage:**

| Spec section | Covered by |
|---|---|
| §7.1 Feature layout | Tasks 5–17 build the entire `lib/features/notifications/` tree |
| §7.2 Boundary rules | Domain code (entities, use cases, builder) imports no Flutter; data layer owns MethodChannel; failure mapping done in repo impl |
| §7.3 Entities | Tasks 5, 6, 7 |
| §7.4 Repository contract | Task 10 |
| §7.5 State flow | Use cases (Tasks 11–14) and home_page wiring (Task 21) |
| §10 Settings integration | Tasks 1–3 (entity / model / cubit) + Tasks 18–20 (UI gated) |
| §11 DI | Task 17 |
| §13.1 Pure-Dart tests | Every domain task has a TDD-first test |
| §13.2 MethodChannel tests | Task 15 |
| §14 Migration plan | Aligned with the "phased" note — Plan A leaves the legacy scheduler in place |

**Deferred to Plan B (Android native):**
- §4 Visual layout, RemoteViews, drawables
- §8 Foreground service, AdhanPlayer, AlarmManager, BootReceiver
- §10.3 UI is gated until Plan B (`FeatureFlags.pinnedPrayerStripUi = true`)

**Deferred to Plan C (iOS Live Activity + adhan rewrite):**
- §9 ActivityKit widget extension
- §9.4 iOS adhan path
- Deletion of `lib/core/notifications/prayer_notification_scheduler*.dart` (must wait until both native paths are live)

**Placeholder scan:** No `TBD` / `TODO` strings in the plan. Every code block is complete.

**Type consistency:** Method names checked across tasks:
- `PrayerStripState.toJson()` / `.fromJson()` — defined Task 6, consumed Task 15
- `NotificationsRepository.enableStrip` / `disableStrip` / `refreshStrip` / `scheduleDailyAdhans` / `cancelAllAdhans` — defined Task 10, consumed Tasks 11–16
- `NotificationsNativeDataSource.scheduleDailyAdhans` parameters (`timingsByPrayer`, `clipAssetByPrayer`, `volume`) — used identically in Task 15 test + impl
- `PlatformNotImplementedException` — declared Task 15, caught Task 16
- `EnablePrayerStripParams.state` / `RefreshPrayerStripParams.state` / `SyncDailyAdhansParams.prayerTimes` — consistent across use cases and tests

Plan A is internally consistent. Execute it.

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-05-23-pinned-prayer-notification-dart-foundation.md`.

Two execution options:

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration.

**2. Inline Execution** — Execute tasks in this session using `executing-plans`, batch execution with checkpoints.

Which approach?
