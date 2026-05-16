---
description: Core widget rules
paths: ["lib/core/widgets/**/*.dart"]
---

# Core Widgets

- Core widgets are highly reusable, generic UI components located in `lib/core/widgets`.
- They should not be tied to specific feature business logic or domain entities.
- Ensure they are responsive and respect the app's theme (`SettingsCubit` manages `ThemeMode`).
- Common components include customized AppBars, Buttons, Loading Indicators, and Error Views.
