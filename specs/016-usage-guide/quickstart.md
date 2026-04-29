# Quickstart: Verifying Feature 016

**Feature**: 016-usage-guide
**Date**: 2026-04-28
**Purpose**: End-to-end verification that the four artifacts (pitch, guide, doc-qa, impl-qa) plus the repository wiring work together. This is what a reviewer (human or AI) walks through before approving the feature for merge.

The steps below are in order. Steps 1–6 are mandatory. Step 7 (reader walkthrough) is the SC-001 / SC-007 check; it can be done by a fresh reader or by the user-qa agent simulating one. Step 8 is structural and required before merge.

---

## Prerequisites

- On branch `016-usage-guide`.
- All four artifacts written: `docs/pitch.md`, `docs/usage-guide.md`, `.claude/agents/doc-qa.md`, `.claude/agents/impl-qa.md`.
- Slash-command shims at `.claude/commands/doc-qa.md`, `.claude/commands/impl-qa.md`.
- `CLAUDE.md` Definition-of-Done section updated.
- `README.md` links updated.
- The two stale `docs/superpowers/…` files relocated to `specs/011-eidos-sdk-and-installable-cli/`.

---

## Step 1 — Doc-QA against the v1 pitch + guide (expect PASS)

```
/doc-qa
```

(or invoke the subagent directly with `docs/pitch.md` + `docs/usage-guide.md`.)

**Expected**: Verdict line is `PASS`. Each tier shows `[PASS]`.
**On FAIL**: Read the `[FAIL]` lines. Either the guide drifted from the pitch (fix the guide) or the pitch is internally inconsistent (fix the pitch). Iterate until PASS before moving on.
**Records**: capture wall-clock time. Should be ≲10s per D-009.

---

## Step 2 — Inject a vision-level drift, expect doc-qa Tier-1 FAIL

In a temporary worktree (or a discardable branch):

1. Edit `docs/pitch.md` to add a non-goal line that contradicts a real guide section. For example, append a line to the pitch's "What Eidos is *not*" section:
   > Eidos is not a tool for translating finished works.

2. Re-run `/doc-qa`.

**Expected**: Verdict is `FAIL — 1 Tier-1 failure, 0 Tier-2 failures, 0 Tier-3 failures`. The Tier-1 finding cites both the new pitch line and the guide's "Translating your world" section.

**Reset**: revert the pitch edit before continuing.

This step demonstrates SC-009 + SC-010 — vision-alignment failures surface from text-comparison alone, with no agent-config change.

---

## Step 3 — Impl-QA default mode, expect PASS

```
/impl-qa
```

**Expected**: Verdict is `PASS`. Tier 2 shows `Skipped (default mode — pass --behavioral to enable)`. Tier 3 may report some `[INFO]` items (undocumented surface — those are the DDD backlog, not failures). Tier 4 shows no items (v1 has no aspirational sections).

**Records**: capture Tier-3 `[INFO]` count. This is the seed for feature 017's "what to remove or document" worklist. Capture wall-clock time (target ≲15s).

---

## Step 4 — Inject a CLI drift, expect impl-qa Tier-1 FAIL

In a discardable branch:

1. Edit `docs/usage-guide.md` to reference a flag that doesn't exist (e.g., `eidos produce piece --form-name X` when the real flag is `--form`).

2. Re-run `/impl-qa`.

**Expected**: Verdict is `FAIL — 1 Tier-1 failure, 0 Tier-2 failures`. The Tier-1 finding cites the guide line and the actual codebase flag, with `attribution: guide stale` (since `git log` shows a recent guide edit and no recent codebase edit).

**Reset**: revert the guide edit before continuing.

This step demonstrates SC-002 / SC-006.

---

## Step 5 — Impl-QA `--behavioral` against a fresh world, expect PASS

```
/impl-qa --behavioral
```

The agent scaffolds a fresh world from the guide's "Create your first world" example, runs the documented commands (with `MOCK_AI=true`), and verifies the post-state claims match.

**Expected**: Verdict is `PASS`. Tier 2 shows `[PASS]` for "Create your first world" and "Produce your first piece."

**Records**: capture wall-clock time (target ≲90s under MOCK_AI). If a Tier-2 `[FAIL]` appears, that's a real bug in either the guide or the scaffolding pipeline — root-cause it before merging. The `attribution:` line tells you which side to fix.

This step demonstrates SC-003.

---

## Step 6 — SC-011 structural check (no hardcoded feature names in doc-qa)

Run a grep against the doc-qa agent definition:

```bash
grep -nE 'chapter|piece|world|bible|canon|produce|translate|publish|probe|comic|haiku|vignette' \
  /home/cutalion/code/one-review-man/.claude/agents/doc-qa.md
```

**Expected**: Zero matches outside the `description:` frontmatter examples (which may quote literal *example* user prompts). Any match in instruction prose is a contract violation per FR-DQ-003 / SC-011 — fix by removing the term or rephrasing generically (e.g., replace "the chapter section" with "a guide section that names a specific deliverable type").

This is the single most important code-review check for this feature; a passing grep is the structural guarantee that doc-qa stays adaptive across project pivots.

---

## Step 7 — Reader walkthrough (SC-001 + SC-007)

Hand `docs/usage-guide.md` to a person (or AI agent simulating one) who has never used Eidos. Stopwatch:

- **SC-001 target**: under 15 minutes from "what is this?" to running `eidos world status` and `eidos piece list` against a freshly scaffolded world that contains at least one piece.
- **SC-007 target**: against a fixed list of search goals (e.g., "How do I translate to Russian?", "How do I undo a canon change?", "How do I publish my world?", "How do I add a custom form?"), the reader finds the relevant section from the TOC in under 30 seconds *each*, four for four.

**Records**: capture both times. If SC-001 exceeds 15 minutes, the guide's first three sections need tightening. If SC-007 fails for any goal, the TOC needs a heading rename or a missing section.

---

## Step 8 — Repository wiring sanity check

Verify these by inspection:

- `README.md` first 20 lines link `docs/pitch.md` (before the guide link) and `docs/usage-guide.md`. Both links resolve.
- `CLAUDE.md` Definition-of-Done section names doc-qa (for any `docs/pitch.md` / `docs/usage-guide.md` change) and impl-qa (for any user-facing CLI / scaffolding / production / guide change), in addition to the existing user-qa requirement.
- `.claude/commands/doc-qa.md` and `.claude/commands/impl-qa.md` exist and dispatch to their respective subagents (mirror `.claude/commands/user-qa.md`'s shape).
- The two stale `docs/superpowers/…` files no longer exist at their original paths; their contents are now under `specs/011-eidos-sdk-and-installable-cli/`.

If any of the above are missing or wrong, fix before merge.

---

## Acceptance summary

The feature is ready to merge when:

| Check | Source |
|---|---|
| Step 1 PASS | doc-qa default run |
| Step 3 PASS | impl-qa default run |
| Step 5 PASS | impl-qa `--behavioral` run |
| Step 6 zero matches | grep against `doc-qa.md` |
| Step 7 within targets | reader walkthrough times |
| Step 8 wiring intact | inspection |

Failed Step 2 (drift not detected) or Step 4 (drift not detected) is also a hard blocker — the verifiers don't actually verify if drift slips past them. Re-do those after fixing the agent.

The PR description MUST include the wall-clock measurements from Steps 1, 3, 5, and 7 — they're the empirical grounding for "fast enough for pre-commit" and the reader-time success criteria.
