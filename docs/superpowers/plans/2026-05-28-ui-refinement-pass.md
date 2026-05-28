# UI Refinement Pass Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Apply five visual refinements across the remastered screens — Cairo typography with Scheherazade New for hadith, theme-correct icon colors, accent-tinted card shadows (no borders), inline segmented settings selectors, and direction-aware arrow icons.

**Architecture:** Change shared design primitives first (`typography_styles`, `SurfaceCard`, a new `AppSegmentedSelector`, a directional-arrow helper), then apply per-file changes so each widget file is edited once. No domain/data changes except wiring two existing `SettingsCubit` setters to the new selectors.

**Tech Stack:** Flutter, `flutter_bloc`, `google_fonts` (Cairo / Scheherazade New), `hugeicons`, the project `context.colorScheme` extension and `TS` typography.

**Reference spec:** `docs/superpowers/specs/2026-05-28-ui-refinement-pass-design.md`

---

## File Structure

### Added
```
lib/core/widgets/design/app_segmented_selector.dart   # generic 2+-option segmented control
lib/core/widgets/design/directional_icons.dart         # backArrowIcon / forwardArrowIcon helpers
lib/core/widgets/design/app_list_skeleton.dart         # shimmer placeholder list (lists)
lib/core/widgets/design/home_skeleton.dart             # shimmer placeholder home layout
test/core/widgets/design/app_segmented_selector_test.dart
```

### Modified
```
lib/config/theme/typography_styles.dart                       # +scheherazade extension
lib/core/widgets/design/surface_card.dart                     # borders -> accent shadow; rename param
lib/core/widgets/design/arabic_quote_block.dart               # amiriQuran -> scheherazade; accentColor
lib/core/widgets/design/labelled_accent_card.dart             # accentColor param rename
lib/core/widgets/design/app_bar_center_title.dart             # amiri -> cairo
lib/features/home/presentation/pages/widgets/home_app_bar.dart        # icon color
lib/features/home/presentation/pages/widgets/quick_access_grid.dart   # border -> shadow
lib/features/home/presentation/pages/widgets/single_prayer_card.dart  # active border -> shadow
lib/features/home/presentation/pages/widgets/last_read_card.dart      # continue-arrow direction
lib/features/surah/presentation/pages/surah_list/widgets/surah_list_tile.dart      # cairo + shadow
lib/features/surah/presentation/pages/surah_list/widgets/surah_list_page_body.dart # back arrow + icon color
lib/features/ahadith/presentation/pages/widgets/ahadith_list_item.dart   # scheherazade preview
lib/features/ahadith/presentation/pages/widgets/ahadith_list_view.dart   # back arrow + icon color
lib/features/ahadith/presentation/pages/widgets/books_list_view.dart     # back arrow + icon color
lib/features/ahadith/presentation/pages/widgets/hadith_book_list_item.dart # cairo title
lib/features/ahadith/presentation/pages/widgets/hadith_view.dart         # cairo/scheherazade, icon colors, arrows
lib/features/settings/presentation/pages/settings_page.dart             # switches -> selectors
pubspec.yaml                                                            # +skeletonizer
lib/features/home/presentation/pages/widgets/home_view.dart             # loading -> HomeSkeleton
```
(`ahadith_list_view.dart` and `surah_list_page_body.dart`, already listed above, also get their loading branches swapped to skeletons in Phase 4.)

---

## Phase 1 — Shared primitives & helpers

### Task 1: Add `.scheherazade` typography extension

**Files:**
- Modify: `lib/config/theme/typography_styles.dart`

- [ ] **Step 1: Add the extension getter**

In the `TypographyStylesExtension` (top of file), add `scheherazade` next to the others:

```dart
extension TypographyStylesExtension on TextStyle {
  TextStyle get amiriQuran => GoogleFonts.amiriQuran(textStyle: this);
  TextStyle get cairo => GoogleFonts.cairo(textStyle: this);
  TextStyle get amiri => GoogleFonts.amiri(textStyle: this);
  TextStyle get scheherazade => GoogleFonts.scheherazadeNew(textStyle: this);
}
```

- [ ] **Step 2: Verify analysis**

Run: `flutter analyze lib/config/theme/typography_styles.dart`
Expected: `No issues found!` (confirms `GoogleFonts.scheherazadeNew` exists in google_fonts ^6.3.3)

- [ ] **Step 3: Commit**

```bash
git add lib/config/theme/typography_styles.dart
git commit -m "feat(theme): add Scheherazade New typography extension"
```

---

### Task 2: `SurfaceCard` — accent shadow instead of borders

**Files:**
- Modify: `lib/core/widgets/design/surface_card.dart`
- Modify: `lib/core/widgets/design/arabic_quote_block.dart`
- Modify: `lib/core/widgets/design/labelled_accent_card.dart`

- [ ] **Step 1: Rewrite `surface_card.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:quran_app/config/theme/color_scheme.dart';

/// Surface-toned card with a soft drop shadow tinted by the theme accent.
/// Pass [accentColor] to tint the shadow more strongly (used by the hadith
/// quote block and the narrator card). No borders — shadow only.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 16,
    this.accentColor,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? accentColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final hasAccent = accentColor != null;
    final tint = accentColor ?? scheme.primary;
    final card = Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: tint.withValues(alpha: hasAccent ? 0.22 : 0.12),
            blurRadius: hasAccent ? 18 : 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: padding,
      child: child,
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: card,
      ),
    );
  }
}
```

- [ ] **Step 2: Update `arabic_quote_block.dart`** — swap font to Scheherazade and use `accentColor`

Replace its `build` body's `SurfaceCard(...)` call and the text style:

```dart
@override
Widget build(BuildContext context) {
  final scheme = context.colorScheme;
  return SurfaceCard(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
    accentColor: scheme.primary,
    child: Text(
      text,
      textAlign: TextAlign.right,
      textDirection: TextDirection.rtl,
      style: TS.regular16.scheherazade.copyWith(
        fontSize: fontSize,
        height: 2.1,
        color: scheme.onSurface,
      ),
    ),
  );
}
```

- [ ] **Step 3: Update `labelled_accent_card.dart`** — rename `leadingAccentColor:` to `accentColor:`

Find the `SurfaceCard(` call and change:
```dart
      leadingAccentColor: accentColor,
```
to:
```dart
      accentColor: accentColor,
```
(The widget's own `accentColor` field stays; only the `SurfaceCard` argument name changes.)

- [ ] **Step 4: Verify no other caller uses the old params**

Run: `grep -rn "leadingAccentColor\|accentWidth" lib/`
Expected: no matches.

- [ ] **Step 5: Verify analysis**

Run: `flutter analyze lib/core/widgets/design/`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/core/widgets/design/surface_card.dart lib/core/widgets/design/arabic_quote_block.dart lib/core/widgets/design/labelled_accent_card.dart
git commit -m "feat(design): replace card borders with accent-tinted shadow"
```

---

### Task 3: `AppSegmentedSelector` primitive + widget test

**Files:**
- Create: `lib/core/widgets/design/app_segmented_selector.dart`
- Create: `test/core/widgets/design/app_segmented_selector_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/config/theme/app_palette.dart';
import 'package:quran_app/core/constants/color_palette.dart';
import 'package:quran_app/core/widgets/design/app_segmented_selector.dart';

void main() {
  testWidgets('tapping an unselected segment fires onChanged with its value',
      (tester) async {
    String? picked;
    await tester.pumpWidget(
      MaterialApp(
        theme: ColorPalette.neutralLight.toThemeData(),
        home: Scaffold(
          body: AppSegmentedSelector<bool>(
            selected: false,
            onChanged: (v) => picked = v == true ? 'on' : 'off',
            options: const [
              SegmentOption(value: false, label: '12h'),
              SegmentOption(value: true, label: '24h'),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.text('24h'));
    await tester.pump();
    expect(picked, 'on');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/widgets/design/app_segmented_selector_test.dart`
Expected: FAIL (compile error — `AppSegmentedSelector` not defined)

- [ ] **Step 3: Write the widget**

```dart
import 'package:flutter/material.dart';
import 'package:quran_app/config/theme/color_scheme.dart';

class SegmentOption<T> {
  const SegmentOption({required this.value, required this.label});
  final T value;
  final String label;
}

/// Compact segmented control. The selected segment is filled with the theme
/// accent. Generic over the option value type.
class AppSegmentedSelector<T> extends StatelessWidget {
  const AppSegmentedSelector({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<SegmentOption<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: scheme.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final option in options)
            _Segment(
              label: option.label,
              selected: option.value == selected,
              onTap: () => onChanged(option.value),
            ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: 16,
            vertical: 7,
          ),
          decoration: BoxDecoration(
            color: selected ? scheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/widgets/design/app_segmented_selector_test.dart`
Expected: `All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add lib/core/widgets/design/app_segmented_selector.dart test/core/widgets/design/app_segmented_selector_test.dart
git commit -m "feat(design): add AppSegmentedSelector primitive"
```

---

### Task 4: Directional arrow helper

**Files:**
- Create: `lib/core/widgets/design/directional_icons.dart`

- [ ] **Step 1: Write the file**

```dart
import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

/// Returns the "back" arrow that points toward the start of the reading
/// direction: right-pointing in RTL (Arabic), left-pointing in LTR (English).
List<List<dynamic>> backArrowIcon(BuildContext context) =>
    Directionality.of(context) == TextDirection.rtl
        ? HugeIcons.strokeRoundedArrowRight02
        : HugeIcons.strokeRoundedArrowLeft02;

/// Returns the "forward"/continue arrow that points toward the end of the
/// reading direction: left-pointing in RTL, right-pointing in LTR.
List<List<dynamic>> forwardArrowIcon(BuildContext context) =>
    Directionality.of(context) == TextDirection.rtl
        ? HugeIcons.strokeRoundedArrowLeft02
        : HugeIcons.strokeRoundedArrowRight02;
```

- [ ] **Step 2: Verify analysis**

Run: `flutter analyze lib/core/widgets/design/directional_icons.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/core/widgets/design/directional_icons.dart
git commit -m "feat(design): add directional arrow icon helpers"
```

---

## Phase 2 — Apply per widget (each file edited once)

### Task 5: `AppBarCenterTitle` — Cairo title

**Files:**
- Modify: `lib/core/widgets/design/app_bar_center_title.dart`

- [ ] **Step 1: Drop the `.amiri` override on the title**

Change:
```dart
          style: TS.bold16.amiri.copyWith(
            fontSize: 15,
            color: scheme.onSurface,
          ),
```
to:
```dart
          style: TS.bold16.copyWith(
            fontSize: 15,
            color: scheme.onSurface,
          ),
```

- [ ] **Step 2: Commit**

```bash
git add lib/core/widgets/design/app_bar_center_title.dart
git commit -m "feat(design): use Cairo for app-bar center title"
```

---

### Task 6: `HomeAppBar` — theme-correct settings icon

**Files:**
- Modify: `lib/features/home/presentation/pages/widgets/home_app_bar.dart`

- [ ] **Step 1: Remove the hardcoded white on the settings IconChip icon**

Change:
```dart
          IconChip(
            icon: const HugeIcon(
              icon: HugeIcons.strokeRoundedSettings01,
              color: Colors.white,
              size: 16,
            ),
            onPressed: () => context.push(AppRouter.settingsPath),
          ),
```
to:
```dart
          IconChip(
            icon: const HugeIcon(
              icon: HugeIcons.strokeRoundedSettings01,
              size: 16,
            ),
            onPressed: () => context.push(AppRouter.settingsPath),
          ),
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/home/presentation/pages/widgets/home_app_bar.dart
git commit -m "fix(home): theme-correct settings icon in app bar"
```

---

### Task 7: `QuickAccessGrid` — shadow tiles, no border

**Files:**
- Modify: `lib/features/home/presentation/pages/widgets/quick_access_grid.dart`

- [ ] **Step 1: Replace the tile decoration (border → shadow)**

In `_QuickTile.build`, change the inner `Container`'s `decoration`:
```dart
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: scheme.onSurface.withValues(alpha: 0.06),
                    ),
                  ),
```
to:
```dart
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: 0.12),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/home/presentation/pages/widgets/quick_access_grid.dart
git commit -m "feat(home): shadow-style quick access tiles"
```

---

### Task 8: `SinglePrayerCard` — active state uses shadow

**Files:**
- Modify: `lib/features/home/presentation/pages/widgets/single_prayer_card.dart`

- [ ] **Step 1: Replace the active border with an accent shadow**

Change the outer `Container`'s `decoration`:
```dart
        decoration: BoxDecoration(
          color: isCurrent ? scheme.surfaceContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCurrent
                ? scheme.onSurface.withValues(alpha: 0.06)
                : Colors.transparent,
          ),
        ),
```
to:
```dart
        decoration: BoxDecoration(
          color: isCurrent ? scheme.surfaceContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isCurrent
              ? [
                  BoxShadow(
                    color: scheme.secondary.withValues(alpha: 0.20),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
        ),
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/home/presentation/pages/widgets/single_prayer_card.dart
git commit -m "feat(home): accent shadow for active prayer card"
```

---

### Task 9: `LastReadCard` — directional continue arrow

**Files:**
- Modify: `lib/features/home/presentation/pages/widgets/last_read_card.dart`

- [ ] **Step 1: Add the helper import**

Add:
```dart
import 'package:quran_app/core/widgets/design/directional_icons.dart';
```

- [ ] **Step 2: Use the directional forward arrow in the Continue button**

Change:
```dart
                icon: const HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowRight02,
                  color: Colors.white,
                  size: 11,
                ),
```
to:
```dart
                icon: HugeIcon(
                  icon: forwardArrowIcon(context),
                  color: Colors.white,
                  size: 11,
                ),
```
(The Continue button sits on the filled primary background, so white stays correct here.)

- [ ] **Step 3: Commit**

```bash
git add lib/features/home/presentation/pages/widgets/last_read_card.dart
git commit -m "feat(home): direction-aware continue-reading arrow"
```

---

### Task 10: `SurahListTile` — Cairo name + shadow card

**Files:**
- Modify: `lib/features/surah/presentation/pages/surah_list/widgets/surah_list_tile.dart`

- [ ] **Step 1: Replace the bordered Container with a shadowed one and drop `.amiri`**

Change the surrounding `Container` decoration (inside the `InkWell`):
```dart
          decoration: BoxDecoration(
            color: scheme.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: scheme.onSurface.withValues(alpha: 0.06)),
          ),
```
to:
```dart
          decoration: BoxDecoration(
            color: scheme.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: scheme.primary.withValues(alpha: 0.12),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
```

And change the surah-name text style:
```dart
                      style: TS.bold16.amiri.copyWith(
                        fontSize: 18,
                        color: scheme.onSurface,
                        height: 1.3,
                      ),
```
to:
```dart
                      style: TS.bold16.copyWith(
                        fontSize: 18,
                        color: scheme.onSurface,
                        height: 1.3,
                      ),
```

- [ ] **Step 2: Run the existing tile test (must still pass)**

Run: `flutter test test/features/surah/presentation/pages/surah_list/surah_list_tile_test.dart`
Expected: `All tests passed!`

- [ ] **Step 3: Commit**

```bash
git add lib/features/surah/presentation/pages/surah_list/widgets/surah_list_tile.dart
git commit -m "feat(surah): Cairo surah name + shadow tile"
```

---

### Task 11: `SurahListPageBody` — directional back arrow + icon color

**Files:**
- Modify: `lib/features/surah/presentation/pages/surah_list/widgets/surah_list_page_body.dart`

- [ ] **Step 1: Add the helper import**

Add:
```dart
import 'package:quran_app/core/widgets/design/directional_icons.dart';
```

- [ ] **Step 2: Replace the back IconChip icon**

Change:
```dart
                  IconChip(
                    icon: const HugeIcon(
                      icon: HugeIcons.strokeRoundedArrowLeft02,
                      color: Colors.white,
                    ),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
```
to:
```dart
                  IconChip(
                    icon: HugeIcon(icon: backArrowIcon(context)),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
```

- [ ] **Step 3: Commit**

```bash
git add lib/features/surah/presentation/pages/surah_list/widgets/surah_list_page_body.dart
git commit -m "feat(surah): direction-aware back arrow + theme icon color"
```

---

### Task 12: `BooksListView` — directional back arrow + icon colors

**Files:**
- Modify: `lib/features/ahadith/presentation/pages/widgets/books_list_view.dart`

- [ ] **Step 1: Add the helper import**

Add:
```dart
import 'package:quran_app/core/widgets/design/directional_icons.dart';
```

- [ ] **Step 2: Replace back arrow icon**

Change:
```dart
                  IconChip(
                    icon: const HugeIcon(
                      icon: HugeIcons.strokeRoundedArrowLeft02,
                      color: Colors.white,
                    ),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
```
to:
```dart
                  IconChip(
                    icon: HugeIcon(icon: backArrowIcon(context)),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
```

- [ ] **Step 3: Remove hardcoded white on the settings IconChip**

Change:
```dart
                  IconChip(
                    icon: const HugeIcon(
                      icon: HugeIcons.strokeRoundedSettings01,
                      color: Colors.white,
                    ),
                    onPressed: () => context.push(AppRouter.settingsPath),
                  ),
```
to:
```dart
                  IconChip(
                    icon: const HugeIcon(
                      icon: HugeIcons.strokeRoundedSettings01,
                    ),
                    onPressed: () => context.push(AppRouter.settingsPath),
                  ),
```

- [ ] **Step 4: Commit**

```bash
git add lib/features/ahadith/presentation/pages/widgets/books_list_view.dart
git commit -m "feat(ahadith): direction-aware back arrow + theme icon colors in books list"
```

---

### Task 13: `AhadithListItem` — Scheherazade preview

**Files:**
- Modify: `lib/features/ahadith/presentation/pages/widgets/ahadith_list_item.dart`

- [ ] **Step 1: Swap the Arabic preview font**

Change:
```dart
            style: TS.bold16.amiri.copyWith(
              fontSize: 15,
              color: scheme.onSurface,
              height: 1.7,
            ),
```
to:
```dart
            style: TS.bold16.scheherazade.copyWith(
              fontSize: 15,
              color: scheme.onSurface,
              height: 1.7,
            ),
```
(The card is a `SurfaceCard`, so the shadow treatment from Task 2 already applies.)

- [ ] **Step 2: Commit**

```bash
git add lib/features/ahadith/presentation/pages/widgets/ahadith_list_item.dart
git commit -m "feat(ahadith): Scheherazade font for hadith preview"
```

---

### Task 14: `AhadithListView` — directional back arrow + icon color

**Files:**
- Modify: `lib/features/ahadith/presentation/pages/widgets/ahadith_list_view.dart`

- [ ] **Step 1: Add the helper import**

Add:
```dart
import 'package:quran_app/core/widgets/design/directional_icons.dart';
```

- [ ] **Step 2: Replace the back IconChip icon**

Change:
```dart
                  IconChip(
                    icon: const HugeIcon(
                      icon: HugeIcons.strokeRoundedArrowLeft02,
                      color: Colors.white,
                    ),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
```
to:
```dart
                  IconChip(
                    icon: HugeIcon(icon: backArrowIcon(context)),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
```

- [ ] **Step 3: Commit**

```bash
git add lib/features/ahadith/presentation/pages/widgets/ahadith_list_view.dart
git commit -m "feat(ahadith): direction-aware back arrow in ahadith list"
```

---

### Task 15: `HadithBookListItem` — Cairo title

**Files:**
- Modify: `lib/features/ahadith/presentation/pages/widgets/hadith_book_list_item.dart`

- [ ] **Step 1: Drop `.amiri` on the book title**

Change:
```dart
                          style: TS.bold16.amiri.copyWith(
                            fontSize: 17,
                            color: scheme.onSurface,
                            height: 1.25,
                          ),
```
to:
```dart
                          style: TS.bold16.copyWith(
                            fontSize: 17,
                            color: scheme.onSurface,
                            height: 1.25,
                          ),
```
(Card is a `SurfaceCard` — shadow already applies.)

- [ ] **Step 2: Commit**

```bash
git add lib/features/ahadith/presentation/pages/widgets/hadith_book_list_item.dart
git commit -m "feat(ahadith): Cairo book title in book list item"
```

---

### Task 16: `HadithView` — fonts, icon colors, directional arrows

**Files:**
- Modify: `lib/features/ahadith/presentation/pages/widgets/hadith_view.dart`

- [ ] **Step 1: Add the helper import**

Add:
```dart
import 'package:quran_app/core/widgets/design/directional_icons.dart';
```

- [ ] **Step 2: Back arrow → directional, drop white**

Change:
```dart
                  IconChip(
                    icon: const HugeIcon(
                      icon: HugeIcons.strokeRoundedArrowLeft02,
                      color: Colors.white,
                    ),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
```
to:
```dart
                  IconChip(
                    icon: HugeIcon(icon: backArrowIcon(context)),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
```

- [ ] **Step 3: Share IconChip (app bar) → drop white**

Change:
```dart
                  IconChip(
                    icon: const HugeIcon(
                      icon: HugeIcons.strokeRoundedShare08,
                      color: Colors.white,
                    ),
                    onPressed: () => _onShare(context),
                  ),
```
to:
```dart
                  IconChip(
                    icon: const HugeIcon(icon: HugeIcons.strokeRoundedShare08),
                    onPressed: () => _onShare(context),
                  ),
```

- [ ] **Step 4: Chapter Arabic name → Cairo**

Change:
```dart
                              style: TS.bold16.amiri.copyWith(
                                fontSize: 18,
                                color: scheme.secondary,
                                height: 1.6,
                              ),
```
to:
```dart
                              style: TS.bold16.copyWith(
                                fontSize: 18,
                                color: scheme.secondary,
                                height: 1.6,
                              ),
```

- [ ] **Step 5: Bookmark + Share action icons → drop white (use ActionBtn fg)**

Change the bookmark `ActionBtn` icon:
```dart
                              icon: HugeIcon(
                                icon: marked
                                    ? HugeIcons.strokeRoundedBookmark01
                                    : HugeIcons.strokeRoundedBookmark02,
                                color: Colors.white,
                              ),
```
to:
```dart
                              icon: HugeIcon(
                                icon: marked
                                    ? HugeIcons.strokeRoundedBookmark01
                                    : HugeIcons.strokeRoundedBookmark02,
                              ),
```

Change the share `ActionBtn` icon:
```dart
                              icon: const HugeIcon(
                                icon: HugeIcons.strokeRoundedShare08,
                                color: Colors.white,
                              ),
```
to:
```dart
                              icon: const HugeIcon(
                                icon: HugeIcons.strokeRoundedShare08,
                              ),
```

- [ ] **Step 6: Next-hadith action icon → directional (keep white; it's the primary filled button)**

Change:
```dart
                            ActionBtn.primary(
                              icon: const HugeIcon(
                                icon: HugeIcons.strokeRoundedArrowRight02,
                                color: Colors.white,
                              ),
                              label: S.of(context).next_hadith,
                              onPressed: () => _onNext(context),
                            ),
```
to:
```dart
                            ActionBtn.primary(
                              icon: HugeIcon(
                                icon: forwardArrowIcon(context),
                                color: Colors.white,
                              ),
                              label: S.of(context).next_hadith,
                              onPressed: () => _onNext(context),
                            ),
```

- [ ] **Step 7: Verify the hadith Arabic body font**

The hadith Arabic matn renders via `ArabicQuoteBlock`, already switched to Scheherazade in Task 2 — no change here. Confirm by reading the `ArabicQuoteBlock(hadith.arabicHadith)` line is unchanged.

- [ ] **Step 8: Commit**

```bash
git add lib/features/ahadith/presentation/pages/widgets/hadith_view.dart
git commit -m "feat(ahadith): Cairo chapter, theme icon colors, directional arrows in hadith view"
```

---

## Phase 3 — Settings selectors

### Task 17: Replace language & time-format switches with selectors

**Files:**
- Modify: `lib/features/settings/presentation/pages/settings_page.dart`

- [ ] **Step 1: Add imports**

Add:
```dart
import 'package:quran_app/core/widgets/design/app_segmented_selector.dart';
```
(Keep the existing `setting_switch.dart` import — it is still used for the notifications row if present. If `flutter analyze` later flags it as unused, remove it.)

- [ ] **Step 2: Replace the two `SettingSwitch` rows inside the General `SurfaceCard`**

Replace this block:
```dart
              SurfaceCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    SettingSwitch(
                      settings: settings,
                      settingTitle: S.current.twentyFourHourFormat,
                      icons: const [
                        HugeIcons.strokeRoundedClock01,
                        HugeIcons.strokeRoundedTimeQuarterPass,
                      ],
                      value: settings.isFormat12Hours,
                      action: () => sl<SettingsCubit>().updateSettings(
                        isFormat12Hours: !settings.isFormat12Hours,
                      ),
                    ),
                    Container(
                      height: 1,
                      color: scheme.onSurface.withValues(alpha: 0.06),
                    ),
                    SettingSwitch(
                      settings: settings,
                      settingTitle: S.current.arabicLanguage,
                      icons: const [
                        HugeIcons.strokeRoundedLanguageSquare,
                        HugeIcons.strokeRoundedLanguageSquare,
                      ],
                      value: settings.isArabic,
                      action: () => sl<SettingsCubit>().updateSettings(
                        isArabic: !settings.isArabic,
                      ),
                    ),
                  ],
                ),
              ),
```
with:
```dart
              SurfaceCard(
                child: Column(
                  children: [
                    _SelectorRow(
                      icon: HugeIcons.strokeRoundedClock01,
                      label: S.current.twentyFourHourFormat,
                      selector: AppSegmentedSelector<bool>(
                        selected: settings.isFormat12Hours,
                        onChanged: (v) => sl<SettingsCubit>()
                            .updateSettings(isFormat12Hours: v),
                        options: [
                          SegmentOption(value: false, label: S.of(context).time_format_12h),
                          SegmentOption(value: true, label: S.of(context).time_format_24h),
                        ],
                      ),
                    ),
                    Container(
                      height: 1,
                      color: scheme.onSurface.withValues(alpha: 0.06),
                    ),
                    _SelectorRow(
                      icon: HugeIcons.strokeRoundedLanguageSquare,
                      label: S.current.arabicLanguage,
                      selector: AppSegmentedSelector<bool>(
                        selected: settings.isArabic,
                        onChanged: (v) =>
                            sl<SettingsCubit>().updateSettings(isArabic: v),
                        options: [
                          SegmentOption(value: true, label: S.of(context).language_arabic),
                          SegmentOption(value: false, label: S.of(context).language_english),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
```

> Note on the time-format mapping: in this codebase `isFormat12Hours == true` means the user enabled the **24-hour** format (the field is named opposite to its meaning). So the `value: true` segment is labelled "24h" and `value: false` is "12h". This matches `single_prayer_card`/`upcoming_prayer` which show 24-hour output when `isFormat12Hours` is true.

- [ ] **Step 3: Add the private `_SelectorRow` widget at the bottom of the file**

```dart
class _SelectorRow extends StatelessWidget {
  const _SelectorRow({
    required this.icon,
    required this.label,
    required this.selector,
  });

  final List<List<dynamic>> icon;
  final String label;
  final Widget selector;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          HugeIcon(icon: icon, color: scheme.onSurface, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: TS.regular16.cairo),
          ),
          selector,
        ],
      ),
    );
  }
}
```

Add the `hugeicons` import if not already present:
```dart
import 'package:hugeicons/hugeicons.dart';
```

- [ ] **Step 4: Add the four new l10n keys**

In `lib/l10n/intl_en.arb` (before the closing `}`, add a leading comma to the previous last entry as needed):
```json
"time_format_12h": "12h",
"time_format_24h": "24h",
"language_arabic": "العربية",
"language_english": "English"
```
In `lib/l10n/intl_ar.arb`:
```json
"time_format_12h": "١٢",
"time_format_24h": "٢٤",
"language_arabic": "العربية",
"language_english": "English"
```

- [ ] **Step 5: Regenerate l10n**

Run: `dart run intl_utils:generate`
Expected: exit 0; `grep -c "time_format_12h\|language_arabic" lib/generated/l10n.dart` returns ≥ 2.

- [ ] **Step 6: Verify analysis**

Run: `flutter analyze lib/features/settings/ lib/l10n lib/generated`
Expected: no errors/warnings (generated `strict_top_level_inference` infos are pre-existing and OK).

- [ ] **Step 7: Commit**

```bash
git add lib/features/settings/presentation/pages/settings_page.dart lib/l10n/intl_en.arb lib/l10n/intl_ar.arb lib/generated/
git commit -m "feat(settings): segmented selectors for language and time format"
```

---

## Phase 4 — Skeleton loading

Low-edit approach: the `skeletonizer` package renders any widget subtree as a shimmer skeleton when `enabled: true`. We build two small placeholder widgets and swap them into the existing loading branches — no per-field skeleton markup.

---

### Task 18: Add the `skeletonizer` dependency

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Add the dependency**

Under `dependencies:` (alphabetical-ish, near `share_plus`), add:
```yaml
  skeletonizer: ^1.4.3
```

- [ ] **Step 2: Resolve**

Run: `flutter pub get`
Expected: `Got dependencies!` (if `^1.4.3` fails to resolve against the current SDK, use the latest `flutter pub add skeletonizer` resolves to and note the version.)

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "build: add skeletonizer for loading placeholders"
```

---

### Task 19: `AppListSkeleton` + wire the list screens

**Files:**
- Create: `lib/core/widgets/design/app_list_skeleton.dart`
- Modify: `lib/features/ahadith/presentation/pages/widgets/ahadith_list_view.dart`
- Modify: `lib/features/surah/presentation/pages/surah_list/widgets/surah_list_page_body.dart`

- [ ] **Step 1: Write `app_list_skeleton.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/core/widgets/design/surface_card.dart';

/// Shimmer placeholder list for screens that load asynchronously. Drop it
/// straight into a loading branch — no per-field skeleton markup needed.
class AppListSkeleton extends StatelessWidget {
  const AppListSkeleton({super.key, this.count = 7});
  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Skeletonizer(
      enabled: true,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
        itemCount: count,
        physics: const NeverScrollableScrollPhysics(),
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, __) => SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'عنوان تجريبي للعنصر قيد التحميل',
                style: TextStyle(fontSize: 16, color: scheme.onSurface),
              ),
              const SizedBox(height: 8),
              Text(
                'سطر فرعي يوضح حالة التحميل',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Wire the hadith list loading branch**

In `ahadith_list_view.dart`, add the import:
```dart
import 'package:quran_app/core/widgets/design/app_list_skeleton.dart';
```
Then change:
```dart
                  if (state is AhadithLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
```
to:
```dart
                  if (state is AhadithLoading) {
                    return const AppListSkeleton();
                  }
```

- [ ] **Step 3: Wire the surah list initial-load**

In `surah_list_page_body.dart`, add the import:
```dart
import 'package:quran_app/core/widgets/design/app_list_skeleton.dart';
```
Then inside the `BlocBuilder<SurahCubit, List<SurahEntity>>` builder, immediately after `final filtered = _filter(surahs);`, add:
```dart
                  if (surahs.isEmpty && _query.isEmpty) {
                    return const AppListSkeleton();
                  }
```
(Initial load is an empty list with no query; a search that returns nothing still shows the normal empty list, not the skeleton.)

- [ ] **Step 4: Verify analysis**

Run: `flutter analyze lib/core/widgets/design/app_list_skeleton.dart lib/features/ahadith/presentation/pages/widgets/ahadith_list_view.dart lib/features/surah/presentation/pages/surah_list/widgets/surah_list_page_body.dart`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/core/widgets/design/app_list_skeleton.dart lib/features/ahadith/presentation/pages/widgets/ahadith_list_view.dart lib/features/surah/presentation/pages/surah_list/widgets/surah_list_page_body.dart
git commit -m "feat(loading): skeleton placeholders for hadith and surah lists"
```

---

### Task 20: `HomeSkeleton` + wire the home loading branch

**Files:**
- Create: `lib/core/widgets/design/home_skeleton.dart`
- Modify: `lib/features/home/presentation/pages/widgets/home_view.dart`

- [ ] **Step 1: Write `home_skeleton.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/core/widgets/design/surface_card.dart';

/// Shimmer placeholder mirroring the home layout (app-bar row, time hero,
/// prayers row, last-read card) while the daily prayer context loads.
class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final boxText = TextStyle(fontSize: 14, color: scheme.onSurface);
    final subText = TextStyle(fontSize: 11, color: scheme.onSurfaceVariant);
    return Skeletonizer(
      enabled: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('1447 هـ الموافق', style: boxText),
                    const SizedBox(height: 4),
                    Text('المدينة، الدولة', style: subText),
                  ],
                ),
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            Center(
              child: Text(
                '12:00',
                style: TextStyle(
                  fontSize: 58,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(child: Text('متبقٍ على الصلاة القادمة', style: subText)),
            const SizedBox(height: 28),
            Row(
              children: [
                for (int i = 0; i < 5; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Column(
                        children: [
                          Text('صلاة', style: TextStyle(fontSize: 10, color: scheme.onSurface)),
                          const SizedBox(height: 8),
                          Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text('00:00', style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('آخر قراءة — الصفحة', style: boxText),
                  const SizedBox(height: 10),
                  Text('متابعة القراءة من حيث توقفت', style: subText),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Wire the home loading branch**

In `home_view.dart`, add the import:
```dart
import 'package:quran_app/core/widgets/design/home_skeleton.dart';
```
Then change:
```dart
              if (state is DailyPrayerContextLoading) {
                return const Center(child: CircularProgressIndicator());
              }
```
to:
```dart
              if (state is DailyPrayerContextLoading) {
                return const HomeSkeleton();
              }
```

- [ ] **Step 3: Verify analysis**

Run: `flutter analyze lib/core/widgets/design/home_skeleton.dart lib/features/home/presentation/pages/widgets/home_view.dart`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add lib/core/widgets/design/home_skeleton.dart lib/features/home/presentation/pages/widgets/home_view.dart
git commit -m "feat(loading): skeleton placeholder for home while prayer context loads"
```

---

## Phase 5 — Validation

### Task 21: Full validation pass

- [ ] **Step 1: Static analysis**

Run: `flutter analyze`
Expected: 0 errors, 0 warnings (generated-file `strict_top_level_inference` infos are pre-existing).

- [ ] **Step 2: Tests**

Run: `flutter test`
Expected: all pass except the pre-existing flaky `test/tools/generate_mushaf_assets_test.dart` (verify it passes in isolation: `flutter test test/tools/generate_mushaf_assets_test.dart`).

- [ ] **Step 3: Build**

Run: `flutter build apk --debug`
Expected: build succeeds.

- [ ] **Step 4: Manual (user) smoke test**

In light + dark across the 4 palettes:
- App-bar / settings / share / back / bookmark icons are visible in light mode.
- Cards show a soft accent shadow, no borders; quote & narrator cards have a slightly stronger accent shadow.
- Hadith Arabic (detail body + list preview) renders in Scheherazade New; everything else (surah names, book/chapter titles, app-bar titles) in Cairo.
- Settings → General shows two inline segmented selectors; toggling time format and language updates the app and persists.
- Back arrow points right in Arabic / left in English; the continue-reading and next-hadith arrows point left in Arabic / right in English.
- Loading states show a shimmer skeleton (not a spinner): home while prayer context loads, hadith list while the first page loads, surah list on initial load.

- [ ] **Step 5: Final commit (only if fixes were needed)**

```bash
git add -A
git commit -m "fix: resolve validation findings from UI refinement pass"
```

---

## Self-Review notes (plan author)

- **Spec coverage:** §1 fonts → Tasks 1,2,5,10,13,15,16; §2 icons → Tasks 6,11,12,14,16; §3 shadows → Tasks 2,7,8,10 (+ SurfaceCard users auto); §4 selectors → Tasks 3,17; §5 directional → Tasks 4,9,11,12,14,16. ✓
- **Placeholders:** none — every step has concrete code/commands. ✓
- **Type consistency:** `SurfaceCard.accentColor` (Task 2) used by ArabicQuoteBlock/LabelledAccentCard; `AppSegmentedSelector<T>` + `SegmentOption<T>` (Task 3) used in Task 17; `backArrowIcon`/`forwardArrowIcon` (Task 4) used in Tasks 9,11,12,14,16; icon type `List<List<dynamic>>` matches `HugeIcon.icon`. ✓
- **New l10n keys** (`time_format_12h/24h`, `language_arabic/english`) are introduced and generated in Task 17 before use. ✓
- **Skeleton loading** (added requirement): `skeletonizer` dep (Task 18) → `AppListSkeleton` for hadith + surah lists (Task 19) → `HomeSkeleton` for home (Task 20). Low-edit: only the existing loading branches change. ✓
```
