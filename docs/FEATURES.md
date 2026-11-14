# Feature Inventory

Snapshot of every feature on `main` after the November 2026 branch consolidation, from a read-only code audit (one reviewer per area, plus a completeness check). Statuses come from reading the code, not from running every flow on a device. Confirm each one with its manual checks before you build on it. A second reviewer re-read the code for all 8 high-severity issues and confirmed each one.

| Feature | Status | High | Medium | Low | Unbuilt plan items |
|---|---|---|---|---|---|
| [Mushaf reader](#mushaf-reader) | 🟡 Partial | 0 | 5 | 8 | 14 |
| [surah-list-and-last-read](#surah-list-and-last-read) | ✅ Working | 0 | 2 | 10 | 7 |
| [quran-playback](#quran-playback) | 🟡 Partial | 2 | 5 | 7 | 10 |
| [Bookmarks](#bookmarks) | ✅ Working | 0 | 4 | 9 | 6 |
| [Quran search](#quran-search) | ✅ Working | 0 | 3 | 7 | 8 |
| [Ahadith](#ahadith) | 🟡 Partial | 2 | 6 | 8 | 7 |
| [home-and-prayer-times](#home-and-prayer-times) | 🟡 Partial | 1 | 5 | 8 | 5 |
| [notifications-adhan-native](#notifications-adhan-native) | 🟡 Partial | 2 | 5 | 8 | 11 |
| [Qibla finder](#qibla-finder) | 🟡 Partial | 0 | 4 | 11 | 4 |
| [settings-and-theming](#settings-and-theming) | ✅ Working | 0 | 3 | 9 | 6 |
| [onboarding-splash-permissions](#onboarding-splash-permissions) | 🟡 Partial | 1 | 3 | 8 | 8 |

## Mushaf reader

**Status:** 🟡 Partial

The Mushaf screen works and you can reach it from about 9 places in the app. It shows 604 printed-page images with highlighted, tappable verses, page-by-page or continuous-scroll reading, six paper themes with a brightness setting, a top bar with page jump, a play / save-page bar, a long-press verse menu, and a recitation mini-player. The main gap is that the mini-player can vanish while audio keeps playing once recitation turns the page. Tafsir, translation, keeping the player from covering the verse, and a surah/juz index are still unbuilt.

### What it does
- Open the Mushaf at a page. /mushaf is registered in lib/config/router/app_router.dart, MushafCubit is a factory in mushaf_di.dart via initMushaf() in core/di/dependency_injection.dart, and it is pushed from the surah list, juz list, page grid, start-reading card, search suggestions, the home and surah-list last-read card, and the bookmarks page (ayah and page tiles).
- Open the Mushaf at a specific verse from an ayah search result. ayah_result_tile passes MushafArgs.focusAyah, and the router calls toggleHighlight when ayah > 0.
- Resume the last-read position: the last-read verse is re-highlighted when you open its page. The position is saved on page change (800 ms debounce), on pause/inactive, and on dispose (LastReadSaver plus LastReadCubit, provided app-wide in main.dart).
- Swipe pages right-to-left in page mode (PageView with 604 items), or read in continuous vertical scroll. Landscape always forces scroll mode (_effectiveMode).
- Tap the page to show the chrome. With the chrome visible, tap a verse to highlight it and open the mini-player, or tap empty space to hide the chrome; this also unpins the player if audio is idle (MushafPageView._handleTap).
- Long-press any verse to open a popover: Bookmark (toggles the ayah bookmark through the app-wide BookmarkCubit), Share (share_plus with the verse text and surah:ayah), and Tafsir / Translation (both show a 'coming soon' snackbar only).
- Top bar: back button, surah name (Arabic or English by locale), and the page number. Tapping the number opens PageJumpSheet (Western digits 1-604, clamped), which jumps in either mode.
- Browse bar (shown with the chrome when no verse is selected): open reading settings, play the page from its first verse (or basmala) to the end of that surah through PlaybackCubit.playRange, and toggle a page bookmark.
- Saved pages show a ribbon in the top corner. Tapping the ribbon removes the bookmark and shows a snackbar with Undo. Saved pages are listed under 'Pages' in the Bookmarks screen with a describePage() label.
- Reading settings sheet (from the browse bar, and also from the Settings page): six paper themes, page brightness 0.3-1.0 with the sheet body fading while you drag, and page/scroll mode through AppSegmentedSelector. All persist through SettingsCubit (HydratedCubit).
- Mini-player: previous / play-pause-resume / next, swipe down or chevron to dismiss, tap the info area for the reciter picker, and tap tune for speed (0.5x-2x) and repeat/range options (PlaybackRepeatOptions).
- During playback the playing verse is highlighted. If the playing verse was also the selected verse, the selection follows it. The view auto-turns or auto-scrolls to the page of the playing verse (computeAutoSwapTargetIndex).
- Printed header band (surah and juz names in QCF2BSML glyphs) and a page-number ornament are drawn on the page in page mode only. Neighbouring page images are precached (±1).

### Entry points
- /mushaf (GoRoute in lib/config/router/app_router.dart; extra is an int page or MushafArgs{page, focusAyah})
- /mushafImage (duplicate route with no callers)
- Home: LastReadCard (lib/features/home/presentation/pages/widgets/last_read_card.dart)
- Surah list: surah_list_tile, juz_browse_list, page_jumper_grid, start_reading_card, search_results_view (page suggestions), ayah_result_tile (MushafArgs with focusAyah), LastReadCard in surah_list_page_body
- Bookmarks page: ayah bookmark tiles and the Pages section (lib/features/bookmarks/presentation/pages/bookmarks_page.dart)
- Settings page Mushaf section opens ReadingSettingsSheet (lib/features/settings/presentation/pages/settings_page.dart)

### Tests
These tests exist under test/features/surah/presentation. MushafCubit has auto-follow, clear-highlight, chrome-toggle and setPage/pin tests (cubit/mushaf/*, cubit/mushaf_chrome_test.dart, and cubit/mushaf_image/mushaf_image_cubit_test.dart, which tests the current MushafCubit under an old name). There are unit tests for the CurrentAyahNotifier basmala mapping, printed_chrome_resolver, mushaf_paper_colors, LastReadSaver timing, computeAutoSwapTargetIndex, and popoverPlacement (the pure function only). Widget tests cover AyahPlaybackOverlay (11 cases, with a fake MushafCubit whose setPage is a no-op), ReadingSettingsSheet (paper, mode and brightness fade), MushafTopBar, MushafBrowseBar, PageJumpSheet (clamping and empty input), MushafPrintedChrome, MushafPageRibbon, and a MushafPage dispose test (saves last-read and stops playback). Data and domain tests cover MushafPageModel, the entities, the repo and GetMushafPage. Bookmarks has tests for the page-bookmark data source, repo, cubit, state and describePage. The brightness test is a tautology. Untested: MushafPageView (hit-testing, tap and chrome logic, long-press, ribbon tap with undo, scrim); AyahActionPopover.show and its bookmark/share actions; MushafPage composition (browse bar and player mutual exclusion, auto-swap followed by the highlight clearing, page jump in both modes, scroll-mode offset math, rotation, _onPlayPage); the focusAyah route path; and the basmala/ayah-0 edge cases. CLAUDE notes in the plans warn that the full test suite rewrites assets through test/tools (generate_mushaf_assets_test), so tests should be run scoped. Nothing was executed for this audit.

### Known issues
- **MEDIUM** `lib/features/surah/presentation/cubit/mushaf/mushaf_cubit.dart`: The mini-player disappears at the first automatic page turn during playback. setPage() always calls copyWith(clearHighlighted: true). Auto-swap reaches setPage in both modes: in page mode, _pageController.animateToPage → PageView.onPageChanged → setPage; in scroll mode, _scrollController.animateTo → _onScroll → setPage. AyahPlaybackOverlay and the browse bar decide visibility only from highlightedAyah != null || isOverlayPinned (mushaf_page.dart lines ~357-363, ayah_playback_overlay.dart ~76-79), and pinOverlay() is only called when getFirstAyahOfPage returns null. So after a verse-tap play or a browse-bar Play, the first page turn hides the player while audio continues, follow-highlighting stops, and the browse bar (with its Play button) can reappear. This contradicts control-surface spec A1, where playerActive includes playingAyah != null and the player 'persists through playback'. It is untested: the overlay and dispose tests use fake cubits whose setPage is a no-op. Verified in code; not observed at runtime.
- **MEDIUM** `lib/features/surah/presentation/pages/mushaf/widgets/mushaf_page_view.dart`: Long-pressing the basmala line opens the verse popover for ayah 0. 96 bounds files contain {"ayah":0} basmala rects, and _hitTest returns them. AyahActionPopover has no ayah-0 guard. Share calls quran.getVerse(s, 0), which throws, because quranData has no verse 0; the catch then shows 'share failed'. Bookmark saves (s, 0) through BookmarkCubit, and the Bookmarks page lists it as 's : ٠'. Tapping the basmala also shows the mini-player label 'Surah s, Ayah 0'.
- **MEDIUM** `lib/features/surah/presentation/pages/mushaf/widgets/ayah_action_popover.dart`: The popover is inserted with Overlay.of(context), the navigator's overlay, as a free OverlayEntry that is not tied to the route. It closes only on an outside tap or when the MushafCubit stream reports a page change. If the user presses system back while it is open, the route pops and the cubit closes without emitting, so the card and its full-screen barrier stay on top of the previous screen until tapped. Scrolling within the same page in scroll mode also leaves the card at a stale position; the reading-controls spec requires dismiss on scroll. Inferred from code, not reproduced.
- **MEDIUM** `lib/features/quran_playback/playback_di.dart`: This race predates the merge (January commit 51677137). initPlayback is declared `void initPlayback() async` and awaits getApplicationDocumentsDirectory() before it registers QuranPlaybackRepo and PlaybackCubit, and initGetIt() does not await it. main.dart builds MultiBlocProvider(sl<PlaybackCubit>()) right after initGetIt completes, and CurrentAyahNotifier (mushaf_di) resolves sl<PlaybackCubit>() lazily. If the platform call has not returned by the first build, the lookup fails as not registered. This is a latent race, not an observed crash.
- **MEDIUM** `lib/features/surah/presentation/pages/mushaf/widgets/mushaf_page_view.dart`: A bounds-JSON load failure is silent. _entityFuture throws a StateError on Left, and FutureBuilder ignores snapshot.error. With entity == null, neither the GestureDetector nor the highlight painter is built, so on that page taps do nothing (the chrome cannot even be toggled) and no error or retry UI appears.

<details><summary>Low-severity notes (8)</summary>

- `lib/config/router/app_router.dart`: The /mushafImage route (mushafImagePath) duplicates the /mushaf builder line for line and has no callers in lib. It is a leftover of the 2026-05-15 debug route from the image-rendering plan (Task 'add /mushafImage debug route'), not of the qibla merge.
- `lib/features/surah/presentation/pages/mushaf/widgets/mushaf_page_number_text.dart`: Dead code. MushafPageNumberText has no references. MushafPaperX.label (hard-coded Arabic paper names in utils/mushaf_paper_colors.dart) is used only by a test, and the settings sheet shows unlabeled swatches. QuranMetaService (hizb/rub) is registered in playback_di but no widget uses it. lib/core/widgets/last_quran_read.dart (LastQuranRead) is unused; home and the surah list use LastReadCard.
- `lib/features/surah/presentation/cubit/mushaf/mushaf_state.dart`: Dead state. highlightedAyahCenterY is written on every highlight through setHighlightBounds (a post-frame emit from MushafPageView) but never read. The overlay is always pinned to the bottom, so a highlighted verse near the bottom of the page can sit under the mini-player. Each highlight change also costs an extra emit and rebuild.
- `lib/features/surah/presentation/pages/mushaf/widgets/page_jump_sheet.dart`: Arabic-Indic digits are rejected. FilteringTextInputFormatter.digitsOnly allows only [0-9], and int.tryParse would not accept ٠-٩ anyway, so a keyboard that types Arabic-Indic digits cannot enter a page; spec A2 requires accepting them. The hint '1 – 604' is a hard-coded, unlocalized string. The top bar also omits the juz that spec A2 lists.
- `lib/features/surah/presentation/pages/mushaf/widgets/mushaf_browse_bar.dart`: Accessibility and localization gaps. The browse-bar buttons (settings, play, save) are icon-only GestureDetectors with no Tooltip or Semantics label. The top-bar back IconButton has no tooltip. The paper swatches in reading_settings_sheet.dart have no labels. Reciter names in the player and reciter sheet always show Reciter.arabicName, which is the only name field on the enum, so English users see Arabic. The juz-glyph fallback 'الجزء $juz' in printed_chrome_resolver.dart is hard-coded Arabic.
- `lib/features/surah/presentation/pages/mushaf/widgets/reading_settings_sheet.dart`: The brightness preview only partly matches spec A5. The sheet sets backgroundColor: colorScheme.surface, and only the inner body fades to 0.12 opacity, so the opaque sheet surface still covers the lower part of the page while you drag. The code comment says 'background... transparent', but only the barrier is.
- `lib/features/surah/presentation/pages/mushaf/widgets/mushaf_page_ribbon.dart`: The ribbon uses PositionedDirectional(end: 18). Page mode is wrapped in RTL Directionality but the scroll-mode ListView is not, so with the English locale the ribbon switches from the left corner to the right when you change mode. The spec's 'settle animation when a page is saved' is not implemented; the ribbon has no animation.
- `test/features/surah/presentation/pages/mushaf/widgets/mushaf_page_view_brightness_test.dart`: This test is a tautology. It defines its own local scrimAlpha() function and asserts arithmetic on it, without rendering MushafPageView or reading the 'page-brightness-scrim' key, so it gives no coverage of the feature. The tests named mushaf_image_* actually test the current MushafCubit, MushafPageModel and entities; only the names are stale, and their imports resolve.

</details>

### Planned but not built
- Tafsir: none of Phase 4 is built. There is no lib/features/tafsir, no TafsirSheet and no bundled Muyassar data, and the popover's Tafsir button only shows a 'coming soon' snackbar (2026-05-31-mushaf-reading-experience-design.md §Phase 4; no plan file exists for Phase 4).
- Translation is a 'coming soon' placeholder only (2026-05-29-mushaf-reading-controls-design.md §E; explicitly out of v1 scope in the reading-experience spec).
- Keeping the player off the verse in page mode is not built: no AnimatedPadding or scaling of the page above the player, and highlightedAyahCenterY is never read (2026-05-31-mushaf-phase2-overlay-aware-playback.md Task 7; reading-experience spec §2.5).
- In scroll mode the view does not auto-scroll to keep the active verse centered above the player; only page-level auto-swap exists (reading-experience spec §2.5 and §3.2; deferred in the phase-2 plan's self-review).
- Placing the mini-player top or bottom opposite the active verse is not built (2026-05-29 reading-controls spec §A/§F; reading-experience spec §2.3).
- The mini-player redesign extras are missing: no replay button and no ayah progress bar (reading-experience spec §2.3). The overlay has only previous/play/next plus info and tune.
- The index sheet (jump by surah or juz, showing hizb/rub) is not built. Only a page-number jump exists, and QuranMetaService has no UI consumer (reading-experience spec §1.4; 2026-05-29 reading-controls spec §B/§D for the hizb/rub display).
- Scroll-mode page separators ('··· صفحة N ···') and the floating current-page pill are not built; scroll mode shows a tinted 4 px gap and no page numbers (reading-experience spec §3.2; no Phase 3 plan file exists).
- Control-surface A1: the playerActive rule including playingAyah != null is not implemented (2026-06-13-mushaf-control-surface-design.md §A1).
- Control-surface A2: the page jump does not accept Arabic-Indic digits, has no slider, and the top bar omits the juz (2026-06-13-mushaf-control-surface-design.md §A2; phase1-chrome plan Task 1/2).
- Control-surface A5: the sheet background was not made transparent (it uses scheme.surface) (2026-06-13-mushaf-control-surface-design.md §A5; phase2-settings-sheet plan Task 2).
- Control-surface A6: the ribbon has no 'settle' animation (2026-06-13-mushaf-control-surface-design.md §Design quality).
- The spec's widget test that the browse bar and player are never visible together, and the page-jump-moves-controller test, do not exist (2026-06-13-mushaf-control-surface-design.md §Testing).
- Note: the plan checkboxes are all unticked even for work that is built, so they are not evidence either way. Superseded rather than unbuilt: the rendering-leak span/font caches (2026-05-14, replaced by image rendering), AyahActionBar (2026-05-15 verse-tap, replaced by the popover and overlay), MushafBottomBar, MushafActionDock, and the 'Copy text' and 'Play from here' items of the 2026-05-15 image-rendering long-press sheet.

### Manual checks on a device
- [ ] Main defect check, page mode. Portrait, page mode, open a page near the end of a surah's page (for example page 2), tap the chrome on, tap the last verse on the page, and press play in the mini-player. When recitation reaches the next page and the view auto-turns, check whether the mini-player stays visible and the highlight keeps following. Per the code it is expected to hide while audio continues.
- [ ] Repeat the previous check in scroll mode, or in landscape, and also with the browse-bar Play button.
- [ ] Long-press the basmala line on page 2 (Al-Baqarah). The popover should not offer bookmark or share for 'ayah 0'. Currently Share shows 'share failed' and Bookmark adds a '2 : ٠' entry to the Bookmarks page.
- [ ] Long-press a verse so the popover opens, then press Android system back (or swipe back on iOS). Check that the popover does not remain over the previous screen.
- [ ] From Home, open the last-read card. You should land on the saved page with the last verse highlighted. Swipe two pages, background the app, and kill it. On relaunch the card should show the new page.
- [ ] From Surah list, search for a verse and tap an ayah result. The Mushaf should open on the right page with that verse highlighted.
- [ ] Tap the page number in the top bar, enter 300 and press Go: it should jump in page mode, then in scroll mode. Enter 999 and it should clamp to 604. On an Arabic-digit keyboard, try typing ٣٠٠ (currently filtered out).
- [ ] Open reading settings from the browse bar. Cycle the six papers and check that page, ink and accent colours change. Drag brightness and confirm the page dims live while the sheet body fades. Switch Page and Scroll and confirm the reading mode changes with the same page kept.
- [ ] Rotate to landscape: it should switch to continuous scroll on the same page, and the printed header and footer should be hidden. Rotate back: it should return to page mode on the current page.
- [ ] Tap the save (bookmark) icon in the browse bar: a ribbon appears on the page, and Bookmarks > Pages lists the page with its surah/ayah description. Tap the ribbon: it is removed, and Undo restores it. In English, check whether the ribbon side differs between page and scroll mode.
- [ ] With the player open, use the tune options to change speed and repeat, and tap the info area to change the reciter. Confirm that a verse highlighted near the bottom of the page may be covered by the player (an unbuilt feature).
- [ ] Tap Tafsir and Translation in the long-press popover. Both should show only a 'coming soon' snackbar.
- [ ] Open the Mushaf from Settings > Mushaf section and change paper and brightness there. Reopen the Mushaf and confirm the settings persisted.

### Enhancement ideas
- Base player visibility on highlightedAyah != null || isOverlayPinned || playingAyah != null, as spec A1 defines it. Alternatively, have setPage keep the highlight when highlightedAyah == playingAyah, so follow mode survives automatic page turns.
- Have _hitTest ignore ayah 0 for long-press, or have the popover disable Share and Bookmark for the basmala.
- Tie the popover to the route, for example with a PopScope or RouteAware listener, or use showDialog/ModalRoute instead of a free OverlayEntry, so it closes on back and on scroll.
- Turn initPlayback into a Future and await it in initGetIt.
- Use highlightedAyahCenterY to anchor the player at the top when the verse sits in the lower part of the page, or add the planned AnimatedPadding that shrinks the page above the player.
- Normalise Arabic-Indic digits in PageJumpSheet before parsing, and localize the hint text.
- Delete /mushafImage, MushafPageNumberText, MushafPaperX.label (or show it localized under the swatches) and LastQuranRead. Replace the tautological brightness test with a widget test that finds the 'page-brightness-scrim' key.
- Show a retry state in MushafPageView when the bounds JSON fails to load.
- Add Semantics/Tooltip labels to the browse-bar buttons, the top-bar back button and the paper swatches. Add an English reciter name to the Reciter enum.

## surah-list-and-last-read

**Status:** ✅ Working

The Quran index screen works and is reachable. It has a search box over surah names, ayah text and page or juz numbers, plus Surah, Juz and Page tabs that open the mushaf at the right place. Your reading position is saved while you read and shown as a "continue reading" card on Home and on this screen. The issues found are polish, test gaps and leftovers: an old duplicate continue-reading widget, hardcoded Arabic text in the surah rows, and no loading skeleton for search. Nothing high-severity turned up.

### What it does
- Open the Quran index from the Home quick-access tile 'Quran' (quick_access_grid.dart:22-26 pushes AppRouter.surahListPath). The route at app_router.dart:114-125 provides SurahCubit()..fetchSurahs() and SearchCubit, both registered in DI (surah_list_di.dart, search_di.dart, called from dependency_injection.dart:26-27).
- Browse all 114 surahs (Surah tab, the default) as tiles showing the name, Makki/Madani, ayah count, start page and number. Tapping a tile opens /mushaf at surah.pageNumber (surah_list_tile.dart:21-22). The list loads from assets/json/surah_list.json, with AppListSkeleton shown while the list is empty (surah_list_page_body.dart:119-121).
- Tap the play icon on a surah tile to start playback from ayah 1 of that surah and open the mushaf (surah_list_tile.dart:61-66, PlaybackCubit.playFromAyah).
- Switch to the Juz tab: a list of the 30 ajzaʼ, each with its first and last surah name; tapping opens the juz's first page (juz_browse_list.dart).
- Switch to the Page tab: a 6-column grid of pages 1-604; tapping opens that page (page_jumper_grid.dart).
- Type in the fixed search field (debounced 200 ms, search_cubit.dart). Results replace the browse view and are grouped as: page/juz jump suggestions for a numeric query (page 1-604, juz 1-30), surah matches by Arabic name, English name or number substring, and up to 100 ayah-text matches. Each ayah result shows surah · ayah label · page, and a '+N more — refine your search' footer appears when results are capped. The clear (x) button returns to browse mode, and the browse tabs are hidden while searching.
- Tap an ayah search result to open /mushaf with MushafArgs(page, focusAyah). The route calls cubit.toggleHighlight(focus) (ayah_result_tile.dart:31-38, app_router.dart:131-136). That the highlight survives the first render was not checked at runtime.
- Open Bookmarks from the bookmark icon in the surah-list app bar (surah_list_page_body.dart:58-61).
- Reading position is saved automatically while in the mushaf: 800 ms after each page change, immediately when the app goes to paused/inactive, and when leaving the mushaf (LastReadSaver wired in mushaf_page.dart:79-95, 142-160). It is stored in the Hive box 'last_read' (typeId 5, opened in hive_config.dart:23-24), with the page clamped to 1..604 (last_read_repository_impl.dart:20).
- See a 'Continue reading' card (LastReadCard) at the top of the surah list and on Home. It shows a page badge, the surah name, a surah-relative % and progress bar, and either 'Surah · Ayah N' or the page label. Ayah 0 (basmala) or no ayah falls back to page-based progress (surah_reading_progress.dart:28). The button pushes /mushaf at last.page, and mushaf_page.dart:97-104 re-highlights the saved ayah when the opened page matches.
- Before any reading history exists, the surah list shows a 'Start reading — Begin with Al-Fatiha' card that opens page 1 (start_reading_card.dart). Home shows no card in that case.
- LastReadCubit is a single app-wide instance: a lazy singleton provided once in main.dart:81. Commit 0fb00d65 removed the per-route re-creation that used to close it on pop.

### Entry points
- Route /surahList (AppRouter.surahListPath) → SurahListPage, in lib/config/router/app_router.dart:114-125
- Home QuickAccessGrid 'Quran' tile → /surahList (lib/features/home/presentation/pages/widgets/quick_access_grid.dart:22-26)
- Home continue-reading card via LastReadCard.maybeBuild (lib/features/home/presentation/pages/widgets/home_view.dart:85,129-133)
- /mushaf route (extra: int page or MushafArgs) is the target for every tap in this feature (app_router.dart:126-143)
- App-root LastReadCubit provider in lib/main.dart:81; Hive box 'last_read' opened in lib/config/hive_config.dart:23-24
- Last-read writes come from MushafPage via LastReadSaver (lib/features/surah/presentation/pages/mushaf/mushaf_page.dart:79-95,142-160)

### Tests
Covered: LastReadRepositoryImpl (round-trip with and without an ayah, null when empty, watch emits, clamping 0→1, 700→604, edge pages 1 and 604) in test/features/surah/data/repositories/last_read_repository_impl_test.dart. LastReadCubit (3 blocTests) in test/features/surah/presentation/cubit/last_read/last_read_cubit_test.dart. LastReadSaver debounce, flush and dispose in test/features/surah/presentation/pages/mushaf/last_read_saver_test.dart. computeSurahProgress in two overlapping files: test/features/surah/surah_reading_progress_test.dart and test/features/surah/presentation/pages/surah_list/surah_reading_progress_test.dart. SurahListTile play button only (surah_list_tile_test.dart). The search domain and data layers (search_quran_test, quran_search_index_impl_test, quran_browse_service_impl_test, search_cubit_test). test/core/widgets/last_quran_read_test.dart only tests the dead LastQuranRead widget. Untested: SurahCubit and the surah data source/repo/use case; LastReadCard; StartReadingCard; SurahListPageBody (tab switching, search/browse swap, bookmark icon); juz list and page grid navigation; searchResultsSliver, AyahResultTile and _JumpTile; MushafArgs route parsing; and the MushafPage wiring of LastReadSaver (page-stream schedule, lifecycle paused/inactive flush, dispose flush). The reliability plan replaced a widget test of that wiring with the saver unit test. No tests were run in this audit.

### Known issues
- **MEDIUM** `lib/features/surah/presentation/cubit/surah/surah_cubit.dart`: fetchSurahs() (lines 11-14) has no try/catch and no isClosed check after `await getSurahList.call(...)`. The empty list doubles as the loading state, so if the asset load or JSON decode fails, the Surah tab shows AppListSkeleton forever with no error or retry. If the route is popped before the load finishes, emit() runs on a closed cubit and throws a StateError.
- **MEDIUM** `lib/features/surah/presentation/pages/surah_list/widgets/surah_list_tile.dart`: Unlocalized strings: the ayah-count noun "آية"/"آيات" (line 19) and "صفحة" (line 30) are hardcoded Arabic. surah.revelationType is the Arabic "مكية"/"مدنية" from surah_list.json, and the JSON's englishRevelationType is ignored. The English UI therefore shows an all-Arabic meta line. surah.name is also prefixed with a hardcoded "سُورَةُ" in surah_model.dart:19.

<details><summary>Low-severity notes (10)</summary>

- `lib/core/widgets/last_quran_read.dart`: Dead duplicate of LastReadCard: LastQuranRead is not referenced anywhere in lib/, only by test/core/widgets/last_quran_read_test.dart. Spec §8 and plan Task 17 say to delete it. It was kept only because its own test imports it, so the tests maintain a widget users never see. It also hardcodes `TextDirection` and physical left/right padding.
- `lib/features/surah/presentation/pages/surah_list/widgets/search_results_view.dart`: No loading skeleton for search, which goes against .claude/rules/loading-states.md and spec §5. On the first keystroke the state is isActive && isSearching with empty results, so the view renders only a 24px spacer (an empty area) for the 200 ms debounce plus the time the search takes. Separately, lines 59-73: the SURAHS header and count come from search results, but the tiles come from SurahCubit.state. If that list is empty (not loaded yet or failed), the header shows a count and every row shrinks to nothing.
- `lib/features/search/data/quran_search_index_impl.dart`: Surah matching is a plain substring check against '<normalized arabic> <english lower> <id>' (lines 51, 55-60). A numeric query like '1' matches every surah whose number contains the digit (1, 10-19, 21, 31, ..., 100-114), so surah results for numbers are noisy rather than exact. QuranSearchIndexImpl.build() also normalizes all 6,236 ayahs synchronously on the main isolate the first time SearchCubit is resolved, which happens when the surah-list page first builds.
- `lib/features/home/presentation/pages/widgets/home_view.dart`: The Home continue-reading card is built only inside the DailyPrayerContextLoaded branch (line 85). When the prayer or location context fails (permission denied, services off, error), Home shows no continue-reading card at all, even though last-read is independent of location. The surah-list screen still shows it.
- `lib/features/surah/presentation/cubit/last_read/last_read_cubit.dart`: The initial state is null and the stored value arrives asynchronously via repository.get().then(...) (lines 13-15), with no error handler on that future. On the first build after the cubit is lazily created, LastReadCard.maybeBuild returns null, so the surah list can briefly render StartReadingCard for a returning reader before the saved value is emitted. Not verified on device.
- `lib/features/surah/presentation/pages/mushaf/mushaf_page.dart`: The saved LastRead pairs page = MushafCubit.currentPage with ayah = highlightedAyah ?? PlaybackCubit.currentAyah (lines 80-85). If playback's current ayah is on a different page than the visible one, the card would show surah/ayah progress for one place and a page badge for another. Whether playback can drift from the visible page was not verified, because the playback code was not read.
- `lib/config/router/app_router.dart`: Merge leftover: the /mushafImage route (mushafImagePath, lines 32, 145-161) is an exact copy of the /mushaf route and has no callers in lib/ or test/. It came in with the PNG-pipeline line (37e09ecc / fc4e9b16) through the origin/main merge, and all navigation from this feature uses mushafPath.
- `lib/features/home/presentation/pages/widgets/quick_access_grid.dart`: Merge leftover from the teammate's qibla branch: a 5th tile (Qibla) was added to a grid with crossAxisCount 4 (lines 15, 42-46). The Qibla tile wraps alone onto a second row under the Quran entry point.
- `test/features/surah/surah_reading_progress_test.dart`: Duplicate test file: computeSurahProgress is also tested in test/features/surah/presentation/pages/surah_list/surah_reading_progress_test.dart. The two files overlap; the older one lives at a path that does not mirror lib/.
- `lib/features/home/presentation/pages/widgets/last_read_card.dart`: The button uses hardcoded `Colors.white` (lines 114, 129) instead of scheme.onPrimary. The percent label from progress_complete uses an ASCII '%' next to Arabic-Indic digits ('{percent}% مكتمل' in intl_ar.arb:124).

</details>

### Planned but not built
- 2026-05-31-surah-list-search-redesign-design.md §8 / plan Task 17 Step 2: delete lib/core/widgets/last_quran_read.dart. Not done: the file still exists and only its own test references it.
- 2026-05-31-surah-list-search-redesign-design.md §8: the continue-reading card is missing the juz as a subtle third element and the labels 'آية {a} من {total} · {pct}٪' and 'صفحة {n} من {span} في السورة'. Only a page badge, the surah name, '{percent}% complete' and 'Surah · Ayah N' or the page label are implemented.
- 2026-05-31-surah-list-search-redesign-design.md §5: the search-loading skeleton is not implemented. While searching with no results yet, the view is empty.
- 2026-05-31-surah-list-search-redesign-design.md §4: the search header is a SliverPersistentHeader(pinned) placed after the continue card. It was built instead as a fixed widget above the CustomScrollView, so the card sits below the search and tabs. This is a deliberate deviation (see the comment in surah_list_page_body.dart:151-154), not a missing feature.
- 2026-05-31-surah-list-search-redesign-design.md §6: the debounce is specified as ~250 ms; the code uses 200 ms (search_cubit.dart:13). This is a minor deviation.
- 2026-05-31-surah-list-search-redesign.md Task 17 Step 5: the normalizer reality check against ~8 real queries is a manual or throwaway step with no lasting artifact, so whether it was done cannot be verified. Task 17 Step 6, the manual smoke test, also cannot be verified.
- 2026-06-13-last-read-reliability.md: Tasks 1-3 (ayah-0 → page-based progress, clamp to 1..604, LastReadSaver debounce/lifecycle/dispose) are all in code, but every checkbox in the plan is still unticked. The Task 4 manual gate (background, then cold start shows page N) has no recorded evidence.

### Manual checks on a device
- [ ] Home → tap the 'Quran' quick tile. Confirm the surah list opens with a skeleton that becomes 114 tiles, the count header reads 114, and the first tile is Al-Fatiha with مكية · ٧ آيات · صفحة ١.
- [ ] Switch the app to English in settings, reopen the surah list and check whether the tile meta line is still Arabic (آية/صفحة/مكية). This confirms the unlocalized-string issue.
- [ ] Tap the Juz tab, scroll to juz 30 and tap it: the mushaf should open at that juz's first page. Then use the Page tab, tap 604, and confirm the last page opens.
- [ ] Type 'الرحمن' in search: the SURAHS section should list Ar-Rahman and AYAHS should show a total count. Tap an ayah result and confirm the mushaf opens on the right page with that ayah highlighted.
- [ ] Type 'baqara' (English) and confirm Al-Baqarah appears. Type '30': confirm 'Go to page 30' and 'Go to juz 30' chips appear and the juz chip opens page 582. Type '700': confirm no page suggestion appears.
- [ ] Type a nonsense string and confirm the 'no results' message shows. Tap the x and confirm the browse tabs and continue card come back.
- [ ] Watch the first keystroke closely on a slow device: if there is a blank flash before results appear, that confirms the missing search skeleton.
- [ ] Fresh install, or clear app data: open the surah list and confirm the 'Start reading' card appears and opens page 1. On Home, confirm there is no continue card.
- [ ] Open the mushaf, swipe to page 50 and wait more than 1 s. Press Home to background the app (do not back out of the reader), swipe-kill it from recents, then cold-start. Confirm the Home and surah-list continue cards show page 50 with a surah-relative %.
- [ ] In the mushaf, tap to highlight an ayah, then back out. Confirm the card reads 'Surah name · Ayah N', and that tapping Continue reopens the page with that ayah highlighted.
- [ ] Leave a position on the basmala of a surah (ayah 0). Confirm the card shows the page label and not 'Ayah 0' or 'Ayah 1'.
- [ ] Start playback from a surah tile's play icon, navigate to a different page while audio plays, back out, and check whether the card's surah/ayah and page badge disagree. This tests the unverified page/ayah mismatch.
- [ ] Deny location permission so Home shows the recovery card. Confirm there is no continue-reading card on Home while it is still on the surah list.
- [ ] Pop the surah list several times and go back to Home. Confirm the Home continue card still updates after the next reading session, which checks that the shared LastReadCubit is no longer closed by route pops.

### Enhancement ideas
- Give SurahCubit an explicit loading/loaded/error state with try/catch and an isClosed guard, and show a retry when the error state is hit instead of an endless skeleton.
- Localize the surah tile meta line: add arb keys for the ayah-count plural and the page label, and pick revelationType or englishRevelationType by locale.
- Delete last_quran_read.dart and its test, and merge the two surah_reading_progress test files into the one under presentation/pages/surah_list.
- Show a skeleton (a Skeletonizer around a few placeholder AyahResultTile cards) while SearchState.isSearching has empty results.
- Make a numeric surah query match the surah number exactly instead of by substring.
- Render the continue-reading card on Home independently of the prayer-context state, so it still shows when location fails.
- Pre-warm QuranSearchIndex off the first frame (for example after startup), or build it in compute(), so opening the surah list does not normalize 6,236 ayahs synchronously.
- Remove the unused /mushafImage route.
- Add widget tests for LastReadCard (ayah-based vs page-based text) and for SurahListPageBody (tab switch, search swap, start-card fallback).

## quran-playback

**Status:** 🟡 Partial

In the Mushaf you can play recitation verse by verse. It supports 17 reciters, 6 speeds, a from/to range, repeat counts and auto page-follow, and it is wired through DI, main.dart and the /mushaf route. Background playback, lock-screen/notification controls and basmala-as-ayah-0 (the June B1/B2 plans) are not built. There are also real defects: a failed download blocks that verse until restart, errors are never shown, and skipping or editing the range can run playback past the range.

### What it does
- Play a whole surah from the Surah list: the play icon on each SurahListTile calls PlaybackCubit.playFromAyah(surah,1) and then pushes /mushaf (surah_list_tile.dart:62-65).
- In the Mushaf, tap a verse to highlight it. This shows the frosted mini-player (AyahPlaybackOverlay is always mounted in mushaf_page.dart, shown when highlightedAyah != null or the overlay is pinned).
- Mini-player Play button plays the highlighted ayah to the end of its surah (playRange); tapping the basmala header starts at ayah 1 (ayah_playback_overlay.dart:526-534).
- Pause and resume. When the current ayah matches the target, tapping Play again resumes instead of restarting.
- Previous/next ayah buttons (skipPrevious/skipNext), disabled at 1:1 and at 114:last. Skipping crosses surah boundaries.
- Browse-bar Play on the Mushaf plays the current page from its first ayah to the end of that surah (mushaf_page.dart:246-265, wired at :388).
- Basmala plays automatically before ayah 1 of every surah except 1 and 9. It plays as a glued 2-track sequence while the basmala header is highlighted (isPlayingBasmala, CurrentAyahNotifier).
- Pick a reciter from 17 everyayah reciters: tap the mini-player info area to open the reciter sheet. The choice persists via SettingsCubit.updateDefaultReciter, and changing it mid-playback restarts the current ayah.
- Pick a speed (0.5/0.75/1/1.25/1.5/2x) in the tune/options sheet. It is persisted via SettingsCubit.updatePlaybackSpeed and reapplied on each ayah.
- Options sheet (PlaybackRepeatOptions): from/to ayah range within a single surah, each-ayah repeat 1..99, whole-range repeat 1..99, and an infinite toggle (range only). Counters use +/- and tap-to-type, and accept Western and Arabic-Indic digits.
- The mini-player subtitle shows the reciter name, the speed if it is not 1x, and repeat progress (current/total, or infinite).
- Auto page-follow: when the playing ayah moves to another page, the PageView or scroll view animates to it (mushaf_page.dart:_onPlayingAyahChanged + auto_swap_helper.dart).
- Audio files are downloaded once per reciter/ayah to the app documents dir and indexed in the Hive box 'ayahAudioCache'. The next 5 ayahs are preloaded with at most 2 concurrent downloads, so already-played verses replay offline.
- Leaving the Mushaf stops playback (MushafPage.dispose calls _playbackCubit.stop()).

### Entry points
- Surah list tile play icon → PlaybackCubit.playFromAyah then context.push('/mushaf') (lib/features/surah/presentation/pages/surah_list/widgets/surah_list_tile.dart:62)
- /mushaf route (AppRouter.mushafPath, lib/config/router/app_router.dart:127) → MushafPage → AyahPlaybackOverlay mini-player
- Mushaf verse tap → MushafCubit.toggleHighlight → overlay (mushaf_page_view.dart)
- Mushaf browse bar Play → MushafPage._onPlayPage (mushaf_page.dart:246, wired at :388)
- Mini-player info tap → reciter sheet; tune icon → options sheet (speed + PlaybackRepeatOptions)
- App-wide BlocProvider(create: sl<PlaybackCubit>) in lib/main.dart:82

### Tests
These tests were not executed; the audit was read-only. Covered: test/features/quran_playback/playback_cubit_test.dart (553 lines, 18 blocTests: pause, race guard, speed on play, skipNext/Prev and boundaries, restartCurrent, setSpeed, setReciter idle/playing, basmala sequence and flag, surahs 1/9 without basmala, (2,0) redirect, basmala prepare-failure fallback); presentation/cubit/playback_repeat_logic_test.dart (pure nextPlaybackStep: each/range/infinite); domain/services/playback_range_validator_test.dart; domain/services/quran_meta_service_test.dart (it tests a service with no lib consumer); aya_sequence_service_test.dart (getPreviousAyah only); presentation/widgets/playback_repeat_options_test.dart; and two overlapping PlaybackState tests (test/features/quran_playback/playback_state_test.dart and presentation/cubit/playback_state_test.dart). Outside the folder: test/features/surah/presentation/pages/mushaf/widgets/ayah_playback_overlay_test.dart (13 widget tests, updated post-merge in 358e47f8), surah_list_tile_test.dart (the play button calls playFromAyah), mushaf_cubit_auto_follow_test.dart, current_ayah_notifier_test.dart and auto_swap_helper_test.dart. Untested: QuranPlaybackRepoImpl (download dedupe, failure path, queue concurrency, sequence index callback); the remote and local data sources; cubit-level playRange/setRange/setRangeEnd and the range-overrun cases; getNextAyah with range end; the error-surfacing path; overlay visibility after page change; DI wiring of initPlayback. No tests exist for background audio or OS media controls, because none of it is built.

### Known issues
- **HIGH** `lib/features/quran_playback/data/repositories/quran_playback_repo_impl.dart`: A failed download blocks that ayah until the app restarts. prepareAyahAudio stores the future in _inFlightDownloads[url] and only removes it after a successful await (line ~76); there is no finally. On a DioException the failed future stays in the map, so every later call takes the 'Download already running' branch, rethrows the same error and returns Left. preloadAyahs also skips the URL on containsKey. One offline or timeout attempt makes that ayah unplayable for the session.
- **HIGH** `ios/Runner/Info.plist`: No background audio or OS media controls. Info.plist has no UIBackgroundModes/audio. AndroidManifest.xml has no com.ryanheise.audioservice.AudioService service or MediaButtonReceiver, and MainActivity is a plain FlutterActivity. just_audio_background (pubspec.yaml:61) is a dead dependency: JustAudioBackground.init is never called, and the package only swaps JustAudioPlatform.instance inside init. No foreground service or media session is used for Quran audio. The existing FOREGROUND_SERVICE_MEDIA_PLAYBACK permission belongs to AdhanPlaybackService. Exact OS behaviour when backgrounded was not verified.
- **MEDIUM** `lib/features/quran_playback/presentation/cubit/playback/playback_cubit.dart`: Playback errors are never shown. _playAyah emits state.error = failure.message, but nothing in lib reads PlaybackState.error and there is no BlocListener<PlaybackCubit>. The SnackBar from overlay spec section 7 is unbuilt. When a download fails the spinner disappears and the user gets no feedback. error also holds a raw, unlocalized failure.message.
- **MEDIUM** `lib/features/quran_playback/presentation/cubit/playback/playback_cubit.dart`: Playback can run past the range end. AyahSequenceService.getNextAyah stops only when current == (endSurah,endAyah) exactly. skipNext/skipPrevious call _playAyah without range checks and do not reset currentAyahPlayCount. The 'To' counter (setRangeEnd, clamped only to >= rangeStart) can be set below the currently playing ayah. In either case current never equals the end, so advance continues across surahs to 114:6.
- **MEDIUM** `lib/features/surah/presentation/cubit/mushaf/mushaf_cubit.dart`: The mini-player can disappear while audio keeps playing. Overlay visibility is highlightedAyah != null || isOverlayPinned. setPage() always clears highlightedAyah, and it is called from PageView.onPageChanged and from the scroll listener, including during auto-follow page turns. The page-play path never pins (pinOverlay only runs when the page has no first ayah). Read from the code: after an auto page turn, or a manual swipe, the overlay hides and auto-follow highlighting stops, while audio continues. Needs on-device confirmation.
- **MEDIUM** `lib/features/surah/presentation/pages/surah_list/widgets/surah_list_tile.dart`: Surah-list play opens the Mushaf with audio running and no visible player. It calls playFromAyah, then context.push(mushafPath, extra: pageNumber) with no focusAyah and no pin. highlightedAyah stays null, so the overlay is hidden. If last-read is on the same page, MushafPage's post-frame restore highlights the last-read ayah instead of the playing one. There are no controls until the user taps a verse.
- **MEDIUM** `lib/features/quran_playback/playback_di.dart`: Playback DI is registered late, an async race. `void initPlayback() async` awaits getApplicationDocumentsDirectory() before any registration, and initGetIt() calls it without await. All playback registrations (repo, services, PlaybackCubit) therefore land after initGetIt returns and _initAll sets _ready, and any exception thrown there is unhandled. Today every consumer resolves lazily (BlocProvider create, the CurrentAyahNotifier lazy singleton), so a crash was not observed or verified. It is a latent ordering bug.

<details><summary>Low-severity notes (7)</summary>

- `lib/features/surah/presentation/pages/mushaf/widgets/ayah_playback_overlay.dart`: There is no way to stop playback from the player. The dismiss button (expand_more) and swipe-down only call MushafCubit.unpinOverlay(); a test asserts 'close button clears highlight but leaves playback running'. Overlay spec 2.2 says close stops playback, and the Restart button from spec 2.2 is missing. Only leaving the Mushaf stops audio.
- `lib/features/surah/presentation/pages/mushaf/widgets/ayah_playback_overlay.dart`: Skip buttons can be dead taps. _isFirst/_isLast use the highlighted target, but PlaybackCubit.skipNext/skipPrevious return early when state.currentAyah is null. With an ayah highlighted and nothing played yet, prev/next look enabled and do nothing.
- `lib/features/quran_playback/presentation/widgets/playback_repeat_options.dart`: Infinite each-ayah repeat is unreachable. The toggle always calls setInfiniteRepeat(!on, RepeatTarget.range), so the RepeatTarget.eachAyah branch in nextPlaybackStep is reachable only from tests. Changing the 'From' counter immediately starts playback (calls playRange), even if the user only meant to configure.
- `lib/features/quran_playback/presentation/cubit/playback/playback_cubit.dart`: Dead or unreachable code: restartCurrent, autoPlayPage, preloadFullSurah and getPageForCurrentAyah have no callers in lib. PlayAyahUseCase is never registered or used. QuranMetaService is registered in playback_di.dart but has no consumer in lib (only tests). MushafState.highlightedAyahCenterY is written via setHighlightBounds but never read. The l10n key playback_restart is unused.
- `lib/features/quran_playback/presentation/cubit/playback/playback_cubit.dart`: Missing isClosed checks after await: stop() emits after await repository.stop(), and so do restartCurrent() (after seek/resume), preloadFullSurah() and setSpeed(). Low impact because the cubit is an app-lifetime lazy singleton. Also, setReciter while paused restarts audio instead of staying paused (wasActive includes isPaused).
- `lib/features/surah/presentation/pages/mushaf/widgets/ayah_playback_overlay.dart`: Localization gaps: the info line uses ayah_label with surah *number* and Western digits ('Surah 2, Ayah 5'), and shows 'Ayah 0' when the basmala header is the target. Reciter chips always show Reciter.arabicName, also in the English locale. The type-in dialog reuses the unrelated filter_apply key. The 'Nx' speed label and the '↻' glyph are hard-coded.
- `lib/features/quran_playback/data/datasources/remote/quran_playback_remote_data_source.dart`: Download retries happen immediately with no backoff (retries=2). preloadAyahs trusts the Hive metadata without checking that the file exists (only prepareAyahAudio checks existsSync). QuranPlaybackRepoImpl.dispose() is not part of the repo interface and is never called.

</details>

### Planned but not built
- 2026-06-13-playback-background-audio-design.md B1 / plans/2026-06-13-playback-phase-b1-media-controls.md Task 1: add audio_service, remove just_audio_background. Not done: pubspec still has just_audio_background and no direct audio_service.
- B1 Task 2: pure processing-state mapper. Absent.
- B1 Task 3: QuranAudioHandler extends BaseAudioHandler (state out, MediaControls, play/pause/stop/seek/skip delegated to the cubit). Absent.
- B1 Task 4: AudioService.init in main.dart before initGetIt plus handler registration in GetIt. Absent.
- B1 Task 5: bind the handler in PlaybackCubit and publish a MediaItem (reciter, surah:ayah, Basmala) on each ayah change. Absent.
- B1 Task 6: platform config (AudioService service + MediaButtonReceiver in AndroidManifest.xml; UIBackgroundModes audio in Info.plist). Absent.
- plans/2026-06-13-playback-phase-b2-basmala-ayah0.md Tasks 1-8 all unbuilt: audioSourceAyah helper; repo maps ayah 0 to 001001.mp3; remove isPlayingBasmala; simplify the cubit (playSelected still redirects (s,0) to (s,1)); delete playPreparedAudioSequence (still used); simplify CurrentAyahNotifier (still translates isPlayingBasmala); overlay plays/seeds from ayah 0 (still maps 0 to 1); 'Play page' starts at ayah 0 (mushaf_page._onPlayPage still plays from 1).
- specs/2026-05-21-playback-overlay-design.md section 7: error SnackBar via BlocListener on PlaybackState.error, then clear error. Not built.
- specs/2026-05-21-playback-overlay-design.md section 2.2: Restart (⟲) control and close button calling stop(). Not built; the redesign replaced close with dismiss-only.
- plans/2026-05-31-mushaf-phase2-overlay-aware-playback.md Task 7: overlay-aware page positioning (AnimatedPadding reserving player height). Not built. The redesigned overlay floats over the page by design, and the highlightedAyahCenterY plumbing is left write-only.

### Manual checks on a device
- [ ] Surah list → tap the play icon on Al-Baqarah. Expect audio to start (basmala, then 2:1) and the Mushaf to open on page 2. Check whether the mini-player is visible without tapping a verse. The code suggests it is hidden.
- [ ] In the Mushaf, tap verse 2:5, then the mini-player Play. Confirm 2:5 plays, the highlight follows each next verse, and the reciter/speed subtitle is correct.
- [ ] Let playback cross a page boundary (e.g. start at the last verse of page 2). Confirm the page auto-turns, then check whether the mini-player and the highlight disappear while audio continues.
- [ ] Tap the basmala header of Surah 2 and press Play. Confirm the basmala plays with the header highlighted, then 2:1 highlights. Repeat for Surah 1 and Surah 9: no extra basmala.
- [ ] Turn on airplane mode, tap an uncached verse (new reciter) and press Play. Expect the spinner to stop with no message. Turn the network back on and press Play on the same verse again. If it still fails until app restart, the stuck _inFlightDownloads defect is confirmed.
- [ ] Options sheet: set From=1, To=3, each-ayah repeat=2, range repeat=2. Confirm the order 1,1,2,2,3,3,1,1,2,2,3,3, then stop. Toggle ∞ and confirm the range loops forever.
- [ ] During a 2:1-2:3 range, press Next past 2:3. Then, during a 2:1-2:20 range at 2:10, set To=5. Check whether playback continues beyond the range into later surahs.
- [ ] Change the reciter while playing. Expect the same verse to restart in the new voice. Change it while paused and note that playback resumes. Kill and relaunch the app: the reciter and speed persist.
- [ ] Press the mini-player dismiss (chevron) or swipe it down while playing. Audio keeps playing with no visible stop. Navigate back from the Mushaf and confirm audio stops.
- [ ] With a verse highlighted but nothing played yet, tap Next/Previous. Expect no response (dead tap).
- [ ] Background test, Android and iOS: start playback, press Home, then lock the screen. Note whether audio continues and whether any lock-screen, notification or Control Center controls appear. None are expected; B1 is unbuilt.
- [ ] Switch the app to English and open the reciter sheet and mini-player. Reciter names stay Arabic, and the label reads 'Surah 2, Ayah 5' with a surah number rather than a name.

### Enhancement ideas
- Wrap the _inFlightDownloads removal in try/finally, and let preloadAyahs retry failed URLs.
- Add a BlocListener<PlaybackCubit> in MushafPage that shows a localized SnackBar on error transitions, then clears error.
- Make getNextAyah stop when current is past the range end (compare absolute positions, not equality). Clamp skipNext/skipPrevious to the active range and reset currentAyahPlayCount.
- Make overlay visibility also depend on PlaybackState (currentAyah != null && (isPlaying || isPaused)), or pin the overlay when playback starts, so controls survive page turns and the surah-list entry.
- Add an explicit Stop control (or make long-press on dismiss stop playback).
- Await initPlayback: make it Future<void> and resolve the documents dir before the registrations, or register an async singleton.
- Execute B1 (audio_service handler + manifest/Info.plist config) and B2 (ayah 0), then drop the dead just_audio_background dependency.
- Delete the dead code: PlayAyahUseCase, autoPlayPage, preloadFullSurah, getPageForCurrentAyah, the unused QuranMetaService registration, highlightedAyahCenterY, and the duplicate playback_state_test.
- Show the surah name and localized digits in the mini-player label, and add English reciter names.

## Bookmarks

**Status:** ✅ Working

Users can save individual ayahs (from the long-press popover in the mushaf), whole mushaf pages (from the Save button in the browse bar, which also draws a ribbon on that page), and ahadith, then see all three on one Bookmarks screen and tap a row to open it. The wiring is complete and the core logic has unit tests. The rough edges: the screen briefly says "No bookmarks yet" before data loads, nothing can be removed from the screen itself, ahadith sort in the wrong order, and save/load errors are never shown to the user.

### What it does
- Open the Bookmarks screen from the Home quick-access grid (quick_access_grid.dart:32-35) or from the bookmark icon in the Surah list app bar (surah_list_page_body.dart:57-61). Route /bookmarks is registered in app_router.dart:99-104.
- Bookmark or unbookmark an ayah: long-press an ayah in the mushaf, then use the bookmark button in AyahActionPopover (opened from mushaf_page_view.dart:293). It toggles BookmarkCubit and the icon shows the saved state (ayah_action_popover.dart:297-305).
- Save or unsave the current mushaf page with the browse-bar Save button. It appears when the chrome is visible and the player is hidden. It is wired to PageBookmarkCubit.toggle(currentPage) and its icon reflects isSaved (mushaf_page.dart:378-393, mushaf_browse_bar.dart:52-53).
- A ribbon is drawn at the top-trailing corner of every saved page, in both page mode and scroll mode, because both build MushafPageView (mushaf_page_view.dart:175-188; mushaf_page.dart:449,469).
- Tap the ribbon to remove the page bookmark. A snackbar says 'Removed from bookmarks' and offers Undo (mushaf_page_view.dart:328-342).
- The Bookmarks screen lists Pages, then Quran ayahs, then Ahadith, each in its own section. Pages are sorted ascending and labelled with surah names and ayah ranges via describePage (Arabic-Indic numerals in Arabic). Ayahs are sorted by surah then ayah (bookmarks_page.dart:58-118).
- Tap a page row to open the mushaf at that page. Tap an ayah row to open the mushaf at the page containing that ayah, without highlighting the ayah (bookmarks_page.dart:145-148,199).
- Tap a hadith row to fetch the hadith with GetHadithByNumber and open /hadith. Failures and missing hadiths show a snackbar (bookmarks_page.dart:257-283).
- All bookmarks persist across launches in the Hive boxes ayah_bookmarks, page_bookmarks and hadith_bookmarks, opened in hive_config.dart:20-22 and registered in bookmarks_di.dart via initBookmarks() in dependency_injection.dart:32. BookmarkCubit and PageBookmarkCubit are provided app-wide in main.dart:79-80.

### Entry points
- Route /bookmarks (AppRouter.bookmarksPath) -> BookmarksPage, lib/config/router/app_router.dart:99-104
- Home quick-access tile 'Bookmarks', lib/features/home/presentation/pages/widgets/quick_access_grid.dart:32-35
- Surah list app-bar bookmark IconChip, lib/features/surah/presentation/pages/surah_list/widgets/surah_list_page_body.dart:57-61
- Mushaf browse-bar Save (page bookmark), lib/features/surah/presentation/pages/mushaf/mushaf_page.dart:378-393
- Mushaf page ribbon tap (remove + Undo), lib/features/surah/presentation/pages/mushaf/widgets/mushaf_page_view.dart:175-188,328-342
- Ayah long-press popover bookmark button, lib/features/surah/presentation/pages/mushaf/widgets/ayah_action_popover.dart:297-305
- App-wide providers main.dart:79-80; DI initBookmarks() via lib/core/di/dependency_injection.dart:32; Hive boxes lib/config/hive_config.dart:20-22

### Tests
No tests were run in this audit; coverage was inferred by reading the test files.

Covered by unit tests:
- Data sources: ayah bookmarks (get/parse/skip-malformed/toggle) and page bookmarks (empty/toggle/multiple).
  - test/features/bookmarks/data/datasources/local/bookmark_local_data_source_test.dart
  - test/features/bookmarks/data/datasources/page_bookmark_local_data_source_test.dart
- Repositories, including exception-to-Left mapping, in test/features/bookmarks/data/repositories/*.
- Ayah use cases, in test/features/bookmarks/domain/usecases/*.
- BookmarkCubit with blocTest: load, load failure, toggle.
- PageBookmarkCubit: load, add, remove.
- PageBookmarkState: contains, and clearing error with copyWith.
- describePage: page 1 in en and ar, and page 604.

Covered by widget tests:
- MushafPageRibbon render and tap (test/features/surah/presentation/pages/mushaf/widgets/mushaf_page_ribbon_test.dart).
- MushafBrowseBar save-icon state (mushaf_browse_bar_test.dart).
- mushaf_page_dispose_test.dart only stubs PageBookmarkCubit.

Untested:
- BookmarksPage: no widget test for sections, ordering, the empty state or navigation.
- Ribbon shown only on bookmarked pages, inside MushafPageView.
- Ribbon tap, snackbar and Undo flow.
- Browse-bar Save actually toggling PageBookmarkCubit, in the integrated mushaf_page.
- PageBookmarkCubit failure paths and the no-op toggle before load.
- No use-case tests for get_page_bookmarks or toggle_page_bookmark.
- describePage for a mid-surah page, which the spec requires.
- Ayah popover bookmark toggle.
- Hadith bookmark ordering and opening from the Bookmarks screen.

### Known issues
- **MEDIUM** `lib/features/bookmarks/presentation/pages/bookmarks_page.dart`: The screen never checks the `loaded` or `error` fields of BookmarkState, PageBookmarkState or HadithBookmarkState. Before the cubits finish loading (BlocProvider is lazy, so BookmarkCubit and HadithBookmarkCubit may be created on this screen's first build), the screen shows 'No bookmarks yet' and then swaps in the list. A Hive load failure also shows 'No bookmarks yet' with no error. This breaks the project's loading-states rule, which requires a Skeletonizer/SurfaceCard skeleton (lines 54-81).
- **MEDIUM** `lib/features/bookmarks/presentation/pages/bookmarks_page.dart`: Ahadith are sorted as strings. HadithBookmark.hadithNumber is a String (hadith_bookmark.dart), so `a.hadithNumber.compareTo(b.hadithNumber)` at lines 63-65 puts '10' and '100' before '2'. Numeric hadith numbers in the Ahadith section appear out of order.
- **MEDIUM** `lib/features/surah/presentation/pages/mushaf/widgets/mushaf_page_view.dart`: The ribbon's Undo (lines 328-342) calls `cubit.toggle(page)` again instead of re-adding the page. The removal is also fired without being awaited, and the 'Removed from bookmarks' snackbar shows even if the toggle fails or is skipped (toggle returns early when `!state.loaded`). If the page is saved again through the browse bar while the snackbar is up, tapping Undo removes it.
- **MEDIUM** `lib/features/bookmarks/presentation/cubit/bookmark_cubit.dart`: Errors are silent. BookmarkCubit and PageBookmarkCubit (and HadithBookmarkCubit) put failures in `state.error`, but no widget reads `.error` anywhere in lib. A failed save from the popover, the browse bar or the ribbon gives no feedback. The `bookmark_save_failed` string that was meant for this is unused.

<details><summary>Low-severity notes (9)</summary>

- `lib/l10n/intl_en.arb`: Merge leftover: dead l10n keys. `bookmark_added`, `bookmark_removed` and `bookmark_save_failed` came from main's squash #1 (df2c656b, for the AyahActionBar later deleted in eccce1d8). `bookmarks_title` duplicates `bookmarks_screen_title`. None of the four is referenced outside lib/generated. The two Arabic titles also differ ('العلامات المرجعية' vs 'الإشارات'), and bookmark wording is mixed elsewhere too ('حفظ', 'أزيلت من المحفوظات').
- `lib/features/bookmarks/presentation/pages/bookmarks_page.dart`: Ayah bookmark rows push a bare page int (`extra: quran.getPageNumber(...)`, lines 145-148) instead of `MushafArgs(page:, focusAyah:)`. The router already supports focusAyah (app_router.dart:131-135) and search results use it (ayah_result_tile.dart:33), but here the bookmarked ayah is not highlighted when the page opens.
- `lib/features/bookmarks/presentation/pages/bookmarks_page.dart`: The Bookmarks screen has no way to remove a bookmark: no swipe, long-press or delete. Ayahs can only be removed from the mushaf popover, pages from the ribbon or Save button, and ahadith from the hadith page.
- `lib/features/bookmarks/presentation/pages/bookmarks_page.dart`: When a bookmarked hadith resolves to null, the screen shows `S.of(context).coming_soon` ('Coming soon'), which is the wrong message (line 273). On failure it shows the raw `failure.message`, which may not be localized (line 268).
- `lib/features/bookmarks/presentation/pages/bookmarks_page.dart`: The trailing chevron is always `HugeIcons.strokeRoundedArrowRight01` (lines 178, 229, 317). Elsewhere the codebase flips arrows by text direction (custom_app_bar.dart:133-135, ahadith_list_view.dart:591). In Arabic RTL this chevron probably points backwards. Whether HugeIcon mirrors on its own is unverified.
- `lib/features/surah/presentation/pages/mushaf/widgets/mushaf_page_ribbon.dart`: The ribbon's tap target is 18x46 logical px, below the 44/48 px minimum, and has no Semantics label. It is the only on-page control for removing a page bookmark.
- `lib/features/bookmarks/data/datasources/local/page_bookmark_local_data_source.dart`: getAll() skips malformed entries, but toggle() uses `int.parse('$e')` (line 31), which throws on any malformed entry and becomes a CacheException. One corrupt entry would make every page toggle fail while the list still loads.
- `lib/features/bookmarks/domain/repositories/bookmark_repository.dart`: Dead API: `BookmarkRepository.isBookmarked` is implemented but has no use case and no caller in lib.
- `lib/features/bookmarks/presentation/pages/bookmarks_page.dart`: The hadith row's loading indicator is a CircularProgressIndicator (lines 306-314). The loading-states rule's exception covers only a slim LinearProgressIndicator over visible content, so this is borderline. The doc comment at lines 26-28 is also stale: it says the screen shows ayahs and ahadith only and does not mention pages.

</details>

### Planned but not built
- The ribbon's 'short settle animation when a page is saved' is not built. MushafPageRibbon is a static StatelessWidget/CustomPaint with no animation (spec 2026-06-13-mushaf-control-surface-design.md, A6 Design quality).
- `PageBookmarkRepository.isBookmarked(int) -> bool` is missing. The interface only has getAll and toggle (spec 2026-06-13-mushaf-control-surface-design.md, A6 Domain).
- The spec'd widget test 'ribbon appears only on bookmarked pages' is missing. Only the standalone MushafPageRibbon render/tap test exists (spec Testing section; plan 2026-06-13-mushaf-control-surface-phase3-page-bookmarks.md Task 7 only covers the standalone widget).
- The spec'd describePage unit test for a mid-Baqarah page is missing. page_description_test.dart covers only page 1 (en and ar) and page 604 (spec Testing section).
- Deviation, not a gap: the spec gives `describePage(int, {required bool isArabic})`, but the code takes `{required String localeCode}`. The plan uses localeCode, so they are consistent with each other.
- The plan's checkboxes are all unchecked, but Tasks 1-10 are present in code. Task 11 (scoped tests, analyze, build apk, manual gate) has no record in the repo and was not verified here.

### Manual checks on a device
- [ ] In the mushaf in page mode, tap the page to show the chrome, then tap Save in the bottom browse bar. The Save icon should fill and a ribbon should appear at the top-trailing corner (top-left under the Arabic locale, top-right under English).
- [ ] Switch Reading mode to scroll in the reading settings. Every saved page should show its ribbon as you scroll.
- [ ] Tap a ribbon. It should disappear and a 'Removed from bookmarks' snackbar with Undo should appear. Tap Undo and the ribbon should come back. Then remove it with the ribbon again, re-save it with the browse-bar Save before the snackbar closes, and tap Undo. Confirm whether the page ends up unsaved (suspected toggle-based Undo bug).
- [ ] Long-press an ayah, tap the bookmark button in the popover, and confirm the icon fills. Open Bookmarks from Home > Bookmarks and from the Surah list's top-right bookmark icon. The ayah should appear under Quran, and the saved page under Pages with a surah/ayah-range description.
- [ ] Tap a Pages row and confirm the mushaf opens at that page. Tap a Quran row and confirm it opens the right page. Note that the ayah is not highlighted (expected given current code).
- [ ] Bookmark ahadith numbered 2 and 10 (or 100) in the same book. Open Bookmarks and check the order. With the current code '10' sorts before '2'.
- [ ] Tap a bookmarked hadith whose book is not downloaded or cached, or with the device offline. Note the snackbar text: 'Coming soon' for a null hadith, or the raw failure message.
- [ ] Switch the app to Arabic. Check that page descriptions use Arabic surah names, Arabic-Indic numerals and the '،' separator, that the page subtitle reads 'صفحة ٣', and whether the row chevrons point the right way in RTL.
- [ ] Force-kill the app and relaunch, then open Bookmarks first thing. Check that all three sections persist, and watch for a 'No bookmarks yet' flash before the list appears.
- [ ] Remove every bookmark through the mushaf and the hadith page. The Bookmarks screen should show the centered 'No bookmarks yet' message.

### Enhancement ideas
- Show a Skeletonizer SurfaceCard placeholder while any of the three cubits is not loaded, and an error state on load failure, instead of 'No bookmarks yet'.
- Sort ahadith numerically (int.tryParse with a string fallback), or by book order from getHadithBooks.
- Make the ribbon's Undo idempotent by re-adding the page explicitly (add an `add`/`setSaved` use case or check `state.contains` before toggling), and show the snackbar only after a successful removal.
- Add swipe-to-delete with Undo on the Bookmarks screen rows.
- Pass `MushafArgs(page:, focusAyah: ayah)` from ayah rows so the bookmarked verse is highlighted on arrival.
- Show `state.error` through a BlocListener with the existing `bookmark_save_failed` string. Delete the dead `bookmark_added`, `bookmark_removed` and `bookmarks_title` keys, and settle on one Arabic term for bookmarks.
- Enlarge the ribbon's hit area (e.g. padding to 44x48) and add a Semantics label, and add the spec'd settle animation.
- Choose the chevron icon by text direction (ArrowLeft01 in RTL), following custom_app_bar.dart.

## Quran search

**Status:** ✅ Working

On the Surahs screen you can type to search the whole Quran: surah names, mushaf page and juzʼ numbers, and ayah text. Tapping a result opens the mushaf, and an ayah result highlights that verse. When the search box is empty, three tabs let you browse by surah, by juzʼ or by page. Everything is wired into routing and DI and has unit tests below the UI, but there are gaps: numbers typed in Arabic digits get no page or juzʼ jump, transliterated surah names like "Fatiha" are not searchable, and nothing on screen shows while the first search runs.

### What it does
- Open the Surahs screen from the home quick-access grid (quick_access_grid.dart:25 pushes AppRouter.surahListPath). The route provides SurahCubit and SearchCubit (app_router.dart:115-123), and initSearch() is registered in core/di/dependency_injection.dart:27.
- Type in the fixed search field. The query is trimmed and debounced 200 ms in SearchCubit.queryChanged, and the browse tabs hide while a query is active (surah_list_page_body.dart:220-247).
- Surah-name search: substring match on the normalized Arabic name, the lowercased English translation name ('The Opening') and the surah number, shown with the regular SurahListTile under a 'Surahs' header with a count (search_results_view.dart:58-78).
- Ayah-text search over all 6,236 ayahs: substring match on normalized text, so diacritics, alef forms, ى/ي and ة/ه do not matter, and non-initial alefs are dropped so الرحمن matches الرحمان. Results show diacritized text in Scheherazade with 'surah name · ayah label · page'. At most 100 are shown, the header counts all matches, and a '+N more — refine your search' note appears when more exist.
- Tap an ayah result to open /mushaf at that ayah's page with the ayah highlighted (MushafArgs.focusAyah → cubit.toggleHighlight in app_router.dart; mushaf_page.dart:99 skips the last-read highlight when a focus highlight is already set).
- A numeric query in ASCII digits shows 'Go to page N' (1–604) and 'Go to juzʼ N' (1–30) cards that open the mushaf at that page or at the juzʼ's first page.
- A 'No results' message appears when a finished search matches nothing.
- Clear the query with the X icon in the field, which returns to browse mode.
- Browse tab Surahs: all 114 surahs (AppListSkeleton while loading). Browse tab Juzʼ: 30 rows, each with its first-to-last surah span, that open its first page. Browse tab Pages: a 6-column grid of pages 1–604 that open that page.
- With no query, the top card shows the continue-reading card (surah-relative progress via computeSurahProgress), or a start-reading card when there is no reading history.
- A bookmark icon in the app bar opens /bookmarks.

### Entry points
- /surahList route (AppRouter.surahListPath), provides SurahCubit and SearchCubit (lib/config/router/app_router.dart:115-123)
- Home quick-access grid tile → context.push(AppRouter.surahListPath) (lib/features/home/presentation/pages/widgets/quick_access_grid.dart:25)
- Exits to /mushaf with an int page or MushafArgs(page, focusAyah) (lib/config/router/app_router.dart:188 _mushafArgsFrom)
- DI: initSearch() in lib/core/di/dependency_injection.dart:27

### Tests
Covered:
- test/features/search/search_quran_test.dart (5 tests): empty query, page and juzʼ jump ranges, out-of-range numbers, grouped Arabic results (with fakes).
- test/features/search/quran_search_index_impl_test.dart (7 tests, real corpus): Arabic, English and number surah matches, the basmala ayah, the limit vs total count, الرحمن↔الرحمان, diacritized display text.
- test/features/search/quran_browse_service_impl_test.dart (3 tests): juzʼ first pages and 30 entries.
- test/features/search/search_cubit_test.dart (2 blocTests): debounce, emitting searching then results.
- test/core/arabic_normalizer_test.dart: the normalizer.

Untested:
- No widget test for SurahListPageBody, searchResultsSliver, AyahResultTile, _JumpTile, juzBrowseSliver or pageJumperSliver.
- No test for the router's _mushafArgsFrom or for focus-ayah highlighting in MushafPage.
- No test for Arabic-Indic digit input, transliterated surah names, or the clear (X) path.
- No DI smoke test that sl<SearchCubit>() resolves.

Tests were not run, per the read-only constraint.

### Known issues
- **MEDIUM** `lib/features/search/domain/usecases/search_quran.dart`: _numberJump uses int.tryParse(query), which only accepts ASCII digits, and normalizeArabic does not map Arabic-Indic digits (٠-٩, U+0660–0669) to ASCII. In this Arabic-first app, typing '٥٠' on an Arabic keyboard gives no page or juzʼ jump. It also matches no surah number, because the surah search keys are built with ASCII '$id' (quran_search_index_impl.dart:52).
- **MEDIUM** `lib/features/search/data/quran_search_index_impl.dart`: Line 52 builds each surah's search key from the Arabic name, getSurahNameEnglish (the translation, e.g. 'The Opening') and the number. The transliterated name (field 'name' in quran-1.4.1/lib/surah_data.dart, e.g. 'Al Fatiha') is never indexed, so English-keyboard searches like 'fatiha', 'baqara' or 'yaseen' find no surah. The SurahListTile entities carry a transliterated englishName from the JSON model, which suggests the old name filter could match these.
- **MEDIUM** `lib/features/surah/presentation/pages/surah_list/widgets/search_results_view.dart`: No loading skeleton. queryChanged emits isSearching=true with the previous results kept. On the first query those results are empty, and searchResultsSliver then renders only a 24px SizedBox (lines 26 and 114) for the 200 ms debounce plus the time to build the index. This breaks the .claude/rules/loading-states.md rule and spec §5 / acceptance criterion 8 (skeletonizer while loading).

<details><summary>Low-severity notes (7)</summary>

- `lib/features/search/search_di.dart`: QuranSearchIndexImpl.build() is a lazy singleton that is never pre-warmed. The first search builds it synchronously inside the debounce Timer callback on the UI isolate: normalizeArabic on 6,236 ayahs plus 114 surahs. The spec (§6, Data) says 'built once at startup'. Whether this causes a visible hitch is not verified.
- `lib/features/search/data/quran_search_index_impl.dart`: Surah-number matching is a plain substring check on the '$id' suffix, so the query '1' matches every surah whose number contains 1 (1, 10–19, 21, 31, …, 100–114). A short numeric query mixes jump cards with a long, mostly irrelevant surah list.
- `lib/features/surah/presentation/pages/surah_list/widgets/search_results_view.dart`: Surah results are looked up by index in SurahCubit.state (lines 59-73), which loads asynchronously (fetchSurahs). If a search finishes before that list loads, the 'Surahs' header shows a count but every row is an empty SizedBox. The arabicName, englishName, ayahCount, revelationPlace and page fields on SurahResult are filled but never read by the UI.
- `lib/features/surah/presentation/pages/surah_list/widgets/ayah_result_tile.dart`: The meta line joins the surah Arabic name with ayah_label, which is 'سورة {surah}، الآية {ayah}' / 'Surah {surah}, Ayah {ayah}' using the surah number. Rows read 'البقرة · سورة ٢، الآية ٢٥٥ · …', naming the surah twice. The spec asked for 'surah name · s:a · page'.
- `lib/features/surah/presentation/cubit/surah/surah_cubit.dart`: fetchSurahs() awaits getSurahList and then emits with no isClosed check. Leaving /surahList before the list resolves can emit on a closed cubit. This cubit belongs to the surah feature but feeds the search results UI.
- `lib/core/widgets/last_quran_read.dart`: Spec §8 / plan Task 17 says to delete this stale widget. It still exists and no file in lib/ imports it. Only test/core/widgets/last_quran_read_test.dart uses it, so it is dead production code kept alive by a test.
- `lib/features/search/data/quran_search_index_impl.dart`: Path-header comments ('// lib/features/search/...') and doc comments are scattered through the search files (search_cubit.dart, search_state.dart, search_quran.dart, search_results_view.dart, ayah_result_tile.dart, juz_browse_list.dart). This is style debt only, not a functional defect.

</details>

### Planned but not built
- Loading skeleton for search results ('list skeletonizer per loading-states.md, not a spinner'): no Skeletonizer is used anywhere in the search results path. Source: 2026-05-31-surah-list-search-redesign-design.md §5 and acceptance criterion 8.
- Build the search index once at startup: the index is lazy and first built on the first query. Source: 2026-05-31-surah-list-search-redesign-design.md §6 (Data).
- Delete the stale lib/core/widgets/last_quran_read.dart: not done (file and its test remain). Source: 2026-05-31-surah-list-search-redesign.md Task 17 Steps 1-2; design spec §8 and §10.
- A pinned search header built as SliverPersistentHeader inside the CustomScrollView: instead, a fixed _SearchHeader sits outside the scroll view. It still stays visible, so this is a deliberate deviation recorded in a code comment and commit dbe3305a, not a missing feature. Source: design spec §4 item 3; plan Task 13.
- Sealed SearchResult base type and separate SurahNameStrategy / AyahTextStrategy / NumberJumpStrategy classes: not built as designed. The entities are separate Equatable classes and the strategies are inlined in SearchQuran and the index. Behaviour is equivalent; only the structure differs. Source: design spec §6 (Domain).
- SurahResult wrapping SurahEntity: SurahResult has its own fields, and the UI looks up SurahEntity from SurahCubit by index instead. Source: design spec §6 (Domain).
- Ayah row meta in the form 'surah · s:a · page': it renders the surah name plus 'سورة N، الآية M' instead. Source: design spec §5 (B) and acceptance criterion 4.
- Normalizer reality check (plan Task 17 Step 5) and manual smoke test (Step 6): no code evidence that either was run, which is expected because the throwaway test is deleted afterwards. The unit test quran_search_index_impl_test.dart does cover الرحمن↔الرحمان. Source: 2026-05-31-surah-list-search-redesign.md.

### Manual checks on a device
- [ ] From Home, tap the Surahs quick-access tile. Expect the app bar with a bookmark icon, the search field, Surahs/Juzʼ/Pages tabs, and the continue-reading card (or the start-reading card on a fresh install) above the list of 114 surahs.
- [ ] Switch to the Juzʼ tab, tap Juzʼ 30, and confirm the mushaf opens on page 582. Switch to the Pages tab, tap 300, and confirm page 300 opens.
- [ ] Type 'الكوثر' and confirm surah 108 appears under 'Surahs'. Type 'opening' (English) and confirm Al-Fatiha appears. Type 'fatiha' and expect no surah match (confirms the transliteration gap).
- [ ] Type 'الرحمن' and confirm ayah results appear with a total count in the header and a '+N more — refine your search' note when there are more than 100.
- [ ] Tap the ayah result for 55:2 and confirm the mushaf opens on the right page with that ayah highlighted, not the last-read ayah. Then go back to Home and confirm the continue-reading card has moved to that ayah.
- [ ] Type '50' with ASCII digits and confirm only a 'Go to page 50' card appears (50 is past the juzʼ range). Type '5' and confirm both page 5 and juzʼ 5 cards appear, and that the juzʼ card opens page 82.
- [ ] Switch to the Arabic keyboard and type '٥' or '٥٠'. Expect no jump cards (this confirms the Arabic-digit defect).
- [ ] Type '1' and look at the Surahs section: expect about 36 surahs (every number containing 1), which confirms the number-matching noise.
- [ ] Type nonsense such as 'xyzq' and confirm the 'No results' / 'لا توجد نتائج' message appears.
- [ ] Tap the X in the search field and confirm the tabs come back and the previously selected browse tab is restored. Also confirm the keyboard stays open while typing and is dismissed when you drag the results.
- [ ] On a cold app start, open Surahs and immediately type a long query. Watch for a blank area, or a stutter on low-end devices, before the first results appear (missing skeleton and lazy index build).
- [ ] Run the app in both English and Arabic and confirm the hint, section headers, jump-card labels and 'more results' text are localized in each.

### Enhancement ideas
- Map Arabic-Indic (٠-٩) and Persian (۰-۹) digits to ASCII before int.tryParse and inside normalizeArabic.
- Add the transliterated name (surah_data 'name', e.g. 'Al Fatiha') to the surah search key, normalizing hyphens and spaces.
- Match surah numbers exactly (or by prefix) instead of as a substring, and show a 'Go to surah N' jump card for 1–114.
- Show a Skeletonizer-wrapped placeholder (one SurfaceCard plus a few ayah-row placeholders) while isSearching is true and results are empty.
- Pre-warm QuranSearchIndex after the first frame, or build it with compute(), so the first query never pays for building the index.
- Highlight the matched substring in ayah results, and add a 'show more' pagination instead of the hard 100 cap.
- Build SurahListTile from SurahResult directly so surah results do not depend on SurahCubit having loaded.
- Delete lib/core/widgets/last_quran_read.dart and its test, as planned in Task 17.

## Ahadith

**Status:** 🟡 Partial

Users can open seven hadith collections from the Home quick-access tile, browse them page by page, filter by grade and chapter, search in Arabic or English, read a hadith with previous/next and swipe, bookmark and share it, download a whole book for offline use, and see a "Hadith of the Day" card on Home. Everything is wired into routes and DI. A few real bugs remain: a failed book download can still be saved as "downloaded", the list goes blank when loading the next page fails, a downloaded book filtered to a deep chapter can get stuck on a loading card, and the hadith counts shown in the UI are wrong for five of the seven books.

### What it does
- Open the hadith books list from Home > Quick access tile (quick_access_grid.dart -> AppRouter.booksPath '/books' -> BooksListPage), with 7 collections: Bukhari, Muslim, Tirmidhi, Abu Dawood, Ibn Majah, Nasai, Mishkat
- Download a whole book for offline use from the book card's download button, with live % progress. Uses the app-wide DownloadBookCubit provided in main.dart, and the downloaded state is persisted with HydratedCubit
- Browse a book's ahadith with infinite scroll in pages of 100, a shimmer skeleton on first load and a skeleton card while more load (ahadithPath '/ahadith', extra = slug)
- Filter by grade (Sahih/Hasan/Da'eef) from a chip row on the list screen, shown only for books that have more than one grade. Grades per book are hardcoded in AhadithRepositoryImpl._bookStatuses
- Filter sheet (filter icon in the app bar) with grade pills, a selected-chapter card that opens a searchable chapter picker (search by number, Arabic name or English name, plus an 'All chapters' row), and a Clear button. Online books ask the API for filtered pages; downloaded books filter the pages already loaded, in memory
- Search inside a book with a 300ms debounce. Arabic queries use the bundled ahadith_indices.zip index (regenerated in the {t,c,s} format, verified for all 7 books) and are filtered by chapter/grade before the 30-result cap. English queries search the Hive cache for downloaded books (filter before the 100 cap) or the hadithapi.com API with status/chapter params for online books. Changing the filter re-runs an active search
- Open a hadith (hadithPath '/hadith') to see the grade badge, the chapter (Arabic and English) when known, the Arabic text, the English translation and narrator, and Previous/Next buttons plus a horizontal swipe that follows RTL. Neighbours are prefetched by HadithNavCubit
- Share a hadith (Arabic text plus book and number) with share_plus
- Bookmark or unbookmark a hadith (Hive box 'hadith_bookmarks'). Bookmarks appear in the Bookmarks page's Ahadith section, and tapping one fetches the hadith by number from the API and opens it
- Hadith of the Day card on Home: a deterministic pick by UTC date from Bukhari or Muslim, cached per day in the Hive box 'daily_hadith', hidden when unavailable, and tappable to open the hadith page

### Entry points
- Home > Quick access tile labelled hadith_screen_title -> context.push(AppRouter.booksPath) (lib/features/home/presentation/pages/widgets/quick_access_grid.dart:30)
- /books -> BooksListPage -> BooksListView (lib/config/router/app_router.dart:94)
- /ahadith (extra: String bookSlug) -> AhadithListPage, which provides AhadithCubit and SearchHadithCubit (app_router.dart:165)
- /hadith (extra: ({Hadith hadith, String bookSlug})) -> HadithPage, which provides the HadithBookmarkCubit singleton and HadithNavCubit (app_router.dart:176)
- Home > DailyHadithCard (lib/features/home/presentation/pages/widgets/home_view.dart:139) -> /hadith
- Bookmarks page > Ahadith section > _AhadithBookmarkTile -> GetHadithByNumber -> /hadith (lib/features/bookmarks/presentation/pages/bookmarks_page.dart:258)
- DI: initAhadith() and initAhadithSearch() called from initGetIt (lib/core/di/dependency_injection.dart:29-30). Hive boxes 'ahadithCache', 'daily_hadith' and 'hadith_bookmarks' are opened in lib/config/hive_config.dart

### Tests
The tests live in test/features/ahadith (12 files, all unit tests, none of them widget or bloc tests). Covered: the Arabic index parse and filter-before-cap (arabic_search_index_test), chapter lookups and the API status map (hadith_lookups_test), local data source getAhadithByNumbers fast path and fallback plus English filter-before-cap (ahadith_local_data_source_test), search repo routing for all three paths including partial-versus-error for the online Arabic fan-out (ahadith_search_repository_impl_test), server-filtered page params, decoration and getBookStatuses (ahadith_filtered_page_test), next/previous estimate and fallback (ahadith_repository_nav_test, get_next_hadith_test), the daily hadith selector and repository, the hadith bookmark data source and repository, and the HadithListFilter logic. Not tested: every cubit (AhadithCubit filter and pagination races, SearchHadithCubit debounce and reapplyFilter, DownloadBookCubit including the error-then-done bug, HadithNavCubit boundary marking, HadithBookmarkCubit, DailyHadithCubit), downloadAllAhadith, AhadithRemoteDataSource and HadithModel.fromJson, getHadithByNumber, every widget (list view error and pagination states, filter sheet, chapter picker, grade sync, hadith view, daily card), and a smoke test of the real bundled index asset. These are static observations; no tests were executed.

### Known issues
- **HIGH** `lib/features/ahadith/presentation/cubit/download_book_cubit.dart`: A failed download is marked as downloaded. downloadAllAhadith is an async* generator that throws Exception("can'n download book") after 3 retries. An async* stream emits that error and then closes, and listen() is called without cancelOnError, so onError emits DownloadFailure and then onDone runs and emits DownloadSuccess with the slug added to downloadedBooks. HydratedCubit persists that. From then on the book shows a green tick, downloadBook() returns early, search treats it as downloaded (local only, so results are incomplete with no network fallback), and the browse filter becomes in-memory only. clearBookCache exists in the local data source but nothing calls it, so the user cannot recover. Also, _subscriptions entries are never removed, nothing in the UI listens for DownloadFailure (no snackbar), and starting a second download emits DownloadingBook(downloadingProgress: {}), which wipes the first book's progress bar until its next tick.
- **HIGH** `lib/features/ahadith/presentation/pages/widgets/ahadith_list_view.dart`: A pagination error blanks the list. In _buildBrowse, AhadithError with paginationError=true skips the first branch, is neither Loading nor Loaded/LoadingMore, and falls through to `return const SizedBox()`, so every loaded hadith disappears. There is no retry, and the scroll listener has nothing left to scroll. The non-pagination error shows a hardcoded, unlocalized `Text('error')` (line 173), also with no retry.
- **MEDIUM** `lib/features/ahadith/presentation/pages/widgets/ahadith_list_view.dart`: A downloaded book with a filter can get stuck. For downloaded books AhadithCubit.applyFilter returns early, and the view only applies applyHadithFilters to the pages already loaded. More pages load only from _onScroll. If the filtered list is too short to scroll (for example a chapter that starts beyond the loaded pages), the ListView shows only the _LoadMoreSkeleton item and never triggers another fetch, so the user sees an endless skeleton. When a filter is active the header count also shows loaded matches, not the total. This is code-verified; runtime is unverified.
- **MEDIUM** `lib/features/ahadith/presentation/cubit/ahadith_cubit.dart`: A filter change races in-flight fetches (online books). applyFilter calls _reset() and then fetchAhadith. If a load-more is in flight, fetchAhadith returns early (state is AhadithLoadingMore), and the old response is then appended to the cleared list and increments pageNumber to 2, so filtered page 1 is never requested and unfiltered data is shown, masked only by the client-side applyHadithFilters. If a page-1 load is in flight, both responses get appended, mixing results. There is no request token or generation guard.
- **MEDIUM** `lib/features/ahadith/data/repositories/ahadith_repository_impl.dart`: Offline previous/next is reported as the book boundary. _locateByEstimate and the fallback scan fold a network Left into an empty list and return Right(null). HadithNavCubit._prefetch treats Right(null) as a confirmed boundary (atEnd/atStart = true), so Next and Previous are disabled permanently on that screen. This hits the daily hadith and bookmark-opened hadiths offline, which are fetched remotely and whose pages are not cached.
- **MEDIUM** `lib/features/ahadith/presentation/pages/widgets/books_list_view.dart`: Two conflicting hadith-count tables. getHadithBooks() hardcodes counts for the UI (Bukhari 7563, Muslim 7500, Tirmidhi 4400, Nasai 5758, Mishkat 5945). HadithPagination._bookHadithCounts in core/constants/hadith_constants.dart uses 7276/7564/3956/5761/6293, which match the bundled index entry counts I counted. The book cards and the list-screen header (_bookHadithCount) show the wrong numbers for 5 of the 7 books. HadithPagination.hadithCount() should be the single source.
- **MEDIUM** `lib/features/ahadith/ahadith_di.dart`: Startup race in DI. `void initAhadith() async` awaits rootBundle.loadString('all_chapters.json'), a 73KB file that goes through compute because it is over 50KB, before registering anything, including DownloadBookCubit, HadithBookmarkCubit, DailyHadithCubit and the repositories. initGetIt cannot await it, so main.dart may set _ready and build before the registrations exist. With the splash disabled, home is the initial route and DailyHadithCard resolves sl<DailyHadithCubit>() during build. Any asset or parse error would also be swallowed as an unhandled async error. This is a code-level race; it is not observed at runtime.
- **MEDIUM** `lib/features/ahadith/data/repositories/ahadith_search_repository_impl.dart`: Search results are never given their chapter. Browse results go through _decoratePage(chapter: lookup[chapterId]), but none of the three search paths (Arabic via getAhadithByNumbers or remote, downloaded English, online English) attaches a Chapter, even though the repo already holds _bookLookupMaps. Search result cards therefore have no chapter line (AhadithListItem: `if (hadith.chapter != null)`), and a hadith opened from search has no chapter header in HadithView. arabicHadithNormalized is not set either.

<details><summary>Low-severity notes (8)</summary>

- `lib/features/ahadith/presentation/cubit/search_hadith_cubit.dart`: There is no guard against stale responses. Each debounced search awaits the repository and emits its result with no check that it is still the latest query, so a slow earlier request (online Arabic fan-out, or an English API call) can overwrite newer results. SearchHadithError shows the raw failure message (DioException.toString()) to users, unlocalized. SearchHadithLoaded and SearchHadithError have no Equatable props.
- `lib/features/ahadith/data/models/hadith_model.dart`: fromJson does json['chapter']['id'] and _mapStatus(json['status']) on a non-null String. A null chapter or status from the API throws a TypeError, which the repositories do not catch because they catch only DioException. It would surface as an uncaught async error, not a Failure.
- `lib/features/bookmarks/presentation/pages/bookmarks_page.dart`: Opening a hadith bookmark always goes to the network: GetHadithByNumber calls the remote data source even when the book is downloaded and cached, so offline bookmark opening fails. The failure snackbar shows the raw Dio message. A hadith that cannot be found shows the 'coming_soon' string ('Coming soon'), which is the wrong copy. Hadith bookmarks are sorted lexically by hadithNumber string, so '10' comes before '9'.
- `lib/features/ahadith/data/datasources/remote/ahadith_remote_data_source.dart`: The hadithapi.com API key is hardcoded in source and sent as a URL query parameter. It should come from build config or env (key not repeated here).
- `lib/features/ahadith/presentation/pages/widgets/ahadith_search_delegate.dart`: Dead code: AhadithSearchDelegate is referenced nowhere, on this branch or on main.
- `assets/json/ahadith_indices`: A stale, git-tracked, unzipped copy of the legacy-format index (bare-string values, about 24MB across 7 JSON files) sits next to the regenerated ahadith_indices.zip. pubspec lists only `assets/json/`, and Flutter asset directory entries are not recursive, so this folder is not bundled. It is dead repo weight and could confuse a future regeneration step.
- `lib/features/ahadith/data/datasources/local/ahadith_arabic_search_local_data_source.dart`: initBook stores a future that the repository and cubit discard (initializeArabicBookSearch is void), so a load error before the first search would be an unhandled async error. Each list-page open reloads and decompresses the full 4.9MB zip in an isolate. The data source is a lazy singleton cleared in SearchHadithCubit.close(), so it is shared state across cubit instances.
- `lib/config/router/app_router.dart`: /ahadith and /hadith hard-cast state.extra (`as String` and `as ({Hadith hadith, String bookSlug})`), so any navigation without extra (deep link, restoration) throws instead of redirecting.

</details>

### Planned but not built
- 2026-05-30-hadith-search-filters-design.md: the chapter picker should show an 'N of M' / 'M chapters' count. The plan dropped it and chapter_picker_sheet.dart does not render a count.
- 2026-05-30-hadith-search-filters-design.md: the selected-chapter card should have a 'Change ›' affordance. The code shows a chevron icon only, with no 'Change' label. The picker's search hint reuses filter_chapter_label instead of a search prompt.
- 2026-05-30-hadith-search-filters-design.md (Testing): the chapter picker widget tests (search by number/Arabic/English, 'All chapters' reset, selection returns to the sheet) do not exist.
- 2026-05-30-hadith-search-filters-design.md (Testing): the grade-sync test (sheet pills <-> main chip row) does not exist.
- 2026-05-30-hadith-search-filters.md Task 7 Step 4: the smoke test parsing the real regenerated asset does not exist. arabic_search_index_test.dart tests only in-memory maps. I verified the asset format manually by unzipping.
- 2026-05-30-hadith-search-filters.md Task 12: full regression plus manual verification. The plan's checkboxes are all still '- [ ]' and the spec header still says 'Design — pending implementation plan', although Tasks 1-11 are present in code. Both docs are stale.
- 2026-05-30-hadith-search-filters-design.md Open item 1 (hadithapi.com /hadiths accepting status + chapter together with hadithEnglish) cannot be verified from code. The remote call sends them, but no test or note confirms that the API honours them.

### Manual checks on a device
- [ ] Cold start with onboarding done and 'show splash on launch' off, so the app opens straight to Home: confirm there is no GetIt 'not registered' red screen and the Hadith of the Day card shows a skeleton and then a hadith. Repeat 5-10 times on a slow or low-end device.
- [ ] Download failure: on Books, tap download on Sahih Muslim, switch to airplane mode around 20%, and wait about 2s for the retries. Expected: an error and the download button back. Bug check: if the card shows a green tick, kill and relaunch the app and confirm the tick persists and the download button is gone.
- [ ] Download success: download Ibn Majah fully on Wi-Fi, go offline, open it, scroll to the end, and confirm all pages load from cache. Then download two books at once and watch whether the first book's progress bar disappears when the second starts.
- [ ] Pagination error: online, open Sahih Bukhari (not downloaded), scroll to load page 2, go offline, and scroll to trigger page 3. Expected: an inline error or retry. Bug check: the whole list goes blank.
- [ ] Initial load error: go offline and open a non-downloaded book. Note that the screen shows the raw English text 'error' with no retry.
- [ ] Downloaded book with a deep chapter filter: with Ibn Majah downloaded, open it, use Filter > Chapter > pick a chapter near the end of the book (search the picker by its number). Expected: that chapter's ahadith. Bug check: only a shimmer card that never resolves.
- [ ] Online filter race: open Abu Dawood (not downloaded), scroll fast so a load-more is in flight, and immediately tap the 'Da'eef' chip. Confirm the first results are Da'eef from the start of the book and no ahadith are skipped (compare numbers with the chip tapped on a fresh open).
- [ ] Grade sync: on Sunan Nasai, tap 'Hasan' in the chip row, open the Filter sheet, and confirm 'Hasan' is selected there. Tap 'Sahih' in the sheet and confirm the chip row updates after closing. 'Clear' resets both the chip row and the chapter, and closes the sheet.
- [ ] Chapter picker: type '12', then an Arabic chapter word, then an English chapter word, and confirm the list narrows each time. Choosing 'All chapters' clears the chapter. Swiping the picker away keeps the previous chapter.
- [ ] Arabic search with a filter: in Bukhari type 'انما الاعمال' with no filter and confirm hadith #1 appears. Pick a chapter that does not contain it and confirm 'No matching ahadith'. Change the chapter while the query is still typed and confirm the results re-run.
- [ ] English search: in a non-downloaded book, search 'prayer' with grade Da'eef (Abu Dawood) and confirm every result shows a Da'eef badge. Note that the result cards show no chapter line, and the hadith opened from a result has no chapter header.
- [ ] Previous/next: open a hadith from the list, use Next/Previous and swipe (in Arabic, swipe right for next), and confirm the slide direction matches. Then open the Hadith of the Day, go offline, and confirm whether Next and Previous become permanently disabled.
- [ ] Bookmarks: bookmark a hadith, open Bookmarks > Ahadith and tap it online (it opens). Go offline and tap it again: note the raw error snackbar, even if that book is downloaded.
- [ ] Book counts: on the Books screen, compare the counts on the Bukhari, Muslim, Tirmidhi, Nasai and Mishkat cards with the real totals (7276, 7564, 3956, 5761, 6293). The cards currently show 7563, 7500, 4400, 5758 and 5945.

### Enhancement ideas
- Fix DownloadBookCubit: catch the error inside the stream or use cancelOnError: true, mark the book downloaded only after the 100% or lastPage event, remove the _subscriptions entry on done or error, add a BlocListener that shows a localized snackbar, and add a 'remove download' action wired to clearBookCache.
- Use HadithPagination.hadithCount() as the single source for the counts shown in getHadithBooks, and delete the hardcoded duplicates.
- Make initAhadith return Future<void> and await it, along with initPlayback, in initGetIt.
- In _buildBrowse, render AhadithError(paginationError: true) as the existing list plus a retry footer, and replace Text('error') with a localized error-and-retry state.
- In the downloaded-plus-filter path, either keep fetching cached pages until the filtered list fills the viewport or reaches lastPage, or query the Hive cache directly by chapter and status.
- Add a request generation counter to AhadithCubit and SearchHadithCubit so stale responses are dropped.
- Decorate search results with their chapter using the lookups the search repo already has; resolving bookmarks and the daily hadith from the local cache first would make them work offline.
- Have HadithNavCubit tell a network failure apart from a true boundary (propagate Left from the repo scan) so offline Previous/Next is not disabled for good.
- Add the chapter count ('N of M') to the picker, cubit and widget tests, and a smoke test against the real asset. Update the plan checkboxes and spec status.
- Remove the dead AhadithSearchDelegate and the stale tracked assets/json/ahadith_indices/ folder; move the API key out of source.

## home-and-prayer-times

**Status:** 🟡 Partial

The Home screen shows today's Hijri date and city, a live clock with a countdown to the next prayer, all six prayer times (Dhuhr shows as Jumu'ah on Fridays), a last-read card, daily hadith and quick-access tiles. Users can pick the calculation method and Asr school under Settings > Adhan & reminders. It works when location and network are available, but when loading fails the whole home is replaced by an error. That error is either a location card or plain English text, and neither offers a way into Quran, Settings or the other screens. Several merge leftovers and refetch inefficiencies are listed below.

### What it does
- See today's Hijri date (weekday, day, month, year) and city/country in the Home app bar (home_app_bar.dart). After Isha the whole context rolls to tomorrow, including the date (prayer_times_repository_impl.dart:48-57).
- See a large current-time clock in 12h or 24h, following settings, plus an 'X remaining for <prayer>' countdown that ticks every second (upcoming_prayer.dart, prayer_countdown_cubit.dart).
- See the six prayer cards (Fajr, Sunrise, Dhuhr, Asr, Maghrib, Isha) with the next one highlighted. Dhuhr is relabelled Jumu'ah on Fridays, using the date of the loaded context (prayers_list.dart:21-31).
- Prayer times load from cache first and then from the Aladhan /v1/calendar API over https. The cache is invalidated when location, method or school changes (prayer_config_signature.dart, prayer_times_repository_impl.dart:33-41).
- Times refresh silently after Isha and at midnight, and on every app resume (prayer_countdown_cubit.dart:83-103, home_page.dart:275-289).
- Choose the calculation method (Auto by region, or one of 13 Aladhan methods) and the Asr school (Shafi or Hanafi). Path: Home gear > Settings > 'Adhan & reminders' (/notifications) > Calculation method card (notifications_settings_page.dart:120-207). The change triggers a refetch through the HomePage SettingsCubit listener (home_page.dart:124-125,170-174).
- In Auto mode the method is picked from the reverse-geocoded English country name, falling back to MWL (calculation_method_for_country.dart).
- Toggle adhan per prayer and set a reminder offset (Off, 5, 10 or 15 min), then play a test adhan after 5 s. Android uses a native channel, other platforms use flutter_local_notifications (per_prayer_adhan_tile.dart, test_adhan_button.dart).
- Recovery card when location fails: 'Enable location' re-requests permission and refetches; for denied-forever or GPS off, 'Open settings' opens app or location settings (home_view.dart:49-80).
- Dismissible Home hint when OS notifications are disabled, with an 'Allow' button that requests permission (notification_hint.dart).
- Last-read card with progress and 'Continue', which pushes /mushaf with the page (last_read_card.dart).
- Quick-access tiles: Quran (/surahList), Hadith (/books), Bookmarks (/bookmarks), Settings (/settings), Qibla (/qibla) (quick_access_grid.dart).
- Each loaded context re-syncs the pinned prayer strip and the next 3 days of adhans and reminders (home_page.dart:73-110).

### Entry points
- /home -> HomePage (app_router.dart:46-59). It is the initial location after onboarding when the splash is disabled (main.dart:109-113), and is otherwise reached via the splash.
- /notifications -> NotificationsSettingsPage (app_router.dart:81-85), reached only from SettingsPage's 'Adhan & reminders' tile (settings_page.dart:149-150).
- /settings via the HomeAppBar gear and the Settings quick tile (both rendered only in the Loaded state).
- DI: initHome() is called from initGetIt() (core/di/dependency_injection.dart:23). Hive boxes prayerTimesCache, userLocationCache and prayerConfig are opened in config/hive_config.dart. The notification use cases come from initNotifications().

### Tests
Not executed, per the read-only rule. Covered: prayer_config_signature_test, prayer_times_local_data_source_test (key-month filter, clearOldCache), prayer_time_remote_data_source_test, prayer_times_model_validation_test, prayer_times_repository_impl_test (after-Isha wholesale roll; preCacheMonth with a mocked 'fully cached' month), prayer_times_get_cached_for_date_test, pre_cache_prayer_times_test, resolve_calculation_params_test, daily_prayer_context_cubit_test (loading/failed/typed failure, in-flight cancel), prayer_countdown_cubit_test, location_recovery_card_test, notification_hint_test, plus test/core/constants/calculation_method_test, test/core/utils/calculation_method_for_country_test and the settings calc-model tests. Untested: the GetDailyPrayerContext use case, LocationRepositoryImpl (cached-then-fresh stream, 20 km rule, error mapping), LocationModel parsing, the HomePage listener orchestration (strip, adhan sync, pre-cache, resume guard), HomeView state rendering including the failure dead-end, HomeAppBar, UpcomingPrayer, PrayersList (Jumu'ah, 12h/24h), QuickAccessGrid, LastReadCard, NotificationsSettingsPage with the calc-method pickers, and the unawaited clearCache ordering.

### Known issues
- **HIGH** `lib/features/home/presentation/pages/widgets/home_view.dart`: Home dead-ends when loading fails. In DailyPrayerContextFailed, only a LocationRecoveryCard or `Center(child: Text(state.message))` is shown (lines 47-81). HomeAppBar (the Settings gear), QuickAccessGrid, LastReadCard and the daily hadith render only when Loaded, and /home is the root route. On a first launch with no network, location denied, or the GPS off, the user cannot open Quran, Hadith, Bookmarks, Settings or Qibla at all. The generic branch also has no retry button.
- **MEDIUM** `lib/features/home/presentation/pages/widgets/home_view.dart`: Error text is not localized. The generic failure branch shows Failure.message, which is hardcoded English in GeolocatorErrorHandler, DioErrorHandler and PrayerTimesRepositoryImpl. Examples: 'No internet connection.', 'Failed to get location within the specified time.', 'Prayer times unavailable for the requested date.'. These appear as-is in the Arabic UI. TimeoutFailure (location timeout) also lands here with no retry.
- **MEDIUM** `lib/features/home/data/repositories/prayer_times_repository_impl.dart`: preCacheMonth's 'fully cached' short-circuit (line 110) can never fire for the current month after the 2nd day. PrayerTimesLocalDataSource.cache() always runs clearOldCache(), which deletes keys before yesterday (prayer_times_local_data_source.dart:42-64), so the current month never holds daysInMonth keys. HomePage calls PreCachePrayerTimes on every Loaded emission (home_page.dart:78-86). Loaded fires on every app resume, every listed settings change (including theme palette and language), the notification-hint Allow, after Isha and at midnight. Each one makes a redundant Aladhan calendar request, two during the last 7 days of a month. The unit test passes only because it mocks getCachedKeysForMonth to return 30 keys.
- **MEDIUM** `lib/features/home/data/datasources/remote/location_remote_data_source.dart`: Prayer times depend on reverse geocoding. getCurrentLocation(position) makes two Nominatim calls (ar and en). If they fail with a DioException and no location is cached, the repository yields Left (location_repository_impl.dart:45-46), so Home shows an error even though GPS coordinates are available and Aladhan only needs lat/lon.
- **MEDIUM** `lib/features/home/data/datasources/local/prayer_times_local_data_source.dart`: PLAUSIBLE, unverified. clearCache() calls `prayerTimesBox.clear()` without awaiting it (line 39), and getPrayerTimes reads getCached on the very next line (prayer_times_repository_impl.dart:39-42). The signature has already been stored as changed. If Hive clears its in-memory keystore only after the disk clear completes, the first fetch after a method or school change returns and schedules adhans for the old-method times. No test covers this, because the repository test mocks clearCache.
- **MEDIUM** `lib/features/home/data/datasources/remote/location_remote_data_source.dart`: PLAUSIBLE: the location permission prompt may repeat. determinePosition() calls Geolocator.requestPermission() whenever the status is `denied` (lines 20-23). It runs on every app resume (_StripResumeGuard, home_page.dart:275-284) and every listed settings change, even when a cached location exists. A user who chose 'Don't allow' may be re-prompted on each resume. Whether the dialog's own pause/resume retriggers it is not verified.

<details><summary>Low-severity notes (8)</summary>

- `lib/features/home/presentation/cubit/prayer_countdown_cubit.dart`: Merge leftover: two sunrise rules. The home countdown iterates prayersList, which includes sunrise (prayers_list_constants.dart:14-21), so between Fajr and Shuruq Home highlights 'Sunrise' as next. NextPrayerResolver, used by the pinned strip, excludes sunrise after commit 358e47f8 dropped the teammate's skipSunrise flag. Home and the strip disagree on the next prayer in that window, and no test asserts either behaviour for Home.
- `lib/features/home/presentation/cubit/daily_prayer_context_cubit.dart`: No isClosed check after await. fetchDailyPrayerContext awaits `_sub?.cancel()` and then calls emit(Loading) and re-subscribes without checking isClosed (lines 27-31). Two calls in the same frame also race: both await the same old subscription, then each assigns _sub, and the first new subscription is never cancelled.
- `lib/features/home/presentation/pages/home_page.dart`: Redundant work on settings changes. The SettingsCubit listener (lines 112-178) fires on palette, language and 12/24h changes too. It runs SyncDailyAdhans with the old context and then calls fetchDailyPrayerContext, whose Loaded listener runs SyncDailyAdhans and pre-cache again. That means double adhan scheduling plus a GPS fix and network call for purely cosmetic changes. The `loaded` parameter of _enableOrRefreshStrip (line 221) is never read.
- `lib/features/home/domain/usecases/get_prayer_times.dart`: Dead code left from the merge. GetPrayerTimesUseCase is not registered or referenced, and it calls getPrayerTimes(location) with the interface defaults method=3 and school=0, ignoring the user's setting. The plan called for the params to be `required`, but prayer_times_repository.dart:7-21 still has the defaults. SettingSwitch (setting_switch.dart) is unused. LocationRepositoryImpl still injects prayerTimesLocalDataSource but never reads it (location_repository_impl.dart:17); the prayer-timings-fixes Task 0.4 said to remove it.
- `lib/features/home/presentation/pages/widgets/quick_access_grid.dart`: Merge leftover in the layout. The teammate's Qibla tile is a 5th child in a `crossAxisCount: 4` grid, so Qibla sits alone on a second row. The spec defines exactly 4 tiles.
- `lib/features/home/presentation/pages/widgets/upcoming_prayer.dart`: The hero and the next-card highlight blink. _emitTick emits Tick and then immediately PrayerCountdownRequestRefresh (after Isha or a stale day). UpcomingPrayer returns SizedBox and PrayersList drops isNext for any non-Tick state, until the refreshed context restarts the timer.
- `lib/features/home/presentation/pages/widgets/test_adhan_button.dart`: _onPressed has no try/catch. A PlatformException or PlatformNotImplementedException from the native or legacy scheduler is unhandled, and no snackbar appears.
- `lib/features/home/presentation/pages/notifications_settings_page.dart`: The calculation-method picker sits under 'Adhan & reminders', which is hard to find. The method DropdownButton is not isExpanded, inside a Row next to an Expanded label. Long names such as 'University of Islamic Sciences, Karachi' or 'الجمعية الإسلامية لأمريكا الشمالية' may overflow on narrow phones (not verified on device).

</details>

### Planned but not built
- 2026-05-13-prayer-times-refresh-and-caching-design.md: 'Date header stays on today's date after Isha' is SUPERSEDED, not unbuilt. Commit dfc0f994 (M2) rolls the whole context, including the date, to tomorrow, and the repository test asserts this.
- 2026-05-13-prayer-times-refresh-and-caching-design.md: the 'fetch next month only if not yet cached' design became preCacheMonth for the current month plus the next month in the last 7 days. The current-month skip never triggers (see issues), so the spec's 'silent background check' does network work on every load.
- 2026-05-13-prayer-times-refresh-and-caching(.md, -design.md): every other item is built. That covers the clearOldCache dd-MM-yyyy parser, getCachedKeysForMonth, year/month params, the PreCachePrayerTimes use case with DI, silent refresh, the two-flag after-Isha and midnight refresh, and nullable-context guards.
- 2026-05-28-screens-remaster-design.md §5.1: the prayers row was specced as 5 cards and has 6 (sunrise included). Quick grid was specced as 4 tiles and has 5 (Qibla added). The countdown was specced as 'Xh Ym until **Isha**' with a bold secondary name and is rendered as a digital clock in a single-style string. The last-read progress was specced as page/604 and uses computeSurahProgress (surah-relative). The plan's rename UpcomingPrayer -> TimeHero (Task 21) was not done. Other remaster tasks outside home were not checked.
- ADJACENT plan 2026-05-30-prayer-timings-fixes.md (does not match the doc pattern): the dedicated prayer_calculation_settings_page.dart from Task 1.7 was never created; the pickers are inline in notifications_settings_page.dart instead. Task 3.1, re-initializing the timezone and scheduler on resume only when timeZoneOffset changes, is not in Dart: there is no timeZoneOffset in lib, and resume always refetches. Commit ccd7aaa3 added a native TIMEZONE_CHANGED receiver instead.

### Manual checks on a device
- [ ] Run it (after this read-only workflow): `fvm flutter pub get` then `fvm flutter run` on an Android device. Flutter is pinned to 3.38.1 via FVM.
- [ ] Fresh install, airplane mode on, finish onboarding. Expected per the code: Home shows only the English text 'No internet connection.' with no Settings gear, quick tiles or retry. Confirm you cannot reach Quran.
- [ ] Fresh install, deny location twice. Confirm the recovery card appears and 'Enable location' re-prompts. Background and resume the app, and note whether the OS permission dialog pops again by itself.
- [ ] With location granted, check that the city/country and Hijri date in the app bar match the device language (ar vs en), and that the countdown ticks every second.
- [ ] Between Fajr and sunrise, compare Home (next = Sunrise card highlighted) with the pinned prayer strip notification (next = Dhuhr), if the strip is enabled.
- [ ] Settings > Adhan & reminders: change Method from Auto to Umm al-Qura, go back to Home, and check that Asr/Isha times change immediately rather than only after the next resume. Then switch Asr school to Hanafi and check that Asr moves later.
- [ ] Open the Method dropdown on a small phone (about 360dp wide) in Arabic and check for a RenderFlex overflow stripe.
- [ ] With a network inspector or proxy, background and foreground the app 3 times and count api.aladhan.com /v1/calendar requests (the code predicts at least one per resume after the 2nd of the month).
- [ ] On a Friday, confirm the Dhuhr card and the countdown read 'Jumu'ah'. After Isha, confirm the prayer list and the Hijri date both switch to tomorrow and Fajr is highlighted.
- [ ] Look at the quick-access grid and confirm Qibla sits alone on a second row. Tap each tile (Quran, Hadith, Bookmarks, Settings, Qibla) and check it opens its screen.
- [ ] Tap 'Play test adhan' on Android and expect a snackbar, then the adhan about 5 s later. On iOS expect a local notification.

### Enhancement ideas
- Render the app bar and QuickAccessGrid in every state, and show the failure as an inline, localized card with a Retry button, so Quran and Settings stay reachable offline.
- Map Failure types to localized ARB strings in the presentation layer instead of showing Failure.message.
- Use a single next-prayer rule (sunrise excluded or included) shared by PrayerCountdownCubit and NextPrayerResolver.
- Skip the current month in PreCachePrayerTimes (getPrayerTimes already fetched it), or compare against the days from yesterday to month end.
- Await clearCache() in getPrayerTimes before reading the cache.
- Fall back to coordinates-only prayer times when Nominatim fails, and fill in the city name later.
- Narrow the SettingsCubit listenWhen so palette and language changes resync the strip only, without a refetch.
- Give calculation method a 'Prayer times' tile of its own on the Settings page, and make the dropdown isExpanded or move it to a bottom sheet.
- Delete GetPrayerTimesUseCase, SettingSwitch, the unused LocationRepositoryImpl field and the method/school interface defaults.
- Add widget tests for HomeView states and NotificationsSettingsPage, plus unit tests for LocationRepositoryImpl and GetDailyPrayerContext.

## notifications-adhan-native

**Status:** 🟡 Partial

On Android the app can play the full adhan at each prayer time with Stop and swipe-to-dismiss, show optional countdown reminders before each prayer, and pin a 5-prayer strip to the notification shade. All three are wired through Dart DI and the native MethodChannel and re-armed after reboot or a time change. iOS is much weaker: the strip toggle does nothing, the per-prayer adhan switches are ignored, only one day is scheduled, the custom adhan sounds are not in the app bundle, and the notification text is English only.

### What it does
- Android: plays the full adhan at Fajr, Dhuhr, Asr, Maghrib and Isha through a native AlarmManager, AdhanAlarmReceiver and AdhanPlaybackService pipeline (foreground service, USAGE_ALARM MediaPlayer). Fajr uses its own clip. Alarms are armed for up to 3 days by SyncDailyAdhans, which the HomePage BlocListener runs whenever DailyPrayerContextLoaded is emitted or the relevant settings change.
- Android: the adhan notification has a Stop action and can be swiped away; both stop playback (ACTION_STOP). After the clip finishes, the notification detaches and stays until swiped.
- Turn the adhan on or off per prayer (5 switches) in Settings > Adhan & reminders (/notifications route, NotificationsSettingsPage > PerPrayerAdhanTile). Persisted in SettingsCubit (adhanEnabledByPrayer). On Android a disabled prayer is dropped from the native timings payload.
- Pick a pre-prayer reminder of Off, 5, 10 or 15 minutes per prayer (ReminderOffsetDropdown). On Android it posts a notification whose system chronometer counts down to the prayer (PrayerReminderReceiver). AdhanAlarmReceiver dismisses it when the adhan fires. On iOS it is a single static notification.
- Pin the prayer strip from the Settings page switch (settings_page.dart, gated by FeatureFlags.pinnedPrayerStripUi = true). It is an ongoing notification with 5 cells and the next prayer highlighted in the app palette's accent colour. A 7-day window comes from the prayer-times cache via BuildPrayerStripWindow. Native exact alarms at each prayer time and at 00:01 move the highlight and roll over to the next day without opening the app. Unpinning cancels it (DisablePrayerStrip).
- The strip is pushed again when the app resumes (_StripResumeGuard), when the next prayer changes (PrayerCountdownCubit tick), and when language, palette, 12/24h format, calculation method or Asr school change.
- Choose the calculation method and Asr school on the same Adhan & reminders page (merged in from the teammate branch). A change triggers a silent refetch, which re-arms adhans and reminders and re-pushes the strip.
- 'Play test adhan' button: native test alarm in 5 s on Android, a flutter_local_notifications test notification on iOS, with a localized snackbar.
- Notification permission is requested in onboarding. A dismissible Home hint (NotificationHint) and a banner on the Adhan & reminders page appear when notifications are disabled at OS level and re-check on resume.
- Android re-arms adhans and reminders from saved snapshots on BOOT_COMPLETED, MY_PACKAGE_REPLACED, TIMEZONE_CHANGED and TIME_SET (AdhanBootReceiver). The strip is re-posted on boot (PrayerStripBootReceiver).
- Stale-alarm guard: an adhan alarm delivered more than 30 minutes late (clock jump or Doze) is dropped. If notifications are disabled, the adhan is skipped so audio never plays without a Stop control.
- iOS: adhan notifications with custom .caf sounds (sounds not bundled, see issues) and static reminders for days.first only, through PrayerNotificationSchedulerImpl.

### Entry points
- /notifications route (AppRouter.notificationsPath) -> NotificationsSettingsPage, opened from SettingsPage's 'Adhan & reminders' row (under FeatureFlags.pinnedPrayerStripUi)
- SettingsPage 'Pinned prayer times' switch -> SettingsCubit.updatePrayerStripPinned
- HomePage BlocListeners (DailyPrayerContextLoaded, SettingsCubit changes, PrayerCountdownCubit next-prayer change, pin-off) and _StripResumeGuard on app resume
- main.dart _initAll -> PrayerNotificationScheduler.init(); OnboardingPage notifications step -> requestNotificationsPermission; HomeView NotificationHint
- MethodChannel 'quran_app/notifications' -> PrayerStripPlugin (registered in MainActivity.configureFlutterEngine)
- Android manifest receivers: AdhanAlarmReceiver, PrayerReminderReceiver, PrayerAlarmReceiver, AdhanBootReceiver (BOOT_COMPLETED/MY_PACKAGE_REPLACED/TIMEZONE_CHANGED/TIME_SET), PrayerStripBootReceiver (BOOT_COMPLETED/MY_PACKAGE_REPLACED/QUICKBOOT); service AdhanPlaybackService (mediaPlayback)

### Tests
The Dart domain and data layers are well covered under test/features/notifications/ (about 1,100 lines across 13 files): the repository's Android/iOS routing for adhans, the enabled filter, 3-day ISO payload, MissingPluginException handling and reminder routing for 0 minutes; channel arguments in the native data source; the strip builder (12/24h, Arabic numerals, Jumu'ah); next-prayer resolver; BuildPrayerStripWindow (gaps, null today); entities; and the strip use cases. Also covered: SettingsModel round-trip of the adhan and reminder maps, and the updateReminderMinutes assertion (test/features/settings/settings_cubit_test.dart), plus NotificationHint widget visibility. Untested:
- PrayerNotificationSchedulerImpl, the entire iOS path.
- The iOS branch of schedulePrayerReminders that schedules static reminders (only cancel is tested).
- The HomePage orchestration (sync on load, settings change, after-Isha day list, resume guard).
- Widgets: NotificationsSettingsPage, PerPrayerAdhanTile, ReminderOffsetDropdown, TestAdhanButton and the Settings-page strip toggle.
- That reminders are filtered by enabled prayer (a test currently asserts the unfiltered map is passed through).
- Any Kotlin code: there is no android/app/src/test, so the schedulers, receivers, controller, renderer and plugin argument parsing have no JVM tests.

### Known issues
- **HIGH** `lib/features/notifications/data/repositories/notifications_repository_impl.dart`: The per-prayer adhan toggles are ignored on iOS. The non-Android branch of scheduleDailyAdhans calls legacyScheduler.scheduleDailyPrayerNotifications(days.first) without enabledByPrayer. PrayerNotificationSchedulerImpl.scheduleDailyPrayerNotifications always schedules all 5 prayers (_notificationIds loop). Turning Fajr off in settings still fires the Fajr adhan on iPhone.
- **HIGH** `ios/Runner.xcodeproj/project.pbxproj`: ios/Runner/fajr_adhan.caf and normal_adhan.caf exist on disk but have zero references in project.pbxproj; the Runner Resources build phase lists only LaunchScreen, AppFrameworkInfo.plist, Assets.xcassets and Main.storyboard. They are therefore not copied into Runner.app, so DarwinNotificationDetails(sound: 'fajr_adhan.caf' / 'normal_adhan.caf') has no file to play. The plan's manual Xcode step (plans/2026-05-14-adhan-audio-notifications.md Task 1 Step 3) was never done.
- **MEDIUM** `lib/features/settings/presentation/pages/settings_page.dart`: The 'Pinned prayer times' switch shows on iOS too (only FeatureFlags.pinnedPrayerStripUi gates it, with no platform check). There is no iOS handler for quran_app/notifications, so enableStrip throws MissingPluginException, which becomes PlatformNotImplementedException and then Left(PlatformNotSupportedFailure). home_page.dart _enableOrRefreshStrip only debugPrints that failure. The user flips a switch that does nothing and gets no feedback.
- **MEDIUM** `lib/features/notifications/domain/usecases/sync_daily_adhans.dart`: Reminders are not filtered by adhanEnabledByPrayer. The spec (advanced-adhan §4 invariant, §6.2, §9.2, §11.1) says a disabled prayer must drop out of both chains, and the UI greys the dropdown as if it were off. In code, home_page.dart passes settings.reminderMinutesByPrayer as is, SyncDailyAdhans forwards it, and the repository filters only `value > 0`. A prayer with its adhan off but a stored 10-minute offset still gets a reminder. On Android that countdown notification is never auto-dismissed, because AdhanAlarmReceiver, which normally clears it, is never armed for that prayer.
- **MEDIUM** `lib/features/home/presentation/pages/home_page.dart`: After Isha the adhan and reminder payload repeats a day. PrayerTimesRepositoryImpl.getPrayerTimes returns tomorrow's PrayerTimes once now is after Isha, and home_page.dart (lines 90-98 and 148-156) then appends local.getCached(today+1) and (today+2). The result is days=[T+1, T+1, T+2]. Android arms duplicate alarms for T+1 (request codes 200-204 and 210-214 at the same times) and loses the third day of coverage. The duplicate adhan is suppressed by the service re-entry guard, so the visible effect is mainly the shorter horizon. The same day-building block is also copy-pasted in two listeners.
- **MEDIUM** `lib/core/notifications/prayer_notification_scheduler_impl.dart`: iOS notification text is hardcoded in English in an Arabic-first app: adhan title _prayerTitles ('Fajr', ...), body 'Time for X prayer', and the test notification 'Adhan test' / 'Background fire check (Ns)'. iOS reminder title and body are built from inline Arabic and English literals in notifications_repository_impl.dart (_prayerNameLocalized, _reminderBody) rather than the ARB keys reminderNotificationTitle and reminderNotificationBody the spec asked for, which do not exist.
- **MEDIUM** `lib/main.dart`: Plausible, not confirmed: an iOS init race. _initAll sets _ready=true, so the router and HomePage build, before it awaits PrayerNotificationScheduler.init(). If DailyPrayerContext loads from cache before init finishes, the iOS legacy scheduleDailyPrayerNotifications and scheduleStaticReminder return early on `!_initialized`. cancelAllStaticReminders has already run by then, so nothing is armed until the next sync.

<details><summary>Low-severity notes (8)</summary>

- `lib/core/notifications/prayer_notification_scheduler_impl.dart`: init() still creates the legacy Android channels prayer_fajr_channel ('Fajr adhan') and prayer_standard_channel ('Prayer adhan'), although the Android legacy path is deliberately inert. The native AdhanPlaybackService channel prayer_adhan_channel has the same name, 'Prayer adhan'. Android's per-app notification settings therefore list duplicate or orphan adhan channels, and muting the wrong one has no effect.
- `android/app/src/main/kotlin/com/example/quran_app/AdhanPlaybackService.kt`: The channel names 'Prayer adhan' and 'Prayer times strip' (PrayerStripRenderer.kt) and their descriptions are hardcoded English, unlike the reminder channel, which uses localized string resources. localizedContext() also calls Locale.setDefault(), which changes the default locale for the whole process.
- `android/app/src/main/kotlin/com/example/quran_app/PrayerStripPlugin.kt`: Dead parts of the Dart/native contract. Dart sends 'volume' in scheduleDailyAdhans, but Kotlin never reads it. SyncDailyAdhansParams.audio is never supplied, so AdhanAudioSettings is always defaults(). nextPrayerIndex is serialized by Dart and dropped by serializeStripArgs. hijriDateLabel, weekdayLabel and isFriday are required natively (a missing key makes the call fail with BAD_ARGS), yet no view renders them: the strip layouts contain only cell_0..4 label and time ids. res/drawable/moon_crescent.xml is referenced nowhere.
- `lib/features/notifications/notifications_di.dart`: Leftover code. RefreshPrayerStrip is registered in DI and unit-tested but never called (home_page uses EnablePrayerStrip for refreshes too, and Kotlin routes both to the same handler). AdhanScheduler.armToday and PrayerReminderScheduler.armToday are unused. PrayerStripController.cancelAlarms still loops over 6 slots (0..5) for 5 cells, a sunrise-era leftover.
- `android/app/src/main/AndroidManifest.xml`: Merge asymmetry. The teammate's branch added TIMEZONE_CHANGED and TIME_SET to AdhanBootReceiver but not to PrayerStripBootReceiver. After travel or a DST change, the strip's RTC refresh alarms (computed from local wall-clock at scheduling time) stay misaligned until the next app open or alarm.
- `lib/features/home/presentation/pages/widgets/test_adhan_button.dart`: Calls NotificationsNativeDataSource directly (presentation to data, bypassing domain) with no try/catch. A PlatformException leaves an unhandled async error and no feedback. The 'Test adhan in 5 seconds' snackbar shows even when nothing will play: Android AdhanAlarmReceiver skips when notifications are disabled, and iOS scheduleTestNotification returns silently before init.
- `lib/features/home/presentation/pages/notifications_settings_page.dart`: Duplicate concept after the merge: _NotifDisabledBanner re-implements NotificationHint (same areNotificationsEnabled check, resume observer and permission request). The page title uses S.current instead of S.of(context). The calculation-method and Asr-school pickers (prayer-time calculation, not notifications) were added to the 'Adhan & reminders' page, and the only route to it sits under the pinnedPrayerStripUi flag. Turning that flag off would hide adhan settings and calculation method too.
- `android/app/src/main/kotlin/com/example/quran_app/AdhanPlaybackService.kt`: Small gaps against the June spec's Fix 4. After completion the re-posted notification uses buildNotification(ongoing=false), which sets setAutoCancel(false) where the spec asked for true. If R.raw.<clip> is missing or the MediaPlayer fails, the service stays in the foreground with no audio until the user dismisses it.

</details>

### Planned but not built
- iOS Live Activity for the pinned strip (ios/PrayerStripWidget extension, ios/Runner/PrayerStripChannel.swift handling the same MethodChannel): not built; AppDelegate.swift registers only generated plugins (specs/2026-05-23-pinned-prayer-notification-design.md §9, plans/2026-05-23-pinned-prayer-notification-dart-foundation.md)
- On iOS below 16.1, a disabled strip toggle with an explanation, plus the localized tile subtitle about the 8-hour Live Activity limit: not built; the toggle is always enabled and has no subtitle (specs/2026-05-23-pinned-prayer-notification-design.md §5 / lines ~100, 379-380)
- Full-length iOS adhan via just_audio_background, started from the notification-fired hook: not built (specs/2026-05-23-pinned-prayer-notification-design.md §9.4)
- Register fajr_adhan.caf and normal_adhan.caf in the Runner Xcode target (Copy Bundle Resources): not done (plans/2026-05-14-adhan-audio-notifications.md Task 1 Step 3)
- Reminders dropped for prayers whose adhan is disabled, with filtering in SyncDailyAdhans and a unit test for it: not built (specs/2026-05-23-advanced-adhan-settings-design.md §4, §6.2, §9.2, §11.1)
- ARB keys reminderNotificationTitle and reminderNotificationBody for the reminder text: not added; the iOS reminder title is the bare prayer name (specs/2026-05-23-advanced-adhan-settings-design.md §6.4, §8)
- Reminder channel created at app startup alongside the adhan and strip channels: currently created lazily in PrayerReminderReceiver on the first reminder (specs/2026-05-23-advanced-adhan-settings-design.md §7.4)
- Prayer icon in each PerPrayerAdhanTile row: not present; the row has only a label, switch and dropdown (specs/2026-05-23-advanced-adhan-settings-design.md §6.2-6.3)
- Kotlin JVM tests for PrayerReminderScheduler, PrayerReminderReceiver and AdhanAlarmReceiver: no android/app/src/test exists (specs/2026-05-23-advanced-adhan-settings-design.md §11.1; specs/2026-06-13-prayer-notification-fixes-design.md Testing)
- Strip header with Hijri date, deep-teal crescent and weekday (bold accent on Friday): removed from the layouts in commit 0cd722f6 while Dart still sends the fields. Treat it as unbuilt or as deliberately dropped; the spec was never updated (specs/2026-05-23-notifications-fixes-design.md §7.1)
- Adhan notification re-posted after completion with autoCancel=true: the code keeps autoCancel(false) (specs/2026-06-13-prayer-notification-fixes-design.md Fix 4)

### Manual checks on a device
- [ ] Android 13+: fresh install, then in onboarding allow notifications. Open Home and run `adb logcat -s Adhan:V PrayerReminder:V`. Expect 'armDays: N armed' for the remaining prayers. Run `adb shell dumpsys alarm | grep quran_app` and confirm AdhanAlarmReceiver alarms at the correct times.
- [ ] Settings > Adhan & reminders > 'Play test adhan'. A snackbar appears and the adhan plays within about 5 s at alarm volume. Expand the shade: audio continues. Tap Stop: audio stops. Repeat, swipe the notification away: audio stops. Repeat, let the clip finish: the notification stays and can be swiped.
- [ ] Turn the Maghrib adhan off and check dumpsys: no Maghrib adhan alarm. Then set a Maghrib reminder of 10 min before turning it off (the dropdown greys out) and check whether a PrayerReminderReceiver alarm still exists for Maghrib. The code predicts it does (defect).
- [ ] Set Asr reminder = 5 min. At T-5 a notification titled 'Asr reminder' / 'تذكير العصر' appears with a counting-down chronometer. At T-0 it is dismissed and the adhan notification appears.
- [ ] Open the app after Isha and look at the logcat armDays lines. Expect the same date armed twice (day 0 and day 1) because of the duplicate-day defect.
- [ ] Pin the strip (Settings > Pinned prayer times). Five cells show, with the next prayer in the palette accent. Switch to 12h format and Arabic: the highlight is still correct and the Arabic-Indic digits render. Leave the app closed past a prayer time and past midnight: the highlight advances and the new day renders. Unpin: the notification disappears.
- [ ] Reboot with the strip pinned and adhans armed. The strip reappears and `dumpsys alarm` shows the adhan and reminder alarms re-armed. Change the timezone in system settings: logcat shows AdhanBootReceiver re-arming. Note that the strip's alarms are not re-armed.
- [ ] Change the calculation method or Asr school on the Adhan & reminders page. Home times update and logcat shows a fresh armDays with the new times.
- [ ] Turn notifications off in system settings and wait for or trigger a test adhan. There should be no audio (logged 'notifications disabled — skipping'), yet the snackbar still says scheduled. The Home hint and the settings banner should show, and 'Allow' re-prompts.
- [ ] Android system Settings > Apps > quran_app > Notifications: inspect the channel list for duplicate 'Prayer adhan' entries and the 'Fajr adhan' legacy channel.
- [ ] iOS: toggle 'Pinned prayer times'. Nothing visible happens (expected defect). Turn the Fajr adhan off and confirm whether the Fajr notification still fires (the code predicts it does). Tap 'Play test adhan' and listen: expect the default system sound, not the adhan, because the .caf files are not bundled. With the app in Arabic, the notification text is English.
- [ ] iOS: cold-start the app with cached prayer times and check the console for '[PrayerNotif] schedule called before init — skipping'. That line would confirm the init race.

### Enhancement ideas
- Make the reminder map depend on adhanEnabledByPrayer in SyncDailyAdhans and add the missing unit test.
- Pass enabledByPrayer through to the iOS legacy scheduler. Schedule up to 3 days on iOS with day-indexed IDs to match Android.
- Add the two .caf files to the Runner target's Copy Bundle Resources.
- Hide or disable the pinned-strip switch on non-Android platforms until a Live Activity exists, or show an explanation.
- Build the adhan/reminder day list from explicit dates (today, +1, +2 via getCachedForDate) instead of the context's prayerTimes, to remove the duplicate day after Isha. Pull the copy-pasted block into one helper.
- Drop the legacy Android channel creation in PrayerNotificationSchedulerImpl.init(), or delete those channels. Localize the native channel names through strings.xml.
- Move the iOS adhan and reminder strings into the ARB files and pass them in from the presentation layer.
- Remove the dead pieces: RefreshPrayerStrip, armToday, the volume and nextPrayerIndex payload fields, the unrendered header fields, and moon_crescent.xml. Or restore the strip header the 05-23 spec described.
- Add TIMEZONE_CHANGED and TIME_SET to PrayerStripBootReceiver.
- Route TestAdhanButton through a use case with error handling. Warn instead of showing 'scheduled' when notifications are disabled.
- Merge _NotifDisabledBanner into NotificationHint. Consider moving the calculation-method pickers to a 'Prayer times' section that is not under the strip feature flag.
- Add a small Robolectric or JVM test target for the request-code arithmetic in PrayerReminderScheduler and AdhanScheduler, and for the strip's computeNextIndex.

## Qibla finder

**Status:** 🟡 Partial

The Qibla screen is fully wired. A user opens it from the Home quick-access grid and sees a compass with a Kaaba needle that turns with the phone, the bearing in degrees, the distance to Makkah and their city, with a plain-numbers fallback on phones without a compass. The core maths and wiring are sound, but on Android the "aligned" state is probably blocked at the plugin's medium accuracy level. The screen can also only be reached once Home has loaded prayer times, and a few strings, a tooltip and a re-entrancy guard are missing.

### What it does
- Open the Qibla screen from the 5th Home quick-access tile ('القبلة' / 'Qibla'), which calls context.push(AppRouter.qiblaPath) (quick_access_grid.dart:42-46). The route /qibla in app_router.dart:105-112 builds BlocProvider(sl<QiblaCubit>()..start()) around QiblaPage.
- See a Skeletonizer skeleton (dial, readout and meta cards) while the location resolves (QiblaSkeleton, used for the QiblaInitial and QiblaLoading states).
- See a live compass. The dial and N/E/S/W letters stay fixed and the Kaaba needle rotates to bearing - trueHeading along the shortest arc (AnimatedRotation, 400ms). On Android the heading is corrected from magnetic to true north with the geomag WMM-2025 declination; on iOS the raw heading is treated as already true (rawHeadingIsTrue = Platform.isIOS).
- See a status pill: 'Point your phone toward the Kaaba', green 'Aligned with the Qibla' within ±5°, or a figure-8 calibration hint when the sensor accuracy is above 15°.
- See the Qibla bearing as a large number (Arabic-Indic digits in the ar locale) with an 8-point rose label such as 'شمال غرب · اتجاه القبلة'.
- See two info cards: the location name (city, country) and the great-circle distance to Makkah in km.
- Without a magnetometer (a null heading, or no reading within 4s), see a fallback card ('No compass on this device' / 'Face X° from North…'). The needle then sits fixed at the bearing measured clockwise from the N mark.
- Tap the refresh chip in the app bar to call recalibrate(), which re-runs the whole location, declination and compass pipeline. It does not recalibrate the sensor itself.
- See a location-recovery card when location fails (permission denied: 'Enable location' requests permission and retries; denied forever: opens app settings; location service off: opens location settings). Any other failure shows its raw failure.message. This error path is only reachable when no location is cached (see issues).

### Entry points
- GoRoute /qibla (AppRouter.qiblaPath) in lib/config/router/app_router.dart:105-112, which builds BlocProvider(sl<QiblaCubit>()..start()) around QiblaPage
- Home quick-access tile (5th tile, compass icon) in lib/features/home/presentation/pages/widgets/quick_access_grid.dart:42-46. It is rendered only when Home is in DailyPrayerContextLoaded (home_view.dart:138)
- DI: initQibla() called from lib/core/di/dependency_injection.dart:24, which runs from main.dart:53 via initGetIt()
- Native: the flutter_compass 0.8.1 EventChannel 'hemanthraj/flutter_compass'; location goes through geolocator plus Nominatim through the Home LocationRepository

### Tests
Covered, as found by reading the files; none were run. test/features/qibla/domain/utils/qibla_calculator_test.dart covers bearing (Cairo about 136°), normalisation, distance (Cairo about 1287 km, 0 at the Kaaba), rose sectors, toTrueHeading for iOS and Android with wrap, pointerAngle and isAligned. get_qibla_direction_test.dart covers bearing, distance and rose. get_magnetic_declination_test.dart covers declination bounds and that San Francisco is easterly. get_magnetic_declination_locale_test.dart covers geomag construction under the ar locale. compass_repository_impl_test.dart covers stream pass-through and a null heading. qibla_cubit_test.dart covers Loading→Loaded with Android declination and pointerAngle, a location failure leading to Error, a null heading flipping hasCompass to false, the 4s timeout flipping hasCompass to false, and no compass restart on a near-identical re-emit. qibla_page_test.dart covers the skeleton and the fallback card. qibla_page_loaded_test.dart covers the live view in Arabic without overflow. qibla_di_test.dart covers QiblaCubit resolving from GetIt with a mocked LocationRepository.

Untested: recalibrate() and re-entrant start(); close() cancellation; the stream onError path; the bearing-changed re-emit path that restarts the compass; the QiblaError widgets (all three recovery cards and the raw failure.message text); the needsCalibration and aligned pill states; CompassDataSource itself (including the null-events branch); localizeDigits and CompassRoseL10n; the dial's _shortest arc maths and needle angle; the /qibla route and the Home quick-access tile; and the accuracy mapping from the real plugin.

### Known issues
- **MEDIUM** `lib/features/qibla/presentation/cubit/qibla_state.dart`: On Android the 'aligned' state is likely unreachable at the plugin's MEDIUM accuracy level. According to the flutter_compass 0.8.1 pub-cache copy, Android reports accuracy as a fixed 15 (HIGH), 30 (MEDIUM) or 45 (LOW), and -1 (null) for UNRELIABLE or unknown. needsCalibration is accuracy > 15, and QiblaStatusPill computes aligned = isAligned && !needsCalibration (qibla_status_pill.dart:20). So at MEDIUM the pill shows the calibration hint and never turns green. The truly UNRELIABLE status maps to null, so no calibration hint appears in exactly the case that needs it. copyWith also keeps the old accuracy when a new reading's accuracy is null, so a stale hint can persist.
- **MEDIUM** `lib/features/home/presentation/pages/widgets/home_view.dart`: Qibla's only entry point (QuickAccessGrid, home_view.dart:138) renders only in the DailyPrayerContextLoaded branch. When Home fails (no network to fetch prayer times, or location denied), the user can't reach Qibla, even though the bearing could be computed offline from a cached or GPS position.
- **MEDIUM** `lib/features/home/data/repositories/location_repository_impl.dart`: Qibla reuses the Home location pipeline. With no cached location, a fresh fix also needs two Nominatim reverse-geocode calls (location_remote_data_source.dart:38-62), so on a first run any DioException turns into QiblaError. The page then shows the raw English failure.message (e.g. 'No internet connection.'), even though GPS coordinates were available. With a cached location, all errors (permission, service, network) are swallowed (lines 43-49), so QiblaPage's three recovery-card branches can only appear when the cache is empty. Home must have loaded, which means a location is already cached, so in practice they are reached rarely.
- **MEDIUM** `lib/features/qibla/presentation/pages/qibla_page.dart`: Unlocalized and mis-worded text on an Arabic-first screen. Line 115 shows Text(failure.message), which comes from hardcoded English in GeolocatorErrorHandler and DioErrorHandler. The reused LocationRecoveryCard shows home_locationCard_title and home_locationCard_body ('Prayer times need your location' / 'تحتاج مواقيت الصلاة إلى موقعك'), which is prayer-times wording on the Qibla screen.

<details><summary>Low-severity notes (11)</summary>

- `lib/features/qibla/presentation/pages/widgets/qibla_compass_dial.dart`: The dial's cardinal letters at lines 85-88 are hardcoded Latin 'N', 'E', 'S', 'W' rather than localized, even though compass_rose_* keys exist for the rose label.
- `lib/features/qibla/presentation/cubit/qibla_cubit.dart`: _locationName (lines 139-144) always prefers the Arabic l.city/l.country over enCity/enCountry regardless of locale, so the English UI shows Arabic place names. home_app_bar.dart:23 switches on isAr. It also joins with a Latin ', ' in Arabic text.
- `lib/features/qibla/presentation/cubit/qibla_cubit.dart`: start() is not re-entrant. It emits, awaits the cancel calls, and only then assigns _locationSub (lines 48-52). Two overlapping calls (a double-tap on refresh) can each assign a subscription, orphaning the first. close() never cancels the orphan, so it keeps the location generator (GPS and possibly Nominatim) alive. Its emissions are only gated by isClosed.
- `lib/features/qibla/presentation/cubit/qibla_cubit.dart`: _onLocation is an async method passed to result.fold and never awaited (line 57). An exception from getQiblaDirection or getMagneticDeclination (geomag) becomes an uncaught zone error that bypasses the stream's onError, leaving the screen stuck on the skeleton. A stale _onLocation from a cancelled subscription can also still emit and start the compass after a recalibrate, because the isClosed check (line 76) does not detect superseded runs.
- `lib/features/qibla/presentation/cubit/qibla_state.dart`: copyWith cannot clear trueHeading. If hasCompass flips to false after real readings (a later null reading or a timeout), the state keeps the old trueHeading. isAligned can then still be true and the pill can show 'Aligned', while the page hides the live needle (qibla_page.dart:60-61) and shows the fallback card.
- `lib/features/qibla/presentation/pages/qibla_page.dart`: The refresh IconChip (lines 34-37) has no tooltip or semantic label. The plan (Task 13) gave it tooltip: s.qibla_recalibrate, which was dropped when the page moved to AppScreenAppBar and IconChip, so the qibla_recalibrate ARB key is now unused in lib/. The compass dial has no Semantics either.
- `lib/features/qibla/data/datasources/compass_data_source.dart`: The null-stream branch (lines 13-16) looks unreachable. In the flutter_compass 0.8.1 pub-cache copy, FlutterCompass.events always returns a stream (Stream.empty on web, otherwise a broadcast channel stream). On Android with no magnetometer the plugin simply never emits, so the 4s sensorTimeout is the only real no-compass path.
- `lib/features/qibla/presentation/cubit/qibla_cubit.dart`: UNVERIFIED, needs a device check. The cubit treats the iOS heading as true north (Platform.isIOS). The flutter_compass 0.8.1 iOS code (pub-cache) gates emission only on headingAccuracy > 0 and passes newHeading.trueHeading through without checking for a negative value. If iOS reports trueHeading = -1 (for example with location authorization off), the needle would be off. The plugin's CLLocationManager only calls startUpdatingHeading.
- `lib/features/qibla/presentation/pages/qibla_page.dart`: QiblaPage is stateless, so returning from openAppSettings() or openLocationSettings() does not re-run the pipeline. The user must tap refresh manually. Only the 'Enable location' path re-runs recalibrate().
- `lib/features/qibla/qibla_di.dart`: qibla_di registers Home's GetCurrentLocationUseCase (line 22-24). The spec (section 4.4) assumes Home already registers it, but Home does not, so the cross-feature registration is owned by qibla. If Home ever registers it too, GetIt will throw on the duplicate registration.
- `ios/Runner/Info.plist`: NSLocationWhenInUseUsageDescription mentions only prayer times; it doesn't mention Qibla direction or compass use.

</details>

### Planned but not built
- The tooltip on the recalibrate action (tooltip: s.qibla_recalibrate) is not built. The plan's QiblaPage used an IconButton with the tooltip; the code uses an IconChip with no tooltip, and the key is unused. (2026-05-30-qibla-finder.md, Task 13 Step 1)
- Spec drift, not a missing feature. Section 4.4 says GetCurrentLocationUseCase is 'already a GetIt singleton' from Home; it is actually registered in qibla_di.dart. Section 4.1 says GetQiblaDirection returns Right(QiblaDirection); the plan and code return it directly with no Either. Section 7's ARB key names qibla_bearing_label and qibla_no_compass_message were shipped as qibla_bearing_suffix and qibla_no_compass_title. (2026-05-30-qibla-finder-design.md)
- The spec's 'Location permission/service failures DO surface as recoverable errors' (section 1 and section 6) is only partly true in practice. The recovery cards exist, but with a cached location the shared repository swallows those failures, so they surface only when the cache is empty. (2026-05-30-qibla-finder-design.md)
- Plan Task 15's manual smoke test (needle rotates on device, deny location then grant and recalibrate recovers) has no recorded evidence: every plan checkbox is still '- [ ]'. Conformance with the plan was not checked line by line; only parts of the 2025-line plan were read. (2026-05-30-qibla-finder.md)

### Manual checks on a device
- [ ] Android, Arabic locale: Home → tap the 'القبلة' tile. Confirm the skeleton, then the dial, an Arabic-Indic degree value, the rose label, and the city and distance cards. Turn the phone and check the needle swings toward the Qibla without a 359→0 long spin.
- [ ] Lay a reference compass app or a known landmark bearing side by side, on Android (declination-corrected) and on iOS. The needle should point up and the pill turn green within about ±5° of the true Qibla bearing shown in degrees.
- [ ] On an Android device, watch the pill near alignment right after launch, before doing a figure-8, and again after. If it shows the 'figure-8' hint and never turns green until calibration reaches HIGH, the accuracy > 15 issue is confirmed.
- [ ] Use an Android emulator or a device without a magnetometer. After about 4s the 'No compass on this device' fallback card should appear, with the needle fixed at the bearing from N.
- [ ] Fresh install or cleared app data, airplane mode on, GPS on. Home will likely fail, so try to reach Qibla: there is no entry point. Then deep-link or push /qibla if possible and check whether an English 'No internet connection.' text appears on the Arabic screen.
- [ ] Clear app data, open the app and deny location. Home shows the recovery card and Qibla is unreachable. Then, with a location cached, revoke the permission in system settings and open Qibla: it should still load from the cached location with no recovery card.
- [ ] Switch the app to English and open Qibla. Check whether 'Your location' shows the Arabic city name (the expected defect) instead of the English one.
- [ ] Double-tap the refresh chip quickly, then leave the screen. Watch the logs or battery and GPS indicator to check nothing keeps fetching location (the orphaned subscription).
- [ ] On the denied-forever card, tap 'Open settings', grant permission and return. The screen will not refresh by itself; confirm that tapping refresh recovers it.
- [ ] iOS: with location permission set to 'Never' but a cached location present, open Qibla and compare the needle with the iOS Compass app to check the unverified negative-trueHeading risk.
- [ ] Turn on TalkBack or VoiceOver and focus the refresh chip and the dial. Check whether any label is announced (none is expected).

### Enhancement ideas
- Change the calibration rule to suit Android: treat 15 and 30 as acceptable and prompt on 45 or on unknown/UNRELIABLE (null), or show the hint without hiding the aligned state.
- Make Qibla reachable when Home fails, for example by moving the quick-access grid outside the Loaded branch, and let Qibla work from a GPS fix alone, without the reverse-geocode call, so it works offline.
- Add Qibla-specific recovery-card copy and localize every Failure shown on this screen instead of rendering failure.message.
- Localize the dial's cardinal letters, choose the location name by locale as HomeAppBar does, and add a tooltip or Semantics label to the refresh chip (reuse qibla_recalibrate) and a semantics description to the dial.
- Guard start() against re-entrancy (a generation token, or ignoring calls while one is in flight), wrap _onLocation in try/catch so it emits QiblaError, and let copyWith clear trueHeading when the compass is lost.
- Re-run the pipeline on AppLifecycleState.resumed after returning from the system settings screens.
- Add widget tests for the error branches and pill states, plus a unit test for the dial's shortest-arc maths.

## settings-and-theming

**Status:** ✅ Working

The Settings screen works and is reachable. From it you can pick one of four colour themes, switch between 12-hour and 24-hour time, switch between Arabic and English, turn the launch splash on or off, open the Mushaf reading-settings sheet, pin prayer times, and open "Adhan & Reminders", which is also where the teammate's calculation-method and Asr-school pickers now live. The main gaps are polish and tidy-up: the theme names are English-only, the colour scheme leaves some roles unset so a few popovers and dropdowns fall back to the page background colour, there is a dead widget file and a split test layout left from the merge, and nothing tests the Settings screen widgets.

### What it does
- Open Settings at /settings (AppRouter.settingsPath, registered in lib/config/router/app_router.dart:88). There are three ways in: the settings icon in the home app bar (home_app_bar.dart:85), the home quick-access tile (quick_access_grid.dart:40) and the books-list app bar (books_list_view.dart:32).
- Pick one of 4 themes (Neutral Dark, Neutral Light, Slate Dark, Slate Light) in PalettePickerWidget. SettingsCubit.updatePalette changes MaterialApp.theme live through the BlocBuilder in main.dart:118-124, and the choice is saved by HydratedCubit.
- Switch between 12h and 24h time with a segmented selector that calls updateSettings(isFormat12Hours: …). The flag is inverted: true means 24h.
- Switch the app language between Arabic and English with a segmented selector. MaterialApp.locale follows settings.isArabic.
- Turn 'Splash screen' on or off (showSplashOnLaunch). main.dart:108-113 reads it at startup to choose /home or /splash as the first screen.
- Open the Mushaf reading-settings sheet from the Mushaf card (ReadingSettingsSheet.show). Only the opening was verified; the sheet's contents were not audited.
- Pin prayer times to the notification strip with a switch (updatePrayerStripPinned). home_page.dart reacts to it.
- Open 'Adhan & Reminders' (/notifications, NotificationsSettingsPage). The Settings card is the only way in, and it shows only while FeatureFlags.pinnedPrayerStripUi is true, which it currently is.
- On the Adhan & Reminders page, choose a calculation method (14 options including auto) and an Asr school (Shafi or Hanafi). home_page.dart:112-175 listens for these changes and quietly re-fetches the daily prayer context with the new method and school.
- During onboarding, the Appearance step reuses PalettePickerWidget and also offers the time-format and splash toggles.
- A saved settings entry that is corrupt does not crash the app: SettingsCubit.fromJson catches the error and returns null, so the defaults are used.
- Saved enum values that no longer exist fall back to defaults (palette, paper, reading mode, reciter, calculation method, Asr school). Saved page brightness is clamped to between 0.3 and 1.0.

### Entry points
- /settings → SettingsPage (lib/config/router/app_router.dart:88), pushed from home_app_bar.dart:85, quick_access_grid.dart:40 and books_list_view.dart:32
- /notifications → NotificationsSettingsPage (app_router.dart:82), pushed only from settings_page.dart:150 and only while FeatureFlags.pinnedPrayerStripUi is true
- ReadingSettingsSheet.show(context) from the Settings Mushaf card (settings_page.dart:121)
- Onboarding AppearanceStep reuses PalettePickerWidget (lib/features/onboarding/presentation/pages/widgets/appearance_step.dart:33)
- main.dart: MaterialApp.router theme/locale from SettingsCubit (lines 118-124); initial route chosen from hasCompletedOnboarding/showSplashOnLaunch (lines 108-113)
- DI: sl.registerSingleton<SettingsCubit> (lib/core/di/dependency_injection.dart:22); root BlocProvider at main.dart:78

### Tests
I did not run any tests; this is a read-only audit. Existing coverage: test/features/settings/settings_cubit_test.dart covers the playbackSpeed/defaultReciter, prayer-strip pin, adhan map, reminder map (including the assert for an invalid step) and calculation-method/Asr-school updaters, plus model round-trips. test/features/settings/presentation/cubit/settings_cubit_test.dart covers pageBrightness clamping and readingMode. test/features/settings/data/models/settings_model_test.dart covers palette persistence, the stale isDarkMode key, notificationHintDismissed and the mushaf fields. settings_model_calc_test.dart covers method/school defaults, round-trip and unknown values. settings_model_paper_test.dart and settings_is24h_test.dart cover the paper field and the 24h getter. test/config/theme/app_palette_test.dart covers isDark, bg colours, shared family colours and toThemeData brightness/primary. test/core/constants/color_palette_test.dart and test/core/widgets/design/app_segmented_selector_test.dart also exist, and reading_settings_sheet_test.dart touches mushafPaper. Untested: updatePalette, updateSettings (language and 24h), updateShowSplashOnLaunch, completeOnboarding, dismissNotificationHint, the fromJson fallback for a corrupt entry, the fromMap default of hasCompletedOnboarding=true for upgrading users, any SettingsPage or PalettePickerWidget widget test, the NotificationsSettingsPage picker widgets, and the MaterialApp re-theme and re-locale wiring in main.dart.

### Known issues
- **MEDIUM** `lib/features/settings/presentation/pages/widgets/palette_picker_widget.dart`: The theme names are hardcoded in English ('Neutral Dark', 'Neutral Light', 'Slate Dark', 'Slate Light' at lines 48-53), and no ARB key exists for them. Arabic users see English labels on both Settings and the onboarding Appearance step.
- **MEDIUM** `lib/config/theme/app_palette.dart`: The colorScheme getter (lines 71-83) leaves surfaceContainerHigh, surfaceContainerHighest, outlineVariant and primaryContainer unset. In the pinned Flutter 3.38.1 SDK (color_scheme.dart:1272/1278), surfaceContainerHigh and surfaceContainerHighest fall back to `surface`, which is palette.bg (the page background), so they come out darker or flatter than cards (`surfaceContainer`). These widgets use them: the calc-method and Asr dropdowns' dropdownColor (notifications_settings_page.dart:145,182), reminder_offset_dropdown.dart:43, ayah_action_popover.dart:197, ayah_playback_overlay.dart:438 and playback_repeat_options.dart:159,208. outlineVariant falls back to onBackground, which falls back to onSurface (ornament_divider.dart:14).
- **MEDIUM** `lib/features/home/presentation/pages/home_page.dart`: Merge leftover. The one SettingsCubit listener (lines 112-175) fires on palette, language, 24h, pin, adhan-map and reminder-map changes as well as method and school. It always calls fetchDailyPrayerContext(silent: true, …) at line 169, which the teammate's branch added. So every theme or language switch on Settings also re-fetches the prayer context and re-syncs adhans. I did not verify whether that fetch hits the network or the cache.

<details><summary>Low-severity notes (9)</summary>

- `lib/core/constants/feature_flags.dart`: The pinnedPrayerStripUi doc comment is stale: it mentions the 'Settings sheet' and says 'flip to true when Plan B lands', but the flag is already true. The same flag also hides the whole Notifications section (settings_page.dart:127), and that section holds the only entry to /notifications. Turning the flag off would make Adhan & Reminders and the teammate's calc-method and Asr pickers unreachable. These pickers set prayer times in general, yet they sit under Notifications.
- `lib/features/home/presentation/pages/widgets/setting_switch.dart`: Dead code. SettingSwitch is defined but nothing references it anywhere in lib/. It is left over from the old settings bottom sheet, which ui-refinement Task 17 replaced with segmented selectors.
- `test/features/settings/settings_cubit_test.dart`: Split test layout left by the merge. There are two settings_cubit_test.dart files: one at the feature root (the teammate's, which also holds many SettingsModel tests) and test/features/settings/presentation/cubit/settings_cubit_test.dart (the mushaf branch's). settings_model_calc_test.dart also sits at the feature root rather than under data/models/, next to settings_model_test.dart.
- `lib/config/theme/app_palette.dart`: toThemeData() sets no fontFamily or textTheme. Text styled with a raw TextStyle that names no font is therefore not Cairo: the palette tile labels (palette_picker_widget.dart:75) and the segmented-selector labels (app_segmented_selector.dart:97). This goes against the ui-refinement spec's 'Cairo typography across the board'.
- `lib/core/widgets/design/surface_card.dart`: The doc comment says 'No borders — shadow only', but the card applies context.cardBorder() at line 32. The accentColor parameter's value is never used; it only acts as a null check that switches between shadow strengths.
- `lib/features/settings/presentation/pages/settings_page.dart`: Copy and label problems. The 12h/24h selector row is labelled '24-Hour Format' (twentyFourHourFormat) and the language selector row is labelled 'Arabic Language'; both are leftovers from the old switches. The Mushaf row's subtitle is just 'Paper' ('الورق'). The app-bar title uses S.current.settings, which is captured outside the BlocBuilder, while the rest of the page mixes S.current and S.of(context). Whether the title updates immediately after a language switch is unverified.
- `lib/features/home/presentation/pages/widgets/prayers_list.dart`: The 24h flag is read through sl<SettingsCubit>().state, which does not rebuild on change, and through the misnamed isFormat12Hours instead of the is24HourFormat getter (prayers_list.dart:36, upcoming_prayer.dart:79). Both sit inside other builders, so they probably refresh on the next rebuild; immediate live update is unverified. home_page.dart:232 already uses is24HourFormat, so usage is inconsistent.
- `lib/features/settings/presentation/pages/widgets/palette_picker_widget.dart`: The tiles are bare GestureDetectors with no Semantics, so screen readers get no button role or selected state. They also use physical EdgeInsets.fromLTRB and Positioned(right:) rather than directional insets.
- `lib/main.dart`: BlocProvider(create: (_) => sl<SettingsCubit>()) at line 78 lets the provider own, and close on dispose, a GetIt singleton that SettingsPage and others also reach through sl<SettingsCubit>(). This is harmless at app lifetime, but there are two access paths to one instance and it is the create-not-value pattern.

</details>

### Planned but not built
- 2026-05-24-settings-page-theme-design.md: calls for the surah list app bar (surah_list_app_bar.dart) to push AppRouter.settingsPath. That file no longer exists, and no surah screen links to Settings (the only callers are home_app_bar, quick_access_grid and books_list_view).
- 2026-05-28-ui-refinement-pass-design.md §1 'Cairo typography across the board': partly built. TS.* styles are Cairo, but ThemeData has no fontFamily, and raw-TextStyle labels (palette tiles, AppSegmentedSelector) do not use Cairo.
- 2026-05-28-ui-refinement-pass-design.md §3 'no borders, shadow only': superseded rather than unbuilt. Commit 9af596bb deliberately added context.cardBorder(), which SurfaceCard, quick_access_grid, single_prayer_card and surah_list_tile all use, and the shadow is now neutral black in light mode only rather than accent-tinted.
- 2026-05-24-settings-page-theme-design.md palette table: the light 'surface' hex values (neutralLight #EAEAEA, slateLight #E2E8F2) were deliberately changed in 9af596bb to #E2E2E2 and #D8E2F0. This is superseded, not missing.
- 2026-05-28-ui-refinement-pass-design.md §1 google_fonts and .amiriQuran: superseded. Commit c9140c21 bundles Cairo, Amiri and ScheherazadeNew as assets (pubspec.yaml:98-119), and .amiriQuran is removed. .scheherazade is applied to arabic_quote_block and ahadith_list_item as the spec asked.
- 2026-05-24-settings-page-theme-design.md 'Section labels … uppercase': not verified (I did not read AppSectionHeader).

### Manual checks on a device
- [ ] Home, then the gear icon in the app bar: Settings opens. Go back and tap the quick-access Settings tile, then the gear on the Books (ahadith) list: each opens the same page. Confirm there is no Settings entry on the Surah list screen.
- [ ] Settings > Appearance: tap each of the 4 tiles. The whole app re-themes immediately and the checkmark moves. Kill and relaunch the app: the chosen theme is still applied.
- [ ] With the app in Arabic, look at the palette tiles: their names are still in English (a known issue). Check the onboarding Appearance step too.
- [ ] Settings > General, time format: choose 24h and go back to Home. The hero clock and the prayer cards show 24-hour times. Choose 12h and confirm ص/م (AM/PM) returns. Note whether the prayer cards update immediately or only on the next countdown tick.
- [ ] Settings > General, language: switch to English. The page direction flips to LTR, the back arrow points left, and the title changes from 'الإعدادات' to 'Settings' straight away. Switch back to Arabic.
- [ ] Settings > General: turn the Splash screen switch off, kill the app and relaunch. It opens straight to Home. Turn it on, relaunch, and the splash plays.
- [ ] Settings > Mushaf > Reading: the reading-settings sheet opens. Change the paper there, open a Mushaf page and confirm the paper changed.
- [ ] Settings > Notifications: toggle 'Pinned prayer times' on (Android). The persistent prayer strip appears. Toggle it off and the strip goes away.
- [ ] Settings > Notifications > Adhan & Reminders: open the calculation-method dropdown on each of the 4 themes. The open menu background matches the page background (surfaceContainerHigh falls back to surface), not the card colour; check it reads clearly in Neutral Light and Slate Light.
- [ ] On Adhan & Reminders, change the method (for example Auto to Egypt) and the Asr school (Shafi to Hanafi), then go back to Home. The Asr time and the other times change accordingly. Relaunch: the choices are kept.
- [ ] On Settings, switch the theme while watching the network or logs. Home re-runs fetchDailyPrayerContext on every theme or language change (from the home_page listener).
- [ ] Fresh install: onboarding shows, and the theme chosen in the Appearance step carries into the app. On an upgrade from an older build with saved settings, onboarding does not show (fromMap defaults hasCompletedOnboarding to true).

### Enhancement ideas
- Add ARB keys for the four palette names, for example palette_neutralDark, and localise PalettePickerWidget.
- Complete the ColorScheme in AppPaletteX.colorScheme (surfaceContainerLow/High/Highest, outline, outlineVariant, primaryContainer) so Material widgets and the dropdowns get real elevated surfaces.
- Set fontFamily: 'Cairo' on ThemeData so unstyled text and Material widgets default to Cairo.
- Give the calculation-method and Asr-school pickers their own 'Prayer times' section on the Settings page, outside the pinnedPrayerStripUi flag, or at least link to them from there.
- Narrow the home_page listener so fetchDailyPrayerContext runs only when calculationMethod or asrSchool changes, not on theme or language switches.
- Delete the unused setting_switch.dart, and merge the two settings_cubit_test.dart files into the layered test path.
- Rename the row labels to 'Time format' and 'Language', and switch the remaining call sites to is24HourFormat.
- Add widget tests for SettingsPage (each control calls the cubit) and PalettePickerWidget (selection marker), plus cubit tests for updatePalette, updateSettings, updateShowSplashOnLaunch, completeOnboarding and dismissNotificationHint.
- Wrap the palette tiles in Semantics(button: true, selected: …) and use directional insets.

## onboarding-splash-permissions

**Status:** 🟡 Partial

On first launch the app shows an animated splash and then a five-step wizard: welcome, language, appearance, location permission and notification permission. After that it goes to Home, and later launches show the splash or go straight to Home depending on a setting. The wizard is fully wired into the router and settings, but tapping "Not now" on location does not stick: Home's first location fetch calls the OS location prompt anyway, and the notifications settings banner says "Open settings" while it only re-asks for permission.

### What it does
- Choose where the app starts. main.dart (QuranApp.initState) builds the GoRouter once: it starts at /home when hasCompletedOnboarding is true and showSplashOnLaunch is false, and at /splash otherwise (lib/main.dart:108-113, lib/config/router/app_router.dart:44-80).
- See the animated splash: logo, the Arabic wordmark, a three-word slogan that slides in, and a SpinKit three-dot loader. After the slogan's callback (about 4.8s plus the stagger) it lifts away and pushReplacement goes to /onboarding on first run or /home afterwards (lib/features/splash/pages/splash_page.dart:33-49, slogan_animation.dart:35-43).
- Returning users only: the splash warms the prayer-context cache using the saved calculation method and Asr school, fire-and-forget, and cancels it on dispose (splash_page.dart:59-88). The use case is registered in home_di.dart:53.
- Go through a five-step PageView wizard on SplashBackdrop with progress dots, an in-app back arrow (hidden on step 0), swipe navigation and a Continue button (onboarding_page.dart).
- Welcome step: shows the localized app name (الفرقان / Al-Furqan), headline and subtitle (welcome_step.dart).
- Language step: Arabic and English cards switch the locale live through SettingsCubit.updateSettings(isArabic:) (language_step.dart:37-51).
- Appearance step: a palette picker reused from Settings that re-themes live, a 12h/24h toggle (inverted isFormat12Hours flag), and a 'show splash on next launch' switch (appearance_step.dart).
- Location step: Enable calls Geolocator.requestPermission() and moves on whether or not it is granted. Not now skips to the notifications step (onboarding_page.dart:54-58, 157-159).
- Notifications step: Enable calls PrayerNotificationScheduler.requestNotificationsPermission() (POST_NOTIFICATIONS on Android 13+, alert+sound on iOS). Enable and Not now both finish: completeOnboarding() is persisted through HydratedCubit, then pushReplacement goes to /home (onboarding_page.dart:59-74; scheduler_impl.dart:128-139).
- Notification scheduler init() no longer asks for anything (timezone and channels only). It runs unconditionally after DI, so the old location-poll that spun forever is gone (main.dart:57-65; scheduler_impl.dart:158-183).
- Asking for permission again later: Home shows LocationRecoveryCard for denied (re-request), denied-forever (openAppSettings) and service-disabled (openLocationSettings) (home_view.dart:47-81). It also shows a dismissible NotificationHint whose dismissal is persisted in notificationHintDismissed (home_view.dart:95-110, notification_hint.dart), and NotificationsSettingsPage shows a banner when notifications are off (notifications_settings_page.dart:26-90).
- On Android, AdhanAlarmReceiver does not start the adhan foreground service when notifications are disabled, so the adhan can no longer play with no card and no Stop button (AdhanAlarmReceiver.kt:49-52).
- Users who installed before this feature (saved settings without the hasCompletedOnboarding key) are treated as already onboarded (settings_model.dart:97-100).
- The 'show splash on launch' toggle is also in the Settings page (settings_page.dart:107-109).

### Entry points
- /splash (AppRouter.splashPath): the initial route on first run or when showSplashOnLaunch is true
- /onboarding (AppRouter.onboardingPath): reached only by the splash's pushReplacement when hasCompletedOnboarding is false
- /home: reached from the splash, from onboarding's _finish, or as the initial route when onboarded and the splash is off
- /notifications (NotificationsSettingsPage): holds the disabled-notifications banner
- main() → AppLoader._initAll → initHydratedCubit/initHive/initGetIt → PrayerNotificationScheduler.init()
- Android native: AdhanAlarmReceiver.onReceive notification-enabled gate

### Tests
No test was run; this step was read-only. Tests that exist: test/features/home/presentation/pages/widgets/notification_hint_test.dart (hidden when enabled, shown when disabled with dismiss callback, hidden when the dismissed flag is set), test/features/home/presentation/pages/widgets/location_recovery_card_test.dart (label and onAction), test/features/home/presentation/cubit/daily_prayer_context_cubit_test.dart (typed LocationPermissionDeniedFailure mapping) and test/features/settings/data/models/settings_model_test.dart (notificationHintDismissed round-trip). Not tested: OnboardingPage and its steps (navigation, permission calls, completeOnboarding), SplashPage routing (first run vs returning user) and the warm-up gating, the main.dart initial-route choice, SettingsCubit.completeOnboarding and updateShowSplashOnLaunch, the hasCompletedOnboarding default of true for missing keys and its round-trip, HomeView failure branching, PrayerNotificationSchedulerImpl (init being non-interactive, areNotificationsEnabled), the notifications-settings banner, and the Kotlin AdhanAlarmReceiver gate. There are no integration_test files for this area.

### Known issues
- **HIGH** `lib/features/home/data/datasources/remote/location_remote_data_source.dart`: Tapping 'Not now' on the location step is not honoured. determinePosition() calls Geolocator.requestPermission() whenever checkPermission() returns `denied` (lines 20-23). Three places reach it. (1) Right after onboarding finishes, Home's cubit is created with fetchDailyPrayerContext (home_page.dart:31-32), so the OS location dialog appears on Home straight after the user skipped it. (2) On every later launch the splash warm-up (splash_page.dart:59-62, 71-78) can show the dialog over the splash; the splash's own comment at lines 54-58 describes this exact hazard. (3) The Home resume observer re-fetches (home_page.dart:275-284). The spec says location is optional and recovery should go through LocationRecoveryCard. The code path is confirmed; the actual on-device dialog behaviour, including a possible re-prompt loop on resume, still needs a manual check.
- **MEDIUM** `lib/features/home/presentation/pages/notifications_settings_page.dart`: The disabled-notifications banner button says 'Open settings' / 'فتح الإعدادات' (notifSettings_disabledBanner_action) but calls requestNotificationsPermission() (lines 79-84). On Android 13+ after the user has denied twice, or on iOS after one denial, the OS dialog does not come back, so the button visibly does nothing and the user has no way back from this screen. The spec asks for a deep link to settings.
- **MEDIUM** `lib/features/home/presentation/pages/widgets/notification_hint.dart`: The Home notification hint has the same problem. Allow only re-requests the permission (home_view.dart:105-107) and has no fallback to app settings, so after the OS stops prompting, Allow does nothing. The spec only names requestNotificationsPermission() here; I flag it because the denied-forever case was handled for location but not for notifications.
- **MEDIUM** `lib/main.dart`: _initAll (lines 50-55) awaits initHydratedCubit, initHive and initGetIt with no try/catch. If any of them throws, _ready never becomes true and the user is stuck on the blank #0D0D0D scaffold (lines 70-74) with no error or retry.

<details><summary>Low-severity notes (8)</summary>

- `lib/main.dart`: Init ordering. setState(_ready = true) at line 55 runs before PrayerNotificationScheduler.init() at line 62. The iOS scheduling path (notifications_repository_impl.dart:93, 152) silently skips when `_initialized` is false (scheduler_impl.dart:193-196), and onboarding's requestNotificationsPermission() also runs on a plugin that may not have finished `initialize`. In practice the splash takes about 5s, so this is probably not hit, but nothing in the code guarantees the order.
- `lib/features/home/presentation/pages/widgets/home_view.dart`: Errors other than permission problems (network, timeout, unknown) show only `Center(child: Text(state.message))` (line 83), with no retry button. The spec says 'existing generic error + retry'.
- `lib/features/onboarding/presentation/pages/onboarding_page.dart`: There is no PopScope. /onboarding is reached by pushReplacement from the splash, so it is the only route, and the Android system back gesture closes the app instead of going to the previous step. Only the in-app arrow steps back.
- `lib/features/splash/pages/splash_page.dart`: Hardcoded text that ignores the locale: the wordmark "اَلْقُرْآنُ الْكَرِيمُ" (line 118) and the slogan "اقْرَأْ تَعَلَّمْ احْفَظْ" (line 137). Users who chose English still see Arabic-only splash text. language_step.dart:39 and :47 also hardcode the 'Arabic' and 'الإنجليزية' sublabels; this looks deliberate, since each card shows the other language's name.
- `lib/main.dart`: The الفرقان / Al-Furqan rebrand is incomplete. MaterialApp title is 'Quran' (line 123), the Android label is 'quran_app' (AndroidManifest.xml:12), the iOS CFBundleDisplayName is 'Quran App', and the splash wordmark still says القرآن الكريم. The new name appears only in the ARB `app_name` used on the welcome step.
- `ios/Runner/Info.plist`: NSLocationWhenInUseUsageDescription and NSLocationAlwaysUsageDescription are English only, and there is no ar.lproj InfoPlist.strings, so Arabic users see an English iOS permission prompt. NSLocationAlways is declared even though nothing I found requests always-on location.
- `lib/features/splash/pages/widgets/slogan_animation.dart`: `.callback(delay: 4.8s)` is attached to the AnimateList of three slogan words, so onLoaded fires once per word. The _exiting guard in splash_page.dart:34 stops repeat navigation, so this works, but it is fragile.
- `lib/features/splash/pages/splash_page.dart`: Leftovers from the merge and earlier rename, which are naming and comments only, not logic: stale 'landing' wording in splash_page.dart:54-58, main.dart:106, splash_backdrop.dart:6,12, settings.dart:22-23 and settings_cubit.dart:72; the router comment at app_router.dart:49-51 says Home is entered only via the splash, but onboarding's _finish and the direct-to-home initialLocation also reach it; NotificationsSettingsPage sits under features/home even though a separate features/notifications module exists; the location recovery-card branching (request / openAppSettings / openLocationSettings) is copied in qibla_page.dart:98-112 and home_view.dart:49-81 instead of shared. The onboarding and splash logic is the same on both merge parents.

</details>

### Planned but not built
- 2026-05-30-permissions-flow-design.md, Part 3 'Durable Settings path': the banner's 'Open settings' action is built as requestNotificationsPermission() rather than a deep link to settings (plan Task 10 listed the deep-link mechanism as an adapt-point).
- 2026-05-30-permissions-flow-design.md, Location re-grant: the 'existing generic error + retry' for other failures has no retry button (home_view.dart:83).
- 2026-05-30-permissions-flow-design.md, Part 2 'Supporting (scheduling gate)': the plan deliberately skipped this and relies on the AdhanAlarmReceiver runtime gate (plan line 31). Not built, by design.
- 2026-05-30-permissions-flow-design.md, Testing: the Home widget tests (denied → card with Enable; denied-forever / service-disabled → settings deep link; both granted → neither surface) have no HomeView-level tests; only the standalone LocationRecoveryCard and NotificationHint widget tests exist. The spec's scheduler test that areNotificationsEnabled() returns the platform value is also missing (no PrayerNotificationSchedulerImpl test).
- 2026-05-30-permissions-flow.md: every task checkbox is unchecked, but in code Tasks 1-11 are present except the gaps listed above.
- 2026-05-29-onboarding-wizard-design.md, Goal 'rebrand the app as الفرقان · Al-Furqan': only the ARB app_name and welcome step use it. The launcher labels, MaterialApp title and splash wordmark do not.
- 2026-05-29-onboarding-wizard-design.md, code plan step 4: it names `requestPermissions()`; the code has `requestNotificationsPermission()`, which does the same job, so this is a naming difference, not a missing feature.
- There is no onboarding-wizard plan file in docs/superpowers/plans, only the spec. The one matching plan is 2026-05-30-permissions-flow.md.

### Manual checks on a device
- [ ] Fresh install (Android 13+): clear app data and launch. Expect a black frame, then the splash (logo, wordmark, slogan words sliding in, three-dot loader), then a fade into the wizard on step 1 with no OS permission dialog during the splash.
- [ ] Wizard step 2: tap English and confirm every wizard string and the layout direction switch to English and LTR straight away, then tap Arabic to switch back. Step 3: tap each palette tile and confirm the wizard re-themes; toggle 12h/24h and the splash switch.
- [ ] Step 4, tap Enable: the OS location dialog appears. Grant it and confirm the wizard moves to step 5 and that no notification dialog appears on its own (the old bug).
- [ ] Step 5, tap Enable: the POST_NOTIFICATIONS dialog appears. After answering, Home opens and prayer times load.
- [ ] Fresh install, tap 'Not now' on location (step 4): after finishing, see whether the OS location dialog appears on Home anyway (the code calls requestPermission when the status is denied). If it does, deny it and see whether a LocationRecoveryCard with an Enable button shows, then background and resume the app and see whether the dialog comes back again.
- [ ] Kill and relaunch after onboarding with location denied (not permanently): watch for the OS location dialog appearing over the splash.
- [ ] Relaunch with 'show splash' turned off in Settings: the app should open directly on Home. Turn it on: splash, then Home (not the wizard).
- [ ] On the Android onboarding wizard (steps 2-5), press the system back button: the code exits the app instead of going to the previous step. The in-app arrow should go back.
- [ ] Deny notifications twice (Android 13+) so the OS stops prompting. Open Adhan & reminders settings and tap the banner's 'Open settings': the code only re-requests permission, so confirm whether anything happens. Try the Home hint's Allow too.
- [ ] With notifications off, wait for an adhan time (or use a test alarm): no adhan audio should play. With notifications on, the adhan plays with its notification card and the Stop action works.
- [ ] Set location services off at the OS level and open Home: you should see a recovery card whose button opens the location settings. Revoke location permanently: the button should open the app settings. Grant it there and return: the card should clear on resume.
- [ ] iOS: run onboarding in Arabic and check the location prompt text (the Info.plist strings are English only) and that the notifications Enable shows the iOS alert prompt.

### Enhancement ideas
- Split determinePosition into a check-only path for the background fetches (splash warm-up, Home load and resume) and an explicit request path for the onboarding and recovery-card buttons, so 'Not now' sticks and recovery goes through LocationRecoveryCard.
- Use a settings deep link for the notification banner and hint when areNotificationsEnabled() stays false after a request (for example an app-settings or notification-settings intent), matching the 'Open settings' label.
- Wrap AppLoader._initAll in try/catch with a retry screen, and await the scheduler init (or gate scheduling on it) before marking the app ready.
- Add a PopScope in OnboardingPage that steps the PageView back before letting the system back gesture exit.
- Localize the splash wordmark and slogan, and finish the Al-Furqan rebrand in the Android label, iOS display name and MaterialApp title. Add an ar.lproj InfoPlist.strings for the location prompt.
- Move the location-recovery branching into one shared widget used by both home_view.dart and qibla_page.dart.
- Add widget tests for OnboardingPage (step flow, completeOnboarding, permission calls through a fake scheduler) and for SplashPage destination routing, plus a SettingsModel test that a missing hasCompletedOnboarding key reads as true.
