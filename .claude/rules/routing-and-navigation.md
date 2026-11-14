---
description: GoRouter conventions — path constants, transitions, params via state.extra, where cubits are provided
paths: ["lib/config/router/*.dart", "lib/features/**/presentation/**/*.dart", "lib/main.dart"]
---

# Routing & Navigation

GoRouter, built once by `AppRouter.createRouter(initialLocation:)` in `lib/config/router/app_router.dart`.

## Path constants
- Every path is a `static const String …Path` on `AppRouter` (`AppRouter.mushafPath`). Never inline a path string in a `GoRoute`, `context.push` or `context.go`.
- camelCase paths (`/surahList`, `/mushafImage`) to match the existing ones.

## Transitions
- Every route uses `pageBuilder: GoTransitions.<…>.build(builder: …)`, never a bare `builder:`.
- Pushed screens use `GoTransitions.fade.withScale`. Home and splash keep their own (`slide.toTop.withFade`, `fade.withScale`). Match the surrounding routes; don't invent a timing.

## Params via `state.extra`
- Pass a primitive, an entity, an args object or a record in `extra`, never path or query params:
  - `state.extra as String` (ahadith: the book slug)
  - `state.extra as ({Hadith hadith, String bookSlug})` (hadith)
  - mushaf takes a `MushafArgs` or a bare page `int`, normalised by `_mushafArgsFrom`; follow that pattern when a route accepts more than one shape, with a safe default.

## Where cubits are provided
- **App-wide** cubits (`SettingsCubit`, bookmarks, last read, playback, downloads) are provided once in `main.dart`'s `MultiBlocProvider`; read them anywhere with `context.read`.
- **Route-scoped** cubits (factories) are created in the route's builder with `BlocProvider(create: (_) => sl<…>()..load())` or a `MultiBlocProvider` (`SurahCubit`, `SearchCubit`, `MushafCubit`). They close when the route pops.
- A lazy-singleton cubit handed to a screen uses `BlocProvider.value(value: sl<…>())`, never `create`: `create` closes the shared instance when the route pops. Don't re-provide an app-wide cubit in a route or page at all; `main.dart` already provides it above the router.

## Navigation calls
| Want to | Use |
|---|---|
| Open a screen on the stack | `context.push(AppRouter.fooPath, extra: …)` |
| Replace the location | `context.go(AppRouter.fooPath)` |
| Close and return a value | `context.pop(result)` |

- Never `Navigator.of(context).push(MaterialPageRoute(…))`: it bypasses GoRouter. `Navigator.pop`/`maybePop` to close a sheet or dialog is fine.
- Navigate from callbacks or `BlocListener.listener`, never from a `builder` (see `state-management-patterns.md`).

## Adding a route
1. Add the `…Path` constant to `AppRouter`.
2. Add the `GoRoute` with `pageBuilder` and the matching transition.
3. Read params with a typed `state.extra` cast.
4. Provide the screen's cubits in the builder.
