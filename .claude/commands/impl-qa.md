---
description: Verify the project's implementation matches what the usage guide claims. Reports surface drift (commands/flags/paths the guide names but the codebase doesn't expose), behavioral drift (post-state mismatches when documented scenarios are run against a fresh artifact directory), undocumented surface (codebase items not mentioned in the guide), and the aspirational-section backlog.
---

## User Input

```text
$ARGUMENTS
```

Arguments are optional. Supported forms:

1. **No arguments** — defaults to `docs/usage-guide.md`, default mode (Tier 1 + Tier 3 + Tier 4 only). No API key required.
2. **`--behavioral`** — adds Tier 2 (live execution against a fresh artifact directory). `MOCK_AI=true` by default.
3. **`--behavioral --live`** — same as `--behavioral` but switches off `MOCK_AI`. Real LLM calls; observed costs apply. The report header carries an explicit warning line.
4. **Custom guide path** — `--guide <path>` (defaults to `docs/usage-guide.md`).
5. **Pre-existing artifact directory** — `-w <path>` (only meaningful with `--behavioral`; otherwise ignored).

If no flags are passed, default mode runs. To get full behavioral coverage, pass `--behavioral`.

## Outline

1. **Parse arguments** into `{guide_path, mode, world_path?}`.
2. **Verify the guide exists.** If missing, stop and ask the user.
3. **Dispatch the impl-qa subagent** via the Task tool. Pass:
   - The guide path.
   - The mode flag.
   - The world path (if provided).
   - The contract reference at `specs/016-usage-guide/contracts/impl-qa-report.md` so the subagent matches the report format exactly.
4. **Wait for the subagent's report.** Relay it to the user verbatim — line numbers, attribution lines, and quoted text are the whole point.
5. **If the report is FAIL**, do NOT start fixing things. Read the `attribution:` lines: each one tells you whether the guide is stale (fix the guide) or the codebase changed (fix the codebase, or update the guide if the codebase change was intentional). Ask the user which findings to address first.
6. **If the report is PASS**, note the Tier 3 / Tier 4 counts. Tier 3 is the undocumented-surface report — items that may need documenting OR removing. Tier 4 is the aspirational-section backlog — items that drive future feature specs.

## Rules

- Impl-qa verifies *guide-to-implementation* consistency. It does not check whether the guide aligns with the project pitch — that is doc-qa's job. Run both before merging changes that touch documentation.
- Tier 3 and Tier 4 are informational. A Tier-3 finding does NOT mean the guide is incomplete and the missing surface should be added — it might mean the codebase has surface that should be removed. The maintainer decides per-item.
- `--behavioral` runs commands against a freshly scaffolded artifact directory by default; existing directories may mask scaffolding regressions. Pass `-w <path>` only when you specifically want to audit a known directory.
- `--behavioral --live` makes real AI calls and incurs cost. Use it only when you specifically need to verify LLM-dependent behavior (most behavioral checks are fine under `MOCK_AI=true`).
- A `FAIL` Verdict is blocking for any change that touches user-facing CLI surface, world scaffolding output, content-production workflow, or the usage guide, per the project Definition of Done.
