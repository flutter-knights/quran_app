---
description: Localization rules — Arabic primary, auto-generated via IDE extension
paths: ["lib/**/*.dart"]
---

# Localization

- The app supports Arabic and English, handled via `package:quran_app/generated/l10n.dart`.
- The `flutter_intl` IDE extension auto-generates localization files when ARB files (`lib/l10n/*.arb`) are saved.
- All user-facing strings must be localized via `S.of(context).string_name` (or `S.current.string_name` where context is not available, though `S.of(context)` is preferred).

## Placement of `.localized()` / UI extensions
- Any extension that calls `S.of(context)` or uses `Color` is **presentation-layer code** (transitively imports Flutter).
- Place enum `.localized()` extensions in **`features/<feature>/presentation/utils/`** (e.g. `enum_localization.dart`).
- NEVER place them in `domain/entities/extensions/` — doing so leaks Flutter into the domain layer and violates Clean Architecture.
- RTL widgets: Since the app supports Arabic, prefer using Directional variants of widgets when appropriate (e.g., `PositionedDirectional`, `EdgeInsetsDirectional`, `AlignmentDirectional`).
