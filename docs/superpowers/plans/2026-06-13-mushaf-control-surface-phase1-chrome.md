# Mushaf Control Surface — Phase 1 (Chrome) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the dual control surfaces (floating dock + mini-player that both show at once) with one coherent surface — a bottom **browse bar** mutually exclusive with the existing player, plus a slim **top bar** (back · surah · page-jump) — and remove the orientation-lock rotate button.

**Architecture:** New pure-presentational widgets `MushafTopBar`, `MushafBrowseBar`, and `PageJumpSheet` take values + callbacks as parameters; `mushaf_page.dart` (the existing `StatefulWidget` that already holds the cubits and page/scroll controllers) wires them. The browse bar is shown only when `chromeVisible && !playerVisible`, where `playerVisible = highlightedAyah != null || isOverlayPinned` — exactly the `AyahPlaybackOverlay` visibility predicate — so the two are never on screen together. The rotate button and its `SystemChrome` orientation lock are deleted; landscape→scroll stays automatic via the existing `_effectiveMode`.

**Tech Stack:** Flutter, `flutter_bloc` (Cubit), `go_router`, `quran` package, `flutter_test`. FVM-pinned Flutter 3.38.1 — run tests with `fvm flutter test`.

> **Scope:** This is Phase 1 of Workstream A. Phase 2 (reading-mode `AppSegmentedSelector` + brightness live-preview) and Phase 3 (page bookmarks + ribbon + description + Bookmarks "Pages" section) are separate plans. In Phase 1 the browse bar's **Save** button keeps the *existing* ayah-bookmark-first-of-page behavior (lifted from the dock) so nothing regresses; Phase 3 swaps it for true page bookmarks.

> **CRITICAL test caveat (project memory):** NEVER run the full `fvm flutter test` — `test/tools/generate_mushaf_assets_test.dart` rewrites `assets/mushaf/**`. Always scope to `test/features/...`. Never `git add -A`; stage explicit paths.

---

## File structure

| File | Responsibility | Action |
|---|---|---|
| `lib/features/surah/presentation/pages/mushaf/widgets/page_jump_sheet.dart` | Modal sheet: enter a page (1–604), returns the int | Create |
| `lib/features/surah/presentation/pages/mushaf/widgets/mushaf_top_bar.dart` | Presentational top bar: back · surah · page→jump | Create |
| `lib/features/surah/presentation/pages/mushaf/widgets/mushaf_browse_bar.dart` | Presentational bottom idle bar: settings · play · save | Create |
| `lib/features/surah/presentation/pages/mushaf/mushaf_page.dart` | Wire top/browse bars; play/jump/back; drop rotate lock | Modify |
| `lib/features/surah/presentation/pages/mushaf/widgets/mushaf_action_dock.dart` | — | Delete |
| `lib/l10n/intl_en.arb`, `intl_ar.arb` | `goToPage` string | Modify |
| Tests for the three new widgets; delete the dock test | — | Create/Delete |

---

### Task 1: `PageJumpSheet` (enter a page number)

**Files:**
- Create: `lib/features/surah/presentation/pages/mushaf/widgets/page_jump_sheet.dart`
- Test: `test/features/surah/presentation/pages/mushaf/widgets/page_jump_sheet_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/widgets/page_jump_sheet.dart';

void main() {
  Future<int?> openAndReturn(WidgetTester tester, String input) async {
    int? result;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await PageJumpSheet.show(context);
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), input);
    await tester.tap(find.byKey(const ValueKey('page-jump-go')));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('returns the entered page number', (tester) async {
    expect(await openAndReturn(tester, '42'), 42);
  });

  testWidgets('clamps above 604 to 604', (tester) async {
    expect(await openAndReturn(tester, '999'), 604);
  });

  testWidgets('ignores non-numeric / empty input (returns null)', (tester) async {
    expect(await openAndReturn(tester, 'abc'), isNull);
  });
}
```

- [ ] **Step 2: Run the test, verify it fails**

Run: `fvm flutter test test/features/surah/presentation/pages/mushaf/widgets/page_jump_sheet_test.dart`
Expected: FAIL — file/class missing.

- [ ] **Step 3: Implement the sheet**

`lib/features/surah/presentation/pages/mushaf/widgets/page_jump_sheet.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quran_app/generated/l10n.dart';

/// Modal sheet to jump to a Mushaf page. Resolves with the chosen page (1–604)
/// or null if dismissed / input was invalid.
class PageJumpSheet extends StatefulWidget {
  const PageJumpSheet({super.key});

  static Future<int?> show(BuildContext context) {
    return showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const PageJumpSheet(),
    );
  }

  @override
  State<PageJumpSheet> createState() => _PageJumpSheetState();
}

class _PageJumpSheetState extends State<PageJumpSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final raw = _controller.text.trim();
    final n = int.tryParse(raw);
    if (n == null) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pop(n.clamp(1, 604));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.goToPage, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                hintText: '1 – 604',
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton(
                key: const ValueKey('page-jump-go'),
                onPressed: _submit,
                child: Text(s.goToPage),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Add the l10n key** (so `s.goToPage` exists)

In `lib/l10n/intl_en.arb` add (after the `"bookmark"` entry — keep JSON valid):
```json
  "goToPage": "Go to page",
```
In `lib/l10n/intl_ar.arb` add the matching key:
```json
  "goToPage": "اذهب إلى صفحة",
```
Then regenerate l10n (the `flutter_intl` IDE plugin does this on save; to force it):
Run: `fvm flutter gen-l10n` *(if the project uses gen-l10n)* — otherwise open/save the ARB in the IDE. Verify `S.current.goToPage` resolves by re-running the test in Step 5.

- [ ] **Step 5: Run the test, verify it passes**

Run: `fvm flutter test test/features/surah/presentation/pages/mushaf/widgets/page_jump_sheet_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/surah/presentation/pages/mushaf/widgets/page_jump_sheet.dart test/features/surah/presentation/pages/mushaf/widgets/page_jump_sheet_test.dart lib/l10n/intl_en.arb lib/l10n/intl_ar.arb lib/generated/
git commit -m "feat(mushaf): page-jump sheet

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: `MushafTopBar` (presentational)

**Files:**
- Create: `lib/features/surah/presentation/pages/mushaf/widgets/mushaf_top_bar.dart`
- Test: `test/features/surah/presentation/pages/mushaf/widgets/mushaf_top_bar_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/widgets/mushaf_top_bar.dart';

void main() {
  Widget host({required VoidCallback onBack, required VoidCallback onJump}) =>
      MaterialApp(
        home: Scaffold(
          body: MushafTopBar(
            surahName: 'Al-Baqarah',
            pageNumber: 3,
            localeCode: 'en',
            onBack: onBack,
            onJump: onJump,
          ),
        ),
      );

  testWidgets('shows surah name and page number', (tester) async {
    await tester.pumpWidget(host(onBack: () {}, onJump: () {}));
    expect(find.text('Al-Baqarah'), findsOneWidget);
    expect(find.textContaining('3'), findsWidgets);
  });

  testWidgets('back button fires onBack', (tester) async {
    var backs = 0;
    await tester.pumpWidget(host(onBack: () => backs++, onJump: () {}));
    await tester.tap(find.byKey(const ValueKey('mushaf-top-back')));
    expect(backs, 1);
  });

  testWidgets('tapping the page area fires onJump', (tester) async {
    var jumps = 0;
    await tester.pumpWidget(host(onBack: () {}, onJump: () => jumps++));
    await tester.tap(find.byKey(const ValueKey('mushaf-top-page')));
    expect(jumps, 1);
  });
}
```

- [ ] **Step 2: Run the test, verify it fails**

Run: `fvm flutter test test/features/surah/presentation/pages/mushaf/widgets/mushaf_top_bar_test.dart`
Expected: FAIL — file/class missing.

- [ ] **Step 3: Implement the widget**

`lib/features/surah/presentation/pages/mushaf/widgets/mushaf_top_bar.dart`:
```dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:quran_app/core/helper%20functions/numeral_helpers.dart';

/// Slim frosted top bar shown with the Mushaf chrome: back, current surah,
/// and a tappable page indicator that opens the page-jump sheet. Pure
/// presentational — the parent supplies values + callbacks.
class MushafTopBar extends StatelessWidget {
  const MushafTopBar({
    super.key,
    required this.surahName,
    required this.pageNumber,
    required this.localeCode,
    required this.onBack,
    required this.onJump,
  });

  final String surahName;
  final int pageNumber;
  final String localeCode;
  final VoidCallback onBack;
  final VoidCallback onJump;

  @override
  Widget build(BuildContext context) {
    final pageStr = pageNumber.toString().toIndicNumerals(localeCode);
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 48,
          padding: const EdgeInsetsDirectional.only(start: 4, end: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              IconButton(
                key: const ValueKey('mushaf-top-back'),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: onBack,
              ),
              Expanded(
                child: Text(
                  surahName,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
              GestureDetector(
                key: const ValueKey('mushaf-top-page'),
                onTap: onJump,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.menu_book_outlined,
                          color: Colors.white, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        pageStr,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
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

- [ ] **Step 4: Run the test, verify it passes**

Run: `fvm flutter test test/features/surah/presentation/pages/mushaf/widgets/mushaf_top_bar_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/surah/presentation/pages/mushaf/widgets/mushaf_top_bar.dart test/features/surah/presentation/pages/mushaf/widgets/mushaf_top_bar_test.dart
git commit -m "feat(mushaf): slim top bar (back, surah, page-jump)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: `MushafBrowseBar` (presentational)

**Files:**
- Create: `lib/features/surah/presentation/pages/mushaf/widgets/mushaf_browse_bar.dart`
- Test: `test/features/surah/presentation/pages/mushaf/widgets/mushaf_browse_bar_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/widgets/mushaf_browse_bar.dart';

void main() {
  Widget host({
    required bool isSaved,
    required VoidCallback onSettings,
    required VoidCallback onPlay,
    required VoidCallback onToggleSave,
  }) =>
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: MushafBrowseBar(
              isSaved: isSaved,
              onSettings: onSettings,
              onPlay: onPlay,
              onToggleSave: onToggleSave,
            ),
          ),
        ),
      );

  testWidgets('shows settings, play, save buttons (no rotate)', (tester) async {
    await tester.pumpWidget(host(
      isSaved: false, onSettings: () {}, onPlay: () {}, onToggleSave: () {}));
    expect(find.byKey(const ValueKey('browse-settings')), findsOneWidget);
    expect(find.byKey(const ValueKey('browse-play')), findsOneWidget);
    expect(find.byKey(const ValueKey('browse-save')), findsOneWidget);
    expect(find.byKey(const ValueKey('browse-rotate')), findsNothing);
  });

  testWidgets('each button fires its callback', (tester) async {
    var settings = 0, play = 0, save = 0;
    await tester.pumpWidget(host(
      isSaved: false,
      onSettings: () => settings++,
      onPlay: () => play++,
      onToggleSave: () => save++,
    ));
    await tester.tap(find.byKey(const ValueKey('browse-settings')));
    await tester.tap(find.byKey(const ValueKey('browse-play')));
    await tester.tap(find.byKey(const ValueKey('browse-save')));
    expect([settings, play, save], [1, 1, 1]);
  });

  testWidgets('save icon reflects isSaved', (tester) async {
    await tester.pumpWidget(host(
      isSaved: true, onSettings: () {}, onPlay: () {}, onToggleSave: () {}));
    expect(find.byIcon(Icons.bookmark), findsOneWidget);
    expect(find.byIcon(Icons.bookmark_outline), findsNothing);
  });
}
```

- [ ] **Step 2: Run the test, verify it fails**

Run: `fvm flutter test test/features/surah/presentation/pages/mushaf/widgets/mushaf_browse_bar_test.dart`
Expected: FAIL — file/class missing.

- [ ] **Step 3: Implement the widget** (frosted style lifted from the old dock; rotate removed)

`lib/features/surah/presentation/pages/mushaf/widgets/mushaf_browse_bar.dart`:
```dart
import 'dart:ui';
import 'package:flutter/material.dart';

/// Frosted idle control bar shown when chrome is visible and no ayah is
/// selected / playing. Pure presentational — parent supplies callbacks + state.
class MushafBrowseBar extends StatelessWidget {
  const MushafBrowseBar({
    super.key,
    required this.isSaved,
    required this.onSettings,
    required this.onPlay,
    required this.onToggleSave,
  });

  final bool isSaved;
  final VoidCallback onSettings;
  final VoidCallback onPlay;
  final VoidCallback onToggleSave;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(26),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _CircleButton(
                keyValue: 'browse-settings',
                icon: Icons.tune,
                onTap: onSettings,
              ),
              const SizedBox(width: 10),
              _CircleButton(
                keyValue: 'browse-play',
                icon: Icons.play_arrow,
                primary: true,
                color: scheme.primary,
                onTap: onPlay,
              ),
              const SizedBox(width: 10),
              _CircleButton(
                keyValue: 'browse-save',
                icon: isSaved ? Icons.bookmark : Icons.bookmark_outline,
                onTap: onToggleSave,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.keyValue,
    required this.icon,
    required this.onTap,
    this.primary = false,
    this.color,
  });

  final String keyValue;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final size = primary ? 46.0 : 36.0;
    return GestureDetector(
      key: ValueKey(keyValue),
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: primary
              ? (color ?? Theme.of(context).colorScheme.primary)
              : Colors.white.withValues(alpha: 0.12),
        ),
        child: Icon(icon, color: Colors.white, size: primary ? 24 : 20),
      ),
    );
  }
}
```

- [ ] **Step 4: Run the test, verify it passes**

Run: `fvm flutter test test/features/surah/presentation/pages/mushaf/widgets/mushaf_browse_bar_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/surah/presentation/pages/mushaf/widgets/mushaf_browse_bar.dart test/features/surah/presentation/pages/mushaf/widgets/mushaf_browse_bar_test.dart
git commit -m "feat(mushaf): browse bar (settings, play, save) without rotate

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: Wire top + browse bars into `mushaf_page.dart`; remove the rotate lock

**Files:**
- Modify: `lib/features/surah/presentation/pages/mushaf/mushaf_page.dart`

- [ ] **Step 1: Update imports**

In `mushaf_page.dart`, replace the import of `widgets/mushaf_action_dock.dart` (line 17) with the new widgets, and add the playback/bookmark/quran imports needed for the moved play logic. The import block additions:
```dart
import 'package:quran/quran.dart' as quran;
import '../../../../quran_playback/domain/entities/ayah_identifier.dart';
import '../../../../bookmarks/presentation/cubit/bookmark_cubit.dart';
import '../../../../bookmarks/presentation/cubit/bookmark_state.dart';
import '../../utils/printed_chrome_resolver.dart';
import 'widgets/mushaf_browse_bar.dart';
import 'widgets/mushaf_top_bar.dart';
import 'widgets/page_jump_sheet.dart';
import 'widgets/reading_settings_sheet.dart';
```
(Remove the `widgets/mushaf_action_dock.dart` import. `ayah_playback_overlay.dart`, `mushaf_page_view.dart`, `settings_cubit.dart` imports stay.)

- [ ] **Step 2: Remove the orientation-lock reset in `dispose`**

Delete these lines (currently `mushaf_page.dart:117–119`):
```dart
    // Release any orientation lock set by the rotate button so the rest of
    // the app is free to follow the sensor again.
    SystemChrome.setPreferredOrientations([]);
```
(The `import 'package:flutter/services.dart';` may now be unused — remove it if `flutter analyze` flags it.)

- [ ] **Step 3: Add the play / jump / save helper methods**

Add these methods to `_MushafPageState` (e.g. just below `_effectiveMode`):
```dart
  // Plays the current page from its first ayah to the end of that surah,
  // selecting the first ayah so the player surfaces. Lifted from the old dock.
  void _onPlayPage() {
    var firstAyah =
        sl<QuranPageService>().getFirstAyahOfPage(_mushafCubit.state.currentPage);
    if (firstAyah == null) {
      _mushafCubit.pinOverlay();
      return;
    }
    if (firstAyah.ayah == 1 && firstAyah.surah != 1 && firstAyah.surah != 9) {
      firstAyah = AyahIdentifier(surah: firstAyah.surah, ayah: 0);
    }
    _mushafCubit.toggleHighlight(firstAyah);
    final surah = firstAyah.surah;
    final start = firstAyah.ayah == 0
        ? AyahIdentifier(surah: surah, ayah: 1)
        : firstAyah;
    _playbackCubit.playRange(
      start: start,
      end: AyahIdentifier(surah: surah, ayah: quran.getVerseCount(surah)),
    );
  }

  Future<void> _onJumpToPage(BuildContext context) async {
    final page = await PageJumpSheet.show(context);
    if (page == null || !mounted) return;
    final mode = _effectiveMode(context);
    if (mode == MushafReadingMode.page) {
      if (_pageController.hasClients) _pageController.jumpToPage(page - 1);
    } else {
      if (_scrollController.hasClients && _scrollPageHeight != 0) {
        _scrollController.jumpTo(_scrollOffsetFor(page));
      }
    }
    _mushafCubit.setPage(page);
  }

  // The page's first ayah, used by the (Phase-1) carried-over ayah bookmark.
  AyahIdentifier? _savableAyah() =>
      sl<QuranPageService>().getFirstAyahOfPage(_mushafCubit.state.currentPage);
```

- [ ] **Step 4: Replace the action-dock Stack child with top bar + browse bar**

In `build`, replace the entire `BlocBuilder<MushafCubit, MushafState>` child that renders the `MushafActionDock` (currently `mushaf_page.dart:236–272`) **and** keep `const AyahPlaybackOverlay()` after it. The new Stack children (top bar + browse bar + overlay):

```dart
              // Top bar — visible whenever chrome is visible (even during
              // playback, so back / page-jump stay reachable).
              BlocBuilder<MushafCubit, MushafState>(
                buildWhen: (a, b) =>
                    a.chromeVisible != b.chromeVisible ||
                    a.currentPage != b.currentPage,
                builder: (context, state) {
                  final isArabic = context
                      .read<SettingsCubit>()
                      .state
                      .settingsModel
                      .isArabic;
                  final chrome = resolvePrintedChrome(state.currentPage);
                  final surahName = isArabic
                      ? quran.getSurahNameArabic(chrome.surahNumber)
                      : quran.getSurahName(chrome.surahNumber);
                  return SafeArea(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: AnimatedSlide(
                        offset: state.chromeVisible
                            ? Offset.zero
                            : const Offset(0, -2),
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        child: AnimatedOpacity(
                          opacity: state.chromeVisible ? 1 : 0,
                          duration: const Duration(milliseconds: 180),
                          child: IgnorePointer(
                            ignoring: !state.chromeVisible,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                              child: MushafTopBar(
                                surahName: surahName,
                                pageNumber: state.currentPage,
                                localeCode: isArabic ? 'ar' : 'en',
                                onBack: () => Navigator.of(context).maybePop(),
                                onJump: () => _onJumpToPage(context),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),

              // Browse bar — only when chrome is visible AND the player is not.
              BlocBuilder<MushafCubit, MushafState>(
                buildWhen: (a, b) =>
                    a.chromeVisible != b.chromeVisible ||
                    a.highlightedAyah != b.highlightedAyah ||
                    a.isOverlayPinned != b.isOverlayPinned ||
                    a.currentPage != b.currentPage,
                builder: (context, state) {
                  final playerVisible =
                      state.highlightedAyah != null || state.isOverlayPinned;
                  final visible = state.chromeVisible && !playerVisible;
                  final savable = _savableAyah();
                  return SafeArea(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: AnimatedSlide(
                        offset: visible ? Offset.zero : const Offset(0, 2),
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        child: AnimatedOpacity(
                          opacity: visible ? 1 : 0,
                          duration: const Duration(milliseconds: 180),
                          child: IgnorePointer(
                            ignoring: !visible,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: BlocBuilder<BookmarkCubit, BookmarkState>(
                                buildWhen: (a, b) => savable == null
                                    ? false
                                    : a.contains(savable) != b.contains(savable),
                                builder: (context, bm) {
                                  final isSaved =
                                      savable != null && bm.contains(savable);
                                  return MushafBrowseBar(
                                    isSaved: isSaved,
                                    onSettings: () =>
                                        ReadingSettingsSheet.show(context),
                                    onPlay: _onPlayPage,
                                    onToggleSave: () {
                                      if (savable != null) {
                                        context
                                            .read<BookmarkCubit>()
                                            .toggle(savable);
                                      }
                                    },
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),

              const AyahPlaybackOverlay(),
```

- [ ] **Step 5: Run the existing mushaf cubit/dispose tests (still green)**

Run:
```bash
fvm flutter test test/features/surah/presentation/cubit test/features/surah/presentation/pages/mushaf/mushaf_page_dispose_test.dart
```
Expected: PASS (the dispose test should still pass; the `SystemChrome` removal doesn't affect last-read save).

- [ ] **Step 6: Analyze**

Run: `fvm flutter analyze lib/features/surah/presentation/pages/mushaf`
Expected: No issues. (Remove any now-unused imports such as `package:flutter/services.dart` if flagged.)

- [ ] **Step 7: Commit**

```bash
git add lib/features/surah/presentation/pages/mushaf/mushaf_page.dart
git commit -m "feat(mushaf): unified chrome — top bar + browse bar; drop rotate lock

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 5: Delete the old action dock + its test

**Files:**
- Delete: `lib/features/surah/presentation/pages/mushaf/widgets/mushaf_action_dock.dart`
- Delete: `test/features/surah/presentation/pages/mushaf/widgets/mushaf_action_dock_test.dart`

- [ ] **Step 1: Confirm no remaining references**

Run: `grep -rn "MushafActionDock\|mushaf_action_dock" lib test`
Expected: no matches (Task 4 removed the import + usage).

- [ ] **Step 2: Delete both files**

```bash
git rm lib/features/surah/presentation/pages/mushaf/widgets/mushaf_action_dock.dart test/features/surah/presentation/pages/mushaf/widgets/mushaf_action_dock_test.dart
```

- [ ] **Step 3: Commit**

```bash
git commit -m "chore(mushaf): remove superseded action dock

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 6: Phase 1 verification

**Files:** none (verification only).

- [ ] **Step 1: Run the mushaf widget + cubit suites (scoped)**

Run:
```bash
fvm flutter test test/features/surah/presentation
```
Expected: All PASS. (If `ayah_playback_overlay_test.dart` or others referenced the dock, none should — they target the overlay independently.)

- [ ] **Step 2: Analyze the feature**

Run: `fvm flutter analyze lib/features/surah`
Expected: No issues.

- [ ] **Step 3: Manual gate (document in PR)**

On device/emulator:
1. Open a page → tap → **top bar** (back · surah · page) and **browse bar** (settings · play · save) appear; tap again → both hide.
2. Tap an ayah → browse bar disappears, the **player** appears (never both); dismiss the player → browse bar returns (chrome still on).
3. Press **Play** on the browse bar → player appears, browse bar gone, top bar still reachable by tapping.
4. Tap the page indicator → **page-jump** sheet → enter a page → it navigates there (page and scroll modes).
5. **Rotate** the device with OS auto-rotate on/off → no stuck state; landscape shows scroll mode; there is no rotate button.
6. Back button pops to the surah list.

- [ ] **Step 4: Finalize**

Phase 1 is complete and self-contained. Proceed to Phase 2 (reading-mode `AppSegmentedSelector` + brightness live-preview) and Phase 3 (page bookmarks + ribbon) plans, or use `superpowers:finishing-a-development-branch` if stopping here.

---

## Self-review notes (author)

- **Spec coverage (Phase 1 slice):** A1 unified surface → Tasks 3,4 (browse bar mutually exclusive with overlay via `playerVisible`); A2 top bar → Tasks 1,2,4; A3 remove rotate → Tasks 4,5. (A4 reading-mode toggle, A5 brightness → Phase 2; A6 page bookmarks → Phase 3, where the carried-over ayah-save button in Task 3/4 is replaced.)
- **Placeholder scan:** none — every widget + test is complete code. The only "if the project uses gen-l10n" note (Task 1 Step 4) is a real either/or with both branches specified (IDE-save vs `gen-l10n`).
- **Type consistency:** `playerVisible = highlightedAyah != null || isOverlayPinned` matches `AyahPlaybackOverlay`'s own predicate; widget keys (`mushaf-top-back`, `mushaf-top-page`, `browse-settings/play/save`, `page-jump-go`) match between widgets and tests; `MushafTopBar`/`MushafBrowseBar`/`PageJumpSheet` signatures identical across tasks.
- **Test caveat honored:** all `flutter test` runs are scoped under `test/features/...`.
