# UI Refinement Pass — Design Spec

**Date:** 2026-05-28
**Status:** Approved (brainstorming)
**Scope:** Visual/widget-layer polish across the already-remastered screens. No domain/data changes except wiring two existing settings selectors. Mushaf, landing, and splash remain excluded.

## Goal

Five targeted refinements requested after the screens remaster:

1. Cairo typography across the board for readability; a better Uthmani font for hadith Arabic text.
2. App-bar / button icons that are invisible in light mode become theme-correct.
3. Replace colored card borders with a soft accent-tinted shadow.
4. Convert the language and time-format settings from toggle switches to inline segmented selectors.
5. Make back / forward arrow icons follow reading direction (RTL/LTR).

## Decisions (from brainstorming, incl. visual companion)

- **Hadith font:** Scheherazade New (Google Fonts) — chosen over Amiri Quran (current), Noto Naskh Arabic, Lateef.
- **Card treatment:** pure accent-tinted drop shadow, no borders and no leading stripe.
- **Settings selector:** inline layout — icon + label on the leading side, 2-option segmented control on the trailing side; selected segment filled with the theme accent.
- **Directional icons:** choose the arrow glyph by `Directionality.of(context)` (no mirror transform).

---

## 1. Typography — Cairo everywhere, Scheherazade New for hadith

**File:** `lib/config/theme/typography_styles.dart`
- Add extension getter `TextStyle get scheherazade => GoogleFonts.scheherazadeNew(textStyle: this);` next to `.cairo` / `.amiri` / `.amiriQuran`.
- The `TS.*` base styles are already Cairo (`_baseCairo`); keep them. Leave `.amiri` / `.amiriQuran` defined (still available) — just stop applying them to non-hadith text.

**Switch to Cairo base (remove `.amiri` override):**
- `lib/core/widgets/design/app_bar_center_title.dart` — title.
- `lib/features/surah/presentation/pages/surah_list/widgets/surah_list_tile.dart` — surah name.
- `lib/features/ahadith/presentation/pages/widgets/hadith_book_list_item.dart` — book title.
- `lib/features/ahadith/presentation/pages/widgets/hadith_view.dart` — chapter Arabic name (heading).

**Switch to Scheherazade (hadith Arabic body):**
- `lib/core/widgets/design/arabic_quote_block.dart` — replace `.amiriQuran` with `.scheherazade`.
- `lib/features/ahadith/presentation/pages/widgets/ahadith_list_item.dart` — Arabic preview text → `.scheherazade`.

**Out of scope:** mushaf rendering (its own QCF fonts), surah-name display elsewhere in mushaf.

## 2. Icon visibility in light mode

**Root cause:** hardcoded `color: Colors.white` on `HugeIcon`s inside `IconChip` and `ActionBtn`. `HugeIcon` resolves color as `widget.color ?? IconTheme.of(context).color ?? ...`, and both wrappers already provide a correct `IconTheme`.

**Fix:** remove the hardcoded `Colors.white` from every `HugeIcon` rendered inside an `IconChip` or `ActionBtn`, letting the wrapper's `IconTheme` drive the color:
- `IconChip` icons → resolve to `onSurface` (visible in both themes). Affects app bars in: `home_app_bar.dart`, `surah_list_page_body.dart`, `books_list_view.dart`, `ahadith_list_view.dart`, `hadith_view.dart`.
- `ActionBtn` icons in `hadith_view.dart` → bookmark/share resolve to `onSurfaceVariant`; the primary "Next" button stays white-on-accent (its `IconTheme` fg is already white).

No API change needed; this is removing the override at call sites. (Optionally hardening `IconChip` to ignore caller color is a stretch goal, not required.)

## 3. Cards — accent-tinted shadow, no borders

**File:** `lib/core/widgets/design/surface_card.dart` (single source of truth)
- Remove the 1px `Border.all` and the `BorderDirectional` leading-accent edge (and the `foregroundDecoration` border path).
- Add a soft `boxShadow`. Repurpose the existing `leadingAccentColor` param as the **shadow tint** (rename conceptually to an accent color; keep a sensible default):
  - When an accent color is provided (quote/narrator) → slightly stronger accent shadow, e.g. `BoxShadow(color: accent.withValues(alpha: 0.22), blurRadius: 18, offset: Offset(0, 6))`.
  - Otherwise → faint primary-tinted shadow, e.g. `BoxShadow(color: primary.withValues(alpha: 0.14), blurRadius: 14, offset: Offset(0, 4))`.
- Dark mode: keep alpha low so it reads as a subtle glow; surface contrast carries the separation. (Exact alphas finalized in implementation; values above are the target.)

**Bring hand-rolled cards in line (borders → shadow):**
- `surah_list_tile.dart`, `quick_access_grid.dart` tiles, `single_prayer_card.dart` (active state) → use the same shadow treatment, reusing `SurfaceCard` where it fits cleanly.

**Keep (not cards):** app-bar bottom hairline borders and in-card 1px dividers — these are separators, left as-is.

## 4. Language & time-format — inline segmented selectors

**New primitive:** `lib/core/widgets/design/app_segmented_selector.dart`
- Generic 2+-option segmented control: `AppSegmentedSelector<T>({required List<({T value, String label})> options, required T selected, required ValueChanged<T> onChanged})`.
- Track = `onSurface @ ~6%`, selected segment filled with theme accent + `onPrimary` text, unselected = `onSurfaceVariant`. Rounded, compact.
- No domain types leak in (generic), per core-widgets rule.

**New settings row widget** (settings feature, presentation): icon + label leading, `AppSegmentedSelector` trailing — inline layout.

**Wire-up:** `lib/features/settings/presentation/pages/settings_page.dart` — replace the two `SettingSwitch` rows in the General section:
- Time format → options 12-hour / 24-hour, bound to `SettingsCubit.updateSettings(isFormat12Hours: ...)` (note: `isFormat12Hours == true` means 24-hour, per existing convention).
- Language → العربية / English, bound to `SettingsCubit.updateSettings(isArabic: ...)`.
- The pinned-prayer-notifications toggle (Settings + Notifications page) stays a real on/off `Switch` — it is genuinely binary on/off, not a choice between equals.

## 5. Directional arrow icons

**Mechanism:** read `Directionality.of(context)` (or `S`/locale) and select the icon constant — no `Transform`/mirror.
- **Back arrow** (app-bar `IconChip` on Surah, Books, Ahadith, Hadith): RTL → `strokeRoundedArrowRight02`; LTR → `strokeRoundedArrowLeft02`.
- **Forward / continue arrows:** "Continue reading" button (`last_read_card.dart`) and "Next hadith" button (`hadith_view.dart`): RTL → left-pointing; LTR → right-pointing. Alignment follows reading direction (Row already flips via `Directionality`).
- Small shared helper (e.g. in `core/widgets/design/` or a tiny util) to avoid repeating the ternary.

## Files Touched (summary)

```
Added:
  lib/core/widgets/design/app_segmented_selector.dart
  lib/features/settings/presentation/pages/widgets/setting_selector_row.dart   (or inline)
  (optional) lib/core/widgets/design/directional_icons.dart  (arrow helper)

Modified:
  lib/config/theme/typography_styles.dart            # +scheherazade
  lib/core/widgets/design/surface_card.dart          # borders -> accent shadow
  lib/core/widgets/design/app_bar_center_title.dart  # amiri -> cairo
  lib/core/widgets/design/arabic_quote_block.dart    # amiriQuran -> scheherazade
  lib/features/surah/.../surah_list_tile.dart         # cairo name + shadow card
  lib/features/surah/.../surah_list_page_body.dart    # back-arrow direction
  lib/features/home/.../home_app_bar.dart             # icon color
  lib/features/home/.../quick_access_grid.dart        # shadow tile
  lib/features/home/.../single_prayer_card.dart       # active shadow (no border)
  lib/features/home/.../last_read_card.dart           # continue-arrow direction
  lib/features/ahadith/.../hadith_book_list_item.dart # cairo title (SurfaceCard already)
  lib/features/ahadith/.../ahadith_list_item.dart     # scheherazade preview
  lib/features/ahadith/.../ahadith_list_view.dart     # back-arrow direction, icon color
  lib/features/ahadith/.../books_list_view.dart       # back-arrow direction, icon color
  lib/features/ahadith/.../hadith_view.dart           # cairo chapter, scheherazade body,
                                                       #   icon colors, back + next arrows
  lib/features/settings/.../settings_page.dart        # switches -> selectors
```

## Testing / Validation

- `flutter analyze` — 0 errors/0 warnings (generated-file infos excluded).
- `flutter test` — existing suite green (note: `surah_list_tile_test.dart` taps the play button; the tile keeps it).
- `flutter build apk --debug` — succeeds.
- Manual (user): verify in light + dark across the 4 palettes — icon contrast, card shadows, hadith font, selectors toggle and persist, arrows point the right way in both Arabic and English.

## Out of Scope

- Mushaf, landing page, splash.
- Bundling a KFGQPC Uthmanic Hafs `.ttf` (only if the user supplies the font later).
- Localizing remaining hardcoded Arabic meta strings (surah "صفحة"/"آية") — separate concern.
