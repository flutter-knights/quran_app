# Onboarding Wizard (الفرقان) — Design

Date: 2026-05-29
Status: Approved, implementing

## Goal
Replace the interim single-screen landing with a 5-step first-run onboarding wizard that:
collects initial preferences (language, theme, time format, splash-on-next-launch),
requests location + notification permissions with a "why" shown before each OS prompt,
and rebrands the app as **الفرقان · Al-Furqan**.

## App name
الفرقان · Al-Furqan. Wordmark replaces the mockup's "QURAN+".

## Flow (unchanged from prior work)
- First run (`!hasCompletedOnboarding`): Splash → Onboarding wizard → Home.
- Later runs: Splash → Home (if `showSplashOnLaunch`), else straight to Home.
- The splash animates into the wizard's first step (both share `SplashBackdrop`).
- `completeOnboarding()` fires when leaving the last step → Home.

## Wizard shape
- 5-step `PageView` on `SplashBackdrop` (deep-green backdrop + glow + faint grid, white foreground).
- Shared chrome: 5-dot progress indicator; white **متابعة / Continue** primary button; swipe + back allowed.
- Preference changes apply live via `SettingsCubit` (language switch re-renders the wizard).

## Steps & copy (Arabic / English mirrors via ARB)
1. **Welcome** — minimal hero. App name **الفرقان** alone at the top (no ﷲ mark beside it, no ﷲ glyph in the body). Centered headline **القرآن الكريم بين يديك** + subtitle **اقرأ، استمع، وتدبّر — مع مواقيت صلاتك في مكان واحد**. Continue.
2. **Language** — title **اختر لغتك**, hint **يمكنك تغييرها لاحقًا**, two large selectable cards (العربية / English). Tapping switches locale live. Continue.
3. **Appearance** — title **خصّص مظهرك**. Theme: **reuse `PalettePickerWidget`** (self-previewing tiles painted in each palette's real colors + name + accent strip + check, like Settings) so the user previews the in-app look; tap re-themes live. Time format: segmented 12/24 (`isFormat12Hours`, inverted flag — false = 12h). Splash toggle: label **شاشة البداية**, sub **عند فتح التطبيق لاحقًا** (`showSplashOnLaunch`). Continue.
4. **Location** — icon + title **مواقيت صلاتك بدقّة** + why paragraph (*نستخدم موقعك لحساب مواقيت الصلاة في مدينتك بدقّة. يبقى على جهازك ولا نشاركه.*). Primary **تفعيل** → `Geolocator.requestPermission()`; secondary **ليس الآن** skips. Either advances.
5. **Notifications** — icon + title **لا تفوتك صلاة** + why paragraph (*فعّل الإشعارات لتصلك تنبيهات الأذان وتذكيرات الصلاة في أوقاتها. يمكنك ضبطها لاحقًا.*). Primary **تفعيل** → notifications permission; secondary **ليس الآن**. Either → Home.

## Permissions
- Location: `Geolocator.requestPermission()`.
- Notifications: expose `requestPermissions()` on `PrayerNotificationScheduler` wrapping the Android plugin's `requestNotificationsPermission()` (exact-alarm handled by existing scheduler init).
- Both proceed regardless of grant/deny; never trap the user.

## Loader
Add **`flutter_spinkit`**; `SplashLoader` wraps `SpinKitThreeBounce` (white) — the real bouncing 3-dot animation. Used on the splash.

## Code plan (sequenced)
1. `pubspec.yaml`: add `flutter_spinkit`; `flutter pub get`.
2. `SplashLoader` → `SpinKitThreeBounce`.
3. l10n: replace interim `landing_*` strings with wizard strings (welcome, language, appearance, permission copy, button labels, app tagline); regenerate via `dart run intl_utils:generate`.
4. `PrayerNotificationScheduler(+Impl)`: add `requestPermissions()`.
5. `features/onboarding/presentation/pages/onboarding_page.dart` (PageView host + chrome) and `widgets/` step widgets; delete interim `landing_page.dart`.
6. Router: `landingPath` → `onboardingPath`, point at `OnboardingPage`; update splash branch + `main.dart` initial-route computation.
7. Verify with `flutter analyze`.

## Non-goals
- Not changing the splash→onboarding transition (already built).
- Not adding a separate qibla/other permission.
- Exact-alarm special-access screen not surfaced as a wizard step.
