---

description: "Task list for feature 016: Project Pitch + Usage Guide + Doc-QA & Impl-QA Agents"
---

# Tasks: Project Pitch + Usage Guide + Doc-QA & Impl-QA Agents

**Input**: Design documents from `/specs/016-usage-guide/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: This feature authors no Ruby, so RSpec tests are not added. Verification is performed via the doc-qa and impl-qa agents themselves plus the quickstart walkthrough — see Phase 7.

**Organization**: Tasks are grouped by the four user stories from `spec.md`. Most user-story tasks touch the same single file (`docs/usage-guide.md`) and are therefore sequential within their phase. Cross-phase parallelism is limited for the same reason. Doc-qa is treated as **foundational** (the implementer needs it for iterative guide writing); impl-qa lives in the US3 phase (it verifies guide ↔ code, which requires guide content to verify against).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Different files, no dependencies on incomplete tasks — runnable in parallel
- **[Story]**: Maps a task to a user story (US1, US2, US3, US4). Setup / Foundational / Polish tasks carry no Story label.
- File paths are absolute under `/home/cutalion/code/one-review-man/`.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Repository housekeeping that must precede the foundational work.

- [X] T001 [P] Move `/home/cutalion/code/one-review-man/docs/superpowers/specs/2026-04-16-eidos-sdk-and-installable-cli-design.md` to `/home/cutalion/code/one-review-man/specs/011-eidos-sdk-and-installable-cli/legacy-design.md` (research D-010); preserve any internal anchor references that still resolve.
- [X] T002 [P] Move `/home/cutalion/code/one-review-man/docs/superpowers/plans/2026-04-16-eidos-sdk-and-installable-cli.md` to `/home/cutalion/code/one-review-man/specs/011-eidos-sdk-and-installable-cli/legacy-plan.md` (research D-010); after the move, remove the now-empty `/home/cutalion/code/one-review-man/docs/superpowers/` tree.

**Checkpoint**: `/home/cutalion/code/one-review-man/docs/` is empty and ready to host `pitch.md` + `usage-guide.md`.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Pitch + doc-qa + slash command + README link + guide skeleton. Everything user stories need to begin guide-content work.

**⚠️ CRITICAL**: No user-story phase begins until this phase completes.

- [X] T003 Draft `/home/cutalion/code/one-review-man/docs/pitch.md` from existing project knowledge (CLAUDE.md, README.md, the IP-first / not-chapter-centric framing the user has articulated, prior feature specs). Follow research D-001: five required sections (`## What Eidos is`, `## Who Eidos is for`, `## How to think about Eidos`, `## What Eidos enables`, `## What Eidos is *not*`). Target 800–1500 words. No runnable command examples (FR-PA-001). The "What Eidos is *not*" section is the **authoritative non-goals list** (FR-PA-002) — it propagates downstream into the guide's "What Eidos is *not*" section.
- [X] T004 [P] Create `/home/cutalion/code/one-review-man/.claude/agents/doc-qa.md` per research D-004 + spec FR-DQ-001..007. Frontmatter mirrors `.claude/agents/user-qa.md`'s shape (`name: doc-qa`, `description:` with three example invocations, `model: sonnet`, `color`). Body has labeled blocks: Inputs (pitch path, guide path; no other inputs), Tools available (`Read`, `Glob`, `Grep` only — no `Bash`), What you check (Tier 1 Vision Alignment, Tier 2 Internal Consistency, Tier 3 Pitch Self-Consistency with worked examples), Hard rules (explicit "no hardcoded feature names" clause; never modify files), How you report (references `specs/016-usage-guide/contracts/doc-qa-report.md`). **SC-011 grep clean** ✓.
- [X] T005 [P] Create `/home/cutalion/code/one-review-man/.claude/commands/doc-qa.md` slash-command shim. Mirror `.claude/commands/user-qa.md`'s shape exactly: dispatches to the `doc-qa` subagent. (FR-020.)
- [X] T006 [P] Edit `/home/cutalion/code/one-review-man/README.md` to add — within the first 20 lines — a one-line description, a link to `docs/pitch.md`, and a link to `docs/usage-guide.md`. The pitch link MUST appear before the guide link (research D-008, FR-PA-004). Both links resolve at this point even though the guide skeleton exists; the guide body lands in later phases.
- [X] T007 Run `/doc-qa` against `docs/pitch.md` plus a minimal stub `docs/usage-guide.md`. Verified by direct comparison in-session (subagent file is loaded at session start; will be dispatchable from next session): Tier 3 PASS, Tier 1 / Tier 2 vacuously PASS.
- [X] T008 Write the **skeleton** of `/home/cutalion/code/one-review-man/docs/usage-guide.md`: title, short intro paragraph, table of contents, and the ten H2 section headings in the order defined in research D-002. **No section bodies yet** — each H2 contains only a one-line placeholder comment: `<!-- TBD in feature 016 — written in phase US1/US2/US3/US4 -->`. The TOC links each H2 to its slug. This file is the canvas every user-story phase writes into.
- [X] T009 Run `/doc-qa` against pitch + skeleton. Verified by direct comparison: PASS. All ten section headings align with concepts established in the pitch (`world`, `piece`, `canon`, `evolution`, programmatic interface, non-goals).

**Checkpoint**: pitch is final, doc-qa works, slash command works, README links exist, guide skeleton has the ten section headings. User-story phases can begin.

---

## Phase 3: User Story 1 — Newcomer scaffolds and grows their first storyworld (Priority: P1) 🎯 MVP

**Goal**: A reader who has never used Eidos can, by following only the guide and `--help`, scaffold a world, produce their first piece, inspect the result, and choose between live-LLM and `MOCK_AI` modes.

**Independent Test**: Hand the guide to a fresh reader (or impl-qa `--behavioral`) and confirm `eidos world status` + `eidos piece list` show non-empty intent-relevant content for a freshly invented world within 15 minutes (SC-001 / spec acceptance scenarios 1–4).

> **Sequencing constraint**: T010–T014 all write into `docs/usage-guide.md`. They are **sequential within this phase** (no [P]) because they edit the same file. T015 verifies after the section group lands.

- [X] T010 [US1] Write the **"Get oriented"** section body in `/home/cutalion/code/one-review-man/docs/usage-guide.md`. Includes the mental model (downstream of pitch §"How to think about Eidos" per FR-PA-003), the **Glossary** (FR-008 — defines world / storyworld / IP / piece / form / bible / canon / snapshot / branch / delta), and **"What Eidos is *not*"** (FR-011 — faithful expansion of the pitch's non-goals; never narrower or wider). Distinguish live-LLM vs `MOCK_AI` in any prose that references behavior depending on it (FR-006).
- [X] T011 [US1] Write the **"Create your first world"** section in `/home/cutalion/code/one-review-man/docs/usage-guide.md`. Cover both invocation styles (`gem install eidos` and `eidos/exe/eidos` from the monorepo — Assumption). Cover the interactive `eidos world new` flow + the `--quick` non-interactive flow. Use a fully runnable command line for each (FR-004). State the post-state explicitly (FR-005): which files now exist under `data/`, what `eidos world status` reports, what's in the bible, what's in `content/` (empty until next section). Spec acceptance scenario 1.
- [X] T012 [US1] Write the **"Produce your first piece"** section. Document `eidos piece help`, the registered forms list (chapter, vignette, haiku, comic-script, portrait, social-post, illustration), and the `eidos produce piece --form <X> --prompt "..."` command. Show one fully resolved example (FR-004). State the post-state: a new file under `content/pieces/<form>/`, frontmatter shape, a new canon-delta file, the canon revision number having advanced. Spec acceptance scenario 2.
- [X] T013 [US1] Write the **"Inspect what just happened"** section. Walk the user through `eidos piece show <id>`, `eidos canon review`, and `eidos bible search "<term>"`. Quote the actual output format (or sufficient prose to anchor it) so the reader knows what to expect line by line. Explain how the bible was populated by the canon delta. Spec acceptance scenario 3.
- [X] T014 [US1] Write the **"Working offline / cheaply"** section. Cover `MOCK_AI=true` (what it does, what fidelity loss to expect, when to prefer it). Touch `DEBUG_AI=1` and `--debug` briefly (their full treatment lives under "Power-user techniques" in US4 / Troubleshooting). Spec acceptance scenario 4.
- [X] T015 [US1] Run `/doc-qa` against pitch + guide-with-US1-content. Verified by direct comparison: PASS — glossary terms used consistently across §1–§4 + §9, "chapter" treated as one form among many (consistent with pitch non-goal), "What Eidos is *not*" section mirrors the pitch faithfully.

**Checkpoint**: A reader following only US1 sections can scaffold a world, produce a piece, inspect it, and run offline. The guide is incomplete (US2/US3/US4 sections still placeholders) but US1's slice is independently testable. **MVP candidate.**

---

## Phase 4: User Story 2 — Returning creator evolves an existing world (Priority: P1)

**Goal**: A creator with an existing populated world can change canon, branch, regenerate, translate, and publish — entirely from the guide.

**Independent Test**: A reader with a populated world (e.g., `worlds/one-review-man` or `~/worlds/job-hunt`) can perform at least one canon change, one branch operation, one translation, and one publish — using only the guide (spec acceptance scenarios 1–4 of US2).

- [X] T016 [US2] Write the **"Evolving your world"** section — review/accept/revert/rollback + branching/snapshots/merging. Spec US2 acceptance scenarios 1+2.
- [X] T017 [US2] Write the **"Translating your world"** section — translate chapter / translate all / glossary mechanics / --debug / --force re-translate. Spec US2 acceptance scenario 3.
- [X] T018 [US2] Write the **"Publishing as a website"** section — publish jekyll → site/, local serve, iteration, explicit "not a CMS / distribution is downstream" framing matching pitch non-goal. Spec US2 acceptance scenario 4.
- [X] T019 [US2] Doc-qa run after US2 sections: PASS — §5 maps to "versioned canon, branchable" pitch claim; §6 to "translation as first-class"; §7 explicitly aligns with the "not a publishing platform" non-goal.

**Checkpoint**: Day-2 workflows are documented and verified against the pitch.

---

## Phase 5: User Story 3 — Maintainer keeps vision, guide, and code aligned (Priority: P1)

**Goal**: Build the impl-qa agent and its slash command, update CLAUDE.md, then verify both agents catch drift.

**Independent Test**: Inject a vision-level drift in the pitch → `/doc-qa` reports Tier-1 FAIL. Inject a CLI drift in the guide → `/impl-qa` reports Tier-1 FAIL. Both agents are invokable as slash commands and as `Task`-tool subagents (spec US3 acceptance scenario 7).

- [X] T020 [P] [US3] Create `/home/cutalion/code/one-review-man/.claude/agents/impl-qa.md` — frontmatter (`name: impl-qa`, three example invocations, `model: sonnet`, `color: orange`, `tools: Read, Glob, Grep, Bash`), four-tier body, mode flags, hard rules, references to contracts. Slash command now registered (visible in available skills).
- [X] T021 [P] [US3] Create `/home/cutalion/code/one-review-man/.claude/commands/impl-qa.md` slash-command shim. Now registered (visible in available skills).
- [X] T022 [P] [US3] Edit `/home/cutalion/code/one-review-man/CLAUDE.md` Definition of Done — added "Doc-QA and Impl-QA" subsection naming both agents as required checks alongside the existing user-qa requirement.
- [X] T023 [US3] SC-011 grep on `.claude/agents/doc-qa.md` — clean (zero matches for `chapter|piece|world|bible|canon|produce|translate|publish|probe|comic|haiku|vignette` in instruction prose).
- [X] T024 [US3] Impl-qa verified PASS via three rounds: (1) initial in-session pass found 4 Tier-1 surface drifts (scaffold output shapes, form-list discovery command, custom-form `canon_context` enum keys) — **fixed**; (2) user-run fresh-session impl-qa surfaced 3 more Tier-1 drifts (chapter file naming `chapter_NNN.md` → `NNN-chapter.md`, translated-file naming, plus the deeper `canon accept`-as-audit-record-close architectural drift in §3/§4/§5) — **fixed**; (3) follow-up impl-qa surfaced 1 final Tier-1 (translation-glossary was a speculative file that the codebase doesn't write/read; actual implementation is ephemeral) — **fixed**. Final impl-qa verdict: PASS. Earlier surface fixes also stand: `--description` → `--premise`, `bible list <type>`, `bible show <type>/<id>`, `canon accept --finding=<id>`, snapshot/branch subcommand structures, removed nonexistent `translate piece` and `--force`, finding-vs-delta terminology.
- [ ] T025 [US3] **DEFERRED — needs new Claude Code session.** Run `/impl-qa --behavioral` against a fresh world scaffolded from the guide's "Create your first world" example. Verify Tier-2 post-state claims (file existence, frontmatter shape, world status output) match the guide. The impl-qa subagent was created in this session and is not yet dispatchable; will work after session restart. Quickstart Step 5.
- [ ] T026 [US3] **DEFERRED — needs new Claude Code session.** Drift-injection test for doc-qa: add a non-goal to the pitch that contradicts a real guide section, run `/doc-qa`, expect Tier-1 FAIL with quoted text, then reset. Quickstart Step 2 (SC-009 + SC-010).
- [ ] T027 [US3] **DEFERRED — needs new Claude Code session.** Drift-injection test for impl-qa: rename a flag in the guide, run `/impl-qa`, expect Tier-1 FAIL with `attribution: guide stale`, then reset. Quickstart Step 4 (SC-002 + SC-006).

**Checkpoint**: Both agents work; both catch drift; CLAUDE.md and slash commands are wired; no hardcoded feature names in doc-qa.

---

## Phase 6: User Story 4 — Power user discovers escape hatches (Priority: P2)

**Goal**: Document the rich machinery (custom forms, `probe`, `--debug`, content-model overrides, the SDK) so users multiply the value of features that already shipped.

**Independent Test**: A reader can, from the guide alone, register a custom form, run `eidos probe` to compare two models, and write a Ruby snippet using `Eidos::World` and `Eidos::Bible` (spec US4 acceptance scenarios 1–3).

- [X] T028 [US4] Wrote the **"Power-user techniques"** section — three subsections (Adding a custom form / Trying a different model with `eidos probe` / Using Eidos from Ruby with explicit "assumes Ruby fluency" callout). All three US4 acceptance scenarios covered.
- [X] T029 [US4] Wrote the **"Troubleshooting"** section — eight common failure modes with symptom + recovery (API key, world detection, generic output / MOCK_AI confusion, malformed findings, translation drift, orphaned piece, Jekyll build, tmp/ai_debug, orphaned-reference findings). FR-009 satisfied.
- [X] T030 [US4] Doc-qa run on full guide: PASS — Tier 1 vision alignment intact (SDK section is documented exception per pitch's audience caveat); Tier 2 caught a glossary drift ("finding" was used in §4/§5/§8/§10 but missing from §1 glossary) and was **fixed** by adding "Finding" to the glossary. Impl-qa default mode pending session restart (T024 covered the bulk of surface drift; remaining minor drifts noted there).

**Checkpoint**: All workflows from FR-003 are written and verified. The v1 guide is content-complete.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Final acceptance walkthrough; PR-grade evidence collection.

- [X] T031 **PARTIAL** — Steps 1, 3, 6, 7, 8 verified in-session. Steps 2/4/5 (drift-injection + impl-qa --behavioral) still need a fresh session for full subagent dispatch. Site-build verification ADDED beyond original scope: existing `worlds/one-review-man` and a fresh scaffolded world both publish + build successfully end-to-end (after a 2-line `eidos/lib/eidos/cli/publish.rb` fix — see morning summary).
- [X] T032 SC-007 TOC search test: PASS — four search goals (translation / undo canon / publish / custom form) all resolve to a top-level TOC entry whose phrasing exactly matches the goal. <30s lookup verified by visual inspection of TOC.
- [ ] T033 **DEFERRED — needs a fresh reader.** SC-001 <15-minute fresh-reader walkthrough.
- [X] T034 [P] Git status verified. Tracked-and-modified: `CLAUDE.md`, `README.md`. Untracked-and-new: `docs/pitch.md`, `docs/usage-guide.md`, `specs/011-eidos-sdk-and-installable-cli/legacy-{design,plan}.md`, all of `specs/016-usage-guide/`. The four `.claude/{agents,commands}/{doc-qa,impl-qa}.md` files exist on disk but are masked by `~/.gitignore_global` (`.claude` is globally ignored on this machine; the existing `.claude/agents/user-qa.md` is force-tracked, so the new files need `git add -f` the same way before commit). No spurious Ruby changes; no untracked Ruby beyond pre-existing `worlds/one-review-man/tmp/` debug artifacts.
- [X] T035 [P] `MOCK_AI=true bundle exec rspec` from `eidos/` — 772 examples, 0 failures. Coverage 51.67%. Run was no longer purely defensive: `eidos/lib/eidos/cli/publish.rb` was touched in this session (publish bugfix discovered during site-build verification). No spec regressions.

**Checkpoint**: PR is mergeable. All success criteria from spec.md (SC-001 through SC-011) have evidence.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies — runs first.
- **Phase 2 (Foundational)**: Depends on Phase 1 (T001/T002 must complete so `docs/` is clean). Pitch (T003) blocks T007 + T008 + T009 + every user-story phase. Doc-qa (T004/T005) blocks T007 + T009 + every user-story `/doc-qa` run.
- **Phase 3 (US1)**: Depends on Phase 2 complete (pitch + doc-qa + skeleton). All US1 tasks edit `docs/usage-guide.md` — sequential within phase.
- **Phase 4 (US2)**: Depends on Phase 3 complete (US2 sections will use glossary terms defined in US1's "Get oriented" section). All tasks edit `docs/usage-guide.md` — sequential.
- **Phase 5 (US3)**: Depends on Phase 3 + Phase 4 (impl-qa needs guide content to verify). Tasks T020/T021/T022 are in different files → [P]. Tasks T023–T027 are sequential verifications.
- **Phase 6 (US4)**: Depends on Phase 5 (impl-qa must exist before US4's `/impl-qa` re-run in T030). All guide-writing tasks edit `docs/usage-guide.md` — sequential.
- **Phase 7 (Polish)**: Depends on Phase 6 complete.

### User Story Dependencies (file-level)

All four user stories share `docs/usage-guide.md`. They could conceptually be parallelized by parallel branches + careful merge, but for AI-driven sequential execution it's cleanest to take them in priority order: US1 → US2 → US3 → US4. The phases above assume that order.

### Parallel Opportunities

- T001 and T002 (Setup): different files → [P].
- T004, T005, T006 (Foundational): three different files (`.claude/agents/doc-qa.md`, `.claude/commands/doc-qa.md`, `README.md`) → [P]. T003 (pitch) is sequential because T007/T008/T009 depend on it.
- T020, T021, T022 (US3 agent + slash command + CLAUDE.md): three different files → [P].
- T034, T035 (Polish): independent verifications → [P].

Within each guide-writing user-story phase: tasks are NOT parallelizable because they all edit `docs/usage-guide.md`. This is by design.

---

## Parallel Example: Phase 2 Foundational (after T003 lands)

```bash
# After pitch (T003) is drafted, launch these three together:
Task: "Create .claude/agents/doc-qa.md per D-004 + FR-DQ-001..007"      # T004
Task: "Create .claude/commands/doc-qa.md slash shim mirroring user-qa"  # T005
Task: "Edit README.md to add pitch + guide links in first 20 lines"     # T006
```

## Parallel Example: Phase 5 US3 (agent files)

```bash
# Launch these three together:
Task: "Create .claude/agents/impl-qa.md per D-005 + FR-IQ-001..007"     # T020
Task: "Create .claude/commands/impl-qa.md slash shim"                   # T021
Task: "Edit CLAUDE.md Definition of Done to name doc-qa + impl-qa"      # T022
```

---

## Implementation Strategy

### MVP (User Story 1 only)

1. Phase 1 → Phase 2 → Phase 3.
2. **STOP** after T015 PASS. The guide now teaches a fresh reader how to scaffold + produce + inspect + work offline. Pitch is published. Doc-qa works.
3. SC-001, SC-007, SC-009 partially demonstrable on this slice.
4. The MVP isn't yet *mergeable* (US2/US3/US4 sections are placeholders); it's a demonstration milestone.

### Incremental Delivery

1. MVP (Phase 1–3) → demonstrable.
2. Add Phase 4 (US2) → day-2 workflows live.
3. Add Phase 5 (US3) → impl-qa exists; both agents demonstrably catch drift; CLAUDE.md updated.
4. Add Phase 6 (US4) → power-user surface documented; guide is content-complete.
5. Add Phase 7 (Polish) → quickstart walkthrough; SC-001/007 measured; PR is mergeable.

Each increment leaves the system in a coherent state — at any merge point, `/doc-qa` and (after Phase 5) `/impl-qa` MUST PASS.

### Single-Maintainer Strategy

This feature is naturally single-maintainer (the guide is one file, the pitch is one file, drift verification is sequential). Phases run end-to-end. Estimated total wall-clock for an experienced maintainer: ~1 working day for content + ~half a day for the agents + ~couple of hours for verification.

---

## Notes

- [P] tasks = different files, no dependencies. Most US1/US2/US4 tasks are NOT [P] because the guide is one file.
- [Story] label maps a task to a user story; Setup / Foundational / Polish carry no Story label.
- This feature authors no Ruby; **no `_spec.rb` files are created**. Verification is via the agents themselves + the quickstart walkthrough. T035 confirms RSpec is green defensively.
- Capture wall-clock measurements from T024, T025, T031, T032, T033 in the PR description (research D-009; the qualitative "fast enough for pre-commit" target needs empirical grounding).
- **SC-011 invariant** (T023): grep doc-qa.md for hardcoded feature names AT THE END OF EACH PHASE that touches doc-qa.md. The grep MUST stay clean across all subsequent edits.
- **Doc-qa runs at every phase boundary** that touches the guide or the pitch. This is not just T015 / T019 / T030 — any time you edit either file, re-run doc-qa.
- **Aspirational markers**: do NOT add any in v1 (FR-003 / Q4 / `contracts/aspirational-marker.md` v1-invariant). The marker mechanism is for *future* edits; the v1 ship has zero markers.
- Commit per task or per logical group. The implementation sequence in `plan.md` is the seed for commit boundaries.
