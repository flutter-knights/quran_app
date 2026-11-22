---
description: Icons — HugeIcons stroke-rounded set, directional arrows through helpers
paths: ["lib/**/*.dart"]
---

# Icons

- Two icon sets are in use: **HugeIcons stroke-rounded** (`HugeIcon(icon: HugeIcons.strokeRounded…, color:, size:)`) across home, ahadith, the Bookmarks page, settings and the core app bars, HugeIcons also in the mushaf running head, foot band, ayah leaf, the tafsir full detent and notice chip, the فاصل chooser and the «أماكني» sheet; Material `Icons.*` in the player leaf, the playback options sheet, `SurahDownloadButton` and a few settings widgets.
- Match the set the surrounding feature already uses; never mix both in one row or bar. Don't sweep files the change doesn't touch.
- **Directional arrows**: `backArrowIcon(context)` and `forwardArrowIcon(context)` (`core/widgets/design/directional_icons.dart`) already flip with the text direction. Never write a new `isArabic ? arrowLeft : arrowRight` ternary, and never use the forward arrow for back navigation.
- Read icon colours from `context.colorScheme`, never a hex literal.
