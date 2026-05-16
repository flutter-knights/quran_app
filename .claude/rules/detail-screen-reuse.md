---
description: Strategies for reusing screen layouts and components
paths: ["lib/features/**/presentation/pages/**/*.dart"]
---

# Detail Screen & UI Reuse

- Use the `go_router` for all screen navigation. Define routes in `lib/config/router/app_router.dart`.
- When passing arguments to a screen, pass primitives or domain entities (e.g. a `Surah` object or an ID) in the route's `extra` parameter.
- Common screen layouts (like a standard detail page with an Audio player app bar) should be templated or composable.
- Ensure that the audio playback state (managed by `PlaybackCubit` or similar) is handled at a high enough level in the widget tree so that it persists across screens if needed.
