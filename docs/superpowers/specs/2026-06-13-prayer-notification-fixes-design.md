# Prayer Notification Fixes — Design

- **Date:** 2026-06-13
- **Branch:** `feature/mushaf-reading-experience`
- **Status:** Approved (brainstorming) — pending spec review → writing-plans
- **Workstream:** C of a 4-part program (A mushaf control surface · B background audio/basmala · **C prayer notifications** · D last-read reliability). Each workstream is its own brainstorm → spec → plan → build cycle.

## Problem statement

The pinned prayer-times notification (the "strip") and the adhan-audio notification have four user-reported defects:

1. **12-hour highlight bug.** With the device/app time format set to 12-hour, the strip highlights only Fajr — no other prayer is ever marked "next". With 24-hour format it works.
2. **Ellipsis / sunrise.** The strip crams six cells (incl. الشروق Sunrise, which is not a salah); long labels get truncated with "…".
3. **Notification dies after a few hours / overnight.** On real devices the strip disappears after some time and does not return until the app is reopened.
4. **Adhan audio can't be swiped away.** When the adhan plays, the only way to stop it is the "Stop" action button; swiping the notification does nothing.

## Root causes (verified in code)

### 1. 12-hour highlight bug — native parses a *localized display* string as a 24-hour clock value

- Dart computes the correct "next" prayer in `NextPrayerResolver.resolve` (operates on raw `HH:mm` 24-hour timings) and sends `nextPrayerIndex` in the strip JSON.
- **But the native side throws that index away and recomputes it** in `PrayerStripService.computeNextIndex` (`android/.../PrayerStripService.kt:51,59,114`), which calls `parseHHmm(cell.time)`.
- `cell.time` is the **display** string. When `use24Hour == false`, `PrayerStripStateBuilder._format12Hour` renders 16:28 → `"04:28"`. Native parses `"04:28"` as 268 minutes and compares against the real wall clock (988 minutes). No afternoon cell is ever `> now`, so the loop falls through to `return 0` → Fajr.
- **Same root cause corrupts `scheduleAlarms`** (`PrayerStripService.kt:147`): in 12-hour mode the refresh alarms are scheduled at the wrong wall-clock times.
- The `use24Hour: settings.isFormat12Hours` wiring at `home_page.dart:202` is **correct** — `isFormat12Hours` is misnamed and actually means "24-hour enabled" (see comment there). Not a bug; addressed cosmetically below.

### 2. Sunrise/ellipsis — six cells, one of which isn't a prayer

- `PrayerStripStateBuilder._renderOrder` and `NextPrayerResolver._order` include `PrayerName.sunrise`.
- The RemoteViews layouts (`prayer_strip_collapsed.xml`, `prayer_strip_expanded.xml`) have six equally-weighted cells with `maxLines="1"` + `ellipsize="end"`. Six cells leave too little width for the longer Arabic labels.

### 3. Notification termination — `dataSync` foreground service + self-inflicted midnight hide

Two independent causes:
- **(a) FGS cap.** `AndroidManifest.xml:59` declares `PrayerStripService` with `android:foregroundServiceType="dataSync"`. Android 15 (API 35) imposes a cumulative ~6-hour-per-day timeout on `dataSync` foreground services; after that the system stops the service. Android 14 also restricts starting `dataSync` FGS from `BOOT_COMPLETED`/alarm contexts — `PrayerAlarmReceiver` and `PrayerStripBootReceiver` both call `startForegroundService(...)`, which can throw `ForegroundServiceStartNotAllowedException`.
- **(b) Midnight hide.** The `REASON_MIDNIGHT` alarm maps to `ACTION_HIDE_STRIP` (`PrayerAlarmReceiver.kt:17`), so at 00:01 the strip is removed and does not return until the app is reopened (native only caches *today's* times, so it can't render the new day on its own).

### 4. Adhan swipe — ongoing FGS notification is non-dismissible

- `AdhanPlaybackService.buildNotification` sets `setOngoing(true)` and the notification is the foreground notification of a running FGS, so the system blocks swipe-to-dismiss on most Android versions. A `deleteIntent → ACTION_STOP` is already wired but can't fire because swipe is blocked. The code comment ("user must Stop or swipe", line 109) is therefore wrong for swipe.

## Goals

- Strip highlights the correct prayer in **every** time format and locale.
- Strip refresh alarms fire at the correct wall-clock times in every format.
- Strip shows **5 prayers**, no ellipsis.
- Strip **persists reliably** — survives the Android-15 FGS cap and survives across days (≥ ~1 week) without reopening the app.
- Adhan notification is **swipe-to-dismiss**, and swiping stops playback (button still works too).

## Non-goals

- Porting the prayer-times calculation to native Kotlin. (We reuse the existing precached month — see Fix 3b.)
- Showing prayer days beyond what's already in the local cache (cache is ~1–2 months; we send a bounded window of 7 days).
- Renaming the persisted `isFormat12Hours` settings field (migration risk). We add a semantic getter instead.
- Any change to the in-app prayer countdown (`PrayerCountdownCubit`) — sunrise stays visible in-app; only the pinned strip drops it.

---

## Design

### Fix 1 — Format-independent sort key (`minutes`)

Make native logic operate on a canonical integer, never a localized string.

**Dart**
- `PrayerCell` (`lib/features/notifications/domain/entities/prayer_cell.dart`): add `final int minutes;` = `h*60+m` parsed from the raw `HH:mm` timing (format-/locale-independent). `label` and `timeFormatted` are unchanged and remain display-only.
- `PrayerStripStateBuilder.build`: compute `minutes` from the raw `HH:mm` string (before any 12-hour / Arabic-Indic formatting) and pass it into each `PrayerCell`.
- Serialization (see new contract below): each cell emits `{label, time, minutes}`.

**Kotlin**
- `PrayerCellNative`: add `val minutes: Int`.
- `PrayerStripState.fromJsonString` / `toJsonString` and `PrayerStripPlugin.serializeStripArgs`: carry `minutes` through.
- `computeNextIndex` and `scheduleAlarms`: use `cell.minutes` directly. **Delete `parseHHmm`** (no longer needed for logic; display strings are never parsed natively again).

### Fix 2 — Drop sunrise → 5 cells

**Dart**
- Remove `PrayerName.sunrise` from `PrayerStripStateBuilder._renderOrder`, `_labelsAr`, `_labelsEn`.
- Remove `PrayerName.sunrise` from `NextPrayerResolver._order` (used only by the strip — verified single call site). The two stay consistent at 5 prayers: Fajr, Dhuhr, Asr, Maghrib, Isha.

**Kotlin / layouts**
- `PrayerStripRenderer.bindCells`: drop `cell_5_*` ids; loop `0 until 5`.
- `prayer_strip_collapsed.xml` + `prayer_strip_expanded.xml`: 5 equally-weighted cells (`weightSum="5"`, remove the 6th cell block). More width per cell → no truncation.

### Fix 3 — Retire the `dataSync` foreground service (alarm-driven ongoing notification)

Replace the long-lived FGS with an ordinary ongoing notification that is (re)posted by the work the app already does.

**New native helper:** `PrayerStripController` (object or class with `applicationContext`) exposing:
- `show(ctx, daysJson)` — save the multi-day payload to `PrayerStripStateStore`, then `renderCurrentDay(ctx)`.
- `refresh(ctx)` — `renderCurrentDay(ctx)`.
- `hide(ctx)` — `store.clear()`, cancel alarms, `NotificationManagerCompat.cancel(NOTIFICATION_ID)`.
- `renderCurrentDay(ctx)` (private core):
  1. load days from store; if disabled → return.
  2. pick the day whose `dateKey == formatKey(now)`; if none → `hide()` and return.
  3. `nextIndex = computeNextIndex(day.cells, now)` (from `minutes`).
  4. `NotificationManagerCompat.notify(NOTIFICATION_ID, renderer.build(day, nextIndex, accent))` — **no `startForeground`**.
  5. `scheduleAlarms(day.cells)` + a midnight alarm.

**Callers (all post in-process; no `startForegroundService`):**
- `PrayerStripPlugin.handleEnableOrRefreshStrip` → `PrayerStripController.show(ctx, json)`.
- `PrayerStripPlugin.handleDisableStrip` → `PrayerStripController.hide(ctx)`.
- `PrayerAlarmReceiver.onReceive`: `REASON_MIDNIGHT` and `REASON_PRAYER` both → `PrayerStripController.refresh(ctx)` (midnight now *rebuilds the new day*, see Fix 3b — it no longer hides).
- `PrayerStripBootReceiver.onReceive` → `PrayerStripController.refresh(ctx)`.

**Notification:** keep `setOngoing(true)` + `IMPORTANCE_LOW` + custom RemoteViews. Pre-Android-14 this is non-swipeable; on 14+ the user may dismiss it, but it returns at the next alarm refresh / app open. No FGS → no 6-hour cap, no boot/alarm FGS-start exception.

**Manifest / permissions:**
- Delete the `<service android:name=".PrayerStripService" android:foregroundServiceType="dataSync" .../>` entry and **delete `PrayerStripService.kt`**.
- Remove the `FOREGROUND_SERVICE_DATA_SYNC` permission. **Keep** `FOREGROUND_SERVICE` + `FOREGROUND_SERVICE_MEDIA_PLAYBACK` (still needed by `AdhanPlaybackService`). Keep `SCHEDULE_EXACT_ALARM`/`USE_EXACT_ALARM`, `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`.

### Fix 3b — Multi-day cache + midnight rebuild

Make the strip render the correct day for ~a week without the app being opened.

**Dart**
- Data layer already supports any date: `PrayerTimesLocalDataSource.getCached({DateTime date})` reads from the precached month; `preCacheMonth` populates it.
- Add a repository read path for an arbitrary cached date that does **not** hit the network, e.g. `PrayerTimesRepository.getCachedForDate(DateTime date) → PrayerTimes?` (cache-only; returns null on a gap). Implement by delegating to `getCached(date: date)`.
- Strip build path (in/near `home_page.dart` `_enableOrRefreshStrip`, extracted to a small builder/usecase): build a **list** of strip days for `today .. today+6`, stopping at the first cached gap; skip `null` days. Each day uses that date's timings (with `minutes`), Hijri/weekday labels, and `isFriday` for that date.
- The contract sends the list (see below). `nextPrayerIndex` is no longer sent (native computes it per current time).

**Kotlin**
- New data classes: `PrayerStripDay(dateKey: String, cells: List<PrayerCellNative>, hijriDateLabel, weekdayLabel, localeCode, isFriday)` and a top-level payload `{ days: [PrayerStripDay], accentColor? }`.
- `PrayerStripStateStore` stores the days payload JSON (key unchanged in spirit; `isEnabled` flag retained).
- `renderCurrentDay` selects today's day by `dateKey == formatKey(now)` (format `"dd-MM-yyyy"`, matching Dart `formatKey`).
- Midnight alarm now just calls `refresh` → `renderCurrentDay`, which naturally advances to the new day (or hides if the cache window is exhausted). When the app is next opened the window is replenished.

### Fix 4 — Adhan notification: swipe-to-terminate

**`AdhanPlaybackService.kt`:**
- `buildNotification`: `setOngoing(false)`, `setAutoCancel(false)`, keep `setDeleteIntent(stopPI)` and the Stop action. (On Android 14+ swiping the FGS notification now fires the delete intent → `ACTION_STOP`.)
- `onCompletion`: after releasing the player, call `stopForeground(STOP_FOREGROUND_DETACH)` and re-post a **dismissible** notification (`ongoing=false`, `autoCancel=true`, same delete intent) so swipe reliably stops/cleans up on all versions even after audio ends.
- Verify swipe → `handleStop` → player stop + `stopSelf()`.

### Cosmetic — semantic getter for the time-format flag

- `Settings` (domain entity): add `bool get is24HourFormat => isFormat12Hours;` (pure Dart; no migration).
- Use `settings.is24HourFormat` at `home_page.dart:202` (`use24Hour: settings.is24HourFormat`). Persisted field name unchanged.

---

## Data contract change (MethodChannel `quran_app/notifications`)

**Before** — single day:
```json
{ "cells": [{"label","time"}], "nextPrayerIndex": int,
  "hijriDateLabel","weekdayLabel","localeCode","isFriday", "accentColor"? }
```

**After** — bounded window of days; cells carry `minutes`; no `nextPrayerIndex`:
```json
{
  "days": [
    { "dateKey": "13-06-2026",
      "cells": [{"label": "الفجر", "time": "04:15", "minutes": 255}, ...5 cells],
      "hijriDateLabel": "...", "weekdayLabel": "...",
      "localeCode": "ar", "isFriday": false }
    /* ...up to 7 days */
  ],
  "accentColor": "#FF2E5244"
}
```
`disableStrip` is unchanged (no args).

---

## File impact (indicative — final list set by the plan)

**Dart**
- `lib/features/notifications/domain/entities/prayer_cell.dart` — add `minutes`.
- `lib/features/notifications/domain/entities/prayer_strip_state.dart` — per-day shape + list payload JSON; drop `nextPrayerIndex` from the wire.
- `lib/features/notifications/domain/builders/prayer_strip_state_builder.dart` — compute `minutes`; drop sunrise; build per supplied date.
- `lib/features/notifications/domain/services/next_prayer_resolver.dart` — drop sunrise.
- New/extended: multi-day strip builder usecase + `PrayerTimesRepository.getCachedForDate`.
- `lib/features/home/data/repositories/prayer_times_repository_impl.dart` — implement `getCachedForDate`.
- `lib/features/home/presentation/pages/home_page.dart` — build the 7-day list; use `is24HourFormat`.
- `lib/features/settings/domain/entities/settings.dart` — `is24HourFormat` getter.
- Native data source that serializes the channel args — send the `days` payload.

**Kotlin**
- New `PrayerStripController.kt`; **delete** `PrayerStripService.kt`.
- `PrayerStripState.kt` — `PrayerStripDay` + payload, `minutes`.
- `PrayerStripRenderer.kt` — 5 cells; `build(day, nextIndex, accent)`.
- `PrayerStripStateStore.kt` — store days payload.
- `PrayerStripPlugin.kt` — call controller; serialize `days`+`minutes`.
- `PrayerAlarmReceiver.kt`, `PrayerStripBootReceiver.kt` — call controller; midnight → refresh (rebuild, not hide).
- `AdhanPlaybackService.kt` — swipe-to-dismiss.
- `AndroidManifest.xml` — remove strip service + `FOREGROUND_SERVICE_DATA_SYNC`.

**Layouts**
- `res/layout/prayer_strip_collapsed.xml`, `res/layout/prayer_strip_expanded.xml` — 5 cells.

---

## Testing

- **Dart unit tests** (`fvm flutter test test/features/notifications/...` and `test/features/home/...` only — never the full suite, per the asset-regeneration caveat):
  - `PrayerStripStateBuilder`: emits 5 cells; `minutes` correct from raw `HH:mm`; display `time` correct in 12h/24h and Arabic-Indic; Friday → Jumu'ah label; per-date build uses the right day's data.
  - `NextPrayerResolver`: 5-prayer order; wrap-to-Fajr when all passed.
  - JSON round-trip of the `days` payload incl. `minutes` and `dateKey`.
  - Multi-day builder: stops at first cache gap; window length bounded; skips nulls.
  - `Settings.is24HourFormat` mirrors `isFormat12Hours`.
- **Kotlin:** `computeNextIndex`/`scheduleAlarms` become trivial int comparisons; cover with a small JVM unit test if a test target exists, else rely on the Dart contract tests + manual verification.
- **Manual on-device gates (documented, not automated):**
  - 12h device format → correct prayer highlighted; alarms fire on time.
  - Strip persists past 6h and across local midnight without reopening the app (within the 7-day window).
  - Boot → strip returns.
  - Adhan plays → swipe the notification → audio stops and notification clears (Android 12, 14, 15 if available).

## Risks / caveats

- **Android 14+ strip dismissibility.** A non-FGS ongoing notification can be user-swiped on 14+. Accepted: it returns at the next refresh/app open. This is the standard trade-off for persistent prayer notifications and is strictly better than unpredictable system kills.
- **Cache window vs. very long no-open periods.** If the app isn't opened for > the precached horizon, the strip eventually hides until reopened. Bounded by the existing month cache; 7-day window is comfortable.
- **OEM battery killers** kill the *process*, not posted notifications or exact alarms (`setExactAndAllowWhileIdle`); this design is resilient to that.
- **Manifest/permission removal** must be verified to not break the adhan media-playback FGS (separate permission, retained).
