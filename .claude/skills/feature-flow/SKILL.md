---
name: feature-flow
description: Entry point for any non-trivial feature — invoke this BEFORE superpowers:brainstorming. Runs brainstorm, grill, model, shape, Goldfish-review the spec (EGM), plan, Goldfish-review the plan, build, review, verify. Not for mechanical edits or bugfixes.
user-invocable: true
argument-hint: "<feature description>"
---

# Feature Flow

Run these in order with the Skill tool, except the EGM steps (see below). Announce each step as you enter it. Paths are relative to the repo root.

| # | Step | Skill |
|---|---|---|
| 1 | Frame the intent, write the spec | `superpowers:brainstorming` |
| 2 | Stress the assumptions | `mattpocock-skills:grilling` |
| 3 | Name the domain | `mattpocock-skills:domain-modeling` |
| 4 | Place the seams | `mattpocock-skills:codebase-design` |
| 5 | Goldfish the spec | EGM `egm-review` |
| 6 | Plan | `superpowers:writing-plans` |
| 7 | Goldfish the plan | EGM `egm-review-loop` |
| 8 | Build, task by task | `superpowers:executing-plans` |
| 9 | Review — each task, then the branch | `mattpocock-skills:code-review` |
| 10 | Verify | `superpowers:verification-before-completion` |

## Skip rules

- Run steps 2–5 and 7 only when the feature touches 3+ files or crosses a layer; otherwise skip them. A new field on an existing screen skips them. Step 3 additionally requires a genuinely new noun/concept.
- Skip steps 5 and 7 when step 8 has already started — a review of a built plan reports drift, not design gaps.
- Bugfixes skip steps 1–8: `mattpocock-skills:diagnosing-bugs`, then TDD, then steps 9–10.

## Handoffs come back here

These override the superpowers skills' own handoffs:
- `brainstorming` hard-gates into `writing-plans` and commits the spec. Do neither — return here for steps 2–5.
- `writing-plans` ends by offering to execute. Don't — return here for step 7.
- `executing-plans` runs every task without stopping and reviews only at the end. Instead, after each task run step 9 on its diff, then stop (see Step 8 checkpoint).

## Step 4 feeds step 6

The seams `codebase-design` settles become the task boundaries in the plan. Carry them across explicitly; do not let `writing-plans` re-derive its own decomposition.

## Artifacts

- Spec (step 1) → `docs/superpowers/specs/YYYY-MM-DD-<feature>-design.md`
- Plan (step 6) → `docs/superpowers/plans/YYYY-MM-DD-<feature>.md`
- EGM reports → `docs/reviews/egm/<spec date>-<feature>/spec/` (step 5) and `.../plan/` (step 7)

Specs and plans are committed with the feature. EGM reports are local review artifacts; don't commit them.

## Steps 5 and 7: EGM

EGM skills set `disable-model-invocation`, so the Skill tool refuses them. Run them by reading:

1. Resolve the root: `jq -r '.plugins["egm@egm"][0].installPath' ~/.claude/plugins/installed_plugins.json`. Skip steps 5 and 7, and say why, when that fails or prints `null`, when `enabledPlugins["egm@egm"]` in `~/.claude/settings.json` is not `true`, or when this thread has no Agent tool.
2. Read `<root>/docs/claude.md`, then `<root>/skills/<skill>/SKILL.md`, and follow it in this thread — the same way for every EGM skill it hands off to (`egm-review-loop`, `egm-resolve`). Resolve `${CLAUDE_PLUGIN_ROOT}` and every `agents/`, `resources/`, `docs/` path in EGM files against `<root>`.
3. Pass every path to EGM as absolute. Before the step starts, state `EGM artifact directory: <absolute reports folder>` in chat. It covers every EGM write, by this thread and by any `egm-synthesizer` (name it in the synthesizer's task).
4. GoldfishContext, both steps: `CLAUDE.md`, `.claude/rules/`, and every local doc the target cites by path.
5. EGM's chat rules end at the step's final gate; then return to this skill.

Step 5 — `egm-review`:
- TargetFile: the spec
- Step: `feature_spec` (EGM stages 5–8)
- Linked files: include in-repo links; leave out every URL and outside link without asking
- Done when the Stage 8 gate is passed

Step 7 — `egm-review-loop`, called directly with its own reviewers for plans. Plans use `### Task N` headings with no `## Implementation Plan` header, so `egm-review` would find no plan range.
- TargetFile: the plan; GoldfishContext adds the spec
- SemanticTarget: `full file`
- Reviewers: `implementation_readiness`, `codebase_details`, each against `implementation-readiness-standard`
- Inputs are fixed here: skip the confirmation prompt and the closing question
- Done when the loop converges, or the owner accepts the open findings at the cap

## Step 8 checkpoint

A task is done when its implementation, its review, and its ledger entry are all complete. At that point summarize the commit SHA, test result, and review verdict, then ask before starting the next task. Never chain tasks.

Use `superpowers:test-driven-development` inside each task.

## Step 9 inputs

Pass `code-review` both:
- the base ref — the task's base commit at a per-task checkpoint, or the merge-base with `main` at the end
- the spec path from step 1, for its Spec axis

## Step 10 commands

```bash
dart format <branch-touched .dart files>
flutter analyze --no-fatal-infos
flutter test
```

Compare against `main`: a failure that `main` doesn't have is a regression, not noise. The test count changes per branch; never quote one from memory. Quote real output before claiming done.

## Settled overlaps

Do not re-open these. They also win over the routes inside `executing-plans`.
- TDD → `superpowers:test-driven-development` (not Matt's)
- Debugging → `mattpocock-skills:diagnosing-bugs` (not `superpowers:systematic-debugging`)
- Review → `mattpocock-skills:code-review` (not `superpowers:requesting-code-review`, not EGM — EGM reviews documents, never code)
- Workspace → a branch checkout (not `superpowers:using-git-worktrees`)
- Brainstorm → `superpowers:brainstorming` (not `egm-brainstorm`)
- Spec and plan writing → `brainstorming` + `writing-plans` (not `egm-draft`)
- Spec vs code → `code-review`'s Spec axis (not `egm-drift-report`)
