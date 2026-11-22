---
description: Feature widget rules and feature-level presentation utilities
paths: ["lib/features/**/presentation/**/*.dart", "lib/features/splash/**/*.dart"]
---

# Feature Widgets

- Feature widgets live beside the page that uses them: `features/<feature>/presentation/pages/**/widgets/` (e.g. `surah/presentation/pages/mushaf/widgets/`). `quran_playback` has no pages, so its widgets sit in `presentation/widgets/`.
- They read state with `BlocBuilder`/`BlocSelector` on their own feature's cubit (`MushafCubit`, `PlaybackCubit`), per `state-management-patterns.md`.
- Don't import a feature widget into another feature. Once a second feature needs it and it holds no feature-specific imports, move it to `core/widgets/` and add it to `core-widgets.md`.
  - Exception: `notifications` exports `AlertsPromptGate` (used by `home`), `OpenSettingButton` (used by `onboarding`); `quran_playback` exports `SurahDownloadButton` and `PlaybackOptionsSheet` (used by `surah`). `bookmarks` exports `PlacesSheet` (used by `surah`).

## Presentation utils (`features/<feature>/presentation/utils/`)
- `surah`: `mushaf_paper_colors.dart` (`MushafPaper` → colours, `ink2`, `leaf`, `ribbon(FasilSlot)` and `fasilRibbon`), `enum_localization.dart` (`MushafPaper.localized`), `current_ayah_notifier.dart`, `mushaf_args.dart` (`MushafArgs`, `MushafOrigin`), `page_bounds.dart` (`resolveRunningSurah`, `pagePlaybackRange`), `follow_playback.dart` (`nextFollowAction`, `followAfterManualTurn`), `reader_rules.dart` (`listenRange`, `playbackScope`, `lineBottomOf`, `leafSlide`, `mushafPageAspect`, `readerNotice`), `menu_query.dart` (`resolveMenuQuery`), `surah_caption.dart` (`surahCaption`: the «مكية، ٧ آيات» line of a surah, used by the القائمة rows and the ayah leaf banner).
- `quran_playback`: `presentation/audio/` holds the OS-facing playback layer: `QuranAudioHandler` and `connectMediaSession` (media notification and lock screen), `nowPlayingItem` (the `MediaItem`), `mediaArtUri` (notification art), `mapProcessingState`, and `PlaybackAudioFocus` with `connectAudioFocus` (pause on calls, the adhan and unplugging). `presentation/widgets/` also holds `SurahDownloadListener`, the app-level failure SnackBar and reciter refresh for `SurahDownloadCubit`, mounted once in `main.dart`'s `MaterialApp.builder`.
- `bookmarks`: `fasil_rules.dart` (`chooserPreselect`, `layoutTailTops`, `fasilRibbonX`), `enum_localization.dart` (`FasilSlot.localized`), `place_labels.dart` (`fasilName`, `ayahPlace`, `placeWhen`).
- `ahadith`: `hadith_list_filter.dart`.
- `notifications`: `enum_localization.dart` (prayer, sound, minute and count labels, the alert summary, the alert icon, prayer-time labels, the strip highlight, background and shape labels, all with Arabic-Indic digits), `calculation_method_localization.dart` (`CalculationMethod`/`AsrSchool` `.localized(context)`), `strip_style_colors.dart` (`StripStyle` → the strip's day and night ARGB style for native, plus the swatch helpers for option sheets and the shade, ink, next-text and muted colours the in-app strip preview mirrors from the native resources).

Enum `.localized()` and `.color` extensions go here too, as `enum_localization.dart` and `enum_colors.dart`, never in `domain/`.
