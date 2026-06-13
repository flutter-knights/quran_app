# Mushaf Control Surface — Phase 2 (Settings Sheet) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the reading-settings sheet consistent and usable: swap the reading-mode `SegmentedButton` for the app's `AppSegmentedSelector`, and make the brightness slider preview live by fading the sheet away while you drag so you see the actual page brightness.

**Architecture:** `ReadingSettingsSheet` becomes a `StatefulWidget` tracking a `_dragging` flag. The brightness `Slider`'s `onChangeStart`/`onChangeEnd` toggle it; an `AnimatedOpacity` around the sheet body drops to ~0.12 while dragging. `ReadingSettingsSheet.show` uses a transparent barrier + transparent sheet background so the faded body reveals the page behind it.

**Tech Stack:** Flutter, `flutter_bloc`, `hydrated_bloc` (SettingsCubit), `AppSegmentedSelector`, `flutter_test`. FVM-pinned Flutter 3.38.1.

> **Scope:** Phase 2 of Workstream A. Depends on nothing in Phase 1 (independent). Phase 3 (page bookmarks) is separate.
> **Test caveat:** never run the full `fvm flutter test` (asset regeneration); scope to `test/features/...`. Never `git add -A`.

---

## File structure

| File | Responsibility | Action |
|---|---|---|
| `lib/features/surah/presentation/pages/mushaf/widgets/reading_settings_sheet.dart` | Reading settings; now stateful w/ brightness preview + `AppSegmentedSelector` | Modify |
| `test/.../widgets/reading_settings_sheet_test.dart` | Add toggle + brightness-fade tests | Modify |

---

### Task 1: Reading-mode toggle → `AppSegmentedSelector`

**Files:**
- Modify: `lib/features/surah/presentation/pages/mushaf/widgets/reading_settings_sheet.dart`
- Test: `test/features/surah/presentation/pages/mushaf/widgets/reading_settings_sheet_test.dart`

- [ ] **Step 1: Add a failing test** (append inside the existing `main()` in the test file, after the paper test)

```dart
  testWidgets('tapping the Scroll segment updates the reading mode',
      (tester) async {
    final cubit = SettingsCubit();
    addTearDown(cubit.close);
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.delegate.supportedLocales,
      home: BlocProvider.value(
        value: cubit,
        child: const Scaffold(body: ReadingSettingsSheet()),
      ),
    ));
    await tester.pumpAndSettle();

    expect(cubit.state.settingsModel.readingMode, MushafReadingMode.page);
    await tester.tap(find.text('Scroll'));
    await tester.pump();
    expect(cubit.state.settingsModel.readingMode, MushafReadingMode.scroll);
  });
```
Add the import at the top of the test file:
```dart
import 'package:quran_app/core/constants/mushaf_reading_mode.dart';
```

- [ ] **Step 2: Run, verify it fails**

Run: `fvm flutter test test/features/surah/presentation/pages/mushaf/widgets/reading_settings_sheet_test.dart`
Expected: FAIL — the `SegmentedButton` renders both labels but tapping "Scroll" text may not toggle reliably, or `MushafReadingMode` import unused → confirm red on the new test.

- [ ] **Step 3: Swap the control**

In `reading_settings_sheet.dart`, add the import:
```dart
import 'package:quran_app/core/widgets/design/app_segmented_selector.dart';
```
Replace the `SegmentedButton<MushafReadingMode>(...)` block (lines 84–99) with:
```dart
                AppSegmentedSelector<MushafReadingMode>(
                  key: const ValueKey('reading-mode-toggle'),
                  selected: model.readingMode,
                  expand: true,
                  onChanged: cubit.updateReadingMode,
                  options: [
                    SegmentOption(
                      value: MushafReadingMode.page,
                      label: s.pageByPage,
                    ),
                    SegmentOption(
                      value: MushafReadingMode.scroll,
                      label: s.continuousScroll,
                    ),
                  ],
                ),
```

- [ ] **Step 4: Run, verify it passes**

Run: `fvm flutter test test/features/surah/presentation/pages/mushaf/widgets/reading_settings_sheet_test.dart`
Expected: PASS (both the paper test and the new toggle test).

- [ ] **Step 5: Commit**

```bash
git add lib/features/surah/presentation/pages/mushaf/widgets/reading_settings_sheet.dart test/features/surah/presentation/pages/mushaf/widgets/reading_settings_sheet_test.dart
git commit -m "feat(mushaf): reading-mode toggle uses AppSegmentedSelector

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: Brightness live-preview (fade the sheet while dragging)

**Files:**
- Modify: `lib/features/surah/presentation/pages/mushaf/widgets/reading_settings_sheet.dart`
- Test: `test/features/surah/presentation/pages/mushaf/widgets/reading_settings_sheet_test.dart`

- [ ] **Step 1: Add a failing test** (append in `main()`)

```dart
  testWidgets('dragging brightness fades the sheet body, restores on end',
      (tester) async {
    final cubit = SettingsCubit();
    addTearDown(cubit.close);
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.delegate.supportedLocales,
      home: BlocProvider.value(
        value: cubit,
        child: const Scaffold(body: ReadingSettingsSheet()),
      ),
    ));
    await tester.pumpAndSettle();

    AnimatedOpacity body() => tester.widget<AnimatedOpacity>(
        find.byKey(const ValueKey('reading-sheet-body')));
    final slider = tester.widget<Slider>(
        find.byKey(const ValueKey('reading-brightness-slider')));

    expect(body().opacity, 1.0);

    slider.onChangeStart!(0.8);
    await tester.pump();
    expect(body().opacity, lessThan(0.5));

    slider.onChanged!(0.6); // still updates the live brightness
    await tester.pump();
    expect(cubit.state.settingsModel.pageBrightness, 0.6);

    slider.onChangeEnd!(0.6);
    await tester.pump();
    expect(body().opacity, 1.0);
  });
```

- [ ] **Step 2: Run, verify it fails**

Run: `fvm flutter test test/features/surah/presentation/pages/mushaf/widgets/reading_settings_sheet_test.dart`
Expected: FAIL — no `AnimatedOpacity` keyed `reading-sheet-body`; slider has no `onChangeStart`/`onChangeEnd`.

- [ ] **Step 3: Make the sheet stateful with the fade**

Replace the whole `reading_settings_sheet.dart` with:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran_app/core/constants/mushaf_paper.dart';
import 'package:quran_app/core/constants/mushaf_reading_mode.dart';
import 'package:quran_app/core/widgets/design/app_segmented_selector.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:quran_app/features/surah/presentation/utils/mushaf_paper_colors.dart';
import 'package:quran_app/generated/l10n.dart';

class ReadingSettingsSheet extends StatefulWidget {
  const ReadingSettingsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      // Transparent barrier + background so that, when the body fades during a
      // brightness drag, the page behind is fully visible.
      barrierColor: Colors.transparent,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => BlocProvider.value(
        value: context.read<SettingsCubit>(),
        child: const ReadingSettingsSheet(),
      ),
    );
  }

  @override
  State<ReadingSettingsSheet> createState() => _ReadingSettingsSheetState();
}

class _ReadingSettingsSheetState extends State<ReadingSettingsSheet> {
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final scheme = Theme.of(context).colorScheme;
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        final model = state.settingsModel;
        final cubit = context.read<SettingsCubit>();
        return AnimatedOpacity(
          key: const ValueKey('reading-sheet-body'),
          opacity: _dragging ? 0.12 : 1.0,
          duration: const Duration(milliseconds: 140),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.readingSettings,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 16),
                  Text(s.paper, style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 8),
                  Row(
                    children: MushafPaper.values.map((p) {
                      final selected = p == model.mushafPaper;
                      return Expanded(
                        child: GestureDetector(
                          key: ValueKey('reading-paper-${p.name}'),
                          onTap: () => cubit.updateMushafPaper(p),
                          child: Container(
                            height: 54,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: p.colors.background,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: selected
                                    ? scheme.primary
                                    : scheme.onSurface.withValues(alpha: 0.12),
                                width: selected ? 2 : 1,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  Text(s.brightness,
                      style: Theme.of(context).textTheme.labelMedium),
                  Slider(
                    key: const ValueKey('reading-brightness-slider'),
                    min: 0.3,
                    max: 1.0,
                    value: model.pageBrightness,
                    onChangeStart: (_) => setState(() => _dragging = true),
                    onChanged: cubit.updatePageBrightness,
                    onChangeEnd: (_) => setState(() => _dragging = false),
                  ),
                  const SizedBox(height: 8),
                  Text(s.readingMode,
                      style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 8),
                  AppSegmentedSelector<MushafReadingMode>(
                    key: const ValueKey('reading-mode-toggle'),
                    selected: model.readingMode,
                    expand: true,
                    onChanged: cubit.updateReadingMode,
                    options: [
                      SegmentOption(
                        value: MushafReadingMode.page,
                        label: s.pageByPage,
                      ),
                      SegmentOption(
                        value: MushafReadingMode.scroll,
                        label: s.continuousScroll,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 4: Run, verify it passes**

Run: `fvm flutter test test/features/surah/presentation/pages/mushaf/widgets/reading_settings_sheet_test.dart`
Expected: PASS (paper, toggle, and brightness-fade tests).

- [ ] **Step 5: Analyze**

Run: `fvm flutter analyze lib/features/surah/presentation/pages/mushaf/widgets/reading_settings_sheet.dart`
Expected: No issues.

- [ ] **Step 6: Commit**

```bash
git add lib/features/surah/presentation/pages/mushaf/widgets/reading_settings_sheet.dart test/features/surah/presentation/pages/mushaf/widgets/reading_settings_sheet_test.dart
git commit -m "feat(mushaf): brightness live-preview — fade settings sheet while dragging

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: Phase 2 verification

- [ ] **Step 1: Scoped tests**

Run: `fvm flutter test test/features/surah/presentation/pages/mushaf/widgets/reading_settings_sheet_test.dart`
Expected: PASS.

- [ ] **Step 2: Manual gate (document in PR)**

Open the reading-settings sheet on the Mushaf:
1. The reading-mode control matches the settings 12h/24h + language switcher style.
2. Drag the brightness slider → the sheet fades out so you see the page brightness change live; releasing restores the sheet.
3. Tapping outside still dismisses the sheet.

---

## Self-review notes (author)

- **Spec coverage:** A4 reading-mode `AppSegmentedSelector` → Task 1; A5 brightness live-preview → Task 2 (transparent barrier in `show`, fade-on-drag body).
- **Placeholder scan:** none — full file replacement + complete tests.
- **Type consistency:** `ValueKey('reading-mode-toggle')` preserved; `ValueKey('reading-brightness-slider')` preserved; new `ValueKey('reading-sheet-body')` used in both code and test; `SegmentOption`/`AppSegmentedSelector` API matches `lib/core/widgets/design/app_segmented_selector.dart`.
- **Test caveat honored:** scoped test path only.
