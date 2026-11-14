---
description: Localization rules — Arabic primary, S.of(context) in build, RTL-safe layout
paths: ["lib/**/*.dart"]
---

# Localization

- Arabic and English via `package:quran_app/generated/l10n.dart` (`S`). Arabic is primary; every layout must work in RTL.
- The flutter_intl IDE extension regenerates `lib/generated/` when `lib/l10n/intl_*.arb` is saved. Add every key to both ARB files. Never run `intl_utils:generate` by hand.
- Every user-facing string is localized. **Inside `build`, use `S.of(context)`.** Reserve `S.current` for code with no `BuildContext` (cubits, `failure.dart`, `.localized()` extensions) and for callbacks such as `onTap` or `BlocListener.listener`, which run after the build.
- Why: several router builders return a `const` page, and a `const` widget is reused without re-running `build`. `S.current` registers no dependency, so its text can freeze in the old language after a switch. `S.of(context)` registers a `Localizations` dependency, which marks the element dirty across that barrier. Follow the rule everywhere instead of auditing which page is affected.
- Never build a `late final` value from `S.current` in `initState`; it never re-localizes. Use a getter.
- Numbers shown in Arabic use Arabic-Indic digits: `toIndicNumerals` / `toLocalized` (see `core-utilities.md`).

## Placement of `.localized()` / `.color` extensions
- Anything that touches `S` or `Color` is presentation code. Put enum extensions in `features/<feature>/presentation/utils/` (`enum_localization.dart`, `enum_colors.dart`), never in `domain/entities/extensions/`.

## RTL
- Use `PositionedDirectional`, `EdgeInsetsDirectional`, `AlignmentDirectional` and `BorderRadiusDirectional`, never left/right.
- Directional arrows come from `backArrowIcon(context)` / `forwardArrowIcon(context)`; never add another `isArabic ? … : …` arrow ternary (see `icons.md`).
