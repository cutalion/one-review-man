# Phase 0 Research: Project Pitch + Usage Guide + Doc-QA & Impl-QA Agents

**Feature**: 016-usage-guide
**Date**: 2026-04-28
**Status**: Resolved — no `NEEDS CLARIFICATION` markers remain

The seven clarifications recorded in `spec.md` (Q1–Q5 + Q6 doc-qa-runtime + Q7 pitch-authorship) resolved every spec-level ambiguity. This document captures the design-level decisions the plan depends on, with rationale and rejected alternatives, so the implementer doesn't re-litigate them mid-task.

---

## D-001 — Pitch document outline

**Decision**: Five sections in this order: (1) Elevator pitch (one sentence), (2) Who Eidos is for, (3) The mental model (worlds, pieces, canon, evolution), (4) What Eidos uniquely enables, (5) What Eidos is *not* (the authoritative non-goals list per FR-PA-002). Target length 800–1500 words. No runnable code or shell examples.

**Rationale**: Maps 1:1 to FR-PA-002's required content. Pitch needs to read in well under five minutes (FR-PA-001). The five-section structure is the smallest split that lets doc-qa Tier 1 cite "the pitch's non-goals say X, the guide section Y assumes the opposite" — a single-blob pitch is harder for the agent to anchor against.

**Alternatives considered**:
- Longer "manifesto" form (~3000 words). Rejected: violates the under-five-minutes target; readers skip it.
- Pure non-goals list ("here's what Eidos is *not*"). Rejected: doesn't give doc-qa enough positive material to compare the guide against.
- Single elevator paragraph. Rejected: too thin for vision-alignment checks; agent would have nothing to cite.

---

## D-002 — Usage guide table of contents

**Decision**: Top-level sections are user-task-named (FR-002), in roughly this order: "Get oriented" (glossary, mental model, what Eidos is *not*), "Create your first world," "Produce your first piece," "Inspect what just happened," "Evolving your world" (canon review, branching, regeneration), "Translating your world," "Publishing as a website," "Power-user techniques" (custom forms, model probing, the SDK), "Working offline / cheaply" (`MOCK_AI`, `--debug`), "Troubleshooting." All workflows from FR-003 covered; no Thor-namespace headings.

**Rationale**: Minimal coherent ordering: orient → first run → introspect → day-2 → distribution → escape hatches → support. Every cross-reference can resolve forward-only without circular "see also" chains, which simplifies doc-qa's internal-consistency check.

**Alternatives considered**:
- CLI-namespace TOC (one chapter per Thor command group). Rejected: violates FR-002, and produces a doc that reads like a man-page index.
- "Day-1 / Day-2 / Day-3" framing. Rejected: temporal framing doesn't match how creators actually use it (they jump between branches, translation, and bible browsing on day 1 already).
- One big chapter per workflow with subsections per command. Rejected: too coarse — readers searching for "how do I undo" need to land on a subsection in <30s (SC-007).

---

## D-003 — Aspirational-marker syntax

**Decision**: A single Markdown blockquote line placed *immediately* under the section heading (H2 or H3), with this exact form:

```markdown
## Section Title

> 🚧 **Not yet implemented** — describes the desired user experience; implementation tracked in spec NNN-name (or "tracked separately").
```

Detection regex (used by both agents): `^>\s*🚧\s*\*\*Not yet implemented\*\*` matched against the line *immediately* after a heading, ignoring blank lines.

**Rationale**:
- Visible to a human skimming the rendered guide (FR-007a).
- Machine-detectable with a stable regex — no false positives from unrelated blockquotes elsewhere in the document.
- Section-header metadata (e.g., HTML comments or YAML frontmatter mid-document) ruled out: Markdown doesn't propagate frontmatter into mid-doc sections, and HTML comments fail the "visible to a human skimmer" requirement.
- Putting the marker *under* the heading rather than in the heading itself keeps the heading text clean and TOC-friendly.

**Alternatives considered**:
- HTML comments (`<!-- aspirational -->`). Rejected: invisible when rendered.
- Heading suffix (`## Section Title 🚧`). Rejected: pollutes the TOC and breaks anchor URLs when the marker is removed.
- A separate `aspirational.yml` file listing aspirational sections by heading. Rejected: introduces a second source of truth that can drift from the document itself.

---

## D-004 — Doc-qa subagent prompt structure

**Decision**: The `.claude/agents/doc-qa.md` file mirrors `.claude/agents/user-qa.md`'s frontmatter (`name`, `description` with example invocations, `model: sonnet`, `color`). Body is a system-prompt-style instruction set with these labeled blocks:
1. **Inputs** — pitch path, guide path; nothing else.
2. **Tools available** — `Read`, `Glob`, `Grep` only (no `Bash`, no codebase inspection).
3. **What you check** — three tiers (Vision Alignment, Internal Consistency, Pitch Self-Consistency) with worked examples for each.
4. **Hard rules** — including the explicit "you carry no hardcoded knowledge of specific feature names, command names, or 'known-deprecated' surface" clause (FR-DQ-003 / SC-011).
5. **How you report** — references `contracts/doc-qa-report.md`.

**Rationale**: User-qa's structure is proven; mirroring it lowers the cognitive cost for maintainers who already know that agent. Restricting tool access to `Read`/`Glob`/`Grep` enforces FR-DQ-004 mechanically — the agent literally cannot inspect Ruby code or run worlds even if its prompt were vague about that boundary.

**Alternatives considered**:
- Granting `Bash` in case the agent needs to dump help text. Rejected: that's impl-qa's job; granting it to doc-qa blurs the split this entire spec was rewritten around.
- Decomposing into three sub-agents (one per tier). Rejected: massive overhead for a sub-second-difference reporting flow.

---

## D-005 — Impl-qa subagent prompt structure

**Decision**: Mirrors `user-qa.md` frontmatter shape. Body has:
1. **Inputs** — guide path; optional world path or scaffold-from-guide directive.
2. **Tools available** — `Read`, `Glob`, `Grep`, `Bash` (Bash needed for `eidos --help` dumps and `--behavioral` world execution).
3. **What you check** — four tiers (Surface Accuracy / Behavioral Accuracy / Undocumented Surface / Backlog) with worked examples.
4. **Mode flags** — default invocation runs Tier 1 + 3 + 4 (static, no API key); `--behavioral` adds Tier 2; `--behavioral --live` switches off `MOCK_AI=true`.
5. **Hard rules** — drift attribution (don't silently blame one side); MOCK_AI default for Tier 2; never modify files.
6. **How you report** — references `contracts/impl-qa-report.md`.

**Rationale**: Mirrors user-qa's posture (drives the CLI, reads files, never modifies). The four-tier structure plus the mode-flag block makes the agent's behavior explicit and matches FR-IQ-003 / FR-IQ-005.

**Alternatives considered**:
- Single-mode invocation (no `--behavioral` flag, always run all tiers). Rejected: violates FR-IQ-005 (no API key default) and SC-002/006 (must be cheap enough for pre-commit).

---

## D-006 — Report formats

**Decision**: Markdown output mirroring `user-qa.md`'s report shape:
- Header: world / artifact paths + intent restatement (one line each).
- Per-tier blocks with `[PASS]` / `[FAIL]` bullets carrying file path, line number, quoted text from each side, and a one-line explanation.
- Verdict line: PASS / FAIL with counts per tier.
- Root-cause candidates section (bullet list of best-guess root causes).

**Rationale**: Human-readable matters more than machine-parseable for a pre-commit check. Markdown is greppable enough that downstream tools (a future CI integration, a `babysit` agent) can extract structure if needed. JSON output rejected — humans skim Markdown faster, and mistake-finding is the dominant use case.

**Alternatives considered**:
- JSON or structured YAML output. Rejected: optimizes for the wrong consumer (agent → human, not agent → tool).
- Plain text with no structure. Rejected: no anchor for "click on the line number to jump."

---

## D-007 — CLAUDE.md Definition-of-Done patch

**Decision**: Extend the existing "Definition of Done" section to add two lines (similar prose style to the existing user-qa requirement):

> Before declaring complete any change that modifies `docs/pitch.md` or `docs/usage-guide.md`, you MUST run `/doc-qa` and confirm a PASS verdict. Tier-1 failures are blocking.
>
> Before declaring complete any change that modifies user-facing CLI surface, world scaffolding output, content-production workflow, or the usage guide, you MUST run `/impl-qa` (default mode for static drift; add `--behavioral` for any change to scaffolding or production) and confirm a PASS verdict.

**Rationale**: Maintains symmetry with the existing user-qa requirement. Two short prose paragraphs rather than a table makes the rule discoverable when scanning CLAUDE.md.

**Alternatives considered**:
- Replace the user-qa requirement entirely. Rejected: user-qa serves a distinct purpose (verifying *generated worlds* against *user intent*); not redundant with either new agent.

---

## D-008 — README.md ordering

**Decision**: Within the first 20 lines of the README, add (in this order): a one-sentence project description, a "Read the pitch" link to `docs/pitch.md`, a "Read the usage guide" link to `docs/usage-guide.md`. The pitch link comes first per FR-PA-004.

**Rationale**: A new visitor must reach the pitch in one click (FR-PA-004) and the guide in one click (FR-001). Putting both within the first 20 lines satisfies both at minimum cost.

**Alternatives considered**:
- Bury the links in a "Documentation" section at the bottom. Rejected: violates the one-click reach requirement.
- Inline the pitch as the README's intro. Rejected: README is contributor-facing too; the pitch is end-user-facing — they can drift, and we want each to have its own source of truth.

---

## D-009 — Performance budget validation

**Decision**: Measure observed wall-clock latency for one default doc-qa run, one default impl-qa run, and one `--behavioral` impl-qa run during `quickstart.md` verification. Record the measurements in the eventual PR description. No hard SLA asserted in the spec.

**Rationale**: "Fast enough for pre-commit" is the qualitative target; encoding a numeric SLA risks brittleness without buying anything. If observed latencies exceed ~30s for static modes, treat as a design feedback signal in a follow-up.

**Alternatives considered**:
- Hard SLA in spec (e.g., <5s static). Rejected: speculative without data.
- No measurement at all. Rejected: leaves the PR description without grounding for "fast enough."

---

## D-010 — Cleanup of pre-existing `docs/` files

**Decision**: Move the two untracked archived files from `docs/superpowers/` into `specs/011-eidos-sdk-and-installable-cli/legacy-design.md` and `legacy-plan.md`. Do not delete — they were design artifacts for a closed feature and have historical value. Update any references inside them to reflect the new path.

**Rationale**: Preserves history adjacent to its spec, where future readers will look for it. Keeps `docs/` clean as the new home for end-user-facing documentation.

**Alternatives considered**:
- Delete outright. Rejected: throws away historical context for no real benefit.
- Leave in place. Rejected: pollutes `docs/` and makes the new artifacts harder to find.

---

## D-011 — Doc-qa "no hardcoded feature names" enforcement mechanism

**Decision**: The constraint is enforced at three layers:
1. **Prompt-level**: an explicit "Hard rules" line in `.claude/agents/doc-qa.md` forbidding any specific feature name, command name, namespace, or known-deprecated surface in the agent's instructions.
2. **Code-review-level**: the PR review checklist includes "grep `.claude/agents/doc-qa.md` for codebase-specific identifiers (`chapter`, `produce`, `world`, `bible`, etc.) — none should appear in instruction text except in *generic example* prose explicitly framed as 'this is a hypothetical example'."
3. **Quickstart-level**: SC-011 verification step in `quickstart.md` does the grep automatically and reports PASS/FAIL.

**Rationale**: The constraint cannot be enforced by a runtime check (the agent doesn't introspect itself). Three layers — prompt, review, quickstart — give a defense-in-depth posture.

**Alternatives considered**:
- Static linter that fails CI on forbidden tokens. Rejected: brittle (legitimate uses of "world" in generic prose; would force awkward synonyms).
- Trust the implementer. Rejected: the spec made this an SC because it's load-bearing for the methodology.
