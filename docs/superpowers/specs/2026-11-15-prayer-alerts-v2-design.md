# Prayer alerts v2: design

Date: 2026-11-15. Branch: `feature/prayer-alerts-v2`. Builds on `docs/superpowers/specs/2026-06-13-prayer-notification-fixes-design.md` (Android native pipeline, already shipped).
Design sources (local, not committed): `docs/design-audit/prayer/settings/final-spec.md` (screens and copy), `docs/design-audit/prayer/_docs/{contract,delta-feasibility,delta-redmi}.md` (code truth, OS limits, Redmi research), `docs/design-audit/tokens.md` "v2 comfort tokens". The behaviour in this spec does not depend on them: copy is in Appendix A, screen states in Appendix C, theme values in Appendix B, the adb triage in §15, deep links in §7, and the reasons for rejected approaches in §4. The local files hold the visuals and the research behind the cause ranking.

## 1. Intent

The owner uses the app every day on a Xiaomi REDMI. Prayer alerts stop within hours, the pinned strip disappears, iOS ignores the per-prayer toggles and has no adhan sound. He wants the basic prayer-alert controls, done simply. The build goes to the owner first and later to the app's public users, so upgrade paths (migration, upgrade sheet, the alarm snapshot written by the current release) matter. "v1" below means the build shipped today; "v2" means this design. Prayer alerts are a side feature, so Home stays as it is and everything lives behind one row in Settings.

Success:
- On the Redmi, adhans keep firing for the 7-day window, extended from the snapshot, without opening the app, unless the OS force-stops it. When the OS still blocks the app, the app says so and shows the fix. Verified on the device by the owner with the §15 adb triage.
- Each prayer can be set in one sheet: alert on/off, sound, ring in silent mode, and a reminder of 1–60 minutes with its own sound.
- A normal notification by default, which follows silent mode and Do Not Disturb. Ringing through silent mode is an opt-in per prayer.
- iOS honours the toggles and plays a bundled adhan clip.

## 2. Goals, non-goals, anti-goals

Goals
- G1 Android reliability: miss detection that names the cause and the fix, a late fallback instead of a silent drop, alarm-clock adhans, and a native 7-day rolling horizon that heals itself from a snapshot of up to 30 cached days. Re-arm on boot, update and time change, plus an independent daily heal alarm. Cause → mechanism map in §7.
- G2 Per-prayer alert model `PrayerAlert`, with migration from today's two maps.
- G3 Audio routes: adhan, notification tone, vibrate only, or silent per prayer. The reminder sound is separate. Ringing through silent mode is per prayer.
- G4 UI: one Settings row, the «الأذان والتذكيرات» page, the prayer sheet, sound pickers with preview, a reliability page, and the strip settings page.
- G5 Strip redesign: two-line compact cells, a vertical expanded view, countdown, highlight, background and shape, and Arabic-Indic digits.
- G6 Onboarding: an alert-preferences step and a Xiaomi-only reliability step. Upgraders get a one-time sheet. A missed adhan opens a sheet.
- G7 iOS: honour the toggles and sounds, bundle clips of 29 s or less, Arabic text, and a rolling schedule of ⌊60 / requests per day⌋ days (6 with all alerts and reminders on, at most 12).
- G8 Comfort theme (the owner asked for an eye-comfort pass during this design): v2 neutral/slate tokens, plus `onPrimary`, `primaryInk`, `primaryTint`, `error` and `onError` getters, with the dark switch track drawn in `primaryInk`.
- G9 Small fixes: Home's next prayer skips sunrise (logic only, no visual change), scheduling is deduped and debounced, «فتح الإعدادات» opens the app's notification settings, legacy channels are deleted, raw audio is kept under resource shrinking, and the Android label is «الفرقان» (it heads every notification this feature posts).

Non-goals
- No time offsets, extra muezzin voices, reminder chime asset, Imsak/Duha/Jumu'ah, high-latitude rules, or on-device prayer-time calculation (§4).
- No iOS Live Activity or pinned strip on iOS.
- No foreground service to keep the app alive (S4 in §4), no FCM push (it needs a server, and a high-priority push cannot start a force-stopped app either), and no `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` (Play restricts it to apps whose core function breaks without it; the settings intent in §7 reaches the same screen with no policy risk).
- No visual change to Home.

Anti-goals (a failure even if it "works")
- A UI that promises delivery the OS can block.
- Alerts ringing through silent mode without the user opting in.
- Re-onboarding existing users.
- Nagging: the Xiaomi checklist appears in onboarding, once for upgraders, and then only after a detected miss.

## 3. Constraints

- Flutter 3.50 via FVM, Clean Architecture + Cubit, HydratedCubit `SettingsCubit`, GetIt, Either, GoRouter, `TS.*` (the app's text styles in `lib/config/theme/`), `context.colorScheme`, HugeIcons stroke-rounded. Every rule in `.claude/rules/` applies (repo-local rule files; `localization.md` and `core-widgets.md` named below live there). The owner's global instructions forbid code comments. Never edit `lib/generated/`. ARB files regenerate through the IDE, so new keys go into both ARBs and `lib/generated` updates on the owner's next save. Code must compile before that save, so §10 says how strings are referenced until then.
- `RadioListTile.groupValue` is deprecated in 3.50, so pickers use `RadioGroup<T>`.
- Android: RemoteViews only (LinearLayout, TextView, ImageView). Collapsed content is about 48 dp, expanded at most 252 dp. Flutter sizes below are logical px. Colour tinting of backgrounds needs API 31; lower APIs fall back to a flat fill. Channel sound and importance are fixed once a channel is created, so every new sound gets a new channel id.
- MIUI autostart and the battery saver cannot be read or granted programmatically.
- iOS: notification sounds must be in the bundle and under 30 s. There is a cap of 64 pending requests. No vibrate-only, no override of silent mode.

## 4. Approaches considered

Scheduling and audio

| Id | Approach | Trade-off | Verdict |
|---|---|---|---|
| S1 | Keep alarm-stream audio for all (today) and add settings | Simple, but rings through silent mode for everyone, which breaks the anti-goal in §2 | Rejected |
| S2 | **Normal notification route by default, per-prayer opt-in to the alarm stream; adhans armed with `setAlarmClock`; native self-healing horizon** | More native work (channels, a route decision at fire time, snapshot window) | **Chosen** |
| S3 | Dart-only rescheduling (re-arm only when the app opens) | No native heal, so a week unopened ends alerts; the strip has the same gap | Rejected |
| S4 | Foreground service keeping the app alive | MIUI still kills it on swipe, Android 15 caps dataSync at 6 h, and an ongoing icon stays visible | Rejected |

Within S2, adhans use `setAlarmClock`: it is exempt from Doze and MIUI saver delays, but it shows an alarm icon in the status bar and the prayer as the lock screen's "next alarm", and it does not survive a force-stop. It sits behind one constant, `AdhanScheduler.USE_ALARM_CLOCK` (default true; false arms adhans with `setExactAndAllowWhileIdle`, same fallback), and the PR lists it as an owner decision.

Other design choices

| Choice | Alternatives | Why this one |
|---|---|---|
| Miss detection compares an armed log with fire records | Derive expectations from the snapshot alone | The snapshot holds triggers that were never armed (a new install's passed prayers, a re-enabled prayer, times shifted by a method change), which would read as false misses |
| Arm a 7-day window and heal it daily | Arm the whole snapshot (up to about 300 alarms) | Fewer heal paths, but every sync and re-arm rewrites hundreds of alarms near the per-app alarm limit (500), and settings edits get slow; 7 days with heal keeps re-arms small |
| Daily heal alarm at 00:05 | WorkManager periodic work | WorkManager adds a dependency, runs at 15 min granularity at best and is deferred by Doze and MIUI like any job; one inexact alarm suffices because exact adhans are already armed days ahead |
| Times come from the cached API months | On-device prayer-time calculation | A second source could disagree with the times the app shows; the cache plus an always-fetched next month covers about 30 days |
| Upgraders start with ring-in-silent off and see a one-time sheet | Migrate `ringInSilent = true` to keep v1's sound | Keeping it would make the alarm stream the default for every existing user, against the silent-mode anti-goal; the owner chose off (listed in the PR) |
| iOS schedules a static ⌊60 / requests per day⌋ days and extends on each open | `BGAppRefreshTask` | iOS runs it at its own discretion, often not at all for rarely used apps, so it cannot be relied on; the status line shows when the iOS schedule has run out |
| `PendingS` until the IDE regenerates `S` (§10) | Run `intl_utils` by hand; edit `lib/generated`; hard-code strings; wait for the IDE before writing UI | The first two break the repo's rules, hard-coding loses the ARB link, and waiting blocks the build. `PendingS` keeps ARB keys and a parity test |

UI (four variants, scored by two judges on a 40-point rubric: hierarchy, brand, RTL, accessibility, density, jobs, Flutter cost, performance)

| Variant | Total | Why it lost or won |
|---|---|---|
| U1 calm list, nested pickers | 33 | **Chosen**: clear hierarchy, cheapest to build with existing widgets |
| U2 everything in one sheet | 28 | Too dense: sound, reminder and silent options compete in one tall sheet |
| U3 two moments, two tabs | 28 | Tabs hide one of the two moments; weaker accessibility and higher build cost |
| U4 reference-familiar | 29 | Copies the reference app's look, with weaker hierarchy and brand fit |

U2–U4 each gave one graft to U1: U2 the one-line silent-mode line and the «يصلك» time, U3 the collapsed/expanded preview toggle and the slider end labels, U4 the method reason line.

## 5. Architecture overview

Components and the end-to-end flow:

1. **Settings** (`SettingsCubit`, HydratedCubit) hold `prayerAlerts` and `StripStyle` (§6).
2. **`AlertsSyncCubit`** (§8) debounces changes, collects the cached days, and calls `SyncDailyAdhans` and the strip use cases.
3. **Repository → data source → `quran_app/notifications` MethodChannel** carry the snapshot (days, per-prayer alerts, strip window and style) to native (§18 seam 3).
4. **Native schedulers** (`AlertPlanner`, `AdhanScheduler`, `PrayerReminderScheduler`, `PrayerStripController`) persist the snapshot and arm the rolling 7-day window (§7).
5. **Receivers** fire: `AdhanAlarmReceiver` takes the fire-time route (playback service or a channel notification) and records the outcome; `PrayerReminderReceiver` posts reminders; the boot and heal receivers re-arm from the snapshot.
6. **`getReliabilityStatus`** reads OS state and the records back; `ReliabilityCubit` drives the status line and reliability page, and `AlertsPromptGate` shows the upgrade or missed sheet (§8).
7. **iOS** replaces steps 3–5 with `PrayerNotificationSchedulerImpl.scheduleAlerts` over `flutter_local_notifications` (§9).

## 6. Domain

```dart
enum PrayerSound { adhan, tone, vibrate, silent }
enum ReminderSound { tone, vibrate, silent }

class PrayerAlert {
  final bool enabled;          // default true
  final PrayerSound sound;     // default adhan (Fajr resolves to the Fajr clip)
  final bool ringInSilent;     // default false; meaningful only for adhan on Android
  final bool reminderEnabled;  // default false; effective only while enabled
  final int reminderMinutes;   // 1..60, default 10
  final ReminderSound reminderSound; // default tone
}
```

- `Settings.prayerAlerts: Map<PrayerName, PrayerAlert>` replaces `adhanEnabledByPrayer` and `reminderMinutesByPrayer`. There are 5 keys and no sunrise.
- Migration in `SettingsModel.fromMap`: when `prayerAlerts` is missing, derive it from the legacy maps:
  - `enabled` = legacy adhan flag.
  - `reminderEnabled` = legacy minutes > 0 (the effective reminder still requires `enabled`, so re-enabling the alert brings the reminder back). Declared behaviour change: v1 sent a reminder even for a prayer whose adhan was off; v2 does not (the owner's rule that a reminder exists only while the alert is on).
  - `reminderMinutes` = the legacy value if it is > 0, else 10.
  - The rest use defaults.
- Values out of range are clamped to 1..60. Unknown enum names fall back to the default. `fromMap` never throws.
- Strip: `StripStyle { expanded=true, showCountdown=true, highlight=StripHighlight.app, background=StripBackground.auto, shape=StripShape.rounded }`. The enums carry no colours in domain. Colours live in a presentation/data mapping that sends day and night ARGB values to native.
  - Highlight: app, darkGreen, emerald, blue, indigo, maroon, bronze.
  - Background: auto, mint, sand, sky, rose.
  - Shape: none, rounded, pill, outline.
- New flags:
  - `alertsIntroSeen` (default false; onboarding completion sets it true; an upgrader without the key sees the one-time sheet).
  - `xiaomiAutostartConfirmed` and `xiaomiBatteryConfirmed` (self-confirm, default false).
- Effective reminder = `enabled && reminderEnabled`. One pure helper `PrayerAlert.effectiveReminderMinutes` returns `int?`.
- `ReliabilityStatus`, a read-only snapshot from native:
  - `notificationsEnabled`
  - `channelBlocked` (true when a channel the current settings route to, or `prayer_adhan_channel`, has importance NONE)
  - `exactAlarmsAllowed`
  - `batteryUnrestricted`
  - `isXiaomi`
  - `scheduledUntil` (DateTime?, the last armed adhan trigger)
  - `snapshotUntil` (DateTime?, the snapshot's last date)
  - `missed` (List<MissedAlert{prayer, at}>)
  - `late` (List<MissedAlert{prayer, at}>, unacknowledged late deliveries)
  - `usesAlarmClock` (the native `USE_ALARM_CLOCK` value, so Dart never assumes it)

## 7. Android native (G1, G3, G5, G9)

### Causes and mechanisms

Ranked by likelihood in the owner's Redmi research (delta-redmi §2). Native build order inside §18 follows this ranking; §18's task order wins where they differ.

| Cause (rank) | Symptom | Mechanism here | What no code can fix |
|---|---|---|---|
| 1. MIUI force-stop (swipe, clean-up) | Alerts and the strip vanish within hours | Miss detection and the missed sheet; Xiaomi checklist (onboarding, upgrade sheet, reliability page); deep links | No code survives a force-stop. The user must lock or allow the app. |
| 2. Autostart blocked after process death | Alarms registered but never delivered | Same checklist; miss detection | Autostart can't be read |
| 3. Battery saver / Doze deferral | Late or dropped adhans | `setAlarmClock`; late notification instead of drop; FGS-start fallback | A deferred adhan still arrives late, as a silent late notification |
| 4. Horizon runs out (days, not hours) | Silence after days unopened | Snapshot of up to 30 days (at least the rest of this month plus next month, once precache always fetches next month), a rolling 7-day window, daily heal alarm, re-sync after precache | Ends where the cache ends |
| 5. Strip window exhausted | Strip disappears after 7 days | The strip gets the same cached range | Ends where the cache ends |

### Scheduling

- Dart sends **every cached day** from today on (up to 30, deduped by date, read through `PrayerTimesRepository.getCachedForDate`). Reach depends on the cache. Today `PreCachePrayerTimes` fetches next month only when 7 or fewer days remain; v2 changes it to fetch next month whenever it isn't cached yet, so the snapshot always reaches into next month (at least about 30 days after one online open). The sync runs again when that precache completes. This is the snapshot. `AdhanScheduler.armDays` and `PrayerReminderScheduler.armDays` arm the first `MAX_DAYS = 7` dates that still have a future trigger, in slots 0..6:
  - adhan request code = 200 + slot×10 + prayerIndex
  - reminder request code = 300 + slot×10 + prayerIndex
  - The test alarm stays at 299. It carries v2 extras (`sound` and `ringInSilent` from Dhuhr's alert, sent by Dart) plus `test = true`: it takes the delivery steps 4–5 only, writes no record or armed-log entry, and never takes the legacy branch. `cancelAll` covers all 7 slots.
- Re-arming sets the new slots first, then cancels only the slots that were not re-armed (the same request code replaces a pending alarm), so a process killed mid-heal never leaves zero alarms. A slot whose trigger is in (now − 30 min, now] with no record yet is still pending (deferred) and is not cancelled unless this run reassigned its request code.
- The adhan alarm extras carry `sound`, `ringInSilent`, `armedAt` (wall clock at arming), `armedElapsed` (`elapsedRealtime` at arming) and `nextAt`, the next canonical time: sunrise for Fajr, then Asr, Maghrib and Isha in order whether or not those are enabled, and tomorrow's Fajr for Isha (Isha + 6 h when tomorrow is not in the snapshot). The snapshot carries all six timings per day plus the per-prayer `sound` and `ringInSilent` for enabled prayers. The reminder payload carries minutes and `reminderSound`. Disabled prayers are omitted, and reminders exist only for enabled prayers (Dart filters).
- Adhans use `setAlarmClock(AlarmClockInfo(trigger, openAppPI), pi)` while `USE_ALARM_CLOCK` is true, else `setExactAndAllowWhileIdle`. If that throws SecurityException, they fall back to `setAndAllowWhileIdle` (the exact variant needs the same permission). Reminders and the strip stay on exact-while-idle.
- v1 already ships the snapshot, `rearmFromSnapshot`, the boot/update/time-change re-arm and the `setAndAllowWhileIdle` fallback (`AdhanScheduler.kt`, `AdhanBootReceiver.kt`, `MAX_DAYS = 3`). v2's delta: 7 days, the heal alarm, both schedulers in every heal path, per-prayer payloads, and the records below.
- Self-heal: `rearmFromSnapshot` re-runs **both** `AdhanScheduler.armDays` and `PrayerReminderScheduler.armDays`:
  - after every adhan fire (all branches);
  - at a daily heal alarm: 00:05, `setAndAllowWhileIdle` (inexact is enough, because exact adhans are already armed days ahead), request code 298, an explicit intent to a new `AdhanHealReceiver` (`exported="false"`), owned by `AdhanScheduler` and independent of the strip;
  - in `AdhanBootReceiver` for BOOT_COMPLETED, MY_PACKAGE_REPLACED, TIME_SET and TIMEZONE_CHANGED; it checks the action and ignores anything else. BOOT_COMPLETED also stores `lastBootHandledAt`.
  Past dates fall away, so the 7-day window rolls forward for as long as the snapshot lasts.
- TIME_SET/TIMEZONE_CHANGED also store `lastClockChangeAt`. MY_PACKAGE_REPLACED and the first v2 snapshot write set `lastCheckedAt` to now when it is unset, so v1-era triggers are never judged.
- Every snapshot read, arm, cancel, record write and snapshot write runs on one single-thread executor in `AlertPlanner`'s owner, with `SharedPreferences.commit()`, so the receiver, heal alarm, boot receiver and a Dart sync never interleave.
- **Update path:** a snapshot or a pending alarm's extras with no `sound` field are legacy, written by v1, whose payload carries a `clips` map of prayer → clip name instead of per-prayer sounds.
  - Legacy entries re-arm with v1 behaviour (sound = adhan, ringInSilent = **true**, today's alarm stream; legacy reminders get `reminderSound = vibrate`, v1's channel) until the first sync after the app opens, so the first Fajr after an update does not go silent without notice. This is a deliberate exception to the silent-mode anti-goal, limited to the time before that first sync.
  - A JUnit case covers v1 parsing.
  - A parse failure keeps the alarms already armed (no `cancelAll` before a successful parse).
- The pure planning logic (pick future dates, assign slots, compute triggers, detect misses) lives in a plain Kotlin `AlertPlanner` object with JUnit tests (`testImplementation("junit:junit:4.13.2")`).

### Fire-time route (`AdhanAlarmReceiver`)

The steps run in order. Steps 1 and 2 each end the route with exactly one record; otherwise step 3 records `firedAt` and steps 4–5 deliver.

1. Notifications disabled, or the channel this route would use (including `prayer_adhan_channel` for playback) has importance NONE: record `skipped` (the reliability status shows why), post nothing, end.
2. Late by more than 30 min:
   - If the clock changed after arming, record `skipped` and end. Detection does not depend on broadcast order: drift = (now − `armedAt`) − (`elapsedRealtime` − `armedElapsed`), and |drift| > 2 min means the wall clock moved. Legacy extras have neither `armedAt` nor `armedElapsed`; they skip the clock check.
   - Else, if `nextAt` has not come yet: record `late` first, then post the **late notification** (silent channel `prayer_alert_silent_v2`, id 210, native strings in Appendix A, localized through `localizedContext(localeCode)` like today's adhan text; tapping it or its «إصلاح» action opens the app like any adhan notification, and the app's missed/late sheet then leads to the fix, so no native deep link is needed; a posting failure never skips the record). Do not play, end.
   - Else: record `missed`, post nothing, end.
3. Record `firedAt` for the trigger.
4. `sound == adhan` and (`ringInSilent` or `isAudibleNow()`): start `AdhanPlaybackService`. If the start throws (`ForegroundServiceStartNotAllowedException` or any other exception), go to step 5.
   - Usage `USAGE_ALARM` when `ringInSilent`, else `USAGE_NOTIFICATION_EVENT`.
   - The clip is `fajr_adhan` for Fajr, else `normal_adhan`.
5. Otherwise post a plain adhan-text notification on the channel for the sound. The OS applies ringer, vibrate and DND itself.
   - adhan (silenced now) or tone → `prayer_alert_tone_v2` (HIGH, default sound).
   - vibrate → `prayer_alert_vibrate_v2` (HIGH, no sound, vibration).
   - silent → `prayer_alert_silent_v2` (DEFAULT, no sound, no vibration).

After any step ends the route, call `rearmFromSnapshot` asynchronously (`goAsync`). `isAudibleNow()` = ringer mode NORMAL && interruption filter ALL (or UNKNOWN) && notification stream volume > 0.

### Reminders

The channel follows `reminderSound`:
- tone → `prayer_reminder_tone_v2` (DEFAULT, default sound)
- vibrate → `prayer_reminder_channel` (shipped in v1: DEFAULT importance, no sound, vibration)
- silent → `prayer_reminder_silent_v2` (LOW)

The reminder sets `setTimeoutAfter(prayerTime − now)` (API 26+), and the receiver skips it when the prayer time has already passed.

### Miss detection

- Records and the armed log are keyed by date + prayer (`2026-11-15/asr`), not by epoch ms.
- **Armed log:** every `armDays` run writes, for each trigger it arms, `key → {triggerAt, armedAt}`. Entries for future triggers are rewritten on every run (so a disabled prayer or a changed time replaces them); entries whose trigger has passed are kept until pruned.
- Every trigger that reaches the receiver leaves exactly one record: `firedAt`, `late`, `skipped` or `missed`.
- `getReliabilityStatus` reports as `missed` each armed-log entry whose `armedAt` is before its `triggerAt`, whose `triggerAt` is in (max(`lastCheckedAt`, `lastBootHandledAt`, `lastClockChangeAt`, now − 24 h), now − 35 min], and that has **no record of any kind**, plus the recorded `missed` records with `triggerAt` > `lastCheckedAt`. `late` lists the `late` records with `triggerAt` > `lastCheckedAt`. The 35 min end is the 30 min late threshold plus a margin: an alarm that is only deferred still gets its own record (normal or late) before it can be judged missed. A trigger that never reached the receiver (process force-stopped, autostart blocked) has no record, which is exactly the case to report. `skipped` triggers are never misses.
- This excludes, by construction: a new install's passed prayers (never armed), a prayer re-enabled after its time, a time shift from a method or location change (the old entry was fired or replaced while still future), v1-era triggers (`lastCheckedAt` set on upgrade), and anything before a clock or timezone change.
- The 24 h reach covers a user who opens the app the morning after a killed evening. The armed log is independent of the snapshot, so the order of sync and status read doesn't matter.
- Records and armed-log entries older than 48 h are pruned on every write.
- Triggers before `lastBootHandledAt` are never reported: a reboot wipes alarms, and on encrypted phones BOOT_COMPLETED only arrives after the first unlock, so a trigger between a night-time reboot and the morning unlock is lost without the app being at fault. Direct-boot support is out of scope (§13).
- `ackMissed(upTo)` sets `lastCheckedAt` = max(current, upTo), where `upTo` is the newest trigger time the user was shown (the newest `at` across the `missed` and `late` items the sheet displayed). The max keeps it monotonic, so a clock moved back never lowers it, and a trigger not yet judged at ack time, or one that becomes reportable between the status read and the ack, is still reported later. The missed sheet acks when it shows, so each miss or late delivery is surfaced once; afterwards the status line no longer reflects it and the reliability page carries the fix.
- The other fields come from `NotificationManagerCompat.areNotificationsEnabled`, `AlarmManager.canScheduleExactAlarms` (API 31+, else true), `PowerManager.isIgnoringBatteryOptimizations`, and `Build.MANUFACTURER`/`BRAND` lower-cased ∈ {xiaomi, redmi, poco}. On API 31+ the value is always `canScheduleExactAlarms()`, which reads true on API 33+ while `USE_EXACT_ALARM` is declared.

### Settings intents

`openSystemSettings(target)`: each target tries its intents in order, catches `ActivityNotFoundException` and `SecurityException`, and ends at the app details screen (`ACTION_APPLICATION_DETAILS_SETTINGS`).
- `notifications`: `ACTION_APP_NOTIFICATION_SETTINGS`
- `exactAlarm`: `ACTION_REQUEST_SCHEDULE_EXACT_ALARM`
- `battery`: `ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS`
- `autostart`: `com.miui.securitycenter/com.miui.permcenter.autostart.AutoStartManagementActivity` → `com.miui.securitycenter/com.miui.permcenter.permissions.PermissionsEditorActivity` (extra `extra_pkgname`) → app details
- `xiaomiBattery`: `com.miui.powerkeeper/com.miui.powerkeeper.ui.HiddenAppsConfigActivity` (extras `package_name`, `package_label`) → `battery` → app details
- The manifest adds `<queries>` for `com.miui.securitycenter` and `com.miui.powerkeeper`.

### Preview

`previewSound(sound, prayer)` / `stopPreview()` play one `MediaPlayer` (adhan clip or default notification ringtone) on `USAGE_MEDIA`. `vibrate` and `silent` have no preview (no ▶ on those rows), so no new permission is needed. Starting a new preview stops the old one.

When a preview ends without an explicit `stopPreview()` (the clip completes, `MediaPlayer` reports an error, or `play` throws), native calls `previewEnded` with `{sound: 'adhan'|'tone'}` back on the same channel, on the main thread. Dart's data source owns the channel's only method-call handler and exposes the events as a stream; the repository maps them to `Stream<PreviewSound>` (empty on iOS), `WatchPreviewEnded` carries them to `SoundPreviewCubit`, which clears its state when the ended sound is the one playing.

### Strip

- Window JSON gains `style`: expanded, countdown, highlightDay/Night (ARGB), highlightTextDay (ARGB, the day colour for text-only highlights, Appendix B), pillTextDay/Night, backgroundDay/Night (ARGB or absent), and shape (`none`/`rounded`/`pill`/`outline`, an enum on both sides; an unknown value reads as `rounded`).
- Each cell gains `nextLabel`, a ready-made header `{prayer} بعد` built in Dart (`strip_nextIn`), and `timeFull` (the expanded row's time: with ص/م or AM/PM in 12h, the same as `time` in 24h; native falls back to `time` when it is absent). The window carries `nextTag` («التالية», `strip_next`) once at the top level; native still reads an older per-day `nextTag`. Strip text comes only from Dart and is built for the app language (`PendingS.forLanguage(localeCode)`, the same language as the cells), never from the Intl default locale.
- **Compact** layout `prayer_strip_collapsed.xml`: 5 cells, name (13 sp) over time (11 sp), no vertical padding or margin, a root with id `strip_root`, `includeFontPadding=false`. With Cairo's line box (ascent 1303 + descent 571 per 1000 em = 1.874 em) a cell is 44.98 dp at 1× font scale, inside the ~48 dp collapsed budget on Android 12+ (58.5 dp at 1.3×, where the system clips). Time strings are built in Dart: they follow `isFormat12Hours` (12h drops ص/م to fit the cell) and use Arabic-Indic digits when the app language is Arabic. Only the chronometer's countdown digits are drawn by the system in the phone's language, which `strip_countdownNote` says.
- **Expanded** layout `prayer_strip_expanded.xml`: a date line (weekday + Hijri, already in the payload; 13 sp, 4 dp below) and 5 rows (min 28 dp, no vertical padding) of name (14 sp) and `timeFull` (15 sp), with an «التالية» tag view on the next row. That is 168.9 dp at 1× and 218.4 dp at 1.3×, inside the 252 dp expanded budget. Layouts use only `LinearLayout` and `TextView`, which RemoteViews can inflate.
- Highlight: the shape drawable (rounded 8 dp / pill / outline 1.5 dp stroke) on the next cell is tinted with the day or night colour on API 31+, or gets a flat fill below that. Shape `none` colours the text only. Pill text is white on day fills and #121413 on night fills; a text-only highlight (`none`, or `outline` on API 31+) uses `highlightTextDay` by day and the night highlight by night.
- Passed and upcoming: upcoming names and times use the primary strip text; passed names and times use `strip_text_passed`, about 50% of primary (#6F000000 day, #7FF8F9F8 night). Both come from `values`/`values-night` resources through the `strip_cell_text` selector (`setEnabled(false)` marks a passed cell), so they follow a dark-mode switch without a re-render. The exception is below API 31 with a background fill: the fill is frozen at render, so cell text is resolved with the same night mode at render too, keeping text and fill in step until the next render.
- Day and night: on API 31+ every custom colour (next text, highlight tint, background tint, the date line over a fill) is sent as a day/night pair (`setColorInt`, the two-`ColorStateList` `setColorStateList`), so the system recolours on a dark-mode switch without a re-render. Below API 31 custom colours are resolved with the night mode at render time and corrected by the next render.
- Background: tints `strip_root` (API 31+, flat fill below). With a day fill, muted text (the date line) uses about 66% black; a night fill keeps the night muted colour.
- Countdown: `setWhen(nextPrayerMs) + setUsesChronometer + setChronometerCountDown + setShowWhen`, and `setSubText` with that cell's `nextLabel`. On Android 12+ the system shows the countdown in the notification header, which may appear only when the strip is expanded; this needs device verification.
- Expanded off: no big content view.
- After Isha the strip shows tomorrow's day with Fajr next, when the window has it. Otherwise it highlights nothing.
- A swiped strip is not re-posted immediately. It returns at the next strip alarm (next prayer or 00:01) or app open.
- Dart sends the strip the same cached range as the adhans (up to 30 days), not 7.
- A stored window that no longer parses, or a render that throws, cancels the strip notification and its alarms instead of leaving a stale strip; the next app open re-sends it.

### Housekeeping

- The manifest registers `AdhanHealReceiver` with `exported="false"`.
- `res/raw/keep.xml` with `tools:keep="@raw/*"`.
- The Dart `init()` deletes `prayer_fajr_channel` and `prayer_standard_channel` and stops creating them.
- `android:label="@string/app_name"`, with values «Al-Furqan» and values-ar «الفرقان».

## 8. Dart scheduling and presentation (G2, G4, G6, G9)

- `NotificationsRepository.scheduleDailyAdhans` and `schedulePrayerReminders` take `Map<PrayerName, PrayerAlert>` instead of the two maps. `SyncDailyAdhans` keeps its shape with `alerts`. Reminders for disabled prayers are never sent.
- New repository calls (with use cases):
  - `getReliabilityStatus()`
  - `ackMissedAlerts(upTo: DateTime)` (the newest `at` among the missed and late items shown)
  - `openSystemSettings(SystemSettingsTarget)`
  - `previewSound(PrayerSound|ReminderSound, PrayerName)` / `stopPreview()`
  - `previewEnded()`: a `Stream<PreviewSound>` of previews that ended on their own (native → Dart)
- On iOS each call returns `Right`: `getReliabilityStatus` gives `notificationsEnabled` from the plugin's permission check, `exactAlarmsAllowed` and `batteryUnrestricted` true, `isXiaomi` false, `scheduledUntil` the last scheduled iOS adhan and no misses; the other calls are no-ops. No `Failure` reaches the UI for an unsupported call.
- Scheduling moves out of HomePage's listeners into `AlertsSyncCubit` (notifications feature, factory, created in HomePage's `MultiBlocProvider`). It owns the debounce timer (cancelled in `close()`), the day collection and the calls to `SyncDailyAdhans` and the strip use cases, and it is their only caller. HomePage's listeners only call `requestSync()`, on:
  - the prayer-times context loading (location and month timings ready)
  - precache completed
  - a settings change, with `listenWhen` limited to `prayerAlerts`, the strip fields, `isArabic`, `isFormat12Hours`, palette (the strip's `app` highlight uses the palette primary), method and school
  - app resume
- `ReliabilityCubit` (notifications feature, factory) is provided by the `NotificationsSettingsPage` and `ReliabilityPage` routes and by `AlertsPromptGate`. It loads `getReliabilityStatus` on create, on app resume (`AppLifecycleListener`), which also covers returning from a system settings screen, and after a Xiaomi self-confirm. Status line rules, first match wins:
  1. No prayer alert enabled → `alerts_enabledCount(0)` («متوقف لكل الصلوات»).
  2. `!notificationsEnabled` → `alerts_status_off`.
  3. `channelBlocked`, or `!exactAlarmsAllowed`, or `missed` or `late` not empty, or `scheduledUntil` before now, or (Android) `scheduledUntil` null, or on Xiaomi `!batteryUnrestricted` → `alerts_status_attention`. The Xiaomi self-confirm flags do not affect the line (the app cannot read those settings, so they would only nag); a detected miss does.
  4. `scheduledUntil` set → `alerts_status_ok` with that date; else (iOS before the first schedule) `alerts_status_okNoDate`.
- Battery optimisation on non-Xiaomi phones shows on the reliability page but does not flip the line while `usesAlarmClock` is true, because `setAlarmClock` is exempt from Doze there. When it is false, rule 3 applies `!batteryUnrestricted` on every phone.
- The Home countdown skips sunrise as "next". Layout unchanged.

### UI

Copy is in Appendix A and states in Appendix C.

- `SettingsPage`: one unconditional row «الأذان والتذكيرات» with the subtitle «مفعّل لـ٤ صلوات» (count of enabled). The pinned-strip switch and the second card are removed from Settings, and the strip moves to the notifications page. The palette grid stays.
- `NotificationsSettingsPage` (route unchanged) is rebuilt as a `ListView`:
  - Status line from `ReliabilityCubit` (rules above), which opens `ReliabilityPage`.
  - «الصلوات» card with 5 `PrayerAlertTile`s.
  - The one-line silent-mode note (`alerts_silentTruth`; `alerts_iosTruth` on iOS).
  - Strip row (Android only).
  - «مواقيت الصلاة», where method and Asr open option sheets, plus the auto-method reason line.
  - `TestAdhanButton`: when notifications are off or exact alarms are denied, the snackbar says nothing will play (`alerts_testBlocked`); otherwise `alerts_testCaption`.
- `PrayerAlertSheet`:
  - Modal bottom sheet, live commit.
  - Sound rows open `showAppOptionSheet`.
  - The silent switch is Android-only and disabled unless the sound is adhan.
  - The reminder group is disabled with its reason while the alert is off.
  - `ReminderPicker`: a local draft, slider 1–60 (59 divisions) committed on `onChangeEnd`, chips 5/10/15/30, ICU-plural text and `alerts_sheet_reminderArrives`.
- Sound picker: `showAppOptionSheet` with `RadioGroup` + `RadioListTile` rows and an optional trailing slot per row; ▶ is that slot, a separate 48 px `IconButton`, on the adhan and tone rows on Android only (iOS has no preview). Previews come from `SoundPreviewCubit` (factory), which stops on close.
- `PrayerStripSettingsPage` (new route `/prayerStrip`):
  - Live Flutter preview with a «مطويّ/موسّع» toggle (`AppSegmentedSelector`).
  - Switches for show, expanded and countdown (with the digits note).
  - Option rows for highlight, background and shape, plus the note.
- `ReliabilityPage` (new route `/alertsReliability`; on iOS only the notifications row and the test button show):
  - Rows for notifications (blocked when notifications are off or `channelBlocked`), exact alarms and battery, each with its state and an action button.
  - A Xiaomi section with three rows: autostart and battery saver (each with «فتح الإعداد» and a self-confirm «تمّ»), and «قفل التطبيق في التطبيقات الأخيرة» (text only).
  - Each row's state is an `AppStatusBadge`: `rel_working` or `rel_needsAction`, with `rel_allowed`/`rel_blocked` (or the battery pair) as the row value. A confirmed Xiaomi row shows the badge `rel_done`.
  - «مجدولة حتى …» and the test button.
- Prompts: `AlertsPromptGate` wraps `HomeView`, provides a `ReliabilityCubit` and, after its first load, shows at most one modal sheet:
  - The upgrade sheet if `!alertsIntroSeen` and onboarding is complete, then marks it seen.
  - Else the missed sheet if `missed` or `late` is not empty (ack on show acknowledges both, up to the newest `at` among them). Its title is `missed_title` for a miss, else `late_title`, naming the most recent prayer. Its body is `missed_body` on Xiaomi and `missed_bodyGeneric` elsewhere. On Xiaomi, showing it clears `xiaomiAutostartConfirmed` and `xiaomiBatteryConfirmed` (MIUI can revert those settings, e.g. after an update), so the checklist asks again. Confirmed Xiaomi rows keep their «فتح الإعداد» action.
- Home's own widgets are unchanged.
- Onboarding: after the notification-permission step, insert «تنبيهات الصلاة»: the choice applies to all 5 prayers (adhan → `enabled` + `sound = adhan`; tone → `enabled` + `sound = tone`; «بدون تنبيه» → `enabled = false`), and the reminder chips none/5/10/15/30 set `reminderEnabled` and `reminderMinutes`. On Xiaomi only, add the reliability step next; it reuses the Xiaomi checklist widget from `ReliabilityPage`. Completion sets `alertsIntroSeen`.
- New shared widgets: `core/widgets/design/app_settings_tile.dart` (replaces the private `_ReadingSettingsRow` and `_NotificationRow` in settings_page.dart) and `app_option_sheet.dart` (`showAppOptionSheet<T>`; no generic pick-one sheet exists today), registered in `core-widgets.md`.
- New presentation utils: the enum localizations. Minute and count phrases come from the ICU plural keys `alerts_minutes` and `alerts_enabledCount`.

## 9. iOS (G7)

- Trim `fajr_adhan.caf` and `normal_adhan.caf` to 29 s with a 2 s fade-out, mono, IMA4 CAF: `afconvert` → WAV, a Python `wave` trim, then `afconvert` → CAF. Add both to the Runner Resources phase in `project.pbxproj`.
- `PrayerNotificationSchedulerImpl` gets `scheduleAlerts(days, alerts, localeCode)`:
  - Schedules per day and prayer, plus reminders.
  - Ids are day×10 + prayer for adhans (0–119) and 200 + day×10 + prayer for reminders (200–319). The test keeps 9999.
  - The day count is ⌊60 / requestsPerDay⌋, at most 12; zero requests per day schedules nothing.
  - Titles and bodies are in Arabic or English by locale.
  - Adhan sounds: adhan → the bundled CAF; tone → default sound; vibrate or silent → no sound. Reminder sounds: tone → default sound; vibrate or silent → no sound. iOS cannot vibrate without sound, so both pickers omit «اهتزاز فقط» on iOS and a stored `vibrate` behaves as silent.
- `scheduleAlerts` starts with `cancelAll`, which clears the v2 id ranges and v1's ids (10–15, 20–25), so no v1 request survives the upgrade. The legacy single-day path is removed.
- Dart stores the last scheduled adhan time after each iOS schedule; it is iOS's `scheduledUntil`.

## 10. Strings and generated code (declared exception)

The owner's rules forbid running `intl_utils` by hand and editing `lib/generated/`. No IDE was available when this was built, so new `S` getters cannot exist yet. The decision:
- Every new string goes into both ARBs under its final key (Appendix A).
- New code reads those strings through `PendingS.of(context)`, a hand-written ar/en lookup in `lib/core/localization/pending_s.dart`. Its getter and method names are identical to the ARB keys, and the plurals are in pure Dart and unit-tested. Language comes from `Localizations.localeOf(context)`, which registers an inherited dependency on `Localizations`, so widgets rebuild on a locale change exactly as with `S.of`.
- Code without a context (a cubit) uses `PendingS.current`, which reads `Intl.getCurrentLocale()` (set by `S.load`), mirroring `S.current`. Code that must match a language it already holds (the strip's `localeCode`) uses `PendingS.forLanguage(languageCode)` instead, so its strings never mix with the cells' language while `Intl`'s locale lags a language switch.
- About 120 strings exist twice until the follow-up. A unit test parses both ARBs and checks that every non-plural `PendingS` getter and method matches word for word per locale, so those can't drift; the two plurals are spot-checked against expected outputs.
- Owner follow-up, listed in the PR: save the ARBs in the IDE, replace `PendingS.of(context)`/`PendingS.current` with `S.of(context)`/`S.current` (a mechanical rename), and delete `pending_s.dart`.
- This is a declared exception to `localization.md`. Reviews must not "fix" it by running `intl_utils` or editing `lib/generated`.

## 11. Comfort theme (G8)

- `AppPaletteX` in `app_palette.dart` takes the Appendix B values for the neutral palettes.
- New getters: `onPrimary`, `primaryInk`, `primaryTint`, `error` and `onError`. They land early, with Task 8, returning today's colours (`onPrimary` #F5F5F5, `primaryInk` = `primary` in light and `secondary` in dark, `primaryTint` = primary @ 12% / secondary @ 22%, `error` = `AppColors.error`, `onError` = today's `colorScheme.onError` per palette), so UI tasks compile against them. The theme commit changes only their values and the palette values, so reverting it keeps the build green.
- A unit test computes WCAG contrast for every palette: 4.5:1 or more for `onSurface` and `onSurfaceVar` on `bg` and on `surface`, and 3:1 for `primaryInk` on `surface`. The neutral values pass in tokens.md's measurements; the test re-checks them in the repo.
- The slate palettes take the proposed values only if that test passes for them. Otherwise slate keeps today's `bg`, `surface`, `onSurface` and `onSurfaceVar`, while the new getters still take the slate columns of Appendix B.
- `AppColors.error` callers in files this feature already touches move to the palette getter; other callers stay.
- `SwitchThemeData`: in dark palettes the selected track is `primaryInk` and the thumb is `bg`.
- The theme value change is the last commit on the branch so it can be reverted on its own.

## 12. Removed

- `AdhanAudioSettings` and the `audio` param of `SyncDailyAdhansParams` (the clip is resolved natively from `sound`).
- `PerPrayerAdhanTile`, `ReminderOffsetDropdown`, `SettingSwitch` (dead), and the `_PickerRow` inside `notifications_settings_page.dart` (the ahadith `chapter_picker_sheet.dart` copy stays).
- `Settings.validReminderMinutes`, `adhanEnabledByPrayer`, `reminderMinutesByPrayer` (migrated).
- `AdhanScheduler.armToday`, `PrayerReminderScheduler.armToday` (legacy).
- `FeatureFlags.pinnedPrayerStripUi` (its only use goes away).
- The Dart legacy fajr/standard channels.

## 13. Risks and mitigations

Failure modes are in §7 (causes and mechanisms) and §16; this section collects them with the policy and security points.

| Risk | Mitigation |
|---|---|
| MIUI force-stop kills every alarm; no code survives it | Miss detection, the missed sheet and the Xiaomi checklist tell the user; the owner verifies with the §15 triage |
| Play policy: `USE_EXACT_ALARM` (already in the manifest) is restricted to alarm and calendar apps; a public release may be asked to justify it. While it stays, exact alarms are always allowed on API 33+, so the exact-alarm row and `alerts_testBlocked` matter only below 33 or if it is removed | `SCHEDULE_EXACT_ALARM` is also declared and checked through `canScheduleExactAlarms`; `setAlarmClock` falls back to `setAndAllowWhileIdle` on `SecurityException`. Dropping `USE_EXACT_ALARM` before a public release is listed in the PR as an owner decision; doing so would need an exact-alarm onboarding step and handling of `ACTION_SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED` (follow-up) |
| Public release before device proof | Release gate: public release waits on the owner running the §15 triage on the Redmi and seeing alarms survive (step 6) |
| iOS alerts stop silently after the static schedule ends | `scheduledUntil` on iOS is the last scheduled adhan (stored by Dart), so the status line turns to attention once it passes; every app open extends it |
| Fire records grow in SharedPreferences | Records and the armed log older than 48 h are pruned on every write |
| `setAlarmClock` shows an alarm icon and a "next alarm" on the lock screen | One constant (`USE_ALARM_CLOCK`) turns it off; listed as an owner decision |
| Receivers for `BOOT_COMPLETED`, `MY_PACKAGE_REPLACED`, `TIME_SET`, `TIMEZONE_CHANGED` are entry points other apps could poke | `AdhanBootReceiver` acts only on those protected system actions (other actions are ignored), takes no data from the intent, and only re-arms from the app's own snapshot. The heal alarm goes to `AdhanHealReceiver` and the alarm receivers, all `exported=false` |
| A reboot at night loses alarms until the first unlock (no direct-boot support) | Not fixed in v2; those triggers are excluded from miss detection so the app does not blame the user. Direct boot (device-protected storage, `LOCKED_BOOT_COMPLETED`) is a follow-up |
| The user blocks one notification channel | `channelBlocked` turns the status line to attention; the notifications row reads blocked and opens the app's notification settings, which list the channels; the receiver records `skipped` |
| Launching MIUI activities by component name and `<queries>` for MIUI packages | Explicit intents only, no data passed beyond our package name; every launch catches `ActivityNotFoundException`/`SecurityException` and falls back to app details. `<queries>` grants visibility of two named packages, nothing else |
| Starting the playback FGS from a receiver can be refused (Android 12+ background-start limits) | Exact and alarm-clock alarms are exempt; any start exception falls through to a channel notification |
| Upgrade: v1 alarms and snapshot lack `sound` | Legacy parsing keeps v1 behaviour until the first sync (§7); JUnit covers it |
| `PendingS` duplicates about 120 strings | Parity test; owner follow-up in the PR (§10) |
| Not proven on a device | Unit tests, debug builds for Android and iOS, and the §15 triage for the owner |
| iOS pending-request cap of 64 | Day count is ⌊60 / requests per day⌋, leaving room for the test |

The feature keeps all data on the device: prayer times, settings and fire records. Nothing new is sent off the device.

## 14. Left to the builder

- Exact widget decomposition inside the named files, and test file names.
- Debounce duration (200–500 ms) inside `AlertsSyncCubit`.
- The exact Kotlin split between `AlertPlanner` and the schedulers, as long as the planner stays pure and tested.
- Whether the strip preview reuses Dart's `PrayerStripState`.

## 15. Verification

- `fvm dart format`, `fvm flutter analyze --no-fatal-infos`, and `fvm flutter test test/features test/core test/config test/quran_package` clean versus `main`. **Never run bare `fvm flutter test`**: `test/tools/generate_mushaf_assets_test.dart` is not skip-guarded and rewrites `assets/mushaf/**`. Check `git status assets/` after every run.
- `cd android && ./gradlew :app:testDebugUnitTest` for `AlertPlanner` and `PrayerStripTest` (payload parsing, colour selection, layout safety and height budgets).
- `fvm flutter build apk --debug` compiles the Kotlin.
- iOS: `plutil -lint ios/Runner.xcodeproj/project.pbxproj`, then `fvm flutter build ios --no-codesign --debug`, then confirm that both `.caf` files are in `build/ios/iphoneos/Runner.app`.
- At authoring time no device was attached (`adb` absent), so the native work is compiled and unit-tested, not proven on the Redmi. The PR carries this adb triage for the owner (`P=com.example.quran_app`):
  1. Right after opening the app: `adb shell dumpsys alarm | grep -c $P` (> 0), `adb shell dumpsys package $P | grep -o 'stopped=[a-z]*'` (`stopped=false`).
  2. `adb shell am get-standby-bucket $P` (45 = restricted) and `adb shell dumpsys deviceidle whitelist | grep $P` (missing = not battery-exempt).
  3. Swipe the app from recents and repeat step 1. `stopped=true` with 0 alarms confirms cause 1 (force-stop).
  4. Run the test adhan, lock the screen, and watch `adb logcat | grep -iE "$P|Adhan"` for the receiver line.
  5. After a miss: `adb shell dumpsys activity exit-info $P | head -20` shows why the process died.
  6. Turn on autostart, set «بدون قيود», lock the app in recents, and repeat step 3. Alarms that survive confirm the fix path.
- Strip on a device (Android 12+ and one below 12): the compact strip is not clipped at 1× and 1.3× font scale; the expanded strip fits; the header countdown shows (note whether it appears only when expanded) with its digits in the phone's language; each shape and background in light and dark, and a dark-mode switch recolours the strip on Android 12+ without reopening the app; after Isha the strip shows tomorrow with Fajr and the countdown targets tomorrow's Fajr.

## 16. Stress-test log

From the stress-test pass of `.claude/skills/feature-flow` (step 2), self-answered; the owner accepted all defaults on 2026-11-15.

| Question | Answer |
|---|---|
| A user turns the alert off, then on again. Is the reminder restored? | Yes. `reminderEnabled` and minutes are kept and only take effect while `enabled`. |
| Sound = tone and `ringInSilent` was on before the change? | The switch shows disabled and is ignored at fire time. The value is kept. |
| The phone is on silent and the prayer uses adhan without the override? | A plain notification goes on the tone channel, so the OS mutes it or vibrates. No FGS, no audio. |
| Two adhans late at once after a clock jump? | A recorded clock change after arming → dropped silently and recorded `skipped`, so it is not reported as missed. A real deferral → one late notification id (210), only for a prayer whose next prayer hasn't started. |
| The snapshot runs out (app untouched for more than a month)? | Alarms stop. Nothing counts as missed beyond the snapshot; the status line shows `alerts_status_attention` (rule 3) and the reliability page «مجدولة حتى …» in the past. Native cannot compute times (§2 non-goal). |
| The strip day changes while the phone is in another mode (light/dark)? | On API 31+ colours are sent as day/night pairs and plain text comes from night-qualified resources, so the system recolours at once. Below API 31 custom colours are chosen at render time and the next prayer, midnight or resume render corrects them. Accepted. |
| Onboarding skipped with «لاحقًا» on the alerts step? | Defaults stay (adhan on, no reminder). `alertsIntroSeen` is set true at completion either way. |
| An upgrader on a non-Xiaomi phone? | The upgrade sheet shows without the Xiaomi line. «مراجعة الإعدادات» opens `/notifications`. |
| The user denies notifications? | The status line shows `alerts_status_off` and the reliability row offers «فتح الإعداد» (app notification settings). |
| iOS: 5 prayers and 5 reminders a day? | 10 requests a day → 6 days within 60 (4 left for the test and slack). |
| Reminder 1 minute before, while the adhan fires a minute later? | Allowed. The adhan receiver cancels the visible reminder (today's behaviour). |
| The app was killed in the evening and opened next morning? | Isha's trigger has no record and is within 24 h, so the missed sheet names Isha. |
| Do notification ids collide with request codes? | No. PendingIntent request codes and notification ids are separate namespaces. Notification ids: strip 100, adhan playback 200 (one at a time, the newest replaces), adhan text 201 (kept apart so a text alert never replaces a running playback notification), late 210, reminders 2300 + prayerIndex. |
| Does the slider write on every step? | No. It keeps a local draft and commits once on `onChangeEnd`. The chips commit immediately. |

## 17. Domain terms

- **Prayer alert**: what happens for one prayer: the prayer-time alert (on/off + sound + ring in silent mode) and its reminder. Not "adhan settings": an alert can be a tone or silent.
- **Reminder**: a notification N minutes before a prayer. It exists only while that prayer's alert is on.
- **Ring in silent mode**: route the adhan through the alarm stream. Android only.
- **Horizon / window**: the dates armed natively (7). The **snapshot** is every cached day Dart sent (up to 30). The window rolls inside the snapshot.
- **Late alert**: a prayer-time alarm delivered more than 30 min late, with no clock change and before the next prayer. It produces the silent late notification.
- **Missed alert**: an armed-log entry, armed before its time, with no record of any kind after its time (within 24 h, excluding time before the last boot or clock change), or one recorded `missed` because it arrived after the next prayer had started.
- **Strip style**: the user's strip knobs. The strip is the pinned notification, never called a "widget" in code.
- **Reliability status**: what the app can read about the OS (notifications, exact alarms, battery, OEM, horizon, misses).

## 18. Seams

Each seam is a plan task boundary.

1. **Strings seam**: ARB + `PendingS` (Task 1). Every later task depends on it.
2. **Alert model seam**: `PrayerAlert`/`StripStyle` entities + `SettingsModel` (de)serialisation + migration + cubit intents (Task 2). Pure Dart and fully testable. Everything above reads only this.
3. **Native contract seam**: the `quran_app/notifications` channel payloads (adhan `sound/ringInSilent`, reminder `reminderSound`, strip `style`, new reliability/settings/preview methods). Dart side: data source + repository + use cases (Task 3). Native side, by area:
   - 3a `AlertPlanner` + schedulers + receivers (Task 4)
   - 3b audio routes, channels and preview (Task 5)
   - 3c reliability and settings intents (Task 6)
   - 3d strip renderer and layouts (Task 9)
4. **Sync seam**: `AlertsSyncCubit` (§8) is the only caller of `SyncDailyAdhans` and the strip push; HomePage only calls `requestSync()`. The countdown fix and the always-fetch-next-month precache change sit with it (Task 7).
5. **UI seams**, each a page or sheet reading `SettingsCubit` slices and calling cubit intents:
   - shared tiles/sheets + Settings row + notifications page + prayer sheet + pickers, plus the new `AppPaletteX` getters with today's colours (Task 8)
   - strip settings page (Task 10)
   - reliability page + prompts + onboarding (Task 11)
6. **iOS seam**: `PrayerNotificationSchedulerImpl.scheduleAlerts` + bundled clips + pbxproj (Task 12).
7. **Theme seam**: `AppPaletteX` values only (Task 13, last commit).

## Appendix A. User-facing copy (ARB keys)

States: Appendix C. Visual layout: `docs/design-audit/prayer/settings/final-spec.md` §2–3 (local). Existing keys reused: `adhan_and_reminders`, `calculationMethod_*`, `asrSchool_*`, `playTestAdhan`, `onb_continue`, prayer names. Native strings: only the late notification text and its «إصلاح»/"Fix" action, channel names and the app label live in `android/app/src/main/res/values{,-ar}/strings.xml`; the late text resolves through `localizedContext(localeCode)`. Strip text comes from Dart.

| Key | Arabic | English |
|---|---|---|
| `alerts_status_ok` | التنبيهات تعمل، ومجدولة حتى {date} | Alerts are on, scheduled until {date} |
| `alerts_status_okNoDate` | التنبيهات تعمل | Alerts are on |
| `alerts_status_attention` | إعداد يحتاج إلى إجراء | A setting needs attention |
| `alerts_status_off` | الإشعارات غير مسموحة، فلن يصل الأذان | Notifications are off, so no adhan will arrive |
| `alerts_prayersSection` | الصلوات | Prayers |
| `alerts_silentTruth` | يتبع الصوت وضع الهاتف الصامت، إلا للصلوات المفعّل لها «يرن حتى في الوضع الصامت». | Sound follows your phone's silent mode, except for prayers set to ring in silent mode. |
| `alerts_iosTruth` | على iPhone يعمل مقطع قصير من الأذان، ويتبع زر الصامت. | On iPhone a short adhan clip plays and follows the mute switch. |
| `alerts_stripRow_title` | شريط أوقات الصلاة | Prayer times strip |
| `alerts_stripRow_on` | مفعّل | On |
| `alerts_stripRow_onExpanded` | مفعّل، عرض موسّع | On, expanded view |
| `alerts_stripRow_off` | متوقف | Off |
| `alerts_timesSection` | مواقيت الصلاة | Prayer times |
| `alerts_autoMethodReason` | تُختار الطريقة تلقائيًا حسب بلدك. | The method is chosen automatically from your country. |
| `alerts_testCaption` | يصل بعد ثوانٍ إذا كانت الإشعارات مسموحة. | Arrives in a few seconds if notifications are allowed. |
| `alerts_testBlocked` | لن يعمل الأذان: الإشعارات أو المنبهات الدقيقة غير مسموحة. | Nothing will play: notifications or exact alarms are off. |
| `alerts_summary_off` | متوقف | Off |
| `alerts_summary_ringsInSilent` | يرن في الوضع الصامت | rings in silent mode |
| `alerts_summary_reminder` | تذكير قبل {minutes} | reminder {minutes} before |
| `alerts_sound_adhan` | الأذان | Adhan |
| `alerts_sound_fajrAdhan` | أذان الفجر | Fajr adhan |
| `alerts_sound_adhanClip` | مقطع من الأذان | Adhan clip |
| `alerts_sound_fajrAdhanClip` | مقطع من أذان الفجر | Fajr adhan clip |
| `alerts_sound_tone` | نغمة الإشعار | Notification tone |
| `alerts_sound_vibrate` | اهتزاز فقط | Vibrate only |
| `alerts_sound_silent` | بدون صوت | Silent |
| `alerts_sheet_atTime` | عند وقت الصلاة | At prayer time |
| `alerts_sheet_alertSwitch` | تنبيه وقت الصلاة | Prayer-time alert |
| `alerts_sheet_sound` | الصوت | Sound |
| `alerts_sheet_ringInSilent` | يرن حتى في الوضع الصامت | Ring even in silent mode |
| `alerts_sheet_ringInSilentSub` | بصوت المنبّه، فقد يرن رغم «عدم الإزعاج»، في اجتماع أو في المسجد. | Uses alarm volume, so it may ring through Do Not Disturb, in a meeting or at the mosque. |
| `alerts_sheet_beforeTime` | التذكير قبل الصلاة | Reminder before prayer |
| `alerts_sheet_reminderSwitch` | تذكير قبل الصلاة | Remind me before |
| `alerts_sheet_reminderValue` | قبل {minutes} | {minutes} before |
| `alerts_sheet_reminderArrives` | يصلك {time} | Arrives at {time} |
| `alerts_sheet_reminderSound` | صوت التذكير | Reminder sound |
| `alerts_sheet_reminderDisabled` | يتوقف التذكير مع إيقاف تنبيه وقت الصلاة. | The reminder is off while the prayer-time alert is off. |
| `alerts_sheet_iosNote` | يعمل الصوت مقطعًا قصيرًا، ويتبع زر الصامت في الهاتف. | Plays a short clip and follows the phone's mute switch. |
| `alerts_picker_prayerSound` | صوت وقت الصلاة | Prayer-time sound |
| `alerts_picker_silentSub` | يظهر الإشعار دون صوت | The notification shows without sound |
| `alerts_picker_preview` | معاينة {sound} | Preview {sound} |
| `alerts_picker_stopPreview` | إيقاف المعاينة | Stop preview |
| `alerts_picker_previewing` | معاينة الآن | Previewing |
| `strip_title` | شريط أوقات الصلاة | Prayer times strip |
| `strip_show` | إظهار الشريط | Show the strip |
| `strip_expanded` | استخدام عرض موسّع | Use expanded view |
| `strip_countdown` | إظهار العدّاد | Show countdown |
| `strip_countdownNote` | أرقام العدّاد تتبع لغة الهاتف | Countdown digits follow the phone's language |
| `strip_highlight` | لون التمييز | Highlight colour |
| `strip_background` | لون الخلفية | Background colour |
| `strip_shape` | شكل التمييز | Highlight shape |
| `strip_note` | يلوّن مساحة الأوقات فقط، ويبقى رأس الإشعار بلون النظام. | Colours only the times area; the notification header keeps the system colour. |
| `strip_previewCollapsed` | مطويّ | Collapsed |
| `strip_previewExpanded` | موسّع | Expanded |
| `strip_next` | التالية | Next |
| `strip_nextIn` | {prayer} بعد | {prayer} in |
| `strip_color_app` | لون التطبيق | App colour |
| `strip_color_darkGreen` | أخضر داكن | Dark green |
| `strip_color_emerald` | زمردي | Emerald |
| `strip_color_blue` | أزرق | Blue |
| `strip_color_indigo` | نيلي | Indigo |
| `strip_color_maroon` | عنابي | Maroon |
| `strip_color_bronze` | برونزي | Bronze |
| `strip_bg_auto` | تلقائي حسب النظام | Automatic (system) |
| `strip_bg_mint` | نعناعي | Mint |
| `strip_bg_sand` | رملي | Sand |
| `strip_bg_sky` | سماوي | Sky |
| `strip_bg_rose` | وردي | Rose |
| `strip_shape_none` | بدون | None |
| `strip_shape_rounded` | مستطيل مستدير | Rounded rectangle |
| `strip_shape_pill` | كبسولة | Pill |
| `strip_shape_outline` | إطار | Outline |
| `rel_title` | حالة التنبيهات | Alert status |
| `rel_needsAction` | يحتاج إجراء | Needs action |
| `rel_working` | يعمل | Working |
| `rel_notifications` | الإشعارات | Notifications |
| `rel_exactAlarms` | المنبهات الدقيقة | Exact alarms |
| `rel_battery` | تحسين البطارية | Battery optimisation |
| `rel_allowed` | مسموحة | Allowed |
| `rel_blocked` | غير مسموحة | Not allowed |
| `rel_batteryRestricted` | مقيّد | Restricted |
| `rel_batteryUnrestricted` | بدون قيود | Unrestricted |
| `rel_batteryHint` | قد يؤخّر النظام الأذان أو يوقفه. يلزم اختيار «بدون قيود». | The system may delay or stop the adhan. Choose «Unrestricted». |
| `rel_openSettings` | فتح الإعداد | Open setting |
| `rel_xiaomiSection` | هواتف شاومي | Xiaomi phones |
| `rel_unverifiable` | لا يستطيع التطبيق قراءة هذا الإعداد، فيكفي تأكيده مرة واحدة. | The app can't read this setting; confirm it once. |
| `rel_autostart` | تفعيل التشغيل التلقائي | Turn on autostart |
| `rel_autostartSub` | للسماح بالتنبيه بعد إغلاق التطبيق. | Lets alerts arrive after the app is closed. |
| `rel_xiaomiBattery` | اختيار «بدون قيود» في توفير البطارية | Choose «No restrictions» in battery saver |
| `rel_xiaomiBatterySub` | لمنع تأخير الأذان. | Stops the adhan from being delayed. |
| `rel_lockApp` | قفل التطبيق في التطبيقات الأخيرة | Lock the app in recent apps |
| `rel_lockAppSub` | بسحب بطاقته إلى الأسفل حتى يظهر القفل، وتجنّب «مسح الكل» قبل ذلك. | Pull its card down until the lock shows, and avoid «Clear all» before that. |
| `rel_done` | تمّ | Done |
| `rel_scheduledUntil` | مجدولة حتى {date} | Scheduled until {date} |
| `rel_scheduledNone` | لا تنبيهات مجدولة بعد | Nothing scheduled yet |
| `rel_scheduledSub` | تمتد الجدولة عند كل فتح للتطبيق وبعد كل أذان. | Scheduling extends each time the app opens and after every adhan. |
| `rel_test` | اختبار الأذان | Test the adhan |
| `onb_alerts_title` | تنبيهات الصلاة | Prayer alerts |
| `onb_alerts_atTime` | عند وقت الصلاة | At prayer time |
| `onb_alerts_none` | بدون تنبيه | No alert |
| `onb_alerts_reminder` | تذكير قبل الصلاة | Reminder before prayer |
| `onb_alerts_reminderNone` | بدون | None |
| `onb_alerts_note` | الصوت يتبع وضع الهاتف الصامت، ويمكن ضبط كل صلاة لاحقًا من الإعدادات. | Sound follows silent mode; each prayer can be adjusted later in Settings. |
| `onb_later` | لاحقًا | Later |
| `onb_skip` | تخطٍّ | Skip |
| `onb_xiaomi_title` | حتى لا يتوقف الأذان على هواتف شاومي | Keep the adhan working on Xiaomi phones |
| `onb_xiaomi_lead` | يوقف نظام شاومي التطبيقات في الخلفية. ثلاث خطوات تُبقي الأذان في وقته. | Xiaomi's system stops apps in the background. Three steps keep the adhan on time. |
| `upg_title` | تحسينات في تنبيهات الصلاة | Prayer alerts improved |
| `upg_silent` | يتبع الأذان الآن وضع الهاتف الصامت. لتشغيله رغم الصامت: «يرن حتى في الوضع الصامت» لكل صلاة. | The adhan now follows silent mode. To ring anyway, turn on «Ring even in silent mode» for a prayer. |
| `upg_reminder` | تذكير قبل الصلاة من دقيقة إلى ٦٠ دقيقة، بصوت مستقل. | A reminder from 1 to 60 minutes before, with its own sound. |
| `upg_xiaomi` | على هواتف شاومي يلزم إعدادان حتى لا يتوقف الأذان. | On Xiaomi phones two settings keep the adhan from stopping. |
| `upg_review` | مراجعة الإعدادات | Review settings |
| `missed_title` | فاتك تنبيه {prayer} | You missed the {prayer} alert |
| `missed_body` | أوقف النظام التطبيق في الخلفية غالبًا. إعدادان على هاتفك يمنعان تكرار ذلك. | The system most likely stopped the app in the background. Two settings on your phone prevent this. |
| `missed_bodyGeneric` | قد يكون النظام أوقف التطبيق أو أخّره. صفحة حالة التنبيهات تبيّن ما يلزم تغييره. | The system may have stopped or delayed the app. Alert status shows what to change. |
| `late_title` | تأخّر تنبيه {prayer} | The {prayer} alert was late |
| `missed_fix` | إصلاح الآن | Fix now |
| `alerts_minutes` (plural) | {count, plural, =1{دقيقة واحدة} =2{دقيقتين} few{{count} دقائق} other{{count} دقيقة}} | {count, plural, =1{1 minute} other{{count} minutes}} |
| `alerts_enabledCount` (plural) | {count, plural, =0{متوقف لكل الصلوات} =1{مفعّل لصلاة واحدة} =2{مفعّل لصلاتين} few{مفعّل لـ{count} صلوات} other{مفعّل لـ{count} صلاة}} | {count, plural, =0{Off for all prayers} =1{On for 1 prayer} other{On for {count} prayers}} |

Native strings (`res/values/strings.xml` / `values-ar/strings.xml`; numbers formatted with the locale's digits, Arabic-Indic for Arabic):

| Resource | Arabic | English |
|---|---|---|
| `app_name` | الفرقان | Al-Furqan |
| `prayer_late_title` | حان وقت %1$s منذ %2$s | %1$s began %2$s ago |
| `prayer_late_minutes` (plurals) | one: دقيقة واحدة · two: دقيقتين · few: %d دقائق · many/other: %d دقيقة | one: %d minute · other: %d minutes |
| `prayer_late_body` | تأخّر التنبيه، وقد يكون السبب توفير البطارية. | The alert was late; battery saving may be the cause. |
| `prayer_late_fix` | إصلاح | Fix |
| `channel_alert_tone` | تنبيهات الصلاة | Prayer alerts |
| `channel_alert_vibrate` | تنبيهات الصلاة (اهتزاز) | Prayer alerts (vibrate) |
| `channel_alert_silent` | تنبيهات الصلاة (بدون صوت) | Prayer alerts (silent) |
| `channel_reminder_tone` | تذكيرات الصلاة | Prayer reminders |
| `channel_reminder_silent` | تذكيرات الصلاة (بدون صوت) | Prayer reminders (silent) |

`rel_batteryUnrestricted` "Unrestricted" and `rel_xiaomiBattery` "No restrictions" differ on purpose: each mirrors the label on its own OS screen (Android battery settings vs MIUI battery saver).

## Appendix B. Comfort theme values (from tokens.md "v2 comfort tokens")

| Field | neutralLight | neutralDark | slateLight (proposed) | slateDark (proposed) |
|---|---|---|---|---|
| `bg` | #EDEEEA | #121413 | #EBEEF2 | #121418 |
| `surface` | #DCE0DA | #202421 | #DBE1E8 | #1F242C |
| `onSurface` | #1B1F1D | #E4E6E3 | #1A1E24 | #E3E6EA |
| `onSurfaceVar` | #545A56 | #ADB2AE | #4C5563 | #ADB4BF |
| `primary` | #2E5244 (kept) | #2E5244 (kept, fill only) | #1C4558 (kept) | #1C4558 (kept, fill only) |
| `onPrimary` (new) | #F5F5F2 | #ECEEEB | #F3F5F7 | #ECEEF1 |
| `primaryInk` (new) | #2E5244 | #93BAA8 | #1C4558 | #8DB5CC |
| `primaryTint` (new) | primary @ 10% | #5C8070 (secondary) @ 24% | #1C4558 @ 10% | #4878A0 @ 24% |
| `error` (new) | #A33A35 | #E68A84 | #A33A35 | #E68A84 |
| `onError` (new) | #F5F5F2 | #121413 | #F5F5F2 | #121418 |

Dark switch: the selected track is `primaryInk` and the thumb is `bg`. Light keeps the primary track with an `onPrimary` thumb.

Strip swatches (day / night; night fills use #121413 text, day fills white text):

| Highlight | Day | Night |
|---|---|---|
| `app` | palette `primary` | Appendix B dark `primaryInk` (#93BAA8 neutral, #8DB5CC slate) |
| `darkGreen` | #4A7C6A | #8FC4AE |
| `emerald` | #1E7A57 | #7FD1AE |
| `blue` | #2F5F98 | #8EBBE3 |
| `indigo` | #4B4FA6 | #A9ABEB |
| `maroon` | #9A3B3B | #E7A3A3 |
| `bronze` | #8A5A14 | #DDB77A |

Text-only day highlights (`none`, or `outline` on API 31+) need 4.5:1 on mint, sand, sky, rose, a light shade (#F2F2F2) and a tinted shade (#DDE3EA). Two swatches miss it as text (darkGreen 3.71–4.28:1, emerald 4.09–4.72:1), so they get a darker text variant, sent as `highlightTextDay`; the others keep their day colour (lowest: bronze 4.57:1, blue 5.06:1). Night swatches are 6.45:1 or more on every night fill and #1F1F1F.

| Highlight | Day text variant | Lowest contrast |
|---|---|---|
| `darkGreen text` | #406C5C | 4.62:1 (tinted shade) |
| `emerald text` | #1C7151 | 4.60:1 (tinted shade) |

| Background | Day | Night |
|---|---|---|
| `auto` | none (system) | none (system) |
| `mint` | #E3EFEA | #16302A |
| `sand` | #F3ECDD | #2E2A20 |
| `sky` | #E3ECF5 | #1B2735 |
| `rose` | #F4E4E6 | #33201F |

These live in one presentation mapping file, the only place outside `app_palette.dart` allowed hex literals.

## Appendix C. Screen states

Every state, with the shared rules: Arabic-Indic digits on every surface when the app is Arabic, rows ≥ 48 px, `SurfaceCard` groups of `AppSettingsTile` rows, full-row switches, no «جديد» badges, no warning glyphs, and no red on light.

| Screen | States |
|---|---|
| Settings row | One row; subtitle from `alerts_enabledCount` (0 → «متوقف لكل الصلوات»). |
| Notifications page | Loading: the status line is a skeleton (`Skeletonizer`) while `ReliabilityCubit` loads; the prayer card renders from settings at once. Status line: off / attention / ok-with-date / ok-without-date (§8 rules). Prayer rows: leading icon (speaker = adhan, bell = tone or vibrate, bell-off = off or silent), title, today's time trailing (hidden when today's timings aren't loaded), summary subtitle built from `alerts_summary_*` and the sound name, joined with «، » / ", ". iOS: no strip row and `alerts_iosTruth` replaces `alerts_silentTruth`. |
| Prayer sheet | Alert on: everything enabled. Alert off: sound row and silent switch at 38% opacity and inert, the reminder group inert with `alerts_sheet_reminderDisabled`. Sound not adhan: silent switch disabled, value kept. Reminder off: slider, chips and reminder sound inert. iOS: no silent switch, `alerts_sheet_iosNote` under the alert group, sound names use the «مقطع» variants. The «يصلك» time is hidden when today's timing isn't loaded. |
| Sound picker | One row per option, the current one selected. ▶ idle / playing (stop icon, indeterminate thin progress, `alerts_picker_previewing`). Closing the sheet stops the preview. iOS: no ▶, no vibrate row. |
| Strip settings | Strip off: the other rows stay visible but inert. Expanded off: the preview toggle is fixed to «مطويّ». Countdown off: no chronometer in the preview. Option sheets show a swatch dot for colours. |
| Reliability page | Each row shows its `AppStatusBadge` (`rel_working`/`rel_needsAction`), its value (`rel_allowed`/`rel_blocked` or the battery pair), and an action only when blocked. Xiaomi rows show the «تمّ» button until confirmed, then the badge `rel_done`. Scheduled: `rel_scheduledUntil` or `rel_scheduledNone`. |
| Onboarding alerts step | Defaults adhan + no reminder; reminder chips inert when «بدون تنبيه» is picked; «لاحقًا» keeps defaults. |
| Onboarding Xiaomi step | Three steps; «تخطٍّ» leaves the flags false. |
| Upgrade sheet | Two lines, plus the Xiaomi line on Xiaomi. «مراجعة الإعدادات» opens `/notifications` (on Xiaomi, `ReliabilityPage` first); «لاحقًا» closes. Shown once. |
| Missed sheet | `missed_title` names the most recent missed prayer; body per §8. «إصلاح الآن» opens `ReliabilityPage`; «لاحقًا» closes. Shown once per detected miss (ack on show). |
| Strip (system) | Compact: 5 cells, passed prayers at 60% text, the next cell highlighted. Expanded: date line + 5 rows, next row highlighted with the «التالية» tag. No next prayer in the window: nothing highlighted. |
| Late notification | Silent, title and body per §7, action «إصلاح». |

