---
description: Core utility rules
paths: ["lib/core/utils/**/*.dart", "lib/core/helper_functions/**/*.dart"]
---

# Core Utilities

- General utility functions and helpers reside in `lib/core/utils` or `lib/core/helper_functions`.
- These include Date/Time formatters, extension methods (e.g. for Strings, DateTimes), input validators, and general helpers.
- They must remain pure or solely rely on standard dart libraries or stable third-party packages. Avoid injecting UI logic or complex dependencies into core utilities.
