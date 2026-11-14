---
description: Cubit usage patterns — state shape, BlocBuilder vs BlocSelector vs BlocListener, side effects, cubit communication
paths: ["lib/features/**/presentation/**/*.dart", "lib/main.dart"]
---

# State Management Patterns

`architecture.md` covers DI registration. This covers how to use cubits and states in widgets.

## State class shape
- `sealed class` for the base state, `final class` for each variant. No `abstract class` for new states.
- Every state extends `Equatable` and lists every field in `props`. Without it `buildWhen`, `BlocSelector` and `listenWhen` can't detect "no change", and the UI rebuilds on every `emit`.
- `const` constructors for every variant.
- A single-object state (one class with `copyWith`) is fine when the screen is one evolving view, like the mushaf; it still extends `Equatable`.

```dart
sealed class FooState extends Equatable {
  const FooState();
  @override
  List<Object?> get props => const [];
}

final class FooLoading extends FooState {
  const FooLoading();
}

final class FooLoaded extends FooState {
  final Foo item;
  const FooLoaded({required this.item});
  @override
  List<Object?> get props => [item];
}
```

## Cubit body rules
- **`if (isClosed) return;` before every `emit()` that follows an `await`**, including inside `result.fold(...)`, and first thing inside a stream's `listen` callback. Async work outlives the screen. A synchronous emit needs no check.
- One public method per user intent (`load()`, `toggle(id)`, `seekTo(page)`); it calls the use case and maps `Either<Failure, T>` to states.
- No `BuildContext`, widgets, navigation or snackbars inside a cubit. The cubit emits; the view reacts.
- Cancel stream subscriptions and timers in `close()`. To resubscribe, assign the new subscription first and cancel the old one after; awaiting the cancel first leaves a gap where `close()` strands a live subscription.
- Don't put ephemeral UI state (focus, expand/collapse, transient input) in a cubit; use a local `StatefulWidget` or `ValueNotifier`.
- Don't `setState` data that already lives in a reachable cubit.

## BlocBuilder, BlocSelector, BlocListener, BlocConsumer
1. **Side effect only** (snackbar, navigation, dialog, sheet, focus) → `BlocListener` with `listenWhen`.
2. **UI tied to one narrow slice** → `BlocSelector<C, S, T>`. Required when the state has 3+ fields or several variants and the widget needs one.
3. **UI tied to the whole state** → `BlocBuilder` with `buildWhen`.
4. **UI and side effects** → a sibling `BlocBuilder` + `BlocListener`, not `BlocConsumer`, unless both share a non-trivial closure.
5. **`BlocConsumer` whose builder ignores state** → plain `BlocListener`.

## Rebuild scoping
- A `BlocBuilder` over ~30 lines or wrapping 5+ children is a smell: extract the reactive leaf into a named widget so siblings stay `const`. A one-off leaf is a private `_Foo` in the same file; one used twice in the feature goes in `pages/widgets/`; one used by two features goes in `core/widgets/`. Pass data in through the constructor and events out through callbacks, so it stays movable.
- Mark leaves `const` whenever their arguments allow.
- Wrap list items that carry images, shadows or animations in `RepaintBoundary`. The mushaf page view is the hot path.

## `context.read` vs `context.watch`
- `context.read<C>()` in callbacks (`onPressed`, `onTap`). Never `watch` in a callback.
- `context.watch<C>()` in `build` only when the whole state is needed; prefer `BlocSelector` for a slice.

## Side effects never go in `builder`
These belong in `BlocListener.listener` or a callback:
- `ScaffoldMessenger.of(context).showSnackBar(...)`
- `context.push`, `context.go`, `context.pop`, `Navigator.*`
- `showDialog`, `showModalBottomSheet`
- `FocusScope.of(context).requestFocus(...)`
- any call that mutates another cubit

## Cubit-to-cubit communication after writes
1. **Listener-driven**, when both cubits are in scope: a `BlocListener` on the action cubit's success state calls the other cubit's method.
2. **Pop with a result**, when they aren't: the action screen calls `context.pop(result)` and the previous screen updates its own cubit.
3. App-wide cubits (`BookmarkCubit`, `LastReadCubit`, `PlaybackCubit`) are shared instances, so a write through one is already visible everywhere; don't mirror their state in a screen cubit.

## What `flutter analyze` won't catch
Check by hand in review: a missing `isClosed` check, `BlocBuilder` without `buildWhen` on a 3+ field state, side effects in `builder`, a state without `Equatable` or with incomplete `props`, a trivial-builder `BlocConsumer`, `setState` duplicating cubit data, a cubit touching `BuildContext`, a subscription not cancelled in `close()`.
