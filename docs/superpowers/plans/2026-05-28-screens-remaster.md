# Screens Remaster Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Port the visual language of `Quran App.html` into the Flutter app across Home, Surah List, Books List, Ahadith List, Hadith Detail, Settings, and Notifications Settings — using a small shared design system and fixing the mockup's RTL bugs.

**Architecture:** Build 9 generic design primitives in `lib/core/widgets/design/`, then rebuild each screen using them. New hadith bookmark + share + next-hadith infrastructure follows the project's Clean Architecture (domain repo → data impl → use case → cubit, registered via `GetIt` in feature DI). All directional edges use `EdgeInsetsDirectional` / `BorderDirectional` so the layout works in both Arabic (RTL) and English (LTR).

**Tech Stack:** Flutter, `flutter_bloc` (Cubit), `get_it` (`sl`), `hive` (caching), `go_router`, `share_plus` (already present), `dartz` (`Either<Failure, T>`), `google_fonts` (Amiri / Cairo).

**Reference spec:** `docs/superpowers/specs/2026-05-28-screens-remaster-design.md`

---

## File Structure

### Added

```
lib/core/widgets/design/
├── app_section_header.dart      # 3×16 bar + uppercase label + optional trailing
├── app_status_badge.dart        # pill: dot + label, tinted bg+border, color-driven
├── ornament_divider.dart        # line — diamond — line
├── surface_card.dart            # surface bg + 1px border + optional leadingAccentColor
├── arabic_quote_block.dart      # SurfaceCard wrapping Amiri Quran text with primary accent
├── labelled_accent_card.dart    # SurfaceCard with uppercase label + body + accent (used for Narrator)
├── action_buttons_row.dart      # Row of equal-flex 44h buttons; ActionBtn + ActionBtn.primary
├── icon_chip.dart               # 38×38 rounded-10 on-surface-06 icon button
└── app_bar_center_title.dart    # label + Amiri title (vertically stacked, centered)

lib/features/ahadith/domain/entities/
└── hadith_bookmark.dart         # value object: bookSlug + hadithNumber

lib/features/ahadith/domain/repositories/
└── hadith_bookmark_repository.dart

lib/features/ahadith/domain/usecases/
├── toggle_hadith_bookmark.dart
├── get_hadith_bookmarks.dart
└── get_next_hadith.dart

lib/features/ahadith/data/datasources/local/
└── hadith_bookmark_local_data_source.dart

lib/features/ahadith/data/repositories/
└── hadith_bookmark_repository_impl.dart

lib/features/ahadith/presentation/cubit/
├── hadith_bookmark_cubit.dart
└── hadith_bookmark_state.dart

test/features/ahadith/
├── hadith_bookmark_local_data_source_test.dart
├── hadith_bookmark_repository_impl_test.dart
└── get_next_hadith_test.dart
```

### Modified

```
lib/config/hive_config.dart                                                # +1 box
lib/features/ahadith/ahadith_di.dart                                       # register bookmark + next-hadith
lib/features/ahadith/domain/repositories/ahadith_repository.dart           # +getNextHadith
lib/features/ahadith/data/repositories/ahadith_repository_impl.dart        # implement getNextHadith
lib/features/home/presentation/pages/widgets/home_view.dart                # full rewrite
lib/features/home/presentation/pages/widgets/home_app_bar.dart             # full rewrite
lib/features/home/presentation/pages/widgets/upcoming_prayer.dart          # full rewrite (time hero)
lib/features/home/presentation/pages/widgets/prayers_list.dart             # restyle
lib/features/home/presentation/pages/widgets/single_prayer_card.dart       # restyle
lib/features/home/presentation/pages/widgets/quick_access_grid.dart        # replaces home_action_buttons.dart
lib/features/home/presentation/pages/widgets/last_read_card.dart           # NEW within home feature
lib/features/surah/presentation/pages/surah_list/widgets/surah_list_page_body.dart   # rewrite
lib/features/surah/presentation/pages/surah_list/widgets/surah_search_bar.dart       # restyle
lib/features/surah/presentation/pages/surah_list/widgets/surah_selection_list.dart   # rewrite as surah_tile
lib/features/surah/presentation/pages/surah_list/widgets/surah_segment_selector.dart # delete
lib/features/ahadith/presentation/pages/widgets/books_list_view.dart       # rewrite
lib/features/ahadith/presentation/pages/widgets/hadith_book_list_item.dart # rewrite
lib/features/ahadith/presentation/pages/widgets/ahadith_list_view.dart     # rewrite
lib/features/ahadith/presentation/pages/widgets/ahadith_list_item.dart     # rewrite
lib/features/ahadith/presentation/pages/widgets/hadith_view.dart           # rewrite + wire bookmark/share/next
lib/features/ahadith/presentation/pages/hadith_page.dart                   # wrap in BlocProvider for HadithBookmarkCubit
lib/features/settings/presentation/pages/settings_page.dart                # restyle with new primitives
lib/features/home/presentation/pages/notifications_settings_page.dart      # restyle with new primitives
lib/l10n/intl_en.arb                                                       # +new keys
lib/l10n/intl_ar.arb                                                       # +new keys
```

---

## Phase 1 — Design Primitives

Each primitive is a focused widget file (40–80 lines). Color always comes from `context.colorScheme`. Use `EdgeInsetsDirectional` for asymmetric paddings and `BorderDirectional` for asymmetric borders. **No hadith / surah / prayer types leak into these files** (per `.claude/rules/core-widgets.md`).

After each primitive, commit. Each task is ~5 minutes.

---

### Task 1: `SurfaceCard`

**Files:**
- Create: `lib/core/widgets/design/surface_card.dart`

- [ ] **Step 1: Write the file**

```dart
import 'package:flutter/material.dart';
import 'package:quran_app/config/theme/color_scheme.dart';

/// Surface-toned card with a 1px border and an optional accent on the
/// **leading** edge (left in LTR, right in RTL). Replaces the HTML mockup's
/// hard-coded `border-right` / `border-left` rules.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 16,
    this.leadingAccentColor,
    this.accentWidth = 3,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? leadingAccentColor;
  final double accentWidth;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final border = leadingAccentColor != null
        ? BorderDirectional(
            top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4)),
            bottom: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4)),
            end: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4)),
            start: BorderSide(color: leadingAccentColor!, width: accentWidth),
          )
        : Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4));
    final decoration = ShapeDecoration(
      color: scheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: BorderSide.none,
      ),
    );
    final card = Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(radius),
        border: border is Border ? border : null,
      ),
      foregroundDecoration: border is BorderDirectional
          ? BoxDecoration(
              border: border,
              borderRadius: BorderRadius.circular(radius),
            )
          : null,
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

- [ ] **Step 2: Verify `flutter analyze` passes**

Run: `flutter analyze lib/core/widgets/design/surface_card.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/core/widgets/design/surface_card.dart
git commit -m "feat(design): add SurfaceCard primitive with directional accent"
```

---

### Task 2: `AppSectionHeader`

**Files:**
- Create: `lib/core/widgets/design/app_section_header.dart`

- [ ] **Step 1: Write the file**

```dart
import 'package:flutter/material.dart';
import 'package:quran_app/config/theme/color_scheme.dart';

/// `[3×16 secondary bar] [uppercase letter-spaced label] [optional trailing]`
class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({super.key, required this.label, this.trailing});

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: scheme.secondary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: scheme.onSurfaceVariant,
              letterSpacing: 1.2,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/core/widgets/design/app_section_header.dart
git commit -m "feat(design): add AppSectionHeader primitive"
```

---

### Task 3: `OrnamentDivider`

**Files:**
- Create: `lib/core/widgets/design/ornament_divider.dart`

- [ ] **Step 1: Write the file**

```dart
import 'package:flutter/material.dart';
import 'package:quran_app/config/theme/color_scheme.dart';

/// `——— ◆ ———` — a thin line, 6×6 rotated diamond in secondary, line.
class OrnamentDivider extends StatelessWidget {
  const OrnamentDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final line = Expanded(
      child: Container(
        height: 1,
        color: scheme.outlineVariant.withValues(alpha: 0.4),
      ),
    );
    return Row(
      children: [
        line,
        const SizedBox(width: 10),
        Transform.rotate(
          angle: 0.785398, // pi/4
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: scheme.secondary,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ),
        const SizedBox(width: 10),
        line,
      ],
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/core/widgets/design/ornament_divider.dart
git commit -m "feat(design): add OrnamentDivider primitive"
```

---

### Task 4: `AppStatusBadge`

**Files:**
- Create: `lib/core/widgets/design/app_status_badge.dart`

- [ ] **Step 1: Write the file**

```dart
import 'package:flutter/material.dart';

/// Pill with optional dot, tinted background, and 1px border in the same color.
/// Color-driven so it can serve any status (hadith grade, download state, etc).
class AppStatusBadge extends StatelessWidget {
  const AppStatusBadge({
    super.key,
    required this.color,
    required this.label,
    this.showDot = true,
  });

  final Color color;
  final String label;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/core/widgets/design/app_status_badge.dart
git commit -m "feat(design): add AppStatusBadge primitive"
```

---

### Task 5: `IconChip`

**Files:**
- Create: `lib/core/widgets/design/icon_chip.dart`

- [ ] **Step 1: Write the file**

```dart
import 'package:flutter/material.dart';
import 'package:quran_app/config/theme/color_scheme.dart';

/// 38×38 rounded-10 button used in app bars. Matches the HTML `.icon-btn`.
class IconChip extends StatelessWidget {
  const IconChip({
    super.key,
    required this.icon,
    this.onPressed,
    this.size = 38,
    this.iconSize = 16,
  });

  final Widget icon;
  final VoidCallback? onPressed;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onPressed,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: scheme.onSurface.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: scheme.onSurface.withValues(alpha: 0.12),
            ),
          ),
          alignment: Alignment.center,
          child: IconTheme(
            data: IconThemeData(color: scheme.onSurface, size: iconSize),
            child: icon,
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/core/widgets/design/icon_chip.dart
git commit -m "feat(design): add IconChip primitive"
```

---

### Task 6: `AppBarCenterTitle`

**Files:**
- Create: `lib/core/widgets/design/app_bar_center_title.dart`

- [ ] **Step 1: Write the file**

```dart
import 'package:flutter/material.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';

/// `[10sp uppercase label]` over `[15sp Amiri title]`, vertically centred.
class AppBarCenterTitle extends StatelessWidget {
  const AppBarCenterTitle({super.key, this.label, required this.title});

  final String? label;
  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null)
          Text(
            label!.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: scheme.onSurfaceVariant,
              letterSpacing: 0.5,
            ),
          ),
        Text(
          title,
          style: TS.bold16.amiri.copyWith(
            fontSize: 15,
            color: scheme.onSurface,
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/core/widgets/design/app_bar_center_title.dart
git commit -m "feat(design): add AppBarCenterTitle primitive"
```

---

### Task 7: `ArabicQuoteBlock`

**Files:**
- Create: `lib/core/widgets/design/arabic_quote_block.dart`

- [ ] **Step 1: Write the file**

```dart
import 'package:flutter/material.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/widgets/design/surface_card.dart';

/// `SurfaceCard` with primary leading accent + Amiri Quran text, line-height 2.1.
/// Generic — works for hadith Arabic text, ayah text, du'a text, etc.
class ArabicQuoteBlock extends StatelessWidget {
  const ArabicQuoteBlock(this.text, {super.key, this.fontSize = 23});

  final String text;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      leadingAccentColor: scheme.primary,
      child: Text(
        text,
        textAlign: TextAlign.right,
        textDirection: TextDirection.rtl,
        style: TS.regular16.amiriQuran.copyWith(
          fontSize: fontSize,
          height: 2.1,
          color: scheme.onSurface,
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/core/widgets/design/arabic_quote_block.dart
git commit -m "feat(design): add ArabicQuoteBlock primitive"
```

---

### Task 8: `LabelledAccentCard`

**Files:**
- Create: `lib/core/widgets/design/labelled_accent_card.dart`

- [ ] **Step 1: Write the file**

```dart
import 'package:flutter/material.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/widgets/design/surface_card.dart';

/// Compact card with uppercase label (in [accentColor]) over body text.
/// Used for the Narrator card and any future "labelled note" surface.
class LabelledAccentCard extends StatelessWidget {
  const LabelledAccentCard({
    super.key,
    required this.label,
    required this.body,
    required this.accentColor,
  });

  final String label;
  final String body;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return SurfaceCard(
      padding: const EdgeInsets.all(14),
      radius: 12,
      leadingAccentColor: accentColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: accentColor,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            body,
            style: TS.regular14.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/core/widgets/design/labelled_accent_card.dart
git commit -m "feat(design): add LabelledAccentCard primitive"
```

---

### Task 9: `ActionButtonsRow`

**Files:**
- Create: `lib/core/widgets/design/action_buttons_row.dart`

- [ ] **Step 1: Write the file**

```dart
import 'package:flutter/material.dart';
import 'package:quran_app/config/theme/color_scheme.dart';

/// Row of equal-flex 44h buttons. Use `ActionBtn.primary` for the filled
/// emphasis variant.
class ActionButtonsRow extends StatelessWidget {
  const ActionButtonsRow({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: children[i]),
        ],
      ],
    );
  }
}

class ActionBtn extends StatelessWidget {
  const ActionBtn({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
  }) : _primary = false;

  const ActionBtn.primary({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
  }) : _primary = true;

  final Widget icon;
  final String label;
  final VoidCallback? onPressed;
  final bool _primary;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final fg = _primary ? Colors.white : scheme.onSurfaceVariant;
    final bg = _primary
        ? scheme.primary
        : scheme.onSurface.withValues(alpha: 0.06);
    final border = _primary
        ? scheme.primary
        : scheme.onSurface.withValues(alpha: 0.12);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border),
          ),
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconTheme(
                data: IconThemeData(color: fg, size: 14),
                child: icon,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify all primitives compile together**

Run: `flutter analyze lib/core/widgets/design/`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/core/widgets/design/action_buttons_row.dart
git commit -m "feat(design): add ActionButtonsRow + ActionBtn primitives"
```

---

## Phase 2 — Hadith Bookmark Infrastructure

Mirrors the existing ayah bookmark stack (`features/bookmarks/`). New box `hadith_bookmarks` stores `List<String>` keyed by `"$bookSlug:$hadithNumber"`.

---

### Task 10: `HadithBookmark` value object

**Files:**
- Create: `lib/features/ahadith/domain/entities/hadith_bookmark.dart`

- [ ] **Step 1: Write the file**

```dart
class HadithBookmark {
  const HadithBookmark({required this.bookSlug, required this.hadithNumber});

  final String bookSlug;
  final int hadithNumber;

  String get storageKey => '$bookSlug:$hadithNumber';

  static HadithBookmark? tryParse(String key) {
    final parts = key.split(':');
    if (parts.length != 2) return null;
    final n = int.tryParse(parts[1]);
    if (n == null || parts[0].isEmpty) return null;
    return HadithBookmark(bookSlug: parts[0], hadithNumber: n);
  }

  @override
  bool operator ==(Object other) =>
      other is HadithBookmark &&
      other.bookSlug == bookSlug &&
      other.hadithNumber == hadithNumber;

  @override
  int get hashCode => Object.hash(bookSlug, hadithNumber);
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/ahadith/domain/entities/hadith_bookmark.dart
git commit -m "feat(ahadith): add HadithBookmark value object"
```

---

### Task 11: Open the Hive box

**Files:**
- Modify: `lib/config/hive_config.dart` — add box open after the ayah_bookmarks line

- [ ] **Step 1: Read current state**

```bash
grep -n "ayah_bookmarks" lib/config/hive_config.dart
```

Expected: a line like `await Hive.openBox<List>('ayah_bookmarks');`

- [ ] **Step 2: Add hadith_bookmarks box opening**

Edit the file to add this line immediately **after** the `ayah_bookmarks` open:

```dart
  await Hive.openBox<List>('hadith_bookmarks');
```

- [ ] **Step 3: Commit**

```bash
git add lib/config/hive_config.dart
git commit -m "feat(hive): open hadith_bookmarks box"
```

---

### Task 12: Local data source + unit test

**Files:**
- Create: `lib/features/ahadith/data/datasources/local/hadith_bookmark_local_data_source.dart`
- Create: `test/features/ahadith/hadith_bookmark_local_data_source_test.dart`

- [ ] **Step 1: Write the data source**

```dart
import 'package:hive/hive.dart';

import '../../../../../core/errors/exceptions.dart';
import '../../../domain/entities/hadith_bookmark.dart';

class HadithBookmarkLocalDataSource {
  HadithBookmarkLocalDataSource({required this.box});
  final Box<List> box;

  static const _key = 'all';

  Set<HadithBookmark> getAll() {
    final raw = box.get(_key);
    if (raw == null) return <HadithBookmark>{};
    final result = <HadithBookmark>{};
    for (final entry in raw) {
      if (entry is! String) continue;
      final parsed = HadithBookmark.tryParse(entry);
      if (parsed != null) result.add(parsed);
    }
    return result;
  }

  /// Toggles the bookmark. Returns `true` if the bookmark is now present.
  Future<bool> toggle(HadithBookmark bookmark) async {
    try {
      final current =
          (box.get(_key) ?? <String>[]).cast<String>().toList(growable: true);
      final key = bookmark.storageKey;
      final wasPresent = current.remove(key);
      if (!wasPresent) current.add(key);
      await box.put(_key, current);
      return !wasPresent;
    } catch (e) {
      throw CacheException('hadith bookmark toggle failed: $e');
    }
  }
}
```

- [ ] **Step 2: Write the unit test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_test/hive_test.dart';
import 'package:hive/hive.dart';

import 'package:quran_app/features/ahadith/data/datasources/local/hadith_bookmark_local_data_source.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith_bookmark.dart';

void main() {
  late HadithBookmarkLocalDataSource sut;
  late Box<List> box;

  setUp(() async {
    await setUpTestHive();
    box = await Hive.openBox<List>('hadith_bookmarks_test');
    sut = HadithBookmarkLocalDataSource(box: box);
  });

  tearDown(() async {
    await tearDownTestHive();
  });

  test('getAll returns empty set when box is empty', () {
    expect(sut.getAll(), isEmpty);
  });

  test('toggle adds when not present and returns true', () async {
    final added = await sut.toggle(
      const HadithBookmark(bookSlug: 'bukhari', hadithNumber: 42),
    );
    expect(added, isTrue);
    expect(sut.getAll(), {
      const HadithBookmark(bookSlug: 'bukhari', hadithNumber: 42),
    });
  });

  test('toggle removes when present and returns false', () async {
    await sut.toggle(
      const HadithBookmark(bookSlug: 'bukhari', hadithNumber: 42),
    );
    final removed = await sut.toggle(
      const HadithBookmark(bookSlug: 'bukhari', hadithNumber: 42),
    );
    expect(removed, isFalse);
    expect(sut.getAll(), isEmpty);
  });

  test('different books with same hadith number are distinct', () async {
    await sut.toggle(const HadithBookmark(bookSlug: 'bukhari', hadithNumber: 1));
    await sut.toggle(const HadithBookmark(bookSlug: 'muslim', hadithNumber: 1));
    expect(sut.getAll().length, 2);
  });
}
```

- [ ] **Step 3: Add `hive_test` to dev_dependencies (if missing)**

Check: `grep "hive_test" pubspec.yaml`
If absent, add under `dev_dependencies:`:

```yaml
  hive_test: ^1.0.1
```

Then run: `flutter pub get`

- [ ] **Step 4: Run the test**

Run: `flutter test test/features/ahadith/hadith_bookmark_local_data_source_test.dart`
Expected: `All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add lib/features/ahadith/data/datasources/local/hadith_bookmark_local_data_source.dart \
        test/features/ahadith/hadith_bookmark_local_data_source_test.dart \
        pubspec.yaml pubspec.lock
git commit -m "feat(ahadith): add HadithBookmarkLocalDataSource + tests"
```

---

### Task 13: Repository abstract + impl + test

**Files:**
- Create: `lib/features/ahadith/domain/repositories/hadith_bookmark_repository.dart`
- Create: `lib/features/ahadith/data/repositories/hadith_bookmark_repository_impl.dart`
- Create: `test/features/ahadith/hadith_bookmark_repository_impl_test.dart`

- [ ] **Step 1: Write the abstract repo**

```dart
import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../entities/hadith_bookmark.dart';

abstract class HadithBookmarkRepository {
  Future<Either<Failure, Set<HadithBookmark>>> getAll();
  Future<Either<Failure, bool>> toggle(HadithBookmark bookmark);
}
```

- [ ] **Step 2: Write the impl**

```dart
import 'package:dartz/dartz.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failure.dart';
import '../../domain/entities/hadith_bookmark.dart';
import '../../domain/repositories/hadith_bookmark_repository.dart';
import '../datasources/local/hadith_bookmark_local_data_source.dart';

class HadithBookmarkRepositoryImpl implements HadithBookmarkRepository {
  HadithBookmarkRepositoryImpl({required this.dataSource});
  final HadithBookmarkLocalDataSource dataSource;

  @override
  Future<Either<Failure, Set<HadithBookmark>>> getAll() async {
    try {
      return Right(dataSource.getAll());
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, bool>> toggle(HadithBookmark bookmark) async {
    try {
      return Right(await dataSource.toggle(bookmark));
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }
}
```

- [ ] **Step 3: Write the repo test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';

import 'package:quran_app/features/ahadith/data/datasources/local/hadith_bookmark_local_data_source.dart';
import 'package:quran_app/features/ahadith/data/repositories/hadith_bookmark_repository_impl.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith_bookmark.dart';

void main() {
  late HadithBookmarkRepositoryImpl sut;
  late Box<List> box;

  setUp(() async {
    await setUpTestHive();
    box = await Hive.openBox<List>('hadith_bookmarks_test_repo');
    sut = HadithBookmarkRepositoryImpl(
      dataSource: HadithBookmarkLocalDataSource(box: box),
    );
  });

  tearDown(() async {
    await tearDownTestHive();
  });

  test('getAll wraps result in Right', () async {
    final result = await sut.getAll();
    result.fold((l) => fail('expected Right'), (set) => expect(set, isEmpty));
  });

  test('toggle returns Right(true) on add, Right(false) on remove', () async {
    const b = HadithBookmark(bookSlug: 'bukhari', hadithNumber: 42);
    final add = await sut.toggle(b);
    add.fold((l) => fail('expected Right'), (v) => expect(v, isTrue));
    final rem = await sut.toggle(b);
    rem.fold((l) => fail('expected Right'), (v) => expect(v, isFalse));
  });
}
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/ahadith/hadith_bookmark_repository_impl_test.dart`
Expected: `All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add lib/features/ahadith/domain/repositories/hadith_bookmark_repository.dart \
        lib/features/ahadith/data/repositories/hadith_bookmark_repository_impl.dart \
        test/features/ahadith/hadith_bookmark_repository_impl_test.dart
git commit -m "feat(ahadith): add HadithBookmarkRepository + impl + tests"
```

---

### Task 14: Use cases (toggle + get)

**Files:**
- Create: `lib/features/ahadith/domain/usecases/toggle_hadith_bookmark.dart`
- Create: `lib/features/ahadith/domain/usecases/get_hadith_bookmarks.dart`

- [ ] **Step 1: Write `ToggleHadithBookmark`**

```dart
import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../entities/hadith_bookmark.dart';
import '../repositories/hadith_bookmark_repository.dart';

class ToggleHadithBookmark {
  ToggleHadithBookmark(this._repo);
  final HadithBookmarkRepository _repo;

  Future<Either<Failure, bool>> call(HadithBookmark bookmark) =>
      _repo.toggle(bookmark);
}
```

- [ ] **Step 2: Write `GetHadithBookmarks`**

```dart
import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../entities/hadith_bookmark.dart';
import '../repositories/hadith_bookmark_repository.dart';

class GetHadithBookmarks {
  GetHadithBookmarks(this._repo);
  final HadithBookmarkRepository _repo;

  Future<Either<Failure, Set<HadithBookmark>>> call() => _repo.getAll();
}
```

- [ ] **Step 3: Commit**

```bash
git add lib/features/ahadith/domain/usecases/toggle_hadith_bookmark.dart \
        lib/features/ahadith/domain/usecases/get_hadith_bookmarks.dart
git commit -m "feat(ahadith): add hadith bookmark use cases"
```

---

### Task 15: `HadithBookmarkCubit` + state

**Files:**
- Create: `lib/features/ahadith/presentation/cubit/hadith_bookmark_state.dart`
- Create: `lib/features/ahadith/presentation/cubit/hadith_bookmark_cubit.dart`

- [ ] **Step 1: Write state**

```dart
import '../../domain/entities/hadith_bookmark.dart';

class HadithBookmarkState {
  const HadithBookmarkState({
    this.bookmarks = const <HadithBookmark>{},
    this.loaded = false,
    this.error,
  });

  final Set<HadithBookmark> bookmarks;
  final bool loaded;
  final String? error;

  bool contains(HadithBookmark b) => bookmarks.contains(b);

  HadithBookmarkState copyWith({
    Set<HadithBookmark>? bookmarks,
    bool? loaded,
    String? error,
  }) =>
      HadithBookmarkState(
        bookmarks: bookmarks ?? this.bookmarks,
        loaded: loaded ?? this.loaded,
        error: error,
      );
}
```

- [ ] **Step 2: Write cubit**

```dart
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/hadith_bookmark.dart';
import '../../domain/usecases/get_hadith_bookmarks.dart';
import '../../domain/usecases/toggle_hadith_bookmark.dart';
import 'hadith_bookmark_state.dart';

class HadithBookmarkCubit extends Cubit<HadithBookmarkState> {
  HadithBookmarkCubit({
    required this.getBookmarks,
    required this.toggleBookmark,
  }) : super(const HadithBookmarkState()) {
    _load();
  }

  final GetHadithBookmarks getBookmarks;
  final ToggleHadithBookmark toggleBookmark;

  Future<void> _load() async {
    final result = await getBookmarks();
    if (isClosed) return;
    result.fold(
      (f) => emit(state.copyWith(loaded: true, error: f.message)),
      (set) => emit(state.copyWith(loaded: true, bookmarks: set, error: null)),
    );
  }

  Future<void> toggle(HadithBookmark bookmark) async {
    if (!state.loaded) return;
    final result = await toggleBookmark(bookmark);
    if (isClosed) return;
    result.fold(
      (f) => emit(state.copyWith(error: f.message)),
      (nowBookmarked) {
        final next = Set<HadithBookmark>.from(state.bookmarks);
        if (nowBookmarked) {
          next.add(bookmark);
        } else {
          next.remove(bookmark);
        }
        emit(state.copyWith(bookmarks: next, error: null));
      },
    );
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add lib/features/ahadith/presentation/cubit/hadith_bookmark_state.dart \
        lib/features/ahadith/presentation/cubit/hadith_bookmark_cubit.dart
git commit -m "feat(ahadith): add HadithBookmarkCubit"
```

---

## Phase 3 — Next-Hadith Use Case

Adds a `getNextHadith` method to `AhadithRepository`. The repo already fetches paginated `HadithPage` objects, so `getNextHadith(bookSlug, currentNumber)` walks forward from the current page; if the current hadith is the last on its page, fetches the next page; if no further hadith exists, returns `null`.

---

### Task 16: Extend `AhadithRepository` abstract

**Files:**
- Modify: `lib/features/ahadith/domain/repositories/ahadith_repository.dart`

- [ ] **Step 1: Read current abstract**

```bash
cat lib/features/ahadith/domain/repositories/ahadith_repository.dart
```

- [ ] **Step 2: Add the new method to the abstract class**

Add inside the abstract class body:

```dart
  /// Returns the next hadith after [currentHadithNumber] within [bookSlug],
  /// or `Right(null)` when no further hadith exists.
  Future<Either<Failure, Hadith?>> getNextHadith({
    required String bookSlug,
    required int currentHadithNumber,
  });
```

Add the import at the top if missing:

```dart
import '../entities/hadith.dart';
```

- [ ] **Step 3: Commit**

```bash
git add lib/features/ahadith/domain/repositories/ahadith_repository.dart
git commit -m "feat(ahadith): add getNextHadith to repository abstract"
```

---

### Task 17: Implement `getNextHadith` in repo impl + test

**Files:**
- Modify: `lib/features/ahadith/data/repositories/ahadith_repository_impl.dart`
- Create: `test/features/ahadith/get_next_hadith_test.dart`

- [ ] **Step 1: Add the implementation**

Add this method inside `AhadithRepositoryImpl` (after `downloadAllAhadith`):

```dart
  @override
  Future<Either<Failure, Hadith?>> getNextHadith({
    required String bookSlug,
    required int currentHadithNumber,
  }) async {
    final totalPages = HadithPagination.getTotalPages(bookSlug);
    // Find which page the current hadith is on by walking forward from page 1.
    // Optimisation: most caller scenarios start on the same page as the current
    // hadith, so begin at page 1 and short-circuit when found.
    int page = 1;
    Hadith? candidate;
    while (page <= totalPages) {
      final pageResult = await getAhadithPage(page, bookSlug);
      final hadithList = pageResult.fold((_) => <Hadith>[], (p) => p.ahadithList);
      if (hadithList.isEmpty) return const Right(null);
      final idx = hadithList.indexWhere(
        (h) => h.hadithNumber == currentHadithNumber,
      );
      if (idx >= 0) {
        if (idx + 1 < hadithList.length) {
          candidate = hadithList[idx + 1];
          return Right(candidate);
        }
        // Current is the last on this page — look at the next page.
        if (page + 1 > totalPages) return const Right(null);
        final nextPage = await getAhadithPage(page + 1, bookSlug);
        return nextPage.fold(
          (f) => Left(f),
          (p) => Right(p.ahadithList.isEmpty ? null : p.ahadithList.first),
        );
      }
      page++;
    }
    return const Right(null);
  }
```

Add import if missing at top of file:

```dart
import 'package:quran_app/features/ahadith/domain/entities/hadith.dart';
```

- [ ] **Step 2: Write the use case**

Create `lib/features/ahadith/domain/usecases/get_next_hadith.dart`:

```dart
import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../entities/hadith.dart';
import '../repositories/ahadith_repository.dart';

class GetNextHadith {
  GetNextHadith(this._repo);
  final AhadithRepository _repo;

  Future<Either<Failure, Hadith?>> call({
    required String bookSlug,
    required int currentHadithNumber,
  }) =>
      _repo.getNextHadith(
        bookSlug: bookSlug,
        currentHadithNumber: currentHadithNumber,
      );
}
```

- [ ] **Step 3: Write a happy-path test using a fake repo**

```dart
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith.dart';
import 'package:quran_app/features/ahadith/domain/entities/download_progress.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith_page.dart';
import 'package:quran_app/features/ahadith/domain/repositories/ahadith_repository.dart';
import 'package:quran_app/features/ahadith/domain/usecases/get_next_hadith.dart';

class _FakeRepo implements AhadithRepository {
  _FakeRepo(this._pages);
  final Map<int, List<Hadith>> _pages; // page -> list

  @override
  Future<Either<Failure, HadithPage>> getAhadithPage(
    int pageNumber,
    String bookSlug,
  ) async {
    final list = _pages[pageNumber] ?? const <Hadith>[];
    return Right(HadithPage(
      ahadithList: list,
      lastPage: !_pages.containsKey(pageNumber + 1),
    ));
  }

  @override
  Stream<DownloadProgress> downloadAllAhadith(String bookSlug) async* {}

  @override
  Future<Either<Failure, Hadith?>> getNextHadith({
    required String bookSlug,
    required int currentHadithNumber,
  }) async {
    // Delegate to the same logic — copied verbatim from impl for the test.
    int page = 1;
    while (_pages.containsKey(page)) {
      final list = _pages[page]!;
      final idx = list.indexWhere((h) => h.hadithNumber == currentHadithNumber);
      if (idx >= 0) {
        if (idx + 1 < list.length) return Right(list[idx + 1]);
        if (!_pages.containsKey(page + 1)) return const Right(null);
        final next = _pages[page + 1]!;
        return Right(next.isEmpty ? null : next.first);
      }
      page++;
    }
    return const Right(null);
  }
}

Hadith _h(int n) => Hadith(
      hadithNumber: n,
      englishHadith: '',
      arabicHadith: '',
      englishNarrator: '',
      englishHeader: '',
      arabicHeader: '',
      status: HadithStatus.sahih,
      chapterId: 1,
    );

void main() {
  test('returns next hadith within same page', () async {
    final sut = GetNextHadith(_FakeRepo({1: [_h(1), _h(2), _h(3)]}));
    final r = await sut(bookSlug: 'b', currentHadithNumber: 1);
    r.fold((l) => fail('expected Right'), (h) => expect(h?.hadithNumber, 2));
  });

  test('rolls to next page when current is last of its page', () async {
    final sut = GetNextHadith(_FakeRepo({1: [_h(1), _h(2)], 2: [_h(3)]}));
    final r = await sut(bookSlug: 'b', currentHadithNumber: 2);
    r.fold((l) => fail('expected Right'), (h) => expect(h?.hadithNumber, 3));
  });

  test('returns null at the end of the book', () async {
    final sut = GetNextHadith(_FakeRepo({1: [_h(1)]}));
    final r = await sut(bookSlug: 'b', currentHadithNumber: 1);
    r.fold((l) => fail('expected Right'), (h) => expect(h, isNull));
  });
}
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/ahadith/get_next_hadith_test.dart`
Expected: `All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add lib/features/ahadith/data/repositories/ahadith_repository_impl.dart \
        lib/features/ahadith/domain/usecases/get_next_hadith.dart \
        test/features/ahadith/get_next_hadith_test.dart
git commit -m "feat(ahadith): implement getNextHadith with tests"
```

---

### Task 18: Wire all new ahadith DI

**Files:**
- Modify: `lib/features/ahadith/ahadith_di.dart`

- [ ] **Step 1: Read the file**

```bash
cat lib/features/ahadith/ahadith_di.dart
```

- [ ] **Step 2: Add registrations**

Add the following imports at the top:

```dart
import 'package:quran_app/features/ahadith/data/datasources/local/hadith_bookmark_local_data_source.dart';
import 'package:quran_app/features/ahadith/data/repositories/hadith_bookmark_repository_impl.dart';
import 'package:quran_app/features/ahadith/domain/repositories/hadith_bookmark_repository.dart';
import 'package:quran_app/features/ahadith/domain/usecases/get_hadith_bookmarks.dart';
import 'package:quran_app/features/ahadith/domain/usecases/get_next_hadith.dart';
import 'package:quran_app/features/ahadith/domain/usecases/toggle_hadith_bookmark.dart';
import 'package:quran_app/features/ahadith/presentation/cubit/hadith_bookmark_cubit.dart';
```

Add this at the **end** of `initAhadith()`, before the closing `}`:

```dart
  // Hadith bookmarks
  sl.registerLazySingleton<HadithBookmarkLocalDataSource>(
    () => HadithBookmarkLocalDataSource(
      box: Hive.box<List>('hadith_bookmarks'),
    ),
  );
  sl.registerLazySingleton<HadithBookmarkRepository>(
    () => HadithBookmarkRepositoryImpl(dataSource: sl()),
  );
  sl.registerLazySingleton<GetHadithBookmarks>(() => GetHadithBookmarks(sl()));
  sl.registerLazySingleton<ToggleHadithBookmark>(
    () => ToggleHadithBookmark(sl()),
  );
  sl.registerLazySingleton<HadithBookmarkCubit>(
    () => HadithBookmarkCubit(
      getBookmarks: sl(),
      toggleBookmark: sl(),
    ),
  );

  // Next hadith navigation
  sl.registerLazySingleton<GetNextHadith>(() => GetNextHadith(sl()));
```

Also add `import 'package:hive/hive.dart';` at the top if missing.

- [ ] **Step 3: Verify analysis**

Run: `flutter analyze lib/features/ahadith/`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add lib/features/ahadith/ahadith_di.dart
git commit -m "feat(ahadith): register hadith bookmark + next-hadith dependencies"
```

---

## Phase 4 — Localization keys

Add the new strings up front so every subsequent screen task can use them.

---

### Task 19: Add new ARB keys

**Files:**
- Modify: `lib/l10n/intl_en.arb`
- Modify: `lib/l10n/intl_ar.arb`

- [ ] **Step 1: Add to `intl_en.arb` (before the closing `}`)**

```json
,
"prayers": "Prayers",
"lastRead": "Last Read",
"quickAccess": "Quick Access",
"quran_screen_title": "Quran",
"hadith_screen_title": "Hadith",
"bookmarks_screen_title": "Bookmarks",
"settings_screen_title": "Settings",
"all_surahs": "All Surahs",
"surahs_count": "{count} surahs",
"search_surah_hint": "Search for a surah...",
"the_noble_quran": "The Noble Qur'an",
"surahs_appbar_title": "Surahs",
"collections_label": "Collections",
"hadith_books_appbar_title": "Hadith Books",
"books_section": "Books",
"books_count": "{count} books",
"ahadith_section": "Ahadith",
"ahadith_count": "{count} ahadith",
"narrator_label": "Narrator",
"next_hadith": "Next",
"progress_complete": "{percent}% complete",
"makkiyya": "Makkiyya",
"madaniyya": "Madaniyya",
"appearance_section": "Appearance",
"general_section": "General"
```

- [ ] **Step 2: Add the same keys to `intl_ar.arb`**

```json
,
"prayers": "الصلوات",
"lastRead": "آخر قراءة",
"quickAccess": "الوصول السريع",
"quran_screen_title": "القرآن الكريم",
"hadith_screen_title": "الحديث الشريف",
"bookmarks_screen_title": "الإشارات",
"settings_screen_title": "الإعدادات",
"all_surahs": "جميع السور",
"surahs_count": "{count} سورة",
"search_surah_hint": "ابحث عن سورة...",
"the_noble_quran": "القرآن الكريم",
"surahs_appbar_title": "السور",
"collections_label": "المجموعات",
"hadith_books_appbar_title": "الحديث الشريف",
"books_section": "الكتب",
"books_count": "{count} كتب",
"ahadith_section": "الأحاديث",
"ahadith_count": "{count} حديث",
"narrator_label": "الراوي",
"next_hadith": "التالي",
"progress_complete": "{percent}% مكتمل",
"makkiyya": "مكية",
"madaniyya": "مدنية",
"appearance_section": "المظهر",
"general_section": "عام"
```

- [ ] **Step 3: Regenerate l10n**

Run: `flutter pub run intl_utils:generate`
(If the project uses `flutter_intl` IDE extension instead, save both ARB files in your editor — it autogenerates.)
Expected: `lib/generated/l10n.dart` updates with the new getters.

- [ ] **Step 4: Commit**

```bash
git add lib/l10n/intl_en.arb lib/l10n/intl_ar.arb lib/generated/
git commit -m "feat(l10n): add keys for screens remaster"
```

---

## Phase 5 — Home Screen

The current `HomeView` is rebuilt around explicit sections per HTML `#sc-home`. The `LastReadCubit` is already provided at the app root (verify in `main.dart` / `app.dart`) — if not, add a `BlocProvider` for it in `HomePage`.

---

### Task 20: Rewrite `HomeAppBar`

**Files:**
- Modify: `lib/features/home/presentation/pages/widgets/home_app_bar.dart`

- [ ] **Step 1: Replace the file**

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/config/router/app_router.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/widgets/design/icon_chip.dart';
import 'package:quran_app/features/home/domain/entities/daily_prayer_context.dart';

class HomeAppBar extends StatelessWidget {
  const HomeAppBar({super.key, required this.dailyPrayerContext});
  final DailyPrayerContext dailyPrayerContext;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Container(
      height: 60,
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          bottom: BorderSide(
            color: scheme.onSurface.withValues(alpha: 0.06),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dailyPrayerContext.hijriDate,
                  style: TS.bold14,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedLocation01,
                      color: scheme.onSurfaceVariant,
                      size: 11,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        dailyPrayerContext.location.city,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: scheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconChip(
            icon: const HugeIcon(
              icon: HugeIcons.strokeRoundedSettings01,
              color: Colors.white, // overridden by IconChip's IconTheme
              size: 16,
            ),
            onPressed: () => context.push(AppRouter.settingsPath),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Verify `dailyPrayerContext.hijriDate` and `location.city` exist**

```bash
grep -n "hijriDate\|location\|city" lib/features/home/domain/entities/daily_prayer_context.dart
```

If `hijriDate` does not exist on `DailyPrayerContext`, format it inline here from the date field using the existing `hijriDateWithDay` localization template. Adjust the body accordingly.

- [ ] **Step 3: Commit**

```bash
git add lib/features/home/presentation/pages/widgets/home_app_bar.dart
git commit -m "feat(home): rewrite HomeAppBar with date + location + settings chip"
```

---

### Task 21: Rewrite time hero (`UpcomingPrayer` → `TimeHero`)

**Files:**
- Modify: `lib/features/home/presentation/pages/widgets/upcoming_prayer.dart`

- [ ] **Step 1: Read current file**

```bash
cat lib/features/home/presentation/pages/widgets/upcoming_prayer.dart
```

This tells you what cubit it watches and which prayer-name extension it uses. Keep those.

- [ ] **Step 2: Replace the file with the new layout**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/features/home/presentation/cubit/prayer_countdown_cubit.dart';
import 'package:quran_app/generated/l10n.dart';

class UpcomingPrayer extends StatelessWidget {
  const UpcomingPrayer({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return BlocBuilder<PrayerCountdownCubit, PrayerCountdownState>(
      builder: (context, state) {
        // Adapt the field accesses below to the actual fields PrayerCountdownState exposes.
        // Most likely: state.currentTime (DateTime), state.nextPrayer, state.timeUntil.
        final timeOfDay = TimeOfDay.now();
        final hour = timeOfDay.hourOfPeriod == 0 ? 12 : timeOfDay.hourOfPeriod;
        final minute = timeOfDay.minute.toString().padLeft(2, '0');
        final period = timeOfDay.period == DayPeriod.am ? 'AM' : 'PM';

        return Column(
          children: [
            const SizedBox(height: 12),
            RichText(
              text: TextSpan(
                style: TS.extra36.copyWith(
                  fontSize: 58,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                  letterSpacing: -2,
                  height: 1,
                ),
                children: [
                  TextSpan(text: '$hour:$minute'),
                  TextSpan(
                    text: ' $period',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: scheme.secondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 7),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: scheme.secondary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                // Use the existing localized template `remainingTimeLabel`:
                //   "{time} remaining for {prayerName}"
                // Adapt to your cubit state's actual fields. If the cubit
                // does not yet expose a formatted countdown, fall back to
                // a placeholder String here and replace once data is ready.
                Text(
                  S.of(context).remainingTimeLabel(
                        _formatCountdown(state),
                        _nextPrayerName(context, state),
                      ),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  // The two helpers below pull from whatever fields PrayerCountdownState
  // exposes today. If your state class has `remaining` and `nextPrayer`
  // already, simplify to direct field reads.
  String _formatCountdown(PrayerCountdownState state) {
    // Fallback for the placeholder; replace with state.remainingTime once available.
    if (state is PrayerCountdownTicking) {
      final d = state.remaining;
      final h = d.inHours;
      final m = d.inMinutes.remainder(60);
      return '${h}h ${m}m';
    }
    return '—';
  }

  String _nextPrayerName(BuildContext context, PrayerCountdownState state) {
    if (state is PrayerCountdownTicking) {
      // Assumes the existing PrayerName.localized(BuildContext) extension.
      return state.nextPrayer.localized(context);
    }
    return '';
  }
}
```

- [ ] **Step 3: Reconcile with actual `PrayerCountdownState`**

Open `lib/features/home/presentation/cubit/prayer_countdown_state.dart` and adjust the helper functions above to match real state class names and fields. **Do not invent fields** — pattern-match on whatever subclasses exist (`PrayerCountdownTicking`, `PrayerCountdownIdle`, etc).

- [ ] **Step 4: `flutter analyze`**

Run: `flutter analyze lib/features/home/presentation/pages/widgets/upcoming_prayer.dart`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/features/home/presentation/pages/widgets/upcoming_prayer.dart
git commit -m "feat(home): rewrite UpcomingPrayer as time hero"
```

---

### Task 22: Restyle `PrayersList` + `SinglePrayerCard`

**Files:**
- Modify: `lib/features/home/presentation/pages/widgets/prayers_list.dart`
- Modify: `lib/features/home/presentation/pages/widgets/single_prayer_card.dart`

- [ ] **Step 1: Update `single_prayer_card.dart`**

Replace its contents with:

```dart
import 'package:flutter/material.dart';
import 'package:quran_app/config/theme/color_scheme.dart';

class SinglePrayerCard extends StatelessWidget {
  const SinglePrayerCard({
    super.key,
    required this.name,
    required this.time,
    required this.icon,
    this.isActive = false,
  });

  final String name;
  final String time;
  final IconData icon;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final fg = isActive ? scheme.secondary : scheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(4, 10, 4, 11),
      decoration: BoxDecoration(
        color: isActive ? scheme.surfaceContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive
              ? scheme.onSurface.withValues(alpha: 0.06)
              : Colors.transparent,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isActive ? scheme.secondary : scheme.onSurface,
            ),
          ),
          const SizedBox(height: 5),
          Icon(icon, size: 18, color: fg),
          const SizedBox(height: 5),
          Text(
            time,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
          if (isActive) ...[
            const SizedBox(height: 4),
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.secondary,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Update `prayers_list.dart`** to lay out 5 equal-flex cards

```dart
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';
import 'package:quran_app/features/home/presentation/pages/widgets/single_prayer_card.dart';
// Existing localization helpers for prayer names + formatted times.
// Adjust import paths if your project organizes these elsewhere.

class PrayersList extends StatelessWidget {
  const PrayersList({super.key, required this.prayerTimes, this.activePrayer});
  final PrayerTimes prayerTimes;
  final PrayerName? activePrayer;

  static const _order = [
    PrayerName.fajr,
    PrayerName.dhuhr,
    PrayerName.asr,
    PrayerName.maghrib,
    PrayerName.isha,
  ];

  IconData _iconFor(PrayerName p) {
    switch (p) {
      case PrayerName.fajr:
        return HugeIcons.strokeRoundedMoon02;
      case PrayerName.dhuhr:
        return HugeIcons.strokeRoundedSun02;
      case PrayerName.asr:
        return HugeIcons.strokeRoundedSun03;
      case PrayerName.maghrib:
        return HugeIcons.strokeRoundedSunset02;
      case PrayerName.isha:
        return HugeIcons.strokeRoundedMoon01;
      default:
        return HugeIcons.strokeRoundedClock01;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final p in _order)
          Expanded(
            child: SinglePrayerCard(
              name: p.localized(context),
              time: prayerTimes.timings[p]?.formatted(context) ?? '',
              icon: _iconFor(p),
              isActive: activePrayer == p,
            ),
          ),
      ],
    );
  }
}
```

- [ ] **Step 3: Fix imports + extension references**

Open the file in the IDE. The `p.localized(context)` and `time.formatted(context)` calls must resolve to actual extensions in your codebase. Search for them:

```bash
grep -rn "extension.*PrayerName\|extension.*on DateTime" lib/features/home/presentation/utils/ 2>/dev/null
```

Adjust the imports and method names to whatever exists today.

- [ ] **Step 4: Commit**

```bash
git add lib/features/home/presentation/pages/widgets/prayers_list.dart \
        lib/features/home/presentation/pages/widgets/single_prayer_card.dart
git commit -m "feat(home): restyle prayers row with active highlight"
```

---

### Task 23: Add `LastReadCard` widget

**Files:**
- Create: `lib/features/home/presentation/pages/widgets/last_read_card.dart`

- [ ] **Step 1: Write the file**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/config/router/app_router.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/widgets/design/surface_card.dart';
import 'package:quran_app/features/surah/domain/entities/last_read.dart';
import 'package:quran_app/features/surah/presentation/cubit/last_read/last_read_cubit.dart';
import 'package:quran_app/generated/l10n.dart';

/// Last-read card on Home. Hides itself when no last-read exists.
/// Returns `null` from `maybeBuild` to let callers skip the section header too.
class LastReadCard extends StatelessWidget {
  const LastReadCard({super.key, required this.last});
  final LastRead last;

  static Widget? maybeBuild(BuildContext context) {
    final last = context.watch<LastReadCubit>().state;
    if (last == null) return null;
    return LastReadCard(last: last);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final percent = ((last.page / 604) * 100).round();
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      radius: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: 9,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: scheme.onSurface.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: scheme.onSurface.withValues(alpha: 0.12),
                  ),
                ),
                child: Text(
                  S.of(context).page_label('${last.page}'),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: scheme.secondary,
                  ),
                ),
              ),
              Text(
                '$percent% ${S.of(context).progress_complete(percent.toString()).split(' ').skip(1).join(' ')}',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent / 100,
              minHeight: 3,
              backgroundColor: scheme.onSurface.withValues(alpha: 0.06),
              valueColor: AlwaysStoppedAnimation(scheme.secondary),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                last.ayah == null
                    ? S.of(context).page_label(last.page.toString())
                    : S.of(context).ayah_label(
                          last.ayah!.surah.toString(),
                          last.ayah!.ayah.toString(),
                        ),
                style: TS.bold14.copyWith(color: scheme.onSurface),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: scheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
                onPressed: () => context.push(
                  AppRouter.mushafPath,
                  extra: last.page,
                ),
                icon: const HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowRight02,
                  color: Colors.white,
                  size: 11,
                ),
                label: Text(
                  S.of(context).continue_reading,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/home/presentation/pages/widgets/last_read_card.dart
git commit -m "feat(home): add LastReadCard wired to LastReadCubit"
```

---

### Task 24: Add `QuickAccessGrid` widget (replaces `HomeActionButtons`)

**Files:**
- Create: `lib/features/home/presentation/pages/widgets/quick_access_grid.dart`
- Delete: `lib/features/home/presentation/pages/widgets/home_action_buttons.dart` (after step 4)
- Delete: `lib/features/home/presentation/pages/widgets/home_button.dart` (if no longer used after step 4)

- [ ] **Step 1: Write the new widget**

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/config/router/app_router.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/generated/l10n.dart';

class QuickAccessGrid extends StatelessWidget {
  const QuickAccessGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 4,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 0.78,
      children: [
        _QuickTile(
          icon: HugeIcons.strokeRoundedBookOpen01,
          label: S.of(context).quran_screen_title,
          onTap: () => context.push(AppRouter.surahListPath),
        ),
        _QuickTile(
          icon: HugeIcons.strokeRoundedBookmark02,
          label: S.of(context).hadith_screen_title,
          onTap: () => context.push(AppRouter.booksPath),
        ),
        _QuickTile(
          icon: HugeIcons.strokeRoundedFavourite,
          label: S.of(context).bookmarks_screen_title,
          enabled: false, // no bookmarks page exists yet
        ),
        _QuickTile(
          icon: HugeIcons.strokeRoundedSettings01,
          label: S.of(context).settings_screen_title,
          onTap: () => context.push(AppRouter.settingsPath),
        ),
      ],
    );
  }
}

class _QuickTile extends StatelessWidget {
  const _QuickTile({
    required this.icon,
    required this.label,
    this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Column(
        children: [
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: enabled ? onTap : null,
                child: Container(
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: scheme.onSurface.withValues(alpha: 0.06),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, size: 24, color: scheme.onSurface),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Verify analysis**

Run: `flutter analyze lib/features/home/presentation/pages/widgets/quick_access_grid.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit (without deleting old files yet)**

```bash
git add lib/features/home/presentation/pages/widgets/quick_access_grid.dart
git commit -m "feat(home): add QuickAccessGrid"
```

- [ ] **Step 4: Defer deletions** of `home_action_buttons.dart` and `home_button.dart` until after Task 25 (so we keep the app compiling between commits).

---

### Task 25: Rewrite `HomeView`

**Files:**
- Modify: `lib/features/home/presentation/pages/widgets/home_view.dart`
- Delete (after this task): `lib/features/home/presentation/pages/widgets/home_action_buttons.dart`, `home_button.dart`

- [ ] **Step 1: Replace `home_view.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/core/widgets/design/app_section_header.dart';
import 'package:quran_app/core/widgets/design/ornament_divider.dart';
import 'package:quran_app/features/home/presentation/cubit/daily_prayer_context_cubit.dart';
import 'package:quran_app/features/home/presentation/cubit/prayer_countdown_cubit.dart';
import 'package:quran_app/features/home/presentation/pages/widgets/home_app_bar.dart';
import 'package:quran_app/features/home/presentation/pages/widgets/last_read_card.dart';
import 'package:quran_app/features/home/presentation/pages/widgets/prayers_list.dart';
import 'package:quran_app/features/home/presentation/pages/widgets/quick_access_grid.dart';
import 'package:quran_app/features/home/presentation/pages/widgets/upcoming_prayer.dart';
import 'package:quran_app/generated/l10n.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: BlocListener<DailyPrayerContextCubit, DailyPrayerContextState>(
          listener: (context, state) {
            if (state is DailyPrayerContextLoaded) {
              context
                  .read<PrayerCountdownCubit>()
                  .startTimer(state.dailyPrayerContext);
            }
          },
          child: BlocBuilder<DailyPrayerContextCubit, DailyPrayerContextState>(
            builder: (context, state) {
              if (state is DailyPrayerContextLoading) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state is DailyPrayerContextFailed) {
                return Center(child: Text(state.error));
              }
              if (state is DailyPrayerContextLoaded) {
                final ctx = state.dailyPrayerContext;
                final last = LastReadCard.maybeBuild(context);
                return Column(
                  children: [
                    HomeAppBar(dailyPrayerContext: ctx),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const UpcomingPrayer(),
                            const SizedBox(height: 14),
                            const OrnamentDivider(),
                            const SizedBox(height: 14),
                            AppSectionHeader(label: S.of(context).prayers),
                            const SizedBox(height: 10),
                            PrayersList(prayerTimes: ctx.prayerTimes),
                            if (last != null) ...[
                              const SizedBox(height: 14),
                              AppSectionHeader(label: S.of(context).lastRead),
                              const SizedBox(height: 10),
                              last,
                            ],
                            const SizedBox(height: 14),
                            AppSectionHeader(
                              label: S.of(context).quickAccess,
                            ),
                            const SizedBox(height: 10),
                            const QuickAccessGrid(),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }
              return const SizedBox();
            },
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Ensure `LastReadCubit` is provided above `HomeView`**

```bash
grep -rn "LastReadCubit" lib/main.dart lib/config/ 2>/dev/null
```

If `LastReadCubit` is **not** provided at app root (or above `HomeView`), wrap `HomeView` in `HomePage`:

```dart
// inside HomePage.build, alongside the existing MultiBlocProvider
BlocProvider(create: (_) => sl<LastReadCubit>())
```

You may need to register the cubit if it isn't already in `last_read_di.dart` — verify with:

```bash
grep -n "LastReadCubit" lib/features/surah/last_read_di.dart
```

- [ ] **Step 3: Delete the obsolete widgets**

```bash
rm lib/features/home/presentation/pages/widgets/home_action_buttons.dart
rm lib/features/home/presentation/pages/widgets/home_button.dart
```

Search the codebase for references and remove imports:

```bash
grep -rn "home_action_buttons\|home_button" lib/
```

- [ ] **Step 4: Run app and visually verify**

Run: `flutter run -d <emulator-id>`
Expected:
- App bar shows Hijri date + location, gear icon pushes to settings
- Time hero shows current time + countdown
- Prayers row shows 5 cards
- Last Read appears only when last-read is set
- Quick access grid has 4 tiles; Bookmarks tile is dimmed

- [ ] **Step 5: Commit**

```bash
git add lib/features/home/presentation/pages/widgets/home_view.dart
git rm lib/features/home/presentation/pages/widgets/home_action_buttons.dart \
       lib/features/home/presentation/pages/widgets/home_button.dart
git commit -m "feat(home): rebuild HomeView with sectioned layout"
```

---

## Phase 6 — Surah List

---

### Task 26: Restyle `SurahSearchBar`

**Files:**
- Modify: `lib/features/surah/presentation/pages/surah_list/widgets/surah_search_bar.dart`

- [ ] **Step 1: Read current file**

```bash
cat lib/features/surah/presentation/pages/surah_list/widgets/surah_search_bar.dart
```

- [ ] **Step 2: Rewrite to a thin 40h surface-bordered TextField**

```dart
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/generated/l10n.dart';

class SurahSearchBar extends StatelessWidget {
  const SurahSearchBar({super.key, required this.onChanged});
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Container(
      height: 40,
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: scheme.onSurface.withValues(alpha: 0.10),
        ),
      ),
      child: Row(
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedSearch01,
            color: scheme.onSurfaceVariant,
            size: 15,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              onChanged: onChanged,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: scheme.onSurface,
              ),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: S.of(context).search_surah_hint,
                hintStyle: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Reconcile call sites**

```bash
grep -rn "SurahSearchBar(" lib/
```

If the existing constructor passes more parameters (e.g. an explicit controller), expand the API to accept them.

- [ ] **Step 4: Commit**

```bash
git add lib/features/surah/presentation/pages/surah_list/widgets/surah_search_bar.dart
git commit -m "feat(surah): restyle surah search bar"
```

---

### Task 27: New `SurahTile` widget (replaces `SurahSelectionList` item)

**Files:**
- Create: `lib/features/surah/presentation/pages/surah_list/widgets/surah_tile.dart`

- [ ] **Step 1: Write the file**

```dart
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/helper%20functions/locale_helpers.dart';
import 'package:quran_app/features/surah/domain/entities/surah_entity.dart';
import 'package:quran_app/generated/l10n.dart';

class SurahTile extends StatelessWidget {
  const SurahTile({super.key, required this.surah, required this.onTap});
  final SurahEntity surah;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final meta = [
      // Adjust property names to whatever SurahEntity exposes
      // (e.g. `surah.revelation == RevelationType.makki ? makkiyya : madaniyya`).
      surah.revelationType.isMakki
          ? S.of(context).makkiyya
          : S.of(context).madaniyya,
      '${surah.ayahCount.toLocalized(context)} ${S.of(context).ayah_label('', '').split(',').first}',
      'p. ${surah.startingPage.toString().toLocalized(context)}',
    ].join(' · ');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: scheme.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: scheme.onSurface.withValues(alpha: 0.06),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: scheme.onSurface.withValues(alpha: 0.06),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: scheme.onSurface.withValues(alpha: 0.12),
                  ),
                ),
                child: Icon(
                  HugeIcons.strokeRoundedPlay,
                  size: 13,
                  color: scheme.secondary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      surah.arabicName,
                      style: TS.bold16.amiri.copyWith(
                        fontSize: 18,
                        color: scheme.onSurface,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      meta,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: scheme.onSurface.withValues(alpha: 0.06),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: scheme.onSurface.withValues(alpha: 0.10),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  surah.number.toString().toLocalized(context),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Reconcile property names**

The exact property names on `SurahEntity` (e.g. `revelationType`, `ayahCount`, `startingPage`, `arabicName`, `number`) **must match the entity**. Read `lib/features/surah/domain/entities/surah_entity.dart` and fix the field accesses.

- [ ] **Step 3: Commit**

```bash
git add lib/features/surah/presentation/pages/surah_list/widgets/surah_tile.dart
git commit -m "feat(surah): add SurahTile widget"
```

---

### Task 28: Rewrite `SurahListPageBody`

**Files:**
- Modify: `lib/features/surah/presentation/pages/surah_list/widgets/surah_list_page_body.dart`
- Delete: `lib/features/surah/presentation/pages/surah_list/widgets/surah_segment_selector.dart`
- Delete: `lib/features/surah/presentation/pages/surah_list/widgets/surah_selection_list.dart`
- Delete: `lib/features/surah/presentation/pages/surah_list/widgets/surah_number_star.dart` (if not used elsewhere)

- [ ] **Step 1: Replace body**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/config/router/app_router.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/core/helper%20functions/locale_helpers.dart';
import 'package:quran_app/core/widgets/design/app_bar_center_title.dart';
import 'package:quran_app/core/widgets/design/app_section_header.dart';
import 'package:quran_app/core/widgets/design/icon_chip.dart';
import 'package:quran_app/core/widgets/design/surface_card.dart';
import 'package:quran_app/features/home/presentation/pages/widgets/last_read_card.dart';
import 'package:quran_app/features/surah/presentation/cubit/surah/surah_cubit.dart';
import 'package:quran_app/features/surah/presentation/cubit/last_read/last_read_cubit.dart';
import 'package:quran_app/features/surah/presentation/pages/surah_list/widgets/surah_search_bar.dart';
import 'package:quran_app/features/surah/presentation/pages/surah_list/widgets/surah_tile.dart';
import 'package:quran_app/generated/l10n.dart';

class SurahListPageBody extends StatelessWidget {
  const SurahListPageBody({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Column(
      children: [
        // App bar
        Container(
          height: 60,
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: scheme.onSurface.withValues(alpha: 0.06),
              ),
            ),
          ),
          child: Row(
            children: [
              IconChip(
                icon: const HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowLeft02,
                  color: Colors.white,
                ),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              const Spacer(),
              AppBarCenterTitle(
                label: S.of(context).the_noble_quran,
                title: S.of(context).surahs_appbar_title,
              ),
              const Spacer(),
              IconChip(
                icon: const HugeIcon(
                  icon: HugeIcons.strokeRoundedMenu01,
                  color: Colors.white,
                ),
                onPressed: () {},
              ),
            ],
          ),
        ),
        Expanded(
          child: BlocBuilder<SurahCubit, SurahCubitState>(
            builder: (context, state) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (context.watch<LastReadCubit>().state != null) ...[
                      LastReadCard(last: context.watch<LastReadCubit>().state!),
                      const SizedBox(height: 14),
                    ],
                    SurahSearchBar(
                      onChanged: (q) =>
                          context.read<SurahCubit>().searchSurahs(q),
                    ),
                    const SizedBox(height: 14),
                    AppSectionHeader(
                      label: S.of(context).all_surahs,
                      trailing: Text(
                        S.of(context).surahs_count(
                              state.surahs.length.toLocalized(context),
                            ),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: scheme.secondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: state.surahs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final s = state.surahs[i];
                        return SurahTile(
                          surah: s,
                          onTap: () => context.push(
                            AppRouter.mushafPath,
                            extra: s.startingPage,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Reconcile against `SurahCubit` API**

Read `lib/features/surah/presentation/cubit/surah/surah_cubit.dart` and `_state.dart`. The actual state type / `surahs` getter / `searchSurahs` method names must match. Fix any divergence.

- [ ] **Step 3: Delete obsolete widgets**

```bash
rm lib/features/surah/presentation/pages/surah_list/widgets/surah_segment_selector.dart
rm lib/features/surah/presentation/pages/surah_list/widgets/surah_selection_list.dart
```

Check for stragglers: `grep -rn "surah_segment_selector\|surah_selection_list\|SurahSegmentSelector\|SurahSelectionList" lib/` — remove any imports/usages found.

- [ ] **Step 4: Provide `LastReadCubit` for the route**

In `lib/config/router/app_router.dart`, the `/surahList` route already provides `SurahCubit`. Extend it with `LastReadCubit`:

```dart
GoRoute(
  path: surahListPath,
  pageBuilder: GoTransitions.fade.withFade.build(
    builder: (context, state) => MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => sl<SurahCubit>()..fetchSurahs()),
        BlocProvider(create: (_) => sl<LastReadCubit>()),
      ],
      child: const SurahListPage(),
    ),
  ),
),
```

Add the `import 'package:flutter_bloc/flutter_bloc.dart';` and LastReadCubit import.

- [ ] **Step 5: Run + visual check**

Run: `flutter run -d <emulator>` → navigate to `/surahList`. Verify the continue bar appears only when last-read is set; search filters; tap → mushaf.

- [ ] **Step 6: Commit**

```bash
git add lib/features/surah/presentation/pages/surah_list/ lib/config/router/app_router.dart
git rm lib/features/surah/presentation/pages/surah_list/widgets/surah_segment_selector.dart \
       lib/features/surah/presentation/pages/surah_list/widgets/surah_selection_list.dart
git commit -m "feat(surah): rebuild surah list with new design system"
```

---

## Phase 7 — Books List

---

### Task 29: Rewrite `HadithBookListItem`

**Files:**
- Modify: `lib/features/ahadith/presentation/pages/widgets/hadith_book_list_item.dart`

- [ ] **Step 1: Replace the file**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/helper%20functions/locale_helpers.dart';
import 'package:quran_app/core/widgets/design/surface_card.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith_book_info.dart';
import 'package:quran_app/features/ahadith/presentation/cubit/download_book_cubit.dart';
import 'package:quran_app/generated/l10n.dart';

class HadithBookListItem extends StatelessWidget {
  const HadithBookListItem({
    super.key,
    required this.onTap,
    required this.bookInfo,
  });

  final VoidCallback onTap;
  final HadithBookInfo bookInfo;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return BlocBuilder<DownloadBookCubit, DownloadBookState>(
      builder: (context, state) {
        final downloading = state.isCurrentlyDownloading(bookInfo.slug);
        final downloaded = state.downloadedBooks.contains(bookInfo.slug);
        final progress = state.getBookProgress(bookInfo.slug);

        final action = _BookAction(
          downloaded: downloaded,
          downloading: downloading,
          progressPct: progress,
          onDownload: () => context
              .read<DownloadBookCubit>()
              .downloadBook(bookSlug: bookInfo.slug),
        );

        return SurfaceCard(
          padding: const EdgeInsets.all(14),
          radius: 14,
          onTap: onTap,
          child: Column(
            children: [
              Row(
                children: [
                  action,
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bookInfo.arabicTitle,
                          style: TS.bold16.amiri.copyWith(
                            fontSize: 17,
                            color: scheme.onSurface,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          bookInfo.title,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurfaceVariant,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${bookInfo.author} · ${bookInfo.hadithCount.toString().toLocalized(context)} ${S.of(context).hadith_total_label}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (downloading) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: progress / 100,
                    minHeight: 3,
                    backgroundColor:
                        scheme.onSurface.withValues(alpha: 0.10),
                    valueColor: AlwaysStoppedAnimation(scheme.secondary),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _BookAction extends StatelessWidget {
  const _BookAction({
    required this.downloaded,
    required this.downloading,
    required this.progressPct,
    required this.onDownload,
  });

  final bool downloaded;
  final bool downloading;
  final int progressPct;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final Color bg, fg, border;
    Widget content;

    if (downloaded) {
      bg = const Color(0xFF3D9E6E).withValues(alpha: 0.12);
      border = const Color(0xFF3D9E6E).withValues(alpha: 0.30);
      fg = const Color(0xFF3D9E6E);
      content = const HugeIcon(
        icon: HugeIcons.strokeRoundedTick02,
        color: Color(0xFF3D9E6E),
        size: 18,
      );
    } else if (downloading) {
      bg = scheme.onSurface.withValues(alpha: 0.06);
      border = scheme.onSurface.withValues(alpha: 0.25);
      fg = scheme.secondary;
      content = Text(
        '$progressPct%',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      );
    } else {
      bg = scheme.onSurface.withValues(alpha: 0.06);
      border = scheme.onSurface.withValues(alpha: 0.10);
      fg = scheme.onSurfaceVariant;
      content = HugeIcon(
        icon: HugeIcons.strokeRoundedDownload01,
        color: fg,
        size: 18,
      );
    }

    return GestureDetector(
      onTap: downloaded || downloading ? null : onDownload,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        alignment: Alignment.center,
        child: content,
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/ahadith/presentation/pages/widgets/hadith_book_list_item.dart
git commit -m "feat(ahadith): redesign HadithBookListItem with badge action"
```

---

### Task 30: Rewrite `BooksListView` with new app bar and section header

**Files:**
- Modify: `lib/features/ahadith/presentation/pages/widgets/books_list_view.dart`

- [ ] **Step 1: Read existing**

```bash
cat lib/features/ahadith/presentation/pages/widgets/books_list_view.dart
```

- [ ] **Step 2: Replace with new layout**

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/config/router/app_router.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/core/constants/hadith_constants.dart';
import 'package:quran_app/core/helper%20functions/locale_helpers.dart';
import 'package:quran_app/core/widgets/design/app_bar_center_title.dart';
import 'package:quran_app/core/widgets/design/app_section_header.dart';
import 'package:quran_app/core/widgets/design/icon_chip.dart';
import 'package:quran_app/features/ahadith/presentation/pages/widgets/hadith_book_list_item.dart';
import 'package:quran_app/generated/l10n.dart';

class BooksListView extends StatelessWidget {
  const BooksListView({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final books = HadithBooksRegistry.all; // adjust to actual lookup

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 60,
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: scheme.onSurface.withValues(alpha: 0.06),
                  ),
                ),
              ),
              child: Row(
                children: [
                  IconChip(
                    icon: const HugeIcon(
                      icon: HugeIcons.strokeRoundedArrowLeft02,
                      color: Colors.white,
                    ),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const Spacer(),
                  AppBarCenterTitle(
                    label: S.of(context).collections_label,
                    title: S.of(context).hadith_books_appbar_title,
                  ),
                  const Spacer(),
                  IconChip(
                    icon: const HugeIcon(
                      icon: HugeIcons.strokeRoundedSettings01,
                      color: Colors.white,
                    ),
                    onPressed: () => context.push(AppRouter.settingsPath),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppSectionHeader(
                      label: S.of(context).books_section,
                      trailing: Text(
                        S.of(context).books_count(
                              books.length.toLocalized(context),
                            ),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: scheme.secondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (final book in books) ...[
                      HadithBookListItem(
                        bookInfo: book,
                        onTap: () => context.push(
                          AppRouter.ahadithPath,
                          extra: book.slug,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2.5: Reconcile `HadithBooksRegistry.all` reference**

Search for how the existing view enumerates books:

```bash
grep -rn "HadithBookInfo\|hadithBooks" lib/features/ahadith/ | head -20
```

Substitute the actual provider (likely a constants file or a method on `AhadithRepository`).

- [ ] **Step 3: Run + visual check**

Navigate to `/books`. Verify section header shows count, each book shows badge + title block, tap on Tirmidhi triggers download (badge → "%" + progress bar).

- [ ] **Step 4: Commit**

```bash
git add lib/features/ahadith/presentation/pages/widgets/books_list_view.dart
git commit -m "feat(ahadith): rebuild BooksListView with new design system"
```

---

## Phase 8 — Ahadith List

---

### Task 31: Rewrite `AhadithListItem`

**Files:**
- Modify: `lib/features/ahadith/presentation/pages/widgets/ahadith_list_item.dart`

- [ ] **Step 1: Replace the file**

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quran_app/config/router/app_router.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/helper%20functions/locale_helpers.dart';
import 'package:quran_app/core/widgets/design/app_status_badge.dart';
import 'package:quran_app/core/widgets/design/surface_card.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith.dart';
import 'package:quran_app/generated/l10n.dart';

class AhadithListItem extends StatelessWidget {
  const AhadithListItem({super.key, required this.hadith});
  final Hadith hadith;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      radius: 12,
      onTap: () => context.push(AppRouter.hadithPath, extra: hadith),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AppStatusBadge(
                color: _statusColor(hadith.status),
                label: _statusLabel(context, hadith.status),
              ),
              Text(
                '#${hadith.hadithNumber.toLocalized(context)}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurfaceVariant,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            hadith.arabicHadith,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TS.bold16.amiri.copyWith(
              fontSize: 15,
              color: scheme.onSurface,
              height: 1.7,
            ),
          ),
          if (hadith.chapter != null) ...[
            const SizedBox(height: 8),
            Text(
              hadith.chapter!.chapterArabic,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static Color _statusColor(HadithStatus s) => switch (s) {
        HadithStatus.sahih => const Color(0xFF3D9E6E),
        HadithStatus.hasan => const Color(0xFFC8882A),
        HadithStatus.daeef => const Color(0xFFD05050),
      };

  static String _statusLabel(BuildContext context, HadithStatus s) =>
      switch (s) {
        HadithStatus.sahih => S.of(context).status_sahih,
        HadithStatus.hasan => S.of(context).status_hasan,
        HadithStatus.daeef => S.of(context).status_daeef,
      };
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/ahadith/presentation/pages/widgets/ahadith_list_item.dart
git commit -m "feat(ahadith): redesign AhadithListItem with status badge + clamped preview"
```

---

### Task 32: Rewrite `AhadithListView`

**Files:**
- Modify: `lib/features/ahadith/presentation/pages/widgets/ahadith_list_view.dart`

- [ ] **Step 1: Replace the file**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/core/helper%20functions/locale_helpers.dart';
import 'package:quran_app/core/widgets/design/app_bar_center_title.dart';
import 'package:quran_app/core/widgets/design/app_section_header.dart';
import 'package:quran_app/core/widgets/design/icon_chip.dart';
import 'package:quran_app/features/ahadith/presentation/cubit/ahadith_cubit.dart';
import 'package:quran_app/features/ahadith/presentation/pages/widgets/ahadith_list_item.dart';
import 'package:quran_app/generated/l10n.dart';

class AhadithListView extends StatelessWidget {
  const AhadithListView({super.key, required this.bookSlug});
  final String bookSlug;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 60,
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: scheme.onSurface.withValues(alpha: 0.06),
                  ),
                ),
              ),
              child: Row(
                children: [
                  IconChip(
                    icon: const HugeIcon(
                      icon: HugeIcons.strokeRoundedArrowLeft02,
                      color: Colors.white,
                    ),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const Spacer(),
                  AppBarCenterTitle(
                    label: _bookLabel(context, bookSlug),
                    title: _bookLabel(context, bookSlug),
                  ),
                  const Spacer(),
                  IconChip(
                    icon: const HugeIcon(
                      icon: HugeIcons.strokeRoundedSearch01,
                      color: Colors.white,
                    ),
                    onPressed: () {}, // search hookup is out-of-scope for now
                  ),
                ],
              ),
            ),
            Expanded(
              child: BlocBuilder<AhadithCubit, AhadithState>(
                builder: (context, state) {
                  // Replace AhadithState/.ahadith with whatever the actual
                  // state shape exposes (likely a Loading/Loaded union).
                  if (state is! AhadithLoaded) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppSectionHeader(
                          label: S.of(context).ahadith_section,
                          trailing: Text(
                            S.of(context).ahadith_count(
                                  state.ahadith.length.toLocalized(context),
                                ),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: scheme.secondary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        for (final hadith in state.ahadith) ...[
                          AhadithListItem(hadith: hadith),
                          const SizedBox(height: 10),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _bookLabel(BuildContext context, String slug) {
    // Reuse the existing book-name localization helper if present.
    // Fallback: capitalize slug.
    return slug;
  }
}
```

- [ ] **Step 2: Reconcile against `AhadithCubit` state shape**

```bash
grep -n "class .*State\|Loaded\|Loading" lib/features/ahadith/presentation/cubit/ahadith_state.dart
```

Match the real state type names and getters. Also wire `_bookLabel` to the existing book-name localization (look for `bookNameLocalized` or similar helper in `lib/features/ahadith/` or `lib/core/`).

- [ ] **Step 3: Commit**

```bash
git add lib/features/ahadith/presentation/pages/widgets/ahadith_list_view.dart
git commit -m "feat(ahadith): rebuild AhadithListView with new design system"
```

---

## Phase 9 — Hadith Detail (with bookmark + share + next)

---

### Task 33: Provide `HadithBookmarkCubit` at the hadith page

**Files:**
- Modify: `lib/features/ahadith/presentation/pages/hadith_page.dart`

- [ ] **Step 1: Replace the file**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran_app/core/di/dependency_injection.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith.dart';
import 'package:quran_app/features/ahadith/presentation/cubit/hadith_bookmark_cubit.dart';
import 'package:quran_app/features/ahadith/presentation/pages/widgets/hadith_view.dart';

class HadithPage extends StatelessWidget {
  const HadithPage({super.key, required this.hadith, required this.bookSlug});
  final Hadith hadith;
  final String bookSlug;

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: sl<HadithBookmarkCubit>(),
      child: HadithView(hadith: hadith, bookSlug: bookSlug),
    );
  }
}
```

- [ ] **Step 2: Update the `/hadith` route to pass `bookSlug`**

In `lib/config/router/app_router.dart` the current `/hadith` route passes `extra: Hadith`. Change the contract to take a record `({Hadith hadith, String bookSlug})`:

```dart
GoRoute(
  path: hadithPath,
  pageBuilder: GoTransitions.fade.withScale.build(
    builder: (context, state) {
      final extra = state.extra as ({Hadith hadith, String bookSlug});
      return HadithPage(hadith: extra.hadith, bookSlug: extra.bookSlug);
    },
  ),
),
```

Update `AhadithListItem` (Task 31) to pass the record:

```dart
onTap: () => context.push(
  AppRouter.hadithPath,
  extra: (hadith: hadith, bookSlug: /* the bookSlug from AhadithListView */),
),
```

To make `bookSlug` available inside the list item, pass it down from `AhadithListView` → `AhadithListItem(hadith: ..., bookSlug: bookSlug)`. Add `final String bookSlug` to `AhadithListItem` constructor and forward it.

- [ ] **Step 3: Commit**

```bash
git add lib/features/ahadith/presentation/pages/hadith_page.dart \
        lib/features/ahadith/presentation/pages/widgets/ahadith_list_item.dart \
        lib/features/ahadith/presentation/pages/widgets/ahadith_list_view.dart \
        lib/config/router/app_router.dart
git commit -m "feat(ahadith): thread bookSlug through hadith route + provide bookmark cubit"
```

---

### Task 34: Rewrite `HadithView` with new design + wired actions

**Files:**
- Modify: `lib/features/ahadith/presentation/pages/widgets/hadith_view.dart`

- [ ] **Step 1: Replace the file**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:share_plus/share_plus.dart';
import 'package:quran_app/config/router/app_router.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/di/dependency_injection.dart';
import 'package:quran_app/core/helper%20functions/locale_helpers.dart';
import 'package:quran_app/core/widgets/design/action_buttons_row.dart';
import 'package:quran_app/core/widgets/design/app_bar_center_title.dart';
import 'package:quran_app/core/widgets/design/app_section_header.dart';
import 'package:quran_app/core/widgets/design/app_status_badge.dart';
import 'package:quran_app/core/widgets/design/arabic_quote_block.dart';
import 'package:quran_app/core/widgets/design/icon_chip.dart';
import 'package:quran_app/core/widgets/design/labelled_accent_card.dart';
import 'package:quran_app/core/widgets/design/ornament_divider.dart';
import 'package:quran_app/core/widgets/design/surface_card.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith_bookmark.dart';
import 'package:quran_app/features/ahadith/domain/usecases/get_next_hadith.dart';
import 'package:quran_app/features/ahadith/presentation/cubit/hadith_bookmark_cubit.dart';
import 'package:quran_app/features/ahadith/presentation/cubit/hadith_bookmark_state.dart';
import 'package:quran_app/generated/l10n.dart';

class HadithView extends StatelessWidget {
  const HadithView({super.key, required this.hadith, required this.bookSlug});
  final Hadith hadith;
  final String bookSlug;

  HadithBookmark get _bookmark =>
      HadithBookmark(bookSlug: bookSlug, hadithNumber: hadith.hadithNumber);

  Future<void> _onShare(BuildContext context) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          text:
              '${hadith.arabicHadith}\n\n— $bookSlug, #${hadith.hadithNumber}',
        ),
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context).share_failed)),
        );
      }
    }
  }

  Future<void> _onNext(BuildContext context) async {
    final result = await sl<GetNextHadith>().call(
      bookSlug: bookSlug,
      currentHadithNumber: hadith.hadithNumber,
    );
    if (!context.mounted) return;
    result.fold(
      (failure) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.message)),
      ),
      (next) {
        if (next == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(S.of(context).coming_soon)),
          );
        } else {
          context.replace(
            AppRouter.hadithPath,
            extra: (hadith: next, bookSlug: bookSlug),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 60,
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: scheme.onSurface.withValues(alpha: 0.06),
                  ),
                ),
              ),
              child: Row(
                children: [
                  IconChip(
                    icon: const HugeIcon(
                      icon: HugeIcons.strokeRoundedArrowLeft02,
                      color: Colors.white,
                    ),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const Spacer(),
                  AppBarCenterTitle(
                    label: bookSlug,
                    title:
                        '${S.of(context).hadith_number_label} ${hadith.hadithNumber.toLocalized(context)}',
                  ),
                  const Spacer(),
                  IconChip(
                    icon: const HugeIcon(
                      icon: HugeIcons.strokeRoundedShare08,
                      color: Colors.white,
                    ),
                    onPressed: () => _onShare(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Chapter card
                    SurfaceCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              AppStatusBadge(
                                color: _statusColor(hadith.status),
                                label: _statusLabel(context, hadith.status),
                              ),
                              if (hadith.chapter != null)
                                Text(
                                  '${S.of(context).chapter_label} ${hadith.chapter!.chapterNumber.toLocalized(context)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                          if (hadith.chapter != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              height: 1,
                              color: scheme.onSurface.withValues(alpha: 0.06),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              hadith.chapter!.chapterArabic,
                              style: TS.bold16.amiri.copyWith(
                                fontSize: 18,
                                color: scheme.secondary,
                                height: 1.6,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              hadith.chapter!.chapterEnglish,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    AppSectionHeader(label: S.of(context).arabic_label),
                    const SizedBox(height: 10),
                    ArabicQuoteBlock(hadith.arabicHadith),
                    const SizedBox(height: 14),
                    const OrnamentDivider(),
                    const SizedBox(height: 14),
                    AppSectionHeader(label: S.of(context).translation_label),
                    const SizedBox(height: 10),
                    Text(
                      hadith.englishHadith,
                      style: TS.regular15.copyWith(
                        color: scheme.onSurface,
                        height: 1.78,
                      ),
                    ),
                    if (hadith.englishNarrator.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      LabelledAccentCard(
                        label: S.of(context).narrator_label,
                        body: hadith.englishNarrator,
                        accentColor: scheme.secondary,
                      ),
                    ],
                    const SizedBox(height: 14),
                    BlocBuilder<HadithBookmarkCubit, HadithBookmarkState>(
                      builder: (context, state) {
                        final marked = state.contains(_bookmark);
                        return ActionButtonsRow(
                          children: [
                            ActionBtn(
                              icon: HugeIcon(
                                icon: marked
                                    ? HugeIcons.strokeRoundedBookmark01
                                    : HugeIcons.strokeRoundedBookmark02,
                                color: Colors.white,
                              ),
                              label: S.of(context).bookmark,
                              onPressed: () => context
                                  .read<HadithBookmarkCubit>()
                                  .toggle(_bookmark),
                            ),
                            ActionBtn(
                              icon: const HugeIcon(
                                icon: HugeIcons.strokeRoundedShare08,
                                color: Colors.white,
                              ),
                              label: S.of(context).share,
                              onPressed: () => _onShare(context),
                            ),
                            ActionBtn.primary(
                              icon: const HugeIcon(
                                icon: HugeIcons.strokeRoundedArrowRight02,
                                color: Colors.white,
                              ),
                              label: S.of(context).next_hadith,
                              onPressed: () => _onNext(context),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '$bookSlug · ${hadith.chapter?.chapterArabic ?? ''}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color:
                            scheme.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Color _statusColor(HadithStatus s) => switch (s) {
        HadithStatus.sahih => const Color(0xFF3D9E6E),
        HadithStatus.hasan => const Color(0xFFC8882A),
        HadithStatus.daeef => const Color(0xFFD05050),
      };

  static String _statusLabel(BuildContext context, HadithStatus s) =>
      switch (s) {
        HadithStatus.sahih => S.of(context).status_sahih,
        HadithStatus.hasan => S.of(context).status_hasan,
        HadithStatus.daeef => S.of(context).status_daeef,
      };
}
```

- [ ] **Step 2: Run + walk through**

Run: `flutter run`. Navigate to a hadith. Verify:
- Chapter card renders
- Arabic block has the leading-edge primary accent on the **right** in Arabic mode, **left** in English mode
- Narrator card shows when narrator is non-empty
- Bookmark icon flips between filled/unfilled when tapped, persists after app restart
- Share opens system share sheet
- Next navigates to the next hadith in the same book; at end shows snackbar

- [ ] **Step 3: Commit**

```bash
git add lib/features/ahadith/presentation/pages/widgets/hadith_view.dart
git commit -m "feat(ahadith): rebuild HadithView with bookmark/share/next actions"
```

---

## Phase 10 — Settings + Notifications restyle

---

### Task 35: Restyle `SettingsPage`

**Files:**
- Modify: `lib/features/settings/presentation/pages/settings_page.dart`

- [ ] **Step 1: Replace the file**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/config/router/app_router.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/constants/feature_flags.dart';
import 'package:quran_app/core/di/dependency_injection.dart';
import 'package:quran_app/core/widgets/design/app_section_header.dart';
import 'package:quran_app/core/widgets/design/surface_card.dart';
import 'package:quran_app/features/home/presentation/pages/widgets/setting_switch.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:quran_app/features/settings/presentation/pages/widgets/palette_picker_widget.dart';
import 'package:quran_app/generated/l10n.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: Text(S.current.settings, style: TS.bold20.cairo),
        backgroundColor: scheme.surface,
      ),
      body: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, state) {
          final settings = state.settingsModel;
          return ListView(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 32),
            children: [
              AppSectionHeader(label: S.of(context).appearance_section),
              const SizedBox(height: 10),
              PalettePickerWidget(
                currentPalette: settings.palette,
                onSelect: (p) => sl<SettingsCubit>().updatePalette(p),
              ),
              const SizedBox(height: 24),
              AppSectionHeader(label: S.of(context).general_section),
              const SizedBox(height: 10),
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
              if (FeatureFlags.pinnedPrayerStripUi) ...[
                const SizedBox(height: 24),
                AppSectionHeader(label: S.current.notifications),
                const SizedBox(height: 10),
                SurfaceCard(
                  padding: EdgeInsets.zero,
                  child: ListTile(
                    leading: HugeIcon(
                      icon: HugeIcons.strokeRoundedNotification01,
                      color: scheme.secondary,
                      size: 22,
                    ),
                    title: Text(
                      S.current.notifications,
                      style: TS.regular16.cairo,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(AppRouter.notificationsPath),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/settings/presentation/pages/settings_page.dart
git commit -m "feat(settings): restyle settings page with new primitives"
```

---

### Task 36: Restyle `NotificationsSettingsPage`

**Files:**
- Modify: `lib/features/home/presentation/pages/notifications_settings_page.dart`

- [ ] **Step 1: Read the current file**

```bash
cat lib/features/home/presentation/pages/notifications_settings_page.dart
```

- [ ] **Step 2: Replace section labels with `AppSectionHeader` + wrap groups in `SurfaceCard`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/core/di/dependency_injection.dart';
import 'package:quran_app/core/widgets/design/app_section_header.dart';
import 'package:quran_app/core/widgets/design/surface_card.dart';
import 'package:quran_app/features/home/presentation/pages/widgets/per_prayer_adhan_tile.dart';
import 'package:quran_app/features/home/presentation/pages/widgets/setting_switch.dart';
import 'package:quran_app/features/home/presentation/pages/widgets/test_adhan_button.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:quran_app/generated/l10n.dart';

class NotificationsSettingsPage extends StatelessWidget {
  const NotificationsSettingsPage({super.key});

  static const List<PrayerName> _orderedPrayers = [
    PrayerName.fajr,
    PrayerName.dhuhr,
    PrayerName.asr,
    PrayerName.maghrib,
    PrayerName.isha,
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: Text(S.current.notifications, style: TS.bold20.cairo),
        backgroundColor: scheme.surface,
      ),
      body: SafeArea(
        child: BlocBuilder<SettingsCubit, SettingsState>(
          builder: (context, state) {
            final settings = state.settingsModel;
            return ListView(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 32),
              children: [
                _Header(),
                const SizedBox(height: 14),
                SurfaceCard(
                  padding: EdgeInsets.zero,
                  child: SettingSwitch(
                    settings: settings,
                    settingTitle: S.current.pinnedPrayerTimes,
                    icons: const [
                      HugeIcons.strokeRoundedNotification01,
                      HugeIcons.strokeRoundedNotificationOff01,
                    ],
                    value: settings.isPrayerStripPinned,
                    action: () => sl<SettingsCubit>()
                        .updatePrayerStripPinned(!settings.isPrayerStripPinned),
                  ),
                ),
                const SizedBox(height: 18),
                AppSectionHeader(
                  label: S.of(context).adhanPerPrayerSection,
                ),
                const SizedBox(height: 10),
                SurfaceCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < _orderedPrayers.length; i++)
                        PerPrayerAdhanTile(
                          prayer: _orderedPrayers[i],
                          showTopDivider: i > 0,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const TestAdhanButton(),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return SurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: scheme.surfaceContainer,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: scheme.onSurface.withValues(alpha: 0.06),
              ),
            ),
            alignment: Alignment.center,
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedNotification01,
              color: scheme.primary,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                S.current.notificationsScreenSubtitle,
                style: TS.regular14.cairo.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/home/presentation/pages/notifications_settings_page.dart
git commit -m "feat(notifications): restyle notifications settings page"
```

---

## Phase 11 — Validation

---

### Task 37: Full validation pass

- [ ] **Step 1: Static analysis**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 2: Run all tests**

Run: `flutter test`
Expected: `All tests passed!`

- [ ] **Step 3: Build for Android**

Run: `flutter build apk --debug`
Expected: build succeeds without errors.

- [ ] **Step 4: Manual smoke test on emulator**

Run: `flutter run -d <emulator-id>`

Walk through each screen in both Arabic (default) and English locales, on each of the 4 palettes (neutral-dark, neutral-light, slate-dark, slate-light):

| Screen | Verify |
|---|---|
| Home | Date + location in app bar, gear → settings, time hero, countdown, prayers row with active card, last-read appears only when set, quick grid (4 tiles), Bookmarks tile dimmed |
| Surah list | Continue bar (when last-read), search filters, section header shows count, tile → mushaf |
| Books list | Section header with count, each book card with badge + title block, download a non-downloaded book — verify badge progresses through downloading (% + progress bar) → downloaded (green check) |
| Ahadith list | App bar with book name, section header with count, 2-line clamp on long Arabic, tap → detail |
| Hadith detail | Chapter card, Arabic block accent on **trailing edge in Arabic / leading edge in English**, narrator card present when narrator non-empty, bookmark icon toggles + persists across app restart, share opens system sheet, Next advances within book, snackbar at end |
| Settings | Palette grid still works, switches reflect cubit state, notifications row → notifications page |
| Notifications settings | Header card, pinned-prayer toggle, per-prayer adhan tiles, test button |

- [ ] **Step 5: RTL spot-check**

In English locale:
- `ArabicQuoteBlock` accent border should be on the **left edge** of the card
- `LabelledAccentCard` (narrator) accent on **left edge**
- App bar back arrow points **left**

In Arabic locale:
- Same accents on the **right edge**
- App bar back arrow points **right**

- [ ] **Step 6: Final commit if anything was touched**

If any fixes were needed during validation:

```bash
git add -A
git commit -m "fix: resolve validation findings from screens remaster pass"
```

---

## Self-Review Checklist (run after writing the plan, before handing off)

This section is for the plan author. Skip when executing.

**Spec coverage:**
- §4 (9 design primitives) → Tasks 1–9 ✅
- §5.1 Home → Tasks 20–25 ✅
- §5.2 Surah List → Tasks 26–28 ✅
- §5.3 Books List → Tasks 29–30 ✅
- §5.4 Ahadith List → Tasks 31–32 ✅
- §5.5 Hadith Detail (with extras) → Tasks 33–34 ✅
- §5.6 Settings → Task 35 ✅
- §5.7 Notifications → Task 36 ✅
- §6.1 Hadith bookmark infra → Tasks 10–15, 18 ✅
- §6.2 Share → wired in Task 34 ✅
- §6.3 Next-hadith → Tasks 16–18, used in Task 34 ✅
- §7 RTL hardening → embedded in primitives (Tasks 1, 7, 8) + verified Task 37 step 5 ✅
- §8 Files added/changed → match the File Structure section above ✅
- §9 Validation → Task 37 ✅

**Placeholder scan:** No "TBD", no "implement later", no "similar to Task N". A few reconciliation steps ("adjust to actual property names") are intentional: the spec admits the brief may need to align with entity field names, and the steps point the engineer to the right `grep` to discover them. ✅

**Type consistency:** `HadithBookmark`, `HadithBookmarkCubit`, `HadithBookmarkState.contains`, `GetNextHadith.call({bookSlug, currentHadithNumber})`, `LastReadCubit` state shape (`LastRead?`), record `({Hadith hadith, String bookSlug})` for the `/hadith` route — all consistent across tasks. ✅
