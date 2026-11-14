# CLAUDE.md

Guidance for Claude Code when working in this repository.

`quran_app` is an Arabic-first Flutter app: the mushaf (page and scroll reading, reading papers,
page and ayah bookmarks), recitation playback, hadith books, search, prayer times with adhan notifications, and
settings.

## Build & Run Commands

Flutter is pinned to **3.50.0 via FVM** (`.fvmrc`). Hive is `hive_ce` (adapters from `hive_ce_generator`,
registered through `lib/hive_registrar.g.dart`). Prefix every command with `fvm`:

```bash
fvm flutter pub get
fvm flutter run
fvm flutter analyze
fvm flutter test
fvm flutter test test/features/surah
fvm dart run build_runner build --delete-conflicting-outputs
```

`flutter test` takes a folder or a file to run part of the suite. `build_runner` only generates the
Hive adapters, for `*_model.dart` files (`build.yaml`).

There is no CI workflow. Run `analyze` and `test` locally before pushing; both must be clean.

Localization regenerates from `lib/l10n/intl_*.arb` through the flutter_intl IDE extension on save.
Do not run `intl_utils:generate` by hand, and never edit `lib/generated/`.

## Architecture

Clean Architecture with Cubit. Each feature is self-contained:

```
lib/
├── config/            # router/app_router.dart, theme/, hive_config, hydrated_bloc_config
├── core/
│   ├── constants/     # AssetsDir, DeviceSize, ColorPalette, MushafPaper, FeatureFlags…
│   ├── di/            # GetIt (sl) setup
│   ├── errors/        # exceptions.dart, failure.dart
│   ├── helper functions/   # note the space in the folder name
│   ├── notifications/ # prayer notification scheduler
│   ├── usecases/      # UseCase, StreamUseCase, NoParams
│   ├── utils/         # DioErrorHandler, GeolocatorErrorHandler
│   └── widgets/       # shared widgets; design/ holds the design-system kit
├── features/<feature>/
│   ├── domain/        # entities, abstract repositories, use cases
│   ├── data/          # models (Hive models here), data sources, repository impls
│   ├── presentation/  # cubit/, pages/ (feature widgets in pages/**/widgets/), utils/
│   └── <feature>_di.dart
├── generated/         # intl output, do not edit
└── l10n/              # ARB sources
```

## Key Patterns

- **State**: `flutter_bloc` Cubits; `HydratedCubit` where state must survive a restart.
- **Errors**: repositories return `Either<Failure, T>` (dartz) and map exceptions to `Failure`
  subclasses (`DioErrorHandler.handle`, `GeolocatorErrorHandler.handle`).
- **DI**: GetIt `sl`. Data sources, repositories and use cases are lazy singletons; screen cubits are
  factories; app-wide cubits are singletons provided once in `main.dart`.
- **Caching**: Hive. Hive models stay in `data/models/` and are registered in `config/hive_config.dart`.
- **Routing**: GoRouter in `config/router/app_router.dart`; path constants are `AppRouter.*Path`.
- **Theme**: `ColorPalette` drives light and dark themes; read colours with `context.colorScheme`,
  text styles with `TS.*`.
- **Loading**: skeletons via `skeletonizer`, never a bare spinner.

## Rules and skills

Rules in `.claude/rules/` load for the files their `paths:` frontmatter names:

- `architecture.md`: layer boundaries, DI, naming, error handling
- `design-principles.md`: KISS, DRY, separation of concerns
- `state-management-patterns.md`: state shape, BlocBuilder vs BlocSelector vs BlocListener, side effects
- `routing-and-navigation.md`: route constants, transitions, `state.extra`, where cubits are provided
- `theming.md`: palette, colour scheme, typography, card styling
- `icons.md`: HugeIcons and directional arrows
- `localization.md`: `S.of(context)` vs `S.current`, RTL, enum extensions
- `loading-states.md`: skeletons
- `core-widgets.md`, `feature-widgets.md`, `core-utilities.md`: catalogues, check before writing new code
- `detail-screen-reuse.md`: screen layout reuse

Skills in `.claude/skills/`: `/feature-flow` (entry point for any non-trivial feature), `/new-feature`,
`/new-entity`, `/new-usecase`, `/new-cubit`, `/new-screen`, `/health-check`.

Specs and plans live in `docs/superpowers/specs/` and `docs/superpowers/plans/`.
