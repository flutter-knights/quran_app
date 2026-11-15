---
description: Feature widget rules and feature-level presentation utilities
paths: ["lib/features/**/presentation/**/*.dart", "lib/features/splash/**/*.dart"]
---

# Feature Widgets

- Feature widgets live beside the page that uses them: `features/<feature>/presentation/pages/**/widgets/` (e.g. `surah/presentation/pages/mushaf/widgets/`). `quran_playback` has no pages, so its widgets sit in `presentation/widgets/`.
- They read state with `BlocBuilder`/`BlocSelector` on their own feature's cubit (`MushafCubit`, `PlaybackCubit`), per `state-management-patterns.md`.
- Don't import a feature widget into another feature. Once a second feature needs it and it holds no feature-specific imports, move it to `core/widgets/` and add it to `core-widgets.md`.

## Presentation utils (`features/<feature>/presentation/utils/`)
- `surah`: `mushaf_paper_colors.dart` (`MushafPaper` → colours), `printed_chrome_resolver.dart`, `current_ayah_notifier.dart`.
- `bookmarks`: `page_description.dart` (page → surah/ayah label).
- `ahadith`: `hadith_list_filter.dart`.
- `notifications`: `enum_localization.dart` (prayer, sound, minute and count labels, the alert summary, the alert icon, prayer-time and status-date labels, all with Arabic-Indic digits).

Enum `.localized()` and `.color` extensions go here too, as `enum_localization.dart` and `enum_colors.dart`, never in `domain/`.
