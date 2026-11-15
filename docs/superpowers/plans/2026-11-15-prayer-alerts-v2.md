# Prayer Alerts v2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Per-prayer alerts (sound, ring in silent mode, 1–60 min reminder with its own sound), a self-healing 7-day native Android schedule with miss/late detection and a Xiaomi fix path, a redesigned pinned strip, honoured toggles and bundled clips on iOS, and the comfort theme.

**Architecture:** `SettingsCubit` holds `prayerAlerts` and `StripStyle`; `AlertsSyncCubit` is the only caller of `SyncDailyAdhans` and the strip use cases and sends up to 30 cached days over the `quran_app/notifications` channel. On Android a pure Kotlin `AlertPlanner` picks slots and judges misses, `AlertStore` serialises every read and write on one executor, and the receivers route each fire to playback, a channel notification, a late notification or a record. On iOS `PrayerNotificationSchedulerImpl.scheduleAlerts` replaces the native layer.

**Tech Stack:** Flutter 3.50 (FVM), flutter_bloc + hydrated_bloc, GetIt, dartz, GoRouter, hive_ce, flutter_local_notifications 23, skeletonizer, HugeIcons; Kotlin (AlarmManager, RemoteViews, MediaPlayer), JUnit 4; Xcode project file.

**Spec:** `docs/superpowers/specs/2026-11-15-prayer-alerts-v2-design.md` (read §6–§9 and Appendices A–C before any task).

## Global Constraints

- Prefix every Flutter command with `fvm`.
- Never run bare `fvm flutter test`; use `fvm flutter test <folder-or-file>`. Full suite: `fvm flutter test test/features test/core test/config test/quran_package`, then `git status assets/` must be clean.
- No code comments at all (no doc comments, no inline comments, no XML comments in new resource files) and no redundant type annotations (owner's global rule). Code blocks in this plan already follow it.
- Never edit `lib/generated/` and never run `intl_utils`. New strings are read through `PendingS.of(context)` inside `build` and `PendingS.current` elsewhere (spec §10). Numbers in Arabic go through `toIndicNumerals(localeCode)`.
- HugeIcons stroke-rounded; skeletons (`Skeletonizer`), never spinners; `RadioGroup<T>`, never `RadioListTile.groupValue`.
- Every rule in `.claude/rules/` applies (layers, DI, `isClosed` before emit after await, `BlocSelector` for slices, paths as `AppRouter.*Path`, `GoTransitions.fade.withScale` for pushed routes, `EdgeInsetsDirectional`, colours from `context.colorScheme`).
- Commits: stage explicit paths only; never commit `docs/design-audit/` or `docs/reviews/`; every message ends with the line `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Kotlin unit tests: `cd android && ./gradlew :app:testDebugUnitTest` (Task 4 adds `testImplementation("junit:junit:4.13.2")` and `testImplementation("org.json:json:20240303")`, because Android's `org.json` is a stub in JVM tests).
- Native compile check: `fvm flutter build apk --debug`. iOS check: `plutil -lint ios/Runner.xcodeproj/project.pbxproj` and `fvm flutter build ios --no-codesign --debug`.
- Formatting: run `fvm dart format <file>…` on the Dart files a task creates or edits, before its commit. Never format the whole tree (untouched files would churn into the commit).
- Analyzer baseline on this branch: `fvm flutter analyze --no-fatal-infos` reports 1 warning and 206 infos. No task may add an issue.
- Each task ends green: its own tests, every existing test it touches, and the analyzer. Each Files block names the existing tests a task must update or delete.
- Prayer order everywhere: `fajr, dhuhr, asr, maghrib, isha` (index 0..4); sunrise never has an alert.
- Declared cross-feature widget exception: the notifications feature exports `AlertsPromptGate` (used by `home`) and `XiaomiChecklist` (used by `onboarding`). Both stay in `features/notifications/presentation/pages/widgets/`; Task 11 records the exception in `.claude/rules/feature-widgets.md`.

## Review Focus

1. **Wall-clock jumps between arming and firing** (manual clock change, timezone travel, DST): no burst of adhans, nothing reported as missed, and the window re-arms at the new local times. Pinned by `AlertPlannerTest.route_skipsWhenClockMovedAfterArming` and `detectMisses_ignoresTriggersBeforeClockChange` (Task 4).
2. **Upgrading from v1 data**: settings with only the legacy maps (including out-of-range or wrongly typed values), a v1 snapshot with `clips`, and v1 pending alarms without `sound`. Alerts keep firing with v1 behaviour until the first sync and nothing throws. Pinned by `SettingsModel migration` tests (Task 2) and `parseAdhanSnapshot_legacyClips`, `route_legacyExtrasLateIsMissed` (Task 4).
3. **Messy cached days**: duplicate dates, gaps, past dates, malformed times (`"25:00"`, `"5:7x"`, `""`), and every prayer disabled. The planner skips bad entries, never throws, and disabling everything cancels every armed slot. Pinned by `planAdhans_dedupesAndSkipsMalformed` and `planAdhans_emptyAlertsCancelsAllSlots` (Task 4).
4. **The test adhan**: it must use the Dhuhr alert's sound, write no record or armed-log entry (so it never masks a real Dhuhr miss), and never take the legacy branch. Pinned by `AdhanTestExtrasTest` (Task 4) and `scheduleTestAdhan sends Dhuhr sound` (Task 3).
5. **Arabic digits in composed strings**: `PendingS.alerts_minutes` and `alerts_enabledCount` return ASCII digits, so every summary, slider label, Settings subtitle and status date must pass through `toIndicNumerals`. Pinned by `alertSummary renders Arabic-Indic digits` (Task 8) and `settings row subtitle uses Arabic digits` (Task 8).

---

In test snippets, `...` stands for arrange code (mocks, fixtures, pumping) built with the helpers the test file already has; the names, values and assertions shown are required. Kotlin paths: `K/` = `android/app/src/main/kotlin/com/example/quran_app/`, `T/` = `android/app/src/test/kotlin/com/example/quran_app/`.

## File map

| Area | Files |
|---|---|
| Strings | `lib/l10n/intl_{ar,en}.arb`, `lib/core/localization/pending_s.dart` |
| Domain | `lib/features/notifications/domain/entities/{prayer_alert,strip_style,reliability_status,system_settings_target,preview_sound,strip_render_style}.dart`, `domain/services/alerts_status_resolver.dart`, `domain/services/alerts_prompt_picker.dart`, `domain/usecases/{get_reliability_status,ack_missed_alerts,open_system_settings,preview_alert_sound,stop_alert_preview,schedule_test_adhan,get_cached_prayer_days}.dart` |
| Settings | `lib/features/settings/{domain/entities/settings.dart,data/models/settings_model.dart,presentation/cubit/settings_cubit.dart,presentation/pages/settings_page.dart}` |
| Data | `lib/features/notifications/data/{datasources/notifications_native_data_source.dart,datasources/notifications_local_data_source.dart,models/reliability_status_model.dart,repositories/notifications_repository_impl.dart}` |
| Presentation | `lib/features/notifications/presentation/{cubit,pages,utils}/…` (Tasks 7, 8, 10, 11); `notifications_settings_page.dart` and `test_adhan_button.dart` move from `features/home` to `features/notifications` (Task 8) |
| Core widgets | `lib/core/widgets/design/{app_settings_tile,app_option_sheet}.dart` |
| Android | `android/app/src/main/kotlin/com/example/quran_app/{AlertPlanner,AlertStore,AlertChannels,LocaleContext,AdhanHealReceiver,ReliabilityReader,SystemSettingsLauncher,SoundPreviewPlayer}.kt` (new) + existing schedulers, receivers, plugin, strip files; `android/app/src/test/kotlin/com/example/quran_app/*Test.kt` |
| iOS | `lib/core/notifications/{prayer_notification_scheduler.dart,prayer_notification_scheduler_impl.dart,ios_alert_plan.dart}`, `ios/Runner/*.caf`, `ios/Runner.xcodeproj/project.pbxproj` |
| Theme | `lib/config/theme/app_palette.dart` |

---

### Task 1: Strings

Mostly done and uncommitted. This task verifies and commits the strings together with the spec and this plan. Native strings are not here: Task 4 adds the late-notification strings and `channel_alert_silent`; Task 5 adds the other four channel names, changes the existing `app_name` values and points the manifest label at it.

**Files:**
- Verify: `lib/l10n/intl_ar.arb`, `lib/l10n/intl_en.arb`, `lib/core/localization/pending_s.dart`
- Test: `test/core/localization/pending_s_test.dart`
- Commit also: `docs/superpowers/specs/2026-11-15-prayer-alerts-v2-design.md`, `docs/superpowers/plans/2026-11-15-prayer-alerts-v2.md`

**Interfaces:**
- Produces: `PendingS.of(BuildContext)`, `PendingS.current`, one getter or method per Appendix A key with the ARB key as its name. Placeholder methods take `String` (`alerts_status_ok(String date)`, `alerts_summary_reminder(String minutes)`, `alerts_sheet_reminderValue(String minutes)`, `alerts_sheet_reminderArrives(String time)`, `alerts_picker_preview(String sound)`, `strip_nextIn(String prayer)`, `rel_scheduledUntil(String date)`, `missed_title(String prayer)`, `late_title(String prayer)`); plurals take `num` (`alerts_minutes(num count)`, `alerts_enabledCount(num count)`) and return ASCII digits.

- [ ] **Step 1: Check the keys exist in both ARBs**

Run: `grep -c '"late_title"\|"missed_bodyGeneric"\|"alerts_minutes"\|"alerts_enabledCount"\|"strip_nextIn"' lib/l10n/intl_ar.arb lib/l10n/intl_en.arb`
Expected: `5` for each file.

- [ ] **Step 2: Run the parity test**

Run: `fvm flutter test test/core/localization/pending_s_test.dart`
Expected: all tests pass (parity for every simple getter and placeholder method, plural spot checks).

- [ ] **Step 3: Analyze**

Run: `fvm flutter analyze --no-fatal-infos`
Expected: 1 warning, 206 infos.

- [ ] **Step 4: Commit**

```bash
git add lib/l10n/intl_ar.arb lib/l10n/intl_en.arb lib/core/localization/pending_s.dart test/core/localization/pending_s_test.dart docs/superpowers/specs/2026-11-15-prayer-alerts-v2-design.md docs/superpowers/plans/2026-11-15-prayer-alerts-v2.md
git commit -m "feat(alerts): add prayer alerts v2 strings, PendingS bridge, spec and plan

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 2: Alert model, migration and cubit intents

**Files:**
- Create: `lib/features/notifications/domain/entities/prayer_alert.dart`, `lib/features/notifications/domain/entities/strip_style.dart`
- Modify: `lib/features/settings/domain/entities/settings.dart`, `lib/features/settings/data/models/settings_model.dart`, `lib/features/settings/presentation/cubit/settings_cubit.dart`
- Modify (compile shims, deleted in Tasks 7–8): `lib/features/home/presentation/pages/home_page.dart`, `lib/features/home/presentation/pages/widgets/per_prayer_adhan_tile.dart`
- Test: `test/features/notifications/domain/entities/prayer_alert_test.dart` (new), `test/features/settings/data/models/settings_model_alerts_test.dart` (new), `test/features/settings/presentation/cubit/settings_cubit_test.dart`
- Update: `test/features/settings/settings_cubit_test.dart` (delete lines 118–277: the legacy-map round-trip, default, merge and drop cases, the `updateAdhanEnabled`/`updateReminderMinutes` blocTests and the assertion case; keep the rest, and remove the now-unused `prayer_name.dart` import at line 7)

**Interfaces:**
- Consumes: `PrayerName` (`lib/core/constants/prayer_name.dart`).
- Produces:
  - `enum PrayerSound { adhan, tone, vibrate, silent }`, `enum ReminderSound { tone, vibrate, silent }`, `const alertPrayers = [PrayerName.fajr, PrayerName.dhuhr, PrayerName.asr, PrayerName.maghrib, PrayerName.isha]`.
  - `class PrayerAlert extends Equatable` with `const PrayerAlert({this.enabled = true, this.sound = PrayerSound.adhan, this.ringInSilent = false, this.reminderEnabled = false, this.reminderMinutes = 10, this.reminderSound = ReminderSound.tone})`, `copyWith(...)`, `int? get effectiveReminderMinutes`, `static const minReminderMinutes = 1`, `static const maxReminderMinutes = 60`.
  - `enum StripHighlight { app, darkGreen, emerald, blue, indigo, maroon, bronze }`, `enum StripBackground { auto, mint, sand, sky, rose }`, `enum StripShape { none, rounded, pill, outline }`, `class StripStyle extends Equatable` with `const StripStyle({this.expanded = true, this.showCountdown = true, this.highlight = StripHighlight.app, this.background = StripBackground.auto, this.shape = StripShape.rounded})` and `copyWith`.
  - `Settings` fields `Map<PrayerName, PrayerAlert> prayerAlerts` (default `Settings.defaultPrayerAlerts`), `StripStyle stripStyle`, `bool alertsIntroSeen = false`, `bool xiaomiAutostartConfirmed = false`, `bool xiaomiBatteryConfirmed = false`, and `int get enabledAlertCount`. `adhanEnabledByPrayer`, `reminderMinutesByPrayer`, `defaultAdhanEnabled`, `defaultReminderMinutes` and `validReminderMinutes` are removed. `isPrayerStripPinned` stays and is the strip's "show" switch.
  - `SettingsCubit`: `void updatePrayerAlert(PrayerName prayer, PrayerAlert alert)`, `void applyAlertToAll({required bool enabled, PrayerSound? sound, bool? reminderEnabled, int? reminderMinutes})`, `void updateStripStyle(StripStyle style)`, `void markAlertsIntroSeen()`, `void setXiaomiAutostartConfirmed(bool value)`, `void setXiaomiBatteryConfirmed(bool value)`, `void clearXiaomiConfirmations()`. `completeOnboarding()` also sets `alertsIntroSeen`. `updateAdhanEnabled` and `updateReminderMinutes` are removed.
  - Persisted keys: `prayerAlerts: {fajr: {enabled, sound, ringInSilent, reminderEnabled, reminderMinutes, reminderSound}}`, `stripStyle: {expanded, showCountdown, highlight, background, shape}`, `alertsIntroSeen`, `xiaomiAutostartConfirmed`, `xiaomiBatteryConfirmed`. Enum values are stored by `.name`.

- [ ] **Step 1: Write the failing entity test**

```dart
test('effectiveReminderMinutes needs enabled and reminderEnabled', () {
  expect(const PrayerAlert(reminderEnabled: true, reminderMinutes: 15).effectiveReminderMinutes, 15);
  expect(const PrayerAlert(enabled: false, reminderEnabled: true).effectiveReminderMinutes, isNull);
  expect(const PrayerAlert().effectiveReminderMinutes, isNull);
});
test('defaults match spec §6', () {
  const a = PrayerAlert();
  expect([a.enabled, a.sound, a.ringInSilent, a.reminderEnabled, a.reminderMinutes, a.reminderSound],
      [true, PrayerSound.adhan, false, false, 10, ReminderSound.tone]);
  expect(const StripStyle(), const StripStyle(expanded: true, showCountdown: true, highlight: StripHighlight.app, background: StripBackground.auto, shape: StripShape.rounded));
});
```

- [ ] **Step 2: Write the failing migration and round-trip tests** in `settings_model_alerts_test.dart`

```dart
group('SettingsModel migration', () {
  test('derives prayerAlerts from the legacy maps', () {
    final m = SettingsModel.fromMap({
      'adhanEnabledByPrayer': {'fajr': true, 'dhuhr': false, 'asr': true},
      'reminderMinutesByPrayer': {'fajr': 15, 'dhuhr': 5, 'asr': 0},
    });
    expect(m.prayerAlerts[PrayerName.fajr], const PrayerAlert(reminderEnabled: true, reminderMinutes: 15));
    expect(m.prayerAlerts[PrayerName.dhuhr], const PrayerAlert(enabled: false, reminderEnabled: true, reminderMinutes: 5));
    expect(m.prayerAlerts[PrayerName.asr], const PrayerAlert());
    expect(m.prayerAlerts.keys, alertPrayers);
    expect(m.prayerAlerts[PrayerName.dhuhr]!.effectiveReminderMinutes, isNull);
  });
  test('clamps out-of-range and ignores wrong types without throwing', () {
    final m = SettingsModel.fromMap({
      'adhanEnabledByPrayer': {'fajr': 'yes'},
      'reminderMinutesByPrayer': {'fajr': 120, 'isha': -3, 'asr': '7'},
    });
    expect(m.prayerAlerts[PrayerName.fajr]!.enabled, isTrue);
    expect(m.prayerAlerts[PrayerName.fajr]!.reminderMinutes, 60);
    expect(m.prayerAlerts[PrayerName.isha], const PrayerAlert());
    expect(m.prayerAlerts[PrayerName.asr], const PrayerAlert());
  });
  test('prayerAlerts wins over legacy maps and unknown enum names fall back', () {
    final m = SettingsModel.fromMap({
      'prayerAlerts': {'fajr': {'sound': 'trumpet', 'reminderMinutes': 0, 'reminderSound': 'silent'}},
      'adhanEnabledByPrayer': {'fajr': false},
    });
    expect(m.prayerAlerts[PrayerName.fajr], const PrayerAlert(reminderMinutes: 1, reminderSound: ReminderSound.silent));
  });
  test('upgrader has alertsIntroSeen false and ringInSilent false', () {
    final m = SettingsModel.fromMap({'adhanEnabledByPrayer': {'fajr': true}});
    expect(m.alertsIntroSeen, isFalse);
    expect(m.prayerAlerts.values.every((a) => !a.ringInSilent), isTrue);
  });
  test('round-trips every new field', () {
    const alerts = {PrayerName.fajr: PrayerAlert(sound: PrayerSound.vibrate, ringInSilent: true, reminderEnabled: true, reminderMinutes: 42, reminderSound: ReminderSound.vibrate)};
    final m = SettingsModel(isFormat12Hours: false, isArabic: true).copyWith(
      prayerAlerts: {...Settings.defaultPrayerAlerts, ...alerts},
      stripStyle: const StripStyle(expanded: false, highlight: StripHighlight.maroon, background: StripBackground.rose, shape: StripShape.outline),
      alertsIntroSeen: true, xiaomiAutostartConfirmed: true, xiaomiBatteryConfirmed: true,
    );
    expect(SettingsModel.fromMap(m.toMap()), m);
    expect(m.toMap().containsKey('adhanEnabledByPrayer'), isFalse);
  });
});
```

- [ ] **Step 3: Write the failing cubit tests** (append to `test/features/settings/presentation/cubit/settings_cubit_test.dart`; that file sets `HydratedBloc.storage = _MemStorage()` in `setUpAll` and builds `final c = SettingsCubit();` per test, so each test below starts with `final cubit = SettingsCubit();`)

```dart
test('updatePrayerAlert clamps reminder minutes to 1..60', () {
  cubit.updatePrayerAlert(PrayerName.asr, const PrayerAlert(reminderMinutes: 90));
  expect(cubit.state.settingsModel.prayerAlerts[PrayerName.asr]!.reminderMinutes, 60);
});
test('applyAlertToAll sets all five prayers', () {
  cubit.applyAlertToAll(enabled: true, sound: PrayerSound.tone, reminderEnabled: true, reminderMinutes: 5);
  expect(cubit.state.settingsModel.prayerAlerts.values.toSet(), {const PrayerAlert(sound: PrayerSound.tone, reminderEnabled: true, reminderMinutes: 5)});
  cubit.applyAlertToAll(enabled: false);
  expect(cubit.state.settingsModel.enabledAlertCount, 0);
});
test('completeOnboarding also marks alertsIntroSeen', () {
  cubit.completeOnboarding();
  expect(cubit.state.settingsModel.hasCompletedOnboarding, isTrue);
  expect(cubit.state.settingsModel.alertsIntroSeen, isTrue);
});
test('clearXiaomiConfirmations resets both flags', () {
  cubit..setXiaomiAutostartConfirmed(true)..setXiaomiBatteryConfirmed(true)..clearXiaomiConfirmations();
  expect(cubit.state.settingsModel.xiaomiAutostartConfirmed, isFalse);
  expect(cubit.state.settingsModel.xiaomiBatteryConfirmed, isFalse);
});
```

- [ ] **Step 4: Run the tests to verify they fail**

Run: `fvm flutter test test/features/notifications/domain/entities/prayer_alert_test.dart test/features/settings`
Expected: compile errors (`PrayerAlert`, `prayerAlerts` undefined).

- [ ] **Step 5: Implement the entities, `Settings`, `SettingsModel` and `SettingsCubit`**

`Settings.defaultPrayerAlerts` is a `static const` map with the five entries written out (`PrayerName.fajr: PrayerAlert(), …`); a collection-`for` is not allowed in a const literal, and the constructor default needs a const. `enabledAlertCount` counts `enabled`. Migration lives in `SettingsModel` and decides how legacy data maps:

```dart
static Map<PrayerName, PrayerAlert> _readPrayerAlerts(Map<String, dynamic> map) {
  final raw = map['prayerAlerts'];
  if (raw is Map) {
    return {for (final p in alertPrayers) p: _alertFromMap(raw[p.name])};
  }
  final enabled = map['adhanEnabledByPrayer'];
  final minutes = map['reminderMinutesByPrayer'];
  return {
    for (final p in alertPrayers)
      p: _migrateLegacy(
        enabled is Map ? enabled[p.name] : null,
        minutes is Map ? minutes[p.name] : null,
      ),
  };
}

static PrayerAlert _migrateLegacy(Object? enabled, Object? minutes) {
  final m = minutes is int ? minutes : 0;
  return PrayerAlert(
    enabled: enabled is bool ? enabled : true,
    reminderEnabled: m > 0,
    reminderMinutes: m > 0 ? m.clamp(1, 60) : 10,
  );
}
```

`_alertFromMap(Object? raw)` returns `const PrayerAlert()` when `raw` is not a `Map`, reads each field with a type check, clamps `reminderMinutes` to 1..60, and resolves enums with `values.firstWhereOrNull((e) => e.name == raw)` falling back to the default. `_readStripStyle` does the same for `stripStyle`. `alertsIntroSeen`, `xiaomiAutostartConfirmed`, `xiaomiBatteryConfirmed` default to `false` in `fromMap`. Add the five fields to the constructor, `copyWith`, `props` and `toMap` of both `Settings` and `SettingsModel`.

Compile shims, removed later: in `home_page.dart` build `enabledByPrayer: {for (final e in s.prayerAlerts.entries) e.key: e.value.enabled}` and `reminderMinutesByPrayer: {for (final e in s.prayerAlerts.entries) e.key: e.value.effectiveReminderMinutes ?? 0}`, and replace the two `_map*Eq` checks with `!mapEquals(p.prayerAlerts, c.prayerAlerts)` (delete `_mapBoolEq`/`_mapIntEq`). In `per_prayer_adhan_tile.dart` the switch calls `updatePrayerAlert(prayer, alert.copyWith(enabled: v))`; the dropdown shows `alert.reminderEnabled && const [5, 10, 15].contains(alert.reminderMinutes) ? alert.reminderMinutes : 0` and its `onChanged(v)` writes `alert.copyWith(reminderEnabled: v > 0, reminderMinutes: v > 0 ? v : alert.reminderMinutes)`.

- [ ] **Step 6: Run the tests to verify they pass**

Run: `fvm flutter test test/features/notifications/domain/entities test/features/settings test/features/home`
Expected: PASS.

- [ ] **Step 7: Analyze**

Run: `fvm flutter analyze --no-fatal-infos`
Expected: no new issues versus the baseline.

- [ ] **Step 8: Commit**

```bash
git add lib/features/notifications/domain/entities/prayer_alert.dart lib/features/notifications/domain/entities/strip_style.dart lib/features/settings/domain/entities/settings.dart lib/features/settings/data/models/settings_model.dart lib/features/settings/presentation/cubit/settings_cubit.dart lib/features/home/presentation/pages/home_page.dart lib/features/home/presentation/pages/widgets/per_prayer_adhan_tile.dart test/features/notifications/domain/entities/prayer_alert_test.dart test/features/settings/data/models/settings_model_alerts_test.dart test/features/settings/presentation/cubit/settings_cubit_test.dart test/features/settings/settings_cubit_test.dart
git commit -m "feat(alerts): add PrayerAlert and StripStyle with v1 settings migration

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 3: Dart native contract (data source, repository, use cases)

The channel table below is the contract. Tasks 4, 5, 6 and 9 implement its native side and must not rename a method or key. The strip rows are listed here for completeness; their Dart entity changes ship with Task 9 so all strip tests change together.

| Method | Arguments | Returns |
|---|---|---|
| `scheduleDailyAdhans` | `days: [{date: 'yyyy-MM-dd', timings: {fajr, sunrise, dhuhr, asr, maghrib, isha: 'HH:mm'}}]` (all six timings), `alerts: {<prayer>: {sound: 'adhan'\|'tone'\|'vibrate'\|'silent', ringInSilent: bool}}` (enabled prayers only), `localeCode: 'ar'\|'en'` | `null` |
| `schedulePrayerReminders` | `days` (same), `reminders: {<prayer>: {minutes: 1..60, reminderSound: 'tone'\|'vibrate'\|'silent'}}` (only prayers with `effectiveReminderMinutes != null`), `localeCode` | `null` |
| `scheduleTestAdhan` | `delaySeconds: int`, `localeCode`, `sound`, `ringInSilent` (from the Dhuhr alert) | `null` |
| `cancelAllAdhans`, `cancelAllReminders`, `disableStrip`, `stopPreview` | none | `null` |
| `ackMissed` | `upTo: int` (epoch ms, the newest `at` among the missed and late items the user was shown) | `null` |
| `getReliabilityStatus` | none | `{notificationsEnabled, channelBlocked, exactAlarmsAllowed, batteryUnrestricted, isXiaomi, usesAlarmClock: bool, scheduledUntil: int? (epoch ms), snapshotUntil: String? ('yyyy-MM-dd'), missed: [{prayer: 'isha', at: int}], late: [{prayer, at}]}` |
| `openSystemSettings` | `target: 'notifications'\|'exactAlarm'\|'battery'\|'autostart'\|'xiaomiBattery'` | `bool` (whether a settings screen opened; Dart ignores it) |
| `previewSound` | `sound: 'adhan'\|'tone'`, `prayer: 'fajr'…'isha'` | `null` |
| `previewEnded` (native → Dart, main thread) | `sound: 'adhan'\|'tone'`; sent when a preview completes, errors or fails to start, never after `stopPreview` | none (Dart's data source holds the channel's only handler) |
| `enableStrip`, `refreshStrip` (Task 9) | `days: [{dateKey, cells: [{label, time, minutes, nextLabel}], nextTag, hijriDateLabel, weekdayLabel, localeCode, isFriday}]`, `style: {expanded, countdown: bool, highlightDay, highlightNight, pillTextDay, pillTextNight: '#AARRGGBB', backgroundDay?, backgroundNight?: '#AARRGGBB', shape: 'none'\|'rounded'\|'pill'\|'outline'}` | `null` |

Channel key renames: `scheduleDailyAdhans` drops `clips` and `volume` and adds `alerts`; `schedulePrayerReminders` renames `remindersByPrayer` → `reminders` (native reads `args["remindersByPrayer"]` at `PrayerStripPlugin.kt:146` until Task 4). Between this commit and Task 4 the Android build sends the new keys while native still reads the old ones, so no adhan arms and reminders are wiped (native sees an empty map and cancels them all). Do not install the branch on a device before Task 4 lands.

**Files:**
- Create: `lib/features/notifications/domain/entities/reliability_status.dart`, `system_settings_target.dart`, `preview_sound.dart`; `lib/features/notifications/data/models/reliability_status_model.dart`; use cases `get_reliability_status.dart`, `ack_missed_alerts.dart`, `open_system_settings.dart`, `preview_alert_sound.dart`, `stop_alert_preview.dart`, `schedule_test_adhan.dart`, `watch_preview_ended.dart` under `lib/features/notifications/domain/usecases/`
- Modify: `lib/features/notifications/data/datasources/notifications_native_data_source.dart`, `lib/features/notifications/data/repositories/notifications_repository_impl.dart`, `lib/features/notifications/domain/repositories/notifications_repository.dart`, `lib/features/notifications/domain/usecases/sync_daily_adhans.dart`, `lib/features/notifications/notifications_di.dart`, `lib/features/home/presentation/pages/home_page.dart` (drop the Task 2 shim maps, pass `alerts`), `lib/features/home/presentation/pages/widgets/test_adhan_button.dart` (call `ScheduleTestAdhan`)
- Delete: `lib/features/notifications/domain/entities/adhan_audio_settings.dart`, `test/features/notifications/domain/entities/adhan_audio_settings_test.dart`
- Test: `test/features/notifications/data/datasources/notifications_native_data_source_test.dart`, `test/features/notifications/data/repositories/notifications_repository_impl_test.dart`, `test/features/notifications/domain/usecases/sync_daily_adhans_test.dart`, `test/features/notifications/data/models/reliability_status_model_test.dart` (new)

**Interfaces:**
- Consumes: `PrayerAlert`, `PrayerSound`, `ReminderSound`, `alertPrayers` (Task 2).
- Produces:
  - `class MissedAlert extends Equatable { final PrayerName prayer; final DateTime at; }`
  - `ReliabilityStatus.copyWith({bool? notificationsEnabled, bool? channelBlocked, bool? exactAlarmsAllowed, bool? batteryUnrestricted, bool? isXiaomi, bool? usesAlarmClock, DateTime? scheduledUntil, bool clearScheduledUntil = false, DateTime? snapshotUntil, List<MissedAlert>? missed, List<MissedAlert>? late})` (used by Tasks 8 and 11).
  - `class ReliabilityStatus extends Equatable` with `const ReliabilityStatus({required this.notificationsEnabled, required this.channelBlocked, required this.exactAlarmsAllowed, required this.batteryUnrestricted, required this.isXiaomi, required this.usesAlarmClock, this.scheduledUntil, this.snapshotUntil, this.missed = const [], this.late = const []})` (bools, `DateTime?`, `List<MissedAlert>`); `const ReliabilityStatus.ios({required bool notificationsEnabled, DateTime? scheduledUntil})` (exact alarms and battery true, Xiaomi false, `usesAlarmClock` false, no misses).
  - `enum SystemSettingsTarget { notifications, exactAlarm, battery, autostart, xiaomiBattery }`; `enum PreviewSound { adhan, tone }`.
  - `NotificationsRepository`: `scheduleDailyAdhans({required List<PrayerTimes> days, required Map<PrayerName, PrayerAlert> alerts, required String localeCode})`, `schedulePrayerReminders({same})`, `scheduleTestAdhan({required PrayerAlert alert, required String localeCode, Duration delay = const Duration(seconds: 5)})`, `Future<Either<Failure, ReliabilityStatus>> getReliabilityStatus()`, `ackMissedAlerts({required DateTime upTo})`, `openSystemSettings(SystemSettingsTarget target)`, `previewSound({required PreviewSound sound, required PrayerName prayer})`, `stopPreview()`; all others return `Either<Failure, Unit>`. `Stream<PreviewSound> previewEnded()` maps native names and drops unknown ones; empty on iOS.
  - Use cases (lazy singletons): `GetReliabilityStatus` (`NoParams`), `AckMissedAlerts` (`AckMissedAlertsParams({required DateTime upTo})`), `OpenSystemSettings` (`SystemSettingsTarget`), `PreviewAlertSound` (`PreviewAlertSoundParams({required PreviewSound sound, required PrayerName prayer})`), `StopAlertPreview` (`NoParams`), `WatchPreviewEnded` (`StreamUseCase<PreviewSound, NoParams>`), `ScheduleTestAdhan` (`ScheduleTestAdhanParams({required PrayerAlert alert, required String localeCode})`).
  - `SyncDailyAdhansParams({required List<PrayerTimes> days, required Map<PrayerName, PrayerAlert> alerts, required String localeCode})` (no `audio`, no maps).
  - Data source: `scheduleDailyAdhans({required List<Map<String, dynamic>> days, required Map<String, Map<String, Object>> alerts, required String localeCode})`, `schedulePrayerReminders({days, required Map<String, Map<String, Object>> reminders, localeCode})`, `scheduleTestAdhan({Duration delay, String localeCode, required String sound, required bool ringInSilent})`, `Future<Map<String, Object?>> getReliabilityStatus()`, `ackMissed({required int upTo})` (sends `{'upTo': upTo}`), `openSystemSettings(String target)`, `previewSound({required String sound, required String prayer})`, `stopPreview()`, `Stream<String> get previewEnded` (a broadcast stream fed by `setMethodCallHandler` on the channel, set on first access).

- [ ] **Step 1: Write the failing data-source tests** (replace the two tests at `notifications_native_data_source_test.dart:65-84` and `:103-121`, which use the removed `clipAssetByPrayer`/`volume`/`remindersByPrayer`; keep the strip, cancel and missing-plugin tests)

```dart
test('scheduleDailyAdhans sends days, alerts and localeCode', () async {
  await ds.scheduleDailyAdhans(
    days: [{'date': '2026-11-15', 'timings': {'fajr': '04:52'}}],
    alerts: {'fajr': {'sound': 'tone', 'ringInSilent': false}},
    localeCode: 'ar',
  );
  final args = calls.single.arguments as Map;
  expect(calls.single.method, 'scheduleDailyAdhans');
  expect(args['alerts'], {'fajr': {'sound': 'tone', 'ringInSilent': false}});
  expect(args.containsKey('clips'), isFalse);
});
test('getReliabilityStatus returns the native map', () async { ...mock returns {'isXiaomi': true}... expect(result['isXiaomi'], true); });
test('openSystemSettings sends the target name', () async { ... expect(args, {'target': 'xiaomiBattery'}); });
test('previewSound sends sound and prayer', () async { ... expect(args, {'sound': 'adhan', 'prayer': 'fajr'}); });
```

- [ ] **Step 2: Write the failing model test**

```dart
test('ReliabilityStatusModel.fromMap parses every field', () {
  final s = ReliabilityStatusModel.fromMap({
    'notificationsEnabled': true, 'channelBlocked': false, 'exactAlarmsAllowed': true,
    'batteryUnrestricted': false, 'isXiaomi': true, 'usesAlarmClock': true,
    'scheduledUntil': DateTime(2026, 11, 21, 18, 16).millisecondsSinceEpoch,
    'snapshotUntil': '2026-12-31',
    'missed': [{'prayer': 'isha', 'at': DateTime(2026, 11, 14, 18, 40).millisecondsSinceEpoch}],
    'late': [],
  });
  expect(s.missed.single, MissedAlert(prayer: PrayerName.isha, at: DateTime(2026, 11, 14, 18, 40)));
  expect(s.snapshotUntil, DateTime(2026, 12, 31));
  expect(s.batteryUnrestricted, isFalse);
});
test('missing or mistyped fields fall back safely', () {
  final s = ReliabilityStatusModel.fromMap({'missed': [{'prayer': 'sunset', 'at': 'x'}]});
  expect(s.notificationsEnabled, isTrue);
  expect(s.missed, isEmpty);
  expect(s.scheduledUntil, isNull);
});
```

Fallbacks: booleans default `true` except `isXiaomi`, `channelBlocked` and `usesAlarmClock` (default `false`); entries with an unknown prayer or a non-int `at` are dropped.

- [ ] **Step 3: Write the failing repository tests** (replace the `scheduleDailyAdhans` and `schedulePrayerReminders` groups)

```dart
test('Android: sends all six timings and only enabled prayers in alerts', () async {
  await repo.scheduleDailyAdhans(days: [pt], alerts: {
    ...Settings.defaultPrayerAlerts,
    PrayerName.asr: const PrayerAlert(enabled: false),
    PrayerName.fajr: const PrayerAlert(sound: PrayerSound.vibrate, ringInSilent: true),
  }, localeCode: 'ar');
  final captured = verify(() => native.scheduleDailyAdhans(days: captureAny(named: 'days'), alerts: captureAny(named: 'alerts'), localeCode: 'ar')).captured;
  expect((captured[0] as List).single['timings'].keys, containsAll(['fajr', 'sunrise', 'dhuhr', 'asr', 'maghrib', 'isha']));
  expect((captured[1] as Map).keys, ['fajr', 'dhuhr', 'maghrib', 'isha']);
  expect(captured[1]['fajr'], {'sound': 'vibrate', 'ringInSilent': true});
});
test('Android: reminders only for enabled prayers with reminderEnabled', () async {
  await repo.schedulePrayerReminders(days: [pt], alerts: {
    ...Settings.defaultPrayerAlerts,
    PrayerName.fajr: const PrayerAlert(reminderEnabled: true, reminderMinutes: 15, reminderSound: ReminderSound.silent),
    PrayerName.asr: const PrayerAlert(enabled: false, reminderEnabled: true),
  }, localeCode: 'en');
  expect(capturedReminders, {'fajr': {'minutes': 15, 'reminderSound': 'silent'}});
});
test('scheduleTestAdhan sends Dhuhr sound', () async {
  await repo.scheduleTestAdhan(alert: const PrayerAlert(sound: PrayerSound.tone), localeCode: 'ar');
  verify(() => native.scheduleTestAdhan(delay: const Duration(seconds: 5), localeCode: 'ar', sound: 'tone', ringInSilent: false)).called(1);
});
test('iOS: getReliabilityStatus is Right with the permission flag', () async {
  debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  when(() => scheduler.areNotificationsEnabled()).thenAnswer((_) async => false);
  final r = await repo.getReliabilityStatus();
  expect(r, const Right(ReliabilityStatus.ios(notificationsEnabled: false)));
  debugDefaultTargetPlatformOverride = null;
});
test('iOS: openSystemSettings, previewSound, ackMissedAlerts(upTo: …) are Right no-ops', () async { ... verifyZeroInteractions(native) ... });
test('Android: getReliabilityStatus maps PlatformNotImplemented to Left(PlatformNotSupportedFailure)', () async { ... });
```

The repository test's legacy mock is named `scheduler` (`_MockLegacyScheduler`). Keep the existing iOS `scheduleDailyAdhans` test calling `legacyScheduler.scheduleDailyPrayerNotifications(days.first)` (Task 12 replaces it). iOS `schedulePrayerReminders` keeps the static-reminder path, reading `alert.effectiveReminderMinutes`.

- [ ] **Step 4: Update `sync_daily_adhans_test.dart`** to pass `alerts: Settings.defaultPrayerAlerts` and verify both repository calls receive the same `alerts` map; keep the "returns Left when scheduleDailyAdhans fails (skips reminders)" case.

- [ ] **Step 5: Run the tests to verify they fail**

Run: `fvm flutter test test/features/notifications`
Expected: compile errors on the new signatures.

- [ ] **Step 6: Implement**

- Data source: `schedulePrayerReminders` sends the key `reminders` (not `remindersByPrayer`); new methods use `_invoke`; `getReliabilityStatus` uses `_channel.invokeMapMethod<String, Object?>` (empty map on `null`) and maps `MissingPluginException` to `PlatformNotImplementedException`.
- Repository Android payloads follow the table; `alerts` is built with `for (final p in alertPrayers) if (alerts[p]?.enabled ?? false) p.name: {'sound': a.sound.name, 'ringInSilent': a.ringInSilent}`; `timings` keeps every entry of `pt.timings` (sunrise included). Replace `_run` with a generic `Future<Either<Failure, T>> _runValue<T>(Future<T> Function() body)` (same mapping: `PlatformNotImplementedException` → `PlatformNotSupportedFailure('Not supported on this platform.')`, anything else → `UnknownNotificationFailure(e.toString())`; the old strip-specific message goes) and keep `_run(body)` as `_runValue(() async { await body(); return unit; })`. `getReliabilityStatus` uses `_runValue` mapping through `ReliabilityStatusModel.fromMap`. Reliability, ack, settings and preview calls use these on Android and return `Right` without touching `native` on iOS (`getReliabilityStatus` returns `ReliabilityStatus.ios(notificationsEnabled: await legacyScheduler.areNotificationsEnabled())`). `scheduleTestAdhan` on iOS calls `legacyScheduler.scheduleTestNotification(delay: delay)`.
- `TestAdhanButton` calls `sl<ScheduleTestAdhan>()(ScheduleTestAdhanParams(alert: settings.prayerAlerts[PrayerName.dhuhr]!, localeCode: …))` instead of the data source.
- `home_page.dart`: `SyncDailyAdhansParams(days: days, alerts: settings.prayerAlerts, localeCode: locale)`.
- Register the six use cases in `initNotifications()` as lazy singletons.

- [ ] **Step 7: Run the tests to verify they pass**

Run: `fvm flutter test test/features/notifications test/features/home`
Expected: PASS.

- [ ] **Step 8: Analyze**

Run: `fvm flutter analyze --no-fatal-infos`
Expected: no new issues.

- [ ] **Step 9: Commit**

```bash
git add lib/features/notifications test/features/notifications lib/features/home/presentation/pages/home_page.dart lib/features/home/presentation/pages/widgets/test_adhan_button.dart
git commit -m "feat(alerts): per-prayer alert payloads and reliability, settings and preview calls

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

(`git add` on the two feature folders stages the deletions of `adhan_audio_settings*.dart` too; check `git status` shows nothing outside the listed paths.)

### Task 4: AlertPlanner, schedulers, receivers and records (Android)

Kotlin source dir: `android/app/src/main/kotlin/com/example/quran_app/` (written `K/` below). Test dir (new): `android/app/src/test/kotlin/com/example/quran_app/` (`T/`).

**Files:**
- Create: `K/AlertPlanner.kt` (pure: no `android.*` imports, not even `Log`), `K/AlertStore.kt`, `K/AdhanHealReceiver.kt`, `K/LocaleContext.kt`, `K/AlertChannels.kt`, `T/AlertPlannerTest.kt`, `T/AdhanTestExtrasTest.kt`
- Modify: `K/AdhanScheduler.kt`, `K/PrayerReminderScheduler.kt`, `K/PrayerReminderReceiver.kt` (adds the `EXTRA_REMINDER_SOUND` constant only; its behaviour changes in Task 5), `K/PrayerReminderIds.kt`, `K/AdhanAlarmReceiver.kt`, `K/AdhanBootReceiver.kt`, `K/PrayerStripPlugin.kt` (adhan, reminder, test and cancel handlers), `android/app/src/main/AndroidManifest.xml`, `android/app/build.gradle.kts`, `android/app/src/main/res/values/strings.xml`, `android/app/src/main/res/values-ar/strings.xml`
- Delete: `AdhanScheduler.armToday`, `PrayerReminderScheduler.armToday`, `PrayerReminderScheduler.rearmFromSnapshot` and `saveSnapshot` (the reminder snapshot is written by `PrayerReminderScheduler.sync` and re-armed only through `AdhanScheduler.rearmFromSnapshot`; update the call at `AdhanBootReceiver.kt:27`), `AdhanScheduler.DaySchedule` (replaced by `AlertPlanner.Day` everywhere it is used: `PrayerReminderScheduler.kt:39`, `PrayerStripPlugin.kt:90` and `:142`), `PrayerReminderIds.requestCodeByPrayer` and `REQUEST_CODE_BASE` (request codes now come from the planner; `notificationIdByPrayer` stays)

**Interfaces:**
- Consumes: the Task 3 channel table rows `scheduleDailyAdhans`, `schedulePrayerReminders`, `scheduleTestAdhan`, `cancelAllAdhans`, `cancelAllReminders`.
- Produces (Tasks 5, 6, 9 rely on these):
  - `object AlertPlanner` with constants `MAX_DAYS = 7`, `ADHAN_BASE = 200`, `REMINDER_BASE = 300`, `HEAL_REQUEST_CODE = 298`, `TEST_REQUEST_CODE = 299`, `LATE_THRESHOLD_MS = 30 min`, `CLOCK_DRIFT_MS = 2 min`, `MISS_MARGIN_MS = 35 min`, `REACH_MS = 24 h`, `PRUNE_MS = 48 h`, `ISHA_FALLBACK_MS = 6 h`, `PRAYERS = listOf("fajr", "dhuhr", "asr", "maghrib", "isha")`.
  - Data classes `Day(date: String, timings: Map<String, String>)`, `AdhanSpec(sound: String, ringInSilent: Boolean)`, `ReminderSpec(minutes: Int, reminderSound: String)`, `AdhanSnapshot(days: List<Day>, alerts: Map<String, AdhanSpec>, localeCode: String, legacy: Boolean)`, `ReminderSnapshot(days: List<Day>, reminders: Map<String, ReminderSpec>, localeCode: String, legacy: Boolean)`, `PlannedAlarm(key: String, prayer: String, requestCode: Int, triggerAt: Long, prayerAt: Long, nextAt: Long)`, `ArmedEntry(triggerAt: Long, armedAt: Long)`, `Record(outcome: Outcome, triggerAt: Long)`, `Miss(prayer: String, at: Long)`; `enum Outcome { FIRED, LATE, SKIPPED, MISSED }`; `enum Route { SKIP, LATE, MISSED, DELIVER }`.
  - Functions: `key(date: String, prayer: String): String` (`"2026-11-15/asr"`), `keyFor(triggerAt: Long, prayer: String, zone: TimeZone): String`, `prayerAt(day: Day, prayer: String, zone: TimeZone): Long?`, `parseAdhanSnapshot(json: String): AdhanSnapshot`, `parseReminderSnapshot(json: String): ReminderSnapshot` (both throw on malformed JSON), `planAdhans(days: List<Day>, alerts: Map<String, AdhanSpec>, now: Long, zone: TimeZone): List<PlannedAlarm>`, `planReminders(days: List<Day>, reminders: Map<String, ReminderSpec>, now: Long, zone: TimeZone): List<PlannedAlarm>`, `staleRequestCodes(base: Int, armed: Set<Int>): List<Int>`, `clockMoved(nowWall: Long, nowElapsed: Long, armedAt: Long?, armedElapsed: Long?): Boolean`, `route(notificationsEnabled: Boolean, channelBlocked: Boolean, nowWall: Long, nowElapsed: Long, triggerAt: Long, nextAt: Long?, armedAt: Long?, armedElapsed: Long?): Route`, `detectMisses(armed: Map<String, ArmedEntry>, records: Map<String, Record>, lastCheckedAt: Long, lastBootHandledAt: Long, lastClockChangeAt: Long, now: Long): List<Miss>`, `lateSince(records: Map<String, Record>, lastCheckedAt: Long): List<Miss>`, `pruneArmed(armed, now)`, `pruneRecords(records, now)`, `snapshotUntil(days: List<Day>): String?`.
  - `object AlertStore`: `val executor: ExecutorService` (single thread), `fun post(context: Context, block: (Context) -> Unit)` (runs on the executor), `fun prefs(context)`; persisted in prefs `alert_store` with `commit()`: `armed_log` and `records` (JSON objects keyed by `key`), `last_checked_at`, `last_boot_handled_at`, `last_clock_change_at`, `scheduled_until`. Accessors: `readArmed`, `writeArmed`, `readRecords`, `writeRecord(context, key, Record)` (prunes on write), `getLong/setLong(context, name, value)`, `setIfUnset(context, name, value)`. Snapshots keep v1's locations: prefs `adhan_prefs` key `adhan_snapshot`, prefs `reminder_prefs` key `reminder_snapshot`.
  - `AdhanScheduler`: `const val USE_ALARM_CLOCK = true`, `fun sync(context, snapshot: AlertPlanner.AdhanSnapshot)` (save snapshot, set `last_checked_at` if unset, arm), `fun armDays(context, snapshot)`, `fun rearmFromSnapshot(context)` (re-arms adhans **and** reminders; caller is already on the executor), `fun armHeal(context)`, `fun cancelAll(context)`, `fun armTest(context, delaySeconds: Int, localeCode: String, sound: String, ringInSilent: Boolean)`.
  - `PrayerReminderScheduler`: `fun sync(context, snapshot: AlertPlanner.ReminderSnapshot)`, `fun armDays(context, snapshot)`, `fun cancelAll(context)`.
  - `AdhanAlarmReceiver` extras: `EXTRA_PRAYER = "prayer"`, `EXTRA_CLIP = "clip"` (read only for legacy), `EXTRA_LOCALE = "locale"`, `EXTRA_TRIGGER_AT = "triggerAt"`, `EXTRA_SOUND = "sound"`, `EXTRA_RING_IN_SILENT = "ringInSilent"`, `EXTRA_ARMED_AT = "armedAt"`, `EXTRA_ARMED_ELAPSED = "armedElapsed"`, `EXTRA_NEXT_AT = "nextAt"`, `EXTRA_KEY = "key"`, `EXTRA_TEST = "test"`; `fun deliver(context, prayer, localeCode, sound, ringInSilent, playing: Boolean = true)` (Task 5 replaces its body and computes `playing`). `PrayerReminderReceiver.EXTRA_REMINDER_SOUND = "reminderSound"`.
  - `fun localizedContext(context: Context, localeCode: String): Context` (top level, `LocaleContext.kt`).
  - `object AlertChannels { const val ALERT_SILENT = "prayer_alert_silent_v2"; fun ensureAlertSilent(context) }` (Task 5 adds the rest).
  - `AdhanAlarmReceiver.postLate(context: Context, prayer: String, localeCode: String, lateMinutes: Int)` and `LATE_NOTIFICATION_ID = 210`.

- [ ] **Step 1: Add the test dependencies**

In `android/app/build.gradle.kts` `dependencies { }` add `testImplementation("junit:junit:4.13.2")` and `testImplementation("org.json:json:20240303")`.

- [ ] **Step 2: Write the failing planner tests** in `T/AlertPlannerTest.kt`, with `val utc = TimeZone.getTimeZone("UTC")`, a `day(date)` helper whose timings are `fajr 04:52, sunrise 06:18, dhuhr 11:41, asr 14:39, maghrib 16:58, isha 18:16`, ten days `2026-11-15`…`2026-11-24`, `allOn = PRAYERS.associateWith { AdhanSpec("adhan", false) }`, and `ms("2026-11-15T13:00")` parsing UTC.

```kotlin
@Test fun planAdhans_armsFirstSevenDatesWithFutureTriggers() {
    val plan = AlertPlanner.planAdhans(tenDays, allOn, ms("2026-11-15T13:00"), utc)
    assertEquals(listOf(202, 203, 204), plan.filter { it.key.startsWith("2026-11-15") }.map { it.requestCode })
    assertEquals((260..264).toList(), plan.filter { it.key.startsWith("2026-11-21") }.map { it.requestCode })
    assertTrue(plan.none { it.key.startsWith("2026-11-22") })
    assertEquals(33, plan.size)
}
@Test fun planAdhans_skipsTodayWhenAllPassed() {
    val plan = AlertPlanner.planAdhans(tenDays, allOn, ms("2026-11-15T20:00"), utc)
    assertEquals("2026-11-16/fajr", plan.first().key)
    assertEquals(200, plan.first().requestCode)
}
@Test fun planAdhans_nextAtFollowsCanonicalOrder() {
    val plan = AlertPlanner.planAdhans(tenDays, mapOf("fajr" to AdhanSpec("adhan", false), "isha" to AdhanSpec("tone", false)), ms("2026-11-15T00:00"), utc)
    assertEquals(ms("2026-11-15T06:18"), plan.first { it.key == "2026-11-15/fajr" }.nextAt)
    assertEquals(ms("2026-11-16T04:52"), plan.first { it.key == "2026-11-15/isha" }.nextAt)
}
@Test fun planAdhans_lastIshaInSnapshotFallsBackSixHours() {
    val plan = AlertPlanner.planAdhans(listOf(day("2026-11-15")), allOn, ms("2026-11-15T00:00"), utc)
    assertEquals(ms("2026-11-16T00:16"), plan.first { it.prayer == "isha" }.nextAt)
}
@Test fun planAdhans_dedupesAndSkipsMalformed() {
    val bad = Day("2026-11-16", mapOf("fajr" to "25:00", "dhuhr" to "5:7x", "asr" to "", "maghrib" to "16:58", "isha" to "18:16"))
    val plan = AlertPlanner.planAdhans(listOf(day("2026-11-15"), day("2026-11-15"), bad), allOn, ms("2026-11-15T20:00"), utc)
    assertEquals(listOf("2026-11-16/maghrib", "2026-11-16/isha"), plan.map { it.key })
}
@Test fun planAdhans_emptyAlertsCancelsAllSlots() {
    assertTrue(AlertPlanner.planAdhans(tenDays, emptyMap(), ms("2026-11-15T00:00"), utc).isEmpty())
    assertEquals(35, AlertPlanner.staleRequestCodes(200, emptySet()).size)
    assertFalse(AlertPlanner.staleRequestCodes(200, setOf(202)).contains(202))
}
@Test fun planReminders_subtractsMinutesAndUses300Base() {
    val plan = AlertPlanner.planReminders(tenDays, mapOf("asr" to ReminderSpec(15, "tone")), ms("2026-11-15T13:00"), utc)
    assertEquals(302, plan.first().requestCode)
    assertEquals(ms("2026-11-15T14:24"), plan.first().triggerAt)
    assertEquals(ms("2026-11-15T14:39"), plan.first().prayerAt)
}
@Test fun parseAdhanSnapshot_v2() { ...{"days":[…],"alerts":{"fajr":{"sound":"tone","ringInSilent":false}},"locale":"ar"} → legacy=false, alerts["fajr"]==AdhanSpec("tone", false)... }
@Test fun parseAdhanSnapshot_legacyClips() {
    val s = AlertPlanner.parseAdhanSnapshot("""{"days":[{"date":"2026-11-15","timings":{"fajr":"04:52","asr":"14:39"}}],"clips":{"fajr":"fajr_adhan","asr":"normal_adhan"},"locale":"ar"}""")
    assertTrue(s.legacy)
    assertEquals(AdhanSpec("adhan", true), s.alerts["fajr"])
    assertEquals(setOf("fajr", "asr"), s.alerts.keys)
}
@Test fun parseReminderSnapshot_legacyIntsBecomeVibrate() {
    val s = AlertPlanner.parseReminderSnapshot("""{"days":[],"reminders":{"asr":10},"locale":"en"}""")
    assertEquals(ReminderSpec(10, "vibrate"), s.reminders["asr"])
    assertTrue(s.legacy)
}
@Test(expected = Exception::class) fun parseAdhanSnapshot_malformedThrows() { AlertPlanner.parseAdhanSnapshot("{not json") }
@Test fun route_onTimeDelivers() { assertEquals(Route.DELIVER, route(late = 29.min)) }
@Test fun route_notificationsOffSkips() { assertEquals(Route.SKIP, AlertPlanner.route(false, false, …)) }
@Test fun route_skipsWhenClockMovedAfterArming() { wall advanced 40 min, elapsed advanced 5 min → Route.SKIP }
@Test fun route_lateBeforeNextAt() { nowWall = ms("2026-11-15T15:10") (31 min late), no drift, nextAt 16:58 → Route.LATE }
@Test fun route_missedAfterNextAt() { nowWall = ms("2026-11-15T17:00") (after nextAt 16:58), no drift → Route.MISSED }
@Test fun route_legacyExtrasLateIsMissed() { armedAt = null, armedElapsed = null, nextAt = null, late 31 min → Route.MISSED }
@Test fun clockMoved_ignoresRebootSinceArming() { nowElapsed < armedElapsed → false }
@Test fun detectMisses_reportsUnrecordedIshaNextMorning() {
    val armed = mapOf("2026-11-14/isha" to ArmedEntry(ms("2026-11-14T18:16"), ms("2026-11-14T09:00")))
    val misses = AlertPlanner.detectMisses(armed, emptyMap(), 0, 0, 0, ms("2026-11-15T07:00"))
    assertEquals(listOf(Miss("isha", ms("2026-11-14T18:16"))), misses)
}
@Test fun detectMisses_skipsRecordedArmedAfterTriggerAndRecent() { FIRED record → none; SKIPPED record → none; armedAt > triggerAt → none; trigger 20 min ago → none }
@Test fun detectMisses_ignoresTriggersBeforeBoot() { lastBootHandledAt after triggerAt → none }
@Test fun detectMisses_ignoresTriggersBeforeClockChange() { lastClockChangeAt after triggerAt → none }
@Test fun detectMisses_includesRecordedMissedAfterLastChecked() { Record(MISSED, t) with t > lastCheckedAt → reported; t <= lastCheckedAt → not }
@Test fun lateSince_filtersByLastChecked() { … }
@Test fun prune_drops48hOld() { entries with triggerAt < now - 48h removed }
```

Write the bodies of the elided tests with the values named in each line; every `route` call uses `triggerAt = ms("2026-11-15T14:39")`, `nextAt = ms("2026-11-15T16:58")`, `armedAt = ms("2026-11-15T09:00")`, and `armedElapsed = 1_000_000`, `nowElapsed = armedElapsed + (nowWall - armedAt)` unless the test moves the clock.

- [ ] **Step 3: Write the failing test-alarm test** in `T/AdhanTestExtrasTest.kt`

```kotlin
@Test fun testAlarmExtrasAreV2AndMarkedTest() {
    val extras = AdhanScheduler.testExtras(localeCode = "ar", sound = "tone", ringInSilent = false, triggerAt = 1_000L)
    assertEquals("tone", extras["sound"])
    assertEquals(false, extras["ringInSilent"])
    assertEquals(true, extras["test"])
    assertFalse(extras.containsKey("key"))
}
```

`AdhanScheduler.testExtras(...)` returns a `Map<String, Any>` that `armTest` copies into the intent, so it stays JVM-testable.

- [ ] **Step 4: Run to verify they fail**

Run: `cd android && ./gradlew :app:testDebugUnitTest`
Expected: compilation failure (`AlertPlanner` unresolved).

- [ ] **Step 5: Implement `AlertPlanner`**

`prayerAt` accepts exactly `H:mm`/`HH:mm` with hour 0..23 and minute 0..59 and returns `null` otherwise; it builds the instant with `Calendar.getInstance(zone)`. Bodies for the parts the tests do not fully pin:

```kotlin
fun planAdhans(days: List<Day>, alerts: Map<String, AdhanSpec>, now: Long, zone: TimeZone): List<PlannedAlarm> {
    val sorted = days.distinctBy { it.date }.sortedBy { it.date }
    val chosen = sorted.filter { d -> PRAYERS.any { p -> alerts.containsKey(p) && (prayerAt(d, p, zone) ?: 0L) > now } }
        .take(MAX_DAYS)
    return chosen.flatMapIndexed { slot, d ->
        PRAYERS.mapIndexedNotNull { i, p ->
            val at = prayerAt(d, p, zone)
            if (!alerts.containsKey(p) || at == null || at <= now) null
            else PlannedAlarm(key(d.date, p), p, ADHAN_BASE + slot * 10 + i, at, at, nextAt(sorted, d, p, at, zone))
        }
    }
}

private val CANONICAL = listOf("fajr", "sunrise", "dhuhr", "asr", "maghrib", "isha")

private fun nextAt(sorted: List<Day>, d: Day, p: String, at: Long, zone: TimeZone): Long {
    val later = CANONICAL.drop(CANONICAL.indexOf(p) + 1).firstNotNullOfOrNull { prayerAt(d, it, zone) }
    if (later != null) return later
    val tomorrow = sorted.getOrNull(sorted.indexOf(d) + 1)?.let { prayerAt(it, "fajr", zone) }
    return tomorrow?.takeIf { it > at } ?: (at + ISHA_FALLBACK_MS)
}

fun clockMoved(nowWall: Long, nowElapsed: Long, armedAt: Long?, armedElapsed: Long?): Boolean {
    if (armedAt == null || armedElapsed == null || nowElapsed < armedElapsed) return false
    return abs((nowWall - armedAt) - (nowElapsed - armedElapsed)) > CLOCK_DRIFT_MS
}

fun route(notificationsEnabled: Boolean, channelBlocked: Boolean, nowWall: Long, nowElapsed: Long,
          triggerAt: Long, nextAt: Long?, armedAt: Long?, armedElapsed: Long?): Route {
    if (!notificationsEnabled || channelBlocked) return Route.SKIP
    if (nowWall - triggerAt <= LATE_THRESHOLD_MS) return Route.DELIVER
    if (clockMoved(nowWall, nowElapsed, armedAt, armedElapsed)) return Route.SKIP
    return if (nowWall < (nextAt ?: (triggerAt + LATE_THRESHOLD_MS))) Route.LATE else Route.MISSED
}

fun detectMisses(armed: Map<String, ArmedEntry>, records: Map<String, Record>, lastCheckedAt: Long,
                 lastBootHandledAt: Long, lastClockChangeAt: Long, now: Long): List<Miss> {
    val from = maxOf(lastCheckedAt, lastBootHandledAt, lastClockChangeAt, now - REACH_MS)
    val to = now - MISS_MARGIN_MS
    val silent = armed.filter { (k, e) -> e.armedAt < e.triggerAt && e.triggerAt > from && e.triggerAt <= to && k !in records }
        .map { (k, e) -> Miss(k.substringAfter('/'), e.triggerAt) }
    val recorded = records.filter { (_, r) -> r.outcome == Outcome.MISSED && r.triggerAt > lastCheckedAt }
        .map { (k, r) -> Miss(k.substringAfter('/'), r.triggerAt) }
    return (silent + recorded).sortedByDescending { it.at }
}
```

`planReminders` uses the same date selection, but a date qualifies when some `prayerAt - minutes * 60_000 > now`; `trigger = prayerAt - minutes * 60_000`, `REMINDER_BASE`, and `nextAt = prayerAt`. A snapshot is legacy when the adhan JSON has no `alerts` object (then every entry of `PRAYERS` present in any day's `timings` gets `AdhanSpec("adhan", true)`; v1 timings also carry sunrise, which is not in `PRAYERS` and gets no alert) or a reminder value is an `Int` (then `ReminderSpec(value, "vibrate")`). `lateSince` returns `LATE` records with `triggerAt > lastCheckedAt`, newest first. `staleRequestCodes(base, armed)` is every `base + slot * 10 + i` for slot 0..6, i 0..4 not in `armed`.

- [ ] **Step 6: Implement `AlertStore`, schedulers, receivers and the plugin handlers**

- `AdhanScheduler.armDays(context, snapshot)`: plan with `System.currentTimeMillis()` and `TimeZone.getDefault()`; for each alarm build the intent with `EXTRA_KEY`, `EXTRA_PRAYER`, `EXTRA_LOCALE`, `EXTRA_TRIGGER_AT`, `EXTRA_SOUND`, `EXTRA_RING_IN_SILENT`, `EXTRA_NEXT_AT`, `EXTRA_ARMED_AT = currentTimeMillis()`, `EXTRA_ARMED_ELAPSED = SystemClock.elapsedRealtime()`; arm with `am.setAlarmClock(AlarmManager.AlarmClockInfo(trigger, openAppPI), pi)` when `USE_ALARM_CLOCK`, else `setExactAndAllowWhileIdle`; on `SecurityException` use `setAndAllowWhileIdle`. Then cancel `staleRequestCodes(200, armedCodes)`, rewrite the armed log (drop entries whose `triggerAt > now`, add the new ones, prune), store `scheduled_until = plan.maxOf { triggerAt }` (or remove it when the plan is empty), and call `armHeal`. Never cancel before the new alarms are set.
- `armHeal`: next local 00:05 via `setAndAllowWhileIdle`, request code 298, explicit intent to `AdhanHealReceiver`.
- `rearmFromSnapshot`: parse both snapshots inside `try`; on any parse exception log and return without cancelling; otherwise `armDays` for both.
- `armTest`: request code 299, extras from `testExtras`, exact with inexact fallback; no armed-log write.
- `PrayerReminderScheduler.armDays`: same pattern with `REMINDER_BASE`, extras as today plus `EXTRA_REMINDER_SOUND`; no armed log for reminders.
- `AdhanAlarmReceiver.onReceive`: `val pending = goAsync()` then `AlertStore.post(context) { … ; pending.finish() }` in a `try/finally`. If `EXTRA_TEST`: `deliver(...)` only. Else: `legacy = !intent.hasExtra(EXTRA_SOUND)` (legacy reads `sound = "adhan"`, `ringInSilent = true`, key from `keyFor(triggerAt, prayer, TimeZone.getDefault())`); `route(NotificationManagerCompat.areNotificationsEnabled(), false, …)` (Task 5 supplies `channelBlocked`); `SKIP` → record `SKIPPED`; `LATE` → `postLate` then record `LATE`; `MISSED` → record `MISSED`; `DELIVER` → record `FIRED`, cancel the visible reminder (`PrayerReminderIds.notificationIdByPrayer`), `deliver(...)`. Finally `AdhanScheduler.rearmFromSnapshot(context)`. The old `STALE_THRESHOLD_MS` guard goes away.
- `deliver` (temporary, Task 5 replaces): start `AdhanPlaybackService` exactly as v1 does, clip `fajr_adhan` for Fajr else `normal_adhan`.
- `postLate`: `AlertChannels.ensureAlertSilent`, `localizedContext(context, localeCode)`, title `getString(R.string.prayer_late_title, prayerName, minutesText)` where `prayerName` is `adhan_title_<prayer>` and `minutesText = resources.getQuantityString(R.plurals.prayer_late_minutes, n, NumberFormat.getIntegerInstance(Locale(localeCode)).format(n))`, body `prayer_late_body`, one action `prayer_late_fix`; content intent and action both open `MainActivity` (same `PendingIntent`); silent, auto-cancel, id 210.
- `AdhanBootReceiver`: accept only `BOOT_COMPLETED`, `MY_PACKAGE_REPLACED`, `TIME_SET` (`Intent.ACTION_TIME_CHANGED`) and `TIMEZONE_CHANGED`; ignore anything else. `BOOT_COMPLETED` stores `last_boot_handled_at`; time actions store `last_clock_change_at`; `MY_PACKAGE_REPLACED` calls `setIfUnset("last_checked_at", now)`. Then `rearmFromSnapshot` on the executor via `goAsync`.
- `AdhanHealReceiver` (`exported="false"`): `goAsync` + `AlertStore.post { AdhanScheduler.rearmFromSnapshot(it) }`.
- `PrayerStripPlugin`: `cancelAllAdhans` and `cancelAllReminders` also run through `AlertStore.post` (replying on the main looper); parse `alerts` into `Map<String, AdhanSpec>` and `reminders` into `Map<String, ReminderSpec>`, build snapshots with `legacy = false`, run `AdhanScheduler.sync`/`PrayerReminderScheduler.sync` through `AlertStore.post`, and reply `result.success(null)` on the main looper (`Handler(Looper.getMainLooper()).post`). `scheduleTestAdhan` reads `sound` (default `"adhan"`) and `ringInSilent` (default `false`).
- Manifest: `<receiver android:name=".AdhanHealReceiver" android:exported="false" />`.
- Strings (both locales, Appendix A native table): `prayer_late_title`, `prayer_late_body`, `prayer_late_fix`, `channel_alert_silent`, and `<plurals name="prayer_late_minutes">` whose items use `%1$s` (the number is pre-formatted with the locale's digits; Arabic items `one`, `two`, `few`, `many`, `other`).
- `localizedContext` moves into `LocaleContext.kt` as the reminder receiver's version (no `Locale.setDefault`); `AdhanPlaybackService` keeps its `Locale.setDefault(locale)` call at its own call site before using the shared function, so its behaviour is unchanged. Both switch to it in Task 5.

- [ ] **Step 7: Run the Kotlin tests**

Run: `cd android && ./gradlew :app:testDebugUnitTest`
Expected: BUILD SUCCESSFUL, all `AlertPlannerTest` and `AdhanTestExtrasTest` cases pass.

- [ ] **Step 8: Compile the app**

Run: `fvm flutter build apk --debug`
Expected: `Built build/app/outputs/flutter-apk/app-debug.apk`.

- [ ] **Step 9: Commit**

```bash
git add android/app/build.gradle.kts android/app/src/main/AndroidManifest.xml android/app/src/main/res/values/strings.xml android/app/src/main/res/values-ar/strings.xml android/app/src/main/kotlin/com/example/quran_app/AlertPlanner.kt android/app/src/main/kotlin/com/example/quran_app/AlertStore.kt android/app/src/main/kotlin/com/example/quran_app/AdhanHealReceiver.kt android/app/src/main/kotlin/com/example/quran_app/LocaleContext.kt android/app/src/main/kotlin/com/example/quran_app/AlertChannels.kt android/app/src/main/kotlin/com/example/quran_app/AdhanScheduler.kt android/app/src/main/kotlin/com/example/quran_app/PrayerReminderScheduler.kt android/app/src/main/kotlin/com/example/quran_app/PrayerReminderIds.kt android/app/src/main/kotlin/com/example/quran_app/PrayerReminderReceiver.kt android/app/src/main/kotlin/com/example/quran_app/AdhanAlarmReceiver.kt android/app/src/main/kotlin/com/example/quran_app/AdhanBootReceiver.kt android/app/src/main/kotlin/com/example/quran_app/PrayerStripPlugin.kt android/app/src/test/kotlin/com/example/quran_app/AlertPlannerTest.kt android/app/src/test/kotlin/com/example/quran_app/AdhanTestExtrasTest.kt
git commit -m "feat(alerts): native 7-day self-healing schedule with armed log and miss records

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 5: Audio routes, channels and preview (Android)

**Files:**
- Modify: `K/AlertChannels.kt`, `K/AlertPlanner.kt` (pure channel helpers), `K/AdhanScheduler.kt` (`AlertChannels.ensureAll` in `sync`), `K/AdhanAlarmReceiver.kt` (`deliver`, `channelBlocked` in step 1), `K/AdhanPlaybackService.kt`, `K/PrayerReminderReceiver.kt`, `K/PrayerStripPlugin.kt` (`previewSound`, `stopPreview`), `lib/core/notifications/prayer_notification_scheduler_impl.dart` (`init()`), `android/app/src/main/AndroidManifest.xml` (label), `android/app/src/main/res/values/strings.xml`, `android/app/src/main/res/values-ar/strings.xml`
- Create: `K/SoundPreviewPlayer.kt`, `android/app/src/main/res/raw/keep.xml`, `T/AlertChannelsTest.kt`

**Interfaces:**
- Consumes: Task 3 rows `previewSound`, `stopPreview`; Task 4 `AlertPlanner.route`, `AdhanAlarmReceiver.deliver(context, prayer, localeCode, sound, ringInSilent, playing)`, `AlertChannels.ALERT_SILENT`, `localizedContext`, `PrayerReminderReceiver.EXTRA_REMINDER_SOUND`.
- Produces:
  - `AlertChannels` ids: `ALERT_TONE = "prayer_alert_tone_v2"` (HIGH, default sound), `ALERT_VIBRATE = "prayer_alert_vibrate_v2"` (HIGH, no sound, vibration), `ALERT_SILENT = "prayer_alert_silent_v2"` (DEFAULT, no sound, no vibration), `REMINDER_TONE = "prayer_reminder_tone_v2"` (DEFAULT, default sound), `REMINDER_VIBRATE = "prayer_reminder_channel"` (v1 channel, unchanged), `REMINDER_SILENT = "prayer_reminder_silent_v2"` (LOW), `PLAYBACK = AdhanPlaybackService.CHANNEL_ID` (`prayer_adhan_channel`); `fun ensureAll(context)`, `fun isBlocked(context, id): Boolean` (`importance == IMPORTANCE_NONE`; a channel not yet created is not blocked).
  - Pure (in `AlertPlanner`): `deliveryChannel(sound: String, playing: Boolean): String` (`playing` → `prayer_adhan_channel`; `adhan`/`tone` → tone; `vibrate` → vibrate; `silent` → silent), `routeChannels(sound: String): Set<String>` (`adhan` → `{prayer_adhan_channel, prayer_alert_tone_v2}`, others → `{deliveryChannel(sound, false)}`), `reminderChannel(reminderSound: String): String`, `clipFor(prayer: String): String` (`fajr_adhan` for Fajr, else `normal_adhan`).
  - `AdhanPlaybackService.EXTRA_RING_IN_SILENT = "ringInSilent"`; usage `USAGE_ALARM` when true, else `USAGE_NOTIFICATION_EVENT`.
  - `object SoundPreviewPlayer { fun play(context, sound: String, prayer: String); fun stop() }` on `USAGE_MEDIA`.

- [ ] **Step 1: Write the failing channel tests** in `T/AlertChannelsTest.kt`

```kotlin
@Test fun deliveryChannelFollowsSound() {
    assertEquals("prayer_adhan_channel", AlertPlanner.deliveryChannel("adhan", playing = true))
    assertEquals("prayer_alert_tone_v2", AlertPlanner.deliveryChannel("adhan", playing = false))
    assertEquals("prayer_alert_tone_v2", AlertPlanner.deliveryChannel("tone", playing = false))
    assertEquals("prayer_alert_vibrate_v2", AlertPlanner.deliveryChannel("vibrate", playing = false))
    assertEquals("prayer_alert_silent_v2", AlertPlanner.deliveryChannel("silent", playing = false))
}
@Test fun routeChannelsForAdhanIncludePlaybackAndTone() {
    assertEquals(setOf("prayer_adhan_channel", "prayer_alert_tone_v2"), AlertPlanner.routeChannels("adhan"))
    assertEquals(setOf("prayer_alert_silent_v2"), AlertPlanner.routeChannels("silent"))
}
@Test fun reminderChannelFollowsReminderSound() {
    assertEquals("prayer_reminder_tone_v2", AlertPlanner.reminderChannel("tone"))
    assertEquals("prayer_reminder_channel", AlertPlanner.reminderChannel("vibrate"))
    assertEquals("prayer_reminder_silent_v2", AlertPlanner.reminderChannel("silent"))
}
@Test fun clipForFajrOnly() {
    assertEquals("fajr_adhan", AlertPlanner.clipFor("fajr"))
    assertEquals("normal_adhan", AlertPlanner.clipFor("isha"))
}
```

`AlertPlanner` must not import `AdhanPlaybackService`; it holds the id strings itself and `AlertChannels` reuses them.

- [ ] **Step 2: Run to verify it fails**

Run: `cd android && ./gradlew :app:testDebugUnitTest`
Expected: compilation failure on `deliveryChannel`.

- [ ] **Step 3: Implement**

- `AlertChannels.ensureAll` (called first thing in `AdhanScheduler.sync`, so channels exist before any alarm fires) creates the five v2/v1 channels with names from `channel_alert_tone`, `channel_alert_vibrate`, `channel_alert_silent`, `channel_reminder_tone`, `channel_reminder_silent` (the v1 reminder channel keeps `reminder_channel_name`). Call it from `AdhanScheduler.sync`, the receiver and `PrayerReminderReceiver`.
- Receiver step 1: compute `playing = sound == "adhan" && (ringInSilent || isAudibleNow(context))` first, then `channelBlocked = AlertChannels.isBlocked(context, AlertPlanner.deliveryChannel(sound, playing))` (only the channel this fire would use, spec L181), passed to `route`; `deliver` reuses `playing`; the test-alarm path skips step 1 but computes `playing` the same way. The union `routeChannels` is for Task 6's status only.
- `deliver(context, prayer, localeCode, sound, ringInSilent, playing)`: when `playing`, `startForegroundService` with `EXTRA_CLIP = clipFor(prayer)` and `EXTRA_RING_IN_SILENT`; wrap in `try { } catch (e: Exception)` and fall through to the text notification on any throw. Otherwise post the adhan-text notification (title `adhan_title_<prayer>`, body `adhan_body_<prayer>`, via `localizedContext`) on `deliveryChannel(sound, false)`, id `AdhanAlarmReceiver.TEXT_NOTIFICATION_ID` (201, apart from the playback notification's 200), opening `MainActivity`.
- `isAudibleNow(context)`: `AudioManager.ringerMode == RINGER_MODE_NORMAL && NotificationManager.currentInterruptionFilter in (INTERRUPTION_FILTER_ALL, INTERRUPTION_FILTER_UNKNOWN) && getStreamVolume(STREAM_NOTIFICATION) > 0`.
- `AdhanPlaybackService.startMediaPlayer` takes `ringInSilent` and sets `USAGE_ALARM` or `USAGE_NOTIFICATION_EVENT`; it calls `Locale.setDefault(Locale(localeCode))` itself, then the shared `localizedContext` from `LocaleContext.kt`, and drops its private copy.
- `PrayerReminderReceiver`: return early when `prayerTimestampMs <= System.currentTimeMillis()`; channel `reminderChannel(intent.getStringExtra(EXTRA_REMINDER_SOUND) ?: "vibrate")`; `setTimeoutAfter(prayerTimestampMs - now)`; the tone channel builder drops `setSound(null)` and `setVibrate`; keep the chronometer; use the shared `localizedContext`.
- `SoundPreviewPlayer.play`: stop any current player, then `MediaPlayer` on `AudioAttributes.USAGE_MEDIA` with the raw resource `resources.getIdentifier(clipFor(prayer), "raw", packageName)` for `adhan` or `RingtoneManager.getDefaultUri(TYPE_NOTIFICATION)` for `tone`; release on completion. Plugin `previewSound` reads `sound`, `prayer`; `stopPreview` calls `stop()`. Completion, the error listener and a failed `play` post `channel.invokeMethod("previewEnded", mapOf("sound" to sound))` to the main thread through the plugin's channel (null after detach); an explicit `stop()` drops the callback without calling it.
- `prayer_notification_scheduler_impl.dart` `init()`: replace the two `createNotificationChannel` calls with `deleteNotificationChannel(channelId: _fajrChannelId)` and `deleteNotificationChannel(channelId: _standardChannelId)`; delete the `_fajrChannel` and `_standardChannel` constants (the iOS `DarwinNotificationDetails` stay until Task 12).
- `res/raw/keep.xml`: `<resources xmlns:tools="http://schemas.android.com/tools" tools:keep="@raw/*" />`.
- Strings: change the existing `app_name` values to «الفرقان» / "Al-Furqan" (both files already define it) and add `channel_alert_tone`, `channel_alert_vibrate`, `channel_reminder_tone`, `channel_reminder_silent` (`channel_alert_silent` came with Task 4); manifest `android:label="@string/app_name"`.

- [ ] **Step 4: Run the Kotlin tests**

Run: `cd android && ./gradlew :app:testDebugUnitTest`
Expected: BUILD SUCCESSFUL.

- [ ] **Step 5: Compile and analyze**

Run: `fvm flutter build apk --debug` then `fvm flutter analyze --no-fatal-infos`
Expected: APK built; no new analyzer issues.

- [ ] **Step 6: Commit**

```bash
git add android/app/src/main/kotlin/com/example/quran_app/AlertChannels.kt android/app/src/main/kotlin/com/example/quran_app/AlertPlanner.kt android/app/src/main/kotlin/com/example/quran_app/AdhanScheduler.kt android/app/src/main/kotlin/com/example/quran_app/AdhanAlarmReceiver.kt android/app/src/main/kotlin/com/example/quran_app/AdhanPlaybackService.kt android/app/src/main/kotlin/com/example/quran_app/PrayerReminderReceiver.kt android/app/src/main/kotlin/com/example/quran_app/PrayerStripPlugin.kt android/app/src/main/kotlin/com/example/quran_app/SoundPreviewPlayer.kt android/app/src/main/res/raw/keep.xml android/app/src/main/res/values/strings.xml android/app/src/main/res/values-ar/strings.xml android/app/src/main/AndroidManifest.xml android/app/src/test/kotlin/com/example/quran_app/AlertChannelsTest.kt lib/core/notifications/prayer_notification_scheduler_impl.dart
git commit -m "feat(alerts): per-sound channels, silent-mode routing, reminder sounds and preview

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 6: Reliability status and settings intents (Android)

**Files:**
- Create: `K/ReliabilityReader.kt`, `K/SystemSettingsLauncher.kt`, `T/ReliabilityRulesTest.kt`
- Modify: `K/AlertPlanner.kt` (pure helpers), `K/PrayerStripPlugin.kt`, `android/app/src/main/AndroidManifest.xml` (`<queries>`)

**Interfaces:**
- Consumes: Task 3 rows `getReliabilityStatus`, `ackMissed`, `openSystemSettings`; Task 4 `AlertStore`, `AlertPlanner.detectMisses`, `lateSince`, `snapshotUntil`, `parseAdhanSnapshot`, `AdhanScheduler.USE_ALARM_CLOCK`; Task 5 `AlertPlanner.routeChannels`, `AlertChannels.isBlocked`.
- Produces:
  - Pure: `AlertPlanner.isXiaomi(manufacturer: String?, brand: String?): Boolean` (lower-cased ∈ {xiaomi, redmi, poco}); `data class IntentSpec(val action: String?, val pkg: String?, val cls: String?, val extras: Map<String, String>)`; `AlertPlanner.settingsCandidates(target: String, packageName: String, label: String, sdk: Int): List<IntentSpec>` (last entry always app details; below API 26 `notifications` goes straight to app details, because `APP_NOTIFICATION_SETTINGS` there reads `app_package`/`app_uid` and closes at once); `AlertPlanner.ackCheckpoint(current: Long?, upTo: Long): Long` = max(current, upTo).
  - `object ReliabilityReader { fun read(context): Map<String, Any?> }` returning exactly the Task 3 keys; `fun ack(context, upTo: Long)` sets `last_checked_at = max(current, upTo)`, where `upTo` is the newest trigger time the user was shown.
  - `object SystemSettingsLauncher { fun open(context, target: String): Boolean }` (true when a screen opened).

- [ ] **Step 1: Write the failing tests**

```kotlin
@Test fun isXiaomiMatchesBrandsCaseInsensitive() {
    assertTrue(AlertPlanner.isXiaomi("Xiaomi", "Redmi"))
    assertTrue(AlertPlanner.isXiaomi("unknown", "POCO"))
    assertFalse(AlertPlanner.isXiaomi("samsung", "samsung"))
    assertFalse(AlertPlanner.isXiaomi(null, null))
}
@Test fun autostartCandidatesInSpecOrder() {
    val c = AlertPlanner.settingsCandidates("autostart", "com.example.quran_app", "Al-Furqan", 34)
    assertEquals("com.miui.permcenter.autostart.AutoStartManagementActivity", c[0].cls)
    assertEquals("com.miui.permcenter.permissions.PermissionsEditorActivity", c[1].cls)
    assertEquals("com.example.quran_app", c[1].extras["extra_pkgname"])
    assertEquals("android.settings.APPLICATION_DETAILS_SETTINGS", c.last().action)
}
@Test fun xiaomiBatteryFallsBackToBatteryThenDetails() {
    val c = AlertPlanner.settingsCandidates("xiaomiBattery", "com.example.quran_app", "Al-Furqan", 34)
    assertEquals("com.miui.powerkeeper.ui.HiddenAppsConfigActivity", c[0].cls)
    assertEquals(mapOf("package_name" to "com.example.quran_app", "package_label" to "Al-Furqan"), c[0].extras)
    assertEquals("android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS", c[1].action)
    assertEquals("android.settings.APPLICATION_DETAILS_SETTINGS", c[2].action)
}
@Test fun notificationsAndExactAlarmTargets() {
    assertEquals("android.settings.APP_NOTIFICATION_SETTINGS", AlertPlanner.settingsCandidates("notifications", "p", "l", 34)[0].action)
    assertEquals("android.settings.REQUEST_SCHEDULE_EXACT_ALARM", AlertPlanner.settingsCandidates("exactAlarm", "p", "l", 34)[0].action)
    assertEquals(1, AlertPlanner.settingsCandidates("bogus", "p", "l", 34).size)
}
```

Use the action strings as literals in `AlertPlanner` so the test stays JVM-only.

- [ ] **Step 2: Run to verify it fails**

Run: `cd android && ./gradlew :app:testDebugUnitTest`
Expected: compilation failure.

- [ ] **Step 3: Implement**

- `ReliabilityReader.read` runs on the executor (the plugin posts to `AlertStore` and replies on the main looper). Fields: `notificationsEnabled` from `NotificationManagerCompat.areNotificationsEnabled`; `channelBlocked` = any channel in the union of `routeChannels(spec.sound)` over the stored adhan snapshot's alerts, plus `prayer_adhan_channel`, is blocked; `exactAlarmsAllowed` = `canScheduleExactAlarms()` on API 31+ (it reads true on API 33+ while `USE_EXACT_ALARM` is declared), `true` below; `batteryUnrestricted` = `PowerManager.isIgnoringBatteryOptimizations(packageName)`; `isXiaomi(Build.MANUFACTURER, Build.BRAND)`; `scheduledUntil` = `scheduled_until` or `null`; `snapshotUntil` = `snapshotUntil(days)`; `missed` = `detectMisses(readArmed, readRecords, last_checked_at, last_boot_handled_at, last_clock_change_at, now)` and `late` = `lateSince(records, last_checked_at)`, each as `[{prayer, at}]`; `usesAlarmClock = AdhanScheduler.USE_ALARM_CLOCK`.
- `SystemSettingsLauncher.open`: for each `IntentSpec` build an `Intent` (action or explicit component, extras, `data = package:<pkg>` for app details, notification settings get `Settings.EXTRA_APP_PACKAGE`, `FLAG_ACTIVITY_NEW_TASK`) and `startActivity`; catch `ActivityNotFoundException` and `SecurityException` and try the next one.
- Plugin: `getReliabilityStatus` → `result.success(map)`; `ackMissed` → `ReliabilityReader.ack(ctx, upTo)` (missing `upTo` → `BAD_ARGS`); `openSystemSettings` → `result.success(SystemSettingsLauncher.open(ctx, target))`.
- Manifest `<queries>`: add `<package android:name="com.miui.securitycenter" />` and `<package android:name="com.miui.powerkeeper" />` beside the existing `PROCESS_TEXT` intent.

- [ ] **Step 4: Run the Kotlin tests and compile**

Run: `cd android && ./gradlew :app:testDebugUnitTest` then `fvm flutter build apk --debug`
Expected: BUILD SUCCESSFUL; APK built.

- [ ] **Step 5: Commit**

```bash
git add android/app/src/main/kotlin/com/example/quran_app/ReliabilityReader.kt android/app/src/main/kotlin/com/example/quran_app/SystemSettingsLauncher.kt android/app/src/main/kotlin/com/example/quran_app/AlertPlanner.kt android/app/src/main/kotlin/com/example/quran_app/PrayerStripPlugin.kt android/app/src/main/AndroidManifest.xml android/app/src/test/kotlin/com/example/quran_app/ReliabilityRulesTest.kt
git commit -m "feat(alerts): native reliability status, miss acknowledgement and settings deep links

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 7: AlertsSyncCubit, countdown fix and precache

**Files:**
- Create: `lib/features/notifications/domain/usecases/get_cached_prayer_days.dart`, `lib/features/notifications/presentation/cubit/alerts_sync_cubit.dart`
- Modify: `lib/features/home/presentation/pages/home_page.dart`, `lib/features/home/presentation/cubit/prayer_countdown_cubit.dart`, `lib/features/home/domain/usecases/pre_cache_prayer_times.dart`, `lib/features/notifications/domain/usecases/build_prayer_strip_window.dart`, `lib/features/notifications/notifications_di.dart`, `lib/features/notifications/data/repositories/notifications_repository_impl.dart` (iOS day pick, Android-only strip calls)
- Test: `test/features/notifications/domain/usecases/get_cached_prayer_days_test.dart` (new), `test/features/notifications/domain/usecases/build_prayer_strip_window_test.dart`, `test/features/notifications/data/repositories/notifications_repository_impl_test.dart`, `test/features/notifications/presentation/cubit/alerts_sync_cubit_test.dart` (new), `test/features/home/presentation/cubit/prayer_countdown_cubit_test.dart`, `test/features/home/domain/usecases/pre_cache_prayer_times_test.dart` (the case "mid-month: pre-caches only current month" inverts)

**Interfaces:**
- Consumes: `SyncDailyAdhans`/`SyncDailyAdhansParams` (Task 3), `Settings.prayerAlerts`, `stripStyle`, `isPrayerStripPinned` (Task 2), existing `BuildPrayerStripWindow`, `EnablePrayerStrip`, `DisablePrayerStrip`, `PrayerTimesRepository.getCachedForDate`.
- Produces:
  - `GetCachedPrayerDays extends UseCase<List<PrayerTimes>, GetCachedPrayerDaysParams>`, `GetCachedPrayerDaysParams({DateTime? now, int maxDays = 30})`: days from today on, stopping at the first gap. Registered with `sl.registerLazySingleton(() => GetCachedPrayerDays(prayerTimesRepository: sl()))` in `initNotifications()`.
  - `BuildPrayerStripWindowParams` gains `required List<PrayerTimes> cachedDays`: the use case builds from its first `days` entries, so one sync reads the cache once. `BuildPrayerStripWindow()` loses `prayerTimesRepository` and its `getCachedForDate` loop, which had no other caller (registered as `sl.registerLazySingleton(() => BuildPrayerStripWindow())`).
  - `AlertsSyncCubit extends Cubit<DateTime?>` (state = time of the last completed sync) with `AlertsSyncCubit({required SettingsCubit settingsCubit, required GetCachedPrayerDays getCachedPrayerDays, required SyncDailyAdhans syncDailyAdhans, required BuildPrayerStripWindow buildPrayerStripWindow, required EnablePrayerStrip enablePrayerStrip, required DisablePrayerStrip disablePrayerStrip, Duration debounce = const Duration(milliseconds: 300), DateTime Function() clock = DateTime.now})`, `void requestSync()`, `Future<void> syncNow()` (visible for tests; coalesces: while a pass runs, callers get the running future and one more pass runs with freshly read settings when it ends, unless the cubit closed), `close()` cancels the timer. Registered as a factory in `initNotifications()`.
  - `AlertsSyncCubit.listensTo(Settings prev, Settings curr): bool` (static, used by HomePage's `listenWhen`): true when `prayerAlerts`, `stripStyle`, `isPrayerStripPinned`, `isArabic`, `isFormat12Hours`, `palette`, `calculationMethod` or `asrSchool` differ.
  - `NotificationsRepositoryImpl` gains `DateTime Function() clock = DateTime.now`. On iOS, `scheduleDailyAdhans` and `schedulePrayerReminders` use the first day in `days` with an alert-prayer time after `clock()` (else `days.first`), because `days` now starts today and after Isha that day has nothing left. `enableStrip` and `disableStrip` go through `_runAndroidOnly` (Right on iOS, no channel call).
  - Declared exception: `AlertsSyncCubit` holds a bare `DateTime?` state instead of a sealed `Equatable` state, because it is a side-effect cubit whose only state is "last synced at".
  - Declared exception: `GetCachedPrayerDays` returns a plain `List`, not `Either`, because it reads only the local cache and has no failure worth surfacing.
  - Known trade-off: HomePage no longer re-pushes the strip when the countdown's next prayer changes (spec §8 lists four triggers). `PrayerStripController`'s exact alarms move the pill, so while exact alarms are denied the pill can lag in the foreground until the next resume.

- [ ] **Step 1: Write the failing tests**

```dart
test('GetCachedPrayerDays stops at the first gap and caps at maxDays', () async {
  when(() => repo.getCachedForDate(any())).thenAnswer((i) async {
    final d = i.positionalArguments.first as DateTime;
    return d.day == 18 ? null : fakePrayerTimes(d);
  });
  final days = await usecase(GetCachedPrayerDaysParams(now: DateTime(2026, 11, 15, 9)));
  expect(days.length, 3);
  final capped = await usecase(GetCachedPrayerDaysParams(now: DateTime(2026, 11, 19), maxDays: 5));
  expect(capped.length, 5);
});
```

```dart
group('AlertsSyncCubit', () {
  test('debounces bursts into one sync', () async {
    cubit.requestSync(); cubit.requestSync(); cubit.requestSync();
    await Future<void>.delayed(const Duration(milliseconds: 5));
    verifyNever(() => sync(any()));
    await Future<void>.delayed(const Duration(milliseconds: 40));
    verify(() => sync(any())).called(1);
  });
  test('close during debounce cancels the pending sync', () async {
    cubit.requestSync();
    await cubit.close();
    await Future<void>.delayed(const Duration(milliseconds: 40));
    verifyNever(() => sync(any()));
  });
  test('sends every cached day and the settings alerts', () async {
    await cubit.syncNow();
    final p = verify(() => sync(captureAny())).captured.single as SyncDailyAdhansParams;
    expect(p.days.length, 30);
    expect(p.alerts, settings.prayerAlerts);
    expect(p.localeCode, 'ar');
  });
  test('strip pinned builds a 30-day window and enables it', () async { ... verify(() => build(any(that: isA<BuildPrayerStripWindowParams>().having((p) => p.days, 'days', 30)))) ... verify(() => enable(any())).called(1); });
  test('strip unpinned disables it', () async { ... verify(() => disable(any())).called(1); verifyNever(() => enable(any())); });
  test('no cached days skips the sync call', () async { ... verifyNever(() => sync(any())); });
  test('strip reuses the days already read', () async {
    await cubit.syncNow();
    final p = verify(() => build(captureAny())).captured.single as BuildPrayerStripWindowParams;
    expect(p.cachedDays, same(cachedDays));
    verify(() => getDays(any())).called(1);
  });
  test('listensTo ignores unrelated fields', () {
    expect(AlertsSyncCubit.listensTo(s, s.copyWith(pageBrightness: 0.5)), isFalse);
    expect(AlertsSyncCubit.listensTo(s, s.copyWith(stripStyle: const StripStyle(expanded: false))), isTrue);
  });
});
```

```dart
test('builds the window from cachedDays', () async {
  final w = await usecase(BuildPrayerStripWindowParams(localeCode: 'ar', use24Hour: true, now: DateTime(2026, 11, 15, 9), days: 30, cachedDays: [fakePrayerTimes(DateTime(2026, 11, 15)), fakePrayerTimes(DateTime(2026, 11, 16))]));
  expect(w!.days.length, 2);
});
```

Build the cubit with `debounce: const Duration(milliseconds: 20)` and mocktail mocks for each use case (no new dev dependency). `SettingsCubit` is a real instance, with `setUpAll(() => HydratedBloc.storage = _MemStorage())` using a local copy of the private class in `settings_cubit_test.dart`; the group uses `setUp(() async { await HydratedBloc.storage.clear(); settingsCubit = SettingsCubit(); cubit = AlertsSyncCubit(...); })` and `tearDown` closes both, so no state leaks between tests.

The countdown cubit reads `DateTime.now()`, and the file's existing `ctxFor` places all six prayers at fixed hours, so add a sibling helper with timings relative to now, small enough that only the 15 minutes around midnight are skipped:

```dart
DailyPrayerContext contextWithOffsets(DateTime now, Map<PrayerName, int> minutes) {
  final base = ctxFor(now);
  String hm(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  return DailyPrayerContext(
    location: base.location,
    date: base.date,
    prayerTimes: PrayerTimes(
      key: base.prayerTimes.key,
      timings: {for (final e in minutes.entries) e.key: hm(now.add(Duration(minutes: e.value)))},
      date: base.prayerTimes.date,
    ),
  );
}

test('next prayer skips sunrise', () async {
  final now = DateTime.now();
  const offsets = {PrayerName.fajr: -2, PrayerName.sunrise: 2, PrayerName.dhuhr: 4, PrayerName.asr: 6, PrayerName.maghrib: 8, PrayerName.isha: 10};
  if (now.subtract(const Duration(minutes: 3)).day != now.day || now.add(const Duration(minutes: 11)).day != now.day) {
    markTestSkipped('fixture would cross midnight');
    return;
  }
  final cubit = PrayerCountdownCubit();
  cubit.startTimer(contextWithOffsets(now, offsets));
  final tick = cubit.state as PrayerCountdownTick;
  expect(tick.prayerCountdown.nextPrayer, PrayerName.dhuhr);
  expect(tick.prayerCountdown.currentPrayer, PrayerName.fajr);
  expect(tick.prayerCountdown.remainingTime.inMinutes, inInclusiveRange(2, 4));
  await cubit.close();
});
```

Midnight rule: the test skips when `now − 3 min` or `now + 11 min` falls on another calendar day, because `HH:mm` timings would wrap and the cubit would read them as today. Timings are truncated to the minute, hence the 2–4 minute range.

```dart
test('mid-month: pre-caches current and next month', () async {
  await usecase.call(PreCachePrayerTimesParams(location: location, now: DateTime(2025, 5, 15, 10)));
  verify(() => repo.preCacheMonth(location: location, year: 2025, month: 5)).called(1);
  verify(() => repo.preCacheMonth(location: location, year: 2025, month: 6)).called(1);
});
```

- [ ] **Step 2: Run to verify they fail**

Run: `fvm flutter test test/features/notifications test/features/home`
Expected: failures (missing classes; countdown returns sunrise; precache skips June).

- [ ] **Step 3: Implement**

- `BuildPrayerStripWindow.call`: loop over the first `min(params.days, params.cachedDays.length)` entries of `cachedDays`; the repository dependency goes.
- `PreCachePrayerTimes`: always call `preCacheMonth` for the next month after the current one (the repository already skips a fully cached month, so "whenever it isn't cached" needs no new check). Delete `_daysInMonth`.
- `PrayerCountdownCubit._emitTick`: in the loop, when `prayerName == PrayerName.sunrise` and `now` is not after it, `continue` without selecting it as next; `currentPrayer` logic is unchanged.
- `AlertsSyncCubit.syncNow()`: read `settingsCubit.state.settingsModel`; read `clock()` once as `now`; `days = await getCachedPrayerDays(GetCachedPrayerDaysParams(now: now))`; if `!s.isPrayerStripPinned`, `disablePrayerStrip(NoParams())` first (so an unpin hides the strip even with an empty cache); if `days` is empty return; `await syncDailyAdhans(SyncDailyAdhansParams(days: days, alerts: s.prayerAlerts, localeCode: s.isArabic ? 'ar' : 'en'))`; if `s.isPrayerStripPinned`, build the window with `BuildPrayerStripWindowParams(localeCode: …, use24Hour: s.is24HourFormat, accentColor: s.palette.primary.toARGB32(), now: now, days: 30, cachedDays: days)` and enable it when non-null; log failures with `debugPrint`, never throw; `if (isClosed) return;` before `emit(clock())`. `requestSync()` cancels and restarts the timer.
- `HomePage`: provide `BlocProvider(create: (_) => sl<AlertsSyncCubit>())`. Listeners become: context loaded → `requestSync()` and `unawaited(sl<PreCachePrayerTimes>()(…).then((_) { if (context.mounted) context.read<AlertsSyncCubit>().requestSync(); }))`; `SettingsCubit` with `listenWhen: (p, c) => AlertsSyncCubit.listensTo(p.settingsModel, c.settingsModel)` → `requestSync()`, plus the existing silent context refetch only when method or school changed. `_StripResumeGuard` calls `requestSync()` instead of `_enableOrRefreshStrip`. Delete `_enableOrRefreshStrip`, the day-collection loops, the countdown next-prayer listener (spec §8 lists four triggers; `PrayerStripController` already re-renders at each prayer boundary through its exact alarms), the pin-off listener and the `PrayerTimesLocalDataSource` import.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `fvm flutter test test/features/notifications test/features/home`
Expected: PASS.

- [ ] **Step 5: Analyze and commit**

Run: `fvm flutter analyze --no-fatal-infos` (no new issues).

```bash
git add lib/features/notifications/domain/usecases/get_cached_prayer_days.dart lib/features/notifications/presentation/cubit/alerts_sync_cubit.dart lib/features/notifications/notifications_di.dart lib/features/home/presentation/pages/home_page.dart lib/features/home/presentation/cubit/prayer_countdown_cubit.dart lib/features/home/domain/usecases/pre_cache_prayer_times.dart lib/features/notifications/domain/usecases/build_prayer_strip_window.dart test/features/notifications/domain/usecases/get_cached_prayer_days_test.dart test/features/notifications/domain/usecases/build_prayer_strip_window_test.dart test/features/notifications/presentation/cubit/alerts_sync_cubit_test.dart test/features/home/presentation/cubit/prayer_countdown_cubit_test.dart test/features/home/domain/usecases/pre_cache_prayer_times_test.dart
git commit -m "feat(alerts): AlertsSyncCubit owns scheduling; countdown skips sunrise; always precache next month

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 8: Shared tiles and sheets, Settings row, notifications page, prayer sheet, pickers, palette getters

Widget files live beside the page that uses them. `NotificationsSettingsPage` and `TestAdhanButton` move into the notifications feature with `git mv` (the route and its path stay). The status line and the strip row render here without navigation; Task 10 wires the strip row and Task 11 wires the status line, so every commit stays runnable.

**Files:**
- Modify: `lib/config/theme/app_palette.dart` (getters, `colorScheme` reads them), `lib/features/settings/presentation/pages/settings_page.dart`, `lib/config/router/app_router.dart` (notifications route providers), `lib/core/constants/feature_flags.dart` (delete the file: its only flag goes away), `.claude/rules/core-widgets.md`, `.claude/rules/core-utilities.md` (drop `FeatureFlags`), `.claude/rules/feature-widgets.md` (notifications utils), `CLAUDE.md` (drop `FeatureFlags…` from the `core/constants/` line), `lib/features/notifications/notifications_di.dart` (factories for `ReliabilityCubit`, `SoundPreviewCubit`, `TodayPrayerTimesCubit`)
- Move: `lib/features/home/presentation/pages/notifications_settings_page.dart` → `lib/features/notifications/presentation/pages/notifications_settings_page.dart`; `lib/features/home/presentation/pages/widgets/test_adhan_button.dart` → `lib/features/notifications/presentation/pages/widgets/test_adhan_button.dart`; `lib/features/home/presentation/utils/calculation_method_localization.dart` → `lib/features/notifications/presentation/utils/calculation_method_localization.dart` (its only caller is the moved page, so the page imports no `home` presentation code)
- Delete: `lib/features/home/presentation/pages/widgets/{per_prayer_adhan_tile,reminder_offset_dropdown,setting_switch}.dart`
- Create:
  - `lib/core/widgets/design/app_settings_tile.dart`, `lib/core/widgets/design/app_option_sheet.dart`, `lib/config/theme/palette_context.dart` (`context.palette`; recorded in `.claude/rules/theming.md` and `core-utilities.md`)
  - `lib/features/notifications/domain/services/alerts_status_resolver.dart`
  - `lib/features/notifications/presentation/cubit/{reliability_cubit,reliability_state,sound_preview_cubit,today_prayer_times_cubit}.dart`
  - `lib/features/notifications/presentation/utils/enum_localization.dart`
  - `lib/features/notifications/presentation/pages/widgets/{alerts_status_line,prayer_alert_tile,prayer_alert_sheet,reminder_picker,sound_picker,alerts_list_parts}.dart` (`alerts_list_parts.dart` holds the `AlertsNote` info line and `AlertsRowDivider` shared by the page and the sheet)
- Test: `test/features/notifications/notifications_di_test.dart`, `test/core/widgets/design/{app_option_sheet_test,app_settings_tile_test}.dart`, `test/features/notifications/domain/services/alerts_status_resolver_test.dart`, `test/features/notifications/presentation/cubit/{reliability_cubit_test,sound_preview_cubit_test,today_prayer_times_cubit_test}.dart`, `test/features/notifications/presentation/utils/enum_localization_test.dart`, `test/features/notifications/presentation/pages/widgets/{prayer_alert_sheet_test,reminder_picker_test,test_adhan_button_test}.dart`, `test/features/notifications/presentation/pages/notifications_settings_page_test.dart` (states plus an ar/en 360×640 smoke test with the bundled Cairo fonts), `test/features/settings/presentation/pages/settings_page_test.dart`, the shared `test/features/notifications/presentation/alerts_test_harness.dart` (`MemStorage`, `alertsApp`, `cairoToday`, `loadAppFonts`), `test/config/theme/app_palette_test.dart` (add getter cases)

**Interfaces:**
- Consumes: Task 2 entities and intents; Task 3 `GetReliabilityStatus`, `AckMissedAlerts`, `OpenSystemSettings`, `PreviewAlertSound`, `StopAlertPreview`, `ScheduleTestAdhan`, `ReliabilityStatus`, `PreviewSound`, `SystemSettingsTarget`; Task 7 `GetCachedPrayerDays`.
- Produces:
  - `AppPaletteX`: `Color get onPrimary`, `primaryInk`, `primaryTint`, `error`, `onError` (today's values: `onPrimary` #F5F5F5; `primaryInk` = `primary` in light, `secondary` in dark; `primaryTint` = `primary.withValues(alpha: 0.12)` light, `secondary.withValues(alpha: 0.22)` dark; `error` = `AppColors.error`; `onError` = #0D0D0D dark, #F5F5F5 light, i.e. today's `colorScheme.onError`, so this commit changes no pixel). `colorScheme` reads `onPrimary`, `error`, `onError` from them.
  - `AppSettingsTile({Key? key, required String title, String? subtitle, Widget? leading, Widget? trailing, VoidCallback? onTap, bool enabled = true})`: min height 48, `EdgeInsetsDirectional` padding 16, `TS.semi16`/`TS.regular14` (titles 600 per final-spec §1 weight discipline), 38% opacity and no tap when disabled. Replaces `_ReadingSettingsRow` and `_NotificationRow`.
  - `class AppOption<T> { const AppOption({required this.value, required this.label, this.subtitle, this.leading, this.trailing}); }` and `Future<void> showAppOptionSheet<T>({required BuildContext context, required String title, required List<AppOption<T>> options, required T selected, required ValueChanged<T> onSelected, Widget? footer, VoidCallback? onClosed})`: modal bottom sheet, `RadioGroup<T>` over `RadioListTile<T>` rows with `secondary` = `trailing`, then `footer` under the rows when non-null; selecting calls `onSelected` and pops; `onClosed` runs once when the sheet is dismissed by any means (`.whenComplete`).
  - `enum AlertsStatusKind { allOff, off, attention, ok, okNoDate }`; `AlertsStatusKind resolveAlertsStatus({required int enabledCount, required ReliabilityStatus status, required bool isAndroid, required DateTime now})`.
  - `ReliabilityCubit(GetReliabilityStatus, AckMissedAlerts, OpenSystemSettings)` factory; states `sealed ReliabilityState`, `ReliabilityLoading`, `ReliabilityLoaded(ReliabilityStatus status)`, `ReliabilityUnavailable`; methods `Future<void> load()`, `Future<void> ackMissed(ReliabilityStatus shown)` (calls `AckMissedAlerts` with `upTo` = the newest `at` across `shown.missed` and `shown.late`; no call when both are empty), `Future<void> openSettings(SystemSettingsTarget target)`; reloads on resume through an `AppLifecycleListener` disposed in `close()`; `load()` runs in the constructor.
  - `SoundPreviewCubit(PreviewAlertSound, StopAlertPreview, WatchPreviewEnded) extends Cubit<PreviewSound?>`: `play(PreviewSound sound, PrayerName prayer)` (playing the same sound again stops it), `stop()`, `close()` stops and cancels the `previewEnded` subscription it opens in the constructor; an ended event for the playing sound emits `null`, any other is ignored.
  - `TodayPrayerTimesCubit(GetCachedPrayerDays) extends Cubit<PrayerTimes?>`: `load()` reads `maxDays: 1`.
  - `enum_localization.dart`: `String prayerLabel(BuildContext context, PrayerName p)` (existing `S.of(context).fajr`…), `String prayerSoundLabel(PendingS s, PrayerSound sound, {required PrayerName prayer, required bool ios})` (adhan → `alerts_sound_fajrAdhan`/`alerts_sound_adhan`, clip variants on iOS), `String reminderSoundLabel(PendingS s, ReminderSound sound, {bool ios = false})` (a stored `vibrate` reads as silent on iOS, in both sound labels), `String minutesLabel(PendingS s, int minutes, String localeCode)`, `String enabledCountLabel(PendingS s, int count, String localeCode)`, `String alertSummary(PendingS s, PrayerAlert a, {required PrayerName prayer, required bool ios, required String localeCode})`, `HugeIcon`-ready `List<List<dynamic>> prayerAlertIcon(PrayerAlert a)` (`strokeRoundedVolumeHigh` for adhan, `strokeRoundedNotification01` for tone/vibrate, `strokeRoundedNotificationOff01` for off or silent). `String? prayerTimeLabel(String? hhmm, {required bool use24Hour, required String localeCode, int minutesBefore = 0})` (`h:mm a` or `HH:mm`; `null` for a missing or malformed time such as `"25:00"`, `"5:7x"`, `""`), `String alertsDateLabel(DateTime date, String localeCode)` (`d MMMM`). Every number goes through `toIndicNumerals(localeCode)`.
  - Widgets: `AlertsStatusLine({VoidCallback? onTap})`, `PrayerAlertTile({required PrayerName prayer})`, `PrayerAlertSheet.show(BuildContext context, PrayerName prayer)`, `ReminderPicker({required int minutes, required bool enabled, required String? rawTime, required bool use24Hour, required ValueChanged<int> onCommit})` (computes «يصلك» from its draft value, so the time follows the slider while dragging; the slider's `semanticFormatterCallback` reads `minutesLabel`), `showPrayerSoundPicker(BuildContext context, PrayerName prayer)`, `showReminderSoundPicker(BuildContext context, PrayerName prayer)`, `TestAdhanButton()`.

- [ ] **Step 1: Write the failing pure tests**

```dart
group('resolveAlertsStatus', () {
  final ok = ReliabilityStatus(notificationsEnabled: true, channelBlocked: false, exactAlarmsAllowed: true, batteryUnrestricted: true, isXiaomi: false, usesAlarmClock: true, scheduledUntil: DateTime(2026, 11, 21, 18, 16), snapshotUntil: DateTime(2026, 12, 31), missed: const [], late: const []);
  final now = DateTime(2026, 11, 15, 12);
  AlertsStatusKind r(ReliabilityStatus s, {int count = 5, bool android = true}) => resolveAlertsStatus(enabledCount: count, status: s, isAndroid: android, now: now);
  test('rule 1 wins over everything', () => expect(r(ok.copyWith(notificationsEnabled: false), count: 0), AlertsStatusKind.allOff));
  test('rule 2', () => expect(r(ok.copyWith(notificationsEnabled: false)), AlertsStatusKind.off));
  test('rule 3 triggers', () {
    expect(r(ok.copyWith(channelBlocked: true)), AlertsStatusKind.attention);
    expect(r(ok.copyWith(exactAlarmsAllowed: false)), AlertsStatusKind.attention);
    expect(r(ok.copyWith(late: [MissedAlert(prayer: PrayerName.asr, at: now)])), AlertsStatusKind.attention);
    expect(r(ok.copyWith(scheduledUntil: DateTime(2026, 11, 14))), AlertsStatusKind.attention);
    expect(r(ok.copyWith(clearScheduledUntil: true)), AlertsStatusKind.attention);
    expect(r(ok.copyWith(isXiaomi: true, batteryUnrestricted: false)), AlertsStatusKind.attention);
  });
  test('battery on non-Xiaomi counts only without alarm clock', () {
    expect(r(ok.copyWith(batteryUnrestricted: false)), AlertsStatusKind.ok);
    expect(r(ok.copyWith(batteryUnrestricted: false, usesAlarmClock: false)), AlertsStatusKind.attention);
  });
  test('rule 4', () {
    expect(r(ok), AlertsStatusKind.ok);
    expect(r(const ReliabilityStatus.ios(notificationsEnabled: true), android: false), AlertsStatusKind.okNoDate);
  });
});
```

```dart
testWidgets('alertSummary renders Arabic-Indic digits', (tester) async {
  final s = await pendingFor(tester, 'ar');
  expect(alertSummary(s, const PrayerAlert(reminderEnabled: true, reminderMinutes: 10), prayer: PrayerName.fajr, ios: false, localeCode: 'ar'), 'أذان الفجر، تذكير قبل ١٠ دقائق');
  expect(alertSummary(s, const PrayerAlert(enabled: false, reminderEnabled: true), prayer: PrayerName.asr, ios: false, localeCode: 'ar'), 'متوقف');
});
testWidgets('alertSummary in English with ring in silent', (tester) async {
  final s = await pendingFor(tester, 'en');
  expect(alertSummary(s, const PrayerAlert(ringInSilent: true, reminderEnabled: true, reminderMinutes: 1), prayer: PrayerName.dhuhr, ios: false, localeCode: 'en'), 'Adhan, rings in silent mode, reminder 1 minute before');
  expect(alertSummary(s, const PrayerAlert(ringInSilent: true), prayer: PrayerName.dhuhr, ios: true, localeCode: 'en'), 'Adhan clip');
});
testWidgets('settings row subtitle uses Arabic digits', (tester) async {
  expect(enabledCountLabel(await pendingFor(tester, 'ar'), 4, 'ar'), 'مفعّل لـ٤ صلوات');
});
```

`pendingFor` mirrors `_pending` in `test/core/localization/pending_s_test.dart`. The summary joins the sound name, `alerts_summary_ringsInSilent` (only for adhan, Android, `ringInSilent`), and `alerts_summary_reminder(minutesLabel(...))` (only when `effectiveReminderMinutes != null`) with «، » in Arabic and ", " in English; a disabled alert is `alerts_summary_off` alone.

- [ ] **Step 2: Write the failing cubit tests** (bloc_test)

```dart
blocTest<ReliabilityCubit, ReliabilityState>('loads on create',
  build: () { when(() => get(any())).thenAnswer((_) async => Right(status)); return cubit(); },
  expect: () => [ReliabilityLoaded(status)]);
blocTest<ReliabilityCubit, ReliabilityState>('failure emits unavailable', ... expect: () => [const ReliabilityUnavailable()]);
blocTest<ReliabilityCubit, ReliabilityState>('ackMissed acks up to the newest shown alert then reloads', act: (c) => c.ackMissed(statusWithIshaMissAndAsrLate), verify: (_) { verify(() => ack(AckMissedAlertsParams(upTo: newestOfTheTwo))).called(1); verify(() => get(any())).called(2); });
blocTest<ReliabilityCubit, ReliabilityState>('ackMissed with nothing shown does not ack', act: (c) => c.ackMissed(status), verify: (_) => verifyNever(() => ack(any())));
blocTest<SoundPreviewCubit, PreviewSound?>('play then play same stops', act: (c) { c.play(PreviewSound.adhan, PrayerName.fajr); c.play(PreviewSound.adhan, PrayerName.fajr); }, expect: () => [PreviewSound.adhan, null]);
test('SoundPreviewCubit.close stops the preview', () async { await cubit.close(); verify(() => stop(any())).called(1); });
```

- [ ] **Step 3: Write the failing widget tests**

- `app_option_sheet_test.dart`: `showAppOptionSheet<int>` with options 1, 2, 3 and `selected: 2`; the radio for 2 is selected; tapping the label of 3 calls `onSelected(3)` and the sheet closes; a `trailing: Icon(Icons.play_arrow)` on option 1 is found; a `footer: Text('f')` renders below the rows; `onClosed` is called exactly once after a selection and once after a barrier tap.
- `prayer_alert_sheet_test.dart` (real `SettingsCubit` above `MaterialApp`, a `TodayPrayerTimesCubit` stub provided around a `Scaffold` whose button calls `PrayerAlertSheet.show(context, PrayerName.fajr)`, Arabic locale; each test taps the button and `pumpAndSettle`s, so the sheet is opened from a pumped page as in production; storage installed in `setUpAll` with a local `_MemStorage` copy, then `setUp(() async { await HydratedBloc.storage.clear(); settingsCubit = SettingsCubit(); })`): with `PrayerAlert(enabled: false)` the reminder switch's `onChanged` is null and `alerts_sheet_reminderDisabled` text is shown; with `sound: PrayerSound.tone` the ring-in-silent switch's `onChanged` is null; toggling the alert switch writes `enabled: true` to the cubit; under `debugDefaultTargetPlatformOverride = TargetPlatform.iOS` there is no ring-in-silent switch and `alerts_sheet_iosNote` is shown.
- `reminder_picker_test.dart`: dragging the slider calls `onCommit` once (on drag end) with the final value; tapping chip «٣٠ دقيقة» calls `onCommit(30)`; the label reads «قبل ١٠ دقائق» for 10; `rawTime: null` hides the «يصلك» line; mid-drag the value and «يصلك» move together before release; the slider's semantics value reads «١٠ دقائق», never a percentage.
- `test_adhan_button_test.dart`: with a `ReliabilityCubit` stub in `ReliabilityLoaded(status.copyWith(notificationsEnabled: false))`, tapping shows `alerts_testBlocked`; with an ok status it calls `ScheduleTestAdhan` and shows `alerts_testCaption`; a `Left` from `ScheduleTestAdhan` shows `alerts_testBlocked`.

- [ ] **Step 4: Run to verify they fail**

Run: `fvm flutter test test/core/widgets test/features/notifications test/config`
Expected: compile errors on the missing classes.

- [ ] **Step 5: Implement**

Status rules (body pinned here because the order matters):

```dart
AlertsStatusKind resolveAlertsStatus({required int enabledCount, required ReliabilityStatus status, required bool isAndroid, required DateTime now}) {
  if (enabledCount == 0) return AlertsStatusKind.allOff;
  if (!status.notificationsEnabled) return AlertsStatusKind.off;
  final until = status.scheduledUntil;
  final batteryMatters = status.isXiaomi || !status.usesAlarmClock;
  if (status.channelBlocked ||
      !status.exactAlarmsAllowed ||
      status.missed.isNotEmpty ||
      status.late.isNotEmpty ||
      (until != null && until.isBefore(now)) ||
      (isAndroid && until == null) ||
      (batteryMatters && !status.batteryUnrestricted)) {
    return AlertsStatusKind.attention;
  }
  return until != null ? AlertsStatusKind.ok : AlertsStatusKind.okNoDate;
}
```

Page and widgets (layout per spec §8 UI and Appendix C; the visual reference is `docs/design-audit/prayer/settings/final-spec.md`, local):
- `AlertsStatusLine`: zero enabled alerts shows `allOff` (`enabledCountLabel(s, 0, …)`, `NotificationOff01`) before reading reliability, whatever its state; otherwise `BlocBuilder<ReliabilityCubit, ReliabilityState>`; `ReliabilityLoading` renders the same tile inside `Skeletonizer`; `allOff` → `enabledCountLabel(s, 0, …)`, `off` → `alerts_status_off`, `attention` → `alerts_status_attention`, `ok` → `alerts_status_ok(date)` with the date formatted `d MMMM` in the app locale and Indic digits, `okNoDate` → `alerts_status_okNoDate`; `ReliabilityUnavailable` shows the `okNoDate` text with a neutral `Notification01` icon in `onSurfaceVariant` (the check is kept for resolved `ok`/`okNoDate`). Palette colours come from `context.palette` (`config/theme/palette_context.dart`). No warning glyphs and no red (spec Appendix C).
- `NotificationsSettingsPage`: `ListView` with `AlertsStatusLine()`, `AppSectionHeader(alerts_prayersSection)` + `SurfaceCard` of five `PrayerAlertTile`s, the `alerts_silentTruth`/`alerts_iosTruth` line, the strip row (Android only, `AppSettingsTile(title: alerts_stripRow_title, subtitle: off/on/onExpanded from isPrayerStripPinned and stripStyle.expanded)`, no `onTap` yet), `AppSectionHeader(alerts_timesSection)` with method and Asr `AppSettingsTile`s opening `showAppOptionSheet` (values `CalculationMethod.values` / `AsrSchool.values`, labels from the existing `.localized(context)`), the `alerts_autoMethodReason` line when the method is `auto`, and `TestAdhanButton`. Delete `_NotifDisabledBanner` (the status line covers it) and `_PickerRow`.
- `PrayerAlertTile`: `BlocSelector<SettingsCubit, SettingsState, PrayerAlert>`; leading `prayerAlertIcon`, title `prayerLabel`, subtitle `alertSummary`, trailing today's time from `TodayPrayerTimesCubit` (hidden when `null`, formatted with the user's 12/24 h setting and Indic digits); tap → `PrayerAlertSheet.show`.
- `PrayerAlertSheet.show`: the modal route sits outside the page's providers, so it captures `final today = context.read<TodayPrayerTimesCubit>();` and builds `BlocProvider.value(value: today, child: PrayerAlertSheet(prayer: prayer))`; `SettingsCubit` is app-wide (provided in `main.dart` above `MaterialApp`) and needs no wrapping.
- `PrayerAlertSheet`: alert switch, sound row (`showPrayerSoundPicker`), ring-in-silent switch (Android only; enabled only when `enabled && sound == adhan`; shows `ringInSilent && sound == adhan`, stored value kept), iOS note, reminder switch, `ReminderPicker`, reminder-sound row; sections use `Column(spacing:)`; the disabled slider and chips rely on the Material disabled colours (no extra `Opacity`), and the picker's own texts switch to `onSurface` at 38%; every change calls `updatePrayerAlert` immediately. The sheet passes today's raw time and `use24Hour`; the picker formats «يصلك» like the tile, hidden when today's timings are missing.
- `ReminderPicker`: `StatefulWidget` holding a local draft; `Slider(min: 1, max: 60, divisions: 59, onChanged: setState, onChangeEnd: onCommit)`; chips 5/10/15/30 labelled with `minutesLabel` («٥ دقائق» … «٣٠ دقيقة») commit at once; label `alerts_sheet_reminderValue(minutesLabel(...))`; slider end labels `minutesLabel(1)`/`minutesLabel(60)` («دقيقة واحدة»/«٦٠ دقيقة»: final-spec lists a bare-number end label as a defect that must not come back).
- `sound_picker.dart`: `showPrayerSoundPicker` lists adhan, tone, vibrate (not on iOS), silent with `alerts_picker_silentSub` under silent; `showReminderSoundPicker` lists tone, vibrate (not on iOS), silent. On Android the adhan and tone rows get a trailing 48 px `IconButton` (`strokeRoundedPlay`/`strokeRoundedStop`, tooltip `alerts_picker_preview(label)`/`alerts_picker_stopPreview`) driven by one `SoundPreviewCubit` per sheet: the picker creates `final preview = sl<SoundPreviewCubit>();` before calling `showAppOptionSheet`, wraps each trailing button in `BlocProvider.value(value: preview, child: _PreviewButton(...))`, passes `footer: BlocProvider.value(value: preview, child: const _PreviewFooter())` (a thin `LinearProgressIndicator` plus `alerts_picker_previewing`, `SizedBox.shrink()` while the state is `null`) and `onClosed: preview.close`, so dismissing the sheet stops the preview. Pickers on iOS create no cubit and pass no footer.
- `TestAdhanButton`: reads `context.read<ReliabilityCubit>().state`; blocked when loaded and `!notificationsEnabled || !exactAlarmsAllowed` → snackbar `alerts_testBlocked`, no schedule; otherwise schedule, then `alerts_testCaption` on `Right` or `alerts_testBlocked` on `Left`.
- `SettingsPage`: replace the mushaf row's `_ReadingSettingsRow` with `AppSettingsTile`; replace the two notification cards with one `SurfaceCard` holding `AppSettingsTile(title: S.of(context).adhan_and_reminders, subtitle: enabledCountLabel(PendingS.of(context), settings.enabledAlertCount, context.langCode), trailing: HugeIcon(icon: forwardArrowIcon(context), color: context.colorScheme.onSurfaceVariant, size: 20), onTap: push notificationsPath)`; delete `_ReadingSettingsRow`, `_NotificationRow`, the strip switch and the `FeatureFlags` import.
- `app_router.dart`: the notifications route builder wraps the page in `MultiBlocProvider(providers: [BlocProvider(create: (_) => sl<ReliabilityCubit>()), BlocProvider(create: (_) => sl<TodayPrayerTimesCubit>()..load())])`.
- DI: register `ReliabilityCubit`, `SoundPreviewCubit`, `TodayPrayerTimesCubit` as factories in `initNotifications()`; `test/features/notifications/notifications_di_test.dart` runs the real `initNotifications()` with mocked `PrayerNotificationScheduler` and `PrayerTimesRepository` and resolves the three cubits and `WatchPreviewEnded`.
- Rules docs: add `AppSettingsTile` and `AppOption`/`showAppOptionSheet` (with its `footer` and `onClosed` parameters) to `core-widgets.md`; in `CLAUDE.md` change `AssetsDir, DeviceSize, ColorPalette, MushafPaper, FeatureFlags…` to `AssetsDir, DeviceSize, ColorPalette, MushafPaper…`; add `notifications: enum_localization.dart` to `feature-widgets.md` (Task 9 adds `strip_style_colors.dart` when the file exists); remove `FeatureFlags` from `core-utilities.md`.

- [ ] **Step 6: Run the tests to verify they pass**

Run: `fvm flutter test test/core test/features/notifications test/features/settings test/features/home test/config`
Expected: PASS.

- [ ] **Step 7: Analyze and commit**

Run: `fvm flutter analyze --no-fatal-infos` (no new issues).

```bash
git add lib/config/theme/app_palette.dart lib/config/router/app_router.dart lib/core/constants/feature_flags.dart lib/core/widgets/design/app_settings_tile.dart lib/core/widgets/design/app_option_sheet.dart lib/features/settings/presentation/pages/settings_page.dart lib/features/home/presentation/pages lib/features/notifications test/core/widgets/design/app_option_sheet_test.dart test/features/notifications test/config/theme/app_palette_test.dart .claude/rules/core-widgets.md .claude/rules/core-utilities.md .claude/rules/feature-widgets.md CLAUDE.md
git commit -m "feat(alerts): notifications page, prayer alert sheet, sound pickers and Settings row

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 9: Strip payload and renderer

**Files:**
- Create: `lib/features/notifications/domain/entities/strip_render_style.dart`, `lib/features/notifications/presentation/utils/strip_style_colors.dart`, `T/PrayerStripTest.kt`
- Modify (Dart): `lib/features/notifications/domain/entities/prayer_cell.dart`, `prayer_strip_state.dart`, `prayer_strip_window.dart`, `lib/features/notifications/domain/builders/prayer_strip_state_builder.dart`, `lib/features/notifications/domain/usecases/build_prayer_strip_window.dart`, `lib/features/notifications/presentation/cubit/alerts_sync_cubit.dart`, `.claude/rules/theming.md` (list `strip_style_colors.dart` among the files allowed to hold hex literals, like `mushaf_paper_colors.dart`)
- Modify (Android): `K/PrayerStripState.kt`, `K/PrayerStripPlugin.kt` (`serializeStripArgs`), `K/PrayerStripController.kt`, `K/PrayerStripRenderer.kt`, `res/layout/prayer_strip_collapsed.xml`, `res/layout/prayer_strip_expanded.xml`, `res/drawable/strip_time_pill.xml`; create `res/drawable/strip_cell_pill.xml`, `res/drawable/strip_cell_outline.xml`
- Test (update): `test/features/notifications/domain/entities/{prayer_cell_test,prayer_strip_state_test,prayer_strip_window_test}.dart`, `test/features/notifications/domain/builders/prayer_strip_state_builder_test.dart`, `test/features/notifications/domain/usecases/build_prayer_strip_window_test.dart`, `test/features/notifications/data/datasources/notifications_native_data_source_test.dart`, `test/features/notifications/presentation/cubit/alerts_sync_cubit_test.dart`; new `test/features/notifications/presentation/utils/strip_style_colors_test.dart`

**Interfaces:**
- Consumes: Task 3 rows `enableStrip`/`refreshStrip`; Task 2 `StripStyle`; Task 7 `AlertsSyncCubit`; Task 8 `AppPaletteX.primary`.
- Produces:
  - `class StripRenderStyle extends Equatable { final bool expanded, countdown; final int highlightDay, highlightNight, pillTextDay, pillTextNight; final int? backgroundDay, backgroundNight; final String shape; Map<String, Object> toJson(); }` (colours serialised `#AARRGGBB`, absent backgrounds omitted).
  - `PrayerCell.nextLabel` (`String`, constructor default `''`), `PrayerStripState.nextTag` (`String`, default `''`; `fromJson` reads a missing key as `''`), so `enable_prayer_strip_test`, `refresh_prayer_strip_test` and `notifications_repository_impl_test` (lines 25–35) compile untouched. `accentColor` is removed from `PrayerStripState`, its JSON, the builder and `BuildPrayerStripWindowParams` (the style replaces it). `nextPrayerIndex` stays in the Dart entity and payload (Dart tests and `fromJson` use it); native never read it and keeps choosing the highlight itself through `pickDay`.
  - `PrayerStripWindow({required List<PrayerStripState> days, StripRenderStyle? style})`, `toJson()` adds `style` when set.
  - `BuildPrayerStripWindowParams` and `PrayerStripStateBuilder.build` gain `String Function(String prayerLabel)? nextInLabel` (null → `nextLabel` `''`) and `String nextTag = ''`; the params also gain `StripRenderStyle? style`.
  - `StripRenderStyle stripRenderStyle(StripStyle style, ColorPalette palette)` in `strip_style_colors.dart`, plus `Color stripHighlightSwatch(StripHighlight h, ColorPalette palette)` and `Color? stripBackgroundSwatch(StripBackground b)` for the Task 10 option sheets.
  - Kotlin: `data class StripStyleNative(expanded, countdown, highlightDay, highlightNight, pillTextDay, pillTextNight: Int, backgroundDay: Int?, backgroundNight: Int?, shape: String)` with defaults matching `StripStyle()` on the neutral palette: `expanded = true`, `countdown = true`, `highlightDay = 0xFF2E5244.toInt()`, `highlightNight = 0xFF93BAA8.toInt()`, `pillTextDay = 0xFFFFFFFF.toInt()`, `pillTextNight = 0xFF121413.toInt()`, `backgroundDay = null`, `backgroundNight = null`, `shape = "rounded"`; `PrayerStripDay.accentColor` and its parse/serialise lines (`PrayerStripState.kt:16`, `:45-47`, `:61`, `:86`, `PrayerStripPlugin.kt:188`) are deleted, and `PrayerStripRenderer.kt:78` reads `style.highlightDay`/`highlightNight` instead; `PrayerStripWindow(days, style)`; `PrayerCellNative.nextLabel`; `PrayerStripDay.nextTag`; `PrayerStripController.pickDay(window: PrayerStripWindow, todayKey: String, tomorrowKey: String, nowMinutes: Int): Pair<PrayerStripDay, Int>?` (pure; index `-1` = nothing highlighted).

Swatches (day / night ARGB, from the local design reference `final-spec.md` §strip-settings): app = `palette.primary` / #93BAA8 (neutral) or #8DB5CC (slate); darkGreen #4A7C6A / #8FC4AE; emerald #1E7A57 / #7FD1AE; blue #2F5F98 / #8EBBE3; indigo #4B4FA6 / #A9ABEB; maroon #9A3B3B / #E7A3A3; bronze #8A5A14 / #DDB77A. Pill text: #FFFFFF day, #121413 night. Backgrounds: auto = absent; mint #E3EFEA / #16302A; sand #F3ECDD / #2E2A20; sky #E3ECF5 / #1B2735; rose #F4E4E6 / #33201F.

- [ ] **Step 1: Write the failing Dart tests**

```dart
test('stripRenderStyle maps enums to day and night ARGB', () {
  final r = stripRenderStyle(const StripStyle(highlight: StripHighlight.maroon, background: StripBackground.sand, shape: StripShape.pill, showCountdown: false), ColorPalette.neutralLight);
  expect(r.highlightDay, 0xFF9A3B3B);
  expect(r.highlightNight, 0xFFE7A3A3);
  expect(r.pillTextDay, 0xFFFFFFFF);
  expect(r.pillTextNight, 0xFF121413);
  expect(r.backgroundDay, 0xFFF3ECDD);
  expect(r.shape, 'pill');
  expect(r.countdown, isFalse);
});
test('app highlight uses the palette primary and auto has no background', () {
  final r = stripRenderStyle(const StripStyle(), ColorPalette.slateDark);
  expect(r.highlightDay, 0xFF1C4558);
  expect(r.highlightNight, 0xFF8DB5CC);
  expect(r.backgroundDay, isNull);
  expect(r.toJson().containsKey('backgroundDay'), isFalse);
  expect(r.toJson()['highlightDay'], '#FF1C4558');
});
test('builder sets nextLabel per cell and nextTag', () {
  final st = PrayerStripStateBuilder.build(prayerTimes: pt, nextPrayer: PrayerName.asr, localeCode: 'ar', isFriday: false, use24Hour: true, nextInLabel: (p) => '$p بعد', nextTag: 'التالية');
  expect(st.cells[2].nextLabel, 'العصر بعد');
  expect(st.nextTag, 'التالية');
  expect(st.toJson()['nextTag'], 'التالية');
  expect((st.toJson()['cells'] as List)[2]['nextLabel'], 'العصر بعد');
});
test('window toJson carries style', () { ... expect(window.toJson()['style'], isA<Map>()); });
```

Update the existing strip tests: drop every `accentColor` expectation, pass the two new builder arguments, and in `alerts_sync_cubit_test.dart` assert the captured `BuildPrayerStripWindowParams.style == stripRenderStyle(settings.stripStyle, settings.palette)` and `nextTag == PendingS.current.strip_next`.

- [ ] **Step 2: Write the failing Kotlin tests** in `T/PrayerStripTest.kt`

```kotlin
@Test fun pickDay_beforeIshaHighlightsTodaysNext() {
    val (day, idx) = PrayerStripController.pickDay(window, "15-11-2026", "16-11-2026", 14 * 60)!!
    assertEquals("15-11-2026", day.dateKey); assertEquals(2, idx)
}
@Test fun pickDay_afterIshaShowsTomorrowWithFajr() {
    val (day, idx) = PrayerStripController.pickDay(window, "15-11-2026", "16-11-2026", 20 * 60)!!
    assertEquals("16-11-2026", day.dateKey); assertEquals(0, idx)
}
@Test fun pickDay_afterIshaWithoutTomorrowHighlightsNothing() {
    val (day, idx) = PrayerStripController.pickDay(windowOf("15-11-2026"), "15-11-2026", "16-11-2026", 20 * 60)!!
    assertEquals("15-11-2026", day.dateKey); assertEquals(-1, idx)
}
@Test fun pickDay_noTodayReturnsNull() { assertNull(PrayerStripController.pickDay(windowOf("10-11-2026"), "15-11-2026", "16-11-2026", 600)) }
@Test fun fromJson_readsStyleAndLabels() {
    val w = PrayerStripWindow.fromJsonString(json)
    assertEquals("pill", w.style.shape); assertEquals(0xFF9A3B3B.toInt(), w.style.highlightDay); assertNull(w.style.backgroundDay)
    assertEquals("العصر بعد", w.days[0].cells[2].nextLabel); assertEquals("التالية", w.days[0].nextTag)
}
@Test fun fromJson_withoutStyleUsesDefaults() {
    val w = PrayerStripWindow.fromJsonString(legacyJson)
    assertEquals(StripStyleNative(), w.style); assertEquals("", w.days[0].nextTag); assertEquals("", w.days[0].cells[0].nextLabel)
}
```

`legacyJson` is a v1 payload as stored today: no `style`, no `nextLabel`/`nextTag`, and a day-level `"accentColor": "#FF2E5244"`, which the parser must ignore. Labels are read with `optString("nextLabel", "")` and `optString("nextTag", "")`.

`windowOf` builds days with cells at `04:52, 11:41, 14:39, 16:58, 18:16` (minutes 292, 701, 879, 1018, 1096). `PrayerStripState.kt` must parse colours with a pure helper (`java.lang.Long.parseLong(hex.removePrefix("#"), 16).toInt()`), not `android.graphics.Color`, so it runs on the JVM.

- [ ] **Step 3: Run to verify they fail**

Run: `fvm flutter test test/features/notifications` and `cd android && ./gradlew :app:testDebugUnitTest`
Expected: failures on the new fields.

- [ ] **Step 4: Implement**

- Dart: add the fields and JSON keys from the Task 3 table; `BuildPrayerStripWindow` forwards `nextInLabel`, `nextTag`, `style`; `AlertsSyncCubit` passes `nextInLabel: PendingS.current.strip_nextIn`, `nextTag: PendingS.current.strip_next`, `style: stripRenderStyle(s.stripStyle, s.palette)` and no `accentColor`.
- `serializeStripArgs`: copy `nextLabel` per cell, `nextTag` per day and the whole `style` map into the stored JSON.
- `PrayerStripController.renderCurrentDay` uses `pickDay` (today key `dd-MM-yyyy`, tomorrow key, minutes now); posts nothing when `pickDay` is `null`; schedules alarms for the shown day as today; it never re-posts on its own after a swipe (the next strip alarm or app open does).
- Layouts: `prayer_strip_collapsed.xml` root `LinearLayout` gets `android:id="@+id/strip_root"`; each cell keeps label over time with `android:includeFontPadding="false"`. `prayer_strip_expanded.xml` becomes a vertical root `strip_root` with a date `TextView` `strip_date` and five rows `row_<i>` (name `cell_<i>_label`, time `cell_<i>_time`, tag `cell_<i>_tag` with `visibility="gone"`).
- Renderer: day/night from `context.resources.configuration.uiMode and UI_MODE_NIGHT_MASK`; highlight background per shape (`strip_time_pill` rounded 8 dp, `strip_cell_pill` 999 dp corners, `strip_cell_outline` 1.5 dp stroke) tinted with `setColorStateList(…, "setBackgroundTintList", …)` on API 31+, flat `setBackgroundColor` below; shape `none` colours the text only; pill text colour from the style; passed cells at 60% text alpha; background tints `strip_root` (API 31+, flat fill below) and switches muted text to `0xA8000000` (≈66% black) on a day fill; the expanded view shows `nextTag` on the next row and the date line `weekdayLabel · hijriDateLabel`; `style.expanded == false` skips `setCustomBigContentView`; `style.countdown` adds `setWhen(nextPrayerMs).setUsesChronometer(true).setChronometerCountDown(true).setShowWhen(true).setSubText(nextCell.nextLabel)`.

- [ ] **Step 5: Run the tests, compile, analyze**

Run: `fvm flutter test test/features/notifications`, `cd android && ./gradlew :app:testDebugUnitTest`, `fvm flutter build apk --debug`, `fvm flutter analyze --no-fatal-infos`
Expected: all pass; APK built; no new issues.

- [ ] **Step 6: Commit**

```bash
git add lib/features/notifications test/features/notifications .claude/rules/theming.md android/app/src/main/kotlin/com/example/quran_app/PrayerStripState.kt android/app/src/main/kotlin/com/example/quran_app/PrayerStripPlugin.kt android/app/src/main/kotlin/com/example/quran_app/PrayerStripController.kt android/app/src/main/kotlin/com/example/quran_app/PrayerStripRenderer.kt android/app/src/main/res/layout/prayer_strip_collapsed.xml android/app/src/main/res/layout/prayer_strip_expanded.xml android/app/src/main/res/drawable/strip_time_pill.xml android/app/src/main/res/drawable/strip_cell_pill.xml android/app/src/main/res/drawable/strip_cell_outline.xml android/app/src/test/kotlin/com/example/quran_app/PrayerStripTest.kt
git commit -m "feat(strip): styled two-line strip with countdown, expanded rows and tomorrow after Isha

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 10: Strip settings page

**Files:**
- Create: `lib/features/notifications/presentation/pages/prayer_strip_settings_page.dart`, `lib/features/notifications/presentation/pages/widgets/strip_preview.dart`
- Modify: `lib/config/router/app_router.dart` (`prayerStripPath = "/prayerStrip"` + `GoRoute`), `lib/features/notifications/presentation/pages/notifications_settings_page.dart` (strip row `onTap`), `lib/features/notifications/presentation/utils/enum_localization.dart` (strip enum labels)
- Test: `test/features/notifications/presentation/pages/prayer_strip_settings_page_test.dart`

**Interfaces:**
- Consumes: `SettingsCubit.updatePrayerStripPinned`, `updateStripStyle`, `StripStyle` (Task 2); `AppSettingsTile`, `showAppOptionSheet`, `TodayPrayerTimesCubit` (Task 8); `stripHighlightSwatch`, `stripBackgroundSwatch`, `PrayerStripStateBuilder` (Task 9); `AppSegmentedSelector`.
- Produces: `AppRouter.prayerStripPath`; `PrayerStripSettingsPage()`; `StripPreview({required PrayerStripState? day, required StripStyle style, required bool expanded, required ColorPalette palette})`; labels `stripHighlightLabel(PendingS, StripHighlight)`, `stripBackgroundLabel(PendingS, StripBackground)`, `stripShapeLabel(PendingS, StripShape)`.

- [ ] **Step 1: Write the failing widget test**

```dart
testWidgets('strip off makes the other rows inert', (tester) async {
  await pumpPage(tester, settings.copyWith(isPrayerStripPinned: false));
  expect(tester.widget<AppSettingsTile>(find.widgetWithText(AppSettingsTile, 'لون التمييز')).enabled, isFalse);
});
testWidgets('expanded off fixes the preview toggle to collapsed', (tester) async {
  await pumpPage(tester, settings.copyWith(isPrayerStripPinned: true, stripStyle: const StripStyle(expanded: false)));
  expect(tester.widget<AppSegmentedSelector<bool>>(find.byType(AppSegmentedSelector<bool>)).selected, isFalse);
});
testWidgets('picking a highlight writes the style', (tester) async {
  await pumpPage(tester, settings.copyWith(isPrayerStripPinned: true));
  await tester.tap(find.text('لون التمييز'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('عنابي'));
  await tester.pumpAndSettle();
  expect(cubit.state.settingsModel.stripStyle.highlight, StripHighlight.maroon);
});
testWidgets('countdown switch shows the digits note', (tester) async { ... expect(find.text('أرقام العدّاد تتبع لغة الهاتف'), findsOneWidget); });
```

`pumpPage` seeds the real `cubit` (a `SettingsCubit`) with the given settings; the file installs storage with `setUpAll(() => HydratedBloc.storage = _MemStorage())` (a local copy of the private class in `settings_cubit_test.dart`) and uses `setUp(() async { await HydratedBloc.storage.clear(); cubit = SettingsCubit(); })` and closes it in `tearDown`.

- [ ] **Step 2: Run to verify it fails**

Run: `fvm flutter test test/features/notifications/presentation/pages/prayer_strip_settings_page_test.dart`
Expected: compile error.

- [ ] **Step 3: Implement**

Page order (spec §8, Appendix C): preview card with `AppSegmentedSelector<bool>` («مطويّ»/«موسّع», local state, forced to collapsed while `expanded` is off); a `SurfaceCard` with three full-row switches (`strip_show` → `updatePrayerStripPinned`, `strip_expanded`, `strip_countdown` with `strip_countdownNote` subtitle); a `SurfaceCard` with highlight, background and shape `AppSettingsTile`s opening `showAppOptionSheet` (colour options get a 16 px swatch dot as `leading`); the `strip_note` line. Everything below the show switch is inert while the strip is off. `StripPreview` draws a system-like frame from today's `TodayPrayerTimesCubit` value through `PrayerStripStateBuilder.build` (skeleton when `null`), using the same swatches and shape as native; no chronometer when countdown is off. The route provides `TodayPrayerTimesCubit` (`..load()`) and uses `GoTransitions.fade.withScale`. The notifications page strip row gets `onTap: () => context.push(AppRouter.prayerStripPath)`.

- [ ] **Step 4: Run, analyze, commit**

Run: `fvm flutter test test/features/notifications` then `fvm flutter analyze --no-fatal-infos`
Expected: PASS; no new issues.

```bash
git add lib/features/notifications/presentation/pages/prayer_strip_settings_page.dart lib/features/notifications/presentation/pages/widgets/strip_preview.dart lib/features/notifications/presentation/pages/notifications_settings_page.dart lib/features/notifications/presentation/utils/enum_localization.dart lib/config/router/app_router.dart test/features/notifications/presentation/pages/prayer_strip_settings_page_test.dart
git commit -m "feat(strip): strip settings page with live preview

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 11: Reliability page, prompts and onboarding

**Files:**
- Create: `lib/features/notifications/domain/services/alerts_prompt_picker.dart`, `lib/features/notifications/presentation/pages/reliability_page.dart`, `lib/features/notifications/presentation/pages/widgets/{xiaomi_checklist,alerts_prompt_gate,upgrade_sheet,missed_sheet}.dart`, `lib/features/onboarding/presentation/pages/widgets/{alerts_step,xiaomi_step}.dart`, `lib/features/onboarding/presentation/utils/apply_alerts_choice.dart`
- Modify: `lib/config/router/app_router.dart` (`alertsReliabilityPath = "/alertsReliability"` + `GoRoute`; onboarding route provides a `ReliabilityCubit`), `lib/features/notifications/presentation/pages/notifications_settings_page.dart` (status line `onTap`), `lib/features/home/presentation/pages/home_page.dart` (wrap `HomeView` in `AlertsPromptGate`), `lib/features/onboarding/presentation/pages/onboarding_page.dart`, `.claude/rules/feature-widgets.md` (record the `AlertsPromptGate` → home and `XiaomiChecklist` → onboarding exception from Global Constraints)
- Test: `test/features/notifications/domain/services/alerts_prompt_picker_test.dart`, `test/features/notifications/presentation/pages/reliability_page_test.dart`, `test/features/notifications/presentation/pages/widgets/alerts_prompt_gate_test.dart`, `test/features/onboarding/alerts_step_test.dart`, `test/features/onboarding/apply_alerts_choice_test.dart`

**Interfaces:**
- Consumes: `ReliabilityCubit` (`load`, `ackMissed(ReliabilityStatus shown)`, `openSettings`), `AppSettingsTile`, `AppStatusBadge`, `TestAdhanButton`, `AlertsStatusLine({onTap})` (Task 8); `SettingsCubit.markAlertsIntroSeen`, `applyAlertToAll`, `setXiaomiAutostartConfirmed`, `setXiaomiBatteryConfirmed`, `clearXiaomiConfirmations`, `completeOnboarding` (Task 2); `ReliabilityStatus`, `SystemSettingsTarget` (Task 3).
- Produces: `enum AlertsPrompt { upgrade, missed, late }`; `({AlertsPrompt prompt, PrayerName? prayer})? pickAlertsPrompt({required bool alertsIntroSeen, required bool onboardingComplete, required ReliabilityStatus status})`; `AppRouter.alertsReliabilityPath`; `ReliabilityPage()`; `XiaomiChecklist({required bool autostartConfirmed, required bool batteryConfirmed})`; `AlertsPromptGate({required Widget child})`; `UpgradeSheet.show(BuildContext, {required bool isXiaomi})`; `MissedSheet.show(BuildContext, {required AlertsPrompt kind, required PrayerName prayer, required bool isXiaomi})`; `AlertsStep({required ValueChanged<AlertsChoice> onChanged})` with `class AlertsChoice extends Equatable { const AlertsChoice({this.sound, this.reminderMinutes}); final PrayerSound? sound; final int? reminderMinutes; }` (`props` = both fields) (`sound == null` = «بدون تنبيه», `reminderMinutes == null` = none); `void applyAlertsChoice(SettingsCubit cubit, AlertsChoice choice)` (pure mapping onto `applyAlertToAll`); `XiaomiStep()`.

- [ ] **Step 1: Write the failing picker tests**

```dart
final none = ReliabilityStatus.ios(notificationsEnabled: true);
final miss = MissedAlert(prayer: PrayerName.isha, at: DateTime(2026, 11, 14, 18, 16));
final late = MissedAlert(prayer: PrayerName.asr, at: DateTime(2026, 11, 15, 14, 39));
test('upgrade first when intro unseen and onboarding complete', () {
  expect(pickAlertsPrompt(alertsIntroSeen: false, onboardingComplete: true, status: none.copyWith(missed: [miss]))?.prompt, AlertsPrompt.upgrade);
});
test('no upgrade before onboarding completes', () {
  expect(pickAlertsPrompt(alertsIntroSeen: false, onboardingComplete: false, status: none), isNull);
});
test('missed beats late and names the most recent miss', () {
  final r = pickAlertsPrompt(alertsIntroSeen: true, onboardingComplete: true, status: none.copyWith(missed: [miss], late: [late]));
  expect(r, (prompt: AlertsPrompt.missed, prayer: PrayerName.isha));
});
test('late only', () {
  expect(pickAlertsPrompt(alertsIntroSeen: true, onboardingComplete: true, status: none.copyWith(late: [late])), (prompt: AlertsPrompt.late, prayer: PrayerName.asr));
});
test('nothing to show', () => expect(pickAlertsPrompt(alertsIntroSeen: true, onboardingComplete: true, status: none), isNull));
```

The lists arrive newest first from native; the picker still takes the entry with the latest `at`.

```dart
group('applyAlertsChoice', () {
  late SettingsCubit cubit;
  setUpAll(() => HydratedBloc.storage = _MemStorage());
  setUp(() async { await HydratedBloc.storage.clear(); cubit = SettingsCubit(); });
  tearDown(() => cubit.close());
  test('tone with 15 minutes', () {
    applyAlertsChoice(cubit, const AlertsChoice(sound: PrayerSound.tone, reminderMinutes: 15));
    final a = cubit.state.settingsModel.prayerAlerts[PrayerName.asr]!;
    expect((a.enabled, a.sound, a.reminderEnabled, a.reminderMinutes), (true, PrayerSound.tone, true, 15));
  });
  test('no reminder turns reminders off', () {
    applyAlertsChoice(cubit, const AlertsChoice(sound: PrayerSound.adhan, reminderMinutes: null));
    expect(cubit.state.settingsModel.prayerAlerts.values.every((a) => a.enabled && !a.reminderEnabled), isTrue);
  });
  test('no alert disables every prayer', () {
    applyAlertsChoice(cubit, const AlertsChoice(sound: null, reminderMinutes: 10));
    expect(cubit.state.settingsModel.prayerAlerts.values.every((a) => !a.enabled), isTrue);
  });
});
```

- [ ] **Step 2: Write the failing widget tests**

Widget tests that use a real `SettingsCubit` install storage with `setUpAll(() => HydratedBloc.storage = _MemStorage())` (a local copy of the private `_MemStorage` in `settings_cubit_test.dart`) and share one cubit per file through `setUp(() async { await HydratedBloc.storage.clear(); settingsCubit = SettingsCubit(); })`.

- `alerts_prompt_gate_test.dart`: with `alertsIntroSeen: true` and a loaded status holding one Isha miss on Xiaomi, the gate shows one sheet with «فاتك تنبيه العشاء» and `missed_body`, calls `ackMissed` once with the status it showed, and both Xiaomi flags read `false` afterwards; on a non-Xiaomi status the body is `missed_bodyGeneric` and the flags are untouched; with `alertsIntroSeen: false` it shows `upg_title`, sets `alertsIntroSeen`, and shows no missed sheet in the same session; a second rebuild shows nothing more.
- `reliability_page_test.dart`: a blocked notifications row shows `rel_needsAction`, `rel_blocked` and «فتح الإعداد», and tapping it calls `openSettings(SystemSettingsTarget.notifications)`; `channelBlocked` alone also reads blocked; Xiaomi rows show the «تمّ» button until confirmed, then the `rel_done` badge while «فتح الإعداد» stays (both read «تمّ», so assert with `find.widgetWithText(TextButton, 'تمّ')` and `find.widgetWithText(AppStatusBadge, 'تمّ')`, never a bare `find.text`); confirming calls `load()` on the cubit; non-Xiaomi hides the Xiaomi section; iOS (`debugDefaultTargetPlatformOverride`) shows only the notifications row and the test button; `scheduledUntil == null` shows `rel_scheduledNone`.
- `alerts_step_test.dart` (the step alone, no cubit): picking «بدون تنبيه» makes the reminder chips inert (`onSelected` null); picking tone then chip 15 makes the last `onChanged` payload `AlertsChoice(sound: PrayerSound.tone, reminderMinutes: 15)`. The cubit mapping is covered by `apply_alerts_choice_test.dart`.

- [ ] **Step 3: Run to verify they fail**

Run: `fvm flutter test test/features/notifications test/features/onboarding`
Expected: compile errors.

- [ ] **Step 4: Implement**

- `ReliabilityPage` (route provides `ReliabilityCubit`): rows for notifications (blocked when `!notificationsEnabled || channelBlocked`, target `notifications`), exact alarms (`exactAlarm`), battery (`rel_batteryRestricted`/`rel_batteryUnrestricted`, hint `rel_batteryHint`, target `battery`); each row an `AppSettingsTile` with an `AppStatusBadge` (`rel_working` with `color: context.colorScheme.primary`, `rel_needsAction` with `color: context.colorScheme.onSurfaceVariant`; never `error`, per Appendix C) and an action only when blocked. Xiaomi section (`rel_xiaomiSection`, `rel_unverifiable`) holds `XiaomiChecklist`. Then «مجدولة حتى …» (`rel_scheduledUntil(date)` or `rel_scheduledNone`, subtitle `rel_scheduledSub`) and `TestAdhanButton`. On iOS only the notifications row and the test button render.
- `XiaomiChecklist`: autostart (`rel_autostart`/`rel_autostartSub`, target `autostart`) and battery saver (`rel_xiaomiBattery`/`rel_xiaomiBatterySub`, target `xiaomiBattery`), each with «فتح الإعداد» and a «تمّ» `TextButton` (calls the matching `setXiaomi…Confirmed(true)` then `context.read<ReliabilityCubit>().load()` unconditionally: both hosts, the reliability route and the onboarding route, provide the cubit); a confirmed row replaces the button with an `AppStatusBadge(label: rel_done, color: context.colorScheme.primary)`; third row `rel_lockApp`/`rel_lockAppSub` is text only.
- `AlertsPromptGate`: provides `BlocProvider(create: (_) => sl<ReliabilityCubit>())`; a `BlocListener` with `listenWhen: (p, c) => p is ReliabilityLoading && c is! ReliabilityLoading` shows at most one sheet per gate lifetime (guard with a `bool` in the gate's `State`), using `pickAlertsPrompt`. Upgrade: `markAlertsIntroSeen()` when shown. Missed/late: `ackMissed(status)` with the status the sheet was built from, when shown, and on Xiaomi `clearXiaomiConfirmations()`.
- `UpgradeSheet`: `upg_title`, `upg_silent`, `upg_reminder`, `upg_xiaomi` (Xiaomi only); «مراجعة الإعدادات» pushes `notificationsPath` and, on Xiaomi, then `alertsReliabilityPath` on top; «لاحقًا» (`onb_later`) closes.
- `MissedSheet`: title `missed_title(prayerLabel)` or `late_title(prayerLabel)`; body `missed_body` (Xiaomi) or `missed_bodyGeneric`; «إصلاح الآن» (`missed_fix`) pushes `alertsReliabilityPath`; «لاحقًا» closes.
- `HomePage`: `child: _StripResumeGuard(child: AlertsPromptGate(child: HomeView()))`.
- `feature-widgets.md`: under the "Don't import a feature widget into another feature" bullet add "Exception: `notifications` exports `AlertsPromptGate` (used by `home`) and `XiaomiChecklist` (used by `onboarding`)."
- Notifications page: `AlertsStatusLine(onTap: () => context.push(AppRouter.alertsReliabilityPath))`.
- `applyAlertsChoice`: `sound == null` → `applyAlertToAll(enabled: false)`; otherwise `applyAlertToAll(enabled: true, sound: choice.sound, reminderEnabled: choice.reminderMinutes != null, reminderMinutes: choice.reminderMinutes)` (minutes omitted when null, so the stored value stays).
- Onboarding: steps become welcome, language, appearance, location, notifications, alerts, and on Xiaomi (from the route's `ReliabilityCubit` once loaded) the Xiaomi step. `_stepCount` becomes a getter (6, or 7 on Xiaomi), with new constants `_alertsStep = 5`, `_xiaomiStep = 6` and `int get _lastStep => _stepCount - 1`. `_OnboardingPageState` holds `AlertsChoice? _alertsChoice`, set from `AlertsStep(onChanged: (c) => setState(() => _alertsChoice = c))`. On the notifications step both buttons now advance to the alerts step: the primary requests permission then `_goTo(_alertsStep)`, and the secondary («ليس الآن», today `_finish()`) also calls `_goTo(_alertsStep)`. `isPermissionStep` still covers only location and notifications, so the alerts and Xiaomi steps show `onb_continue` as the primary label. The secondary button's `if (isPermissionStep)` becomes `if (_index >= _locationStep)` with label `onb_not_now` on location and notifications, `onb_later` on alerts and `onb_skip` on Xiaomi; its handler is `_index == _lastStep ? _finish() : _goTo(_index + 1)` (location → notifications → alerts → Xiaomi), with no apply on alerts. The alerts step's primary calls `applyAlertsChoice(context.read<SettingsCubit>(), _alertsChoice!)` when non-null, then advances (or finishes when it is the last step); its secondary «لاحقًا» (`onb_later`) advances without applying; the Xiaomi step reuses `XiaomiChecklist` under `onb_xiaomi_title`/`onb_xiaomi_lead` with «تخطٍّ» (`onb_skip`); the last step calls `_finish()`, whose `completeOnboarding()` also sets `alertsIntroSeen` (Task 2). `_ProgressDots` takes the dynamic count.

- [ ] **Step 5: Run, analyze, commit**

Run: `fvm flutter test test/features/notifications test/features/onboarding test/features/home` then `fvm flutter analyze --no-fatal-infos`
Expected: PASS; no new issues.

```bash
git add lib/features/notifications lib/features/onboarding lib/features/home/presentation/pages/home_page.dart lib/config/router/app_router.dart .claude/rules/feature-widgets.md test/features/notifications test/features/onboarding
git commit -m "feat(alerts): reliability page, upgrade and missed sheets, onboarding alert steps

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 12: iOS

**Files:**
- Create: `lib/core/notifications/ios_alert_plan.dart`, `lib/features/notifications/data/datasources/notifications_local_data_source.dart`, `test/core/notifications/ios_alert_plan_test.dart`
- Modify: `lib/core/notifications/prayer_notification_scheduler.dart`, `lib/core/notifications/prayer_notification_scheduler_impl.dart`, `lib/features/notifications/data/repositories/notifications_repository_impl.dart`, `lib/features/notifications/notifications_di.dart`, `ios/Runner/fajr_adhan.caf`, `ios/Runner/normal_adhan.caf` (replaced), `ios/Runner.xcodeproj/project.pbxproj`
- Test: `test/features/notifications/data/repositories/notifications_repository_impl_test.dart` (iOS cases), `test/features/home/presentation/pages/widgets/notification_hint_test.dart` (its `_FakeScheduler implements PrayerNotificationScheduler` must follow the interface)

**Interfaces:**
- Consumes: `PrayerAlert`, `alertPrayers` (Task 2); `ReliabilityStatus.ios` (Task 3).
- Produces:
  - `int iosDayCount(int requestsPerDay)` = `requestsPerDay <= 0 ? 0 : min(12, 60 ~/ requestsPerDay)`.
  - `enum IosSound { fajrClip, normalClip, defaultSound, none }`; `class IosAlertRequest extends Equatable { final int id; final DateTime at; final String title; final String body; final IosSound sound; }`; `List<IosAlertRequest> planIosAlerts({required List<PrayerTimes> days, required Map<PrayerName, PrayerAlert> alerts, required String localeCode, required DateTime now})`.
  - `PrayerNotificationScheduler.scheduleAlerts({required List<PrayerTimes> days, required Map<PrayerName, PrayerAlert> alerts, required String localeCode}) → Future<DateTime?>` (last scheduled adhan); `cancelAll()` clears ids 0–119, 200–319, 10–15 and 20–25. Removed from the interface: `scheduleDailyPrayerNotifications`, `cancelAllPrayerNotifications`, `scheduleStaticReminder`, `cancelAllStaticReminders`.
  - `NotificationsLocalDataSource` (`DateTime? readIosScheduledUntil()`, `Future<void> writeIosScheduledUntil(DateTime? value)`) backed by the open Hive box `prayerConfig`, key `iosScheduledUntil` (epoch ms); lazy singleton.

- [ ] **Step 1: Write the failing planner tests**

```dart
test('iosDayCount follows floor(60 / requests), capped at 12', () {
  expect(iosDayCount(10), 6);
  expect(iosDayCount(6), 10);
  expect(iosDayCount(5), 12);
  expect(iosDayCount(1), 12);
  expect(iosDayCount(0), 0);
});
test('ids, sounds and day limit with all alerts and reminders on', () {
  final alerts = {for (final p in alertPrayers) p: const PrayerAlert(reminderEnabled: true, reminderMinutes: 10)};
  final reqs = planIosAlerts(days: eightDays, alerts: alerts, localeCode: 'ar', now: DateTime(2026, 11, 15));
  expect(reqs.where((r) => r.id < 200).map((r) => r.id).reduce(max), 54);
  expect(reqs.firstWhere((r) => r.id == 0).sound, IosSound.fajrClip);
  expect(reqs.firstWhere((r) => r.id == 1).sound, IosSound.normalClip);
  expect(reqs.firstWhere((r) => r.id == 200).at, DateTime(2026, 11, 15, 4, 42));
  expect(reqs.length, 60);
  expect(reqs.firstWhere((r) => r.id == 0).title, 'الفجر');
});
test('tone uses the default sound, vibrate and silent use none, disabled is skipped', () {
  final reqs = planIosAlerts(days: eightDays.take(1).toList(), alerts: {
    PrayerName.fajr: const PrayerAlert(sound: PrayerSound.tone),
    PrayerName.dhuhr: const PrayerAlert(sound: PrayerSound.vibrate, reminderEnabled: true, reminderSound: ReminderSound.vibrate),
    PrayerName.asr: const PrayerAlert(enabled: false, reminderEnabled: true),
  }, localeCode: 'en', now: DateTime(2026, 11, 15));
  expect(reqs.firstWhere((r) => r.id == 0).sound, IosSound.defaultSound);
  expect(reqs.firstWhere((r) => r.id == 1).sound, IosSound.none);
  expect(reqs.firstWhere((r) => r.id == 201).sound, IosSound.none);
  expect(reqs.any((r) => r.id == 2 || r.id == 202), isFalse);
});
test('past triggers are skipped and no alerts schedules nothing', () { ... now = DateTime(2026, 11, 15, 12) → no id 0 or 1; alerts all disabled → isEmpty });
```

`eightDays` are eight `PrayerTimes` from 15-11-2026 with the timings used in Task 4. Day index counts the scheduled days (0..dayCount−1); prayer index is the position in `alertPrayers`. Titles and bodies: adhan title = prayer name, body = Android's `adhan_body_<prayer>` copy («حان موعد صلاة الفجر» / "It's time for Fajr prayer"); reminder title = `reminder_title_<prayer>` copy («تذكير الفجر» / "Fajr reminder"), body = `reminder_body_<prayer>` copy («اقتربت صلاة الفجر» / "Fajr prayer is coming up"), held as const maps in `ios_alert_plan.dart` (spec Appendix A has no iOS keys, so the iOS text mirrors the shipped Android strings).

- [ ] **Step 2: Write the failing repository tests (iOS)**

```dart
test('iOS: scheduleDailyAdhans calls scheduleAlerts and stores scheduledUntil', () async {
  when(() => scheduler.scheduleAlerts(days: any(named: 'days'), alerts: any(named: 'alerts'), localeCode: 'ar')).thenAnswer((_) async => DateTime(2026, 11, 20, 18, 16));
  await repo.scheduleDailyAdhans(days: [pt], alerts: Settings.defaultPrayerAlerts, localeCode: 'ar');
  verify(() => local.writeIosScheduledUntil(DateTime(2026, 11, 20, 18, 16))).called(1);
});
test('iOS: schedulePrayerReminders is a no-op (scheduleAlerts covers reminders)', () async { ... verifyNever(() => scheduler.scheduleAlerts(...)); });
test('iOS: getReliabilityStatus reports the stored scheduledUntil', () async { ... expect(r, Right(ReliabilityStatus.ios(notificationsEnabled: true, scheduledUntil: DateTime(2026, 11, 20, 18, 16)))); });
```

- [ ] **Step 3: Run to verify they fail**

Run: `fvm flutter test test/core/notifications test/features/notifications/data`
Expected: compile errors.

- [ ] **Step 4: Implement**

- `scheduleAlerts`: `await cancelAll()`, then `zonedSchedule` each `planIosAlerts` request with `DarwinNotificationDetails(presentAlert: true, presentBadge: false, presentSound: sound != IosSound.none, sound: 'fajr_adhan.caf' | 'normal_adhan.caf' | null)`; return the latest adhan `at` (or `null`). Delete the single-day path, the static-reminder methods, `_notificationIds`, `_reminderIds`, `_prayerTitles`, `_fajrDetails`, `_standardDetails` and `_reminderDetails`; the test notification (id 9999) keeps working with `presentSound` and `normal_adhan.caf`.
- `notification_hint_test.dart` `_FakeScheduler`: delete the overrides of `scheduleDailyPrayerNotifications`, `cancelAllPrayerNotifications`, `scheduleStaticReminder` and `cancelAllStaticReminders`, and add `@override Future<DateTime?> scheduleAlerts({required List<PrayerTimes> days, required Map<PrayerName, PrayerAlert> alerts, required String localeCode}) async => null;` and `@override Future<void> cancelAll() async {}`.
- Repository iOS branch: `scheduleDailyAdhans` → `final until = await legacyScheduler.scheduleAlerts(...)` then `await local.writeIosScheduledUntil(until)`; `cancelAllAdhans` → `legacyScheduler.cancelAll()`; reminder calls are no-ops; `getReliabilityStatus` adds `scheduledUntil: local.readIosScheduledUntil()`. Add `local` to the constructor and DI.
- Clips: `cp docs/design-audit/prayer/_docs/caf/fajr_adhan.caf ios/Runner/fajr_adhan.caf` and `cp docs/design-audit/prayer/_docs/caf/normal_adhan.caf ios/Runner/normal_adhan.caf` (29.0 s, mono, IMA4, already trimmed per spec §9; the source folder is local and never committed). Check both: `afinfo ios/Runner/fajr_adhan.caf | grep duration` reports ≤ 29.1 s, and `shasum ios/Runner/*.caf` gives `2cb253e3…` (fajr) and `10cdd11c…` (normal), not the old `21e372f8…` / `762ef43a…`.
- Fallback when that folder is missing (no ffmpeg on this machine; `S` is the scratchpad), per clip, from the Android raw source:
  `afconvert -f WAVE -d LEI16@22050 -c 1 android/app/src/main/res/raw/fajr_adhan.mp3 S/fajr.wav && python3 -c "import wave;i=wave.open('S/fajr.wav');o=wave.open('S/fajr29.wav','wb');o.setparams(i.getparams());o.writeframes(i.readframes(29*i.getframerate()))"`
  `afconvert -f caff -d ima4 S/fajr29.wav ios/Runner/fajr_adhan.caf` (repeat with `normal_adhan`), then rerun the `afinfo` check.
- `project.pbxproj` (the `.caf` files are not referenced today): for each file add a `PBXFileReference` (`lastKnownFileType = file; path = fajr_adhan.caf; sourceTree = "<group>";`), a child entry in the `Runner` group, a `PBXBuildFile` (`… in Resources`), and an entry in the Runner target's Resources phase `97C146EC1CF9000F007C117D`. Use fresh 24-hex-digit ids that do not already occur in the file.

- [ ] **Step 5: Verify**

Run: `fvm flutter test test/core/notifications test/features/notifications test/features/home`, `plutil -lint ios/Runner.xcodeproj/project.pbxproj`, `fvm flutter build ios --no-codesign --debug`, then `ls build/ios/iphoneos/Runner.app/*.caf`
Expected: tests pass; `OK`; build succeeds; both `fajr_adhan.caf` and `normal_adhan.caf` listed.

- [ ] **Step 6: Analyze and commit**

Run: `fvm flutter analyze --no-fatal-infos` (no new issues).

```bash
git add lib/core/notifications/ios_alert_plan.dart lib/core/notifications/prayer_notification_scheduler.dart lib/core/notifications/prayer_notification_scheduler_impl.dart lib/features/notifications/data/datasources/notifications_local_data_source.dart lib/features/notifications/data/repositories/notifications_repository_impl.dart lib/features/notifications/notifications_di.dart test/core/notifications/ios_alert_plan_test.dart test/features/notifications/data/repositories/notifications_repository_impl_test.dart test/features/home/presentation/pages/widgets/notification_hint_test.dart ios/Runner/fajr_adhan.caf ios/Runner/normal_adhan.caf ios/Runner.xcodeproj/project.pbxproj
git commit -m "feat(ios): per-prayer alerts and reminders with bundled 29 s adhan clips

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 13: Comfort theme values (last commit)

This commit changes the palette and getter values and adds the dark `switchTheme` (spec L341); nothing else depends on it, so reverting it alone keeps the build green. The contrast check was run while writing this plan: every proposed value passes (lowest: neutralLight `onSurfaceVar` on `surface` 5.29:1; `primaryInk` on `surface` ≥ 6.53:1), so the slate palettes take the proposed Appendix B values too.

**Files:**
- Modify: `lib/config/theme/app_palette.dart`
- Test: `test/config/theme/app_palette_contrast_test.dart` (new), `test/config/theme/app_palette_test.dart` (the `bg colors` group expects the new hex values)

**Interfaces:**
- Consumes: the Task 8 getters `onPrimary`, `primaryInk`, `primaryTint`, `error`, `onError`.
- Produces: Appendix B values; `toThemeData()` gains `switchTheme` (dark palettes: selected track `primaryInk`, selected thumb `bg`; light: selected track `primary`, selected thumb `onPrimary`).

- [ ] **Step 1: Write the failing tests**

```dart
double contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (max(la, lb) + 0.05) / (min(la, lb) + 0.05);
}
for (final p in ColorPalette.values) {
  test('$p text contrast', () {
    expect(contrast(p.onSurface, p.bg), greaterThanOrEqualTo(4.5));
    expect(contrast(p.onSurface, p.surface), greaterThanOrEqualTo(4.5));
    expect(contrast(p.onSurfaceVar, p.bg), greaterThanOrEqualTo(4.5));
    expect(contrast(p.onSurfaceVar, p.surface), greaterThanOrEqualTo(4.5));
    expect(contrast(p.primaryInk, p.surface), greaterThanOrEqualTo(3));
  });
}
test('Appendix B values', () {
  expect(ColorPalette.neutralDark.bg, const Color(0xFF121413));
  expect(ColorPalette.neutralLight.surface, const Color(0xFFDCE0DA));
  expect(ColorPalette.slateDark.primaryInk, const Color(0xFF8DB5CC));
  expect(ColorPalette.neutralDark.primaryTint, const Color(0xFF5C8070).withValues(alpha: 0.24));
  expect(ColorPalette.slateLight.error, const Color(0xFFA33A35));
  expect(ColorPalette.slateDark.onError, const Color(0xFF121418));
});
test('dark switch uses primaryInk track and bg thumb', () {
  final t = ColorPalette.neutralDark.toThemeData().switchTheme;
  expect(t.trackColor!.resolve({WidgetState.selected}), const Color(0xFF93BAA8));
  expect(t.thumbColor!.resolve({WidgetState.selected}), const Color(0xFF121413));
});
```

- [ ] **Step 2: Run to verify they fail**

Run: `fvm flutter test test/config`
Expected: value and switch-theme failures (contrast may already pass for some palettes).

- [ ] **Step 3: Implement**

Set `bg`, `surface`, `onSurface`, `onSurfaceVar` for all four palettes and `onPrimary`, `primaryInk`, `primaryTint` (`primary @ 10%` light; `secondary @ 24%` dark), `error`, `onError` from Appendix B; `primary` and `secondary` stay. Add the `switchTheme` with `WidgetStateProperty.resolveWith`. `AppColors.error` has no caller in the files this feature touches other than `app_palette.dart`, which now uses the `error` getter; leave `AppColors.error` itself.

- [ ] **Step 4: Run the full suite and checks**

Run: `fvm flutter analyze --no-fatal-infos`, `fvm flutter test test/features test/core test/config test/quran_package`, then `git status assets/`
Expected: no new analyzer issues; all tests pass; `assets/` clean.

- [ ] **Step 5: Commit**

```bash
git add lib/config/theme/app_palette.dart test/config/theme/app_palette_contrast_test.dart test/config/theme/app_palette_test.dart
git commit -m "feat(theme): comfort palette values and dark switch track

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

