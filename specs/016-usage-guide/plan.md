# Implementation Plan: Project Pitch + Usage Guide + Doc-QA & Impl-QA Agents

**Branch**: `016-usage-guide` | **Date**: 2026-04-28 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/016-usage-guide/spec.md`

## Summary

Deliver four artifacts that establish a layered model of *what Eidos is*, *how it's used*, and *how we know we're still on track*: a short **pitch** at `docs/pitch.md` (vision source-of-truth), a comprehensive **usage guide** at `docs/usage-guide.md` (operational source-of-truth, organized by user task), and two Claude Code subagents — **doc-qa** (verifies guide ↔ pitch alignment via reading-comprehension; carries no hardcoded feature names) and **impl-qa** (verifies guide ↔ codebase alignment via mechanical CLI/world checks). The pitch is drafted by the implementer from existing repo signals and edited by the user. Sequencing matters: pitch first, then doc-qa, then guide written iteratively against doc-qa, then impl-qa, then repository wiring (CLAUDE.md Definition-of-Done, README.md links, slash commands). The pitch + guide pair becomes the source of truth for document-driven development going forward; the first DDD pass is expected to surface obsolete codebase surface (e.g., the `eidos chapter` Thor namespace) for removal in features 017+.

## Technical Context

**Language/Version**: Markdown (CommonMark) for docs and agent prompts; YAML frontmatter for agent metadata. No Ruby code authored in this feature. Existing Ruby (Thor CLI, FormRegistry) is *read* by impl-qa but not modified here.
**Primary Dependencies**: None new. The agents are Claude Code subagents — runtime is Claude Code itself; no gems, no scripts. Existing project tooling (`eidos` CLI, RSpec, RuboCop) is unchanged.
**Storage**: Plain files only. `docs/pitch.md`, `docs/usage-guide.md`, `.claude/agents/doc-qa.md`, `.claude/agents/impl-qa.md`, `.claude/commands/doc-qa.md`, `.claude/commands/impl-qa.md`, plus an edit to `CLAUDE.md` and `README.md`.
**Testing**: The agents themselves are the runtime validation surface. The plan's verification step is to drive each agent against an injected-drift scenario and confirm the report shape. RSpec coverage is unchanged (no Ruby touched), so the existing `EIDOS_COVERAGE_FLOOR` still holds without intervention.
**Target Platform**: Claude Code on the developer's local machine (Linux/macOS). No deployment, no service.
**Project Type**: Documentation + local agent tooling. Single-project repo; no new directory option needed.
**Performance Goals**: doc-qa default invocation completes in ≲10 seconds wall-clock for the v1 pitch + guide (≲1k + ≲10k words). impl-qa default invocation (Tier 1 + 3 + 4, all static) completes in ≲15 seconds. impl-qa `--behavioral` runs in ≲90 seconds under `MOCK_AI=true` for the seeded "Create your first world" + "Produce your first piece" scenarios. These are operational targets, not hard SLAs — slow first runs are acceptable while iterating.
**Constraints**: No new runtime gem. No project API key (`OPENAI_API_KEY` etc.) required for any default agent invocation. Doc-qa MUST NOT inspect the codebase, scaffold worlds, or call the project's LLM content pipeline (per FR-DQ-004). Doc-qa's prompt MUST contain zero hardcoded feature names (per FR-DQ-003 / SC-011) — the no-feature-names property is a code-review invariant.
**Scale/Scope**: 1 pitch (~800–1500 words), 1 usage guide (~5k–10k words covering 9+ workflows), 2 agent definitions (~150–250 lines each), 2 slash commands, 1 README.md edit, 1 CLAUDE.md edit. Plus a chore: relocate the two stale files under `docs/` (archived 011 design notes) into `specs/011-eidos-sdk-and-installable-cli/`.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

The constitution defines seven principles. Six are not engaged by this feature; one is engaged and discharged by the guide content itself.

| Principle | Engaged? | Disposition |
|---|---|---|
| I. Test-First with Mock AI | No | This feature authors no Ruby. RSpec coverage is unchanged. Agent validation is described in `quickstart.md`, not in `_spec.rb`. |
| II. Producer Contract | No | No producer added. |
| III. Dependency Injection | No | No Ruby classes added. |
| IV. Canon Integrity with Versioned IP | No | No canon touch. |
| V. Security by Default | **Yes** | The guide MUST teach users to provide `OPENAI_API_KEY` via env var, MUST NOT print or commit it. Both agents MUST NOT log credentials. Discharged by FR-006, FR-009, and the doc-qa/impl-qa instruction text. |
| VI. Pluggable AI Services with Evals | No | No AI service added. |
| VII. Separation of Concerns | No | No engine/producer/publishing change. |

**Gate verdict: PASS** — no violations, no exceptions claimed, no Complexity Tracking entries needed.

**Re-check note (post-Phase 1)**: After data-model + contracts are written, re-evaluate whether any agent prompt accidentally couples to internal Ruby symbols (which would partially violate the spec's FR-007 / FR-DQ-003 even if not the constitution directly). This is the one design risk to watch.

## Project Structure

### Documentation (this feature)

```text
specs/016-usage-guide/
├── spec.md              # Feature spec (already written, clarified twice)
├── plan.md              # This file
├── research.md          # Phase 0 output — pitch / guide / agent design decisions
├── data-model.md        # Phase 1 output — entity shapes (Pitch, Guide, Reports)
├── contracts/
│   ├── doc-qa-report.md   # Schema for doc-qa output
│   ├── impl-qa-report.md  # Schema for impl-qa output
│   └── aspirational-marker.md  # Concrete syntax for FR-007a markers
├── quickstart.md        # Phase 1 output — verification scenarios
├── checklists/
│   └── requirements.md  # Spec quality checklist (already created in /speckit.specify)
└── tasks.md             # Phase 2 output — created later by /speckit.tasks
```

### Source Code (repository root)

This feature touches no Ruby. The artifact tree is:

```text
docs/
├── pitch.md             # NEW — project vision, ~800–1500 words
└── usage-guide.md       # NEW — operational guide, ~5k–10k words

.claude/
├── agents/
│   ├── doc-qa.md        # NEW — pitch ↔ guide subagent
│   ├── impl-qa.md       # NEW — guide ↔ code subagent
│   └── user-qa.md       # EXISTS — left untouched
└── commands/
    ├── doc-qa.md        # NEW — slash-command shim
    ├── impl-qa.md       # NEW — slash-command shim
    └── user-qa.md       # EXISTS — left untouched

CLAUDE.md                # EDIT — Definition of Done extended to name doc-qa + impl-qa
README.md                # EDIT — link the pitch first, then the usage guide

# CHORE: relocate two pre-existing untracked files
docs/superpowers/specs/2026-04-16-eidos-sdk-and-installable-cli-design.md
                       → specs/011-eidos-sdk-and-installable-cli/legacy-design.md
docs/superpowers/plans/2026-04-16-eidos-sdk-and-installable-cli.md
                       → specs/011-eidos-sdk-and-installable-cli/legacy-plan.md
(Or delete if 011 is a finished feature whose history we don't need.)
```

**Structure Decision**: Single-project structure. Documentation lives in the existing `docs/` directory (formerly untracked scratch — adopted by this feature as the canonical end-user-docs location). Agents and slash commands extend the existing `.claude/agents/` and `.claude/commands/` patterns established by `user-qa`. No new top-level directory needed. No code source tree changes.

## Phase 0: Outline & Research

The Technical Context above carries no `NEEDS CLARIFICATION` markers — every technical decision was either pinned by the seven clarifications in `spec.md`'s Clarifications section or has a reasonable default that the spec itself documents (e.g., agent file paths, frontmatter shape mirrored from `user-qa.md`).

**`research.md` will document the following resolved decisions** (each with Decision / Rationale / Alternatives considered):

1. **Pitch document outline & length** — five sections matching FR-PA-002 (a–e), targeting 800–1500 words. Alternative considered: longer "manifesto" form (rejected: pitch is meant to read in under five minutes).
2. **Usage-guide table-of-contents structure** — workflow-task headings (FR-002), no Thor-namespace headings. Alternative: organize by command surface (rejected: violates FR-002).
3. **Aspirational-marker syntax** — `> 🚧 Not yet implemented` blockquote callout immediately under the affected section's H2/H3. Section-header metadata flag rejected (Markdown frontmatter doesn't propagate to mid-document sections; the callout is human-skimmable per FR-007a).
4. **Doc-qa subagent prompt structure** — three labeled tiers (Vision Alignment, Internal Consistency, Pitch Self-Consistency) modeled on `user-qa.md`'s tier shape; explicit "no feature names" hard rule in the prompt; no `Bash` tool access (only `Read`, `Glob`, `Grep`).
5. **Impl-qa subagent prompt structure** — four labeled tiers; `Read`, `Glob`, `Grep`, and `Bash` tool access (Bash needed for help-text dumps and `--behavioral` world execution); explicit `MOCK_AI=true` default for Tier 2.
6. **Report formats** — Markdown structure mirroring `user-qa.md`'s output shape (per-tier `[PASS]`/`[FAIL]` bullets with file paths + line numbers + quoted text + verdict + root-cause candidates). Alternatives considered: JSON output (rejected: human-readable matters more for a pre-commit check; agents that consume the output can parse Markdown).
7. **CLAUDE.md Definition-of-Done patch** — extend the existing "Definition of Done" section to add doc-qa as required for any change to `docs/pitch.md` or `docs/usage-guide.md`, and impl-qa as required for any change to user-facing CLI surface, scaffolding, content production, or the usage guide.
8. **README.md ordering** — pitch link appears before usage-guide link, both within the first ~30 lines so a new visitor finds them in one click (per FR-PA-004 / FR-001).
9. **Performance budget validation** — measure end-to-end agent runtime once during `quickstart.md` verification; record observed latency. Hard SLA not asserted (per spec — "fast enough for pre-commit" is the qualitative target).
10. **`docs/` cleanup** — the two pre-existing files (archived 011 notes) move to `specs/011-eidos-sdk-and-installable-cli/legacy-{design,plan}.md`. Rationale: 011 is closed; preserving the history near its spec is more discoverable than leaving it under `docs/`.

**Output**: `research.md` (written in Phase 0 below).

## Phase 1: Design & Contracts

**Prerequisites**: research.md complete.

1. **Entities → `data-model.md`**:
   - **Pitch** — fields: elevator description, target user, mental model, distinctive enablement, non-goals; relationships: upstream of Guide.Glossary and Guide.WhatEidosIsNot.
   - **Usage Guide** — fields: TOC, glossary, workflow sections (current vs aspirational), troubleshooting, "What Eidos is not"; relationships: downstream of Pitch; verified-against by both agents.
   - **Documented Scenario** — fields: title, preconditions, command sequence, expected post-state, status (current / aspirational); relationship: 1..N within a Guide.
   - **Aspirational Marker** — concrete shape (a single Markdown blockquote line under the section heading).
   - **Doc-QA Report** — per-tier `[PASS]`/`[FAIL]` bullets, verdict, root-cause candidates.
   - **Impl-QA Report** — per-tier `[PASS]`/`[FAIL]` bullets (Tier 3+4 informational), verdict, drift-attribution column.
   - **CLI Surface** (Tier-3 ground truth) — derived dynamically from Thor help dumps + `data/forms/` glob + `world_config.yml` / `settings.yml` schemas.

2. **Contracts → `contracts/`**:
   - **`contracts/doc-qa-report.md`** — exact section structure of doc-qa's output, with a worked PASS example and a worked FAIL example.
   - **`contracts/impl-qa-report.md`** — same for impl-qa, including the four-tier structure and the drift-attribution requirement.
   - **`contracts/aspirational-marker.md`** — the exact Markdown blockquote syntax, where it must appear (immediately under the heading), and how the agents detect it (regex pattern shown). This is the FR-007a parsing contract.

3. **`quickstart.md`** — end-to-end verification:
   - Step 1: write a stub pitch + guide, run doc-qa, expect PASS.
   - Step 2: inject a vision-level drift (add a guide section that contradicts a pitch non-goal), re-run doc-qa, expect Tier-1 FAIL with quoted text.
   - Step 3: revert; run impl-qa default, expect PASS.
   - Step 4: inject a CLI drift (rename a flag in the guide that doesn't exist in the codebase), re-run impl-qa, expect Tier-1 FAIL.
   - Step 5: run impl-qa `--behavioral` against a fresh world, exercise "Create your first world" + "Produce your first piece," expect PASS.
   - Step 6: structural inspection — confirm doc-qa.md prompt has no feature names (SC-011 verification).
   - Step 7: SC-007 manual check — pick four search goals, time the TOC lookup.
   - Step 8: confirm `README.md` and `CLAUDE.md` edits are in place.

4. **Agent context update**:
   - Run `.specify/scripts/bash/update-agent-context.sh claude` to refresh CLAUDE.md's "Active Technologies" / "Recent Changes" footer with the 016 entry. Manual additions between markers are preserved.

**Output**: `data-model.md`, `contracts/{doc-qa-report.md, impl-qa-report.md, aspirational-marker.md}`, `quickstart.md`, plus the agent context refresh.

## Post-Design Constitution Re-check

After Phase 1 artifacts are drafted, re-verify:

- **Principle V (Security by Default)**: doc-qa and impl-qa prompts MUST NOT instruct the agent to log API keys or full prompts. Confirmed in `contracts/doc-qa-report.md` and `contracts/impl-qa-report.md` design — neither mentions credentials.
- **FR-DQ-003 / SC-011 invariant**: doc-qa's prompt is a *property of the agent's instruction text*. Verify in code review that no concrete feature name appears in `.claude/agents/doc-qa.md`. The contract (`contracts/doc-qa-report.md`) explicitly forbids it.

**Gate re-verdict: PASS** (deferred to post-implementation review of the actual agent files).

## Complexity Tracking

No constitution violations. No complexity entries.

## Implementation Sequence (informative — full ordering lands in `tasks.md`)

The order is load-bearing for the methodology, not just for engineering. Rough sequence:

1. Pitch draft (`docs/pitch.md`) — implementer writes from existing project knowledge; user reviews.
2. Doc-qa subagent (`.claude/agents/doc-qa.md` + `.claude/commands/doc-qa.md`) — built next so the pitch is checked for self-consistency before any guide work.
3. Guide outline (table of contents + section headings, no body content yet) — to expose vision-level mismatches early.
4. Doc-qa run #1 against pitch + guide outline — fix pitch or outline iteratively.
5. Guide body content, written workflow by workflow — doc-qa Tier 2 (internal consistency) re-runs as content lands.
6. Impl-qa subagent (`.claude/agents/impl-qa.md` + `.claude/commands/impl-qa.md`) — built once the guide has enough content to verify against.
7. Impl-qa default run — fix Tier-1 failures by either correcting the guide or marking sections aspirational.
8. Impl-qa `--behavioral` run against the seeded scenarios — fix Tier-2 failures.
9. Repository wiring: `README.md` link order, `CLAUDE.md` Definition of Done extension, `docs/` legacy-file relocation chore.
10. Final acceptance pass: both agents PASS; `quickstart.md` walked end-to-end; SC-001/007 reader walkthrough done.

## Phase 2 (out of scope for this command)

Tasks decomposition lives in `tasks.md` and is produced by `/speckit.tasks`. The implementation sequence above is the seed.
