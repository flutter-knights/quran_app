# Hadith Search × Filters — Bug Fix + Filter Sheet Redesign

**Date:** 2026-05-30
**Branch:** `feature/301-side-features`
**Status:** Design — pending implementation plan

## Problem

Two related problems on the hadith list screen (`AhadithListView`):

1. **Search and filters don't work together.** When a chapter or grade filter is
   active and the user searches, results come back empty or incomplete — even
   when matching hadith exist in that chapter/grade.
2. **The filter sheet overwhelms.** Books have many chapters (Bukhari ~97, others
   more). The current sheet is a single flat, unsearchable `ListView` of every
   chapter — hard to scan, hard to find a specific chapter.

## Root Cause (Bug)

Filters *are* applied to search results — `_buildSearchResults()` calls
`applyHadithFilters(state.hadithList, _filter)`, and chapter IDs match correctly
(both `filter.chapterId` and `Hadith.chapterId` are the API `chapter.id`). The bug
is that **filtering runs over an already-truncated result set, and online search
never tells the server about the filter:**

- **Downloaded English** (`AhadithLocalDataSource.getSearchedHadiths`): caps at the
  first `kPageLimit` (100) matches via `.take(kPageLimit)` **before** the view's
  chapter filter runs → narrowing to one chapter yields few/empty results even
  when more matches exist. *Offline-first app → this is the most likely path hit.*
- **Online English** (`AhadithRemoteDataSource.getSearchedHadiths`): queries
  `hadithEnglish` + `book` only, page 1, no `chapter`/`status` → same truncation.
- **Arabic** (`AhadithArabicSearchLocalDataSource.getSearchedHadithsNumbers`): caps
  matched numbers at `kArabicSearchResultLimit` (30) **before** chapter is even
  known — the index is `number → normalizedText` only, with no chapter data.

The fix is to make search **filter-aware in the data layer** — filter before the
cap, and for online search pass the filter to the API — rather than post-filtering
a capped set in the view.

## Desired Behavior

- **Search is scoped to the active filter.** With a chapter and/or grade filter
  active, a search returns **all** matching hadith **within** that chapter/grade.
- Changing the filter while a query is active **re-runs the search** under the new
  scope.
- Clearing the query returns to the (already filter-aware) browse list.

## Architecture — Part 1: Filter-Aware Search

### Data flow

```
_SearchField ──query──► _AhadithListViewState._onQueryChanged
                                │ (also re-fires when _filter changes & query active)
                                ▼
        SearchHadithCubit.searchAhadith(query, bookSlug, filter)
                                ▼
   AhadithSearchRepository.searchHadiths(query, bookSlug, isDownloaded, filter)
            ┌───────────────────┼─────────────────────────────┐
       Arabic query        Online English                 Downloaded English
            ▼                   ▼                                 ▼
  filter numbers by      send status + chapter            filter by status +
  chapter/status in      params to API                    chapterId BEFORE
  index BEFORE cap       (chapterNumber via lookup)        .take(kPageLimit)
```

### Changes

**`HadithListFilter` (presentation/utils)** — no change to the model; it already
carries `status` + `chapterId`. It will now be passed down into search.

**`SearchHadithCubit`**
- `searchAhadith(String query, String bookSlug, HadithListFilter filter)` — accept
  and forward the active filter. Store the last `(query, bookSlug)` so the view can
  call a `reapplyFilter(filter)` (or re-call `searchAhadith`) when the filter
  changes while a query is active.

**`AhadithSearchRepository` (domain) + impl**
- `searchHadiths({required String query, required String bookSlug, required bool isDownloaded, required HadithListFilter filter})`.
- The impl gains access to the `chapterId → chapterNumber` mapping by injecting the
  existing `'chapters'` DI singleton (`Map<String, dynamic>`, already used by
  `AhadithRepositoryImpl`) and building per-book lookups the same way
  (`_generateLookups`). Consider extracting that lookup builder into a small shared
  helper so both repos use one implementation.
- **Online English path:** call a filtered remote search that forwards
  `status` (API value via the same `_statusApiValue` map) and `chapter`
  (chapterNumber from the lookup) alongside `hadithEnglish`. Add a
  `getSearchedHadiths(query, bookSlug, {status, chapterNumber})` overload (or new
  param) on `AhadithRemoteDataSource`, mirroring `getFilteredAhadithPage`.
  - *Assumption to verify in implementation:* the hadithapi.com search endpoint
    accepts `status` and `chapter` together with `hadithEnglish` (same `/hadiths`
    endpoint as the filtered page, so likely). If not, fall back to fetching
    filtered pages and matching the query client-side.
- **Downloaded English path:** `AhadithLocalDataSource.getSearchedHadiths` filters
  by `status` + `chapterId` **before** `.take(kPageLimit)`.
- **Arabic path:** see Part 3 (index gains chapter + status, enabling filtering
  before the cap).

**View (`AhadithListView`)**
- `_onQueryChanged` and `_updateFilter` both ensure search re-runs with the current
  `_filter` when a query is active.
- `applyHadithFilters` on search results is **kept as a redundant safety net** but
  is no longer load-bearing.

## Architecture — Part 2: Filter Sheet Redesign (compact sheet + small picker)

### Compact sheet (`_FilterSheet`)
- **Grade pills** (All / Sahih / Hasan / Da'eef) — only grades present in the book
  (`availableStatuses`), single-select, instant-apply. **Synced** with the
  main-screen grade chip row: both read/write the same `_filter` via `_updateFilter`
  (single source of truth — no new sync logic needed).
- **Selected-chapter card** showing the current chapter (number + name) or
  "All chapters", with a **"Change ›"** affordance. Tapping it opens the picker.
- **Clear all** resets both grade and chapter.
- Instant-apply throughout — no separate "Show results" button (matches current
  behavior).

### Small chapter picker (new widget)
- A **second bottom sheet** (capped height, scrollable — *not* full-screen) that
  slides up over the dimmed filter sheet.
- **Search field** at the top filters chapters live by chapter **number**, **Arabic
  name**, or **English name**. Shows an "N of M" / "M chapters" count.
- **"All chapters"** reset row at the top of the list; current selection is checked.
- Selecting a chapter **closes the picker and returns to the compact sheet** with
  the selection applied (the sheet stays open so the user can still adjust grade).
- Follows existing bottom-sheet conventions (`showModalBottomSheet`,
  `isScrollControlled`, surface color, grab handle). Search uses simple in-memory
  `String.contains` over the already-loaded `chapters` list (no async/skeleton
  needed — data is in memory).

### Grade chip row (main screen, `_StatusChipsRow`)
- Unchanged in placement/behavior; remains the always-visible quick toggle. Kept in
  sync with the sheet via shared `_filter` state.

## Architecture — Part 3: Arabic Search Index (chapter + status)

To make Arabic search fully filter-aware **before** the `kArabicSearchResultLimit`
cap, the search index must carry each hadith's chapter (and, for symmetry, grade).

### Index format change (`assets/json/ahadith_indices.zip`, per-book JSON)
- **Current:** `{ "<hadithNumber>": "<normalizedArabicText>" }`
- **New:** `{ "<hadithNumber>": { "t": "<normalizedText>", "c": <chapterId>, "s": "<status>" } }`

### Generator (`scripts/normalize_arabic_hadith.dart`)
- The crawl already receives `item['chapter']['id']` and `item['status']` — capture
  them into the new value object. Re-run to regenerate all seven book JSONs and
  re-zip into `assets/json/ahadith_indices.zip`.

### Parser + search (`AhadithArabicSearchLocalDataSource`)
- `_parseZipInBackground` returns the richer map (`number → {text, chapterId, status}`).
- `getSearchedHadithsNumbers({required String query, HadithListFilter? filter})`
  filters entries by `query.contains` **and** the active chapter/grade **before**
  applying `.take(kArabicSearchResultLimit)` → complete results within a chapter/grade.

### Backward compatibility
- The bundled asset is replaced wholesale (no user migration). The parser should
  tolerate a missing/old-format value defensively (treat a bare string as
  `{t: value}` with no chapter/status) so a stale asset never crashes.
- **Interim behavior until the asset is regenerated:** with the legacy
  bare-string asset still bundled, old entries parse with null chapter/grade.
  Arabic search *without* a filter is unaffected (text-only match). Arabic search
  *with* a chapter/grade filter returns **empty** (the index filters everything
  out, and the repo's in-memory net can only narrow, not recover). This is
  stricter than the pre-fix behavior (which showed partial, post-filtered
  results); it is resolved the moment the `{t,c,s}` asset ships (Task 7). The
  English (downloaded + online) paths do not depend on the asset.

## Error Handling

- Unchanged failure mapping: repo returns `Either<Failure, List<Hadith>>`; the cubit
  emits `SearchHadithError` on `Left`. Online filtered-search `DioException` follows
  the existing pattern (404 → empty list, not an error).
- Index load/decode failure continues to degrade to empty results (existing
  behavior in `getSearchedHadithsNumbers`).

## Testing

- **Failing-first repo test:** search a downloaded book with an active chapter
  filter and assert the result set contains **all** in-chapter matches (would fail
  today due to pre-cap truncation).
- Filter-aware search unit tests across the three paths (downloaded English, online
  English with forwarded params, Arabic with index-level filtering).
- Arabic index parser test for the new value format **and** old-format fallback.
- Chapter picker: search filters by number / Arabic / English; "All chapters"
  reset; selection returns to the sheet with filter applied.
- Grade sync: toggling a grade in the sheet reflects in the main chip row and vice
  versa.

## Out of Scope

- Per-chapter hadith counts (no cheap data source).
- Multi-select grade (stays single-select to map onto the API's single `status`).
- Any change to browse-list filtering (already works correctly).

## Open Items to Verify During Implementation

1. hadithapi.com `/hadiths` accepts `status` + `chapter` alongside `hadithEnglish`.
2. Regenerated `ahadith_indices.zip` size stays acceptable as a bundled asset.
