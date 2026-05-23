# Advanced Adhan Settings Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Promote `NotificationsSettingsPage` from a single pinned-strip toggle into a full adhan-control hub with per-prayer adhan on/off, per-prayer pre-prayer reminder (0–15 min, 5-min steps) using Android live-countdown notifications, and a promoted "Play test adhan" button.

**Architecture:** Two new `Map<PrayerName, …>` fields on the existing `Settings` entity persist the user choices through `HydratedCubit`. `SyncDailyAdhans` reads them, filters disabled prayers, and routes through the existing `NotificationsRepositoryImpl` platform-branched path. Android adds `PrayerReminderScheduler` + `PrayerReminderReceiver` posting a `NotificationCompat` notification with `setUsesChronometer(true) + setChronometerCountDown(true)` so the OS renders the countdown for free. iOS gets a single static `flutter_local_notifications` notification at T-N as a documented parity gap.

**Tech Stack:** Dart 3 / Flutter, `flutter_bloc` (`HydratedCubit`), `mocktail` + `bloc_test` + `flutter_test`, Kotlin (Android `AlarmManager` + `NotificationCompat`), `flutter_local_notifications` (iOS only), `flutter_intl` for localization, `dartz` for `Either`.

**Source spec:** `docs/superpowers/specs/2026-05-23-advanced-adhan-settings-design.md` (commit `730da16`).

**Pre-flight checks (run once before starting):**

```bash
flutter analyze
flutter test
```

Both must be green. The branch already contains the prior adhan + pinned-strip work (commit `8b1716f`), so the baseline is healthy.

---

## File map

The plan creates / modifies these files. Each task lists only the file(s) it touches.

| Path | Action | Owner |
|---|---|---|
| `lib/features/settings/domain/entities/settings.dart` | modify | Task 1 |
| `lib/features/settings/data/models/settings_model.dart` | modify | Task 1 |
| `test/features/settings/settings_cubit_test.dart` | modify | Task 1, 2 |
| `lib/features/settings/presentation/cubit/settings_cubit.dart` | modify | Task 2 |
| `lib/features/notifications/domain/repositories/notifications_repository.dart` | modify | Task 3 |
| `lib/features/notifications/data/datasources/notifications_native_data_source.dart` | modify | Task 4 |
| `test/features/notifications/data/datasources/notifications_native_data_source_test.dart` | modify | Task 4 |
| `lib/features/notifications/data/repositories/notifications_repository_impl.dart` | modify | Task 5 |
| `test/features/notifications/data/repositories/notifications_repository_impl_test.dart` | modify | Task 5 |
| `lib/features/notifications/domain/usecases/sync_daily_adhans.dart` | modify | Task 6 |
| `test/features/notifications/domain/usecases/sync_daily_adhans_test.dart` | modify | Task 6 |
| `lib/features/home/presentation/pages/home_page.dart` | modify | Task 7 |
| `android/app/src/main/kotlin/com/example/quran_app/PrayerReminderIds.kt` | create | Task 8 |
| `android/app/src/main/kotlin/com/example/quran_app/PrayerReminderScheduler.kt` | create | Task 8 |
| `android/app/src/main/kotlin/com/example/quran_app/PrayerReminderReceiver.kt` | create | Task 9 |
| `android/app/src/main/kotlin/com/example/quran_app/AdhanAlarmReceiver.kt` | modify | Task 10 |
| `android/app/src/main/kotlin/com/example/quran_app/PrayerStripPlugin.kt` | modify | Task 11 |
| `android/app/src/main/AndroidManifest.xml` | modify | Task 12 |
| `android/app/src/main/res/values/strings.xml` | modify | Task 12 |
| `android/app/src/main/res/values-ar/strings.xml` | modify | Task 12 |
| `lib/core/notifications/prayer_notification_scheduler.dart` | modify | Task 13 |
| `lib/core/notifications/prayer_notification_scheduler_impl.dart` | modify | Task 13 |
| `lib/l10n/intl_en.arb` | modify | Task 14 |
| `lib/l10n/intl_ar.arb` | modify | Task 14 |
| `lib/features/home/presentation/pages/widgets/reminder_offset_dropdown.dart` | create | Task 15 |
| `lib/features/home/presentation/pages/widgets/per_prayer_adhan_tile.dart` | create | Task 16 |
| `lib/features/home/presentation/pages/widgets/test_adhan_button.dart` | create | Task 17 |
| `lib/features/home/presentation/pages/widgets/home_view.dart` | modify | Task 17 |
| `lib/features/home/presentation/pages/notifications_settings_page.dart` | modify | Task 18 |

---

## Task 1: Extend `Settings` entity + `SettingsModel` with the two new maps

**Files:**
- Modify: `lib/features/settings/domain/entities/settings.dart`
- Modify: `lib/features/settings/data/models/settings_model.dart`
- Modify: `test/features/settings/settings_cubit_test.dart`

- [ ] **Step 1: Add failing round-trip tests for both maps**

Append to `test/features/settings/settings_cubit_test.dart` before the closing `}`:

```dart
  test('toMap / fromMap round-trips adhanEnabledByPrayer', () {
    final model = SettingsModel(
      isDarkMode: true,
      isFormat12Hours: false,
      isArabic: true,
      adhanEnabledByPrayer: const {
        PrayerName.fajr: false,
        PrayerName.dhuhr: true,
        PrayerName.asr: true,
        PrayerName.maghrib: true,
        PrayerName.isha: false,
      },
    );
    final round = SettingsModel.fromMap(model.toMap());
    expect(round.adhanEnabledByPrayer[PrayerName.fajr], false);
    expect(round.adhanEnabledByPrayer[PrayerName.dhuhr], true);
    expect(round.adhanEnabledByPrayer[PrayerName.isha], false);
  });

  test('toMap / fromMap round-trips reminderMinutesByPrayer', () {
    final model = SettingsModel(
      isDarkMode: true,
      isFormat12Hours: false,
      isArabic: true,
      reminderMinutesByPrayer: const {
        PrayerName.fajr: 15,
        PrayerName.dhuhr: 0,
        PrayerName.asr: 10,
        PrayerName.maghrib: 5,
        PrayerName.isha: 0,
      },
    );
    final round = SettingsModel.fromMap(model.toMap());
    expect(round.reminderMinutesByPrayer[PrayerName.fajr], 15);
    expect(round.reminderMinutesByPrayer[PrayerName.asr], 10);
    expect(round.reminderMinutesByPrayer[PrayerName.maghrib], 5);
  });

  test('fromMap applies default adhan-enabled map (all true) when missing', () {
    final round = SettingsModel.fromMap({
      'isArabic': true,
      'isDarkMode': true,
      'isFormat12Hours': true,
      'playbackSpeed': 1.0,
      'defaultReciter': 'alafasy',
      'isPrayerStripPinned': false,
    });
    for (final p in [
      PrayerName.fajr, PrayerName.dhuhr, PrayerName.asr,
      PrayerName.maghrib, PrayerName.isha,
    ]) {
      expect(round.adhanEnabledByPrayer[p], true, reason: '$p should default to true');
    }
  });

  test('fromMap applies default reminder map (all zero) when missing', () {
    final round = SettingsModel.fromMap({
      'isArabic': true,
      'isDarkMode': true,
      'isFormat12Hours': true,
      'playbackSpeed': 1.0,
      'defaultReciter': 'alafasy',
      'isPrayerStripPinned': false,
    });
    for (final p in [
      PrayerName.fajr, PrayerName.dhuhr, PrayerName.asr,
      PrayerName.maghrib, PrayerName.isha,
    ]) {
      expect(round.reminderMinutesByPrayer[p], 0, reason: '$p should default to 0');
    }
  });
```

Also add at the top of the test file:

```dart
import 'package:quran_app/core/constants/prayer_name.dart';
```

- [ ] **Step 2: Run the new tests to verify they fail**

```bash
flutter test test/features/settings/settings_cubit_test.dart
```

Expected: the four new tests fail with "no parameter named adhanEnabledByPrayer" or "the getter adhanEnabledByPrayer isn't defined".

- [ ] **Step 3: Extend the `Settings` entity**

Replace the contents of `lib/features/settings/domain/entities/settings.dart` with:

```dart
import 'package:equatable/equatable.dart';

import 'package:quran_app/core/constants/prayer_name.dart';
import '../../../quran_playback/domain/entities/reciter.dart';

class Settings extends Equatable {
  final bool isDarkMode;
  final bool isFormat12Hours;
  final bool isArabic;
  final double playbackSpeed;
  final Reciter defaultReciter;
  final bool isPrayerStripPinned;
  final Map<PrayerName, bool> adhanEnabledByPrayer;
  final Map<PrayerName, int> reminderMinutesByPrayer;

  static const Map<PrayerName, bool> defaultAdhanEnabled = {
    PrayerName.fajr: true,
    PrayerName.dhuhr: true,
    PrayerName.asr: true,
    PrayerName.maghrib: true,
    PrayerName.isha: true,
  };

  static const Map<PrayerName, int> defaultReminderMinutes = {
    PrayerName.fajr: 0,
    PrayerName.dhuhr: 0,
    PrayerName.asr: 0,
    PrayerName.maghrib: 0,
    PrayerName.isha: 0,
  };

  static const List<int> validReminderMinutes = [0, 5, 10, 15];

  const Settings({
    required this.isDarkMode,
    required this.isFormat12Hours,
    required this.isArabic,
    this.playbackSpeed = 1.0,
    this.defaultReciter = Reciter.alafasy,
    this.isPrayerStripPinned = false,
    this.adhanEnabledByPrayer = defaultAdhanEnabled,
    this.reminderMinutesByPrayer = defaultReminderMinutes,
  });

  Settings copyWith({
    bool? isDarkMode,
    bool? isFormat12Hours,
    bool? isArabic,
    double? playbackSpeed,
    Reciter? defaultReciter,
    bool? isPrayerStripPinned,
    Map<PrayerName, bool>? adhanEnabledByPrayer,
    Map<PrayerName, int>? reminderMinutesByPrayer,
  }) {
    return Settings(
      isArabic: isArabic ?? this.isArabic,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      isFormat12Hours: isFormat12Hours ?? this.isFormat12Hours,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      defaultReciter: defaultReciter ?? this.defaultReciter,
      isPrayerStripPinned: isPrayerStripPinned ?? this.isPrayerStripPinned,
      adhanEnabledByPrayer: adhanEnabledByPrayer ?? this.adhanEnabledByPrayer,
      reminderMinutesByPrayer:
          reminderMinutesByPrayer ?? this.reminderMinutesByPrayer,
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
        adhanEnabledByPrayer,
        reminderMinutesByPrayer,
      ];
}
```

- [ ] **Step 4: Extend `SettingsModel` with serialization helpers**

Replace the contents of `lib/features/settings/data/models/settings_model.dart` with:

```dart
import 'package:quran_app/core/constants/prayer_name.dart';
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
    super.adhanEnabledByPrayer,
    super.reminderMinutesByPrayer,
  });

  @override
  SettingsModel copyWith({
    bool? isDarkMode,
    bool? isFormat12Hours,
    bool? isArabic,
    double? playbackSpeed,
    Reciter? defaultReciter,
    bool? isPrayerStripPinned,
    Map<PrayerName, bool>? adhanEnabledByPrayer,
    Map<PrayerName, int>? reminderMinutesByPrayer,
  }) {
    return SettingsModel(
      isArabic: isArabic ?? this.isArabic,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      isFormat12Hours: isFormat12Hours ?? this.isFormat12Hours,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      defaultReciter: defaultReciter ?? this.defaultReciter,
      isPrayerStripPinned: isPrayerStripPinned ?? this.isPrayerStripPinned,
      adhanEnabledByPrayer: adhanEnabledByPrayer ?? this.adhanEnabledByPrayer,
      reminderMinutesByPrayer:
          reminderMinutesByPrayer ?? this.reminderMinutesByPrayer,
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
      isPrayerStripPinned: map['isPrayerStripPinned'] ?? false,
      adhanEnabledByPrayer: _readEnabledMap(map['adhanEnabledByPrayer']),
      reminderMinutesByPrayer: _readReminderMap(map['reminderMinutesByPrayer']),
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
      'adhanEnabledByPrayer': {
        for (final e in adhanEnabledByPrayer.entries) e.key.name: e.value,
      },
      'reminderMinutesByPrayer': {
        for (final e in reminderMinutesByPrayer.entries) e.key.name: e.value,
      },
    };
  }

  static Map<PrayerName, bool> _readEnabledMap(dynamic raw) {
    if (raw is! Map) return Settings.defaultAdhanEnabled;
    final result = <PrayerName, bool>{...Settings.defaultAdhanEnabled};
    for (final e in raw.entries) {
      final p = PrayerName.values
          .where((x) => x.name == e.key as String)
          .cast<PrayerName?>()
          .firstWhere((_) => true, orElse: () => null);
      final v = e.value;
      if (p != null && v is bool) result[p] = v;
    }
    return result;
  }

  static Map<PrayerName, int> _readReminderMap(dynamic raw) {
    if (raw is! Map) return Settings.defaultReminderMinutes;
    final result = <PrayerName, int>{...Settings.defaultReminderMinutes};
    for (final e in raw.entries) {
      final p = PrayerName.values
          .where((x) => x.name == e.key as String)
          .cast<PrayerName?>()
          .firstWhere((_) => true, orElse: () => null);
      final v = e.value;
      if (p != null && v is int && Settings.validReminderMinutes.contains(v)) {
        result[p] = v;
      }
    }
    return result;
  }
}
```

- [ ] **Step 5: Run the tests — they should pass**

```bash
flutter test test/features/settings/settings_cubit_test.dart
```

Expected: all tests in the file pass.

- [ ] **Step 6: Commit**

```bash
git add lib/features/settings/domain/entities/settings.dart \
        lib/features/settings/data/models/settings_model.dart \
        test/features/settings/settings_cubit_test.dart
git commit -m "feat(settings): add per-prayer adhan + reminder maps to Settings"
```

---

## Task 2: Add cubit mutators for per-prayer adhan + reminder

**Files:**
- Modify: `lib/features/settings/presentation/cubit/settings_cubit.dart`
- Modify: `test/features/settings/settings_cubit_test.dart`

- [ ] **Step 1: Add failing blocTests for both mutators**

Append to `test/features/settings/settings_cubit_test.dart` before the closing `}`:

```dart
  blocTest<SettingsCubit, SettingsState>(
    'updateAdhanEnabled(Fajr, false) emits state with Fajr disabled',
    build: () => SettingsCubit(),
    act: (c) => c.updateAdhanEnabled(PrayerName.fajr, false),
    expect: () => [
      isA<SettingsState>().having(
        (s) => s.settingsModel.adhanEnabledByPrayer[PrayerName.fajr],
        'fajr enabled',
        false,
      ),
    ],
  );

  blocTest<SettingsCubit, SettingsState>(
    'updateReminderMinutes(Maghrib, 10) emits state with reminder=10',
    build: () => SettingsCubit(),
    act: (c) => c.updateReminderMinutes(PrayerName.maghrib, 10),
    expect: () => [
      isA<SettingsState>().having(
        (s) => s.settingsModel.reminderMinutesByPrayer[PrayerName.maghrib],
        'maghrib reminder',
        10,
      ),
    ],
  );

  test('updateReminderMinutes rejects invalid step (7) with an assertion', () {
    final cubit = SettingsCubit();
    expect(
      () => cubit.updateReminderMinutes(PrayerName.fajr, 7),
      throwsA(isA<AssertionError>()),
    );
  });
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
flutter test test/features/settings/settings_cubit_test.dart
```

Expected: the three new tests fail with "no method updateAdhanEnabled" etc.

- [ ] **Step 3: Add the mutators**

Modify `lib/features/settings/presentation/cubit/settings_cubit.dart` — add imports and three methods before `fromJson`:

```dart
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/features/settings/domain/entities/settings.dart';
```

```dart
  void updateAdhanEnabled(PrayerName prayer, bool enabled) {
    final next = Map<PrayerName, bool>.from(
      state.settingsModel.adhanEnabledByPrayer,
    )..[prayer] = enabled;
    emit(SettingsState(
      state.settingsModel.copyWith(adhanEnabledByPrayer: next),
    ));
  }

  void updateReminderMinutes(PrayerName prayer, int minutes) {
    assert(
      Settings.validReminderMinutes.contains(minutes),
      'reminder minutes must be one of ${Settings.validReminderMinutes}, '
      'got $minutes',
    );
    final next = Map<PrayerName, int>.from(
      state.settingsModel.reminderMinutesByPrayer,
    )..[prayer] = minutes;
    emit(SettingsState(
      state.settingsModel.copyWith(reminderMinutesByPrayer: next),
    ));
  }
```

- [ ] **Step 4: Run the tests — they should pass**

```bash
flutter test test/features/settings/settings_cubit_test.dart
```

Expected: all green.

- [ ] **Step 5: Commit**

```bash
git add lib/features/settings/presentation/cubit/settings_cubit.dart \
        test/features/settings/settings_cubit_test.dart
git commit -m "feat(settings): cubit mutators for per-prayer adhan + reminder"
```

---

## Task 3: Extend `NotificationsRepository` contract

**Files:**
- Modify: `lib/features/notifications/domain/repositories/notifications_repository.dart`

This task only modifies a contract — types must compile. Functional tests come in Task 5.

- [ ] **Step 1: Extend the abstract repository**

Replace the contents of `lib/features/notifications/domain/repositories/notifications_repository.dart` with:

```dart
import 'package:dartz/dartz.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';
import 'package:quran_app/features/notifications/domain/entities/adhan_audio_settings.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_strip_state.dart';

/// Single facade for all notification work — pinned strip + adhan playback +
/// pre-prayer reminders. All methods return `Either<Failure, Unit>`.
abstract class NotificationsRepository {
  Future<Either<Failure, Unit>> enableStrip(PrayerStripState state);
  Future<Either<Failure, Unit>> disableStrip();
  Future<Either<Failure, Unit>> refreshStrip(PrayerStripState state);

  /// Schedules today's per-prayer adhan notifications.
  /// [enabledByPrayer] filters which prayers receive an adhan.
  /// Replaces any previously scheduled set.
  Future<Either<Failure, Unit>> scheduleDailyAdhans({
    required PrayerTimes prayerTimes,
    required AdhanAudioSettings audio,
    required Map<PrayerName, bool> enabledByPrayer,
    required String localeCode,
  });

  Future<Either<Failure, Unit>> cancelAllAdhans();

  /// Schedules pre-prayer reminder notifications.
  /// [reminderMinutesByPrayer] maps each prayer to a positive offset in
  /// minutes; 0 means no reminder. Replaces any previously scheduled set.
  Future<Either<Failure, Unit>> schedulePrayerReminders({
    required PrayerTimes prayerTimes,
    required Map<PrayerName, int> reminderMinutesByPrayer,
    required String localeCode,
  });

  Future<Either<Failure, Unit>> cancelAllReminders();
}
```

- [ ] **Step 2: Compile-check by running analyze (impls aren't updated yet — expect errors)**

```bash
flutter analyze
```

Expected: errors in `notifications_repository_impl.dart` (missing implementations) — these will be fixed in Task 5. Do NOT commit yet; types still don't compile. Continue to Task 4.

---

## Task 4: Extend `NotificationsNativeDataSource` for the new channel methods

**Files:**
- Modify: `lib/features/notifications/data/datasources/notifications_native_data_source.dart`
- Modify: `test/features/notifications/data/datasources/notifications_native_data_source_test.dart`

- [ ] **Step 1: Add failing data-source tests for both new methods**

Append to `test/features/notifications/data/datasources/notifications_native_data_source_test.dart` before the closing `}`:

```dart
  test('schedulePrayerReminders invokes the channel with the reminder map',
      () async {
    await ds.schedulePrayerReminders(
      remindersByPrayer: const {'fajr': 15, 'maghrib': 5},
      timingsByPrayer: const {
        'fajr': '04:15',
        'dhuhr': '12:52',
        'maghrib': '19:46',
      },
      localeCode: 'ar',
    );
    expect(calls.single.method, 'schedulePrayerReminders');
    final args = calls.single.arguments as Map;
    expect(args['remindersByPrayer'], {'fajr': 15, 'maghrib': 5});
    expect(args['timings'], {
      'fajr': '04:15', 'dhuhr': '12:52', 'maghrib': '19:46',
    });
    expect(args['localeCode'], 'ar');
  });

  test('cancelAllReminders invokes the channel', () async {
    await ds.cancelAllReminders();
    expect(calls.single.method, 'cancelAllReminders');
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
flutter test test/features/notifications/data/datasources/notifications_native_data_source_test.dart
```

Expected: the two new tests fail with "no method schedulePrayerReminders".

- [ ] **Step 3: Extend the abstract interface + impl**

In `lib/features/notifications/data/datasources/notifications_native_data_source.dart`:

Add to the `NotificationsNativeDataSource` abstract:

```dart
  Future<void> schedulePrayerReminders({
    required Map<String, int> remindersByPrayer,
    required Map<String, String> timingsByPrayer,
    required String localeCode,
  });

  Future<void> cancelAllReminders();
```

Add to `NotificationsNativeDataSourceImpl`:

```dart
  @override
  Future<void> schedulePrayerReminders({
    required Map<String, int> remindersByPrayer,
    required Map<String, String> timingsByPrayer,
    required String localeCode,
  }) =>
      _invoke('schedulePrayerReminders', {
        'remindersByPrayer': remindersByPrayer,
        'timings': timingsByPrayer,
        'localeCode': localeCode,
      });

  @override
  Future<void> cancelAllReminders() => _invoke('cancelAllReminders');
```

- [ ] **Step 4: Run the data-source tests — they should pass**

```bash
flutter test test/features/notifications/data/datasources/notifications_native_data_source_test.dart
```

Expected: all green.

- [ ] **Step 5: Commit**

```bash
git add lib/features/notifications/data/datasources/notifications_native_data_source.dart \
        test/features/notifications/data/datasources/notifications_native_data_source_test.dart
git commit -m "feat(notifications): native data source methods for reminder scheduling"
```

---

## Task 5: Implement repository platform branching + MissingPluginException guard

**Files:**
- Modify: `lib/features/notifications/data/repositories/notifications_repository_impl.dart`
- Modify: `test/features/notifications/data/repositories/notifications_repository_impl_test.dart`

- [ ] **Step 1: Update existing tests to use the new `scheduleDailyAdhans` signature**

In `test/features/notifications/data/repositories/notifications_repository_impl_test.dart` find every call to `repo.scheduleDailyAdhans(...)` and add `enabledByPrayer:` plus update the mock setups. Replace the entire `group('scheduleDailyAdhans', ...)` block with:

```dart
  group('scheduleDailyAdhans', () {
    const allEnabled = {
      PrayerName.fajr: true,
      PrayerName.dhuhr: true,
      PrayerName.asr: true,
      PrayerName.maghrib: true,
      PrayerName.isha: true,
    };

    test('Android: routes to native with filtered timings; ignores legacy',
        () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      when(() => native.scheduleDailyAdhans(
            timingsByPrayer: any(named: 'timingsByPrayer'),
            clipAssetByPrayer: any(named: 'clipAssetByPrayer'),
            volume: any(named: 'volume'),
            localeCode: any(named: 'localeCode'),
          )).thenAnswer((_) async {});

      final r = await repo.scheduleDailyAdhans(
        prayerTimes: pt,
        audio: AdhanAudioSettings.defaults(),
        enabledByPrayer: allEnabled,
        localeCode: 'en',
      );

      expect(r, const Right(unit));
      verify(() => native.scheduleDailyAdhans(
            timingsByPrayer: any(named: 'timingsByPrayer'),
            clipAssetByPrayer: any(named: 'clipAssetByPrayer'),
            volume: any(named: 'volume'),
            localeCode: any(named: 'localeCode'),
          )).called(1);
      verifyNever(() => scheduler.scheduleDailyPrayerNotifications(any()));
      debugDefaultTargetPlatformOverride = null;
    });

    test('Android: omits prayers whose enabled=false from the timings map',
        () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      Map<String, String>? capturedTimings;
      when(() => native.scheduleDailyAdhans(
            timingsByPrayer: any(named: 'timingsByPrayer'),
            clipAssetByPrayer: any(named: 'clipAssetByPrayer'),
            volume: any(named: 'volume'),
            localeCode: any(named: 'localeCode'),
          )).thenAnswer((invocation) async {
        capturedTimings = invocation.namedArguments[#timingsByPrayer]
            as Map<String, String>;
      });

      await repo.scheduleDailyAdhans(
        prayerTimes: pt,
        audio: AdhanAudioSettings.defaults(),
        enabledByPrayer: const {
          PrayerName.fajr: false,
          PrayerName.dhuhr: true,
          PrayerName.asr: true,
          PrayerName.maghrib: true,
          PrayerName.isha: false,
        },
        localeCode: 'en',
      );

      expect(capturedTimings!.containsKey('fajr'), false);
      expect(capturedTimings!.containsKey('isha'), false);
      expect(capturedTimings!.containsKey('dhuhr'), true);
      debugDefaultTargetPlatformOverride = null;
    });

    test('iOS: routes to legacy scheduler, ignores native', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      when(() => scheduler.scheduleDailyPrayerNotifications(any()))
          .thenAnswer((_) async {});

      final r = await repo.scheduleDailyAdhans(
        prayerTimes: pt,
        audio: AdhanAudioSettings.defaults(),
        enabledByPrayer: allEnabled,
        localeCode: 'en',
      );

      expect(r, const Right(unit));
      verify(() => scheduler.scheduleDailyPrayerNotifications(pt)).called(1);
      verifyNever(() => native.scheduleDailyAdhans(
            timingsByPrayer: any(named: 'timingsByPrayer'),
            clipAssetByPrayer: any(named: 'clipAssetByPrayer'),
            volume: any(named: 'volume'),
            localeCode: any(named: 'localeCode'),
          ));
      debugDefaultTargetPlatformOverride = null;
    });

    test('returns Left(UnknownNotificationFailure) when native throws on Android',
        () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      when(() => native.scheduleDailyAdhans(
            timingsByPrayer: any(named: 'timingsByPrayer'),
            clipAssetByPrayer: any(named: 'clipAssetByPrayer'),
            volume: any(named: 'volume'),
            localeCode: any(named: 'localeCode'),
          )).thenThrow(Exception('boom'));

      final r = await repo.scheduleDailyAdhans(
        prayerTimes: pt,
        audio: AdhanAudioSettings.defaults(),
        enabledByPrayer: allEnabled,
        localeCode: 'en',
      );
      r.fold((f) => expect(f, isA<UnknownNotificationFailure>()), (_) {});
      debugDefaultTargetPlatformOverride = null;
    });
  });
```

- [ ] **Step 2: Add tests for the new reminder methods**

Append before the closing `}` of `void main()`:

```dart
  group('schedulePrayerReminders', () {
    test('Android: routes to native.schedulePrayerReminders with reminder map',
        () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      when(() => native.schedulePrayerReminders(
            remindersByPrayer: any(named: 'remindersByPrayer'),
            timingsByPrayer: any(named: 'timingsByPrayer'),
            localeCode: any(named: 'localeCode'),
          )).thenAnswer((_) async {});

      final r = await repo.schedulePrayerReminders(
        prayerTimes: pt,
        reminderMinutesByPrayer: const {
          PrayerName.fajr: 15,
          PrayerName.asr: 10,
          PrayerName.maghrib: 0,
        },
        localeCode: 'en',
      );

      expect(r, const Right(unit));
      verify(() => native.schedulePrayerReminders(
            remindersByPrayer: {'fajr': 15, 'asr': 10},
            timingsByPrayer: any(named: 'timingsByPrayer'),
            localeCode: 'en',
          )).called(1);
      debugDefaultTargetPlatformOverride = null;
    });

    test('Android: swallows MissingPluginException as Right(unit)', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      when(() => native.schedulePrayerReminders(
            remindersByPrayer: any(named: 'remindersByPrayer'),
            timingsByPrayer: any(named: 'timingsByPrayer'),
            localeCode: any(named: 'localeCode'),
          )).thenThrow(
        const PlatformNotImplementedException('schedulePrayerReminders'),
      );

      final r = await repo.schedulePrayerReminders(
        prayerTimes: pt,
        reminderMinutesByPrayer: const {PrayerName.fajr: 15},
        localeCode: 'en',
      );

      // Partial-rollback safety: treat as "feature unavailable", not an error.
      expect(r, const Right(unit));
      debugDefaultTargetPlatformOverride = null;
    });

    test('Android: drops entries where minutes == 0', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      Map<String, int>? captured;
      when(() => native.schedulePrayerReminders(
            remindersByPrayer: any(named: 'remindersByPrayer'),
            timingsByPrayer: any(named: 'timingsByPrayer'),
            localeCode: any(named: 'localeCode'),
          )).thenAnswer((invocation) async {
        captured = invocation.namedArguments[#remindersByPrayer]
            as Map<String, int>;
      });

      await repo.schedulePrayerReminders(
        prayerTimes: pt,
        reminderMinutesByPrayer: const {
          PrayerName.fajr: 0,
          PrayerName.dhuhr: 10,
          PrayerName.asr: 0,
        },
        localeCode: 'en',
      );

      expect(captured, {'dhuhr': 10});
      debugDefaultTargetPlatformOverride = null;
    });
  });

  test('cancelAllReminders Android: delegates to native', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    when(() => native.cancelAllReminders()).thenAnswer((_) async {});
    final r = await repo.cancelAllReminders();
    expect(r, const Right(unit));
    verify(() => native.cancelAllReminders()).called(1);
    debugDefaultTargetPlatformOverride = null;
  });

  test('cancelAllReminders iOS: no-op (returns Right(unit))', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final r = await repo.cancelAllReminders();
    expect(r, const Right(unit));
    verifyZeroInteractions(native);
    debugDefaultTargetPlatformOverride = null;
  });
```

- [ ] **Step 3: Run the tests to verify they fail**

```bash
flutter test test/features/notifications/data/repositories/notifications_repository_impl_test.dart
```

Expected: many failures — `scheduleDailyAdhans` signature mismatch, missing `schedulePrayerReminders` / `cancelAllReminders`.

- [ ] **Step 4: Implement the repository changes**

Replace the contents of `lib/features/notifications/data/repositories/notifications_repository_impl.dart` with:

```dart
import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
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

  /// Like `_run`, but treats `PlatformNotImplementedException` as a soft
  /// success — used for additive methods (reminders) so a partial native-side
  /// revert never crashes the Dart scheduler.
  Future<Either<Failure, Unit>> _runOptional(
    String label,
    Future<void> Function() body,
  ) async {
    try {
      await body();
      return const Right(unit);
    } on PlatformNotImplementedException {
      debugPrint('[Notifications] $label: native side missing, skipping');
      return const Right(unit);
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
    required Map<PrayerName, bool> enabledByPrayer,
    required String localeCode,
  }) =>
      _run(() async {
        if (defaultTargetPlatform == TargetPlatform.android) {
          final filteredTimings = <PrayerName, String>{
            for (final e in prayerTimes.timings.entries)
              if (enabledByPrayer[e.key] ?? true) e.key: e.value,
          };
          await native.scheduleDailyAdhans(
            timingsByPrayer: _lowercasePrayerKeys(filteredTimings),
            clipAssetByPrayer: _lowercasePrayerKeys(audio.clipAssetByPrayer),
            volume: audio.volume,
            localeCode: localeCode,
          );
        } else {
          await legacyScheduler.scheduleDailyPrayerNotifications(prayerTimes);
        }
      });

  @override
  Future<Either<Failure, Unit>> cancelAllAdhans() =>
      _run(() async {
        if (defaultTargetPlatform == TargetPlatform.android) {
          await native.cancelAllAdhans();
        } else {
          await legacyScheduler.cancelAllPrayerNotifications();
        }
      });

  @override
  Future<Either<Failure, Unit>> schedulePrayerReminders({
    required PrayerTimes prayerTimes,
    required Map<PrayerName, int> reminderMinutesByPrayer,
    required String localeCode,
  }) =>
      _runOptional('schedulePrayerReminders', () async {
        if (defaultTargetPlatform == TargetPlatform.android) {
          final filtered = <String, int>{
            for (final e in reminderMinutesByPrayer.entries)
              if (e.value > 0) e.key.name.toLowerCase(): e.value,
          };
          await native.schedulePrayerReminders(
            remindersByPrayer: filtered,
            timingsByPrayer: _lowercasePrayerKeys(prayerTimes.timings),
            localeCode: localeCode,
          );
        }
        // iOS path is handled inline by the legacy scheduler from
        // scheduleDailyPrayerNotifications — reminders are not separate on iOS yet.
        // (Task 13 introduces scheduleStaticReminder; iOS callers will route
        //  here once that lands. For now this is a no-op on iOS.)
      });

  @override
  Future<Either<Failure, Unit>> cancelAllReminders() =>
      _runOptional('cancelAllReminders', () async {
        if (defaultTargetPlatform == TargetPlatform.android) {
          await native.cancelAllReminders();
        }
        // iOS: no separate reminder slots yet; will be added in Task 13.
      });

  Map<String, String> _lowercasePrayerKeys(Map<PrayerName, String> source) {
    return {for (final e in source.entries) e.key.name.toLowerCase(): e.value};
  }
}
```

- [ ] **Step 5: Run the tests — they should pass**

```bash
flutter test test/features/notifications/data/repositories/notifications_repository_impl_test.dart
```

Expected: all green.

- [ ] **Step 6: Run `flutter analyze` to confirm Task 3 + 4 + 5 compile end-to-end**

```bash
flutter analyze
```

Expected: any remaining errors should be in callers (e.g., `SyncDailyAdhans`) — these are fixed in Task 6. Note them but don't fix yet.

- [ ] **Step 7: Commit**

```bash
git add lib/features/notifications/domain/repositories/notifications_repository.dart \
        lib/features/notifications/data/repositories/notifications_repository_impl.dart \
        test/features/notifications/data/repositories/notifications_repository_impl_test.dart
git commit -m "feat(notifications): repository routes for per-prayer adhan + reminders"
```

---

## Task 6: Extend `SyncDailyAdhans` params + use case

**Files:**
- Modify: `lib/features/notifications/domain/usecases/sync_daily_adhans.dart`
- Modify: `test/features/notifications/domain/usecases/sync_daily_adhans_test.dart`

- [ ] **Step 1: Replace the sync-daily-adhans test with the extended contract**

Replace the contents of `test/features/notifications/domain/usecases/sync_daily_adhans_test.dart` with:

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

  const allEnabled = {
    PrayerName.fajr: true,
    PrayerName.dhuhr: true,
    PrayerName.asr: true,
    PrayerName.maghrib: true,
    PrayerName.isha: true,
  };
  const noReminders = {
    PrayerName.fajr: 0,
    PrayerName.dhuhr: 0,
    PrayerName.asr: 0,
    PrayerName.maghrib: 0,
    PrayerName.isha: 0,
  };

  setUp(() {
    repo = _MockRepo();
    useCase = SyncDailyAdhans(repository: repo);
    registerFallbackValue(pt);
    registerFallbackValue(AdhanAudioSettings.defaults());
  });

  test('delegates to scheduleDailyAdhans AND schedulePrayerReminders',
      () async {
    when(() => repo.scheduleDailyAdhans(
          prayerTimes: any(named: 'prayerTimes'),
          audio: any(named: 'audio'),
          enabledByPrayer: any(named: 'enabledByPrayer'),
          localeCode: any(named: 'localeCode'),
        )).thenAnswer((_) async => const Right(unit));
    when(() => repo.schedulePrayerReminders(
          prayerTimes: any(named: 'prayerTimes'),
          reminderMinutesByPrayer: any(named: 'reminderMinutesByPrayer'),
          localeCode: any(named: 'localeCode'),
        )).thenAnswer((_) async => const Right(unit));

    final result = await useCase.call(SyncDailyAdhansParams(
      prayerTimes: pt,
      enabledByPrayer: allEnabled,
      reminderMinutesByPrayer: noReminders,
      localeCode: 'en',
    ));

    expect(result.isRight(), true);
    verify(() => repo.scheduleDailyAdhans(
          prayerTimes: pt,
          audio: AdhanAudioSettings.defaults(),
          enabledByPrayer: allEnabled,
          localeCode: 'en',
        )).called(1);
    verify(() => repo.schedulePrayerReminders(
          prayerTimes: pt,
          reminderMinutesByPrayer: noReminders,
          localeCode: 'en',
        )).called(1);
  });

  test('returns Left when scheduleDailyAdhans fails (skips reminders)',
      () async {
    when(() => repo.scheduleDailyAdhans(
          prayerTimes: any(named: 'prayerTimes'),
          audio: any(named: 'audio'),
          enabledByPrayer: any(named: 'enabledByPrayer'),
          localeCode: any(named: 'localeCode'),
        )).thenAnswer((_) async => const Left(
          UnknownNotificationFailure('boom'),
        ));

    final result = await useCase.call(SyncDailyAdhansParams(
      prayerTimes: pt,
      enabledByPrayer: allEnabled,
      reminderMinutesByPrayer: noReminders,
      localeCode: 'en',
    ));

    expect(result.isLeft(), true);
    verifyNever(() => repo.schedulePrayerReminders(
          prayerTimes: any(named: 'prayerTimes'),
          reminderMinutesByPrayer: any(named: 'reminderMinutesByPrayer'),
          localeCode: any(named: 'localeCode'),
        ));
  });
}
```

Add to the top of the test file:

```dart
import 'package:quran_app/core/errors/failure.dart';
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
flutter test test/features/notifications/domain/usecases/sync_daily_adhans_test.dart
```

Expected: failures — `SyncDailyAdhansParams` doesn't have the new fields.

- [ ] **Step 3: Replace the use case**

Replace the contents of `lib/features/notifications/domain/usecases/sync_daily_adhans.dart` with:

```dart
import 'package:dartz/dartz.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/core/usecases/usecase.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';
import 'package:quran_app/features/notifications/domain/entities/adhan_audio_settings.dart';
import 'package:quran_app/features/notifications/domain/repositories/notifications_repository.dart';

class SyncDailyAdhansParams {
  final PrayerTimes prayerTimes;
  final AdhanAudioSettings? audio;
  final Map<PrayerName, bool> enabledByPrayer;
  final Map<PrayerName, int> reminderMinutesByPrayer;
  final String localeCode;

  const SyncDailyAdhansParams({
    required this.prayerTimes,
    required this.enabledByPrayer,
    required this.reminderMinutesByPrayer,
    required this.localeCode,
    this.audio,
  });
}

class SyncDailyAdhans
    extends UseCase<Either<Failure, Unit>, SyncDailyAdhansParams> {
  final NotificationsRepository repository;
  SyncDailyAdhans({required this.repository});

  @override
  Future<Either<Failure, Unit>> call(SyncDailyAdhansParams params) async {
    final adhanResult = await repository.scheduleDailyAdhans(
      prayerTimes: params.prayerTimes,
      audio: params.audio ?? AdhanAudioSettings.defaults(),
      enabledByPrayer: params.enabledByPrayer,
      localeCode: params.localeCode,
    );

    return adhanResult.fold(
      (failure) async => Left(failure),
      (_) => repository.schedulePrayerReminders(
        prayerTimes: params.prayerTimes,
        reminderMinutesByPrayer: params.reminderMinutesByPrayer,
        localeCode: params.localeCode,
      ),
    );
  }
}
```

- [ ] **Step 4: Run the use-case tests — they should pass**

```bash
flutter test test/features/notifications/domain/usecases/sync_daily_adhans_test.dart
```

Expected: all green.

- [ ] **Step 5: Commit**

```bash
git add lib/features/notifications/domain/usecases/sync_daily_adhans.dart \
        test/features/notifications/domain/usecases/sync_daily_adhans_test.dart
git commit -m "feat(notifications): sync use case now schedules adhans + reminders"
```

---

## Task 7: Wire HomePage listener to re-sync on adhan/reminder changes

**Files:**
- Modify: `lib/features/home/presentation/pages/home_page.dart`

The HomePage already runs `SyncDailyAdhans` from `DailyPrayerContextLoaded`. We extend the existing `SettingsCubit` listener to also re-run sync when the new maps change.

- [ ] **Step 1: Update the daily-prayer-context listener to pass the new fields**

In `home_page.dart`, find the block that calls `SyncDailyAdhans`:

```dart
              unawaited(
                sl<SyncDailyAdhans>().call(
                  SyncDailyAdhansParams(
                    prayerTimes: loaded.dailyPrayerContext.prayerTimes,
                    localeCode: locale,
                  ),
                ),
              );
```

Replace with:

```dart
              final settings = context.read<SettingsCubit>().state.settingsModel;
              unawaited(
                sl<SyncDailyAdhans>().call(
                  SyncDailyAdhansParams(
                    prayerTimes: loaded.dailyPrayerContext.prayerTimes,
                    enabledByPrayer: settings.adhanEnabledByPrayer,
                    reminderMinutesByPrayer: settings.reminderMinutesByPrayer,
                    localeCode: locale,
                  ),
                ),
              );
```

- [ ] **Step 2: Extend the `SettingsCubit` `listenWhen` predicate to include the new maps**

Find:

```dart
          BlocListener<SettingsCubit, SettingsState>(
            listenWhen: (prev, curr) =>
                prev.settingsModel.isPrayerStripPinned !=
                    curr.settingsModel.isPrayerStripPinned ||
                prev.settingsModel.isArabic != curr.settingsModel.isArabic,
            listener: (context, settings) {
              final ctxState = context.read<DailyPrayerContextCubit>().state;
              if (settings.settingsModel.isPrayerStripPinned &&
                  ctxState is DailyPrayerContextLoaded) {
                _enableOrRefreshStrip(context, ctxState);
              } else if (!settings.settingsModel.isPrayerStripPinned) {
                unawaited(sl<DisablePrayerStrip>().call(NoParams()));
              }
            },
          ),
```

Replace with:

```dart
          BlocListener<SettingsCubit, SettingsState>(
            listenWhen: (prev, curr) {
              final p = prev.settingsModel;
              final c = curr.settingsModel;
              return p.isPrayerStripPinned != c.isPrayerStripPinned ||
                  p.isArabic != c.isArabic ||
                  !_mapBoolEq(p.adhanEnabledByPrayer, c.adhanEnabledByPrayer) ||
                  !_mapIntEq(
                    p.reminderMinutesByPrayer, c.reminderMinutesByPrayer,
                  );
            },
            listener: (context, settings) {
              final ctxState = context.read<DailyPrayerContextCubit>().state;
              if (settings.settingsModel.isPrayerStripPinned &&
                  ctxState is DailyPrayerContextLoaded) {
                _enableOrRefreshStrip(context, ctxState);
              } else if (!settings.settingsModel.isPrayerStripPinned) {
                unawaited(sl<DisablePrayerStrip>().call(NoParams()));
              }

              // Re-sync adhans + reminders whenever the relevant settings change.
              if (ctxState is DailyPrayerContextLoaded) {
                final locale = settings.settingsModel.isArabic ? 'ar' : 'en';
                unawaited(
                  sl<SyncDailyAdhans>().call(
                    SyncDailyAdhansParams(
                      prayerTimes: ctxState.dailyPrayerContext.prayerTimes,
                      enabledByPrayer:
                          settings.settingsModel.adhanEnabledByPrayer,
                      reminderMinutesByPrayer:
                          settings.settingsModel.reminderMinutesByPrayer,
                      localeCode: locale,
                    ),
                  ),
                );
              }
            },
          ),
```

- [ ] **Step 3: Add the two map-equality helpers at the bottom of the file**

Below the `_enableOrRefreshStrip` method add:

```dart
  static bool _mapBoolEq(Map<PrayerName, bool> a, Map<PrayerName, bool> b) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (b[e.key] != e.value) return false;
    }
    return true;
  }

  static bool _mapIntEq(Map<PrayerName, int> a, Map<PrayerName, int> b) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (b[e.key] != e.value) return false;
    }
    return true;
  }
```

Add the import at the top:

```dart
import 'package:quran_app/core/constants/prayer_name.dart';
```

- [ ] **Step 4: Run `flutter analyze`**

```bash
flutter analyze
```

Expected: clean. If errors remain, address them and rerun.

- [ ] **Step 5: Run the full test suite**

```bash
flutter test
```

Expected: all green.

- [ ] **Step 6: Commit**

```bash
git add lib/features/home/presentation/pages/home_page.dart
git commit -m "feat(home): re-sync adhans + reminders on settings change"
```

---

## Task 8: Create `PrayerReminderIds` + `PrayerReminderScheduler.kt`

**Files:**
- Create: `android/app/src/main/kotlin/com/example/quran_app/PrayerReminderIds.kt`
- Create: `android/app/src/main/kotlin/com/example/quran_app/PrayerReminderScheduler.kt`

This is pure Kotlin parallel to `AdhanScheduler.kt`. No JVM tests — verification is via logcat on device.

- [ ] **Step 1: Create `PrayerReminderIds.kt`**

```kotlin
package com.example.quran_app

/**
 * Single source of truth for the prayer → reminder-notification-ID mapping.
 *
 * Deliberately NOT keyed on PrayerName.values — the enum also contains
 * `sunrise`, which has no reminder, and using `.index` would shift IDs.
 */
object PrayerReminderIds {

    const val NOTIFICATION_ID_BASE = 2300
    const val REQUEST_CODE_BASE = 300

    /** Lowercase prayer name -> notification ID. Order matches request codes. */
    val notificationIdByPrayer: Map<String, Int> = linkedMapOf(
        "fajr"    to 2300,
        "dhuhr"   to 2301,
        "asr"     to 2302,
        "maghrib" to 2303,
        "isha"    to 2304,
    )

    /** Lowercase prayer name -> PendingIntent request code. */
    val requestCodeByPrayer: Map<String, Int> = linkedMapOf(
        "fajr"    to 300,
        "dhuhr"   to 301,
        "asr"     to 302,
        "maghrib" to 303,
        "isha"    to 304,
    )

    val allPrayers: List<String> = notificationIdByPrayer.keys.toList()
}
```

- [ ] **Step 2: Create `PrayerReminderScheduler.kt`**

```kotlin
package com.example.quran_app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.util.Log
import java.util.Calendar

/**
 * Schedules pre-prayer reminder alarms via [AlarmManager].
 *
 * Trigger time = prayer time minus offsetMinutes. Skips any trigger that has
 * already passed today. Cancels previously-armed reminders before re-arming.
 *
 * Logs every step under tag "PrayerReminder" so behaviour is diagnosable via
 * `adb logcat *:S PrayerReminder:V`.
 */
object PrayerReminderScheduler {

    private const val TAG = "PrayerReminder"

    /**
     * Arms today's remaining reminders.
     *
     * @param remindersByPrayer keys are lowercase prayer names, values are
     *                          positive offsets in minutes (entries with 0 or
     *                          missing prayers are ignored).
     * @param timings keys are lowercase prayer names, values are "HH:mm" 24h.
     * @param localeCode "en" or "ar" — passed through to the receiver so the
     *                   posted notification matches the app's current language.
     */
    fun armToday(
        context: Context,
        remindersByPrayer: Map<String, Int>,
        timings: Map<String, String>,
        localeCode: String,
    ) {
        Log.i(TAG, "armToday: starting (locale=$localeCode, " +
            "${remindersByPrayer.size} reminders requested)")

        cancelAll(context)

        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val now = Calendar.getInstance()
        var armed = 0
        var skipped = 0

        for ((prayer, offsetMinutes) in remindersByPrayer) {
            if (offsetMinutes <= 0) {
                skipped++
                continue
            }
            val rc = PrayerReminderIds.requestCodeByPrayer[prayer]
            val notifId = PrayerReminderIds.notificationIdByPrayer[prayer]
            if (rc == null || notifId == null) {
                Log.w(TAG, "armToday: unknown prayer key '$prayer'")
                skipped++
                continue
            }
            val hhmm = timings[prayer]
            if (hhmm == null) {
                Log.w(TAG, "armToday: $prayer missing timing")
                skipped++
                continue
            }
            val parts = hhmm.split(":")
            if (parts.size != 2) {
                Log.w(TAG, "armToday: $prayer bad time '$hhmm'")
                skipped++
                continue
            }
            val hour = parts[0].toIntOrNull()
            val minute = parts[1].toIntOrNull()
            if (hour == null || minute == null) {
                Log.w(TAG, "armToday: $prayer unparseable '$hhmm'")
                skipped++
                continue
            }

            val prayerCal = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, hour)
                set(Calendar.MINUTE, minute)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            val triggerMs = prayerCal.timeInMillis - offsetMinutes * 60_000L
            if (triggerMs <= now.timeInMillis) {
                Log.i(TAG, "armToday: skipped $prayer (trigger in the past)")
                skipped++
                continue
            }

            val intent = Intent(context, PrayerReminderReceiver::class.java).apply {
                putExtra(PrayerReminderReceiver.EXTRA_PRAYER, prayer)
                putExtra(PrayerReminderReceiver.EXTRA_PRAYER_TIMESTAMP_MS,
                    prayerCal.timeInMillis)
                putExtra(PrayerReminderReceiver.EXTRA_NOTIFICATION_ID, notifId)
                putExtra(PrayerReminderReceiver.EXTRA_LOCALE, localeCode)
                putExtra(PrayerReminderReceiver.EXTRA_OFFSET_MINUTES,
                    offsetMinutes)
            }
            val pi = PendingIntent.getBroadcast(
                context, rc, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )

            try {
                am.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP, triggerMs, pi,
                )
                Log.i(TAG, "armed $prayer reminder at $triggerMs " +
                    "(prayer=$hhmm, offset=${offsetMinutes}m, request=$rc)")
                armed++
            } catch (e: SecurityException) {
                Log.w(TAG, "armToday: exact denied, using inexact for $prayer")
                am.setAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP, triggerMs, pi,
                )
                armed++
            }
        }

        Log.i(TAG, "armToday: $armed armed, $skipped skipped")
    }

    /** Cancels all armed reminder alarms AND any visible reminder notifications. */
    fun cancelAll(context: Context) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        for ((prayer, rc) in PrayerReminderIds.requestCodeByPrayer) {
            val intent = Intent(context, PrayerReminderReceiver::class.java)
            val pi = PendingIntent.getBroadcast(
                context, rc, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            am.cancel(pi)
        }
        // Also remove any reminder notification currently on screen.
        val nm = androidx.core.app.NotificationManagerCompat.from(context)
        for ((_, id) in PrayerReminderIds.notificationIdByPrayer) {
            nm.cancel(id)
        }
        Log.i(TAG, "cancelAll: cleared " +
            "${PrayerReminderIds.requestCodeByPrayer.size} reminders")
    }
}
```

- [ ] **Step 3: Confirm Kotlin compiles**

```bash
cd android && ./gradlew :app:compileDebugKotlin
```

Expected: BUILD SUCCESSFUL. (`PrayerReminderReceiver` doesn't exist yet — but its symbols are referenced. The build will fail with an "unresolved reference" error. Skip to Task 9 and run the compile after Task 9 instead.)

> ⚠️ Note: this compile step **will fail** until Task 9's receiver exists. That's fine — we commit after Task 10 once the full slice compiles.

---

## Task 9: Create `PrayerReminderReceiver.kt`

**Files:**
- Create: `android/app/src/main/kotlin/com/example/quran_app/PrayerReminderReceiver.kt`

- [ ] **Step 1: Create the receiver**

```kotlin
package com.example.quran_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

/**
 * Fires at T-N before a prayer. Posts a single notification with the system's
 * built-in countdown chronometer (`setUsesChronometer + setChronometerCountDown`).
 *
 * The OS handles the per-second visual countdown; we do no polling.
 *
 * The matching reminder notification is cancelled by [AdhanAlarmReceiver]
 * when the actual adhan alarm fires at T-0.
 */
class PrayerReminderReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent?) {
        val prayer = intent?.getStringExtra(EXTRA_PRAYER) ?: return
        val prayerTimestampMs = intent.getLongExtra(EXTRA_PRAYER_TIMESTAMP_MS, 0L)
        val notifId = intent.getIntExtra(
            EXTRA_NOTIFICATION_ID,
            PrayerReminderIds.notificationIdByPrayer[prayer] ?: return,
        )
        val localeCode = intent.getStringExtra(EXTRA_LOCALE) ?: "en"
        val offsetMinutes = intent.getIntExtra(EXTRA_OFFSET_MINUTES, 0)

        Log.i(TAG, "onReceive prayer=$prayer offset=${offsetMinutes}m " +
            "prayerAt=$prayerTimestampMs locale=$localeCode")

        ensureChannel(context)
        val notif = buildNotification(
            context, prayer, prayerTimestampMs, localeCode,
        )
        NotificationManagerCompat.from(context).notify(notifId, notif)
    }

    private fun buildNotification(
        context: Context,
        prayer: String,
        prayerTimestampMs: Long,
        localeCode: String,
    ): android.app.Notification {
        val ctx = localizedContext(context, localeCode)

        val titleResId = ctx.resources.getIdentifier(
            "reminder_title_$prayer", "string", context.packageName,
        ).let { if (it != 0) it else R.string.adhan_title_fajr }
        val bodyResId = ctx.resources.getIdentifier(
            "reminder_body_$prayer", "string", context.packageName,
        ).let { if (it != 0) it else R.string.adhan_body_fajr }
        val title = ctx.getString(titleResId)
        val body = ctx.getString(bodyResId)

        val openIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val openPI = PendingIntent.getActivity(
            context, 0, openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        return NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setWhen(prayerTimestampMs)
            .setUsesChronometer(true)
            .setChronometerCountDown(true)
            .setShowWhen(true)
            .setOnlyAlertOnce(true)
            .setOngoing(false)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setSound(null)
            .setVibrate(longArrayOf(0L, 200L))
            .setContentIntent(openPI)
            .build()
    }

    private fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java)
            ?: return
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        val name = context.getString(R.string.reminder_channel_name)
        val channel = NotificationChannel(
            CHANNEL_ID, name, NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            description = context.getString(R.string.reminder_channel_description)
            setShowBadge(false)
            enableVibration(true)
            vibrationPattern = longArrayOf(0L, 200L)
            setSound(null, null)
        }
        manager.createNotificationChannel(channel)
    }

    private fun localizedContext(context: Context, localeCode: String): Context {
        val locale = java.util.Locale(localeCode)
        val config = Configuration(context.resources.configuration)
        config.setLocale(locale)
        return context.createConfigurationContext(config)
    }

    companion object {
        private const val TAG = "PrayerReminderRx"
        const val CHANNEL_ID = "prayer_reminder_channel"

        const val EXTRA_PRAYER = "prayer"
        const val EXTRA_PRAYER_TIMESTAMP_MS = "prayer_ts_ms"
        const val EXTRA_NOTIFICATION_ID = "notif_id"
        const val EXTRA_LOCALE = "locale"
        const val EXTRA_OFFSET_MINUTES = "offset_minutes"
    }
}
```

- [ ] **Step 2: Confirm Kotlin compiles**

```bash
cd android && ./gradlew :app:compileDebugKotlin
```

Expected: BUILD SUCCESSFUL (the manifest entry, strings, and channel-name string don't exist yet, but they aren't compile-time symbols; this will still fail at *runtime* but compile cleanly). If `R.string.reminder_channel_name` / `R.string.reminder_channel_description` is unresolved, that's expected — proceed to Task 12 which adds the strings, then re-run.

> ⚠️ Like Task 8, defer the commit until Task 10 finishes the native slice and the strings exist (Task 12). Combined commit at the end of Task 12.

---

## Task 10: Modify `AdhanAlarmReceiver` to cancel matching reminder at T-0

**Files:**
- Modify: `android/app/src/main/kotlin/com/example/quran_app/AdhanAlarmReceiver.kt`

- [ ] **Step 1: Add the cancel-reminder call**

Replace the contents of `android/app/src/main/kotlin/com/example/quran_app/AdhanAlarmReceiver.kt` with:

```kotlin
package com.example.quran_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.core.app.NotificationManagerCompat

/**
 * Fires at prayer time. Must return within 10s (Android limit on BroadcastReceiver).
 * Cancels any pending reminder notification for this prayer, then hands off
 * to AdhanPlaybackService.
 */
class AdhanAlarmReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent?) {
        val prayer = intent?.getStringExtra(EXTRA_PRAYER) ?: "unknown"
        val clip = intent?.getStringExtra(EXTRA_CLIP) ?: "normal_adhan"
        val localeCode = intent?.getStringExtra(EXTRA_LOCALE) ?: "en"

        Log.i(TAG, "onReceive prayer=$prayer clip=$clip locale=$localeCode")

        // Dismiss the corresponding reminder notification if it's still visible —
        // otherwise the countdown sits at 00:00:00 next to the live adhan UI.
        PrayerReminderIds.notificationIdByPrayer[prayer]?.let { reminderId ->
            NotificationManagerCompat.from(context).cancel(reminderId)
            Log.i(TAG, "cancelled reminder notif id=$reminderId for $prayer")
        }

        val serviceIntent = Intent(context, AdhanPlaybackService::class.java).apply {
            action = AdhanPlaybackService.ACTION_PLAY
            putExtra(AdhanPlaybackService.EXTRA_PRAYER, prayer)
            putExtra(AdhanPlaybackService.EXTRA_CLIP, clip)
            putExtra(AdhanPlaybackService.EXTRA_LOCALE, localeCode)
        }
        context.startForegroundService(serviceIntent)
    }

    companion object {
        private const val TAG = "AdhanReceiver"
        const val EXTRA_PRAYER = "prayer"
        const val EXTRA_CLIP = "clip"
        const val EXTRA_LOCALE = "locale"
    }
}
```

- [ ] **Step 2: Compile**

```bash
cd android && ./gradlew :app:compileDebugKotlin
```

Expected: still failing on `R.string.reminder_*` — fixed by Task 12.

---

## Task 11: Wire `PrayerStripPlugin` routes for `schedulePrayerReminders` + `cancelAllReminders`

**Files:**
- Modify: `android/app/src/main/kotlin/com/example/quran_app/PrayerStripPlugin.kt`

- [ ] **Step 1: Add the two new method routes**

In `PrayerStripPlugin.kt`, add two `when` branches in `onMethodCall`:

```kotlin
            "scheduleDailyAdhans" -> handleScheduleDailyAdhans(ctx, call, result)
            "cancelAllAdhans" -> handleCancelAllAdhans(ctx, result)
            "scheduleTestAdhan" -> handleScheduleTestAdhan(ctx, call, result)
            "schedulePrayerReminders" -> handleSchedulePrayerReminders(ctx, call, result)
            "cancelAllReminders" -> handleCancelAllReminders(ctx, result)
            else -> result.notImplemented()
```

Then add the two handler methods (just below `handleScheduleTestAdhan`):

```kotlin
    private fun handleSchedulePrayerReminders(
        ctx: Context, call: MethodCall, result: MethodChannel.Result
    ) {
        val args = call.arguments as? Map<*, *>
        if (args == null) {
            result.error("BAD_ARGS", "Expected Map", null)
            return
        }
        @Suppress("UNCHECKED_CAST")
        val remindersByPrayer = (args["remindersByPrayer"] as? Map<String, Int>)
            ?: emptyMap()
        @Suppress("UNCHECKED_CAST")
        val timings = (args["timings"] as? Map<String, String>) ?: emptyMap()
        val localeCode = (args["localeCode"] as? String) ?: "en"

        PrayerReminderScheduler.armToday(
            ctx, remindersByPrayer, timings, localeCode,
        )
        result.success(null)
    }

    private fun handleCancelAllReminders(
        ctx: Context, result: MethodChannel.Result,
    ) {
        PrayerReminderScheduler.cancelAll(ctx)
        result.success(null)
    }
```

- [ ] **Step 2: Compile**

```bash
cd android && ./gradlew :app:compileDebugKotlin
```

Expected: still failing on `R.string.reminder_*`. Fixed by Task 12.

---

## Task 12: Manifest receiver + reminder strings (en + ar)

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `android/app/src/main/res/values/strings.xml`
- Modify: `android/app/src/main/res/values-ar/strings.xml` (create if absent)

- [ ] **Step 1: Register the new receiver in the manifest**

In `android/app/src/main/AndroidManifest.xml`, immediately after the existing `AdhanBootReceiver` block (closing `</receiver>`), insert:

```xml
        <receiver
            android:name=".PrayerReminderReceiver"
            android:exported="false" />
```

- [ ] **Step 2: Add the English reminder strings**

Replace the contents of `android/app/src/main/res/values/strings.xml` with:

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">Quran App</string>

    <!-- Adhan notification -->
    <string name="adhan_stop">Stop</string>
    <string name="adhan_body_fajr">It\'s time for Fajr prayer</string>
    <string name="adhan_body_dhuhr">It\'s time for Dhuhr prayer</string>
    <string name="adhan_body_asr">It\'s time for Asr prayer</string>
    <string name="adhan_body_maghrib">It\'s time for Maghrib prayer</string>
    <string name="adhan_body_isha">It\'s time for Isha prayer</string>

    <string name="adhan_title_fajr">Fajr</string>
    <string name="adhan_title_dhuhr">Dhuhr</string>
    <string name="adhan_title_asr">Asr</string>
    <string name="adhan_title_maghrib">Maghrib</string>
    <string name="adhan_title_isha">Isha</string>

    <!-- Pre-prayer reminder -->
    <string name="reminder_channel_name">Pre-prayer reminders</string>
    <string name="reminder_channel_description">Notifies you a few minutes before each prayer</string>
    <string name="reminder_title_fajr">Fajr reminder</string>
    <string name="reminder_title_dhuhr">Dhuhr reminder</string>
    <string name="reminder_title_asr">Asr reminder</string>
    <string name="reminder_title_maghrib">Maghrib reminder</string>
    <string name="reminder_title_isha">Isha reminder</string>
    <string name="reminder_body_fajr">Fajr prayer is coming up</string>
    <string name="reminder_body_dhuhr">Dhuhr prayer is coming up</string>
    <string name="reminder_body_asr">Asr prayer is coming up</string>
    <string name="reminder_body_maghrib">Maghrib prayer is coming up</string>
    <string name="reminder_body_isha">Isha prayer is coming up</string>
</resources>
```

- [ ] **Step 3: Add / extend the Arabic strings file**

If `android/app/src/main/res/values-ar/strings.xml` doesn't exist, create it. Set its contents to:

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">تطبيق القرآن</string>

    <!-- Adhan notification -->
    <string name="adhan_stop">إيقاف</string>
    <string name="adhan_body_fajr">حان وقت صلاة الفجر</string>
    <string name="adhan_body_dhuhr">حان وقت صلاة الظهر</string>
    <string name="adhan_body_asr">حان وقت صلاة العصر</string>
    <string name="adhan_body_maghrib">حان وقت صلاة المغرب</string>
    <string name="adhan_body_isha">حان وقت صلاة العشاء</string>

    <string name="adhan_title_fajr">الفجر</string>
    <string name="adhan_title_dhuhr">الظهر</string>
    <string name="adhan_title_asr">العصر</string>
    <string name="adhan_title_maghrib">المغرب</string>
    <string name="adhan_title_isha">العشاء</string>

    <!-- Pre-prayer reminder -->
    <string name="reminder_channel_name">تذكيرات قبل الصلاة</string>
    <string name="reminder_channel_description">تنبيه قبل الصلاة بدقائق</string>
    <string name="reminder_title_fajr">تذكير الفجر</string>
    <string name="reminder_title_dhuhr">تذكير الظهر</string>
    <string name="reminder_title_asr">تذكير العصر</string>
    <string name="reminder_title_maghrib">تذكير المغرب</string>
    <string name="reminder_title_isha">تذكير العشاء</string>
    <string name="reminder_body_fajr">اقتربت صلاة الفجر</string>
    <string name="reminder_body_dhuhr">اقتربت صلاة الظهر</string>
    <string name="reminder_body_asr">اقتربت صلاة العصر</string>
    <string name="reminder_body_maghrib">اقتربت صلاة المغرب</string>
    <string name="reminder_body_isha">اقتربت صلاة العشاء</string>
</resources>
```

> If the file already has an Arabic strings block, just merge the `<!-- Pre-prayer reminder -->` section in.

- [ ] **Step 4: Compile the whole Android slice**

```bash
cd android && ./gradlew :app:assembleDebug
```

Expected: BUILD SUCCESSFUL.

- [ ] **Step 5: Commit all native + Dart-glue changes from Tasks 8–12**

```bash
git add android/app/src/main/kotlin/com/example/quran_app/PrayerReminderIds.kt \
        android/app/src/main/kotlin/com/example/quran_app/PrayerReminderScheduler.kt \
        android/app/src/main/kotlin/com/example/quran_app/PrayerReminderReceiver.kt \
        android/app/src/main/kotlin/com/example/quran_app/AdhanAlarmReceiver.kt \
        android/app/src/main/kotlin/com/example/quran_app/PrayerStripPlugin.kt \
        android/app/src/main/AndroidManifest.xml \
        android/app/src/main/res/values/strings.xml \
        android/app/src/main/res/values-ar/strings.xml
git commit -m "feat(android): add PrayerReminderScheduler + countdown notification"
```

---

## Task 13: Add iOS static reminder support to the legacy scheduler

**Files:**
- Modify: `lib/core/notifications/prayer_notification_scheduler.dart`
- Modify: `lib/core/notifications/prayer_notification_scheduler_impl.dart`

The native repository's `schedulePrayerReminders` is currently a no-op on iOS (see Task 5's comment). This task adds an iOS implementation through the existing `flutter_local_notifications` plugin and wires the repository to use it.

- [ ] **Step 1: Extend the scheduler interface**

Replace the contents of `lib/core/notifications/prayer_notification_scheduler.dart` with:

```dart
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';

abstract class PrayerNotificationScheduler {
  Future<void> init();
  Future<void> scheduleDailyPrayerNotifications(PrayerTimes prayerTimes);
  Future<void> cancelAllPrayerNotifications();

  /// Schedules a single static pre-prayer reminder for [prayer] at [atUtc].
  /// Used on iOS only — Android has its own scheduler with live countdown.
  Future<void> scheduleStaticReminder({
    required PrayerName prayer,
    required DateTime at,
    required String title,
    required String body,
  });

  /// Cancels all pre-prayer reminders that were posted via
  /// [scheduleStaticReminder]. iOS-only callsite.
  Future<void> cancelAllStaticReminders();

  Future<void> scheduleTestNotification({Duration delay});
}
```

- [ ] **Step 2: Implement the new methods**

In `lib/core/notifications/prayer_notification_scheduler_impl.dart`:

Add these constants in the impl class (near the other `_notificationIds`):

```dart
  static const Map<PrayerName, int> _reminderIds = {
    PrayerName.fajr: 20,
    PrayerName.dhuhr: 22,
    PrayerName.asr: 23,
    PrayerName.maghrib: 24,
    PrayerName.isha: 25,
  };

  static const NotificationDetails _reminderDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'prayer_reminder_channel',
      'Pre-prayer reminders',
      channelDescription: 'Notifies you a few minutes before each prayer',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      playSound: false,
      enableVibration: true,
    ),
    iOS: DarwinNotificationDetails(
      presentSound: false,
      presentAlert: true,
      presentBadge: false,
    ),
  );
```

Add these methods at the bottom of the class, before the closing `}`:

```dart
  @override
  Future<void> scheduleStaticReminder({
    required PrayerName prayer,
    required DateTime at,
    required String title,
    required String body,
  }) async {
    if (!_initialized) {
      debugPrint('[PrayerNotif] reminder before init — skipping');
      return;
    }
    final id = _reminderIds[prayer];
    if (id == null) return;
    if (at.isBefore(DateTime.now())) {
      debugPrint('[PrayerNotif] reminder for $prayer in the past — skipping');
      return;
    }
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(at, tz.local),
      notificationDetails: _reminderDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
    debugPrint('[PrayerNotif] reminder scheduled for $prayer at $at');
  }

  @override
  Future<void> cancelAllStaticReminders() async {
    for (final id in _reminderIds.values) {
      await _plugin.cancel(id: id);
    }
  }
```

- [ ] **Step 3: Update `NotificationsRepositoryImpl.schedulePrayerReminders` to call the iOS path**

In `lib/features/notifications/data/repositories/notifications_repository_impl.dart`, replace the existing `schedulePrayerReminders` implementation with:

```dart
  @override
  Future<Either<Failure, Unit>> schedulePrayerReminders({
    required PrayerTimes prayerTimes,
    required Map<PrayerName, int> reminderMinutesByPrayer,
    required String localeCode,
  }) =>
      _runOptional('schedulePrayerReminders', () async {
        if (defaultTargetPlatform == TargetPlatform.android) {
          final filtered = <String, int>{
            for (final e in reminderMinutesByPrayer.entries)
              if (e.value > 0) e.key.name.toLowerCase(): e.value,
          };
          await native.schedulePrayerReminders(
            remindersByPrayer: filtered,
            timingsByPrayer: _lowercasePrayerKeys(prayerTimes.timings),
            localeCode: localeCode,
          );
        } else {
          await legacyScheduler.cancelAllStaticReminders();
          final date = _parseGregorian(prayerTimes.date.gregorianDate);
          if (date == null) return;
          for (final e in reminderMinutesByPrayer.entries) {
            if (e.value <= 0) continue;
            final hhmm = prayerTimes.timings[e.key];
            if (hhmm == null) continue;
            final parts = hhmm.split(':');
            if (parts.length != 2) continue;
            final hour = int.tryParse(parts[0]);
            final minute = int.tryParse(parts[1]);
            if (hour == null || minute == null) continue;
            final prayerAt =
                DateTime(date.year, date.month, date.day, hour, minute);
            final at = prayerAt.subtract(Duration(minutes: e.value));
            await legacyScheduler.scheduleStaticReminder(
              prayer: e.key,
              at: at,
              title: _prayerNameLocalized(e.key, localeCode),
              body: _reminderBody(e.key, e.value, localeCode),
            );
          }
        }
      });

  @override
  Future<Either<Failure, Unit>> cancelAllReminders() =>
      _runOptional('cancelAllReminders', () async {
        if (defaultTargetPlatform == TargetPlatform.android) {
          await native.cancelAllReminders();
        } else {
          await legacyScheduler.cancelAllStaticReminders();
        }
      });

  DateTime? _parseGregorian(String s) {
    // PrayerTimes.date.gregorianDate is "dd-MM-yyyy".
    final parts = s.split('-');
    if (parts.length != 3) return null;
    final d = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final y = int.tryParse(parts[2]);
    if (d == null || m == null || y == null) return null;
    return DateTime(y, m, d);
  }

  String _prayerNameLocalized(PrayerName p, String locale) {
    if (locale == 'ar') {
      return const {
        PrayerName.fajr: 'الفجر',
        PrayerName.dhuhr: 'الظهر',
        PrayerName.asr: 'العصر',
        PrayerName.maghrib: 'المغرب',
        PrayerName.isha: 'العشاء',
        PrayerName.sunrise: 'الشروق',
      }[p]!;
    }
    return p.name[0].toUpperCase() + p.name.substring(1);
  }

  String _reminderBody(PrayerName p, int minutes, String locale) {
    final name = _prayerNameLocalized(p, locale);
    if (locale == 'ar') {
      return '$name خلال $minutes دقيقة';
    }
    return '$name in $minutes minutes';
  }
```

- [ ] **Step 4: Run analyze + tests**

```bash
flutter analyze
flutter test
```

Expected: clean. iOS-path tests for `schedulePrayerReminders` are NOT added at the unit level (they would just exercise `flutter_local_notifications`'s mock, which is low value); coverage is via the manual checklist (Task 19, step 7).

- [ ] **Step 5: Commit**

```bash
git add lib/core/notifications/prayer_notification_scheduler.dart \
        lib/core/notifications/prayer_notification_scheduler_impl.dart \
        lib/features/notifications/data/repositories/notifications_repository_impl.dart
git commit -m "feat(notifications): iOS static reminders via legacy scheduler"
```

---

## Task 14: Add new ARB keys (English + Arabic)

**Files:**
- Modify: `lib/l10n/intl_en.arb`
- Modify: `lib/l10n/intl_ar.arb`

> The project uses `flutter_intl` which auto-regenerates `lib/generated/l10n.dart` on save. Confirm by running `flutter pub run intl_utils:generate` after the edits if your IDE doesn't auto-trigger.

- [ ] **Step 1: Add the English keys**

In `lib/l10n/intl_en.arb`, add a comma after the current last entry and then insert these seven keys inside the top-level object (immediately before the closing `}`):

```json
"adhanPerPrayerSection": "Adhan per prayer",
"reminderLabel": "Remind me",
"reminderOff": "Off",
"reminderMinutesBefore": "{minutes} min before",
"@reminderMinutesBefore": {
  "placeholders": { "minutes": { "type": "int" } }
},
"playTestAdhan": "Play test adhan",
"testAdhanScheduledSnack": "Test adhan in 5 seconds"
```

Result: every entry except the very last ends with a comma — standard JSON, no trailing commas.

- [ ] **Step 2: Add the Arabic keys**

Same pattern in `lib/l10n/intl_ar.arb`:

```json
"adhanPerPrayerSection": "الأذان لكل صلاة",
"reminderLabel": "ذكرني",
"reminderOff": "لا",
"reminderMinutesBefore": "قبل {minutes} د",
"@reminderMinutesBefore": {
  "placeholders": { "minutes": { "type": "int" } }
},
"playTestAdhan": "تشغيل أذان تجريبي",
"testAdhanScheduledSnack": "أذان تجريبي خلال ٥ ثوانٍ"
```

- [ ] **Step 3: Regenerate localization**

```bash
flutter pub run intl_utils:generate
```

Expected: no errors. `lib/generated/l10n.dart` updates with the new accessors.

- [ ] **Step 4: Confirm analyze still passes**

```bash
flutter analyze
```

Expected: clean.

- [ ] **Step 5: Commit**

```bash
git add lib/l10n/intl_en.arb lib/l10n/intl_ar.arb lib/generated/l10n.dart \
        lib/generated/intl/messages_en.dart lib/generated/intl/messages_ar.dart \
        lib/generated/intl/messages_all.dart
git commit -m "feat(i18n): add ARB keys for advanced adhan settings UI"
```

> Note: `git add` paths for the generated files may vary by environment. Use `git status` first to see which generated files actually changed and stage those exact paths.

---

## Task 15: `ReminderOffsetDropdown` widget

**Files:**
- Create: `lib/features/home/presentation/pages/widgets/reminder_offset_dropdown.dart`

- [ ] **Step 1: Create the widget**

```dart
import 'package:flutter/material.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/generated/l10n.dart';

/// Dropdown for picking a pre-prayer reminder offset.
///
/// Values: [0, 5, 10, 15] — 0 means "Off". When [enabled] is false the
/// dropdown is greyed and not interactive (its underlying value is preserved
/// in state, just visually muted).
class ReminderOffsetDropdown extends StatelessWidget {
  final int value;
  final bool enabled;
  final ValueChanged<int> onChanged;

  const ReminderOffsetDropdown({
    super.key,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  static const List<int> _values = [0, 5, 10, 15];

  String _labelFor(BuildContext context, int v) {
    if (v == 0) return S.of(context).reminderOff;
    return S.of(context).reminderMinutesBefore(v);
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: value,
          isDense: true,
          icon: Icon(
            Icons.keyboard_arrow_down,
            color: context.colorScheme.onSurfaceVariant,
            size: 20,
          ),
          dropdownColor: context.colorScheme.surfaceContainerHigh,
          style: TS.regular14.cairo.copyWith(
            color: context.colorScheme.onSurface,
          ),
          onChanged: enabled ? (v) { if (v != null) onChanged(v); } : null,
          items: [
            for (final v in _values)
              DropdownMenuItem(value: v, child: Text(_labelFor(context, v))),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Confirm analyze**

```bash
flutter analyze
```

Expected: clean.

- [ ] **Step 3: Commit**

```bash
git add lib/features/home/presentation/pages/widgets/reminder_offset_dropdown.dart
git commit -m "feat(settings): ReminderOffsetDropdown widget"
```

---

## Task 16: `PerPrayerAdhanTile` widget

**Files:**
- Create: `lib/features/home/presentation/pages/widgets/per_prayer_adhan_tile.dart`

- [ ] **Step 1: Create the widget**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/core/di/dependency_injection.dart';
import 'package:quran_app/features/home/presentation/pages/widgets/reminder_offset_dropdown.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:quran_app/generated/l10n.dart';

/// One row per prayer: localized label + adhan switch + reminder offset dropdown.
/// When the switch is off the dropdown is shown muted and disabled.
class PerPrayerAdhanTile extends StatelessWidget {
  final PrayerName prayer;
  final bool showTopDivider;

  const PerPrayerAdhanTile({
    super.key,
    required this.prayer,
    this.showTopDivider = false,
  });

  String _localizedName(BuildContext context) {
    switch (prayer) {
      case PrayerName.fajr: return S.of(context).fajr;
      case PrayerName.dhuhr: return S.of(context).dhuhr;
      case PrayerName.asr: return S.of(context).asr;
      case PrayerName.maghrib: return S.of(context).maghrib;
      case PrayerName.isha: return S.of(context).isha;
      case PrayerName.sunrise: return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        final s = state.settingsModel;
        final adhanOn = s.adhanEnabledByPrayer[prayer] ?? true;
        final reminderMinutes = s.reminderMinutesByPrayer[prayer] ?? 0;

        return Column(
          children: [
            if (showTopDivider)
              Divider(
                color: context.colorScheme.outlineVariant,
                height: 1,
                thickness: 0.5,
              ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _localizedName(context),
                          style: TS.bold16.cairo.copyWith(
                            color: context.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      Switch(
                        value: adhanOn,
                        onChanged: (v) =>
                            sl<SettingsCubit>().updateAdhanEnabled(prayer, v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        S.of(context).reminderLabel,
                        style: TS.regular14.cairo.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 12),
                      ReminderOffsetDropdown(
                        value: reminderMinutes,
                        enabled: adhanOn,
                        onChanged: (v) => sl<SettingsCubit>()
                            .updateReminderMinutes(prayer, v),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
```

- [ ] **Step 2: Confirm analyze**

```bash
flutter analyze
```

Expected: clean. The l10n keys `fajr`, `dhuhr`, etc. already exist in the ARB files (confirmed in spec).

- [ ] **Step 3: Commit**

```bash
git add lib/features/home/presentation/pages/widgets/per_prayer_adhan_tile.dart
git commit -m "feat(settings): PerPrayerAdhanTile widget"
```

---

## Task 17: `TestAdhanButton` widget + remove the debug FAB

**Files:**
- Create: `lib/features/home/presentation/pages/widgets/test_adhan_button.dart`
- Modify: `lib/features/home/presentation/pages/widgets/home_view.dart`

- [ ] **Step 1: Create the test button**

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/di/dependency_injection.dart';
import 'package:quran_app/core/notifications/prayer_notification_scheduler.dart';
import 'package:quran_app/features/notifications/data/datasources/notifications_native_data_source.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:quran_app/generated/l10n.dart';

/// Production-visible "Play test adhan" button. Fires the same native test
/// path as the prior debug FAB.
class TestAdhanButton extends StatelessWidget {
  const TestAdhanButton({super.key});

  Future<void> _onPressed(BuildContext context) async {
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;
    final localeCode =
        context.read<SettingsCubit>().state.settingsModel.isArabic ? 'ar' : 'en';
    if (isAndroid) {
      await sl<NotificationsNativeDataSource>().scheduleTestAdhan(
        delay: const Duration(seconds: 5),
        localeCode: localeCode,
      );
    } else {
      await sl<PrayerNotificationScheduler>().scheduleTestNotification(
        delay: const Duration(seconds: 5),
      );
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context).testAdhanScheduledSnack)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => _onPressed(context),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedPlayCircle,
                color: context.colorScheme.primary,
                size: 22,
              ),
              const SizedBox(width: 12),
              Text(
                S.of(context).playTestAdhan,
                style: TS.bold16.cairo.copyWith(
                  color: context.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Remove the debug FAB from `home_view.dart`**

In `lib/features/home/presentation/pages/widgets/home_view.dart`, change the `Scaffold(...)`:

```dart
    return Scaffold(
      floatingActionButton: kDebugMode
          ? FloatingActionButton.extended(
              // … all the existing FAB body …
            )
          : null,
      body: SafeArea( …
```

…by deleting the entire `floatingActionButton: …` block (top to bottom) so the Scaffold now starts with `body:`. Also remove the no-longer-needed imports (`kDebugMode`, `defaultTargetPlatform`, the two scheduler imports, the SettingsCubit import if it's only used by the FAB block).

If after the edit `home_view.dart` no longer uses any imports they were brought in solely for the FAB, remove them. Final imports should be only those used by what remains.

- [ ] **Step 3: Confirm analyze**

```bash
flutter analyze
```

Expected: clean — no unused-import warnings.

- [ ] **Step 4: Commit**

```bash
git add lib/features/home/presentation/pages/widgets/test_adhan_button.dart \
        lib/features/home/presentation/pages/widgets/home_view.dart
git commit -m "feat(settings): TestAdhanButton; retire debug FAB on home"
```

---

## Task 18: Compose the new `NotificationsSettingsPage`

**Files:**
- Modify: `lib/features/home/presentation/pages/notifications_settings_page.dart`

- [ ] **Step 1: Replace the page**

Replace the contents of `lib/features/home/presentation/pages/notifications_settings_page.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/core/di/dependency_injection.dart';
import 'package:quran_app/features/home/presentation/pages/widgets/per_prayer_adhan_tile.dart';
import 'package:quran_app/features/home/presentation/pages/widgets/setting_switch.dart';
import 'package:quran_app/features/home/presentation/pages/widgets/test_adhan_button.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:quran_app/generated/l10n.dart';

class NotificationsSettingsPage extends StatelessWidget {
  const NotificationsSettingsPage({super.key});

  static const List<PrayerName> _orderedPrayers = [
    PrayerName.fajr,
    PrayerName.dhuhr,
    PrayerName.asr,
    PrayerName.maghrib,
    PrayerName.isha,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(S.current.notifications, style: TS.bold20.cairo),
        backgroundColor: context.colorScheme.surface,
      ),
      body: SafeArea(
        child: BlocBuilder<SettingsCubit, SettingsState>(
          builder: (context, state) {
            final settings = state.settingsModel;
            return ListView(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 24, 16, 24),
              children: [
                _Header(),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: context.colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: SettingSwitch(
                    settings: settings,
                    settingTitle: S.current.pinnedPrayerTimes,
                    icons: const [
                      HugeIcons.strokeRoundedNotification01,
                      HugeIcons.strokeRoundedNotificationOff01,
                    ],
                    value: settings.isPrayerStripPinned,
                    action: () => sl<SettingsCubit>()
                        .updatePrayerStripPinned(!settings.isPrayerStripPinned),
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 4, bottom: 8),
                  child: Text(
                    S.of(context).adhanPerPrayerSection.toUpperCase(),
                    style: TS.bold12.cairo.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: context.colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < _orderedPrayers.length; i++)
                        PerPrayerAdhanTile(
                          prayer: _orderedPrayers[i],
                          showTopDivider: i > 0,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const TestAdhanButton(),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: context.colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedNotification01,
              color: context.colorScheme.primary,
              size: 26,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              S.current.notificationsScreenSubtitle,
              style: TS.regular14.cairo.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Confirm analyze**

```bash
flutter analyze
```

Expected: clean.

- [ ] **Step 3: Commit**

```bash
git add lib/features/home/presentation/pages/notifications_settings_page.dart
git commit -m "feat(settings): advanced adhan settings UI on NotificationsSettingsPage"
```

---

## Task 19: Final verification — analyze, tests, manual device checklist

**Files:** none — verification only.

- [ ] **Step 1: Run the full test suite**

```bash
flutter test
```

Expected: every test passes.

- [ ] **Step 2: Run analyze**

```bash
flutter analyze
```

Expected: no issues.

- [ ] **Step 3: Build Android APK**

```bash
cd android && ./gradlew :app:assembleDebug && cd ..
```

Expected: BUILD SUCCESSFUL.

- [ ] **Step 4: Install on device and stream logcat**

```bash
flutter install
adb logcat -c
adb logcat *:S Adhan:V AdhanReceiver:V AdhanService:V PrayerReminder:V PrayerReminderRx:V
```

- [ ] **Step 5: Manual device checklist**

Walk through these on the device. Each must pass before declaring the work complete.

| # | Scenario | Expected |
|---|---|---|
| 1 | Open `NotificationsSettingsPage`. All 5 adhan switches default to ON, all reminder dropdowns default to "Off". | Visible per layout in spec §6.1. |
| 2 | Disable Fajr adhan. Wait for next Fajr (or set device time forward). | No notification, no audio. `adb shell dumpsys alarm \| grep com.example.quran_app` shows no Fajr alarm. |
| 3 | Enable Fajr adhan, set Fajr reminder to 15 min. Wait until T-15. | Notification appears with `00:14:59 → 00:14:58 → …` countdown rendered by Android. |
| 4 | Let the reminder run until T-0. | Reminder auto-dismissed by `AdhanAlarmReceiver`; adhan notification appears immediately; logcat shows `cancelled reminder notif id=2300 for fajr`. |
| 5 | Swipe a reminder notification before T-0. | Reminder dismissed; adhan still fires at T-0. |
| 6 | Toggle Maghrib OFF while a Maghrib reminder is pending. | Reminder + adhan both cancelled. `dumpsys` confirms. |
| 7 | Switch reminder for Asr from 10 → 5 → Off in quick succession. | Three re-syncs visible in logcat; final `dumpsys` matches the final state. |
| 8 | iOS device: enable 10-min Dhuhr reminder. | Static notification at T-10 with body "Dhuhr in 10 minutes". No countdown. |
| 9 | Tap "Play test adhan". | Snackbar shows "Test adhan in 5 seconds"; adhan plays via native FGS in ~5s. |
| 10 | Disable all 5 prayer adhan toggles. | No alarms in `dumpsys`. |
| 11 | Reboot device with reminders configured. | No reminders re-armed automatically. Open app → next sync re-arms them. |
| 12 | Switch language to Arabic. Open settings page; verify all labels Arabic. Re-trigger a reminder. | Notification title/body are Arabic. |

- [ ] **Step 6: Final commit if any tweaks were needed**

If you made adjustments during the manual pass:

```bash
git add -p   # stage the tweaks explicitly
git commit -m "fix(settings): post-verification tweaks for advanced adhan UI"
```

---

## Self-Review (already performed by the plan author)

**Spec coverage:**
- §2 Goals: per-prayer on/off (Tasks 1–7, 16), reminder offset (Tasks 1–9, 15), Android live countdown (Task 9), persistence (Task 1), promoted test button (Task 17), flat page (Task 18) — all covered.
- §3 Non-goals respected: no voice selection, no volume slider, no iOS live countdown, no vibrate-only, no sunrise, no boot recovery, no feature flag.
- §4 Architecture: every component named in the architecture diagram has a task.
- §5 Data model: Tasks 1, 2.
- §6 UI: Tasks 14, 15, 16, 17, 18.
- §7 Android mechanics: Tasks 8, 9, 10, 11, 12.
- §8 iOS fallback: Task 13.
- §9 Data flow: Tasks 5, 6, 7.
- §10 MethodChannel additions: Task 11.
- §11 Test plan automated portions: Tasks 1–6 cover all Dart-side unit tests called out. Kotlin JVM tests for `PrayerReminderScheduler` were *not* spun up as separate tasks because the existing native code (`AdhanScheduler`) ships without JVM tests in this repo; we maintain parity with the established pattern. If the engineer prefers, a follow-up task to add JVM tests is straightforward.
- §11 Manual checklist: Task 19.
- §12 Migration & rollback: handled by the `_runOptional` guard in Task 5 and the additive `fromMap` defaults in Task 1.

**Placeholders:** none — every step has concrete code, exact paths, exact commands.

**Type consistency:** `enabledByPrayer` and `reminderMinutesByPrayer` use `Map<PrayerName, …>` throughout the Dart layer; `remindersByPrayer` (lowercase prayer key, int value) and `timingsByPrayer` (lowercase key, "HH:mm") are used in the data-source / channel boundary. `PrayerReminderIds.notificationIdByPrayer` is the single source of truth for `(prayer → notification ID)` on the Android side and is referenced consistently by `PrayerReminderScheduler`, `PrayerReminderReceiver`, and `AdhanAlarmReceiver`.

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-05-23-advanced-adhan-settings.md`. Two execution options:

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration.

**2. Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints.

Which approach?
