---
description: Theming — palette, colour scheme, typography, card styling
paths: ["lib/**/*.dart"]
---

# Theming (`lib/config/theme/`)

- **One theme per palette.** `ColorPalette` (`core/constants/color_palette.dart`: `neutralDark`, `neutralLight`, `slateDark`, `slateLight`) is picked in Settings; `main.dart` builds `theme: settings.palette.toThemeData()`. There is no separate dark theme or `ThemeMode`: a dark palette is the dark mode.
- **`AppPaletteX`** (`app_palette.dart`) holds every palette colour (`bg`, `surface`, `primary`, `secondary`, `onSurface`, `onSurfaceVar`, `mushafBg`, `mushafText`, `mushafBorderColor`), the `ColorScheme` and the component themes. A new palette colour or component theme goes here.
- **Hex literals live only in `app_palette.dart`, `app_colors.dart` (`AppColors.error`) and `features/surah/presentation/utils/mushaf_paper_colors.dart`** (the `MushafPaper` reading papers). Never write `Color(0x…)` in a widget; a few existing list items still do, and a change that touches one moves its colour into the theme.
- **Read colours with `context.colorScheme`** (`color_scheme.dart`), never `Theme.of(context).colorScheme` repeated inline. `surface` is the page background and `surfaceContainer` the card fill, as `AppPaletteX.colorScheme` maps them.
- **Cards** use `context.cardShadow()` (empty in dark palettes) and `context.cardBorder()`; `SurfaceCard` already applies the shadow.
- **Typography**: `TS.*` (`TypographyStyles`, Cairo) for UI text, e.g. `TS.bold16`, `TS.regular14`, with `.copyWith(color: …)`. Quran and hadith text use the `TextStyle` extensions `.scheherazade` and `.amiri`. Fonts are bundled in `assets/fonts/` and declared in `pubspec.yaml` (Cairo 400–800, Amiri and Scheherazade New 400/700); there is no `google_fonts`. A new family or weight goes in both places, never fetched at runtime.
- **Mushaf colours** follow the reading paper (`MushafPaper`), not the app palette: read them through `MushafPaperX` in `features/surah/presentation/utils/mushaf_paper_colors.dart`. `AppPaletteX.mushafBg` / `mushafText` have no callers today; don't build on them.
