---
description: Building screens from the shared kit — no per-screen copies of headers, cards or sections
paths: ["lib/features/**/presentation/**/*.dart"]
---

# Screen Layout Reuse

- Header: `AppScreenAppBar` (back chip, centred title, optional trailing). Don't build a fresh `AppBar` per screen.
- Sections: `AppSectionHeader` over `SurfaceCard`s; `ArabicQuoteBlock` for Arabic text; `LabelledAccentCard` for a labelled note; `OrnamentDivider` between blocks.
- Gaps: `Column(spacing: N)` / `Row(spacing: N)`, not `SizedBox` between every child.
- Long lists: wrap in `ScrollToTopFab`; load with `AppListSkeleton` (see `loading-states.md`).
- Audio: `PlaybackCubit` is app-wide (`main.dart`), so playback survives navigation. Never create a second `PlaybackCubit` or `AudioPlayer` in a screen.
- Computed values belong on the entity or in `presentation/utils/`, not inline in `build`.
- Routing and params: `routing-and-navigation.md`.
