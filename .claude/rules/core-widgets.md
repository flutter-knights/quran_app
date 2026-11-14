---
description: Core widgets catalogue — always check before creating new widgets to prevent duplication
paths: ["lib/**/*.dart"]
---

# Core Widgets (`lib/core/widgets/`)

Before creating ANY widget, check this list. If a match exists, use it. A core widget knows no feature, entity or cubit, and reads colours from the theme.

## Design kit (`core/widgets/design/`)
- **SurfaceCard**: surface card with a soft shadow, light mode only; no border (`child, padding, radius, accentColor, onTap`). The default card for any grouped content.
- **LabelledAccentCard**: uppercase label in an accent colour over body text (`label, body, accentColor`).
- **ArabicQuoteBlock**: `SurfaceCard` with a leading accent and Amiri Quran text (`text, fontSize`). For ayah, hadith and du'a text.
- **AppScreenAppBar**: back chip, centred title with optional eyebrow label, optional trailing action (`title, label, trailing, onBack`). The standard screen header.
- **AppBarCenterTitle**: small uppercase label over the title (`label, title`).
- **IconChip**: 38×38 app-bar icon button (`icon, onPressed, size, iconSize`).
- **AppSectionHeader**: accent bar + uppercase label + optional trailing (`label, trailing`).
- **AppSegmentedSelector\<T\>**: compact segmented control over `SegmentOption<T>(value, label)` (`options, selected, onChanged, expand`).
- **AppStatusBadge**: tinted pill with optional dot (`color, label, showDot`). For any status: hadith grade, download state.
- **ActionButtonsRow** + **ActionBtn** / **ActionBtn.primary**: row of equal-width 44-high buttons (`icon, label, onPressed, iconTrailing`).
- **OrnamentDivider**: line ◆ line divider.
- **ScrollToTopFab**: wraps a scrollable and fades in a scroll-to-top button past `threshold` (`controller, child, threshold`).
- **AppListSkeleton** (`count`), **HomeSkeleton**: loading skeletons, see `loading-states.md`.
- **SplashBackdrop**, **SplashLoader**: the splash and landing brand backdrop and its three-dot loader.
- **backArrowIcon(context)**, **forwardArrowIcon(context)** (`directional_icons.dart`): HugeIcons arrows that point the right way in RTL and LTR.

## Other core widgets
- **PrettierTap**: shrink-on-press tap wrapper (`child, onTap, shrinkPixels`). Use for custom tappables instead of a bare `GestureDetector`.
- **CustomAppBar**: app bar with `title, leading, trailing`, sliver or box (`isSliver, height`), auto back button.
- **ToggleWidget**: switches between `defaultChild` and `targetChild` on `value`.
- **CircularBullet**: small round bullet.
- **LastQuranRead**: the "continue reading" card; reads `LastReadCubit`.
