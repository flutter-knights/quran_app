# Typography snaps

Every raw style, `copyWith` size override and `Theme.of(context).textTheme.*` call site moved onto a `TS` token. Rule: same weight tier first, then the nearest size, the larger one when halfway. A change over 2 pt, or of weight tier, is marked **REVIEW**. No snap changed a weight tier.

## Review list (moved more than 2 pt)

| File | Before | After | Change |
|---|---|---|---|
| home/presentation/pages/widgets/upcoming_prayer.dart | 46 w800, letterSpacing -1.5 | TS.extra36 | -10 pt |
| qibla/presentation/pages/widgets/qibla_degree_readout.dart | 40 bold token | TS.bold32 | -8 pt |
| core/widgets/design/home_skeleton.dart | 58 w800 | TS.extra36 | -22 pt |
| surah_list/juz_browse_list.dart | 13 w800 | TS.extra16 | +3 pt |
| surah_list/surah_list_tile.dart | 13 w800 | TS.extra16 | +3 pt |

## All snaps applied by script

| File | Before | After | Change |
|---|---|---|---|
| ahadith/presentation/pages/widgets/ahadith_list_item.dart | 11 w600 | TS.semi12 | +1 pt |
| ahadith/presentation/pages/widgets/ahadith_list_item.dart | 13 w700, letterSpacing 0.5 | TS.bold14 | +1 pt |
| ahadith/presentation/pages/widgets/ahadith_list_view.dart | 12 w600 | TS.semi12 | +0 pt |
| ahadith/presentation/pages/widgets/ahadith_list_view.dart | 14 w600 | TS.semi14 | +0 pt |
| ahadith/presentation/pages/widgets/ahadith_list_view.dart | 12 w600 | TS.semi12 | +0 pt |
| ahadith/presentation/pages/widgets/ahadith_list_view.dart | 12 w600 | TS.semi12 | +0 pt |
| ahadith/presentation/pages/widgets/ahadith_list_view.dart | 16 w700 | TS.bold16 | +0 pt |
| ahadith/presentation/pages/widgets/ahadith_list_view.dart | 12 w600 | TS.semi12 | +0 pt |
| ahadith/presentation/pages/widgets/ahadith_list_view.dart | 14 (inherited) | TS.regular14 | +0 pt |
| ahadith/presentation/pages/widgets/ahadith_list_view.dart | 14 (inherited) | TS.regular14 | +0 pt |
| ahadith/presentation/pages/widgets/ahadith_list_view.dart | 12 (inherited) | TS.regular12 | +0 pt |
| ahadith/presentation/pages/widgets/ahadith_list_view.dart | 15 (inherited) | TS.regular15 | +0 pt |
| ahadith/presentation/pages/widgets/ahadith_list_view.dart | 11 w600 | TS.semi12 | +1 pt |
| ahadith/presentation/pages/widgets/books_list_view.dart | 11 w600 | TS.semi12 | +1 pt |
| ahadith/presentation/pages/widgets/chapter_picker_sheet.dart | 14 (inherited) | TS.regular14 | +0 pt |
| ahadith/presentation/pages/widgets/chapter_picker_sheet.dart | 16 w700 | TS.bold16 | +0 pt |
| ahadith/presentation/pages/widgets/daily_hadith_card.dart | 11 w600 | TS.semi12 | +1 pt |
| ahadith/presentation/pages/widgets/daily_hadith_card.dart | 16 (inherited) | TS.regular16 | +0 pt |
| ahadith/presentation/pages/widgets/daily_hadith_card.dart | 11 (inherited) | TS.regular12 | +1 pt |
| ahadith/presentation/pages/widgets/daily_hadith_card.dart | 11 (inherited) | TS.regular12 | +1 pt |
| ahadith/presentation/pages/widgets/hadith_book_list_item.dart | 11 w700 | TS.bold12 | +1 pt |
| ahadith/presentation/pages/widgets/hadith_book_list_item.dart | 11 w500 | TS.medium12 | +1 pt |
| ahadith/presentation/pages/widgets/hadith_book_list_item.dart | 11 w600, letterSpacing 0.3 | TS.semi12 | +1 pt |
| ahadith/presentation/pages/widgets/hadith_book_list_item.dart | 17 bold token | TS.bold16 | -1 pt |
| ahadith/presentation/pages/widgets/hadith_view.dart | 13 w500 | TS.medium14 | +1 pt |
| ahadith/presentation/pages/widgets/hadith_view.dart | 11 w600 | TS.semi12 | +1 pt |
| ahadith/presentation/pages/widgets/hadith_view.dart | 18 bold token | TS.bold20 | +2 pt |
| bookmarks/presentation/pages/bookmarks_page.dart | 11 w600 | TS.semi12 | +1 pt |
| bookmarks/presentation/pages/bookmarks_page.dart | 11 w600 | TS.semi12 | +1 pt |
| bookmarks/presentation/pages/bookmarks_page.dart | 14 bold token | TS.bold14 | +0 pt |
| bookmarks/presentation/pages/bookmarks_page.dart | 14 bold token | TS.bold14 | +0 pt |
| bookmarks/presentation/pages/bookmarks_page.dart | 14 bold token | TS.bold14 | +0 pt |
| home/presentation/pages/widgets/home_app_bar.dart | 18 w800 | TS.extra20 | +2 pt |
| home/presentation/pages/widgets/last_read_card.dart | 11 w700 | TS.bold12 | +1 pt |
| home/presentation/pages/widgets/last_read_card.dart | 10.5 w600 | TS.semi12 | +1.5 pt |
| home/presentation/pages/widgets/last_read_card.dart | 10.5 w700 | TS.bold12 | +1.5 pt |
| home/presentation/pages/widgets/quick_access_grid.dart | 11 w600 | TS.semi12 | +1 pt |
| home/presentation/pages/widgets/single_prayer_card.dart | 10 w700 | TS.bold12 | +2 pt |
| home/presentation/pages/widgets/single_prayer_card.dart | 10 w600 | TS.semi12 | +2 pt |
| home/presentation/pages/widgets/upcoming_prayer.dart | 46 w800, letterSpacing -1.5 | TS.extra36 | -10 pt |
| qibla/presentation/pages/widgets/qibla_compass_dial.dart | 14 w700 | TS.bold14 | +0 pt |
| qibla/presentation/pages/widgets/qibla_degree_readout.dart | 40 bold token | TS.bold32 | -8 pt |
| quran_playback/presentation/widgets/playback_repeat_options.dart | 18 bold | TS.bold20 | +2 pt |
| settings/presentation/pages/widgets/palette_picker_widget.dart | 11 w700 | TS.bold12 | +1 pt |
| surah/presentation/pages/mushaf/widgets/ayah_action_popover.dart | 10 (inherited) | TS.regular10 | +0 pt |
| surah/presentation/pages/mushaf/widgets/ayah_playback_overlay.dart | 13 (inherited) | TS.regular14 | +1 pt |
| surah/presentation/pages/mushaf/widgets/ayah_playback_overlay.dart | 10 (inherited) | TS.regular10 | +0 pt |
| surah/presentation/pages/mushaf/widgets/ayah_playback_overlay.dart | 12 w600 | TS.semi12 | +0 pt |

## All snaps applied by hand

| File | Before | After | Change | Note |
|---|---|---|---|---|
| core/widgets/custom_app_bar.dart | 18 w600 | TS.semi20 | +2 pt |  |
| core/widgets/custom_app_bar.dart | 16 bold | TS.bold16 | +0 pt |  |
| core/widgets/design/labelled_accent_card.dart | 10 w700, letterSpacing 1 | TS.bold12 | +2 pt | letterSpacing dropped |
| core/widgets/design/app_list_skeleton.dart | 16 / 12 regular | TS.regular16 / TS.regular12 | +0 pt |  |
| core/widgets/design/action_buttons_row.dart | 12 w600 | TS.semi12 | +0 pt |  |
| core/widgets/design/app_segmented_selector.dart | 13 w600 | TS.semi12 | -1 pt | exception to the tie rule: TS.semi14 overflowed the settings selector row by 2 px at 360 dp (settings_page_test caught it) |
| core/widgets/design/app_section_header.dart | 12 w700, letterSpacing 1.2 | TS.bold12 | +0 pt | letterSpacing dropped |
| core/widgets/design/app_status_badge.dart | 11 w700 | TS.bold12 | +1 pt |  |
| core/widgets/design/app_bar_center_title.dart | 10 w500, letterSpacing 0.5 | TS.medium12 | +2 pt | letterSpacing dropped |
| core/widgets/design/app_bar_center_title.dart | bold16 copyWith 15 | TS.bold16 | +1 pt | tie, larger |
| core/widgets/design/home_skeleton.dart | 14 / 10 regular | TS.regular14 / TS.regular10 | +0 pt |  |
| core/widgets/design/home_skeleton.dart | 11 regular | TS.regular12 | +1 pt | tie, larger |
| core/widgets/design/home_skeleton.dart | 58 w800 | TS.extra36 | -22 pt | skeleton placeholder, no token above 36 |
| surah_list/page_jumper_grid.dart | 13 w700 | TS.bold14 | +1 pt | tie, larger |
| surah_list/juz_browse_list.dart | 13 w800 | TS.extra16 | +3 pt | smallest extra token is 16 |
| surah_list/juz_browse_list.dart | 12 w600 | TS.semi12 | +0 pt |  |
| surah_list/ayah_result_tile.dart | 11 w600 | TS.semi12 | +1 pt |  |
| surah_list/start_reading_card.dart | 12 w600 | TS.semi12 | +0 pt |  |
| surah_list/surah_list_tile.dart | bold16 copyWith 18 | TS.bold20 | +2 pt | tie, larger |
| surah_list/surah_list_tile.dart | 12 w600 | TS.semi12 | +0 pt |  |
| surah_list/surah_list_tile.dart | 13 w800 | TS.extra16 | +3 pt | smallest extra token is 16 |
| surah_list/search_results_view.dart | 14 w600 / 14 w700 | TS.semi14 / TS.bold14 | +0 pt |  |
| surah_list/search_results_view.dart | 11 w600 (x2) | TS.semi12 | +1 pt |  |
| surah_list/surah_list_page_body.dart | 11 w600 | TS.semi12 | +1 pt |  |
| surah_list/surah_list_page_body.dart | 14 regular (field + hint) | TS.regular14 | +0 pt |  |
| mushaf/mushaf_page_number_text.dart | 16 regular | TS.regular16 | +0 pt |  |
| mushaf/mushaf_top_bar.dart | 15 w600 | TS.semi16 | +1 pt | tie, larger |
| mushaf/mushaf_top_bar.dart | 14 w600 | TS.semi14 | +0 pt |  |
| mushaf/mushaf_printed_chrome.dart | footer: runtime 9-12 w700 | TS.bold12.copyWith(fontSize: footerFontSize) | +0 pt | runtime size |
| mushaf/page_jump_sheet.dart | textTheme.titleMedium (16 w500) | TS.medium16 | +0 pt |  |
| mushaf/reading_settings_sheet.dart | titleMedium (16 w500); labelMedium (12 w500) x3 | TS.medium16; TS.medium12 | +0 pt |  |
| mushaf/ayah_playback_overlay.dart | titleSmall (14 w500); labelMedium (12 w500) | TS.medium14; TS.medium12 | +0 pt |  |
| quran_playback/playback_repeat_options.dart | labelMedium (12 w500) x2; titleMedium (16 w500) | TS.medium12; TS.medium16 | +0 pt |  |
| quran_playback/playback_repeat_options.dart | labelSmall (11 w500) | TS.medium12 | +1 pt |  |
| bookmarks/bookmarks_page.dart | no size (inherits Material bodyMedium 14 w400) | TS.regular14 | +0 pt |  |
| ahadith/chapter_picker_sheet.dart | 14, w700 when selected else w500 | (selected ? TS.bold14 : TS.medium14) | +0 pt |  |
| home/home_app_bar.dart | medium14 copyWith 11 w700 | TS.bold12 | +1 pt |  |
| home/upcoming_prayer.dart | periodStyle: 20 w700, letterSpacing 0 (derived from the hero style) | TS.bold20 | +0 pt | height and colour kept |

## Unstyled `Text` pinned to a token

Each inherited Material's default for its slot, which is exactly an existing token, so the pin changes nothing on screen. 14 body and SnackBar texts took `TS.regular14` (Material `bodyMedium`); 6 button labels took `TS.medium14` (`labelLarge`). `onboarding/alerts_step.dart:191` stays unstyled: its parent `ChoiceChip` already sets `labelStyle: TS.semi14`.

## letterSpacing

TS owns letter spacing, so raw `letterSpacing` was dropped where a raw style became a token: labelled_accent_card (1), app_section_header (1.2), app_bar_center_title (0.5), ahadith_list_item (0.5), hadith_book_list_item (0.3). Existing `copyWith(letterSpacing: ...)` overrides on tokens were left: upcoming_prayer hero (-1.5), appearance_step (1), welcome_step (1.5), slogan_animation (0.4).

## Kept as written (exceptions)

- Quran and hadith text: the `.scheherazade` and `.amiri` extensions (arabic_quote_block, ahadith_list_item, daily_hadith_card, home_view, ayah_result_tile, splash_page, welcome_step).
- Printed glyph font `QCF2BSML` in mushaf_printed_chrome.dart (the header glyphs keep their runtime sizes; the footer is `TS.bold12.copyWith(fontSize: footerFontSize)`).
- notifications/strip_preview.dart is untouched. It mirrors the native Android strip, whose layouts use 13 and 11 sp (collapsed) and 13, 14, 12 and 15 sp (expanded). Snapping the preview moved four sizes by 1 pt and it stopped matching the delivered notification, which the code review caught. Its four `copyWith(fontSize:)` overrides stay in the ratchet count.
- Native Android and iOS text is out of scope.
