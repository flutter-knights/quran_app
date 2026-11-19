# Typography inventory

Measured on branch `refactor/typography-ts` at `e6a5e45f` (main), before any change. Source: every `*.dart` under `lib/` except `lib/generated/` and `lib/config/theme/typography_styles.dart`, with comments and strings masked.

## Baseline

- `fvm flutter analyze`: **233 issues** (info and warning only, no errors).
- `fvm flutter test`: **1419 passed, 0 failed**.
- `TextStyle(` constructions: 77
- `fontFamily:`: 2
- `fontSize:`: 96
- `fontWeight:`: 58
- `letterSpacing:`: 10
- `Theme.of(context).textTheme`: 11
- `Text(` calls with no `style:`: 21

The 79 `TextStyle(` hits in a plain grep are these constructions plus the one in `typography_styles.dart` and `DefaultTextStyle(` in `custom_app_bar.dart`.

## Raw `TextStyle(` constructions

A style with no `fontFamily` renders in the platform font today, because `toThemeData()` sets no `fontFamily`. A style with no `fontWeight` is regular (w400) for snapping. `FontWeight.bold` is w700. `-` means the property is not written.

| Family | Size | Weight | letterSpacing | Count | Files |
|---|---|---|---|---|---|
| (inherited) | 16 | - | - | 3 | app_list_skeleton.dart, daily_hadith_card.dart, mushaf_page_number_text.dart |
| (inherited) | 15 | - | - | 1 | ahadith_list_view.dart |
| (inherited) | 14 | - | - | 6 | ahadith_list_view.dart x2, chapter_picker_sheet.dart, home_skeleton.dart, surah_list_page_body.dart x2 |
| (inherited) | 13 | - | - | 1 | ayah_playback_overlay.dart |
| (inherited) | 12 | - | - | 2 | ahadith_list_view.dart, app_list_skeleton.dart |
| (inherited) | 11 | - | - | 3 | daily_hadith_card.dart x2, home_skeleton.dart |
| (inherited) | 10 | - | - | 4 | ayah_action_popover.dart, ayah_playback_overlay.dart, home_skeleton.dart x2 |
| (inherited) | - | - | - | 1 | bookmarks_page.dart |
| (inherited) | 14 | selected ? FontWeight.w700 : FontWeight.w500 | - | 1 | chapter_picker_sheet.dart |
| (inherited) | 13 | w500 | - | 1 | hadith_view.dart |
| (inherited) | 11 | w500 | - | 1 | hadith_book_list_item.dart |
| (inherited) | 10 | w500 | 0.5 | 1 | app_bar_center_title.dart |
| (inherited) | 18 | w600 | - | 1 | custom_app_bar.dart |
| (inherited) | 15 | w600 | - | 1 | mushaf_top_bar.dart |
| (inherited) | 14 | w600 | - | 3 | ahadith_list_view.dart, mushaf_top_bar.dart, search_results_view.dart |
| (inherited) | 13 | w600 | - | 1 | app_segmented_selector.dart |
| (inherited) | 12 | w600 | - | 9 | action_buttons_row.dart, ahadith_list_view.dart x4, ayah_playback_overlay.dart, juz_browse_list.dart, start_reading_card.dart, surah_list_tile.dart |
| (inherited) | 11 | w600 | - | 12 | ahadith_list_item.dart, ahadith_list_view.dart, ayah_result_tile.dart, bookmarks_page.dart x2, books_list_view.dart, daily_hadith_card.dart, hadith_view.dart, quick_access_grid.dart, search_results_view.dart x2, surah_list_page_body.dart |
| (inherited) | 11 | w600 | 0.3 | 1 | hadith_book_list_item.dart |
| (inherited) | 10.5 | w600 | - | 1 | last_read_card.dart |
| (inherited) | 10 | w600 | - | 1 | single_prayer_card.dart |
| (inherited) | 18 | w700 | - | 1 | playback_repeat_options.dart |
| (inherited) | 16 | w700 | - | 3 | ahadith_list_view.dart, chapter_picker_sheet.dart, custom_app_bar.dart |
| (inherited) | 14 | w700 | - | 2 | qibla_compass_dial.dart, search_results_view.dart |
| (inherited) | 13 | w700 | - | 1 | page_jumper_grid.dart |
| (inherited) | 13 | w700 | 0.5 | 1 | ahadith_list_item.dart |
| (inherited) | 12 | w700 | 1.2 | 1 | app_section_header.dart |
| (inherited) | 11 | w700 | - | 4 | app_status_badge.dart, hadith_book_list_item.dart, last_read_card.dart, palette_picker_widget.dart |
| (inherited) | 10.5 | w700 | - | 1 | last_read_card.dart |
| (inherited) | 10 | w700 | - | 1 | single_prayer_card.dart |
| (inherited) | 10 | w700 | 1 | 1 | labelled_accent_card.dart |
| (inherited) | footerFontSize | w700 | - | 1 | mushaf_printed_chrome.dart |
| (inherited) | 58 | w800 | - | 1 | home_skeleton.dart |
| (inherited) | 13 | w800 | - | 2 | juz_browse_list.dart, surah_list_tile.dart |
| QCF2BSML | surahFontSize | - | - | 1 | mushaf_printed_chrome.dart |
| QCF2BSML | juzFontSize | - | - | 1 | mushaf_printed_chrome.dart |

## `copyWith` overrides of size, weight or spacing on a token

The family is the token's (Cairo, or the `.scheherazade` / `.amiri` extension where the call chains one). Only the overridden properties are shown.

| Family | Size | Weight | letterSpacing | Count | Files |
|---|---|---|---|---|---|
| Cairo (token) | 40 | - | - | 1 | qibla_degree_readout.dart |
| Cairo (token) | 18 | - | - | 2 | hadith_view.dart, surah_list_tile.dart |
| Cairo (token) | 17 | - | - | 1 | hadith_book_list_item.dart |
| Cairo (token) | 16 | - | - | 1 | daily_hadith_card.dart |
| Cairo (token) | 15 | - | - | 3 | ahadith_list_item.dart, app_bar_center_title.dart, strip_preview.dart |
| Cairo (token) | 14 | - | - | 3 | bookmarks_page.dart x3 |
| Cairo (token) | 13 | - | - | 2 | strip_preview.dart x2 |
| Cairo (token) | 11 | - | - | 2 | home_view.dart, strip_preview.dart |
| Cairo (token) | fontSize | - | - | 1 | arabic_quote_block.dart |
| Cairo (token) | - | - | 0.4 | 1 | slogan_animation.dart |
| Cairo (token) | - | - | 1 | 1 | appearance_step.dart |
| Cairo (token) | - | - | 1.5 | 1 | welcome_step.dart |
| Cairo (token) | 20 | w700 | 0 | 1 | upcoming_prayer.dart |
| Cairo (token) | 11 | w700 | - | 1 | home_app_bar.dart |
| Cairo (token) | 46 | w800 | -1.5 | 1 | upcoming_prayer.dart |
| Cairo (token) | 18 | w800 | - | 1 | home_app_bar.dart |

## Font-family extensions

- `.amiri`: 2 (splash_page.dart:121, welcome_step.dart:30)
- `.cairo`: 9 (home_app_bar.dart:50, home_app_bar.dart:74, last_read_card.dart:105, last_read_card.dart:66, settings_page.dart:199, slogan_animation.dart:31, start_reading_card.dart:31, upcoming_prayer.dart:56, upcoming_prayer.dart:98)
- `.scheherazade`: 5 (ahadith_list_item.dart:53, arabic_quote_block.dart:24, ayah_result_tile.dart:55, daily_hadith_card.dart:122, home_view.dart:146)

## Material textTheme call sites

The 11 `Theme.of(context).textTheme.*` uses resolve to Material 3 `englishLike2021` values (read from the pinned SDK): titleMedium 16 w500, titleSmall 14 w500, labelMedium 12 w500, labelSmall 11 w500.

| Slot | Effective style | Count | Files |
|---|---|---|---|
| titleMedium | 16 w500 | 3 | page_jump_sheet.dart, reading_settings_sheet.dart, playback_repeat_options.dart |
| titleSmall | 14 w500 | 1 | ayah_playback_overlay.dart |
| labelMedium | 12 w500 | 6 | reading_settings_sheet.dart x3, ayah_playback_overlay.dart, playback_repeat_options.dart x2 |
| labelSmall | 11 w500 | 1 | playback_repeat_options.dart |

## New token

`medium12`: 12 w500 is used 6 times (every `labelMedium` site), and the nearest medium token before it was `medium14`, 2 pt away. No other size and weight met the rule (3 or more uses, no token within 1 pt).
