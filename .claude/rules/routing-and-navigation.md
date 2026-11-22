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
- Every route uses a `pageBuilder`, never a bare `builder:`.
- Pushed screens use `pageBuilder: _fadePage(builder: …)` in `app_router.dart`: `GoTransitions.fade.withStyle(curve: Curves.easeInOut)` at 200 ms, no scale or slide. Don't add a per-route timing; change the helper to change every screen.
- The three entry routes keep their own `GoTransitions`: splash (`fade.withScale`), home (`slide.toTop.withFade`, 500 ms, the splash hand-off) and onboarding (`fade`, 450 ms). They share the `SplashBackdrop`.
- `test/config/router/app_router_test.dart` pins this: four `GoTransitions` uses (the entry routes and `_fadePage`), every other `GoRoute` goes through `_fadePage`, and the helper is a 200 ms `easeInOut` fade.

## Notification tap
- `config/router/now_playing_route.dart` owns it: `listenNowPlaying` (wired once in `main.dart`) calls `openNowPlaying`. With no reader on the stack it pushes `AppRouter.mushafPath` with `MushafArgs.nowPlaying`; with one, it pops the routes above the reader and fires `nowPlayingResume`, which `MushafPage` answers with `MushafCubit.resumeFollow()`.

## Params via `state.extra`
- Pass a primitive, an entity, an args object or a record in `extra`, never path or query params:
  - `state.extra as String` (ahadith: the book slug)
  - `state.extra as ({Hadith hadith, String bookSlug})` (hadith)
  - mushaf takes a `MushafArgs` (it carries `origin`: `normal` or `jump`) or a bare page `int`, normalised by `_mushafArgsFrom` (a bare `int` is `normal`); follow that pattern when a route accepts more than one shape, with a safe default.

## Where cubits are provided
- **App-wide** cubits (`SettingsCubit`, `FasilCubit`, `SavedAyatCubit`, last read, playback, book and surah downloads (`DownloadBookCubit`, `SurahDownloadCubit`), `AlertsSyncCubit`) are provided once in `main.dart`'s `MultiBlocProvider`; read them anywhere with `context.read`.
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
