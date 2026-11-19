---
description: Theming — palette, colour scheme, typography, card styling
paths: ["lib/**/*.dart"]
---

# Theming (`lib/config/theme/`)

- **One theme per palette.** `ColorPalette` (`core/constants/color_palette.dart`: `neutralDark`, `neutralLight`, `slateDark`, `slateLight`) is picked in Settings; `main.dart` builds `theme: settings.palette.toThemeData()`. There is no separate dark theme or `ThemeMode`: a dark palette is the dark mode.
- **`AppPaletteX`** (`app_palette.dart`) holds every palette colour (`bg`, `surface`, `primary`, `secondary`, `onSurface`, `onSurfaceVar`, `mushafBg`, `mushafText`, `mushafBorderColor`), the `ColorScheme` and the component themes. A new palette colour or component theme goes here.
- **Hex literals live only in `app_palette.dart`, `features/surah/presentation/utils/mushaf_paper_colors.dart`** (the `MushafPaper` reading papers) and **`features/notifications/presentation/utils/strip_style_colors.dart`** (the prayer strip's day and night swatches sent to native). Never write `Color(0x…)` in a widget; a few existing list items still do, and a change that touches one moves its colour into the theme.
- **Read colours with `context.colorScheme`** (`color_scheme.dart`), never `Theme.of(context).colorScheme` repeated inline. A palette-only getter that has no `ColorScheme` slot (`primaryInk`, `primaryTint`) is read with **`context.palette`** (`palette_context.dart`, selects `SettingsCubit`'s palette and rebuilds when it changes; call it in `build`), never `context.select((SettingsCubit c) => c.state.settingsModel.palette)` or a `BlocSelector` that only adds the palette. `surface` is the page background and `surfaceContainer` the card fill, as `AppPaletteX.colorScheme` maps them.
- **Cards** use `context.cardShadow()` (empty in dark palettes) and `context.cardBorder()`; `SurfaceCard` already applies the shadow.
- **Typography**: `TS.*` (`TypographyStyles`, Cairo, `typography_styles.dart`) owns the family, size, weight and letter spacing of every piece of UI text, e.g. `TS.bold16`, `TS.regular14`. `.copyWith(...)` only adds colour, height, decoration or shadows. Never write `TextStyle(`, `fontFamily:`, `fontSize:`, `fontWeight:` or `Theme.of(context).textTheme.*` in a widget: `test/config/theme/typography_ratchet_test.dart` fails when a count rises. `toThemeData()` sets `fontFamily: TS.fontFamily`, so Material widgets (buttons, snackbars, dialogs, chips) render in Cairo at Material's default sizes; give a `Text` an explicit token when its size matters.
  - A size with no token snaps to the nearest token of the same weight, the larger one when halfway. Add a token only when the same size and weight is used 3 or more times with no token within 1 pt.
  - A runtime size (`context.responsiveFont`, the reading-size setting, a `LayoutBuilder` value) starts from the nearest token: `TS.bold12.copyWith(fontSize: size)`.
  - Exceptions: Quran and hadith text use the `.scheherazade` and `.amiri` extensions, and the mushaf's printed chrome uses the `QCF2BSML` glyph font.
  - Fonts are bundled in `assets/fonts/` and declared in `pubspec.yaml` (Cairo 400–800, Amiri and Scheherazade New 400/700); there is no `google_fonts`. A new family or weight goes in both places, never fetched at runtime.
- **Mushaf colours** follow the reading paper (`MushafPaper`), not the app palette: read them through `MushafPaperX` in `features/surah/presentation/utils/mushaf_paper_colors.dart`. `AppPaletteX.mushafBg` / `mushafText` have no callers today; don't build on them.
