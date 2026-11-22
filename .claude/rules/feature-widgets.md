---
description: Feature widget rules and feature-level presentation utilities
paths: ["lib/features/**/presentation/**/*.dart", "lib/features/splash/**/*.dart"]
---

# Feature Widgets

- Feature widgets live beside the page that uses them: `features/<feature>/presentation/pages/**/widgets/` (e.g. `surah/presentation/pages/mushaf/widgets/`). `quran_playback` has no pages, so its widgets sit in `presentation/widgets/`.
- They read state with `BlocBuilder`/`BlocSelector` on their own feature's cubit (`MushafCubit`, `PlaybackCubit`), per `state-management-patterns.md`.
- Don't import a feature widget into another feature. Once a second feature needs it and it holds no feature-specific imports, move it to `core/widgets/` and add it to `core-widgets.md`.
  - Exception: `notifications` exports `AlertsPromptGate` (used by `home`), `OpenSettingButton` (used by `onboarding`); `quran_playback` exports `SurahDownloadButton` and `PlaybackOptionsSheet` (used by `surah`). `bookmarks` exports `PlacesSheet`, `FasilRowSummary` (the swatch, name and position of a فاصل) and `placeTapTarget` (the 48 px tap-target `ButtonStyle`), all used by `surah`.
  - Deliberate two-way coupling: `surah` reads `bookmarks` (`FasilSlot`, the cubits, `fasil_rules.dart`, `place_notices.dart`), and `bookmarks` reads `surah`'s `mushaf_paper_colors.dart` for `fasilRibbon`, so the ribbon hexes live once, in the file `theming.md` allows. `bookmarks` swatches pass the app palette's brightness, because they sit on app surfaces, not on a reading paper. Don't add more.

## Presentation utils (`features/<feature>/presentation/utils/`)
- `surah`: `mushaf_paper_colors.dart` (`MushafPaper` → colours, `ink2`, `leaf`, `ribbon(FasilSlot)`, `ribbonShadow`, `fasilRibbon`, and `MushafPaperColors.paperButton()`: the paper-ink `ButtonStyle` every Text/Outlined button drawn on a reading paper must use, since the app theme's button ink follows the app palette, not the paper), `enum_localization.dart` (`MushafPaper.localized`), `current_ayah_notifier.dart`, `mushaf_args.dart` (`MushafArgs`, `MushafOrigin`), `page_bounds.dart` (`resolveRunningSurah`, `pagePlaybackRange`), `follow_playback.dart` (`nextFollowAction`, `followAfterManualTurn`), `reader_rules.dart` (`listenRange`, `playbackScope`, `lineBottomOf`, `firstLineOf`, `firstLineBottomOf`, `pageTextLeftOf`, `leafSlide`, `mushafPageAspect`, `readerNotice`), `menu_query.dart` (`resolveMenuQuery`), `surah_caption.dart` (`surahCaption`: the «مكية، ٧ آيات» line of a surah, used by the القائمة rows and the ayah leaf banner).
- `quran_playback`: `presentation/audio/` holds the OS-facing playback layer: `QuranAudioHandler` and `connectMediaSession` (media notification and lock screen), `nowPlayingItem` (the `MediaItem`), `mediaArtUri` (notification art), `mapProcessingState`, and `PlaybackAudioFocus` with `connectAudioFocus` (pause on calls, the adhan and unplugging). `presentation/widgets/` also holds `SurahDownloadListener`, the app-level failure SnackBar and reciter refresh for `SurahDownloadCubit`, mounted once in `main.dart`'s `MaterialApp.builder`.
- `bookmarks`: `fasil_rules.dart` (`chooserPreselect`, `layoutTailTops`, `fasilTails`, `FasilGeometry`: ribbon and tab sizes derived from the page's text margin), `enum_localization.dart` (`FasilSlot.localized`), `place_labels.dart` (`fasilName`, `ayahPlace`, `placeWhen`), `place_notices.dart` (`showPlaceNotice` with undo, `showPlaceWriteError`).
- `ahadith`: `hadith_list_filter.dart`.
- `notifications`: `enum_localization.dart` (prayer, sound, minute and count labels, the alert summary, the alert icon, prayer-time labels, the strip highlight, background and shape labels, all with Arabic-Indic digits), `calculation_method_localization.dart` (`CalculationMethod`/`AsrSchool` `.localized(context)`), `strip_style_colors.dart` (`StripStyle` → the strip's day and night ARGB style for native, plus the swatch helpers for option sheets and the shade, ink, next-text and muted colours the in-app strip preview mirrors from the native resources).

Enum `.localized()` and `.color` extensions go here too, as `enum_localization.dart` and `enum_colors.dart`, never in `domain/`.
