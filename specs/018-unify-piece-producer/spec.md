# Feature Specification: Unify the chapter producer + add a global canon revision counter

**Feature Branch**: `018-unify-piece-producer`
**Created**: 2026-04-29
**Status**: Draft
**Input**: User description: "Bring eidos produce chapter under the unified PieceProducer contract; retire ChapterGenerator and produce write; add a global canon revision counter to world_state.yml; thread the revision into piece frontmatter as canon_version. Out of scope: SDK-shadow CLI removal (018b) and worlds/one-review-man migration (018c)."

## Clarifications

### Session 2026-04-29

- Q: How should the chapter form's `id` relate to the chapter number under the unified piece contract? → A: Hash `id` like every other form (uniform semantics across forms); the chapter number lives in a separate frontmatter field (`chapter_number`); the filename `NNN-chapter.md` is derived from `chapter_number` so the human-readable on-disk shape is preserved. `eidos piece show <hash-id>` is the canonical lookup; users referencing a chapter by number look it up via `eidos piece list --form chapter` first (or use the SDK).
- Q: How should existing worlds (which lack a `canon.revision` field in `world_state.yml`) be handled when first touched by post-018a code? → A: **In-place migration on first read** — the producer notices the missing field, computes the revision retroactively from `count(data/canon_deltas/*.yml)`, writes it to `world_state.yml` with a single user-visible log line, and proceeds. **Critically: this migration code is temporary scaffolding.** The only legacy world this project carries is `worlds/one-review-man`. Feature 018c will migrate that world explicitly. Once 018c lands, the in-place-migration code in 018a becomes vestigial and MUST be removed (either as the final task in 018c or as a small follow-up cleanup feature). 018a's spec calls this out so the migration code does not silently turn into permanent legacy.

## Context

Feature 016's impl-qa `--behavioral` run surfaced four Tier-2 behavioral failures in the v1 ship of `docs/usage-guide.md`. All four trace to two architectural gaps in the codebase, not to gaps in the guide. Feature 018a closes both.

**Gap 1: chapter is a legacy producer.** When you run `eidos produce chapter`, the code routes through `Eidos::ChapterGenerator` — a class that predates the post-014 `PieceProducer` contract. As a result, chapter files at `content/chapters/NNN-chapter.md` get a different frontmatter schema (no `id`, no `form`, no `canon_delta_ref`) and *no canon-delta file is written under `data/canon_deltas/`*. The user-facing guide describes the post-state as universal: every produce writes a piece file with consistent frontmatter and a canon delta. The chapter path silently violates that contract, and no other form does. There are also two other legacy producers riding on the same dead-end model: `eidos produce write` (an experimental agent-based chapter writer) and any helpers that exist only because chapter is special.

**Gap 2: there is no global canon-revision counter.** The guide describes `data/world_state.yml` as carrying a `canon.revision` field that increments on every successful canon-delta apply, displayed by `eidos world status`, and threaded into produced pieces' frontmatter as `canon_version`. The implementation does not have this. Reality: per-entity revision history under `data/story_bible/revisions/` (created on demand) plus snapshot-name-based piece versioning that writes the literal string `unversioned` into piece frontmatter when no snapshot is anchored. The single integer revision the guide promises is missing.

The user's direction is: **bring the code into compliance with the guide, not the other way around**. The guide is the desired user experience; this feature makes it true. Two related cleanups (out of scope here, addressed in 018b/018c) are: removing SDK-shadow CLI commands and migrating the existing `worlds/one-review-man` directory to the new chapter shape.

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Producing a chapter writes a canon delta and modern frontmatter, like every other form (Priority: P1)

A creator runs `eidos produce chapter` (with or without an explicit number) on a fresh world. After the command finishes, the chapter file at `content/chapters/NNN-chapter.md` has the same frontmatter shape as a piece of any other form (id, form, generated_date, canon_delta_ref, plus form-specific extras like title and summary), and a canon-delta file at `data/canon_deltas/<id>.yml` records exactly what the chapter introduced into the canon — applied immediately to the bible.

**Why this priority**: this is the central contract violation. Every guide section about canon evolution presumes it; today, chapter is the exception that breaks the frame. Fixing it removes the exception.

**Independent Test**: scaffold a fresh world; run `eidos produce chapter`; assert the chapter file's frontmatter contains `id`, `form: chapter`, and a `canon_delta_ref` that resolves to a real file; assert that file exists at `data/canon_deltas/<id>.yml` and has the new-piece schema (`piece_id`, `applied_at`, the delta sections); assert the bible reflects whatever the chapter introduced.

**Acceptance Scenarios**:

1. **Given** a fresh world with `MOCK_AI=true`, **When** the user runs `eidos produce chapter --auto`, **Then** the resulting `content/chapters/<NNN>-chapter.md` has YAML frontmatter containing `id`, `form: chapter`, `generated_date`, `canon_delta_ref`, plus chapter-specific keys (`title`, `summary`, etc.). The frontmatter contains *no* legacy-only keys that contradict the new contract.
2. **Given** the same fresh world, **When** the user runs `eidos produce chapter --auto`, **Then** a new file appears at `data/canon_deltas/<id>.yml` whose `piece_id` matches the chapter's frontmatter `id`, whose `applied_at` is timestamped, and whose body declares the entities the chapter introduced. After the command, the bible (`data/story_bible/`) reflects those entries.
3. **Given** a world that already has chapters 1–3 produced, **When** the user runs `eidos produce chapter --auto`, **Then** chapter 4 is created (auto-numbering picks up from the last existing chapter), with the same modern frontmatter and canon-delta contract.
4. **Given** the same world, **When** the user runs `eidos produce piece --form chapter`, **Then** that path produces an equivalent chapter file (same frontmatter shape, same canon-delta-write contract). The two invocations are interchangeable; `produce chapter` is a thin shortcut over `produce piece --form chapter`.

---

### User Story 2 — The canon revision number exists, advances, displays, and is recorded on every piece (Priority: P1)

A creator scaffolds a fresh world. `eidos world status` shows the current canon revision as `0`. The creator produces a piece — any form — and `eidos world status` now shows revision `1`. The piece's frontmatter records `canon_version: 1`. After three more clean produces, the revision is `4`. After a `canon revert`, it advances to `5` (because revert applies a new inverse delta — see Edge Cases).

**Why this priority**: every guide section that mentions "canon revision" presumes a single integer that increments per delta apply. Without it, the `world status` description and the piece frontmatter description are both fiction. This story makes them true.

**Independent Test**: scaffold a fresh world; run `eidos world status` and find a `Canon revision: 0` line; produce a piece; re-run `world status` and find `Canon revision: 1`; open the produced piece's frontmatter and find `canon_version: 1`.

**Acceptance Scenarios**:

1. **Given** a fresh world, **When** the user runs `eidos world status`, **Then** the output includes a line stating the current canon revision is `0`.
2. **Given** a fresh world, **When** the user runs any `eidos produce piece --form <X>` (or `eidos produce chapter`) under `MOCK_AI=true`, **Then** afterward `eidos world status` reports the revision has incremented by exactly 1, and the produced piece's frontmatter carries `canon_version: <N>` matching the new revision.
3. **Given** a world at revision `R`, **When** the user runs `eidos canon revert --finding=<id>` to undo a delta, **Then** the revision advances (revert is itself a canon mutation; the revision is the count of applied mutations, not net additions). The piece file's frontmatter is left untouched (it's an immutable historical artifact).
4. **Given** a world at revision `R`, **When** the user pins generation to a snapshot via `eidos produce piece --form <X> --snapshot <name>`, **Then** the produced piece's frontmatter carries `canon_version: <name>` (the snapshot label) instead of an integer. This is the one documented exception.
5. **Given** a fresh world, **When** the user inspects `data/world_state.yml`, **Then** the file contains a `canon.revision: 0` field. After produces, that field reflects the same number `world status` reports.

---

### User Story 3 — Legacy chapter producers are gone (Priority: P2)

A maintainer or curious user runs `eidos help produce` and the listed subcommands no longer include `eidos produce write`. Searching the codebase for `Eidos::ChapterGenerator` returns zero references in `eidos/lib/`. Existing worlds that produce chapters via the old path are not broken — they simply use the new path now.

**Why this priority**: removing the legacy code is the cleanup half of "make code match guide." Without retirement, the dead path stays around to mislead the next maintainer. P2 because the *behavior* (US1 + US2) is what the guide describes; the cleanup is bookkeeping that follows.

**Independent Test**: `grep -r "ChapterGenerator" eidos/lib/` returns nothing. `eidos produce help` lists no `write` subcommand. The full RSpec suite stays green (any spec that previously exercised `ChapterGenerator` either is removed or now drives `PieceProducer` instead).

**Acceptance Scenarios**:

1. **Given** the post-018a codebase, **When** a maintainer greps `eidos/lib/` for `ChapterGenerator`, **Then** the result is zero matches. The class file `eidos/lib/eidos/chapter_generator.rb` no longer exists.
2. **Given** the post-018a codebase, **When** a user runs `eidos produce help`, **Then** the output does not list a `write` subcommand. Running `eidos produce write` returns the same friendly unknown-command help that `eidos some-typo` would return.
3. **Given** the post-018a codebase, **When** the full RSpec suite runs under `MOCK_AI=true`, **Then** all examples pass with zero failures and SimpleCov coverage stays at or above the committed `EIDOS_COVERAGE_FLOOR`.

---

### Edge Cases

- The user invokes `eidos produce chapter --auto` against a world that has *legacy* chapter files in `content/chapters/` (left by previous-version produces). The new producer must auto-number past the highest existing chapter regardless of whether the legacy file has the new frontmatter. (Migration of legacy files into the new shape is *out of scope*; that's 018c. Until then, legacy chapter files should still be readable by `eidos piece show` and `eidos chapter list` even though their frontmatter omits the new keys — current `Eidos::Piece#from_file` already synthesizes defaults for missing keys.)
- The user runs `eidos canon revert --finding=<id>`. The revision counter MUST advance (because revert applies an inverse delta — it's a canon mutation). The piece file's frontmatter is *not* edited (pieces are immutable historical artifacts).
- The user runs `eidos canon rollback <type> <id> <revision>`. This is a per-entity rollback, not a global. It writes a per-entity revision marker but should *also* increment the global counter, because the canon as a whole has changed.
- The user runs `eidos produce piece --dry-run`. No piece file, no canon delta, no bible mutation, no revision advance. Verified by impl-qa Tier-2 already; must continue to hold.
- The user pins generation with `--snapshot <name>` against a non-existent snapshot. Existing snapshot-validation behavior is preserved; this feature does not change it.
- A world's `world_state.yml` already has a top-level `canon` mapping (unlikely on existing worlds; more likely on worlds scaffolded post-018a). The producer code that increments the counter must not silently no-op if the field is missing (banned-pattern: silent fallback). Either it ensures the field exists at scaffold time, or it raises a typed error pointing at the missing field. The implementation MUST NOT pretend revision was advanced when the file was not actually updated.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: `eidos produce chapter [N]` and `eidos produce piece --form chapter` MUST be functionally equivalent. Both go through the same producer path (`PieceProducer` or its successor) and produce a chapter file with identical frontmatter shape and an identical canon-delta-write contract. The auto-numbering of `produce chapter` (and the optional explicit `[N]` argument) is preserved as a UX shortcut implemented on top of the unified path; it determines the value written into `chapter_number`, not the `id`.
- **FR-002**: Chapter files written by `eidos produce chapter` MUST have YAML frontmatter containing, at minimum: `id` (a hash, same shape as every other form's `id` — *not* the chapter number), `form: chapter`, `generated_date`, `canon_delta_ref`, `canon_version`, plus chapter-specific keys (`title`, `summary`, `chapter_number`, etc. as appropriate). The chapter file's filename on disk MUST be `NNN-chapter.md` where `NNN` is the zero-padded `chapter_number` from frontmatter — so the human-readable on-disk shape users currently see is preserved. Legacy keys that conflict with the new contract MUST NOT be written.
- **FR-003**: A successful `eidos produce chapter` invocation MUST write a canon-delta file at `data/canon_deltas/<id>.yml` with the same schema as any other piece form (`piece_id`, `applied_at`, plus the delta sections). The bible at `data/story_bible/` MUST reflect the applied delta after the produce returns.
- **FR-004**: `Eidos::ChapterGenerator` MUST be removed from `eidos/lib/`. Every former call site MUST be updated to use the unified path. The class file itself MUST NOT remain as a stub; it is fully retired.
- **FR-005**: `eidos produce write` MUST be removed from the CLI surface. The corresponding Thor method, any supporting agent-runner code, and any tests that exercise it MUST be removed. Running `eidos produce write` after the change MUST surface the friendly unknown-command help (the existing `UnknownCommandHelp` mixin handles this automatically once the method is gone).
- **FR-006**: `data/world_state.yml` (both the scaffold output and existing worlds) MUST carry a `canon.revision` integer field. On scaffold, the value is `0`. When a producer or status-reader encounters a world whose `world_state.yml` is missing the field, it MUST run a one-shot **in-place migration** that adds it before any other operation: compute the value as `count(data/canon_deltas/*.yml)` (each delta represents one historical apply), write it back to `world_state.yml`, and emit a single user-visible log line of the form `Migrating <world>/data/world_state.yml: adding canon.revision = <N>`. Silent fallback (e.g. defaulting to 0 without writing) is forbidden under the project's banned-patterns rule. This migration code is **temporary scaffolding** — see FR-006a.
- **FR-006a**: The in-place migration introduced by FR-006 MUST be removed in or immediately after feature 018c (which migrates `worlds/one-review-man` explicitly). The project carries exactly one long-running legacy world; once that world is migrated, no future scaffolded world will lack the field, and the migration path becomes dead code. 018a's documentation MUST flag this code as scheduled for retirement, and 018c's spec MUST take ownership of the removal task. Allowing this code to outlive its purpose is itself a banned-patterns regression.
- **FR-007**: After every successful canon-delta apply (inside the unified producer), the `canon.revision` field in the world's `world_state.yml` MUST be incremented by exactly 1 *as part of the same operation* — not in a separate cleanup pass. If the bible was updated but the revision counter was not, the operation must fail loudly (raise) rather than leave the world in an inconsistent state.
- **FR-008**: `eidos canon revert --finding=<id>` MUST advance the revision counter by exactly 1 (a revert is a canon mutation, recorded as a new delta application). `eidos canon rollback <type> <id> <revision>` MUST also advance the global revision counter by exactly 1.
- **FR-009**: `eidos world status` output MUST include a line that states the current canon revision in a form a creator can read at a glance (e.g. `Canon revision: 4`). The exact label and formatting are an implementation detail; the requirement is that the field is visible.
- **FR-010**: Every produced piece (any form, including chapter) MUST record the canon revision the piece was produced from in its frontmatter as `canon_version`. The value is the integer revision number when no snapshot is pinned, OR the snapshot label when `--snapshot <name>` is passed. The literal string `unversioned` MUST NOT appear as a `canon_version` value on newly-written pieces; if a piece is somehow produced before `canon.revision` exists, the producer raises rather than writing `unversioned`.
- **FR-011**: The full RSpec suite MUST pass under `MOCK_AI=true` after the change, with zero failures. SimpleCov coverage MUST stay at or above the committed `EIDOS_COVERAGE_FLOOR`. New tests MUST cover the chapter-via-PieceProducer path, the revision-counter advance on produce, and the revision-counter advance on revert/rollback. (Per Constitution Principle I, failing tests are written *before* implementation in each US slice.)
- **FR-012**: Pre-existing chapter files in any world MUST remain readable by `eidos piece show`, `eidos chapter list` (until 018b retires it), and the SDK without modification. Migration of legacy frontmatter into the new shape is explicitly **out of scope**; that is feature 018c. The new code MUST tolerate reading a legacy chapter file (synthesizing defaults for missing fields) without raising.
- **FR-013**: `docs/usage-guide.md` MUST be re-verified by `/impl-qa --behavioral` after the change. All four T025 Tier-2 failures from feature 016's acceptance run MUST flip from FAIL to PASS. If the guide and codebase still disagree on any point at the end of this feature, that disagreement MUST be either (a) fixed in the code in this feature, or (b) flagged as a follow-up ticket — never silently accepted.

### Key Entities

- **Canon Revision**: a non-negative integer stored at `data/world_state.yml#canon.revision`. Starts at 0 on scaffold. Increments by exactly 1 on every successful canon-delta application (whether from a produce, a revert, or a rollback). Read by `eidos world status` and by every producer that writes piece frontmatter.
- **Piece Frontmatter** (post-018a, all forms including chapter): YAML at the top of every piece file containing `id` (a hash, uniform across forms — for chapter, this is *not* the chapter number), `form`, `generated_date`, `canon_delta_ref`, `canon_version` (integer or snapshot label), plus form-specific keys (e.g. `title`, `summary`, `chapter_number` for chapter; nothing extra for haiku). For chapter specifically, the filename `NNN-chapter.md` is derived from the form-specific `chapter_number` field — `id` and `chapter_number` are independent.
- **Canon Delta**: file at `data/canon_deltas/<id>.yml` written by every successful produce (any form). Same schema as today for non-chapter forms. Chapter now writes one too.
- **Unified Producer**: the single code path through which all forms (chapter, vignette, haiku, comic-script, portrait, social-post, illustration, short-story, plus any custom form) flow. After 018a, no form has its own producer class; all forms use the same producer. (Naming the producer class is an implementation detail for `/speckit.plan`.)

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of `eidos produce chapter` invocations produce a chapter file with `id`, `form: chapter`, `canon_delta_ref` in its frontmatter and a corresponding canon-delta file at `data/canon_deltas/<id>.yml`. Measured by an RSpec example that runs the produce path under `MOCK_AI=true` and asserts both file shapes.
- **SC-002**: 100% of `eidos produce <any form>` invocations advance `canon.revision` by exactly 1. Measured by an RSpec example that snapshots the field, runs produce, re-reads the field, asserts `+1`. Repeated for chapter, vignette, and at least one image form.
- **SC-003**: `eidos world status` displays the current canon revision in a form a creator can spot in under 5 seconds of skimming the output. Measured by reading the actual output and confirming the revision line is present and labeled.
- **SC-004**: After this feature lands, `/impl-qa --behavioral` against a freshly-scaffolded world returns **zero Tier-2 failures**. The four T025 failures from feature 016's behavioral run are all flipped to PASS. Measured by re-running `/impl-qa --behavioral` and checking the verdict.
- **SC-005**: `grep -r "ChapterGenerator" eidos/lib/` returns zero matches. `eidos produce help` does not list `write`. Measured by running both checks.
- **SC-006**: `MOCK_AI=true bundle exec rspec` from `eidos/` passes with 0 failures. SimpleCov coverage stays at or above `EIDOS_COVERAGE_FLOOR`. Measured by running the suite.
- **SC-007**: A pre-existing chapter file (with legacy frontmatter, e.g. one of the chapters in `worlds/one-review-man/content/chapters/`) is still readable by `eidos piece show <id>` and `eidos chapter list -w worlds/one-review-man` without raising. Measured by running both commands against the unmigrated `worlds/one-review-man` after the change.

## Assumptions

- The `eidos/lib/eidos/forms/chapter.yml` form definition exists and registers `chapter` as a built-in form (the form *file* is already there; the wire-up to use `PieceProducer` for it is the missing piece).
- `PieceProducer` already supports the structured-flow contract chapters need (title/summary/new-characters extraction). If it doesn't, this feature extends `PieceProducer` (or its single successor) to support form-specific structured outputs, with chapter being the first user. *No new producer class — extend the unified one.*
- The chapter form's auto-numbering ("next number after the highest existing `NNN-chapter.md`") is preserved as the chapter form's `chapter_number` strategy. The `id` field for chapter is a hash like every other form. The filename on disk is derived from `chapter_number`, not from `id`.
- The existing canon-delta schema applies to chapter unchanged. The chapter's `new_characters`, `new_locations`, etc. fields map to the same delta sections every other form uses.
- Worlds created before 018a may not have `canon.revision` in their `world_state.yml`. The producer's first action on such a world is the in-place migration described in FR-006: compute the value as `count(data/canon_deltas/*.yml)`, write it, log one line, proceed. This migration code is intentionally **temporary** — once feature 018c migrates `worlds/one-review-man` (the only long-running legacy world this project carries), the migration path becomes dead code and is removed per FR-006a. No other long-running legacy worlds exist; future worlds are scaffolded post-018a and ship with the field from day one.
- `worlds/one-review-man` will not be migrated by this feature. Its chapter files keep their legacy frontmatter shape. `eidos piece show` and `eidos chapter list` continue to work via existing default-synthesis in `Piece#from_file`. Migration is feature 018c.
- The `eidos chapter list/show` SDK-shadow CLI commands and the `eidos character` family remain in place for this feature; they are 018b's scope.
- Feature 018a's branch is based on `main` (which now has both 016 and 017 merged). It does not depend on 018b or 018c, but 018c will depend on 018a + 018b being merged first.
