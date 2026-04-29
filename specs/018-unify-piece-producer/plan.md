# Implementation Plan: Unify the chapter producer + add a global canon revision counter

**Branch**: `018-unify-piece-producer` | **Date**: 2026-04-29 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/018-unify-piece-producer/spec.md`

## Summary

Bring `eidos produce chapter` under the same `PieceProducer` contract every other form already uses; retire `Eidos::ChapterGenerator`, `Eidos::Producers::ChapterProducer`, and `eidos produce write`. Add a global `canon.revision` integer to `data/world_state.yml`; advance it atomically with every delta apply (produce, revert, rollback); display it in `eidos world status`; thread it into piece frontmatter as `canon_version` instead of the literal string `unversioned`. Per the Q2 clarification, an in-place migration adds the field to existing worlds on first read; that migration code is temporary and will be removed in/after 018c. Per Q1, chapter `id` becomes a uniform hash like every other form, with `chapter_number` and the human-readable `NNN-chapter.md` filename derived from a separate frontmatter field.

## Technical Context

**Language/Version**: Ruby 3.3.5, `# frozen_string_literal: true` on every file
**Primary Dependencies**: existing — Thor (CLI), ruby-openai (LLM), tty-prompt, tty-spinner, rainbow, dotenv, YAML stdlib. No new gems
**Storage**: YAML files on disk under `worlds/<name>/data/`. New: a `canon` mapping with `revision: N` integer in `world_state.yml`. Modified: every piece's frontmatter (chapter included) carries a hash `id` + `canon_version` (integer or snapshot label)
**Testing**: RSpec with `MOCK_AI=true`. Three new failing tests (one per user story) before implementation, plus migration of existing chapter-related specs from `ChapterGenerator` to `PieceProducer`
**Target Platform**: Linux/macOS dev workstation; CI on the same gem
**Project Type**: Single-project Ruby gem (engine + SDK + CLI)
**Performance Goals**: No change to producer hot-path latency. The revision-counter increment is a sub-millisecond YAML write occurring atomically with the existing delta-apply write
**Constraints**: No new producer class — extend the unified `PieceProducer` to support chapter's structured-output contract (title/summary/new-characters extraction from LLM JSON). Atomic apply: bible mutation + revision counter increment must succeed together or roll back together (FR-007). No silent fallback when `canon.revision` is missing — in-place migration with a user-visible log line OR raise (FR-006). Migration code is temporary scaffolding scheduled for retirement (FR-006a)
**Scale/Scope**: ~5 source files modified (`piece_producer.rb` extended; `produce.rb` Thor commands updated; `world.rb` scaffold updated; `helpers.rb` status output updated; `canon_delta.rb` apply! threaded with WorldState). 2 source files deleted (`chapter_generator.rb`, `producers/chapter_producer.rb`). 1 new source file (`world_state.rb`). 4 spec files deleted/migrated, 2 new spec files added. Net codebase delta: removal-heavy, ~−300 to −600 LOC

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Engaged? | Disposition |
|---|---|---|
| I. Test-First with Mock AI | **Yes (heavy)** | Three failing tests written before implementation (one per user story). All migrated chapter specs must pass under `MOCK_AI=true`. SimpleCov coverage stays at or above the floor. |
| II. Producer Contract | **Yes (central)** | This feature *consolidates* the Producer Contract into one path. Every form (chapter included) flows through `PieceProducer`. The `Producer.register(:chapter, ChapterProducer)` registration at `chapter_producer.rb:99` is removed because chapter is no longer a special-cased producer. |
| III. Dependency Injection | **Yes** | `PieceProducer` already accepts injectable collaborators via constructor kwargs. Extending it for chapter's structured-output flow MUST preserve injection — no new hard-coded service instantiation. The new `WorldState` helper is constructor-injectable into `CanonDelta#apply!`. |
| IV. Canon Integrity with Versioned IP | **Yes (central)** | This feature is the implementation half of canon versioning. `canon.revision` becomes the user-visible version. Atomic apply: bible mutation + revision-counter increment succeed together or fail loudly. Every piece records `canon_version`. |
| V. Security by Default | No | No key handling, no logging surface change. |
| VI. Pluggable AI Services with Evals | No | No new AI service. The structured-output extraction for chapter is an LLM-prompt detail, not a service-layer change. |
| VII. Separation of Concerns | **Yes (reaffirmed)** | After 018a, the engine layer has *one* producer path. CLI doesn't contain canon-mutation logic. |

**Gate verdict: PASS** — no violations. Principles I, II, III, IV, VII are actively engaged and discharged below.

**Re-check note (post-Phase 1)**: After contracts are written, re-verify that no inadvertent silent-fallback paths slip in around the missing-`canon.revision` migration. The migration is the most likely place for an unintended fallback to creep back. Address explicitly in `contracts/world-state-migration.md`.

## Project Structure

### Documentation (this feature)

```text
specs/018-unify-piece-producer/
├── spec.md              # Already written; clarified Q1/Q2
├── plan.md              # This file
├── research.md          # Phase 0 — five resolved decisions
├── data-model.md        # Phase 1 — entities and shapes
├── contracts/
│   ├── chapter-piece-parity.md       # What a chapter file looks like post-018a
│   ├── canon-revision-atomicity.md   # Bible-and-counter atomicity invariant
│   └── world-state-migration.md      # FR-006 migration; FR-006a retirement
├── quickstart.md        # Phase 1 — verification steps for SC-001..SC-007
├── checklists/
│   └── requirements.md  # Already written
└── tasks.md             # Phase 2 (created later by /speckit.tasks)
```

### Source Code (repository root)

```text
eidos/
├── lib/eidos/
│   ├── producers/
│   │   ├── piece_producer.rb              # MODIFIED — gain structured-output support for chapter; current_canon_version reads from WorldState
│   │   └── chapter_producer.rb            # DELETED (Producer.register(:chapter, …) line removed)
│   ├── chapter_generator.rb               # DELETED
│   ├── canon_delta.rb                     # MODIFIED — apply! accepts world_state:, increments atomically
│   ├── world_state.rb                     # NEW — read/write canon.revision; FR-006 in-place migration; flagged temporary per FR-006a
│   └── cli/
│       ├── produce.rb                     # MODIFIED — produce chapter routes through PieceProducer; produce write Thor method removed
│       ├── world.rb                       # MODIFIED — scaffold writes canon: { revision: 0 } in world_state.yml
│       └── helpers.rb                     # MODIFIED — render_status_report adds a "Canon revision: N" line
└── spec/
    ├── chapter_generation_spec.rb                       # DELETE
    ├── eidos/chapter_generator_spec.rb                  # DELETE
    ├── eidos/producers/chapter_producer_spec.rb         # DELETE
    ├── eidos/producers/chapter_producer_back_compat_spec.rb  # DELETE
    ├── integration/chapter_number_regression_spec.rb    # MIGRATE — drive PieceProducer
    ├── integration/produce_chapter_prompt_flag_spec.rb  # MIGRATE — drive PieceProducer
    ├── eidos/producers/piece_producer_chapter_spec.rb   # NEW — chapter-via-PieceProducer parity
    ├── eidos/world_state_spec.rb                        # NEW — read/write/migrate
    └── eidos/canon_delta_atomicity_spec.rb              # NEW — atomicity of apply! + revision increment
```

Out of scope (untouched):

- `eidos/lib/eidos/forms/chapter.yml` — already exists; this feature wires up consumption via `PieceProducer`, not the form definition.
- `eidos/lib/eidos/cli/chapter_cli.rb` and `character_cli.rb` — SDK-shadow CLIs are 018b's scope.
- `worlds/one-review-man/content/chapters/*.md` — legacy chapter files. They remain readable via existing default-synthesis in `Piece#from_file`. Migration to new frontmatter is 018c.
- `eidos/lib/eidos/story_bible_exporter.rb` — feature 017 already cleaned the publish path.
- `docs/usage-guide.md` — the guide already describes the post-018a behavior. No edits expected. Re-verified by `/impl-qa --behavioral` per FR-013.

**Structure Decision**: Single-project Ruby gem. ~5 modified files + 1 new helper class + 2 deleted classes. Removal-heavy net delta.

## Phase 0: Outline & Research

The Technical Context has no `NEEDS CLARIFICATION` markers — Q1/Q2 from `/speckit.clarify` resolved the two architectural forks. `research.md` documents five resolved decisions:

**D-001 — How to fold chapter's structured-output contract into `PieceProducer`.** *Decision:* extend `PieceProducer` with a per-form "structured output" hook. The chapter form gains a `structured_output: true` flag (in `chapter.yml` or in the `Form` schema) declaring that its LLM output is a JSON envelope (with `title`, `summary`, `new_characters`, `body`) rather than a single-blob body. `PieceProducer#produce` checks the flag and dispatches accordingly. Other forms keep their current single-body behavior. *Alternative considered:* keep `ChapterGenerator` and have `PieceProducer` delegate to it for the chapter form; rejected because it doesn't actually retire the legacy code, just hides it. *Alternative considered:* parse all forms as structured JSON; rejected because most forms don't have structured fields and the parsing overhead is unwarranted.

**D-002 — Where the revision counter lives and who owns its read/write.** *Decision:* a new small class `Eidos::WorldState` at `eidos/lib/eidos/world_state.rb`. It encapsulates reading `data/world_state.yml`, the in-place migration when `canon.revision` is missing (per FR-006), atomic increment-and-write, and the typed error path when migration cannot run (e.g., the file itself missing — corrupt world). Public API: `current_revision`, `advance_revision!`. *Alternative considered:* fold into `WorldConfig`; rejected because `WorldConfig` is for static config and the revision is dynamic state. *Alternative considered:* fold into `Canon` (the SDK façade); rejected because increment happens deep inside `CanonDelta#apply!`, before the SDK is in scope.

**D-003 — Atomic apply: how to ensure bible mutation + revision counter increment succeed together.** *Decision:* `CanonDelta#apply!` accepts a new `world_state:` injectable kwarg (defaulting to `WorldState.new(world_path:)`). After all bible-mutating sub-operations succeed (just before the existing `@applied_at = Time.now.utc` stamp at line ~243 in current code), call `world_state.advance_revision!` *inside* the existing `begin/rescue` block as the bible mutations. If the increment write fails, the existing `rollback!(bible, applied_actions)` path rolls back the bible mutations too. Both succeed or both fail. *Alternative considered:* increment first, mutate second; rejected because a mid-mutation failure would leave the counter ahead of the bible (worse than the inverse). *Alternative considered:* delegate the increment to `PieceProducer` after `apply_delta` returns; rejected because `apply!` is also called from `canon revert` and `canon rollback`, and we want the increment in one place.

**D-004 — Chapter `id` generation.** *Decision:* chapter uses the same hash-id strategy as other forms (the existing `generate_ulid` method in `PieceProducer` line 212). The `chapter_number` field is computed by the existing `next_chapter_id` method in `PieceProducer` line 204 — *renamed* to `next_chapter_number` (since after 018a it's no longer the id, it's the chapter number). The filename is derived from `chapter_number` via `format('%03d-chapter.md', chapter_number)` in the writer. *Alternative considered:* numeric chapter id (e.g. `id: "001"`); rejected by Q1 clarification in favor of uniform hash semantics.

**D-005 — Removal of `eidos produce write`.** *Decision:* delete the Thor method `def write(chapter = nil)` at `produce.rb` line 373 and its `desc/option` lines (369–372). Delete any agent-runner support code only if it is no longer referenced (grep first to confirm). Specs that exercise `produce write` are deleted, not migrated — there is no replacement command. The `UnknownCommandHelp` mixin already on the Thor class will surface a friendly error if someone types `eidos produce write`. *Alternative considered:* keep `produce write` as a stub that says "removed in 018a"; rejected — Thor's unknown-command help is more honest and removes the maintenance burden.

**Output**: `research.md` (written below).

## Phase 1: Design & Contracts

**Prerequisites**: research.md complete (Phase 0 above).

1. **Entities → `data-model.md`**:
   - **`canon.revision`** field in `data/world_state.yml` — non-negative integer, starts at 0 on scaffold, advances by exactly 1 per delta apply.
   - **`Eidos::WorldState`** Ruby class — encapsulates read/write/migrate. Public API: `current_revision`, `advance_revision!` (atomic write + return new value).
   - **Piece frontmatter** (post-018a, all forms including chapter) — `id` is a hash, `canon_version` is integer or snapshot label, never `'unversioned'` for new pieces. Chapter additionally carries `chapter_number`.
   - **`Form` schema extension** — chapter (and any future structured-output form) gains a `structured_output: true` flag. `Form` reads it; `PieceProducer` dispatches on it.

2. **Contracts → `contracts/`**:
   - **`contracts/chapter-piece-parity.md`** — what shape a chapter file MUST have post-018a to be considered "produced via the unified contract." Lists every required frontmatter key, the canon-delta link, and the on-disk filename derivation. Defines the regression test that asserts chapter and (e.g.) vignette have the same shape modulo form-specific fields.
   - **`contracts/canon-revision-atomicity.md`** — the atomicity invariant (FR-007). Defines what it means for the bible+counter to be consistent; defines the failure modes and what state the world is in after each (always one of {pre-apply, post-apply}, never partial).
   - **`contracts/world-state-migration.md`** — the FR-006 migration: when it triggers, how it computes the revision (`count(data/canon_deltas/*.yml)`), what it logs, when it MUST raise instead (e.g., when `world_state.yml` itself is missing — corrupt world), and the FR-006a deletion timeline that ties to 018c.

3. **`quickstart.md`** — verification steps mirroring SC-001..SC-007:
   - Step 1: write the three failing specs (one per user story) and verify they fail on `main`.
   - Step 2: implement `WorldState`; verify revision-counter spec passes.
   - Step 3: extend `PieceProducer` with structured-output support; verify chapter-via-PieceProducer parity spec passes.
   - Step 4: thread atomicity through `CanonDelta#apply!`; verify atomicity spec passes.
   - Step 5: delete `ChapterGenerator`, `ChapterProducer`, `produce write`; migrate dependent specs; verify the full suite passes.
   - Step 6: scaffold a fresh world; produce a piece of every form; verify revision advances, frontmatter is correct, canon delta is written.
   - Step 7: re-run `/impl-qa --behavioral`; verify all four T025 Tier-2 failures flip to PASS (SC-004).
   - Step 8: confirm `worlds/one-review-man` still works — legacy chapter files readable; SC-007.
   - Step 9: structural — `grep -r "ChapterGenerator" eidos/lib/` returns zero (SC-005).

4. **Agent context update**:
   - Run `.specify/scripts/bash/update-agent-context.sh claude` to refresh CLAUDE.md's footer with the 018 entry.

**Output**: `data-model.md`, `contracts/{chapter-piece-parity, canon-revision-atomicity, world-state-migration}.md`, `quickstart.md`.

## Post-Design Constitution Re-check

After Phase 1 artifacts are drafted:

- **Principle I (Test-First)**: failing specs precede implementation in every step of `quickstart.md`. ✓
- **Principle II (Producer Contract)**: `chapter-piece-parity.md` is the contract — every form goes through one producer with one frontmatter shape. ✓
- **Principle III (DI)**: `WorldState` is constructor-injectable into `CanonDelta#apply!`. `PieceProducer` keeps its existing kwarg-injection. ✓
- **Principle IV (Canon Integrity)**: `canon-revision-atomicity.md` codifies the invariant. ✓
- **Principle VII (Separation of Concerns)**: producer doesn't grow CLI code; CLI doesn't grow canon-mutation code. The new `WorldState` helper sits at the engine layer like other state-access helpers. ✓

**Critical risk to monitor in implementation**: the in-place migration in `WorldState` has a banned-pattern hazard — if it silently writes 0 when `count(data/canon_deltas/*.yml)` returns 0 because the directory doesn't exist (vs. exists-but-empty), that's a fallback that hides world corruption. The contract `world-state-migration.md` MUST explicitly require: `data/canon_deltas/` directory exists → use file count (zero is valid for a fresh-but-not-yet-produced world); `data/canon_deltas/` directory absent → raise (it's a corrupt world). Reviewer call-out for the implementation PR.

**Gate re-verdict: PASS** (deferred to post-implementation review of the actual diff).

## Complexity Tracking

No constitution violations. No complexity entries.

## Implementation Sequence (informative — full ordering lands in `tasks.md`)

1. **Failing specs first** — three new specs (one per user story), each failing on current `main`.
2. **`WorldState` class** — implement read/write/atomic-advance + the FR-006 migration with the FR-006a retirement marker. Spec passes for US2.
3. **`CanonDelta#apply!` atomicity** — accept injectable `world_state:`, advance revision inside the existing rescue block. Atomicity spec passes.
4. **`PieceProducer` extension** — add structured-output support. Wire chapter's `chapter_number` derivation. Update `current_canon_version` to read from `WorldState` instead of returning `'unversioned'`. Chapter-via-PieceProducer parity spec passes.
5. **CLI rewrites** — `produce chapter [N]` becomes a thin shortcut over `produce piece --form chapter` with chapter-number injection; `produce write` Thor method deleted; `world.rb` scaffold writes `canon: { revision: 0 }`; `helpers.rb#render_status_report` shows the revision.
6. **Legacy file deletion** — delete `chapter_generator.rb`, `producers/chapter_producer.rb`, related specs. `Producer.register(:chapter, ...)` registration removed. SC-005 grep clean.
7. **Spec migration** — chapter-related integration specs migrate to drive `PieceProducer`.
8. **Suite green** — `MOCK_AI=true bundle exec rspec` all green; coverage held.
9. **Behavioral re-verification** — `/impl-qa --behavioral` passes (SC-004); manual run confirms `worlds/one-review-man` still works (SC-007); grep confirms removal (SC-005).

## Phase 2 (out of scope for this command)

Tasks decomposition lives in `tasks.md` and is produced by `/speckit.tasks`.
