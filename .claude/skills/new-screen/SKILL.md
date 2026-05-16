---
name: new-screen
description: Add a new screen/page to an existing feature with proper Cubit integration and routing
user-invocable: true
argument-hint: "<screen-name>"
---

# Add New Screen

## 1. Create the page file

Place it at: `lib/features/<feature>/presentation/pages/<view_name>_page.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran_app/core/di/dependency_injection.dart';

class ExamplePage extends StatelessWidget {
  const ExamplePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ExampleCubit>()..loadData(),
      child: const _ExamplePageBody(),
    );
  }
}

class _ExamplePageBody extends StatelessWidget {
  const _ExamplePageBody();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(S.of(context).example_title)),
      body: BlocBuilder<ExampleCubit, ExampleState>(
        builder: (context, state) {
          if (state is ExampleLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is ExampleLoaded) {
            return Text(state.data);
          } else if (state is ExampleError) {
            return Center(child: Text(state.message));
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}
```

## 2. Add route to go_router

In `lib/config/router/app_router.dart`, add:
```dart
GoRoute(
  path: '/example',
  builder: (context, state) => const ExamplePage(),
),
```

## 3. All user-facing strings must use `S.of(context).key_name`
Update `intl_en.arb` and `intl_ar.arb` with the new keys.
