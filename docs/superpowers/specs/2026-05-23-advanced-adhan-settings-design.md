# Advanced Adhan Notification Settings — Design

**Date:** 2026-05-23
**Branch:** `feature/004-pinned-prayer-notification` (or successor)
**Scope:** Promote the current `NotificationsSettingsPage` from a single pinned-strip toggle into a full adhan-control hub: per-prayer adhan on/off, per-prayer pre-prayer reminders (0–15 min) with an Android live countdown, and a "Play test adhan" entry point.

## Companion documents

- Prior adhan + strip design: `docs/superpowers/specs/2026-05-23-notifications-fixes-design.md`
- Prior adhan audio design: `docs/superpowers/specs/2026-05-14-adhan-audio-notifications-design.md`
- Prior pinned-strip design: `docs/superpowers/specs/2026-05-23-pinned-prayer-notification-design.md`

The implementation plan that follows this spec will be written by `superpowers:writing-plans` and stored alongside the existing plan files in `docs/superpowers/plans/`.

---

## 1. Background

After the 2026-05-23 notifications-fixes work, Android adhan delivery is healthy: per-prayer alarms fire via `AdhanScheduler`, `AdhanPlaybackService` plays the audio on `USAGE_ALARM`, and the pinned strip is independent. The user-facing settings UI, however, has not kept pace — `NotificationsSettingsPage` exposes only the pinned-strip toggle. There is no way to silence Fajr if the user wakes naturally, no way to ask for a five-minute warning before Maghrib, and no production-visible button to test the adhan (the existing test FAB is a debug surface on `home_view`).

The 2026-05-23 spec explicitly deferred per-prayer voice selection and an in-app volume slider (§3 non-goals). This design picks up the two deferrals that **don't** depend on bundling more audio assets — per-prayer enablement and pre-prayer reminders — and adds them through the existing native channel infrastructure.

## 2. Goals

1. Expose **per-prayer adhan on/off** as five switches on `NotificationsSettingsPage` (Fajr, Dhuhr, Asr, Maghrib, Isha).
2. Expose a **pre-prayer reminder offset per prayer** in 5-minute steps from 0 (Off) to 15.
3. The reminder posts an **Android live-countdown notification** powered by `NotificationCompat.setChronometerCountDown(true)` — the system renders `15:00 → 14:59 → …` with no polling on the app side.
4. Settings are persisted via the existing `HydratedCubit` flow and re-sync the native scheduler immediately when any value changes.
5. Promote the debug "Test adhan 30s" FAB into a production "Play test adhan" button on the settings page.
6. The page stays flat — one screen, no sub-pages, consistent with the existing flat list pattern.

## 3. Non-goals

- **Per-prayer voice/clip selection.** Only two clips are bundled (`fajr_adhan.mp3`, `normal_adhan.mp3`); voice selection requires content work before a UI is worthwhile.
- **In-app volume slider.** The 2026-05-23 spec's reasoning still stands: `USAGE_ALARM` rides the OS alarm volume; a second slider is confusing and risks missed prayers.
- **iOS live countdown.** iOS notifications cannot mutate after delivery. iOS gets a single static notification at T-N ("Dhuhr in 10 minutes"). Documented as a platform gap, not a regression.
- **Per-prayer vibrate-only or silent modes.** Out of scope; the toggle is binary.
- **Sunrise reminder/adhan.** Sunrise is not a prayer in this app's model.
- **Boot recovery for reminders.** Mirrors the adhan policy (§6.4 of the prior spec): re-arms on next app open.
- **Feature flag.** This is additive UI plus opt-in alarms; rollback = revert.

## 4. Architecture

```
┌────────────────────────────────────────────────────────────────┐
│  Dart                                                           │
│                                                                 │
│  NotificationsSettingsPage                                      │
│    ├── PinnedStripToggle (existing)                             │
│    ├── PerPrayerAdhanTile × 5  (NEW)                            │
│    │     ├── Adhan switch                                       │
│    │     └── ReminderOffsetDropdown                             │
│    └── TestAdhanButton (NEW; replaces debug FAB)                │
│                                                                 │
│  SettingsCubit (HydratedCubit, existing)                        │
│    ├── updateAdhanEnabled(PrayerName, bool)                     │
│    └── updateReminderMinutes(PrayerName, int 0..15 step 5)      │
│                                                                 │
│  HomePage listener — re-runs SyncDailyAdhans on settings change │
│                                                                 │
│  SyncDailyAdhans(prayerTimes, settings)                         │
│    │                                                            │
│    └── NotificationsRepositoryImpl.scheduleDailyAdhans          │
│            │                                                    │
│            ├── Android: native.cancelAllAdhans                  │
│            │           native.cancelAllReminders   (NEW)        │
│            │           native.scheduleDailyAdhans                │
│            │           native.schedulePrayerReminders (NEW)     │
│            │                                                    │
│            └── iOS: legacy.scheduleDailyPrayerNotifications     │
│                     legacy.scheduleStaticReminders (NEW)        │
└────────────────────────────────────────────────────────────────┘
                              │ MethodChannel: quran_app/notifications
                              ▼
┌────────────────────────────────────────────────────────────────┐
│  Android native                                                 │
│                                                                 │
│  PrayerStripPlugin                                              │
│    ├── existing methods …                                       │
│    └── schedulePrayerReminders / cancelAllReminders (NEW)       │
│                                                                 │
│  PrayerReminderScheduler.kt (NEW)                               │
│  PrayerReminderReceiver.kt  (NEW)                               │
│  prayer_reminder_channel (NEW notification channel)             │
│                                                                 │
│  AdhanAlarmReceiver        — modified to cancel matching        │
│                              reminder notification at T-0       │
└────────────────────────────────────────────────────────────────┘
```

Key invariants:

- **Reminders are not a foreground service.** The Android chronometer countdown is rendered by the system. We post one notification per reminder; the system updates the displayed countdown automatically.
- **Disabled prayers vanish from both alarm chains** (adhan + reminder). Filtering happens in `SyncDailyAdhans` before the platform branch.
- **Adhan firing dismisses the corresponding reminder.** Otherwise a stale `00:00:00` countdown sits next to the live adhan UI.

## 5. Data model — extend `Settings`

Two new fields on the existing `Settings` entity, keyed by `PrayerName`:

```dart
// lib/features/settings/domain/entities/settings.dart
class Settings extends Equatable {
  // existing fields …
  final Map<PrayerName, bool> adhanEnabledByPrayer;
  final Map<PrayerName, int>  reminderMinutesByPrayer; // 0 = off, valid: {0, 5, 10, 15}

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
}
```

**Rationale (entity choice):** `SettingsCubit` is already the `HydratedCubit` source of truth, and HomePage already listens to it for `isPrayerStripPinned`. A new entity would duplicate plumbing without a corresponding boundary. The existing `AdhanAudioSettings` is *audio* configuration (which clip plays); these maps are *scheduling* configuration (which prayers fire and when to warn). Keeping them in `Settings` matches the existing flat-prefs pattern.

**Persistence:** `SettingsModel.toMap` writes both maps as `Map<String, dynamic>` keyed by `PrayerName.name`. `SettingsModel.fromMap` reads them with the static defaults as fallback so existing hydrated users hydrate cleanly without a migration shim.

```dart
factory SettingsModel.fromMap(Map<String, dynamic> map) {
  return SettingsModel(
    // existing fields …
    adhanEnabledByPrayer: _readEnabledMap(map['adhanEnabledByPrayer']),
    reminderMinutesByPrayer: _readReminderMap(map['reminderMinutesByPrayer']),
  );
}
```

**Cubit additions:**

- `updateAdhanEnabled(PrayerName prayer, bool value)`
- `updateReminderMinutes(PrayerName prayer, int minutes)` — asserts `minutes ∈ {0, 5, 10, 15}`.

## 6. UI — `NotificationsSettingsPage`

### 6.1 Layout

The page becomes three vertically stacked groups:

1. **Pinned prayer times** — existing `SettingSwitch`, unchanged.
2. **Adhan per prayer** — section header `S.current.adhanPerPrayerSection`, then five `PerPrayerAdhanTile` rows inside a single `surfaceContainer` card with dividers between them.
3. **Play test adhan** — `TestAdhanButton`.

```
┌─ Notifications ─────────────────────────────────────────────┐
│ [icon] Manage your prayer-time notifications                 │
│                                                              │
│ [ Pinned prayer times                          [ON] ]        │
│                                                              │
│ ADHAN PER PRAYER                                             │
│ ┌──────────────────────────────────────────────────────────┐ │
│ │  Fajr                                          [ON]      │ │
│ │  Remind me  ─  15 min before  ▾                          │ │
│ │ ────────────────────────────────────────────────────────  │ │
│ │  Dhuhr                                         [ON]      │ │
│ │  Remind me  ─  Off            ▾                          │ │
│ │ ────────────────────────────────────────────────────────  │ │
│ │  Asr / Maghrib / Isha …                                  │ │
│ └──────────────────────────────────────────────────────────┘ │
│                                                              │
│ [  ▶  Play test adhan  ]                                     │
└──────────────────────────────────────────────────────────────┘
```

### 6.2 New widgets

| Widget | Location | Responsibility |
|---|---|---|
| `PerPrayerAdhanTile` | `features/home/presentation/pages/widgets/per_prayer_adhan_tile.dart` | One row per prayer. Prayer icon + localized label + adhan switch + reminder dropdown. Switch off ⇒ dropdown disabled (greyed) and treated as "Off" regardless of stored value. |
| `ReminderOffsetDropdown` | `features/home/presentation/pages/widgets/reminder_offset_dropdown.dart` | `DropdownButton<int>` with values `[0, 5, 10, 15]`. Localized labels: `reminderOff`, `reminderMinutesBefore(5)`, etc. |
| `TestAdhanButton` | `features/home/presentation/pages/widgets/test_adhan_button.dart` | Calls native `scheduleTestAdhan(+5s)` on Android, legacy scheduler on iOS. Snackbar feedback: "Test adhan in 5 seconds". Always visible (no debug flag). |

### 6.3 Styling

Reuses the existing tokens: `surfaceContainer` background with 14dp radius for cards, Cairo typography via `TS.bold20.cairo` and `TS.regular14.cairo`. Prayer icons reuse the same set used by the strip (HugeIcons or the inline iconography already declared for the strip).

### 6.4 Localization

New ARB keys (in `intl_en.arb` and `intl_ar.arb`):

```
adhanPerPrayerSection         "Adhan per prayer"          / "الأذان لكل صلاة"
reminderLabel                 "Remind me"                  / "ذكرني"
reminderOff                   "Off"                        / "لا"
reminderMinutesBefore({minutes}) "{minutes} min before"    / "قبل {minutes} د"
playTestAdhan                 "Play test adhan"            / "تشغيل أذان تجريبي"
testAdhanScheduledSnack       "Test adhan in 5 seconds"   / "أذان تجريبي خلال ٥ ثوانٍ"
reminderNotificationTitle({prayer}) "{prayer} reminder"   / "تذكير {prayer}"
reminderNotificationBody({prayer})  "{prayer} prayer is coming up" / "اقتربت صلاة {prayer}"
```

## 7. Android — reminder mechanics

### 7.1 New native components

```
android/app/src/main/kotlin/com/example/quran_app/
├── PrayerReminderScheduler.kt   — pure helper, arms/cancels AlarmManager intents
└── PrayerReminderReceiver.kt    — fires at T-N, posts the countdown notification
```

| Class | Purpose |
|---|---|
| `PrayerReminderScheduler` | Given `(remindersByPrayer, timings)` arms one `setExactAndAllowWhileIdle` alarm per reminder. Cancels previously-armed reminders before re-arming. Logs every arm and cancel. |
| `PrayerReminderReceiver` | Wakes at T-N, reads extras `(prayer, prayerTimestampMs, notificationId)`, builds the countdown notification, posts it. Returns within 10ms. |

### 7.2 Countdown notification

```kotlin
val builder = NotificationCompat.Builder(ctx, PrayerNotificationChannels.REMINDER_CHANNEL_ID)
    .setSmallIcon(R.mipmap.ic_launcher)
    .setContentTitle(ctx.getString(R.string.reminder_title, prayerNameLocalized))
    .setContentText(ctx.getString(R.string.reminder_body, prayerNameLocalized))
    .setWhen(prayerTimestampMs)             // anchor for the chronometer
    .setUsesChronometer(true)
    .setChronometerCountDown(true)
    .setShowWhen(true)
    .setOnlyAlertOnce(true)
    .setOngoing(false)                       // swipeable
    .setAutoCancel(true)                     // tap launches app, dismisses notification
    .setPriority(NotificationCompat.PRIORITY_DEFAULT)
    .setCategory(NotificationCompat.CATEGORY_REMINDER)
    .setSound(null)
    .setVibrate(longArrayOf(0, 200))
    .setContentIntent(launchAppPendingIntent)

NotificationManagerCompat.from(ctx).notify(notificationId, builder.build())
```

The OS displays a countdown ticking down to `00:00:00` at `prayerTimestampMs`. No app code runs for the visual updates.

### 7.3 Request codes and IDs

| Resource | Range |
|---|---|
| Reminder PendingIntent request codes | `300` (Fajr) `… 304` (Isha). Skips Sunrise. |
| Reminder notification IDs | `2300` (Fajr) `… 2304` (Isha). |
| Adhan PendingIntent request codes | `200..204` (existing) |
| Adhan notification ID | unchanged |

### 7.4 Notification channel

New channel `prayer_reminder_channel`:

- Importance: `IMPORTANCE_DEFAULT` (shows in shade, no head-up)
- Sound: none
- Vibration: short single pulse `[0, 200]`
- Localized name (`Pre-prayer reminders` / `تذكيرات قبل الصلاة`)

Created at app startup in the same place where `prayer_adhan_channel` and `prayer_strip_channel` are created.

### 7.5 Adhan ↔ reminder coordination

When `AdhanAlarmReceiver` fires at T-0, it now also cancels the corresponding reminder notification ID before starting `AdhanPlaybackService`. The prayer-to-notification-ID mapping is defined explicitly (not derived from `PrayerName.index`, which would collide because the enum contains `sunrise`):

```kotlin
object PrayerReminderIds {
    const val BASE = 2300
    val byPrayer: Map<String, Int> = mapOf(
        "fajr" to 2300, "dhuhr" to 2301, "asr" to 2302,
        "maghrib" to 2303, "isha" to 2304,
    )
}

// in AdhanAlarmReceiver.onReceive:
PrayerReminderIds.byPrayer[prayer]?.let {
    NotificationManagerCompat.from(ctx).cancel(it)
}
```

The same map is the single source of truth for `PrayerReminderScheduler` when posting reminders. This guarantees only one notification representing "this prayer" is on-screen at any time.

## 8. iOS — static reminder fallback

iOS uses `flutter_local_notifications` for both adhans (legacy) and now reminders. A new helper on the legacy scheduler:

```dart
Future<void> scheduleStaticReminder({
  required PrayerName prayer,
  required DateTime atUtc,
  required String body,
});
```

Implementation: a single one-shot notification at `at`, title from `reminderNotificationTitle`, body composed from `reminderMinutesBefore`. No chronometer; the message text is the entire UX.

## 9. Data flow

### 9.1 Settings change

```
User toggles Fajr OFF in NotificationsSettingsPage
   │
   ▼
SettingsCubit.updateAdhanEnabled(PrayerName.fajr, false)
   │  emits new state — HydratedBloc persists to disk
   ▼
HomePage BlocListener<SettingsCubit, SettingsState>
   listenWhen: previous.adhanEnabledByPrayer != current
            || previous.reminderMinutesByPrayer != current
   │
   ▼
SyncDailyAdhans(currentPrayerTimes, currentSettings)
```

### 9.2 Re-sync

```
NotificationsRepositoryImpl.scheduleDailyAdhans
   │
   ├── Android:
   │     native.cancelAllAdhans()
   │     native.cancelAllReminders()
   │     native.scheduleDailyAdhans(
   │         timings = prayerTimes.filterEnabled(settings),
   │         clips = audioSettings.clipAssetByPrayer,
   │     )
   │     native.schedulePrayerReminders(
   │         remindersByPrayer = settings.reminderMinutesByPrayer
   │             .where((p, m) => m > 0 && settings.adhanEnabledByPrayer[p]),
   │         timings = prayerTimes.allTimings,
   │     )
   │
   └── iOS: parallel calls into legacyScheduler
```

The repository cancels both alarm chains on every sync; an unconditional cancel-then-arm keeps the state machine trivial.

### 9.3 `SyncDailyAdhans` signature change

```dart
// Before
Future<Either<Failure, void>> call(PrayerTimes prayerTimes);

// After
Future<Either<Failure, void>> call(PrayerTimes prayerTimes, Settings settings);
```

HomePage already holds a `SettingsCubit` reference; passing `state.settingsModel` is a one-line callsite change.

## 10. MethodChannel additions

New methods on `quran_app/notifications`:

```kotlin
// Args
{
  "remindersByPrayer": { "fajr": 15, "asr": 10 },        // omitted prayers = no reminder
  "timings":           { "fajr": 1716445200000, ... }     // epoch ms, all prayers
}
```

| Method | Direction | Behavior |
|---|---|---|
| `schedulePrayerReminders` | Dart → Native | Delegates to `PrayerReminderScheduler.armReminders`. |
| `cancelAllReminders` | Dart → Native | Cancels all 5 reminder PendingIntents and notification IDs `2300..2304`. |

Errors return `MethodChannel` failure codes; `NotificationsRepositoryImpl` maps to `NotificationsFailure` via the existing pattern.

## 11. Test plan

### 11.1 Automated

**Dart unit**

- `SettingsModel.fromMap` applies defaults for both new maps when the JSON has no such keys (existing-user hydration).
- `SettingsModel.toMap → fromMap` round-trip preserves the maps including non-default values.
- `SettingsCubit.updateReminderMinutes(prayer, 7)` throws / no-ops (assert valid step).
- `SyncDailyAdhans` filters disabled prayers before invoking the repository; reminders for disabled prayers are dropped.
- `NotificationsRepositoryImpl` Android branch invokes both `scheduleDailyAdhans` and `schedulePrayerReminders` with the filtered maps.

**Kotlin JVM**

- `PrayerReminderScheduler.armReminders` computes trigger time = prayer time − offset; uses request codes `300..304`; cancels prior alarms before re-arming.
- `PrayerReminderReceiver.onReceive` builds a `NotificationCompat.Builder` with `setUsesChronometer(true) && setChronometerCountDown(true) && setWhen(prayerTimestampMs)`.
- `AdhanAlarmReceiver` cancels notification ID `REMINDER_NOTIF_BASE + prayerIndex` before starting playback.

### 11.2 Manual device checklist

| # | Scenario | Expected |
|---|---|---|
| 1 | Disable Fajr adhan, wait for Fajr | No notification, no audio; `dumpsys alarm` shows no Fajr alarm |
| 2 | Enable Fajr 15-min reminder, wait until T-15 | Notification appears; countdown ticks `14:59 → 14:58 → …` rendered by OS |
| 3 | Reminder still showing when T-0 fires | Reminder auto-dismissed; adhan notification appears immediately |
| 4 | Swipe reminder away before T-0 | Reminder dismissed; adhan fires normally |
| 5 | Toggle Maghrib off while reminder is pending | Reminder + adhan both cancelled; `dumpsys` confirms |
| 6 | Change Asr reminder from Off → 10 → 5 → Off | Three re-syncs; each new state visible in `dumpsys` |
| 7 | iOS: enable 10-min Dhuhr reminder | Static notification fires at T-10 with body "Dhuhr in 10 minutes"; no countdown (platform-expected) |
| 8 | Tap "Play test adhan" | Snackbar, then adhan plays in ~5s via native FGS |
| 9 | Disable all 5 prayers | No alarms at all in `dumpsys`; no notifications fire |
| 10 | Reboot device with reminders configured | Reminders do NOT re-arm; next app open re-arms them (matches adhan policy) |
| 11 | Friday Dhuhr with reminder | Strip Jum'ah label intact; reminder body uses `Dhuhr` label per current strings |

### 11.3 Cross-cutting

- `flutter analyze` clean
- `flutter test` all green
- Kotlin compile clean
- APK delta ≤ ~10 KB (no new assets; only Kotlin + a vector or two if needed)

## 12. Migration & rollback

- **No DB migration.** Hydration falls back to defaults; existing users land on "all on, all reminders off".
- **No feature flag.** Additive UI plus opt-in alarms; rollback = git revert.
- **Two-slice rollback path.** The Dart UI + cubit + repository routing slice is independent from the native reminder slice. To make a partial revert safe, `NotificationsRepositoryImpl` must wrap the new native calls (`schedulePrayerReminders` / `cancelAllReminders`) in a try/catch that swallows `MissingPluginException` with a logged warning. The implementation plan will add this guard alongside the new native methods so that reverting only the Kotlin side never crashes the Dart scheduler.

## 13. Open questions

None at spec-write time. Implementation-detail questions (exact icon choices, snackbar timing, error-mapping codes) will surface during `writing-plans`.
