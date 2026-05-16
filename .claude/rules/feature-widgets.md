---
description: Feature widget rules
paths: ["lib/features/**/presentation/widgets/**/*.dart"]
---

# Feature Widgets

- Feature widgets are UI components specific to a particular feature (e.g., `AhadithList`, `SurahCard`).
- They reside in `lib/features/<feature_name>/presentation/widgets/`.
- They should access state primarily via `BlocBuilder` or `BlocSelector` listening to their feature's specific `Cubit` (e.g., `MushafCubit`, `PlaybackCubit`).
- Do not reuse a feature widget in another completely distinct feature without a very good reason. If it becomes globally needed, consider abstracting it and moving it to `lib/core/widgets`.
