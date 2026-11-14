# Permissions Flow — Fixes & Gentle Re-grant Design

**Date:** 2026-05-30
**Status:** Approved (design)
**Scope:** Onboarding permission prompts, orphaned adhan audio, and a gentle re-grant flow for skipped permissions.

## Problem statement

Three issues in the first-run / permissions experience:

1. **Premature notification prompt.** On the onboarding location step, the instant the user grants location, the OS notification permission dialog fires — before the user reaches or reads the notification rationale step.
2. **No re-grant path.** If the user skips (or later loses) a permission, nothing guides them back to grant it; the app gives no contextual nudge and no durable entry point.
3. **Orphaned adhan audio.** When notification permission is not granted, the adhan sound plays with no visible notification card, and cannot be stopped until the clip finishes on its own.

## Root causes (verified against code)

### Bug #1 — premature notification prompt
`main.dart` (`_AppLoaderState._initAll`) runs a post-frame loop:

```dart
while (await Geolocator.checkPermission() == LocationPermission.denied) {
  await Future.delayed(const Duration(milliseconds: 300));
}
await sl<PrayerNotificationScheduler>().init();
```

`PrayerNotificationSchedulerImpl.init()` calls `requestNotificationsPermission()` (and `requestExactAlarmsPermission()`). Granting location on the onboarding location step makes `checkPermission()` return non-`denied`, the loop unblocks, `init()` runs, and the notification dialog appears immediately — over the location step, before the notification step.

Secondary defect: if the user taps "Not now" on location, permission stays exactly `denied`, so the loop spins forever and `init()` (timezone + iOS channel setup) never runs.

### Bug #3 — orphaned adhan audio (Android only)
`AdhanAlarmReceiver.onReceive` → `startForegroundService()` → `AdhanPlaybackService` plays the adhan via `MediaPlayer` on `AudioAttributes.USAGE_ALARM` **and** posts the ongoing foreground-service notification that carries the only **Stop** action.

On Android 13+ without `POST_NOTIFICATIONS`, the foreground-service notification is suppressed, but `MediaPlayer` audio on the alarm stream plays regardless. Result: adhan audio with no card and no Stop control until the clip ends. iOS is unaffected (it simply doesn't fire the notification; no orphaned audio).

### Re-grant signal availability
The data layer already produces distinct, typed failures in `geolocator_error_handler.dart`:
`LocationPermissionDeniedFailure`, `LocationPermissionDeniedForeverFailure`, `LocationServiceDisabledFailure`, `TimeoutFailure`, `UnknownFailure`. However `DailyPrayerContextCubit` collapses them into `DailyPrayerContextFailed(failure.message)` — a plain string — discarding the type the UI needs.

The Android manifest declares `USE_EXACT_ALARM`, so `requestExactAlarmsPermission()` is effectively silent (no settings navigation) and can be removed from `init()` safely.

## Design

### Part 1 — Bug #1 fix: make `init()` non-interactive, ungate it

- Remove `requestNotificationsPermission()` and `requestExactAlarmsPermission()` from `PrayerNotificationSchedulerImpl.init()`. `init()` retains only: timezone setup, channel creation, legacy-channel migration, `_initialized = true`.
- In `main.dart`, remove the location-permission poll. Call `init()` unconditionally after `initGetIt()` (it no longer needs location and no longer prompts). This also removes the spin-forever-on-"Not now" defect.
- The onboarding **notification step** (`onboarding_page.dart`, `_notificationsStep`) remains the sole first-run notification prompt, fired only when the user taps **Enable** on that step.

**Result:** granting location no longer triggers a notification prompt; the notification prompt happens only when the user explicitly asks for it.

### Part 2 — Bug #3 fix: gate adhan playback on notification permission

- **Primary (runtime guard):** in `AdhanAlarmReceiver.onReceive`, before `startForegroundService()`, check
  `NotificationManagerCompat.from(context).areNotificationsEnabled()`. If `false`, log and `return` — never start the service. (Checking in the receiver, not inside the service, avoids the start-then-`stopSelf` `ForegroundServiceDidNotStartInTime` crash. If a guard is ever added inside the service it must call `startForeground()` first, then `stopSelf()`.)
- **Supporting (scheduling gate):** when adhan alarms are scheduled, skip scheduling if notifications are disabled; when the user grants notifications via the re-grant flow or onboarding, trigger a reschedule so future adhans fire.
- **Stated behavior:** notifications OFF → **no adhan fires at all.** Consistent with the "optional / gentle" stance. Documented so it is an intentional product decision, not a silent side effect.

### Part 3 — Re-grant flow (gentle, contextual; option C)

Both permissions are treated as **optional**; the app stays usable. Surfaces are contextual (shown where the feature is used) plus a durable Settings path. No blocking dialogs, no global launch banner.

**Location (required for prayer times):**
- Promote `DailyPrayerContextFailed` to carry the typed `Failure` (not a string). Add the `Failure` import to the state file; update the cubit to emit `DailyPrayerContextFailed(failure)`.
- `HomeView` branches on the failure type:
  - `LocationPermissionDeniedFailure` → **recovery card** in place of the prayer area: "Prayer times need your location" + **Enable** button that re-requests permission.
  - `LocationPermissionDeniedForeverFailure` / `LocationServiceDisabledFailure` → same card; the button **deep-links** to settings (`Geolocator.openAppSettings()` for denied-forever, `Geolocator.openLocationSettings()` for service-disabled), since the OS dialog will not reappear.
  - any other failure (network, timeout, unknown) → existing generic error + retry. *(Ensures a network error never tells the user to enable location they already granted.)*

**Notifications (optional):**
- A slim, **dismissible** inline hint on Home ("Turn on adhan alerts" + **Allow**), shown only when location is granted (so prayer times render) **and** OS notifications are disabled.
- **Allow** triggers `requestNotificationsPermission()` and, on grant, a reschedule.
- **Dismiss** persists a flag (settings/Hive) so the hint does not re-nag. Default: **persistent dismiss** (hidden until re-enabled or surfaced via Settings) — not snooze-and-return.
- The hint remains discoverable in Settings regardless of dismissal.

**Durable Settings path:**
- `NotificationsSettingsPage` (Adhan & reminders) shows a top banner when OS notifications are disabled, with an **Open settings** action.

**Resume re-check:**
- Home registers a `WidgetsBindingObserver`. On `AppLifecycleState.resumed`, it re-queries permission state (`Geolocator.checkPermission()` + scheduler `areNotificationsEnabled()`) and re-fetches the prayer context, so the recovery card / notification hint clear automatically when the user returns from settings having granted.

### Part 4 — Permission-state plumbing

- Add `Future<bool> areNotificationsEnabled()` to the `PrayerNotificationScheduler` abstraction and implement it:
  - Android: `AndroidFlutterLocalNotificationsPlugin.areNotificationsEnabled()`.
  - iOS: derive from `checkPermissions()` (alert/sound authorized).
- Location state for the resume re-check reads `Geolocator.checkPermission()`; initial render is driven by the typed failure from the fetch (more precise — distinguishes service-disabled from permission-denied).

## Component boundaries

- **`PrayerNotificationSchedulerImpl`** — `init()` becomes non-interactive; gains `areNotificationsEnabled()`. No UI knowledge.
- **`AdhanAlarmReceiver` (Kotlin)** — owns the runtime "are notifications enabled?" gate before starting playback. Single responsibility: decide whether to dispatch to the service.
- **`DailyPrayerContextCubit` / state** — carries typed `Failure`; no UI decisions.
- **`HomeView` + small new widgets** (`LocationRecoveryCard`, `NotificationHint`) — pure presentation; read state + permission queries, render the right surface. Each widget answers: what it shows, when it shows, what it depends on.
- **`NotificationsSettingsPage`** — gains a disabled-notifications banner.

## Error handling

- Permission requests wrapped in try/catch (as today) — a thrown platform exception never traps the user.
- Deep-links to settings are best-effort; failure is silent (user can still navigate manually).
- Resume re-fetch failures fall through to the existing failure-state handling.

## Testing

- **Cubit test:** each typed `Failure` maps to the expected `DailyPrayerContextFailed(failure)`; non-permission failures stay generic.
- **Widget tests (Home):**
  - location-denied failure → recovery card with Enable.
  - denied-forever / service-disabled → recovery card with settings deep-link.
  - notifications disabled (location granted) → notification hint visible.
  - both granted → neither surface shown.
  - dismiss hint → hint hidden and stays hidden.
- **Scheduler test:** `areNotificationsEnabled()` returns the platform value (mocked plugin).
- **Manual / instrumented (Android):**
  - Onboarding: granting location does **not** trigger the notification dialog.
  - Adhan with notifications disabled: no audio fires (receiver gate); with notifications enabled: adhan + card + Stop work.

## Out of scope

- Reworking the onboarding wizard structure or copy beyond the prompt-timing fix.
- Snooze-and-return scheduling for the notification hint (persistent dismiss chosen instead).
- iOS adhan delivery changes (iOS is unaffected by bug #3).
- Unrelated refactors of the prayer-times fetch or scheduling pipeline.
