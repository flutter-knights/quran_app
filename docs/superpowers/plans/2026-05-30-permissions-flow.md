# Permissions Flow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the premature notification prompt and orphaned adhan audio, and add a gentle, contextual re-grant flow for skipped location/notification permissions.

**Architecture:** `init()` becomes non-interactive (no OS prompts); the onboarding step is the only first-run notification prompt. A native runtime gate in `AdhanAlarmReceiver` prevents adhan audio when notifications are disabled. Home surfaces a location **recovery card** (driven by a typed failure) and a dismissible **notification hint** (driven by a live permission query), with a Settings banner as the durable path and a resume re-check that clears both.

**Tech Stack:** Flutter, flutter_bloc (Cubit), GetIt (`sl`), Geolocator, flutter_local_notifications, Kotlin (Android foreground service), intl_utils l10n.

**Spec:** `docs/superpowers/specs/2026-05-30-permissions-flow-design.md`

---

## File map

- `lib/core/notifications/prayer_notification_scheduler_impl.dart` — strip prompts from `init()`; add `areNotificationsEnabled()`.
- `lib/core/notifications/prayer_notification_scheduler.dart` — add `areNotificationsEnabled()` to abstraction.
- `lib/main.dart` — remove the location poll; call `init()` unconditionally.
- `android/app/src/main/kotlin/com/example/quran_app/AdhanAlarmReceiver.kt` — gate on `areNotificationsEnabled()`.
- `lib/features/home/presentation/cubit/daily_prayer_context_state.dart` — `DailyPrayerContextFailed` carries `Failure`.
- `lib/features/home/presentation/cubit/daily_prayer_context_cubit.dart` — emit the typed failure.
- `lib/features/home/presentation/pages/widgets/home_view.dart` — branch the failure state; render recovery card + notification hint.
- `lib/features/home/presentation/pages/widgets/location_recovery_card.dart` — **new** widget.
- `lib/features/home/presentation/pages/widgets/notification_hint.dart` — **new** widget.
- `lib/features/home/presentation/pages/home_page.dart` — resume re-fetch in `_StripResumeGuard`.
- `lib/features/home/presentation/pages/notifications_settings_page.dart` — disabled banner.
- `lib/features/settings/domain/entities/settings.dart` + `lib/features/settings/data/models/settings_model.dart` + `lib/features/settings/presentation/cubit/settings_cubit.dart` — `notificationHintDismissed` flag.
- `lib/l10n/*.arb` + `lib/generated/l10n.dart` (generated) — new strings.

**Note on the scheduling-time gate:** the spec mentions a "supporting" scheduling-time gate. The runtime gate in `AdhanAlarmReceiver` (Task 3) is strictly stronger — it also covers the case where notifications are disabled *after* alarms were scheduled — so a separate scheduling-time gate is omitted (YAGNI). Reschedule-on-grant is achieved by re-fetching the prayer context (Task 9), which re-runs the existing `SyncDailyAdhans` pipeline.

---

### Task 1: Make `init()` non-interactive

**Files:**
- Modify: `lib/core/notifications/prayer_notification_scheduler_impl.dart` (the `init()` body, around lines 157–171)

- [ ] **Step 1: Remove the two permission requests from `init()`**

In `init()`, delete these two lines (currently ~166–167):

```dart
    await androidPlugin?.requestExactAlarmsPermission();
    await androidPlugin?.requestNotificationsPermission();
```

Leave the rest of `init()` intact (timezone setup, `deleteNotificationChannel`, both `createNotificationChannel` calls, `_initialized = true`, the debugPrint). The `androidPlugin` local is still used by the channel calls, so keep it.

- [ ] **Step 2: Verify analyzer is clean**

Run: `flutter analyze lib/core/notifications/prayer_notification_scheduler_impl.dart`
Expected: "No issues found!" (no unused-variable warning for `androidPlugin`).

- [ ] **Step 3: Commit**

```bash
git add lib/core/notifications/prayer_notification_scheduler_impl.dart
git commit -m "fix(notifications): make scheduler init() non-interactive (no OS prompts)"
```

---

### Task 2: Stop gating `init()` on the location poll

**Files:**
- Modify: `lib/main.dart` (`_AppLoaderState._initAll`, lines 44–61)

- [ ] **Step 1: Replace the post-frame location poll with an unconditional init**

Replace the body of `_initAll` from `setState(() => _ready = true);` onward (lines 49–60) with:

```dart
    setState(() => _ready = true);

    // init() is non-interactive (timezone + channels only) — safe to run
    // unconditionally. It must NOT be gated on a location-permission poll:
    // a user who taps "Not now" on location leaves permission at `denied`,
    // which would spin a 300ms loop forever and never init the scheduler.
    try {
      await sl<PrayerNotificationScheduler>().init();
    } catch (e, st) {
      debugPrint('PrayerNotificationScheduler.init failed: $e\n$st');
    }
```

Remove the now-unused `geolocator` import if `flutter analyze` flags it (check first — it may still be used elsewhere in the file; it is not, so the import on line 4 `import 'package:geolocator/geolocator.dart';` should be deleted).

- [ ] **Step 2: Verify analyzer is clean**

Run: `flutter analyze lib/main.dart`
Expected: "No issues found!" (no unused `geolocator` import, no unused `WidgetsBinding`/`Geolocator` references).

- [ ] **Step 3: Commit**

```bash
git add lib/main.dart
git commit -m "fix(launch): run scheduler init() unconditionally, drop location poll"
```

---

### Task 3: Gate adhan playback on notification permission (native)

**Files:**
- Modify: `android/app/src/main/kotlin/com/example/quran_app/AdhanAlarmReceiver.kt`

- [ ] **Step 1: Add the enabled-check before starting the service**

`NotificationManagerCompat` is already imported. In `onReceive`, immediately **before** the block that builds `serviceIntent` and calls `context.startForegroundService(serviceIntent)` (currently ~lines 44–50), insert:

```kotlin
        // If POST_NOTIFICATIONS is not granted, the foreground-service
        // notification is suppressed by the OS but the MediaPlayer would still
        // play — adhan audio with no card and no Stop control. Gate here (before
        // startForegroundService) rather than inside the service, so we never
        // start-then-bail (which crashes with ForegroundServiceDidNotStartInTime).
        if (!NotificationManagerCompat.from(context).areNotificationsEnabled()) {
            Log.w(TAG, "onReceive: notifications disabled — skipping adhan for $prayer")
            return
        }
```

- [ ] **Step 2: Build the Android app to verify it compiles**

Run: `flutter build apk --debug`
Expected: BUILD SUCCESSFUL (Kotlin compiles; no unresolved references).

- [ ] **Step 3: Commit**

```bash
git add android/app/src/main/kotlin/com/example/quran_app/AdhanAlarmReceiver.kt
git commit -m "fix(adhan): skip playback when notifications are disabled"
```

---

### Task 4: Expose `areNotificationsEnabled()` on the scheduler

**Files:**
- Modify: `lib/core/notifications/prayer_notification_scheduler.dart`
- Modify: `lib/core/notifications/prayer_notification_scheduler_impl.dart`

- [ ] **Step 1: Add the method to the abstraction**

In `prayer_notification_scheduler.dart`, add to the abstract class (after `requestNotificationsPermission()`):

```dart
  /// Whether OS notifications are currently enabled for the app. Drives the
  /// Home notification hint and the resume re-check. Returns false if unknown.
  Future<bool> areNotificationsEnabled();
```

- [ ] **Step 2: Implement it**

In `prayer_notification_scheduler_impl.dart`, add (next to `requestNotificationsPermission`):

```dart
  @override
  Future<bool> areNotificationsEnabled() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      return await androidPlugin.areNotificationsEnabled() ?? false;
    }
    final iosPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    final granted =
        await iosPlugin?.checkPermissions().then((p) => p?.isAlertEnabled);
    return granted ?? false;
  }
```

- [ ] **Step 3: Verify analyzer is clean**

Run: `flutter analyze lib/core/notifications/`
Expected: "No issues found!". If `IOSFlutterLocalNotificationsPlugin.checkPermissions()` or `isAlertEnabled` is not available in the installed plugin version, fall back to `return androidPlugin != null ? ... : false;` and on iOS `return true;` — confirm the exact API against `flutter_local_notifications` in `pubspec.lock` before adjusting.

- [ ] **Step 4: Commit**

```bash
git add lib/core/notifications/prayer_notification_scheduler.dart lib/core/notifications/prayer_notification_scheduler_impl.dart
git commit -m "feat(notifications): add areNotificationsEnabled() to scheduler"
```

---

### Task 5: Add localized strings

**Files:**
- Modify: `lib/l10n/intl_en.arb` (or the English ARB in `lib/l10n/`)
- Modify: `lib/l10n/intl_ar.arb` (or the Arabic ARB)
- Regenerate: `lib/generated/l10n.dart`

- [ ] **Step 1: Add keys to the English ARB**

Find the existing `onb_*` keys to match formatting (each key has a paired `@key` metadata entry). Add:

```json
  "home_locationCard_title": "Prayer times need your location",
  "@home_locationCard_title": {},
  "home_locationCard_body": "We use it only to compute accurate prayer times.",
  "@home_locationCard_body": {},
  "home_locationCard_enable": "Enable location",
  "@home_locationCard_enable": {},
  "home_locationCard_openSettings": "Open settings",
  "@home_locationCard_openSettings": {},
  "home_notifHint_text": "Turn on notifications to hear the adhan",
  "@home_notifHint_text": {},
  "home_notifHint_allow": "Allow",
  "@home_notifHint_allow": {},
  "notifSettings_disabledBanner_text": "Notifications are off — you won't hear the adhan.",
  "@notifSettings_disabledBanner_text": {},
  "notifSettings_disabledBanner_action": "Open settings",
  "@notifSettings_disabledBanner_action": {}
```

- [ ] **Step 2: Add the Arabic translations to the Arabic ARB**

```json
  "home_locationCard_title": "تحتاج مواقيت الصلاة إلى موقعك",
  "home_locationCard_body": "نستخدمه فقط لحساب مواقيت صلاة دقيقة.",
  "home_locationCard_enable": "تفعيل الموقع",
  "home_locationCard_openSettings": "فتح الإعدادات",
  "home_notifHint_text": "فعّل الإشعارات لسماع الأذان",
  "home_notifHint_allow": "السماح",
  "notifSettings_disabledBanner_text": "الإشعارات متوقفة — لن تسمع الأذان.",
  "notifSettings_disabledBanner_action": "فتح الإعدادات"
```

- [ ] **Step 3: Regenerate l10n (headless)**

Run: `dart run intl_utils:generate`
Expected: regenerates `lib/generated/l10n.dart` and `lib/generated/intl/*.dart` with the new getters.

- [ ] **Step 4: Verify the getters exist**

Run: `flutter analyze lib/generated/l10n.dart`
Expected: "No issues found!". Confirm `S` now exposes `home_locationCard_title`, etc.

- [ ] **Step 5: Commit**

```bash
git add lib/l10n/ lib/generated/
git commit -m "feat(l10n): strings for permission recovery card, hint, and banner"
```

---

### Task 6: Carry the typed `Failure` in `DailyPrayerContextFailed`

**Files:**
- Modify: `lib/features/home/presentation/cubit/daily_prayer_context_state.dart`
- Modify: `lib/features/home/presentation/cubit/daily_prayer_context_cubit.dart`
- Modify: `lib/features/home/presentation/pages/widgets/home_view.dart` (line 41 references `state.error`)
- Test: `test/features/home/presentation/cubit/daily_prayer_context_cubit_test.dart`

- [ ] **Step 1: Write the failing test**

Add to the cubit test file (uses imports already present: `Left`, `failure.dart`). Add an import for the specific failure: `import 'package:quran_app/core/errors/failure.dart';` is already imported. Add:

```dart
  blocTest<DailyPrayerContextCubit, DailyPrayerContextState>(
    'fetchDailyPrayerContext: Failed state carries the typed Failure',
    build: () {
      when(() => usecase.call(any())).thenAnswer(
        (_) => Stream.value(
          const Left(LocationPermissionDeniedFailure('denied')),
        ),
      );
      return DailyPrayerContextCubit(getDailyPrayerContext: usecase);
    },
    act: (c) => c.fetchDailyPrayerContext(),
    expect: () => [
      isA<DailyPrayerContextLoading>(),
      isA<DailyPrayerContextFailed>().having(
        (s) => s.failure,
        'failure',
        isA<LocationPermissionDeniedFailure>(),
      ),
    ],
  );
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/home/presentation/cubit/daily_prayer_context_cubit_test.dart`
Expected: FAIL — `DailyPrayerContextFailed` has no `failure` getter (compile error / missing member).

- [ ] **Step 3: Update the state class**

In `daily_prayer_context_state.dart`, add `import 'package:quran_app/core/errors/failure.dart';` at the top (after the `part of` line is not allowed — instead add the import to the **cubit** file; `state` is a `part of` the cubit, so the cubit's imports are visible). Change `DailyPrayerContextFailed`:

```dart
final class DailyPrayerContextFailed extends DailyPrayerContextState {
  final Failure failure;

  const DailyPrayerContextFailed(this.failure);

  String get message => failure.message;

  @override
  List<Object> get props => [failure];
}
```

- [ ] **Step 4: Update the cubit to emit the typed failure**

In `daily_prayer_context_cubit.dart`, add `import 'package:quran_app/core/errors/failure.dart';` and change the fold's failure branch:

```dart
        (failure) => emit(DailyPrayerContextFailed(failure)),
```

- [ ] **Step 5: Update `home_view.dart` reference**

Line 41 currently: `return Center(child: Text(state.error));`. Change to use the message getter:

```dart
                return Center(child: Text(state.message));
```

(Task 7 replaces this branch entirely; this keeps it compiling in the meantime.)

- [ ] **Step 6: Confirm no other references to `.error`**

Run: `grep -rn "DailyPrayerContextFailed" lib/ ; grep -rn "\.error" lib/features/home/`
Expected: no remaining `state.error` on a `DailyPrayerContextFailed`.

- [ ] **Step 7: Run the test + analyze**

Run: `flutter test test/features/home/presentation/cubit/daily_prayer_context_cubit_test.dart && flutter analyze lib/features/home/`
Expected: PASS, "No issues found!".

- [ ] **Step 8: Commit**

```bash
git add lib/features/home/presentation/cubit/ lib/features/home/presentation/pages/widgets/home_view.dart test/features/home/presentation/cubit/daily_prayer_context_cubit_test.dart
git commit -m "refactor(home): carry typed Failure in DailyPrayerContextFailed"
```

---

### Task 7: Location recovery card + HomeView branching

**Files:**
- Create: `lib/features/home/presentation/pages/widgets/location_recovery_card.dart`
- Modify: `lib/features/home/presentation/pages/widgets/home_view.dart`
- Test: `test/features/home/presentation/pages/widgets/location_recovery_card_test.dart`

- [ ] **Step 1: Write the widget**

Create `location_recovery_card.dart`. Mirror styling conventions (use `SurfaceCard` from `lib/core/widgets/design/surface_card.dart`, `context.colorScheme` from `lib/config/theme/color_scheme.dart`, `TS` typography). The card takes an `onAction` callback and a label so the host decides request-vs-deeplink:

```dart
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/widgets/design/surface_card.dart';
import 'package:quran_app/generated/l10n.dart';

/// Shown on Home when prayer times can't load because location permission is
/// missing. [actionLabel] + [onAction] are supplied by the host so the same
/// card serves both "request permission" and "open settings" (denied-forever).
class LocationRecoveryCard extends StatelessWidget {
  const LocationRecoveryCard({
    super.key,
    required this.actionLabel,
    required this.onAction,
  });

  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final s = S.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SurfaceCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedLocation01,
                color: scheme.primary,
                size: 34,
              ),
              const SizedBox(height: 14),
              Text(
                s.home_locationCard_title,
                textAlign: TextAlign.center,
                style: TS.bold16.copyWith(color: scheme.onSurface),
              ),
              const SizedBox(height: 8),
              Text(
                s.home_locationCard_body,
                textAlign: TextAlign.center,
                style: TS.regular14.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onAction,
                child: Text(actionLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

Confirm `SurfaceCard`'s constructor (it takes a `child`; it is used as `SurfaceCard(child: ...)` in `notifications_settings_page.dart`). Confirm `TS.bold16`/`TS.regular14` exist (used widely in `home_view.dart` / `permission_step.dart`).

- [ ] **Step 2: Write the failing widget test**

Create `location_recovery_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:quran_app/features/home/presentation/pages/widgets/location_recovery_card.dart';
import 'package:quran_app/generated/l10n.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: S.delegate.supportedLocales,
        home: Scaffold(body: child),
      );

  testWidgets('renders action label and fires onAction', (tester) async {
    var tapped = false;
    await tester.pumpWidget(host(
      LocationRecoveryCard(
        actionLabel: 'Enable location',
        onAction: () => tapped = true,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Enable location'), findsOneWidget);
    await tester.tap(find.text('Enable location'));
    expect(tapped, isTrue);
  });
}
```

- [ ] **Step 3: Run it to verify it fails, then passes**

Run: `flutter test test/features/home/presentation/pages/widgets/location_recovery_card_test.dart`
Expected: PASS once the widget compiles (it is self-contained). If it fails on missing l10n, confirm Task 5 ran.

- [ ] **Step 4: Branch the failure state in `home_view.dart`**

Replace the failure branch (currently `if (state is DailyPrayerContextFailed) { return Center(child: Text(state.message)); }`) with type-aware branching. Add imports: `import 'package:geolocator/geolocator.dart';`, `import 'package:quran_app/core/errors/failure.dart';`, `import 'package:quran_app/features/home/presentation/pages/widgets/location_recovery_card.dart';`. Then:

```dart
              if (state is DailyPrayerContextFailed) {
                final failure = state.failure;
                if (failure is LocationPermissionDeniedFailure) {
                  return LocationRecoveryCard(
                    actionLabel: S.of(context).home_locationCard_enable,
                    onAction: () async {
                      await Geolocator.requestPermission();
                      if (context.mounted) {
                        context
                            .read<DailyPrayerContextCubit>()
                            .fetchDailyPrayerContext();
                      }
                    },
                  );
                }
                if (failure is LocationPermissionDeniedForeverFailure) {
                  return LocationRecoveryCard(
                    actionLabel: S.of(context).home_locationCard_openSettings,
                    onAction: () => Geolocator.openAppSettings(),
                  );
                }
                if (failure is LocationServiceDisabledFailure) {
                  return LocationRecoveryCard(
                    actionLabel: S.of(context).home_locationCard_openSettings,
                    onAction: () => Geolocator.openLocationSettings(),
                  );
                }
                return Center(child: Text(state.message));
              }
```

Confirm the failure class names against `lib/core/errors/failure.dart` (`LocationPermissionDeniedFailure`, `LocationPermissionDeniedForeverFailure`, `LocationServiceDisabledFailure` — as used in `geolocator_error_handler.dart`).

- [ ] **Step 5: Run the home tests + analyze**

Run: `flutter test test/features/home/ && flutter analyze lib/features/home/`
Expected: PASS, "No issues found!".

- [ ] **Step 6: Commit**

```bash
git add lib/features/home/presentation/pages/widgets/ test/features/home/presentation/pages/widgets/location_recovery_card_test.dart
git commit -m "feat(home): location recovery card for denied/disabled location"
```

---

### Task 8: Add `notificationHintDismissed` settings flag

**Files:**
- Modify: `lib/features/settings/domain/entities/settings.dart`
- Modify: `lib/features/settings/data/models/settings_model.dart`
- Modify: `lib/features/settings/presentation/cubit/settings_cubit.dart`
- Test: `test/features/settings/data/models/settings_model_test.dart`

Mirror the existing `showSplashOnLaunch` bool exactly (entity field + default, copyWith, props; model constructor/copyWith/fromMap/toMap; cubit setter).

- [ ] **Step 1: Write the failing model test**

In `settings_model_test.dart`, add a test that the flag round-trips and defaults to `false`:

```dart
  test('notificationHintDismissed: defaults false and round-trips via map', () {
    const model = SettingsModel(isFormat12Hours: false, isArabic: true);
    expect(model.notificationHintDismissed, isFalse);

    final restored = SettingsModel.fromMap(
      model.copyWith(notificationHintDismissed: true).toMap(),
    );
    expect(restored.notificationHintDismissed, isTrue);
  });
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/settings/data/models/settings_model_test.dart`
Expected: FAIL — `notificationHintDismissed` is not defined.

- [ ] **Step 3: Add the field to the entity**

In `settings.dart`: add field + doc, constructor default, copyWith param + assignment, and props entry:

```dart
  /// Whether the user dismissed the Home "turn on notifications" hint. Once
  /// dismissed it stays hidden (no re-nag); the Settings banner remains.
  final bool notificationHintDismissed;
```
Constructor: `this.notificationHintDismissed = false,`
copyWith param: `bool? notificationHintDismissed,`
copyWith body: `notificationHintDismissed: notificationHintDismissed ?? this.notificationHintDismissed,`
props: add `notificationHintDismissed,`

- [ ] **Step 4: Add to the model**

In `settings_model.dart`: constructor `super.notificationHintDismissed,`; copyWith param + pass-through `notificationHintDismissed: notificationHintDismissed ?? this.notificationHintDismissed,`; `fromMap`: `notificationHintDismissed: map['notificationHintDismissed'] ?? false,`; `toMap`: `'notificationHintDismissed': notificationHintDismissed,`.

- [ ] **Step 5: Add the cubit setter**

In `settings_cubit.dart`, after `completeOnboarding()`:

```dart
  /// Permanently dismisses the Home notification hint.
  void dismissNotificationHint() {
    if (state.settingsModel.notificationHintDismissed) return;
    emit(
      SettingsState(
        state.settingsModel.copyWith(notificationHintDismissed: true),
      ),
    );
  }
```

- [ ] **Step 6: Run the settings tests + analyze**

Run: `flutter test test/features/settings/ && flutter analyze lib/features/settings/`
Expected: PASS, "No issues found!".

- [ ] **Step 7: Commit**

```bash
git add lib/features/settings/ test/features/settings/data/models/settings_model_test.dart
git commit -m "feat(settings): notificationHintDismissed flag"
```

---

### Task 9: Notification hint widget + HomeView wiring

**Files:**
- Create: `lib/features/home/presentation/pages/widgets/notification_hint.dart`
- Modify: `lib/features/home/presentation/pages/widgets/home_view.dart`
- Test: `test/features/home/presentation/pages/widgets/notification_hint_test.dart`

The hint is a self-contained `StatefulWidget` that queries `areNotificationsEnabled()` (scheduler injectable for tests, default `sl<...>()`), refreshes on resume, hides when enabled or when the settings flag is set, and exposes `onAllow`/`onDismiss` callbacks.

- [ ] **Step 1: Write the widget**

```dart
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/di/dependency_injection.dart';
import 'package:quran_app/core/notifications/prayer_notification_scheduler.dart';
import 'package:quran_app/generated/l10n.dart';

/// Slim, dismissible Home hint shown only when notifications are OS-disabled
/// and the user hasn't dismissed it. [onAllow] should request permission and
/// then trigger a context re-fetch (which reschedules adhans); [onDismiss]
/// persists the dismissal. [dismissed] reflects the settings flag.
class NotificationHint extends StatefulWidget {
  const NotificationHint({
    super.key,
    required this.dismissed,
    required this.onAllow,
    required this.onDismiss,
    PrayerNotificationScheduler? scheduler,
  }) : scheduler = scheduler;

  final bool dismissed;
  final Future<void> Function() onAllow;
  final VoidCallback onDismiss;
  final PrayerNotificationScheduler? scheduler;

  @override
  State<NotificationHint> createState() => _NotificationHintState();
}

class _NotificationHintState extends State<NotificationHint>
    with WidgetsBindingObserver {
  bool _enabled = true; // assume enabled until checked (hides by default)

  PrayerNotificationScheduler get _scheduler =>
      widget.scheduler ?? sl<PrayerNotificationScheduler>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    try {
      final enabled = await _scheduler.areNotificationsEnabled();
      if (mounted) setState(() => _enabled = enabled);
    } catch (_) {/* leave hidden on error */}
  }

  @override
  Widget build(BuildContext context) {
    if (widget.dismissed || _enabled) return const SizedBox.shrink();
    final scheme = context.colorScheme;
    final s = S.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedNotification01,
            color: scheme.primary,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              s.home_notifHint_text,
              style: TS.regular14.copyWith(color: scheme.onSurface),
            ),
          ),
          TextButton(
            onPressed: () async {
              await widget.onAllow();
              await _refresh();
            },
            child: Text(s.home_notifHint_allow),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 18, color: scheme.onSurface),
            onPressed: widget.onDismiss,
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Write the widget test (fake scheduler)**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:quran_app/core/notifications/prayer_notification_scheduler.dart';
import 'package:quran_app/features/home/presentation/pages/widgets/notification_hint.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';
import 'package:quran_app/core/constants/prayer_name.dart';

class _FakeScheduler implements PrayerNotificationScheduler {
  _FakeScheduler(this.enabled);
  final bool enabled;
  @override
  Future<bool> areNotificationsEnabled() async => enabled;
  @override
  Future<void> init() async {}
  @override
  Future<bool?> requestNotificationsPermission() async => true;
  @override
  Future<void> scheduleDailyPrayerNotifications(PrayerTimes p) async {}
  @override
  Future<void> cancelAllPrayerNotifications() async {}
  @override
  Future<void> scheduleStaticReminder({
    required PrayerName prayer,
    required DateTime at,
    required String title,
    required String body,
  }) async {}
  @override
  Future<void> cancelAllStaticReminders() async {}
  @override
  Future<void> scheduleTestNotification({Duration delay = Duration.zero}) async {}
}

void main() {
  Widget host(Widget child) => MaterialApp(
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: S.delegate.supportedLocales,
        home: Scaffold(body: child),
      );

  testWidgets('hidden when notifications enabled', (tester) async {
    await tester.pumpWidget(host(NotificationHint(
      dismissed: false,
      onAllow: () async {},
      onDismiss: () {},
      scheduler: _FakeScheduler(true),
    )));
    await tester.pumpAndSettle();
    expect(find.byType(TextButton), findsNothing);
  });

  testWidgets('shown when disabled; dismiss fires callback', (tester) async {
    var dismissed = false;
    await tester.pumpWidget(host(NotificationHint(
      dismissed: false,
      onAllow: () async {},
      onDismiss: () => dismissed = true,
      scheduler: _FakeScheduler(false),
    )));
    await tester.pumpAndSettle();
    expect(find.byType(TextButton), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    expect(dismissed, isTrue);
  });

  testWidgets('hidden when dismissed flag set', (tester) async {
    await tester.pumpWidget(host(NotificationHint(
      dismissed: true,
      onAllow: () async {},
      onDismiss: () {},
      scheduler: _FakeScheduler(false),
    )));
    await tester.pumpAndSettle();
    expect(find.byType(TextButton), findsNothing);
  });
}
```

Note: `import 'package:quran_app/generated/l10n.dart';` is required in the test — add it. Also remove the `S` import note collision; ensure the `S` symbol resolves.

- [ ] **Step 3: Fix the redundant initializer**

In the widget, the constructor `}) : scheduler = scheduler;` is redundant — replace with a normal field assignment: drop the initializer and keep `this.scheduler` in the parameter list:

```dart
  const NotificationHint({
    super.key,
    required this.dismissed,
    required this.onAllow,
    required this.onDismiss,
    this.scheduler,
  });
```

- [ ] **Step 4: Run the test**

Run: `flutter test test/features/home/presentation/pages/widgets/notification_hint_test.dart`
Expected: PASS.

- [ ] **Step 5: Wire into `home_view.dart`**

In the `DailyPrayerContextLoaded` branch, insert the hint at the top of the scrolling `Column` children (before `UpcomingPrayer`). Read the settings flag and supply callbacks. Add imports for `SettingsCubit` and `NotificationHint`. Insert:

```dart
                            NotificationHint(
                              dismissed: context
                                  .watch<SettingsCubit>()
                                  .state
                                  .settingsModel
                                  .notificationHintDismissed,
                              onDismiss: () => context
                                  .read<SettingsCubit>()
                                  .dismissNotificationHint(),
                              onAllow: () async {
                                await sl<PrayerNotificationScheduler>()
                                    .requestNotificationsPermission();
                                if (context.mounted) {
                                  context
                                      .read<DailyPrayerContextCubit>()
                                      .fetchDailyPrayerContext(silent: true);
                                }
                              },
                            ),
```

Add imports: `import 'package:quran_app/core/di/dependency_injection.dart';`, `import 'package:quran_app/core/notifications/prayer_notification_scheduler.dart';`, `import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';`.

- [ ] **Step 6: Run home tests + analyze**

Run: `flutter test test/features/home/ && flutter analyze lib/features/home/`
Expected: PASS, "No issues found!". If existing home widget tests construct `HomeView` without a `SettingsCubit` provider, they will now need one — update those tests to wrap with a `BlocProvider<SettingsCubit>` using a fake (follow the pattern in `test/features/surah/.../mushaf_bottom_bar_test.dart` which uses a fake `SettingsCubit`, per recent commit `3283ab7`).

- [ ] **Step 7: Commit**

```bash
git add lib/features/home/presentation/pages/widgets/ test/features/home/
git commit -m "feat(home): dismissible notification hint; reschedule on grant"
```

---

### Task 10: Notifications settings disabled banner

**Files:**
- Modify: `lib/features/home/presentation/pages/notifications_settings_page.dart`

- [ ] **Step 1: Add a banner above the per-prayer list**

Convert the relevant part to show a banner when `areNotificationsEnabled()` is false. Add a small private `StatefulWidget` `_NotifDisabledBanner` (same query/resume pattern as `NotificationHint`, but the action opens app settings) and insert it as the first child of the `ListView`:

```dart
import 'package:app_settings/app_settings.dart'; // confirm this package exists in pubspec; otherwise use AppSettings from the same package used elsewhere, or platform channel.
```

If no app-settings package is available, reuse `Geolocator.openAppSettings()` is location-specific — instead use the notification deep-link already available via the platform. Simplest portable option: show the banner with an "Open settings" button that calls `await sl<PrayerNotificationScheduler>().requestNotificationsPermission()` (on Android 13+ if not permanently denied this re-prompts; if permanently denied it silently no-ops — acceptable for v1). Confirm the chosen mechanism during implementation and keep it best-effort.

Banner widget:

```dart
class _NotifDisabledBanner extends StatefulWidget {
  const _NotifDisabledBanner();
  @override
  State<_NotifDisabledBanner> createState() => _NotifDisabledBannerState();
}

class _NotifDisabledBannerState extends State<_NotifDisabledBanner>
    with WidgetsBindingObserver {
  bool _enabled = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) _refresh();
  }
  Future<void> _refresh() async {
    try {
      final e = await sl<PrayerNotificationScheduler>().areNotificationsEnabled();
      if (mounted) setState(() => _enabled = e);
    } catch (_) {}
  }
  @override
  Widget build(BuildContext context) {
    if (_enabled) return const SizedBox.shrink();
    final scheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: SurfaceCard(
        child: Row(
          children: [
            Expanded(
              child: Text(
                S.of(context).notifSettings_disabledBanner_text,
                style: TS.regular14.copyWith(color: scheme.onSurface),
              ),
            ),
            TextButton(
              onPressed: () async {
                await sl<PrayerNotificationScheduler>()
                    .requestNotificationsPermission();
                await _refresh();
              },
              child: Text(S.of(context).notifSettings_disabledBanner_action),
            ),
          ],
        ),
      ),
    );
  }
}
```

Add the needed imports (`color_scheme.dart`, `typography_styles.dart`, `dependency_injection.dart`, `prayer_notification_scheduler.dart`) and insert `const _NotifDisabledBanner(),` as the first child of the `ListView` in `build`.

- [ ] **Step 2: Analyze**

Run: `flutter analyze lib/features/home/presentation/pages/notifications_settings_page.dart`
Expected: "No issues found!".

- [ ] **Step 3: Commit**

```bash
git add lib/features/home/presentation/pages/notifications_settings_page.dart
git commit -m "feat(settings): banner when notifications are OS-disabled"
```

---

### Task 11: Resume re-check on Home

**Files:**
- Modify: `lib/features/home/presentation/pages/home_page.dart` (`_StripResumeGuardState.didChangeAppLifecycleState`, lines 248–254)

- [ ] **Step 1: Re-fetch the prayer context on resume**

So the location recovery card clears automatically when the user returns from settings having granted. In `didChangeAppLifecycleState`, after the existing `if (state != AppLifecycleState.resumed) return;`, add a silent re-fetch regardless of current state (covers the failed→granted transition):

```dart
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // Re-fetch so a now-granted location clears the recovery card. Silent to
    // avoid a skeleton flash when data is already showing.
    context.read<DailyPrayerContextCubit>().fetchDailyPrayerContext(silent: true);
    final ctxState = context.read<DailyPrayerContextCubit>().state;
    if (ctxState is DailyPrayerContextLoaded) {
      _enableOrRefreshStrip(context, ctxState);
    }
  }
```

(The notification hint refreshes itself on resume via its own observer — Task 9.)

- [ ] **Step 2: Analyze + run home tests**

Run: `flutter analyze lib/features/home/ && flutter test test/features/home/`
Expected: "No issues found!", PASS.

- [ ] **Step 3: Commit**

```bash
git add lib/features/home/presentation/pages/home_page.dart
git commit -m "feat(home): re-fetch prayer context on resume to clear recovery card"
```

---

### Task 12: Full verification

- [ ] **Step 1: Analyze the whole project**

Run: `flutter analyze`
Expected: "No issues found!".

- [ ] **Step 2: Run the full test suite**

Run: `flutter test`
Expected: All tests pass.

- [ ] **Step 3: Manual / instrumented checks (Android device or emulator)**

- Onboarding: on the location step, tap **Enable**, grant location → **no** notification dialog appears; the wizard advances to the notification step, where tapping **Enable** is the only thing that prompts for notifications.
- Adhan with notifications disabled (revoke in system settings): trigger a test adhan → **no** audio plays (receiver gate). Re-enable notifications → test adhan plays with a card + Stop.
- Home with location denied → recovery card; grant + return → card clears on resume.
- Home with notifications off → hint visible; Allow → grants + hint clears; dismiss → hint stays hidden across app restarts.

- [ ] **Step 4: Final commit (if any test-fixups were needed)**

```bash
git add -A
git commit -m "test(permissions): fixups for permission-flow changes"
```

---

## Self-review notes

- **Spec coverage:** Bug #1 → Tasks 1–2. Bug #3 → Task 3 (+ reschedule-on-grant in Tasks 9/11). `areNotificationsEnabled()` plumbing → Task 4. Typed failure → Task 6. Location recovery (denied/denied-forever/service-disabled) → Task 7. Notification hint + persistent dismiss → Tasks 8–9. Settings banner → Task 10. Resume re-check → Task 11 (location) + Task 9 (notifications). l10n → Task 5. Behavior "notifications off → no adhan" → Task 3.
- **Type consistency:** `DailyPrayerContextFailed.failure` (Task 6) is consumed in Task 7 and `.message` in `home_view`. `areNotificationsEnabled()` (Task 4) consumed in Tasks 9/10. `notificationHintDismissed` (Task 8) consumed in Task 9. `dismissNotificationHint()` (Task 8) consumed in Task 9.
- **Known adapt-points (subagent must confirm against current files):** exact `flutter_local_notifications` iOS permission API (Task 4 Step 3); `SurfaceCard`/`TS` member names; settings-cubit provider needed by any pre-existing HomeView widget test (Task 9 Step 6); the notification deep-link mechanism for the Settings banner (Task 10 Step 1).
