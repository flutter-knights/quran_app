---
description: KISS, DRY, separation of concerns, and the app-level design principles
paths: ["lib/**/*.dart"]
---

# Design Principles

Every code change MUST follow:

- **KISS**: no over-engineering, no speculative abstractions.
- **DRY**: reuse existing helpers, base classes, and shared widgets before writing new ones. Check `core-widgets.md`, `feature-widgets.md` and `core-utilities.md` first.
- **Separation of concerns**: one responsibility per layer and class. No API or Hive calls in widgets, no UI logic in repositories.

App-level principles:

1. **Clean Architecture**: Domain, Data and Presentation stay separate, per `architecture.md`.
2. **State**: business logic in Cubits, rendering in widgets, per `state-management-patterns.md`.
3. **Offline first**: prayer times, location, hadith pages and reading position are cached in Hive so the app works without a network.
4. **Arabic and RTL first**: every layout must work in RTL, per `localization.md`.
5. **Theming**: colours come from the palette and `context.colorScheme`, per `theming.md`.
