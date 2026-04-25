---
name: health-check
description: Run a full codebase health audit — finds tech debt, duplication, pattern violations, and quality regressions across all layers. Auto-fixes low-risk issues.
user-invocable: true
argument-hint: "[scope] — optional: feature name (crm), branch name (feature-xyz), or omit for full codebase"
---

# Codebase Health Check

Periodic full-codebase audit for the Wakil App. Dispatches 4 parallel audit agents, confidence-scores every finding, applies safe fixes automatically, writes a report, and prints a summary.

## Scope Modes

Parse the argument to determine audit scope:

| Invocation | Scope | Files scanned |
|------------|-------|---------------|
| `/health-check` | Full codebase | All of `lib/` |
| `/health-check crm` | Single feature | `lib/features/crm/` + its imports from `lib/core/` |
| `/health-check feature-search-sort-filter` | Branch diff | Only files changed on this branch vs `master` (via `git diff --name-only master...HEAD` or `git diff --name-only master...<branch>`) |

**How to detect the mode:**
1. If arg matches a directory under `lib/features/` → **feature mode**
2. If arg matches a git branch name (`git branch --list <arg>`) → **branch mode**
3. If no arg → **full codebase mode**

In **branch mode**, the agents only scan files from the diff list. In **feature mode**, agents scan that feature's directory plus any `core/` files it imports. All agents receive the scope constraint in their prompt.

## Checklist

You MUST follow these steps in order:

### Step 1 — Gather Context (Haiku Agent)

Launch a **Haiku** agent to collect:
- Contents of `CLAUDE.md` and all `.claude/rules/*.md` files
- **If branch mode:** `git diff --name-only master...<branch>` to get the file list
- **If feature mode:** `ls -R lib/features/<name>/` to get the file list
- List of all feature directories under `lib/features/`

The agent returns a context bundle used to brief the audit agents.

### Step 2 — Run 4 Parallel Audit Agents (Sonnet)

Launch **4 Sonnet agents in parallel**, each with the context bundle from Step 1. Each agent reads files directly, does NOT run any build/test commands.

**Finding ID scheme (required for cross-step joins):** every finding MUST include a stable `id` string of the form `"A<agentNumber>-<zero-padded-index>"` — e.g. `"A1-001"`, `"A1-002"`, `"A3-017"`. Agent #1 uses the `A1-` prefix, Agent #2 uses `A2-`, etc. Within an agent the index starts at `001` and increments. This guarantees globally unique IDs across parallel agents without coordination.

---

**Agent #1: Architecture & DI**

Scan `lib/features/*/`, `lib/core/di/`, `lib/core/usecase/` for:

- **Layer violations:** `data/` importing from `presentation/`, `domain/` importing from `data/` or `presentation/`
- **Flutter in domain:** `domain/` files importing `package:flutter/*`, `dart:ui`, `generated/l10n.dart`, `app/theme/*`, or anything that transitively pulls Flutter (per `rules/architecture.md`)
- **Legacy enum extension path:** Any `.localized()` / `.color` enum extension file under `features/*/domain/entities/extensions/` — must be moved to `features/*/presentation/utils/enum_localization.dart` and `enum_colors.dart` (per `rules/feature-widgets.md`, `rules/localization.md`)
- **DI registration:** Cubits must be `registerFactory`. Data sources, repos, use cases must be `registerLazySingleton`
- **State pattern:** Prefer `sealed class` + `final class` for state types over `abstract class`. Flag pre-existing `abstract class` states at **Suggestion** severity only — do NOT flag as Critical/Warning unless the cubit is newly added on this branch.
- **guard() usage:** Every repository impl method that makes an async call must wrap it in `guard()`
- **isClosed check:** Every cubit must check `if (isClosed) return;` before every `emit()`
- **UseCase SRP:** Each use case has exactly one `call()` method
- **Repo contract:** Every abstract repository method has a matching implementation
- **Feature DI file:** Exists at `features/<name>/<name>_di.dart` and is called from `core/di/dependency_injection.dart`

Return findings as JSON array:
```json
[{
  "id": "A<n>-<index>",        // e.g. "A1-001" — REQUIRED, globally unique (see ID scheme above)
  "file": "path",
  "line": N,
  "issue": "...",
  "fix": "...",
  "severity": "critical|warning|suggestion",
  "effort": "S|M|L",           // S = <15 min, M = 15–60 min, L = >1 hour
  "risk": "high|medium|low",   // impact on users / correctness if not fixed
  "autoFixable": true|false    // hint only — Step 5 auto-fix list is authoritative
}]
```

---

**Agent #2: Reusability & Duplication**

Scan `lib/features/**/presentation/`, `lib/core/widgets/` for:

- **Misplaced shared widgets:** Widgets used by 2+ features but living in a single feature's folder (should be `core/widgets/`)
- **Duplicated form sections:** Same set of `CustomTextInput` fields appearing in multiple form bodies (e.g., address inputs in CRM + Tasks)
- **Duplicated styling:** `InputDecoration` or `BoxDecoration` patterns repeated across files instead of using theme
- **Similar card layouts:** Cards sharing the same PrettierTap + Container + BoxDecoration + padding structure
- **Validation logic:** Same validation rules (email, phone, required) duplicated across forms
- **Inconsistent enum patterns:** Enum `.localized()` and `.color` extensions that differ in structure across features

For each extraction candidate, assess:
- **Occurrences:** How many times it repeats (must be >= 2 to recommend)
- **Readability gain:** Does extraction reduce noise or add harmful indirection?
- **Maintenance gain:** Single source of truth vs scattered copies

Only recommend if occurrences >= 2 AND genuinely improves readability.

Return findings as JSON array:
```json
[{
  "id": "A2-<index>",          // REQUIRED, globally unique
  "file": "path",
  "line": N,
  "issue": "...",
  "fix": "...",
  "severity": "critical|warning|suggestion",
  "effort": "S|M|L",
  "risk": "high|medium|low",
  "autoFixable": true|false,   // hint only — Step 5 auto-fix list is authoritative
  "occurrences": N,            // Agent #2 only — how many times the pattern repeats
  "files": ["path1", "path2"]  // Agent #2 only — all files where it occurs
}]
```

---

**Agent #3: UI Quality & Performance**

Scan `lib/features/**/presentation/`, `lib/core/widgets/` for:

- **Missing const:** Constructors on stateless widgets with no mutable fields; widget instances where all args are compile-time constants
- **RTL breakage:** `EdgeInsets.only(left:/right:)` or `Padding` with `left:`/`right:` must be `EdgeInsetsDirectional.only(start:/end:)`. Remove any `context.isArabic` ternaries that exist solely for layout spacing (keep `context.isArabic` only for locale-specific content logic like conditional text or formatting)
- **Rebuild scoping — `BlocBuilder` without `buildWhen`** on cubits with 3+ state fields or multiple sealed variants. Should use `BlocSelector<C, S, T>` on a narrow slice, or add `buildWhen`.
- **Rebuild scoping — wide `BlocBuilder` subtree:** builder returning >30 lines or wrapping >5 direct children — rebuild scope too broad; extract the reactive leaf into its own widget so siblings stay `const`.
- **Side effects in `builder`:** `BlocBuilder`/`BlocConsumer.builder` that calls `showSnackBar`, `Navigator.push`, `showDialog`, `CustomSnackBar.*`, or any method with a side effect. Must move to `BlocListener`.
- **`BlocConsumer` with trivial builder:** `BlocConsumer` where the builder ignores state or returns a `const`/static widget — should be plain `BlocListener`.
- **Missing state equality:** State classes that don't extend `Equatable` (or omit fields from `props`) — breaks `buildWhen`/`BlocSelector` because every emit looks "changed".
- **Non-`const` leaves inside `BlocBuilder`:** Widgets inside a reactive subtree whose args are all compile-time constants but aren't marked `const` — they rebuild on every emit for no reason.
- **`context.watch`/`context.read` misuse:** `watch` called inside `onPressed`/callbacks (should be `read`); `read` used where the widget needs to react to changes (should be `watch`/`BlocSelector`).
- **Duplicate state:** `setState` in a `StatefulWidget` for data that is already in a cubit in the same scope.
- **Ephemeral UI state in cubit:** Text field focus, expand/collapse toggles, hover, local animation state, or transient form input living in a cubit instead of local `StatefulWidget`/`ValueNotifier`.
- **Missing `RepaintBoundary`:** List items inside a scrollable that contain images, shadows, gradients, or animations — wrap in `RepaintBoundary` to isolate paint.
- **Extraction by current need:** Inline widget subtree that meets ANY of (a) used 2+ times in the file, (b) >40 lines / >3 parameters / has its own state, (c) has a clear conceptual name (e.g. `PropertyCard`, `StatusBadge`), (d) sits inside a `BlocBuilder` and extracting it would narrow the rebuild. Extract into a named widget in the feature's `presentation/widgets/`. Do NOT flag small 5-line subtrees just because "they might be reused" — extract by current need, not imagined future reuse.
- **Promotion to `core/widgets/`:** Feature-scoped widget used by a second feature (checked via Agent #2). Promote only on the second real usage, and only if it has zero feature-specific imports (no entities, no cubits, no hardcoded strings/colors).
- **Deep widget trees:** More than 5 nested levels without extraction into a named widget
- **Logic in build():** API calls, data transformations, or business logic inside `build()` methods
- **Missing state handling:** `BlocBuilder`/`BlocConsumer` that don't handle loading, error, or empty states

Return findings as JSON array:
```json
[{
  "id": "A<n>-<index>",        // e.g. "A1-001" — REQUIRED, globally unique (see ID scheme above)
  "file": "path",
  "line": N,
  "issue": "...",
  "fix": "...",
  "severity": "critical|warning|suggestion",
  "effort": "S|M|L",           // S = <15 min, M = 15–60 min, L = >1 hour
  "risk": "high|medium|low",   // impact on users / correctness if not fixed
  "autoFixable": true|false    // hint only — Step 5 auto-fix list is authoritative
}]
```

---

**Agent #4: Convention & Consistency**

Scan `lib/features/`, `lib/app/routes/`, `lib/core/` for:

- **Naming mismatches:** File name doesn't match the primary class it contains (e.g., `contact_cubit.dart` should contain `ContactCubit`)
- **Folder structure deviations:** Features missing required subdirectories: `data/datasources/remote/`, `data/models/`, `data/repositories/`, `domain/entities/`, `domain/repositories/`, `domain/usecases/`, `presentation/manager/`, `presentation/pages/`
- **Enum localization:** Every enum used in UI must have a `.localized()` extension
- **Enum colors:** Every status/type enum displayed in badges must have a `.color` getter
- **Hardcoded routes:** Route strings must use `AppRoutes.*` constants, no inline `'/crm'` etc.
- **resolveDisplay():** Nullable display values must use `resolveDisplay()`, not inline `?? ''` or `?? 'N/A'`
- **Error display:** User-facing errors must use `CustomSnackBar`, not `ScaffoldMessenger` directly
- **Localization access:** Must use `S.current` (not `S.of(context)`). Flag any Arabic/English user-facing string literals in dart files that should use `S.current`.
- **Model serialization:** `fromJson`/`toJson` must be manual, no code generation annotations

Return findings as JSON array:
```json
[{
  "id": "A<n>-<index>",        // e.g. "A1-001" — REQUIRED, globally unique (see ID scheme above)
  "file": "path",
  "line": N,
  "issue": "...",
  "fix": "...",
  "severity": "critical|warning|suggestion",
  "effort": "S|M|L",           // S = <15 min, M = 15–60 min, L = >1 hour
  "risk": "high|medium|low",   // impact on users / correctness if not fixed
  "autoFixable": true|false    // hint only — Step 5 auto-fix list is authoritative
}]
```

---

### Step 2b — Merge and Failure Handling (Orchestrator)

After the 4 Sonnet agents return, the orchestrator (the main conversation) performs these steps locally — no additional agents:

1. **Merge** — concatenate `F = F₁ ∪ F₂ ∪ F₃ ∪ F₄` into a single `findings` array. IDs are already globally unique due to the `A1-`/`A2-`/`A3-`/`A4-` prefix scheme.
2. **Validate IDs** — every finding must have a unique `id` string. If duplicates or missing IDs are found, assign a fallback `id` of the form `"A<n>-F<sequence>"` and log a warning. Do NOT silently drop findings.
3. **Failure handling** — if one or more of the 4 Sonnet agents fails, errors, or returns empty/malformed JSON:
   - Continue with the results from the remaining agents.
   - Mark the failed category in the report's Category Breakdown with `⚠ incomplete — agent failed` and set its counts to `—`.
   - Do NOT abort the run. Step 7 summary must call out which categories ran clean vs. which were incomplete.
4. **Pass `findings` to Step 3.**

### Step 3 — Confidence Score Each Finding (Parallel Haiku Agents)

For each finding from Step 2b, launch **Haiku** agents in parallel. Each agent:

1. Reads the actual file and surrounding context (10 lines above/below)
2. Checks the finding against CLAUDE.md and `.claude/rules/*.md`
3. Scores confidence 0-100:

| Score | Meaning |
|-------|---------|
| 0     | False positive. Does not survive scrutiny, or pre-existing accepted pattern |
| 25    | Might be real, might be noise. Stylistic, not in project rules |
| 50    | Real but minor. Nitpick-level, low impact |
| 75    | Verified real issue. Impacts quality or functionality. Violates project rules |
| 100   | Confirmed critical. High frequency, directly violates CLAUDE.md or architecture |

**Batching:** merge findings into batches of up to 10, passing each batch to one Haiku agent. The agent MUST echo back the finding's `id` string (not a positional index) in its output:

```json
[{ "id": "A1-003", "score": 75, "reason": "..." }]
```

**Join rule:** the orchestrator joins scores onto findings by `id`. If any `id` from the input batch is missing in the output, treat its score as `0` (discard) and log a warning. If any `id` in the output does not match a known finding, ignore it.

**Failure handling:** if a Haiku batch fails or returns malformed JSON, re-dispatch that specific batch up to 2 retries. If it still fails, default those findings' scores to `50` (Suggestion) and note `scoringFailed: true` on each — they will still appear in the report but at the lowest classified severity.

### Step 4 — Filter, Classify, and Compute Health Score

**Classification:**
- Score < 50: **discard** (do not report)
- Score 50-79: classify as **Suggestion** 🔵
- Score 80-99: classify as **Warning** 🟡
- Score 100: classify as **Critical** 🔴

**Health score (0–100):**

```
score  = max(0, 100 - (10 * criticalCount + 3 * warningCount + 1 * suggestionCount))
```

**Grade mapping:**

| Score  | Grade | Label     |
|--------|-------|-----------|
| 90–100 | **A** | Excellent |
| 75–89  | **B** | Good      |
| 60–74  | **C** | Fair      |
| 40–59  | **D** | Poor      |
| 0–39   | **F** | Critical  |

**Hotspots:** group findings by `file` and sort descending by count. Top 5 files become the "Hotspots" list in the report.

**Trend (if prior report exists):** if `docs/reviews/` contains a previous `*-health-check.md`, compute `newFindings = currentFindings - previousFindings` (by file+line+issue key) and `resolvedFindings = previousFindings - currentFindings`. Include `Δ` deltas in the summary table.

### Step 5 — Apply Fixes

Fixes MUST be applied before the report is written (Step 6) so the report can accurately count auto-fixed items and list them.

**Auto-fix eligibility — Step 5's rule list is authoritative.** An audit agent's `autoFixable: true` hint is NOT sufficient on its own. A finding is auto-fixed only if ALL the following hold:
- Confidence score ≥ 80 (Warning or Critical)
- The fix matches one of the rules in the "Auto-fix" list below (literal match, not a paraphrase)
- Applying the fix is mechanically safe and individually reversible via git

If an agent marks `autoFixable: true` for a rule not in the list, treat it as `autoFixable: false` and route it to the "Ask approval first" flow instead. Conversely, if the agent marks `autoFixable: false` for a rule that IS in the list, trust the agent and ask approval.

**Auto-fix (no approval needed)** — low-risk, mechanical, score >= 80 (Warning + Critical only; Suggestions are never auto-fixed):
- Add missing `const` keywords (including `const` leaves inside `BlocBuilder` subtrees)
- `EdgeInsets.only(left: X, right: Y)` --> `EdgeInsetsDirectional.only(start: X, end: Y)`
- Remove `context.isArabic` ternaries that only guard layout spacing
- Add missing `if (isClosed) return;` before `emit()`
- Replace `S.of(context)` with `S.current`
- Replace hardcoded route strings with `AppRoutes.*`
- Replace `?? ''` on display values with `resolveDisplay()`
- Convert `BlocConsumer` with trivial/ignored builder --> `BlocListener`

**Ask approval first** — structural, high-risk, or requiring judgement:
- Convert `BlocBuilder` --> `BlocSelector` (requires picking the slice and verifying rebuild intent)
- Split a wide `BlocBuilder` into narrower `BlocBuilder`s / `BlocSelector`s
- Move side-effect calls (`CustomSnackBar.*`, `Navigator.push`, `showDialog`) out of `BlocBuilder.builder` into a sibling `BlocListener` — requires picking the correct `listenWhen` predicate; wrong predicate = snackbar fires on every rebuild or never fires
- Swap `context.watch` --> `context.read` inside callbacks — subtle correctness risk (stale closure, missed rebuild); needs case-by-case review
- Extract a reactive subtree into a new named widget in `features/<name>/presentation/widgets/`
- Promote a feature widget --> `core/widgets/` (only on verified second-feature usage, zero feature-specific imports)
- Add `Equatable` to a state class and populate `props` (risk: changes equality semantics elsewhere)
- Move ephemeral UI state (focus, toggles, transient form input) out of a cubit into local `StatefulWidget`/`ValueNotifier`
- Move legacy enum extension files from `domain/entities/extensions/` to `presentation/utils/`
- Move or rename files
- Restructure state classes (`abstract` --> `sealed`)
- Extract duplicated form sections into shared components
- Change DI registration type (e.g., LazySingleton --> Factory)

For approval items, present:
1. What will change and why
2. Before/after code snippets
3. All affected files

Wait for user response. Apply only approved changes. Record applied changes (both auto-fixed and approved) for Step 6.

### Step 6 — Write Report

Save to `docs/reviews/YYYY-MM-DD-health-check.md`. Use severity emojis (🔴 Critical, 🟡 Warning, 🔵 Suggestion), risk emojis (🟥 High, 🟧 Medium, 🟩 Low), and effort labels (S / M / L).

Findings within each category must be **sorted by severity DESC, then risk DESC, then file path ASC** so the most urgent items sit at the top.

**File path hyperlinks (required):** Every file path in the report must be a clickable markdown link. The report lives at `docs/reviews/`, so the relative path to `lib/` is `../../lib/`. Use this format:

- Single file with line number: `` [`lib/path/to/file.dart:LINE`](../../lib/path/to/file.dart#LLINE) ``
- Single file without line number: `` [`lib/path/to/file.dart`](../../lib/path/to/file.dart) ``
- Short display name with full path: `` [`filename.dart`](../../lib/full/path/to/filename.dart) ``
- Directory (no link): leave as plain backtick `` `lib/features/splash/domain/` ``

Always use the full `lib/...` path in the link target, even when the display text is abbreviated.

```markdown
# 🩺 Codebase Health Check — YYYY-MM-DD

> **Scope:** full | feature `<name>` | branch `<branch>`
> **Files scanned:** N
> **Branch:** <current-branch>  •  **Generated:** YYYY-MM-DD HH:MM

---

## 📊 Executive Dashboard

| Metric          | Value                                |
|-----------------|--------------------------------------|
| **Health score**| **NN / 100** — **Grade X** (Label)   |
| Files scanned   | N                                    |
| Total findings  | N (after filter, score ≥ 50)         |
| Auto-fixed      | N                                    |
| Needs approval  | N                                    |
| Trend vs last   | ▲ new: N · ▼ resolved: N · ● same: N |

### Severity breakdown
| Severity         | Count | Δ vs last |
|------------------|-------|-----------|
| 🔴 Critical      | N     | ±N        |
| 🟡 Warning       | N     | ±N        |
| 🔵 Suggestion    | N     | ±N        |
| ✅ Auto-fixed    | N     | —         |

### Category breakdown
| Category                  | 🔴 | 🟡 | 🔵 | Total |
|---------------------------|----|----|----|-------|
| Architecture & DI         | N  | N  | N  | N     |
| Reusability & Duplication | N  | N  | N  | N     |
| UI Quality & Performance  | N  | N  | N  | N     |
| Convention & Consistency  | N  | N  | N  | N     |

### 🔥 Hotspot files (most findings)
| # | File | Findings | Top severity |
|---|------|----------|--------------|
| 1 | [`lib/features/crm/.../file.dart`](../../lib/features/crm/.../file.dart) | N | 🔴 |
| 2 | ... | ... | ... |
| 3 | ... | ... | ... |
| 4 | ... | ... | ... |
| 5 | ... | ... | ... |

---

## 🗂 Findings

### Architecture & DI

| Sev | Risk | Effort | Auto | Location | Issue | Fix |
|-----|------|--------|------|----------|-------|-----|
| 🔴  | 🟥   | S      | ✅    | [`lib/path/to/file.dart:LINE`](../../lib/path/to/file.dart#LLINE) | short description | short direction |
| 🟡  | 🟧   | M      | —    | [`lib/path/to/file.dart:LINE`](../../lib/path/to/file.dart#LLINE) | ...   | ... |
| 🔵  | 🟩   | S      | —    | [`lib/path/to/file.dart:LINE`](../../lib/path/to/file.dart#LLINE) | ...   | ... |

### Reusability & Duplication

| Sev | Risk | Effort | Occurrences | Files | Issue | Fix |
|-----|------|--------|-------------|-------|-------|-----|
| 🟡  | 🟧   | M      | 4           | [`a.dart`](../../lib/full/path/a.dart), [`b.dart`](../../lib/full/path/b.dart), `+2` | duplicated address form | extract `AddressFormSection` into `core/widgets/` |

### UI Quality & Performance

| Sev | Risk | Effort | Auto | Location | Issue | Fix |
|-----|------|--------|------|----------|-------|-----|
| ... | ...  | ...    | ...  | ...      | ...   | ... |

### Convention & Consistency

| Sev | Risk | Effort | Auto | Location | Issue | Fix |
|-----|------|--------|------|----------|-------|-----|
| ... | ...  | ...    | ...  | ...      | ...   | ... |

---

## 🎯 Top Refactors (sorted by impact / effort ratio)

| # | Refactor | Risk | Effort | Impact | Affected files |
|---|----------|------|--------|--------|----------------|
| 1 | Name & one-line intent | 🟥 | L | High | [`a.dart`](../../lib/full/path/a.dart), [`b.dart`](../../lib/full/path/b.dart), `+N` |
| 2 | ... | ... | ... | ... | ... |
| 3 | ... | ... | ... | ... | ... |

---

## ✅ Auto-Fixed Changes (N)

| File | Line | Rule applied |
|------|------|--------------|
| [`lib/path/to/file.dart`](../../lib/path/to/file.dart) | L | `const` added on reactive leaf |
| [`lib/path/to/file.dart`](../../lib/path/to/file.dart) | L | `S.of(context)` → `S.current` |
| ...    | ... | ... |

---

## 👍 What's Done Well
- Bullet list of architectural strengths and good patterns observed.

---

## ⚙ Legend
- **Severity:** 🔴 Critical (score 100) · 🟡 Warning (80–99) · 🔵 Suggestion (50–79)
- **Risk:** 🟥 High (user-visible or correctness) · 🟧 Medium (maintainability) · 🟩 Low (polish)
- **Effort:** S (<15 min) · M (15–60 min) · L (>1 hour)
- **Auto:** ✅ applied in Step 5 · — requires manual work
```

### Step 7 — Print Inline Summary

Output to conversation. Keep it short — details live in the report file.

```
🩺 Health Check Complete — Grade **X** (NN / 100)

Scope: <full | feature:<name> | branch:<branch>>   Files scanned: N

| Severity      | Count | Δ |
|---------------|-------|---|
| 🔴 Critical   | N     | ±N |
| 🟡 Warning    | N     | ±N |
| 🔵 Suggestion | N     | ±N |
| ✅ Auto-fixed | N     | — |

Categories: Arch N · Reuse N · UI N · Convention N
Hotspots: file_a (N)  ·  file_b (N)  ·  file_c (N)

🎯 Top 3 Refactors
1. <name>  — 🟥 High · L · files: N
2. <name>  — 🟧 Med  · M · files: N
3. <name>  — 🟩 Low  · S · files: N

✅ Auto-Fixed (N)
- <file:line> — <rule>
- <file:line> — <rule>
  (+N more — see full report)

📄 Full report: docs/reviews/YYYY-MM-DD-health-check.md
```

---

## Rules

- Do NOT run `flutter analyze`, `flutter test`, or any build commands. This is a static-reading-only audit.
- Do NOT flag issues that linters or compilers would catch (import errors, type errors, formatting).
- Pre-existing patterns that are intentionally accepted and work may be downgraded to **Suggestion** severity (e.g., `abstract class HomeState`) — do NOT flag as Critical or Warning unless the pattern is being newly introduced on this branch.
- Each sub-agent must read actual file contents, not guess from file names.
- All auto-fixes must be individually reversible via git.
- When in doubt about a finding's validity, score it lower rather than higher.
