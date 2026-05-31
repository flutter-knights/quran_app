# Surah List — Search Redesign & Reading Progress

**Date:** 2026-05-31
**Branch:** `feature/004-pinned-prayer-notification` (to be peeled into its own branch when work starts)
**Status:** Approved design — pending spec review

## 1. Goal

Restore the *structure* of the old surah-list screen (pinned search header + the old segment selector reborn as browse tabs), rebuilt with today's design tokens, and give it a genuinely **comprehensive search** over the whole Mushaf — surah names, juzʼ, page number, and **ayah text**. Plus two smaller fixes: make the "continue reading" card **surah-relative**, and confirm the bookmark storage model.

The ayah corpus already exists at `quran-1.4.1/lib/quran_text_normal.dart` (6,236 entries of `{surah_number, verse_number, content}`).

## 2. Non-goals

- No change to the palette tokens, `AppPaletteX`, or typography. Colors always come from `context.colorScheme`.
- No change to bookmark storage (it already stores ayah-level `surah:ayah` — see §7). We *confirm* it, not rebuild it.
- No new "Bookmark" browse tab on this screen — the app already has a dedicated bookmarks page; we reach it via an app-bar icon instead of duplicating it.
- Ayah-text search is in-memory and synchronous (debounced). No isolate, no full-text engine, no fuzzy/Levenshtein matching in v1 (substring over a normalized index only).
- No redesign of the Mushaf reading page itself — we only extend its route to optionally accept a focus ayah (§6).

## 3. Current state (what exists today)

| Concern | Today |
|---|---|
| Surah list | `surah_list_page_body.dart` → `Scaffold` + `CustomScrollView`: `AppScreenAppBar`, optional `LastReadCard`, `SurahSearchBar` (name-only, scrolls away), `AppSectionHeader`, `ListView.separated` of `SurahListTile`. |
| Search | Local `setState` filter on Arabic + English **name only**. No juzʼ / page / ayah text. |
| Navigation | `context.push(AppRouter.mushafPath, extra: surah.pageNumber)` — route parses `state.extra as int?`. |
| Bookmarks | `AyahIdentifier{surah, ayah}` stored as `"surah:ayah"` strings in Hive box `ayah_bookmarks`. |
| Continue reading | `LastReadCard` (home) shows page badge + `page / 604` percent (whole-mushaf). `LastRead{page, ayah?}` in Hive box `last_read`. Stale duplicate at `lib/core/widgets/last_quran_read.dart`. |
| Data | `quran_text_normal` (ayah text), `surah_data` (names ar/en, ayah count, Makki/Madani), `juz_data` (juzʼ→surah/verse), `page_data` (page→surah/verse). Helpers: `quran.getPageNumber(s,a)`, `getJuzNumber`, `getVerseCount`, `getSurahName`. |
| Mushaf | `MushafCubit` already supports `toggleHighlight(AyahIdentifier)`, `playingAyah`/`highlightedAyah` state, auto-scroll-to-page, and highlight-bounds publishing (used by playback). Constructor takes `initialPage` + a `currentAyahNotifier`. |

## 4. Screen model

`Scaffold` (surface bg) → `SafeArea` → `CustomScrollView`, wrapped by the existing `ScrollToTopFab`.

Slivers, in order:

1. **`AppScreenAppBar`** — eyebrow "The Noble Qurʼan", title "Surahs", **trailing bookmark `IconChip`** → pushes the existing bookmarks page.
2. **Continue-reading card** (`SliverToBoxAdapter`) — shown only when reading history exists; otherwise a slim **"ابدأ القراءة · الفاتحة / Start reading"** start card occupies the slot so the screen isn't bare. *This scrolls away.*
3. **Pinned search header** (`SliverPersistentHeader(pinned: true)`) — restyled with current tokens:
   - Row 1: one search `TextField` (chip-style, `surfaceContainer`, leading search icon, trailing clear-when-non-empty).
   - Row 2: browse-tab selector — `AppSegmentedSelector` (the existing shared widget) with **`Surah · Juz · Page`**.
4. **Content sliver** — driven by state (§5).

### 5. Two view states

The search box is **global**: typing overrides the browse view entirely.

**A) Browse (search box empty)** — content = the active tab:

| Tab | Content | Tap |
|---|---|---|
| **Surah** (default, first-time) | `AppSectionHeader("ALL SURAHS", count)` + `ListView.separated` of `SurahListTile` (114) | `/mushaf` at `surah.pageNumber` |
| **Juzʼ** | list of 30 ajzaʼ, each row: "الجزء N" + its surah span (e.g. الفاتحة → البقرة) | `/mushaf` at first page of the juzʼ |
| **Page** | a 1–604 page-jumper grid (compact number cells, ~6 per row) | `/mushaf` at that page |

**B) Search results (search box non-empty)** — content = grouped results, replaces the browse view:

```
▎ SURAHS
 ◯ الرحمن                         55
▎ AYAHS (213)
 ﴿الرحمن علم القرآن﴾          الرحمن · 55:2 · ص531
 ﴿بسم الله الرحمن الرحيم﴾    الفاتحة · 1:1 · ص1
```

- If the query is **numeric**, prepend `JumpSuggestion` chips at the top: "↳ صفحة N / Go to Page N" (1–604) and "الجزء N / Juzʼ N" (1–30).
- `SURAHS` section: name matches (ar/en), shown as compact `SurahListTile`-style rows.
- `AYAHS` section: each row shows the ayah text (snippet) + `surah name · surah:ayah · page`. A trailing count appears in the section header. Results capped at a sane display limit (e.g. 100) with a "more results — refine your search" footer note (no silent truncation).
- Empty results → a centered "no results" placeholder.
- Loading (only the very first index build, if not pre-warmed) → list **skeletonizer** per `.claude/rules/loading-states.md`, not a spinner. In practice the index builds in <1 frame so this is rarely seen.

**Tap behavior for an ayah result:** open `/mushaf` at `quran.getPageNumber(surah, ayah)` **and highlight that ayah** (§6).

## 6. Search internals — Strategy pattern (new `search` feature)

New clean-architecture feature folder: `lib/features/search/`.

### Domain
- `SearchResult` — sealed base with subtypes:
  - `SurahResult(SurahEntity surah)`
  - `AyahResult({int surah, int ayah, String text, int page})`
  - `JumpSuggestion({JumpKind kind /* page | juz */, int number, int page})`
- `SearchQuran` use case — takes a raw query string, returns `SearchResults` (grouped: `surahs`, `ayahs`, `suggestions`). Internally orchestrates strategies:
  - `SurahNameStrategy` — normalized substring over surah ar/en names.
  - `AyahTextStrategy` — normalized substring over the ayah index.
  - `NumberJumpStrategy` — if the trimmed query parses as an int, emit page (1–604) and juzʼ (1–30) suggestions where in range.
- `QuranSearchIndex` (domain port) — exposes the normalized, queryable corpus; built once.

### Data
- `QuranSearchIndexImpl` — built once at startup from `quran_text_normal` + `surah_data`. Each entry caches its **normalized text** alongside the original.
- **`ArabicNormalizer`** (core util, e.g. `lib/core/helper functions/arabic_normalizer.dart`):
  - strip tashkīl (`ً`–`ْ`, `ٰ`), tatwīl (`ـ`);
  - unify alef forms `أ إ آ ٱ → ا`, `ى → ي`, `ة → ه`;
  - collapse whitespace; English → lowercase.
  - The **same** normalizer runs on user input before matching.

### Presentation
- `SearchCubit` — holds query + results; **debounced ~250 ms**; emits `idle` (empty query) vs `results`.
- Surah-list page owns: a `SearchCubit`, the active browse tab (local state), and a `LastReadCubit`/`SurahCubit` as today.
- 6,236 entries × substring is trivial on the main thread. **Fallback if it ever janks:** move `SearchQuran` into an isolate via `compute` — explicitly out of scope for v1.

### ⚠️ Known tuning risk — corpus orthography
`quran_text_normal` uses a particular spelling (e.g. stores `الرحمان` with the middle alef, not `الرحمن`). Normalization fixes diacritics and hamza/alef *forms* but cannot bridge a present/absent *letter*. Implication: ayah matching is only as good as the corpus spelling. **Plan requires** a verification step — run ~8 real queries (`رحمن`, `العالمين`, `قل هو الله`, an English surah name, `الكوثر`, a page number, a juzʼ number) and confirm hits; tune the normalizer if a common query misses.

## 7. Bookmark decision — keep ayah-level

Keep storing `AyahIdentifier{surah, ayah}` (current behavior). Rationale:
- Precise — a page holds many ayahs; ayah is the real location.
- Page is always derivable via `quran.getPageNumber(surah, ayah)`.
- Lets bookmarks read as "Surah : Ayah".

**No code change** beyond confirming it. The bookmarks page is reachable from the new app-bar icon.

## 8. Continue-reading card — surah-relative

Update the single `LastReadCard` (home widget) and **delete the stale `lib/core/widgets/last_quran_read.dart`** if no live references remain (verify in plan).

- **Surah derivation:** `lastRead.ayah?.surah` ?? first surah on `lastRead.page` (via `quran.getPageData`).
- **Top line:** surah Arabic name + "صفحة N / Page N" together; juzʼ as a subtle third element.
- **Progress (surah-relative):**
  - If `lastRead.ayah` is known → `ayah.ayah / quran.getVerseCount(surah)`, label "آية {a} من {total} · {pct}٪".
  - Else (page only) → position of `page` within the surah's page range `[firstPage, lastPage]` → `(page - firstPage + 1) / (lastPage - firstPage + 1)`, label "صفحة {n} من {span} في السورة".
- Keep the existing `SurfaceCard` + `LinearProgressIndicator` + "Continue Reading" button visual; only the content/denominator changes.

## 9. Mushaf route — optional focus ayah

Extend `/mushaf` to optionally scroll-to + highlight an ayah, for ayah search results.

- New arg type `MushafArgs({int page, AyahIdentifier? focusAyah})`.
- Route parser is **backward-compatible**: `state.extra is int` → `MushafArgs(page: extra)`; `state.extra is MushafArgs` → use as-is. All existing call sites (last-read card, surah tile, bookmarks page) keep passing an `int` and are untouched.
- `MushafCubit` gains an optional `focusAyah`; after the initial page renders it calls the existing `toggleHighlight`/highlight-bounds path so the ayah is highlighted and centered (same machinery playback uses).

## 10. File-level plan (for the implementation plan to expand)

**New**
- `lib/features/search/domain/entities/search_result.dart` (sealed + subtypes)
- `lib/features/search/domain/repositories/quran_search_index.dart` (port)
- `lib/features/search/domain/usecases/search_quran.dart` (+ strategies, can be private helpers or small classes)
- `lib/features/search/data/quran_search_index_impl.dart`
- `lib/features/search/presentation/cubit/search_cubit.dart` (+ state)
- `lib/features/search/search_di.dart`
- `lib/core/helper functions/arabic_normalizer.dart`
- surah-list widgets: pinned search header, browse-tab content (juzʼ list, page-jumper grid), grouped search-results sliver, ayah-result row, start-reading card.

**Changed**
- `surah_list_page_body.dart` — new sliver structure + view-state switching + `SearchCubit` provider.
- `surah_search_bar.dart` — reused/restyled inside the pinned header.
- `last_read_card.dart` — surah-relative content.
- `app_router.dart` — `MushafArgs` parsing (backward compatible).
- `mushaf_cubit.dart` / `mushaf_page.dart` — optional `focusAyah` highlight.
- DI wiring (`main`/injection) — register `search_di`.

**Deleted (pending verification)**
- `lib/core/widgets/last_quran_read.dart` (if unused).

## 11. Acceptance criteria

1. First launch (no history): pinned header + `Surah` tab list of 114, no continue card (start-reading card instead).
2. Browse tabs switch the empty-state view: Surah list / 30 ajzaʼ / 1–604 page grid; each navigates correctly.
3. Typing a surah name (ar **or** en) shows it under `SURAHS`.
4. Typing ayah text shows matching verses under `AYAHS` with `surah · s:a · page`; tapping opens the correct page **with the ayah highlighted**.
5. Typing a number offers page + juzʼ jump suggestions (only in-range).
6. Continue-reading card shows surah name + page and a **surah-relative** percent.
7. Bookmarks unchanged (still ayah-level), reachable from the app-bar icon.
8. Loading uses skeletonizer, not a spinner (per project rule).
9. Existing `/mushaf` call sites still work unchanged (int extra).
10. Normalizer verified against the ~8 real queries in §6.
