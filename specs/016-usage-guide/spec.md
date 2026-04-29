# Feature Specification: Project Pitch + Usage Guide + Doc-QA & Impl-QA Agents

**Feature Branch**: `016-usage-guide`
**Created**: 2026-04-28
**Status**: Draft
**Input**: User description: "Usage guide for creating and evolving an Eidos storyworld, plus a local doc-qa agent that verifies the guide is internally consistent and matches actual CLI behavior. Becomes the base document for document-driven development."

## Clarifications

### Session 2026-04-28

- Q: Should the doc-qa agent verify the guide via static analysis, live execution, or a hybrid? → A: Hybrid — Tier 1 (surface) and Tier 3 (internal consistency) are static; Tier 2 (behavioral) is live and opt-in via a `--behavioral` flag (or equivalent), with `MOCK_AI=true` as the safe default for the structural tiers so they work without an API key.
- Q: How should the guide express not-yet-implemented behavior so document-driven development can describe future state without breaking doc-qa? → A: Aspirational markers — the guide annotates unimplemented sections explicitly (e.g., a `> 🚧 Not yet implemented` callout or a section-header flag). Doc-qa treats marked sections as expected to mismatch the codebase and reports them in a separate **Backlog tier** — informational, not failing. The Backlog tier becomes the input worklist for subsequent feature specs.
- Q: What counts as "user-facing surface" for the doc-qa coverage check (SC-005)? → A: CLI surface + registered piece forms + key config files. Specifically: (a) every Thor command and its primary user-facing flags under `eidos`, (b) every form registered via `FormRegistry` (built-in plus per-world `data/forms/*.yml`), and (c) the user-facing fields of `data/world_config.yml` and `data/settings.yml`. The SDK and environment variables are documented in dedicated sections but are **not** counted toward the 80% floor. `strings.yml` keys, internal Thor `tree`/`help` plumbing, and deprecated/hidden flags are excluded.
- Q: Does feature 016 ship the full guide v1, or only the doc-qa agent plus a seeded skeleton? → A: Full guide v1. Every workflow listed in FR-003 is written end-to-end and verified before merge. Reason: the user wants a complete, coherent document they can read, review, and use to identify codebase items that should change (add, fix, or remove). A skeleton with TODO markers would not enable that holistic read. Aspirational markers (FR-007a) and the Tier-4 Backlog tier remain in scope for *future* edits to the guide — they are how the doc evolves after this feature, not how it ships in this feature. **Concrete DDD use-case the user named**: the existing `eidos chapter` Thor commands belong to an older book-generation framing and are not needed in the IP/world model — the full guide read should make that mismatch visible, and a follow-up feature would either remove them from the CLI or reframe them in the IP context.
- Q: What is doc-qa's actual scope, and is it the only verifier? → A: **Doc-qa is split into two distinct agents.** (1) **doc-qa** verifies that the **Usage Guide is consistent with the Project Pitch** — a new artifact (`docs/pitch.md`) that captures the project's goal/vision (like a landing-page description). Its job is to surface *vision-level* mismatches: behavior the guide documents that contradicts what the project is supposed to *be*. It MUST do this by deriving inconsistencies from comparing the two documents — it MUST NOT carry hardcoded knowledge of specific feature names (e.g., it doesn't "know" that `chapter` commands are obsolete; it should infer that from a pitch that frames the project as IP/world-first). (2) **impl-qa** verifies that the **Implementation is consistent with the Usage Guide** — the mechanical CLI surface check, behavioral check on a fresh world, and undocumented-surface report. The split means a maintainer keeps one mental loop in their head at a time: read the guide and the pitch to ask "is this the right product?"; run impl-qa to ask "does the code do what the guide says?". The previously specified Tier-1/Tier-2/Tier-4 work moves to **impl-qa**; doc-qa's tiers are reorganized around vision alignment + internal consistency.
- Q: What is doc-qa's runtime mechanism — pure rules, single LLM prompt, or a structured pipeline? → A: **Doc-qa is a Claude Code subagent**, just like the existing `user-qa` agent. It reads the two documents, applies reading-comprehension reasoning, and emits a report. There is no custom pipeline, no claim-extraction layer, no separate LLM service — the "engine" is whatever Claude does when its subagent prompt instructs it to compare two texts. The spec's constraints (no hardcoded feature names per FR-DQ-003, no project-LLM-pipeline calls per FR-DQ-006, fast enough for pre-commit) bind the *prompt and tool access* of the subagent, not its internal architecture. "Static analysis" in FR-DQ-004 means *no execution of project code or scaffolding of worlds* — not "no LLM reasoning"; the reasoning is intrinsic to running on Claude.
- Q: Who authors the first draft of `docs/pitch.md`? → A: **The implementer drafts it from existing project knowledge** (CLAUDE.md, README.md, the IP-first / not-chapter-centric framing the user has already articulated, prior feature specs), and the user edits it as needed. The pitch draft MUST be the very first artifact produced inside this feature — landed before any usage-guide content is written, so the guide is derived from a real pitch (per the Assumptions ordering). The user is the editor-of-record; the implementer is on the hook for an opinionated, faithful first cut.

## Context

Eidos has matured through fifteen feature iterations and now ships a unified CLI, an SDK, and a storyworld pivot that supports many "forms" beyond chapters. What it does **not** have is a single, end-user-facing document that walks a storyworld creator from "I have an idea for an IP" to "I have a published, evolving world with multiple pieces, a canon history, and translations." Today, knowledge is scattered across `README.md`, `eidos/README.md`, `CLAUDE.md`, and per-feature `specs/*/quickstart.md` files — all written for contributors or AI agents, not for the people Eidos is *for*.

This feature delivers four artifacts that together form a layered model of *what Eidos is*, *how it's used*, and *how we know we're still on track*:

1. **A pitch document** (`docs/pitch.md`) — short, landing-page-style description of what Eidos *is*, who it's for, and what makes it distinctive. The source of truth for project vision. Small, stable, deliberately not a tutorial.
2. **A usage guide** (`docs/usage-guide.md`) — the canonical "how to use Eidos" document, explaining the user-facing mental model and standard workflows organized by what a creator wants to do, not by which Thor namespace exposes it.
3. **A local `doc-qa` agent** — verifies that the **Usage Guide is consistent with the Pitch**. Catches vision-level drift: workflows the guide documents that contradict what the project is supposed to *be*. Derives mismatches by comparing the two documents; does not carry hardcoded feature names.
4. **A local `impl-qa` agent** — verifies that the **Implementation is consistent with the Usage Guide**. Catches mechanical drift: CLI surface that doesn't match what the guide claims, post-state that doesn't match what the guide promises, undocumented surface that may need to be either documented or removed. Analogous in shape to the existing `user-qa` agent.

The two-agent split is deliberate: the maintainer holds one mental loop at a time. *Is this the right product?* (read pitch + guide; run doc-qa.) *Does the code do what we say it does?* (run impl-qa.) Mixing both lenses inside a single agent makes drift reports harder to act on and tempts the agent toward hardcoded knowledge of specific features.

The pitch + guide pair will become the **source of truth for document-driven development**: subsequent features will identify gaps by reading the guide and finding behaviors it documents that the system does not yet deliver — or behaviors the system delivers that are not documented and may therefore be wrong, redundant, or worth removing. Doc-qa keeps the guide honest to the pitch; impl-qa keeps the code honest to the guide.

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Newcomer scaffolds and grows their first storyworld (Priority: P1)

A creator who has just installed Eidos opens the guide and, without prior knowledge of the codebase, scaffolds a new storyworld, produces their first piece, inspects what was generated, and understands what to do next. They never need to read source code, search GitHub, or guess flag names.

**Why this priority**: This is the largest barrier to adoption. If the first 30 minutes don't work, nothing else matters. Every other story in this spec assumes the user got past this one.

**Independent Test**: A reader who has never used Eidos before can, by following only the guide and the CLI's `--help`, reach a state where `eidos world status` and `eidos piece list` both show non-empty, intent-relevant content for a world they invented in the last hour. Tested by handing the guide to a fresh reader (or to the **impl-qa** agent in `--behavioral` mode) and recording where they get stuck.

**Acceptance Scenarios**:

1. **Given** a fresh shell with `eidos` installed and no existing worlds, **When** the user follows the "Create your first world" section step by step, **Then** they end up with a directory containing populated `data/world_config.yml`, a non-empty `data/story_bible/`, and at least one piece file under `content/pieces/`.
2. **Given** a freshly scaffolded world, **When** the user follows the "Produce your first piece" section, **Then** they understand which forms are available, can choose one, and the documented command produces a piece whose frontmatter matches what the guide promised.
3. **Given** a piece has been produced, **When** the user follows "Inspect what just happened," **Then** they can run `eidos piece show`, `eidos canon review`, and `eidos bible search` against their world and the guide explains every line of the output they see.
4. **Given** the user wants to experiment without spending API tokens, **When** they read the "Working offline / cheaply" section, **Then** they know that `MOCK_AI=true` exists, what it does to output fidelity, and when to prefer it.

---

### User Story 2 — Returning creator evolves an existing world (Priority: P1)

A creator who has a world with several pieces wants to change canon (rename a character, retire a location, introduce a new fact), branch the world to try a what-if, regenerate or translate existing pieces, and publish the result. The guide tells them which command does what, in what order, and what state the world is in afterward.

**Why this priority**: Day-2 workflows are where Eidos's distinctive value (canon versioning, branching, translation, publishing) actually lives. If the guide only covers Day-1, users will treat Eidos as a fancier `gpt`-prompt and never discover what makes it different.

**Independent Test**: A reader with an existing populated world (e.g., `worlds/one-review-man` or `~/worlds/job-hunt`) can follow the "Evolving your world" section to perform at least one canon change, one branch operation, one translation, and one publish — entirely from the guide.

**Acceptance Scenarios**:

1. **Given** a world with at least one piece and a populated bible, **When** the user follows "Reviewing and accepting canon changes," **Then** they understand what `eidos canon review` shows, when to use `accept` vs `revert` vs `rollback`, and what files change as a result.
2. **Given** the same world, **When** the user follows "Branching to explore an alternative," **Then** they can create a branch, generate divergent pieces on it, compare branches, and merge or discard — and the guide names the exact commands and the resulting on-disk state at each step.
3. **Given** a world with English content, **When** the user follows "Translating your world," **Then** they can produce a Russian (or other) translation and the guide explains how the glossary is built, what `--debug` reveals, and how to handle a translation that drifted.
4. **Given** the user wants a public reading surface, **When** they follow "Publishing as a website," **Then** they end up with a `site/` directory they can serve locally and the guide tells them how to iterate on the output.

---

### User Story 3 — Maintainer keeps vision, guide, and code aligned (Priority: P1)

A maintainer (human or AI) wants to know two distinct things, and wants them answered by two distinct lenses: (a) does the **usage guide** still describe a product consistent with the **project pitch**? and (b) does the **codebase** still do what the **usage guide** says it does? The maintainer invokes `doc-qa` for the first question and `impl-qa` for the second. Each agent's report is focused, citeable, and free of the other's noise.

**Why this priority**: A doc that lies is worse than no doc. A vision that has drifted from its own usage guide is worse still — it produces features nobody asked for. Two narrowly scoped agents keep both layers honest without forcing the maintainer to read one tangled report.

**Independent Test**: (a) A maintainer who deliberately introduces a vision-level drift (e.g., the pitch reframes Eidos as IP-first while the guide keeps documenting chapter-only flows) can run `doc-qa` and receive a report naming the section of the guide that contradicts the pitch — even though the codebase still implements those flows. (b) A maintainer who deliberately introduces an implementation drift (e.g., renames a Thor command without updating the guide) can run `impl-qa` and receive a report naming the section and line of the guide that is now stale.

**Acceptance Scenarios**:

1. **Given** the pitch and the guide describe the same product, **When** the maintainer invokes `doc-qa`, **Then** it reports PASS with zero vision-alignment findings.
2. **Given** the pitch describes Eidos as IP-first but the guide spends a whole section on chapter-only book generation, **When** `doc-qa` runs, **Then** it reports a vision-alignment failure naming the guide section, quoting both the contradictory guide text and the relevant pitch text — *without* the agent having any hardcoded knowledge of "chapters" being deprecated.
3. **Given** the guide is internally consistent (terminology, step ordering, file-path references all coherent), **When** `doc-qa` runs, **Then** the internal-consistency tier reports PASS.
4. **Given** the guide and codebase agree on every documented command, flag, and post-state, **When** the maintainer invokes `impl-qa`, **Then** it reports PASS with zero drift findings.
5. **Given** a drift has been introduced (e.g., the guide documents `eidos produce piece --form X` but the codebase has renamed the flag to `--type`), **When** `impl-qa` runs, **Then** it reports a surface-accuracy failure naming the guide section and the codebase location.
6. **Given** `impl-qa` runs against a fresh world built from a guide example, **When** the resulting world state contradicts what the guide promised, **Then** it reports the gap with exact paths and quoted guide text.
7. **Given** either agent is invoked as a slash command (`/doc-qa`, `/impl-qa`) or as a Task-tool subagent, **When** either path is used, **Then** the entry points behave identically and accept the same inputs for that agent.

---

### User Story 4 — Power user discovers escape hatches (Priority: P2)

A creator has hit an edge — a piece they want to regenerate from a different angle, a custom form they want to register, a model they want to compare against the default — and the guide tells them what's possible and how to do it without leaving the supported path.

**Why this priority**: Eidos has rich machinery (custom forms in `data/forms/`, the `probe` command, `--debug`, content-model overrides, the SDK) that today is documented only in code. Surfacing it in the guide multiplies the value of features that already shipped without requiring any new code.

**Independent Test**: A reader can, from the guide alone, register a custom form for their world, run `eidos probe` to compare two models, and write a short Ruby script that uses `Eidos::World` and `Eidos::Bible`.

**Acceptance Scenarios**:

1. **Given** a creator wants a form Eidos doesn't ship (e.g., "tweet"), **When** they follow "Adding a custom form," **Then** the guide names the file path, schema, and validation rules, and the form appears in `eidos piece help`.
2. **Given** a creator wants to test a different model, **When** they follow "Trying a different model with `eidos probe`," **Then** they can run a side-by-side comparison and the guide explains the cost/quality tradeoffs in the output.
3. **Given** a developer wants programmatic access, **When** they follow the "Using Eidos from Ruby" section, **Then** they have a working snippet that loads a world, lists chapters, and updates a character — and the guide makes clear which mutations persist immediately.

---

### Edge Cases

- The guide documents a flag that exists today but is deprecated and slated for removal — what does the guide say, and how does **impl-qa** behave? (Expected: the guide either omits it or names it as deprecated; impl-qa Tier-1 PASSes if the flag still exists; the maintainer flags it for removal in a future spec.)
- The pitch defines a non-goal (e.g., "not a hosted service") but a guide section accidentally implies the opposite (e.g., "your world is automatically published"). **Doc-qa Tier-1** flags this as a vision-alignment failure citing both texts.
- The guide documents a "best practice" that is not enforced by the codebase (e.g., "always run `canon review` before `produce`"). Neither agent flags this as drift; **doc-qa Tier-2** detects it only when the guide *contradicts* itself across sections.
- A reader runs a command and gets an error the guide doesn't mention. **Impl-qa Tier-2** (`--behavioral`) runs the same command against a fresh world and surfaces the unmentioned failure mode so the guide can be updated.
- The codebase has commands that are not documented in the guide at all (e.g., `eidos canon impact_review`). **Impl-qa Tier-3** reports these as undocumented surface — the maintainer decides whether to document, reframe, or remove.
- The user's locale, terminal width, or color setting changes the output of help text. The guide MUST NOT depend on color or width, and **impl-qa** MUST normalize CLI output before comparing.
- The user has multiple worlds. The guide must make the `-w` / world-resolution rules unambiguous, and **impl-qa** must verify the documented resolution matches the implementation.
- The pitch is updated to reframe the project (e.g., a new non-goal is added). **Doc-qa Tier-1** MUST flag every guide section that newly contradicts the pitch, in the next run, with no agent-config change. (See SC-010.)

## Requirements *(mandatory)*

### Functional Requirements

**The Guide itself:**

- **FR-001**: The guide MUST be a single primary document at a stable, discoverable path (canonically `docs/usage-guide.md`) and MUST be linked from the top-level `README.md` so a new visitor finds it within one click.
- **FR-002**: The guide MUST be organized by **user task**, not by CLI namespace. Section headings MUST describe what the user is trying to do ("Create your first world," "Branch to try a what-if"), not the command surface ("The `world` namespace").
- **FR-003**: The guide MUST cover at minimum these workflows: world creation (interactive and non-interactive), inspecting world state, producing pieces of any registered form, browsing the bible, reviewing / accepting / reverting canon changes, branching and merging, translating, publishing the Jekyll site, debugging with `probe` and `--debug`, and using the SDK from Ruby. **All of these workflows MUST be written end-to-end in feature 016 — no aspirational markers in the v1 ship**. Aspirational markers (FR-007a) and the Tier-4 Backlog tier are mechanisms for how the guide *evolves over time*, not for how it ships in this feature.
- **FR-004**: Every command shown in the guide MUST be a complete, runnable command line — never a placeholder or fragment. Where the user is expected to substitute a value (e.g., a world name), the substitution point MUST be marked unambiguously and the guide MUST show one fully resolved example per substitution pattern.
- **FR-005**: The guide MUST tell the user what state their world is in after each documented step (which files exist, what `world status` would now report, which canon revision they are on).
- **FR-006**: The guide MUST explicitly distinguish behaviors that depend on a live LLM from behaviors that work under `MOCK_AI=true`, and MUST tell the user which sections are safe to follow offline.
- **FR-007**: The guide MUST NOT contain implementation details that bind to a specific Ruby class, method name, or internal module path. References to internal symbols belong in `CLAUDE.md` or per-feature specs, not in the user guide.
- **FR-007a**: The guide MUST support **aspirational sections** — content that describes a desired user experience not yet implemented in the codebase. Aspirational sections MUST be marked with an unambiguous, machine-detectable annotation (e.g., a `> 🚧 Not yet implemented` callout immediately under the section heading, or an explicit `status: aspirational` flag in the section's metadata). Aspirational status MUST be visible to a human skimming the guide, not buried in HTML comments. Sections without a marker are by default expected to match the current codebase exactly.
- **FR-008**: The guide MUST include a "Glossary" section defining the user-facing vocabulary (world, storyworld, IP, piece, form, bible, canon, snapshot, branch, delta, glossary) once and consistently, and every other section MUST use those terms without redefinition.
- **FR-009**: The guide MUST include a "Troubleshooting" section that names the most common failure modes a user will hit on first run (no API key, wrong working directory, world not found, mock-only output) with the documented recovery for each.
- **FR-010**: The guide MUST be skimmable — a reader who knows what they're looking for can find the relevant section from the table of contents in under 30 seconds without reading prose.
- **FR-011**: The guide MUST have a "What Eidos is *not*" section that names the boundary of the system so users do not form mistaken expectations the rest of the guide must then walk back. The content of this section MUST be a faithful expansion of the pitch's non-goals list (FR-PA-002) — never a narrower or wider claim. Any divergence between the two is a doc-qa Tier-1 failure.

**The Pitch Document:**

- **FR-PA-001**: The pitch MUST be a single short Markdown document at `docs/pitch.md` that reads as a landing-page-style statement of what Eidos is, who it's for, and what makes it distinctive. It is not a tutorial and MUST NOT contain runnable command examples. Its job is to give a reader the *idea of the product* in well under five minutes.
- **FR-PA-002**: The pitch MUST cover, at minimum: (a) the project's one-sentence elevator description, (b) the target user (creator of an IP/storyworld), (c) the core mental model (worlds, pieces, canon, evolution over time), (d) what Eidos *enables* that other tools don't, and (e) explicit non-goals — what Eidos is *not*. The "not" list in the pitch is authoritative; the guide's "What Eidos is not" section MUST be consistent with it.
- **FR-PA-003**: The pitch MUST be the canonical source of truth for the project's vocabulary at the conceptual level (storyworld, IP, world, pitch's framing of "piece," "canon"). The Usage Guide's Glossary (FR-008) MUST be downstream of the pitch and MUST NOT introduce conflicting definitions.
- **FR-PA-004**: The pitch MUST be linked from the top-level `README.md` and MUST be the first thing a new reader of the repository sees described — before the usage guide.

**The Doc-QA Agent (Pitch ↔ Usage Guide):**

- **FR-DQ-001**: The doc-qa agent MUST live at `.claude/agents/doc-qa.md` with the same frontmatter shape as the existing `user-qa` agent (name, description, model, color) and MUST be invocable both as a slash command (`/doc-qa`) and as a `Task`-tool subagent.
- **FR-DQ-002**: The doc-qa agent MUST take as input two paths: the pitch (default: `docs/pitch.md`) and the usage guide (default: `docs/usage-guide.md`). It MUST NOT take any other input that names specific features, commands, or codebase artifacts. Its scope is *document-to-document*, not *document-to-code*.
- **FR-DQ-003**: The doc-qa agent's prompt and configuration MUST NOT carry hardcoded knowledge of specific features, command names, namespaces, or "known-obsolete" surface. It MUST derive vision-level mismatches purely from comparing pitch text and guide text. If the pitch is updated to reframe the project, doc-qa's findings MUST shift accordingly without any agent-config change.
- **FR-DQ-004**: The doc-qa agent MUST verify three tiers, all performed via **document-only inspection** — no execution of project code, no world scaffolding, no calls to the project's LLM content pipeline. The reasoning is performed by the Claude Code subagent itself reading and comparing the two documents; there is no custom analysis pipeline:
  - **Tier 1 — Vision alignment**: every workflow, command, concept, or capability the guide presents is consistent with the project's stated vision in the pitch. Examples of Tier-1 failure: the guide spends a section on a workflow the pitch frames as out-of-scope; the guide assumes a target user different from the one the pitch names; the guide describes a creative output category the pitch's "what Eidos is *not*" list excludes.
  - **Tier 2 — Internal consistency**: claims made in one guide section do not contradict claims made in another. Vocabulary defined in the Glossary is used consistently throughout. Step ordering across cross-referenced workflows is coherent. Aspirational sections (FR-007a) must be self-consistent even though they describe future state.
  - **Tier 3 — Pitch self-consistency**: the pitch document itself does not contradict its own claims (e.g., the elevator pitch and the non-goals list don't disagree about what the product is for).
- **FR-DQ-005**: The doc-qa agent MUST report findings using the same shape as user-qa — a per-tier list of `[PASS]` / `[FAIL]` items with exact section anchors, line numbers, and quoted text from both documents — followed by a single PASS/FAIL verdict.
- **FR-DQ-006**: The doc-qa agent MUST NOT require any project API key (e.g., `OPENAI_API_KEY` for the Eidos content pipeline) and MUST NOT invoke the project's LLM content pipeline. (The subagent itself runs on Claude Code, which is its inherent runtime — not subject to this constraint.) Doc-qa MUST complete fast enough to use as a pre-commit check.
- **FR-DQ-007**: The doc-qa agent MUST NOT modify either document or any code. Its output is a report only. When it surfaces a vision-alignment failure, the maintainer decides whether to update the pitch or the guide; the agent does not assume a direction.

**The Impl-QA Agent (Usage Guide ↔ Implementation):**

- **FR-IQ-001**: The impl-qa agent MUST live at `.claude/agents/impl-qa.md` with the same frontmatter shape as `user-qa` and MUST be invocable both as a slash command (`/impl-qa`) and as a Task-tool subagent.
- **FR-IQ-002**: The impl-qa agent MUST take as input the path to the guide (default: `docs/usage-guide.md`) and optionally a path to a world to use as the verification target. If no world is supplied, the agent MUST be able to scaffold a fresh one from a guide example.
- **FR-IQ-003**: The impl-qa agent MUST verify three tiers, plus an informational backlog tier:
  - **Tier 1 — Surface accuracy** (static): every CLI command, flag, subcommand, and file path the guide names in **non-aspirational** sections actually exists in the current codebase. Aspirational sections (marked per FR-007a) are excluded from this tier.
  - **Tier 2 — Behavioral accuracy** (live, opt-in): when the agent executes a documented workflow from a non-aspirational section against a fresh or supplied world, the resulting state matches what the guide says will happen (file existence, frontmatter shape, `world status` output content).
  - **Tier 3 — Undocumented surface** (static, informational): every Thor command, primary flag, registered piece form, or user-facing field of `data/world_config.yml` / `data/settings.yml` that the codebase exposes but the guide does not mention is enumerated. Per the user's framing, items here serve a *dual* purpose: candidates for documentation OR candidates for removal. The agent MUST NOT recommend a direction.
  - **Tier 4 — Backlog** (static, informational): every aspirational section the guide contains is enumerated with its title, the commands or behaviors it describes, and (where the agent can detect them) the codebase deltas it implies. Drives future feature specs.
- **FR-IQ-004**: The impl-qa agent MUST report findings using the same shape as user-qa — per-tier `[PASS]` / `[FAIL]` items with exact paths, line numbers, and quoted text — followed by a single PASS/FAIL verdict (Tier 3 + Tier 4 are informational and never fail the verdict). The report MUST distinguish drift caused by the guide being stale from drift caused by the codebase being broken, with evidence; it MUST NOT silently assume one direction.
- **FR-IQ-005**: The impl-qa agent's default invocation MUST run only Tier 1 + Tier 3 + Tier 4 (all static) with no API key required, and MUST complete fast enough to use as a pre-commit check. Tier 2 (behavioral) MUST be opt-in via a `--behavioral` flag or equivalent; when invoked, it MUST default to `MOCK_AI=true` and require an explicit further flag to use a live LLM. The report MUST clearly mark which findings would require a live-LLM rerun to confirm.
- **FR-IQ-006**: The impl-qa agent MUST NOT modify the guide or the codebase. Its output is a report only.
- **FR-IQ-007**: The "user-facing surface" definition for impl-qa Tier 3 is: (a) every Thor command and its primary user-facing flags under `eidos`, (b) every form registered via `FormRegistry` (built-in plus per-world `data/forms/*.yml`), and (c) the user-facing fields of `data/world_config.yml` and `data/settings.yml`. The SDK, environment variables, `strings.yml` keys, internal Thor plumbing (`tree`, inherited `help`), and deprecated/hidden flags are explicitly out of scope.

**Repository integration:**

- **FR-020**: Two slash-command files MUST live at `.claude/commands/doc-qa.md` and `.claude/commands/impl-qa.md` and MUST each dispatch to their respective subagent (mirroring `.claude/commands/user-qa.md`).
- **FR-021**: `CLAUDE.md` MUST be updated so that the **Definition of Done** section names **both** doc-qa and impl-qa as required checks, alongside the existing user-qa requirement. Specifically: doc-qa is required for any change that modifies the pitch *or* the usage guide; impl-qa is required for any change that modifies user-facing CLI surface, scaffolding output shape, content-production workflow, or the usage guide.

### Key Entities

- **Pitch**: a single short Markdown document at `docs/pitch.md`. Landing-page-style description of what Eidos is, who it's for, what it enables, and explicit non-goals. The canonical source of truth for project vision and conceptual vocabulary. Stable; changes rarely.
- **Usage Guide**: a single Markdown document at `docs/usage-guide.md`. Organized by user task. Contains a glossary (downstream of the pitch), runnable examples, troubleshooting, and a "What Eidos is not" section (downstream of the pitch's non-goals). The canonical user-facing operational source of truth.
- **Documented Scenario**: a contiguous, named workflow inside the guide (e.g., "Create your first world"). Each scenario has preconditions, an ordered command sequence, expected post-state, and references to other scenarios it composes with. A scenario is either **current** (matches today's codebase, subject to impl-qa Tier-1/Tier-2 enforcement) or **aspirational** (marked per FR-007a, surfaced in impl-qa Tier 4 as a backlog item).
- **Doc-QA Agent**: a Claude Code subagent at `.claude/agents/doc-qa.md` that consumes the **pitch** and the **usage guide**, evaluates them across three static tiers (Tier 1 vision alignment, Tier 2 internal consistency of the guide, Tier 3 pitch self-consistency), and emits a structured report. Carries no hardcoded feature names; derives mismatches purely from text comparison.
- **Impl-QA Agent**: a Claude Code subagent at `.claude/agents/impl-qa.md` that consumes the **usage guide** and the **codebase**, evaluates them across four tiers (Tier 1 surface accuracy / static, Tier 2 behavioral accuracy / live opt-in, Tier 3 undocumented surface / static informational, Tier 4 backlog / static informational), and emits a structured report. Mechanical: checks names, paths, post-states.
- **Doc-QA Report / Impl-QA Report**: each agent's output. Per-tier findings with exact citations, a verdict, and root-cause candidates. Never modifies files.
- **CLI Surface**: the set of commands, subcommands, flags, and required arguments exposed by `eidos/exe/eidos` and its Thor classes. Impl-QA's Tier-1 ground truth.
- **World State**: the on-disk shape of a world directory after a sequence of documented commands. Impl-QA's Tier-2 ground truth.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A reader who has never used Eidos can scaffold a world and produce their first piece in under 15 minutes by following only the guide and the CLI's built-in `--help`. Measured by reader walkthrough or by a clean impl-qa run that exercises the "Create your first world" + "Produce your first piece" sections end-to-end.
- **SC-002**: 100% of CLI commands, subcommands, and flags shown in the guide are present in the current codebase. Measured by **impl-qa Tier-1** pass rate.
- **SC-003**: 100% of post-state claims in the guide ("after this step, your world has X") match the actual on-disk state when the documented commands are executed against a fresh world. Measured by **impl-qa Tier-2** pass rate.
- **SC-004**: The guide contains zero internal contradictions across its sections (terminology, step ordering, file-path references). Measured by **doc-qa Tier-2** (internal consistency) pass rate.
- **SC-005**: At least 80% of the user-facing surface — defined per FR-IQ-007 as Thor commands & primary flags + registered forms + user-facing fields of `world_config.yml` and `settings.yml` — is documented in the guide. Measured by the **impl-qa Tier-3** "undocumented surface" report. Anything below 80% is a signal that either the guide is incomplete *or* the codebase has surface that should be removed; the maintainer decides per-item. Anything documented (in a non-aspirational section) but not present in the codebase is a hard impl-qa Tier-1 failure.
- **SC-006**: When a maintainer renames or removes a CLI flag without updating the guide, impl-qa surfaces the drift in a single run with exact citation. Demonstrated by an injected-drift acceptance test in the impl-qa quickstart.
- **SC-007**: The guide's table of contents lets a reader find the section relevant to their goal in under 30 seconds without scrolling through prose. Measured by reader walkthrough against a fixed list of search goals (e.g., "How do I translate to Russian?", "How do I undo a canon change?").
- **SC-008**: After this feature ships, all subsequent feature specs (`017+`) that touch user-facing surface MUST cite the guide section they affect — making the pitch + guide pair the de-facto driver of document-driven development. Measured by spec audit at the next feature's review.
- **SC-009**: The guide is fully consistent with the pitch — zero vision-alignment failures across every section. Measured by **doc-qa Tier-1** pass rate. This is the primary signal that doc-qa exists to provide.
- **SC-010**: When the pitch is updated to reframe the project (e.g., declaring a new non-goal), doc-qa surfaces the affected guide sections in the next run *without any agent-config change*. Demonstrated by an acceptance test that mutates the pitch and re-runs doc-qa.
- **SC-011**: The doc-qa agent's prompt and configuration contain zero hardcoded feature names, command names, or "known-deprecated" surface. Verified by inspection of `.claude/agents/doc-qa.md`. (This is the structural guarantee behind FR-DQ-003.)

## Assumptions

- The target reader of the guide is a **storyworld creator**, not a Ruby developer or contributor. They are comfortable with a terminal and copy-pasting commands but should not need to understand Thor, RSpec, or YAML serialization to follow the guide. Where Ruby fluency is required (the SDK section), the guide will say so explicitly.
- The guide is written in **English only** for this iteration. Multi-language guide variants are out of scope and will be addressed in a later spec if there is demand. (Eidos's translation feature applies to *content*, not to its own documentation.)
- Both QA agents (doc-qa, impl-qa) run locally as Claude Code subagents. There is no CI integration in this spec — that is a follow-up. The expectation is that human/AI maintainers run them as part of the existing Definition of Done.
- The guide assumes Eidos is installed as a gem (`gem install eidos`) **or** invoked from the monorepo via `eidos/exe/eidos`. Both invocation styles MUST be documented; the guide must not assume one and ignore the other.
- The guide will use `worlds/one-review-man` and `~/worlds/job-hunt` as recurring examples where helpful, but every example MUST also work for a brand-new world the reader invents. No example may presuppose state only present in those two worlds.
- `docs/` is currently untracked scratch. This spec adopts `docs/` as the canonical location for end-user docs. The two pre-existing files there (archived 011 design notes) will be moved to `specs/011-eidos-sdk-and-installable-cli/` or deleted as a chore inside this feature.
- Document-driven development with this guide as the source of truth is **a methodology change**, not a tooling change. This spec delivers the guide and the verifier; the discipline of comparing the guide to reality before opening new feature specs is a process the team adopts on top.
- The first DDD pass is expected to surface **obsolete codebase surface** alongside undocumented surface. The user has already named one concrete example: the `eidos chapter` Thor namespace is residual from an earlier book-generation framing and is unlikely to appear in an IP-first guide. Expect the impl-qa Tier-3 "undocumented user-facing surface" finding (FR-IQ-007) to drive *removal* features as often as it drives *documentation* features. The maintainer makes that call per-item; impl-qa does not assume one direction. Crucially, the *vision-level* mismatch (chapters being framed as the unit of output when the project is IP-first) MUST surface from doc-qa Tier-1 by comparing the pitch and the guide — without any specific knowledge of "chapter" being baked into the agent.
- The pitch and the guide are written *in this feature*. The pitch is small and stable; the guide is large. The deliberate ordering is: write the pitch first, derive the guide's framing from it, then make sure both check clean against each other via doc-qa before considering the guide "done." This avoids the failure mode where a beautifully crafted guide cements a vision the team has actually moved away from.
- **Pitch authorship handoff**: the implementer of this feature drafts the pitch from existing repository signals (CLAUDE.md, README.md, the IP-first / not-chapter-centric framing the user has articulated, prior feature specs). The user is the editor-of-record and may rewrite, narrow, or expand any part of it. The pitch draft MUST land as the first commit inside this feature — before any usage-guide content is written — so the guide is genuinely derived from a real pitch and not a hypothetical one.
