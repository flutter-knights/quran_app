---
name: new-screen
description: Add a new screen/page to an existing feature with proper Cubit integration and routing
user-invocable: true
argument-hint: "<screen-name>"
---

# Add New Screen

Read `routing-and-navigation.md`, `state-management-patterns.md`, `loading-states.md` and `core-widgets.md` first.

## 1. Create the page file

`lib/features/<feature>/presentation/pages/<view_name>_page.dart`. Widgets only this screen uses go in `pages/widgets/`.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran_app/core/widgets/design/app_list_skeleton.dart';
import 'package:quran_app/core/widgets/design/app_screen_app_bar.dart';
import 'package:quran_app/generated/l10n.dart';

class ExamplePage extends StatelessWidget {
  const ExamplePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppScreenAppBar(title: S.of(context).example_title),
            Expanded(
              child: BlocBuilder<ExampleCubit, ExampleState>(
                builder: (context, state) => switch (state) {
                  ExampleLoading() || ExampleInitial() => const AppListSkeleton(),
                  ExampleLoaded(:final data) => ExampleList(data: data),
                  ExampleError(:final message) => Center(child: Text(message)),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- Loading is a skeleton (`AppListSkeleton`, or a `Skeletonizer` over placeholder content shaped like the loaded layout), never a spinner.
- Snackbars, navigation and sheets go in a `BlocListener`, never in `builder`.

## 2. Add the route

In `lib/config/router/app_router.dart`, add a path constant and a route that provides the cubit:

```dart
static const String examplePath = "/example";
```

```dart
GoRoute(
  path: examplePath,
  pageBuilder: GoTransitions.fade.withScale.build(
    builder: (context, state) => BlocProvider(
      create: (_) => sl<ExampleCubit>()..loadData(),
      child: const ExamplePage(),
    ),
  ),
),
```

Params go in `extra` with a typed cast (`state.extra as int`). Navigate with `context.push(AppRouter.examplePath)`.

## 3. Strings

`S.of(context).key` inside `build`. Add every key to both `lib/l10n/intl_en.arb` and `lib/l10n/intl_ar.arb`; the IDE extension regenerates `lib/generated/`.
