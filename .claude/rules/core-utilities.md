---
description: Core utilities, helpers, constants, and base classes — always reuse before writing new ones
paths: ["lib/**/*.dart"]
---

# Core Utilities & Infrastructure

Check here before writing a helper. Keep these pure: no widgets, no feature imports.

## Helper functions (`core/helper functions/`, with a space; imported as `helper%20functions`)
- **`normalizeArabic(String)`** (`arabic_normalizer.dart`): strips diacritics and folds letter variants for Quran search; apply it to both the query and the index. Pure Dart, safe in domain.
- **`AhadithHelpers`**: `cleanArabicQuery` (hadith search's own normalizer, kept separate on purpose), `sortHadiths`, `isArabic(text)`.
- **`String.toIndicNumerals(localeCode)`** (`numeral_helpers.dart`) and **`Object.toLocalized(context)`** (`locale_helpers.dart`): ASCII → Arabic-Indic digits when the locale is Arabic. Use one of them for every number shown in Arabic; never hand-roll the digit map again.
- **`context.isArabic`**, **`context.langCode`** (`locale_helpers.dart`).
- **`context.palette`** (`config/theme/palette_context.dart`): the selected `ColorPalette` for `AppPaletteX` getters such as `primaryInk`; build-only, see `theming.md`.
- **`DateTime.to24hTime()`**, **`DateTime.format12h(context)`**, **`String.parse24hTime()`**, `removeTimeZone()`, `gregorianDate()` (`time_helpers.dart`).
- **`Duration.toDigitalClock()`** (`duration_helpers.dart`).

## Constants (`core/constants/`)
- **`AssetsDir`**: `fontsDir`, `imagesDir`, `iconsDir`, `jsonDir`. Never hardcode an `assets/` path.
- **`DeviceSize`** on `BuildContext`: `context.height`, `context.width`, `context.aspectRatio`, `context.fontScaler`, `context.responsiveFont(size)`.
- **`ColorPalette`**, **`MushafPaper`**, **`MushafReadingMode`**, **`PrayerName`**, **`HadithPagination`**.

## Base classes
- **`UseCase<T, P>`** (`core/usecases/usecase.dart`): `Future<T> call(P params)`. **`StreamUseCase<T, Params>`** for streams. **`NoParams`** for parameterless calls.
- **`Failure`** (`core/errors/failure.dart`) and its subclasses; `Failure.fromException(e)`.
- **`DioErrorHandler.handle`**, **`GeolocatorErrorHandler.handle`** (`core/utils/`): exception → `Failure`.

## Services
- **`PrayerNotificationScheduler`** (`core/notifications/`): `init()` runs in `main()`; on iOS `scheduleAlerts` schedules the per-prayer adhans and reminders planned by `planIosAlerts` (`features/notifications/data/services/ios_alert_plan.dart`, pure and tested) and returns the last adhan time. Android scheduling is native.
  - Known exception to "no feature imports": the scheduler imports `PrayerTimes` (home), `PrayerAlert` and the iOS planner (notifications). Don't add more.
