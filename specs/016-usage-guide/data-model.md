# Data Model: Project Pitch + Usage Guide + Doc-QA & Impl-QA Agents

**Feature**: 016-usage-guide
**Date**: 2026-04-28

This feature has no Ruby data model — no new classes, no new YAML schemas under `worlds/*/data/`. Its "data" is documents and agent reports. The entities below are the conceptual shapes the implementer needs to keep in mind so that doc-qa and impl-qa can anchor against them.

---

## Pitch

**Path**: `docs/pitch.md`
**Format**: Markdown (CommonMark).
**Lifecycle**: Stable. Edits are infrequent and significant — every edit triggers doc-qa across all guide sections (per FR-021 + SC-010).

**Required sections** (FR-PA-002):

| Section | Heading | Purpose | Authoritative for |
|---|---|---|---|
| Elevator | `## What Eidos is` | One-sentence elevator pitch | The product's identity |
| Audience | `## Who Eidos is for` | Target user description | Guide's audience assumptions |
| Mental model | `## How to think about Eidos` | Worlds, pieces, canon, evolution | The Glossary in the guide (FR-PA-003) |
| Distinctive value | `## What Eidos enables` | What this tool does that others don't | Implicit guide framing decisions |
| Non-goals | `## What Eidos is *not*` | Authoritative non-goals list | Guide's "What Eidos is *not*" section (FR-011) |

**Constraints**:
- 800–1500 words target (FR-PA-001).
- No runnable command examples (FR-PA-001).
- No internal Ruby symbols, file paths, or class names (mirrors guide-level FR-007).

**Relationships**:
- Upstream of: Usage Guide (Glossary, "What Eidos is *not*" section, framing assumptions).
- Verified by: Doc-QA (Tier 1 vision alignment, Tier 3 pitch self-consistency).

---

## Usage Guide

**Path**: `docs/usage-guide.md`
**Format**: Markdown (CommonMark) with Markdown-style code fences for shell examples.
**Lifecycle**: Iterative. Edits are frequent and granular. Every edit to user-facing CLI surface, scaffolding, or content production triggers impl-qa; every edit to the guide itself triggers both agents (per FR-021).

**Required top-level sections** (FR-003 + D-002):
1. Get oriented (mental model, glossary, "What Eidos is *not*")
2. Create your first world
3. Produce your first piece
4. Inspect what just happened
5. Evolving your world (canon review, branching, regeneration)
6. Translating your world
7. Publishing as a website
8. Power-user techniques (custom forms, model probing, the SDK)
9. Working offline / cheaply (`MOCK_AI`, `--debug`)
10. Troubleshooting

**Required content invariants**:
- Every command is fully runnable, not a fragment (FR-004).
- Every step states the world's resulting state (FR-005).
- Live-LLM vs `MOCK_AI` distinction is explicit in any section that depends on it (FR-006).
- Glossary terms are used consistently and defined once (FR-008).
- Skimmable: TOC lookup → relevant section in <30s (FR-010 / SC-007).
- "What Eidos is *not*" is a faithful expansion of the pitch's non-goals (FR-011).
- v1 ship has zero aspirational markers (FR-003 — full guide v1 per Q4).

**Relationships**:
- Downstream of: Pitch (glossary, "What Eidos is *not*", framing).
- Verified by: Doc-QA (Tier 2 internal consistency), Impl-QA (Tier 1 surface, Tier 2 behavioral).

---

## Documented Scenario

**Containment**: Lives inside the Usage Guide as one or more contiguous workflows under a top-level section.

**Conceptual fields** (not a YAML schema — a property of well-written prose):

| Field | Description | Source |
|---|---|---|
| `title` | The H2 / H3 heading of the section | Markdown structure |
| `preconditions` | What state the world is in before the workflow | First paragraph or explicit "Before you start" callout |
| `command_sequence` | Ordered shell commands the user runs | Code fences in section body |
| `expected_post_state` | What the world looks like afterward | Explicit statement per FR-005 |
| `status` | `current` (default) or `aspirational` | Presence of FR-007a marker |
| `cross_refs` | Other scenarios referenced by name | Markdown links |

**Status transitions**:
- `aspirational` → `current` happens when a future feature implements the section's described behavior. The transition is a doc-only edit (remove the marker), but the same PR almost always touches code (the new feature). Both doc-qa and impl-qa must PASS in the resulting state.
- `current` → `aspirational` happens when a section describes behavior the maintainer wants to deprecate but not yet remove from documentation. Rare; usually the section is just deleted instead.

**Verification**:
- Doc-QA Tier 1 verifies that *current* scenarios are consistent with the pitch. Aspirational scenarios are excluded from Tier 1 (FR-014 — wait, that's the old FR; the current spec excludes aspirational from impl-qa Tier 1 specifically per FR-IQ-003 Tier 1; doc-qa Tier 1 still applies to all sections — *aspirational sections must still align with the pitch's vision*).
- Impl-QA Tier 1 verifies *current* scenarios' surface; excludes aspirational sections.
- Impl-QA Tier 2 (`--behavioral`) verifies *current* scenarios' post-state.
- Impl-QA Tier 4 enumerates *aspirational* scenarios as backlog.

---

## Aspirational Marker

**Form**:

```markdown
## Section Title

> 🚧 **Not yet implemented** — describes the desired user experience; implementation tracked in spec NNN-name (or "tracked separately").
```

**Detection regex**: `^>\s*🚧\s*\*\*Not yet implemented\*\*` against the first non-blank line under a heading. Both agents implement this detection identically. Defined precisely in `contracts/aspirational-marker.md`.

**Placement rule**: Immediately under the H2 or H3 heading whose section it marks. Markers MUST NOT appear inside paragraphs of running prose, mid-section, or inside code blocks.

**v1 invariant**: zero markers in the v1 ship of the guide (FR-003 / Q4). Markers are a methodology mechanism for *future* edits.

---

## Doc-QA Report

**Format**: Markdown emitted to standard output by the subagent.

**Structure**:

```markdown
# Doc-QA Report

**Pitch**: docs/pitch.md
**Guide**: docs/usage-guide.md

## Tier 1 — Vision Alignment

[PASS] <one-line description with optional file:line citation>
[FAIL] guide §"<section>" contradicts pitch §"<section>":
       guide line N: "<quoted text>"
       pitch line M: "<quoted text>"
       reason: <one-line explanation>

## Tier 2 — Internal Consistency

[PASS] <…>
[FAIL] <…>

## Tier 3 — Pitch Self-Consistency

[PASS] <…>
[FAIL] <…>

## Verdict

PASS  (or)  FAIL — N Tier-1 failures, M Tier-2 failures, K Tier-3 failures.

## Root-Cause Candidates

- <one or more best-guess explanations of the source of the drift>
```

**Rules**:
- File paths use exact strings, line numbers refer to current document state.
- Quoted text is literal; no paraphrasing.
- The Verdict is the *only* line a CI / pre-commit hook needs to grep for to decide pass/fail.
- The agent never modifies either input file.

Defined in detail in `contracts/doc-qa-report.md`.

---

## Impl-QA Report

**Format**: Markdown.

**Structure**: same shape as Doc-QA Report, with four tiers and a drift-attribution column on every Tier-1/Tier-2 finding:

```markdown
## Tier 1 — Surface Accuracy

[FAIL] guide §"…" line N references `eidos produce piece --form X`, codebase exposes `--form` only as `--type`.
       attribution: codebase changed (no recent guide edit; commit Y renamed the flag)
```

Tier 3 (Undocumented Surface) and Tier 4 (Backlog) are informational and never fail the verdict. Defined in detail in `contracts/impl-qa-report.md`.

---

## CLI Surface (impl-qa Tier 3 ground truth)

**Source**: dynamically derived at impl-qa run time from:
1. `eidos help`, `eidos <subcommand> help` recursively (Thor commands + flags).
2. `eidos/lib/eidos/forms/*.yml` + `worlds/<world>/data/forms/*.yml` (registered piece forms).
3. `eidos/lib/eidos/world_config.rb` (or the canonical schema — keys and their user-facing types).
4. `worlds/<world>/data/settings.yml` schema (LLM provider, model, temperature, task_options).

**Excluded** (out of scope for SC-005's coverage floor): SDK public surface, environment variables, `strings.yml` keys, internal Thor plumbing (`tree`, inherited `help`), deprecated/hidden flags. Listed in FR-IQ-007.

---

## World State (impl-qa Tier 2 ground truth)

**Source**: a fresh world directory scaffolded from a Documented Scenario's preconditions. The agent runs the scenario's command sequence and inspects the resulting:
- `data/world_config.yml` field values
- `data/story_bible/*.yml` populations
- `data/canon_deltas/*.yml` shapes
- `content/pieces/<form>/*.md` frontmatter
- `eidos world status` output text

against the Documented Scenario's `expected_post_state` claims. Mismatches are Tier-2 failures with file paths and quoted post-state text.

---

## Out-of-band entities (referenced, not authored)

- **`.claude/agents/doc-qa.md`** — agent definition, structured per D-004.
- **`.claude/agents/impl-qa.md`** — agent definition, structured per D-005.
- **`.claude/commands/doc-qa.md`**, **`.claude/commands/impl-qa.md`** — slash-command shims, mirroring `.claude/commands/user-qa.md`'s shape.
- **`CLAUDE.md`** — Definition-of-Done extended per D-007.
- **`README.md`** — pitch + guide links inserted per D-008.
