---
description: High-level design principles for the app
paths: ["lib/**/*.dart"]
---

# Design Principles

1. **Clean Architecture**: Strictly maintain the separation of Domain, Data, and Presentation layers as described in `architecture.md`.
2. **State Management**: Use `flutter_bloc` (specifically `Cubit`). Keep business logic in Cubits, pure UI rendering in Views/Widgets.
3. **Dependency Injection**: Leverage `GetIt` for providing DataSources, Repositories, UseCases, and Cubits.
4. **Offline First/Caching**: Use `Hive` for storing user data like prayer times and location offline so the app remains functional.
5. **Localization & RTL First**: The Quran app has strong Arabic usage. Ensure layouts work seamlessly in RTL modes.
6. **Theming**: Dark and Light themes are managed centrally via `config/theme`. Access colors through standard `Theme.of(context)` properties or custom ThemeExtensions if defined.
