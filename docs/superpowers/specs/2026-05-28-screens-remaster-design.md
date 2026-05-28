# Screens Remaster — Design Spec

**Date:** 2026-05-28
**Branch:** `feature/300-quran-playback` (to be peeled into its own branch when work starts)
**Driver mockup:** `Quran App.html` (repo root)

## 1. Goal

Port the visual language of `Quran App.html` into the Flutter app, screen by screen, while fixing the RTL/directionality bugs that exist in the HTML. Match the design system (palette tokens, card shape, section-header pattern, status badges, typography rhythm) — not pixel-for-pixel.

## 2. Non-goals

- Splash, Landing, and Mushaf screens are **out of scope** (kept as-is).
- No changes to the `ColorPalette` enum or `AppPaletteX` extension — the 4 palettes already match the HTML's `--bg / --surface / --primary / --secondary / --on-surface / --on-surface-var` tokens.
- No new design tokens via `ThemeExtension`. Layout constants (radii, paddings) stay as inline `const` values in the relevant widget; color always comes from `context.colorScheme`.
- The Settings UX stays as a dedicated `/settings` page push (not the HTML's bottom sheet) — palette grid and per-prayer adhan toggles don't fit a sheet.

## 3. In-scope screens

| Screen | Existing file | Status |
|---|---|---|
| Home | `lib/features/home/presentation/pages/widgets/home_view.dart` (+ children) | Remaster |
| Surah List | `lib/features/surah/presentation/pages/surah_list/` | Remaster |
| Books List (Hadith books) | `lib/features/ahadith/presentation/pages/books_list_page.dart` + `widgets/books_list_view.dart` + `widgets/hadith_book_list_item.dart` | Remaster |
| Ahadith List | `lib/features/ahadith/presentation/pages/ahadith_list_page.dart` + `widgets/ahadith_list_view.dart` + `widgets/ahadith_list_item.dart` | Remaster |
| Hadith Detail | `lib/features/ahadith/presentation/pages/hadith_page.dart` + `widgets/hadith_view.dart` | Remaster + extras (see §6) |
| Settings | `lib/features/settings/presentation/pages/settings_page.dart` | Restyle |
| Notifications Settings | `lib/features/home/presentation/pages/notifications_settings_page.dart` | Restyle |

## 4. Shared design primitives

New folder: `lib/core/widgets/design/`.

Each widget is a small file (30–80 lines). All directional edges use `EdgeInsetsDirectional` / `BorderDirectional` / `AlignmentDirectional` so the HTML's RTL bugs do not carry over.

| File | Widget | Purpose | Source in HTML |
|---|---|---|---|
| `app_section_header.dart` | `AppSectionHeader({label, trailing?})` | 3×16 secondary-color bar + uppercase letter-spaced label + optional trailing widget (e.g. count text or link) | `.section-header` |
| `app_status_badge.dart` | `AppStatusBadge(HadithStatus)` | Pill: dot + label, tinted bg + 1px border, color mapped from status (sahih=#3D9E6E, hasan=#C8882A, daeef=#D05050) | `.status-badge` |
| `ornament_divider.dart` | `OrnamentDivider()` | line + 6×6 rotated secondary diamond + line | `.ornament-div` |
| `surface_card.dart` | `SurfaceCard({child, leadingAccentColor?, padding?, radius=16})` | Surface bg, 1px on-surface-06 border, optional **directional leading-edge** accent (replaces HTML's hard-coded `border-right` / `border-left`) | `.chapter-card`, `.arabic-block`, `.narrator-card` |
| `arabic_quote_block.dart` | `ArabicQuoteBlock(text)` | `SurfaceCard` with `leadingAccentColor = primary` + Amiri Quran text, 23sp, line-height 2.1 | `.arabic-block` |
| `narrator_card.dart` | `NarratorCard({label, body})` | `SurfaceCard` with `leadingAccentColor = secondary` + uppercase 10sp label in secondary + body in on-surface-var | `.narrator-card` |
| `action_buttons_row.dart` | `ActionButtonsRow(children: [ActionBtn, …])` and `ActionBtn({icon, label, onPressed, primary=false})` | Row of equal-flex 44h buttons; one can be `primary` (primary bg + white text) | `.actions-row`, `.action-btn` |
| `icon_chip.dart` | `IconChip({icon, onPressed})` | 38×38 rounded-10 on-surface-06 button used in app bars | `.icon-btn` |
| `app_bar_center_title.dart` | `AppBarCenterTitle({label, title})` | Stack of 10sp label (on-surface-var, +0.5 letter-spacing) over 15sp Amiri title — used in Surah/Books/Ahadith/Hadith app bars | `.app-bar-center` |

Spacing rhythm in the HTML is uniform — gap 14 between sections, padding 16 inside cards. We will encode these as `const _kCardPadding = 16`, `const _kSectionGap = 14` inside each widget file (no global constants module — the values are not parameterized).

## 5. Per-screen specs

### 5.1 Home

The current `HomeView` is a basic column with three blocks (`HomeAppBar`, `UpcomingPrayer`, `PrayersList`) and a bottom action row. Rebuild as a scrollable `Column` with explicit sections per HTML.

**App bar** (`HomeAppBar` rewrite):
- Leading: column with Hijri date (`TS.bold14.cairo`) and location row (location pin icon + city, `TS.regular11`, on-surface-var). Direction-aware: `CrossAxisAlignment.start` so it sits on the leading edge.
- Trailing: `IconChip` with settings (gear) icon → `context.push(AppRouter.settingsPath)`.

**Body sections (scrollable):**
1. **Time hero** (`UpcomingPrayer` rewrite): big time `TS.bold58` (letter-spacing -2, line-height 1), period label inline (20sp secondary), countdown row below — small dot + text "3h 45m until **Isha**" with the prayer name in secondary bold.
2. `OrnamentDivider`
3. `AppSectionHeader(label: S.current.prayers)`
4. **Prayers row** (`PrayersList` rewrite): 5 equal-flex `_PrayerCard`s (name + icon + time + active dot). Active card uses `surface` bg + on-surface-06 border + secondary text/icon tint. Reuses existing `PrayerName` enum and prayer-name localization extensions in `presentation/utils/`.
5. `AppSectionHeader(label: S.current.lastRead)`
6. **Last-read card** — `SurfaceCard` with: top row (surah badge + page badge), divider, surah name (Amiri 17sp secondary), aya sub (10.5sp on-surface-var), 3px progress bar, footer (progress label + filled "Continue" button). **Last-read tracking does not exist yet** in the codebase — the mushaf does not currently persist the last-viewed page. For this remaster, the implementation reads the most-recently-bookmarked ayah from `BookmarkCubit` as the "last read" proxy; if no bookmarks exist, the whole Last Read section (header + card) is hidden. A proper last-viewed-page tracker is a separate follow-up (out of scope here).
7. `AppSectionHeader(label: S.current.quickAccess)`
8. **Quick grid** — 4-column grid of square tiles. Each tile: aspect-1 surface tile + on-surface-06 border + icon (24px on-surface stroke) + label below (11sp). The current `HomeActionButtons` already navigates to Quran / Hadith. The 4 tiles are: **Quran** (→ `/surahList`), **Hadith Books** (→ `/books`), **Bookmarks** (→ bookmarks screen — if no screen exists yet, this tile is disabled with reduced opacity and a follow-up tracked), **Settings** (→ `/settings`). Sub-labels from the HTML (e.g. "114 surahs") are omitted to keep the tile clean.

**Settings sheet:** not built. Gear icon pushes to `/settings`.

### 5.2 Surah List

App bar uses `AppBarCenterTitle(label: "The Noble Qur'an", title: "Surahs")` with leading back chip + trailing menu chip.

Body order:
1. **Continue-reading bar** — `SurfaceCard` (radius 14, padding 12×14). Row: small icon chip + (label "Continue Reading" + value "Al-Baqarah · Aya 255") + primary-filled "Page 43" pill button on the trailing edge. Hidden when no last-read (uses the same bookmark-proxy fallback as Home — see §5.1.6).
2. **Search bar** — `SurfaceCard`-styled `TextField`. 40h, on-surface-10 border, search icon prefix, hint "Search for a surah…". Keeps the existing `SurahCubit` search flow.
3. `AppSectionHeader(label: S.current.allSurahs, trailing: Text("114 surahs"))`
4. **Surah list** — `ListView.separated` of `_SurahTile`. Each tile: leading `_PlayButton` (34 round, on-surface-06 bg, secondary play triangle), `_SurahInfo` (name in Amiri 18sp on-surface + meta `"Makkiyya · 7 ayahs · p. 1"` 10sp on-surface-var), trailing `_SurahNumber` (30 round, on-surface-06, 10sp bold). Tap goes to mushaf at the surah's first page.

Existing `SurahCubit` / `SurahListPageBody` / `SurahSelectionList` are replaced; segment selector is removed (the HTML has a single flat list).

### 5.3 Books List

App bar uses `AppBarCenterTitle(label: S.current.collections, title: S.current.hadithBooks)` with leading back chip + trailing settings chip (push to `/settings`).

Body:
1. `AppSectionHeader(label: S.current.books, trailing: Text("7 books"))`
2. List of `_BookCard`s. Each card: leading 44×44 `_BookAction` badge that renders one of three states from `DownloadBookCubit`:
   - **Not downloaded** — on-surface-06 bg, on-surface-var color, download arrow icon
   - **Downloading** — secondary-tinted, shows `"67%"` instead of icon; below the card, a 3px progress bar (the card switches to column layout when downloading, matching HTML)
   - **Downloaded** — green-tinted (`#3D9E6E` family) with check icon
3. Info column: Arabic title (Amiri 17sp on-surface), English title (11sp on-surface-var), meta row (author · count). Tap on the **info area** opens the book → `context.push(AppRouter.ahadithPath, extra: bookSlug)`. Tap on the **badge** triggers `DownloadBookCubit.downloadBook` (only if not yet downloaded / downloading).

Existing `ToggleWidget` + `CircularBullet` are replaced. Wiring uses the existing `DownloadBookCubit` API (`isCurrentlyDownloading`, `getBookProgress`, `downloadedBooks`).

### 5.4 Ahadith List

App bar uses `AppBarCenterTitle(label: <book localized name>, title: <book localized name>)` with leading back chip + trailing search chip.

Body:
1. `AppSectionHeader(label: S.current.ahadith, trailing: Text("${count} ahadith"))`
2. List of `_HadithPreviewCard`s. Each: top row (`AppStatusBadge` + "#42" number on the trailing edge), Arabic preview text (Amiri 15sp, **2-line clamp via `maxLines: 2, overflow: TextOverflow.ellipsis`**), chapter line (11sp on-surface-var). Tap → push hadith detail with `extra: hadith`.

### 5.5 Hadith Detail — with extras

App bar uses `AppBarCenterTitle(label: <book>, title: "Hadith #42")` with leading back chip + trailing share chip (`IconChip` with share icon → triggers `share_plus`).

Body order:
1. **Chapter card** — `SurfaceCard` with top row (`AppStatusBadge` + chapter ref "Chapter 7" on the trailing edge), divider, chapter Arabic name (Amiri 18sp secondary), chapter English (13sp on-surface-var).
2. `AppSectionHeader(label: S.current.arabicLabel)`
3. `ArabicQuoteBlock(hadith.arabicHadith)`
4. `OrnamentDivider`
5. `AppSectionHeader(label: S.current.translationLabel)`
6. Translation text — plain `Text(hadith.englishHadith, style: TS.regular15)`, line-height 1.78, on-surface color.
7. `NarratorCard(label: S.current.narratorLabel, body: hadith.englishNarrator)` — shown only when `englishNarrator.isNotEmpty`. Note: the `Hadith` entity has only `englishNarrator`, no Arabic version — the card shows the English string regardless of app locale. This is an accepted limitation; localizing the narrator requires data-source changes that are out of scope.
8. `ActionButtonsRow` with 3 buttons:
   - **Bookmark** (icon-only label) — toggles bookmark. See §6 below for the new infrastructure.
   - **Share** — `share_plus` (already in `pubspec.yaml`): shares `"<arabicHadith>\n\n— <bookName>, #<number>"`.
   - **Next** (primary, with chevron) — navigates to next hadith in the current book. See §6.
9. Footer annotation: 10sp on-surface-var, "Sahih al-Bukhari · Book of Fasting" (book + chapter), 50% opacity.

### 5.6 Settings (restyle only)

The existing `SettingsPage` already follows a similar structure (`_SectionLabel` + cards). Restyle to use the new primitives:
- Replace `_SectionLabel` with `AppSectionHeader`.
- Wrap each settings row group in a `SurfaceCard` (no leading accent), with `_SettingRow`s separated by a 1px on-surface-06 divider — matches the HTML settings sheet rows.
- `_SettingRow` widget: row with leading 34×34 icon chip (secondary stroke), label, trailing `Switch.adaptive` styled to secondary track color.
- Palette picker keeps its 2×2 grid as-is — already on-brand.

### 5.7 Notifications Settings (restyle only)

Same primitives. The existing `_Header` (icon + subtitle) stays — restyled to a `SurfaceCard`. Each setting group becomes a `SurfaceCard` containing `_SettingRow`s with directional dividers (already does this via `PerPrayerAdhanTile` — just verify the styling matches).

## 6. Hadith Detail extras — infrastructure

These add real surface area beyond visual remaster. Called out clearly so the implementation plan can decide whether to ship them together with the visual port or as a follow-up.

### 6.1 Bookmark (hadith)

`BookmarkCubit` today bookmarks **ayah** identifiers (`AyahIdentifier`), not hadith. Two options:

- **(a) Extend `BookmarkCubit`** to handle a union of bookmark targets. Heavier — touches the bookmark hive box schema.
- **(b) New `HadithBookmarkCubit` + repo + hive box** parallel to the ayah bookmark stack. Smaller blast radius. **Recommended.**

Either way, what we need:
- `HadithBookmarkRepository` (abstract in domain, impl in data) backed by a new Hive box `hadith_bookmarks` keyed by `"$bookSlug:$hadithNumber"`.
- `ToggleHadithBookmark` use case (returns `Either<Failure, bool>` — new state).
- `GetHadithBookmarks` use case (returns `Set<String>`).
- `HadithBookmarkCubit` registered as `Factory` and provided at the hadith detail page level.
- Wire `BookmarkButton` to call cubit's `toggle()` and reflect state via `BlocBuilder`.

### 6.2 Share

`share_plus: ^11.0.0` is already in `pubspec.yaml`. Implementation is a one-liner in the share action's `onPressed`:
```dart
SharePlus.instance.share(
  ShareParams(text: '${hadith.arabicHadith}\n\n— ${bookName}, #${hadith.hadithNumber}'),
);
```
No infrastructure needed.

### 6.3 Next/Prev hadith

The HTML shows only "Next" (with a chevron), not Prev. We will add **Next only** to match. Two integration paths:

- **(a) Page-level state**: pass the full `List<Hadith>` (or just the current index + `bookSlug`) into the hadith detail route, navigate next via `context.replace` to the next entry. Avoids new cubit but couples list and detail.
- **(b) Repository use case**: add `GetNextHadith({bookSlug, currentHadithNumber})` to `AhadithRepository`. Detail page calls it on Next-tap and replaces the route. Cleaner; reuses for any future entry point. **Recommended.**

Either way, the route signature for `/hadith` doesn't need to change (still takes a `Hadith` in `extra`). Replacement uses `context.replace(AppRouter.hadithPath, extra: nextHadith)`.

## 7. RTL hardening

The HTML mockup has known RTL bugs we will not reproduce:

| HTML bug | Flutter fix |
|---|---|
| `.arabic-block { border-right: 3px solid var(--primary); }` — hard-coded right edge regardless of language | `SurfaceCard.leadingAccentColor` uses `BorderDirectional(start: BorderSide(...))` so the accent sits on the leading edge in both RTL and LTR |
| `.narrator-card { border-left: 3px solid var(--secondary); }` — same issue, opposite side | Same `BorderDirectional(start: ...)` mechanism |
| `.book-info { text-align: right; }` only flipped via `[data-lang="en"]` selector | Use `CrossAxisAlignment.start` + `TextAlign.start` everywhere; let Flutter's directionality flip naturally |
| `.playback-dock { padding: 6px 8px 6px 14px; }` with `[data-lang="en"]` override | `EdgeInsetsDirectional.fromSTEB(14, 6, 8, 6)` — no manual override needed |
| Bidi text mixing Arabic and Hindi-Arabic numerals — HTML uses `<bdi>` tags | Use `Directionality` widget or `TextDirection.rtl` in `Text.rich` spans where Arabic numbers (e.g. "page ٤٣") need isolation; the existing `toLocalized` extension already produces the correct numeral set per locale |
| Chevron icons (`◂` for back) | Use Flutter's `Icons.chevron_left` with `Directionality`-aware wrapping (or use `Icons.arrow_back_ios_new` which auto-flips) |

## 8. Files added / changed

**Design primitives (9 files):**
- `lib/core/widgets/design/app_section_header.dart`
- `lib/core/widgets/design/app_status_badge.dart`
- `lib/core/widgets/design/ornament_divider.dart`
- `lib/core/widgets/design/surface_card.dart`
- `lib/core/widgets/design/arabic_quote_block.dart`
- `lib/core/widgets/design/narrator_card.dart`
- `lib/core/widgets/design/action_buttons_row.dart`
- `lib/core/widgets/design/icon_chip.dart`
- `lib/core/widgets/design/app_bar_center_title.dart`

**Hadith bookmark / next infrastructure (7 files — all in scope per §6):**
- `lib/features/ahadith/domain/repositories/hadith_bookmark_repository.dart`
- `lib/features/ahadith/data/repositories/hadith_bookmark_repository_impl.dart`
- `lib/features/ahadith/data/datasources/local/hadith_bookmark_local_data_source.dart`
- `lib/features/ahadith/domain/usecases/toggle_hadith_bookmark.dart`
- `lib/features/ahadith/domain/usecases/get_hadith_bookmarks.dart`
- `lib/features/ahadith/domain/usecases/get_next_hadith.dart`
- `lib/features/ahadith/presentation/cubit/hadith_bookmark_cubit.dart` (+ state)

**Changed:**
- `lib/features/home/presentation/pages/widgets/home_view.dart` — rewritten layout
- `lib/features/home/presentation/pages/widgets/home_app_bar.dart` — new layout (date column + gear chip)
- `lib/features/home/presentation/pages/widgets/upcoming_prayer.dart` — time hero rewrite
- `lib/features/home/presentation/pages/widgets/prayers_list.dart` + `single_prayer_card.dart` — restyled
- `lib/features/home/presentation/pages/widgets/home_action_buttons.dart` → renamed to `quick_access_grid.dart`
- `lib/features/surah/presentation/pages/surah_list/widgets/surah_list_page_body.dart` — rewritten
- `lib/features/surah/presentation/pages/surah_list/widgets/surah_selection_list.dart` — replaced with new `surah_tile.dart`
- `lib/features/surah/presentation/pages/surah_list/widgets/surah_search_bar.dart` — restyled
- `lib/features/surah/presentation/pages/surah_list/widgets/surah_segment_selector.dart` — **removed** (HTML has no segment selector)
- `lib/features/ahadith/presentation/pages/widgets/books_list_view.dart` — restructured
- `lib/features/ahadith/presentation/pages/widgets/hadith_book_list_item.dart` — rewritten using `SurfaceCard`
- `lib/features/ahadith/presentation/pages/widgets/ahadith_list_view.dart` — restructured
- `lib/features/ahadith/presentation/pages/widgets/ahadith_list_item.dart` — rewritten
- `lib/features/ahadith/presentation/pages/widgets/hadith_view.dart` — rewritten
- `lib/features/settings/presentation/pages/settings_page.dart` — restyled with new primitives
- `lib/features/home/presentation/pages/notifications_settings_page.dart` — restyled
- `lib/features/ahadith/ahadith_di.dart` — register `HadithBookmarkCubit` and new use cases
- `lib/l10n/intl_en.arb` / `intl_ar.arb` — new keys: `collections`, `hadithBooks`, `allSurahs`, `lastRead`, `quickAccess`, `narratorLabel`, `nextHadith`, etc.

**Removed:** none (some widget files renamed in place).

## 9. Validation

Per the project rules — type checking and tests verify code correctness, not feature correctness. Manual run-through required:

1. **Type-check:** `flutter analyze` clean.
2. **Run on emulator** in both Arabic (default) and English locales.
3. **Toggle each palette** (neutral-dark, neutral-light, slate-dark, slate-light) on each screen — verify contrast and that no hard-coded colors leak.
4. **Each screen:**
   - Home: countdown updates, palette switch is live, gear → settings.
   - Surah list: search filters, continue-reading bar appears when last-read is set, tile → mushaf navigation.
   - Books: download a non-downloaded book — verify badge progresses through downloading → downloaded states with progress bar visible mid-download.
   - Ahadith: 2-line clamp on long Arabic; tap → detail.
   - Hadith detail: narrator card only when narrator present; bookmark toggle persists across app restart; share opens system share sheet; "Next" advances to the next hadith in the same book and "Next" remains active until last hadith (then becomes disabled or hides).
   - Settings: palette grid still works; switches reflect cubit state.
   - Notifications: existing toggles still work; restyled visuals.
5. **RTL spot-check:** in English mode, confirm `ArabicQuoteBlock` accent border is on the **left** (leading edge for LTR) and `NarratorCard` accent likewise on the left; in Arabic mode, both are on the **right**.

## 10. Out of scope (explicit non-goals)

- New navigation patterns (bottom nav, drawer) — none in the HTML, none here.
- Mushaf page tweaks (paper picker, playback dock) — out of scope per user request.
- Splash and landing screens — out of scope.
- Onboarding flow — already covered by existing landing.
- Audio playback redesign — covered by playback overlay spec from 2026-05-21.
