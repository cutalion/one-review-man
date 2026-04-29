---

description: "Task list for feature 018a: unify the chapter producer + add a global canon revision counter"
---

# Tasks: Unify the chapter producer + add a global canon revision counter

**Input**: Design documents from `/specs/018-unify-piece-producer/`
**Prerequisites**: spec.md, plan.md, research.md, data-model.md, contracts/{chapter-piece-parity,canon-revision-atomicity,world-state-migration}.md, quickstart.md

**Tests**: REQUIRED. Constitution Principle I (Test-First with Mock AI) mandates failing specs land before each user story's implementation. Per the plan, three new spec files are introduced (one per user story); each MUST fail on `main` before its implementation tasks begin.

**Organization**: Tasks are grouped by the three user stories from `spec.md`. **The phases have a real dependency**: US2 (canon revision counter) is foundational for US1 (chapter parity) — `PieceProducer`'s chapter extension reads the revision from `WorldState`. US1 is foundational for US3 (legacy deletion) — `ChapterGenerator` cannot be retired until chapter goes through `PieceProducer`. The phase order (US2 → US1 → US3) reflects this; both US1 and US2 are P1 by spec priority.

## Format: `[ID] [P?] [Story?] Description`

- **[P]**: Different files, no dependencies on incomplete tasks — runnable in parallel
- **[Story]**: Maps a task to a user story (US1, US2, US3). Setup / Foundational / Polish tasks carry no Story label.
- File paths are absolute under `/home/cutalion/code/one-review-man/`.

---

## Phase 1: Setup

- [X] T001 Confirm working tree is clean and on branch `018-unify-piece-producer`. From `/home/cutalion/code/one-review-man/`, run `git status --short`; expected output is only the new `specs/018-unify-piece-producer/` files plus untracked `tmp/` and `worlds/one-review-man/tmp/`. No staged or modified files outside this feature dir.
- [X] T002 Confirm baseline RSpec is green on `main` before any 018a edits. From `/home/cutalion/code/one-review-man/eidos/`, run `MOCK_AI=true bundle exec rspec 2>&1 | tail -3`. Expected: 775 examples, 0 failures (post-017 baseline). Capture the count for the PR-description delta calculation later (T031).

---

## Phase 2: Foundational

No foundational task. The feature's foundational work IS US2 (the canon revision counter). Per the priority + dependency analysis in the spec, US2 lands first; US1 builds on its `WorldState`; US3 cleans up after US1.

---

## Phase 3: User Story 2 — The canon revision counter (Priority: P1)

**Goal**: A fresh world has `canon: { revision: 0 }` in `data/world_state.yml`. `eidos world status` shows the current revision. Every successful canon-delta apply (produce, revert, rollback) advances it by exactly 1, atomically with the bible mutation. Existing worlds (without the field) get an in-place migration on first read, with the migration code flagged temporary per FR-006a.

**Independent Test**: scaffold a fresh world; produce any piece (e.g. a vignette under `MOCK_AI=true`) — bypass chapter, which still uses the legacy path until US1; assert the revision counter advances from 0 to 1 in `world_state.yml`; assert `world status` reports the same; assert the vignette's frontmatter `canon_version` field is the integer `1`.

> **Sequencing constraint**: T003–T004 (failing specs) MUST land before T005–T010 (implementation). Within each step group, parallelism is noted with [P].

- [X] T003 [P] [US2] Create failing spec `/home/cutalion/code/one-review-man/eidos/spec/eidos/world_state_spec.rb` per `contracts/world-state-migration.md`. The spec MUST contain at minimum the eight examples sketched in the contract (already-present read; migrate-and-return; empty-deltas-dir returns 0; corrupt-world raises when `canon_deltas/` absent; corrupt-world raises when `world_state.yml` absent; non-integer raises; negative raises; advance increments; atomic on partial-write failure). Use `Dir.mktmpdir` for temp worlds and `MOCK_AI=true` in setup.
- [X] T004 [P] [US2] Create failing spec `/home/cutalion/code/one-review-man/eidos/spec/eidos/canon_delta_atomicity_spec.rb` per `contracts/canon-revision-atomicity.md`. The spec MUST contain at minimum the five examples sketched in the contract (advance-by-1 on success; revision-unchanged on apply!-raise; revision-unchanged on advance!-raise with bible rolled back; advance on canon revert; advance on canon rollback). Use `Dir.mktmpdir` and stub `WorldState` where appropriate.
- [X] T005 [US2] Verify the two new specs FAIL on the current code state. From `eidos/`, run `MOCK_AI=true bundle exec rspec spec/eidos/world_state_spec.rb spec/eidos/canon_delta_atomicity_spec.rb`. Both MUST fail (the classes don't exist or don't have the new behavior). If any example passes pre-implementation, strengthen the test before continuing.
- [X] T006 [US2] Implement `/home/cutalion/code/one-review-man/eidos/lib/eidos/world_state.rb` per `data-model.md` and `contracts/world-state-migration.md`. Class `Eidos::WorldState` with public methods `current_revision` (with FR-006 in-place migration; raises `CorruptWorldError` when `data/canon_deltas/` is absent or `world_state.yml` is absent or `canon.revision` is non-integer or negative) and `advance_revision!` (atomic write — write to `world_state.yml.tmp` then `File.rename`; returns the new integer). Use the existing `say`-style output helper if invoked from a CLI context, else `warn` to stderr. Add a `# frozen_string_literal: true` header. Add a class-level docstring noting "FR-006a: this class's migration branch is temporary scaffolding scheduled for retirement in/after feature 018c."
- [X] T007 [US2] Modify `/home/cutalion/code/one-review-man/eidos/lib/eidos/canon_delta.rb` per `contracts/canon-revision-atomicity.md`. Add a `world_state:` kwarg to `apply!` (default `Eidos::WorldState.new(world_path: world_path)`). Inside the existing `begin/rescue StandardError => e` block at approximately lines 219–241, after all the `@new_*.each` and `@entity_updates.each` mutating loops succeed and BEFORE the existing `@applied_at = Time.now.utc` stamp at line 243, call `world_state.advance_revision!` and store the result in an instance variable like `@canon_version_after_resolved` for the audit-log writes that follow to use. If `advance_revision!` raises, the existing `rescue` clause runs `rollback!(bible, applied_actions)` and re-raises (no new error path needed).
- [X] T007a [US2] Update `Eidos::Producers::PieceProducer#current_canon_version` (in `/home/cutalion/code/one-review-man/eidos/lib/eidos/producers/piece_producer.rb`, the method around line 217) to read `Eidos::WorldState.new(world_path: @world_path).current_revision` (returning an integer) when no `--snapshot` is pinned. When `--snapshot <name>` is passed, continue returning the snapshot label string (existing behavior). The literal string `'unversioned'` MUST NOT be returned for new pieces — if `WorldState` raises `CorruptWorldError`, propagate it (the producer fails loudly rather than writing a degraded value). This task discharges FR-010 for ALL forms (universal); without it, T011's smoke test (vignette → `canon_version: 1`) cannot pass. Add an example to the existing `canon_delta_atomicity_spec.rb` (T004) asserting that after a successful PieceProducer produce, the piece file's frontmatter `canon_version` is an integer matching the world's current revision.
- [X] T008 [US2] Verify the two specs from T003+T004 now PASS. From `eidos/`, run `MOCK_AI=true bundle exec rspec spec/eidos/world_state_spec.rb spec/eidos/canon_delta_atomicity_spec.rb`. Expected: 0 failures.
- [X] T009 [P] [US2] Update `/home/cutalion/code/one-review-man/eidos/lib/eidos/cli/world.rb` scaffold to write `canon: { revision: 0 }` into `data/world_state.yml` for newly-created worlds. The writer is around line 392 (`write_yaml_file(File.join(target, 'data', 'world_state.yml'), state_data)`). Add a `'canon' => { 'revision' => 0 }` entry to `state_data` hash. Update the existing `world_new_*_spec.rb` files (whichever asserts on scaffold output) to expect the new field; if no spec asserts on `world_state.yml` content today, add a new line asserting it.
- [X] T010 [P] [US2] Update `/home/cutalion/code/one-review-man/eidos/lib/eidos/cli/helpers.rb` `render_status_report` (line 71) to emit a "Canon revision: N" line by reading from `Eidos::WorldState.new(world_path: abs_root).current_revision`. Add the line between `show_basic_info(config)` and `enumerate_pieces_by_form(abs_root)` so it appears prominently near the top of `world status` output. If a corresponding spec exists at `spec/eidos/cli/world_status_*` (or similar), update it to assert the new line; if not, add a small spec file for `world status` output assertions.
- [X] T011 [US2] Manual smoke test for US2 in isolation. From `/home/cutalion/code/one-review-man/`: scaffold a temp world (`eidos/exe/eidos world new --quick -w tmp/us2-smoke --title "US2 Test" --author "T" --premise "Test." --languages en`); confirm `tmp/us2-smoke/data/world_state.yml` contains `canon:` with `revision: 0`; run `eidos/exe/eidos world status -w tmp/us2-smoke` and confirm output includes a `Canon revision: 0` line; produce a vignette via the existing (still-unmodified) `PieceProducer` path under `MOCK_AI=true`; confirm the revision advanced to 1 in the YAML; confirm the vignette's frontmatter contains `canon_version: 1` (integer, not the string `unversioned`). Clean up: `rm -rf tmp/us2-smoke`.

**Checkpoint**: User Story 2 functional and tested. The revision counter exists end-to-end. Chapter still uses the legacy `ChapterGenerator` path and writes legacy frontmatter — that's US1's job.

---

## Phase 4: User Story 1 — Chapter under the unified piece-producer contract (Priority: P1)

**Goal**: `eidos produce chapter [N]` and `eidos produce piece --form chapter` are functionally equivalent, both routing through `PieceProducer`. Chapter files get the universal frontmatter shape (id hash, form, generated_date, canon_delta_ref, canon_version) plus chapter-specific fields (title, summary, chapter_number); the on-disk filename is still `NNN-chapter.md` derived from `chapter_number`. A canon-delta file is written for every chapter produce.

**Independent Test**: scaffold a fresh world; produce a chapter via `eidos produce chapter --auto` under `MOCK_AI=true`; assert the chapter file has all five universal frontmatter keys; assert `id` is a hash (not the chapter number); assert `chapter_number: 1`; assert `canon_version: 1`; assert the file is at `content/chapters/001-chapter.md`; assert `data/canon_deltas/<id>.yml` exists with `piece_id` matching frontmatter `id`.

> **Sequencing constraint**: T012 (failing spec) MUST land before T014–T018 (implementation). T012 + T013 are [P] (different files).

- [X] T012 [P] [US1] Create failing spec `/home/cutalion/code/one-review-man/eidos/spec/eidos/producers/piece_producer_chapter_spec.rb` per `contracts/chapter-piece-parity.md`. The spec MUST contain at minimum the seven examples sketched in the contract (universal frontmatter keys; chapter-specific keys; filename derivation; canon-delta link; integer canon_version; snapshot-label canon_version under --snapshot; parity with vignette). Use `Dir.mktmpdir` and `MOCK_AI=true`. Additionally include a "malformed-JSON failure mode" example per `contracts/chapter-piece-parity.md` §"Failure modes": stub `MockLLMService` to return non-JSON when chapter produce runs; assert the produce raises (or exits non-zero) with NO piece file written, NO canon-delta file written, NO revision advance, and exactly one `parse-drop` `AuditFinding` opened with the raw response in its evidence field.
- [X] T013 [P] [US1] Verify the new spec FAILS pre-implementation. From `eidos/`: `MOCK_AI=true bundle exec rspec spec/eidos/producers/piece_producer_chapter_spec.rb`. ALL examples MUST fail (no chapter goes through `PieceProducer` yet). Strengthen the spec if any pass.
- [X] T014 [P] [US1] Add `structured_output: true` to `/home/cutalion/code/one-review-man/eidos/lib/eidos/forms/chapter.yml`. Add the corresponding field to the `Form` class at `/home/cutalion/code/one-review-man/eidos/lib/eidos/form.rb` — accept `structured_output` as an optional boolean attribute (default `false`); expose via `Form#structured_output?` predicate method.
- [X] T015 [US1] Extend `/home/cutalion/code/one-review-man/eidos/lib/eidos/producers/piece_producer.rb` with structured-output dispatch and chapter filename derivation. In `#produce`, after the LLM returns the body, branch on `form_obj.structured_output?`: if true, parse the response as a JSON envelope `{title, summary, new_characters, body}` and thread those fields into the piece's frontmatter and into the canon-delta's `new_characters` section; if false, treat as a single-blob body (existing behavior). Rename the existing `next_chapter_id` method to `next_chapter_number` (it now produces the chapter number, not the id). Update `target_path` (the method that resolves the on-disk path for a piece) so the chapter form returns `content/chapters/<NNN>-chapter.md` derived from `chapter_number`, while every other form keeps `content/pieces/<form>/<id>.md`. **Note**: `current_canon_version` is updated by T007a in US2 — leave that method alone here.
- [X] T016 [US1] Rewrite `/home/cutalion/code/one-review-man/eidos/lib/eidos/cli/produce.rb` `chapter [NUMBER]` Thor action (currently around line 362, instantiating `Eidos::ChapterGenerator`). Replace with thin shortcut over `PieceProducer.new(world_path:, llm_service:, form_registry:, bible:, canon:).produce(form: 'chapter', prompt: <user prompt or empty>, length: nil, dry_run: options[:dry_run])`, with the chapter number injected via the `next_chapter_number` method (or via the explicit `[NUMBER]` arg if provided). Preserve the existing `--auto`, `--snapshot`, `--output`, `--prompt`, `--debug`, `--content-model` flag surface — these are user-facing and the contract preserves them. Do NOT delete `eidos/lib/eidos/chapter_generator.rb` or `eidos/lib/eidos/producers/chapter_producer.rb` yet — that's T020/T021 in US3.
- [X] T017 [US1] Verify the spec from T012 now PASSES. From `eidos/`: `MOCK_AI=true bundle exec rspec spec/eidos/producers/piece_producer_chapter_spec.rb`. Expected: all examples pass.
- [X] T018 [US1] Manual smoke test for US1. From `/home/cutalion/code/one-review-man/`: scaffold a temp world; run `MOCK_AI=true eidos/exe/eidos produce chapter -w tmp/us1-smoke --auto`; inspect `tmp/us1-smoke/content/chapters/001-chapter.md` frontmatter — confirm `id` is a hash, `form: chapter`, `chapter_number: 1`, `canon_version: 2` (because US2's smoke test scaffolded above might have advanced; OR `canon_version: 1` if you scaffold a fresh world for this test); confirm `data/canon_deltas/<id>.yml` exists with `piece_id` matching frontmatter `id`. Clean up.

**Checkpoint**: User Story 1 functional and tested. Chapter goes through `PieceProducer`. The legacy classes still exist but have no callers from the user-visible CLI surface — that's US3's job to retire them.

---

## Phase 5: User Story 3 — Retire the legacy chapter producers (Priority: P2)

**Goal**: `Eidos::ChapterGenerator` is gone. `Eidos::Producers::ChapterProducer` is gone. `eidos produce write` is gone. The `Producer.register(:chapter, ChapterProducer)` registration is gone. Chapter-related specs that exercised the legacy classes are deleted; integration specs that exercise the chapter path are migrated to drive `PieceProducer`. Full RSpec stays green; `grep -r "ChapterGenerator" eidos/lib/` returns zero matches.

**Independent Test**: `grep -r "ChapterGenerator" eidos/lib/` returns exit 1 (no matches). `eidos produce help` does not list `write`. `MOCK_AI=true bundle exec rspec` passes with 0 failures.

- [X] T019 [P] [US3] Delete `/home/cutalion/code/one-review-man/eidos/lib/eidos/chapter_generator.rb` (the entire file).
- [X] T020 [P] [US3] Delete `/home/cutalion/code/one-review-man/eidos/lib/eidos/producers/chapter_producer.rb` (the entire file). This includes the `Producer.register(:chapter, Eidos::Producers::ChapterProducer)` registration line at the bottom of that file. If `Eidos::Producer.register` is consulted by any other call site, audit those — `grep -rn "Producer.register\|Producer.lookup\|Producer.find" eidos/lib/` — and update to instantiate `PieceProducer` directly if needed.
- [X] T021 [US3] Delete the `def write(chapter = nil)` Thor method and its `desc 'write [CHAPTER]', ...'` + `option :requirements/:dry_run/:force` lines from `/home/cutalion/code/one-review-man/eidos/lib/eidos/cli/produce.rb` (currently lines 369–~400). Audit for any agent-runner support code referenced ONLY by the deleted method (`grep -rn "agent_runner\|AgentRunner\|agent_writer" eidos/lib/`) and delete if orphaned.
- [X] T022 [P] [US3] Delete `/home/cutalion/code/one-review-man/eidos/spec/chapter_generation_spec.rb` (top-level file).
- [X] T023 [P] [US3] Delete `/home/cutalion/code/one-review-man/eidos/spec/eidos/chapter_generator_spec.rb`.
- [X] T024 [P] [US3] Delete `/home/cutalion/code/one-review-man/eidos/spec/eidos/producers/chapter_producer_spec.rb` and `/home/cutalion/code/one-review-man/eidos/spec/eidos/producers/chapter_producer_back_compat_spec.rb`.
- [X] T025 [US3] Migrate `/home/cutalion/code/one-review-man/eidos/spec/integration/chapter_number_regression_spec.rb` to drive `PieceProducer` instead of `ChapterGenerator`. Read the original spec carefully; identify what invariants it asserted (chapter numbering after gaps, after edits, etc.); rewrite each example to use `PieceProducer.new(...).produce(form: 'chapter', ...)` while preserving the SAME invariants. If any invariant cannot be expressed against `PieceProducer` (because the legacy logic was specific to `ChapterGenerator`'s state machine), document it inline in the spec with a comment and either skip or rewrite to test the equivalent post-018a behavior.
- [X] T026 [US3] Migrate `/home/cutalion/code/one-review-man/eidos/spec/integration/produce_chapter_prompt_flag_spec.rb` to drive the post-018a `produce chapter` Thor action (which now routes through `PieceProducer`). Preserve the spec's intent (asserting that `--prompt` flag is correctly threaded into chapter generation).
- [X] T026a [P] [US3] Add `/home/cutalion/code/one-review-man/eidos/spec/eidos/legacy_chapter_readability_spec.rb` to guard FR-012. The spec writes a temp piece file with **legacy** frontmatter (no `id`, no `form`, no `canon_delta_ref`, no `canon_version` — only the pre-018a keys: `layout`, `title`, `chapter_number`, `characters`, `summary`, `word_count`, etc.) at `content/chapters/001-chapter.md` inside a `Dir.mktmpdir` temp world. Asserts that `Eidos::Piece.from_file(path)` reads it without raising and synthesizes sensible defaults for the new keys (per the existing `Piece#from_file` default-synthesis comment block). Also asserts `eidos piece show <id> -w <temp-world>` and `eidos piece list --form chapter -w <temp-world>` both run without raising. ~30 lines. Locks in the legacy-readability invariant so future `PieceProducer` / `Piece` changes don't accidentally break worlds whose chapters predate 018a.
- [X] T027 [US3] Verify SC-005: from `/home/cutalion/code/one-review-man/`, run `grep -rn "ChapterGenerator" eidos/lib/`; expected exit code 1 (no matches). Also `grep -rn "Producers::ChapterProducer\|chapter_producer" eidos/lib/`; expected zero matches outside any harmless comments. Also `eidos/exe/eidos produce help`; expected NOT to list a `write` subcommand.

**Checkpoint**: Legacy chapter code gone; surface clean.

---

## Phase 6: Polish & Cross-Cutting Concerns

- [X] T028 Run full RSpec suite: from `/home/cutalion/code/one-review-man/eidos/`, run `MOCK_AI=true bundle exec rspec 2>&1 | tail -3`. Expected: ~770–780 examples (slight shift due to spec deletions in T022–T024 and additions in T003/T004/T012); 0 failures; SimpleCov coverage at or above the `EIDOS_COVERAGE_FLOOR` (per Constitution Principle I).
- [X] T029 Run `/impl-qa --behavioral` against a fresh world. Expected: PASS verdict; **all four** T025 Tier-2 failures (chapter frontmatter; chapter canon-delta; world_state.yml has canon.revision; world status shows revision) flip to PASS. (SC-004.)
- [X] T030 Manual sanity on `worlds/one-review-man` (SC-007 verification — NOT migrating, just confirming readability). From `/home/cutalion/code/one-review-man/`: run `eidos/exe/eidos chapter list -w worlds/one-review-man 2>&1 | head -5`; expected: legacy chapter files still listed without raising. Run `eidos/exe/eidos world status -w worlds/one-review-man 2>&1 | tail -10`; expected: ONE log line of the form `Migrating .../world_state.yml: adding canon.revision = N` on first invocation (FR-006 in-place migration), then a `Canon revision: N` line where N matches the count of files in `worlds/one-review-man/data/canon_deltas/`. Run `eidos/exe/eidos world status -w worlds/one-review-man` again; expected: NO migration log line (field is now persisted). Reset by deleting any newly-written-but-unintended files: `git diff --stat worlds/one-review-man/`; if `world_state.yml` is the only modified file and the diff is just the `canon: { revision: N }` addition, the migration ran correctly — that change can be committed as part of this feature OR reverted (the in-place migration will re-run on the next 018a invocation).
- [X] T031 [P] Run rubocop on the changed Ruby files: from `/home/cutalion/code/one-review-man/eidos/`, run `bundle exec rubocop lib/eidos/world_state.rb lib/eidos/canon_delta.rb lib/eidos/producers/piece_producer.rb lib/eidos/cli/produce.rb lib/eidos/cli/world.rb lib/eidos/cli/helpers.rb spec/eidos/world_state_spec.rb spec/eidos/canon_delta_atomicity_spec.rb spec/eidos/producers/piece_producer_chapter_spec.rb 2>&1 | tail -10` if rubocop is bundled locally; if not, note that CI rubocop will run on PR.
- [X] T032 [P] Clean up sandbox artifacts: `rm -rf tmp/us2-smoke tmp/us1-smoke tmp/test-018a-world` from `/home/cutalion/code/one-review-man/`. Pre-existing `tmp/` content from earlier features may remain — only this feature's sandboxes are removed here.

**Checkpoint**: Feature ready to merge. PR description should include T028's wall-clock + RSpec count, T029's verdict, and the diff stat showing net LOC delta (expected removal-heavy: −300 to −600 LOC).

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: T001 + T002 are independent and runnable in any order; together they confirm the baseline.
- **Phase 2 (Foundational)**: empty — the project's foundational work for this feature IS US2.
- **Phase 3 (US2)**: depends on Phase 1 complete. T003 + T004 [P] (failing specs, different files) → T005 (verify failing) → T006 + T007 (implementation, partly different files but ordered because T007 imports `Eidos::WorldState` from T006) → **T007a** (`PieceProducer#current_canon_version` reads `WorldState`; required for T011's smoke test to pass) → T008 (verify passing) → T009 + T010 [P] (scaffold + status output, different files) → T011 (manual smoke).
- **Phase 4 (US1)**: depends on Phase 3 complete (T015 reads `Eidos::WorldState`). T012 + T013 [P] → T014 + T015 + T016 (sequential; T015 depends on T014's `structured_output?` predicate; T016 depends on T015's renamed `next_chapter_number`) → T017 (verify passing) → T018 (manual smoke).
- **Phase 5 (US3)**: depends on Phase 4 complete (the legacy classes can only be deleted once chapter goes through `PieceProducer`). T019 + T020 + T022 + T023 + T024 [P] (different files; pure deletions) → T021 (different concern from deletions but same `produce.rb` file edits — sequence after T020) → T025 + T026 (sequential or [P], same `spec/integration/` directory but different files — could be [P]) → T027 (verification grep).
- **Phase 6 (Polish)**: depends on Phase 5 complete. T028 (full suite) → T029 (impl-qa --behavioral, depends on T028 green) → T030 (manual sanity on real world) → T031 + T032 [P] (rubocop + cleanup).

### Within-phase ordering (key constraints)

- T005 MUST come AFTER T003+T004 (failing tests must exist before they can be verified failing).
- T008 MUST come AFTER T006+T007+T007a (implementation must exist before it can pass; T007a is required for the integer-`canon_version` example in `canon_delta_atomicity_spec.rb`).
- T013 MUST come AFTER T012 (verify failing requires the spec to exist).
- T015 MUST come AFTER T014 (`PieceProducer` extension reads the new `Form#structured_output?`).
- T016 MUST come AFTER T015 (the rewritten Thor action calls `PieceProducer` with chapter form, which depends on T015's structured-output dispatch).
- T017 MUST come AFTER T014+T015+T016 (the spec verifies the full chapter-via-PieceProducer pipeline).
- T021 MUST come AFTER T020 (deleting `chapter_producer.rb` first removes the `Producer.register` registration; then `produce write` can be safely deleted from `produce.rb`).
- T028 MUST come AFTER all Phase 3+4+5 implementation tasks (the suite includes the migrated specs).

### Parallel Opportunities

- T001 + T002 (Setup): independent verification commands → [P] possible.
- T003 + T004 (US2 failing specs): different spec files → [P].
- T009 + T010 (US2 scaffold + status output): different source files → [P].
- T012 + T013 (US1 failing spec + verify failing): T013 depends on T012's existence. NOT [P].
- T014 (form schema) is [P] with T015 wait; actually T015 depends on T014's predicate. NOT [P].
- T019 + T020 + T022 + T023 + T024 (US3 deletions): each is a different file → [P].
- T031 + T032 (Polish lint + cleanup): different concerns → [P].

---

## Parallel Example: Phase 3 US2 failing specs

```bash
# Run these two together (different spec files):
Task: "Create failing spec spec/eidos/world_state_spec.rb per contracts/world-state-migration.md"  # T003
Task: "Create failing spec spec/eidos/canon_delta_atomicity_spec.rb per contracts/canon-revision-atomicity.md"  # T004
```

## Parallel Example: Phase 5 US3 deletions

```bash
# Five files, all pure deletions, can run together:
Task: "Delete eidos/lib/eidos/chapter_generator.rb"                          # T019
Task: "Delete eidos/lib/eidos/producers/chapter_producer.rb"                 # T020
Task: "Delete eidos/spec/chapter_generation_spec.rb"                          # T022
Task: "Delete eidos/spec/eidos/chapter_generator_spec.rb"                    # T023
Task: "Delete eidos/spec/eidos/producers/chapter_producer*.rb"               # T024
```

---

## Implementation Strategy

### MVP (User Story 2 + User Story 1 — both are P1)

1. T001 → T002 (setup).
2. Phase 3 US2: T003 → T004 → T005 → T006 → T007 → T008 → T009 → T010 → T011. **Stop and validate**: revision counter works end-to-end against any non-chapter form.
3. Phase 4 US1: T012 → T013 → T014 → T015 → T016 → T017 → T018. **Stop and validate**: chapter unification works.
4. At this point both P1 stories are green; the codebase has the new behavior; the legacy code still exists alongside but is unused. This is a reasonable pause point if you want to merge a P1-only slice.

### Full Feature

5. Phase 5 US3 (legacy retirement): T019 → T020 → T022 → T023 → T024 [P] → T021 → T025 → T026 → T027. **Stop and validate**: legacy code gone, full suite green.
6. Phase 6 Polish: T028 → T029 → T030 → T031 → T032.

### Single-Maintainer Strategy

Whole feature should fit in ~1 working day for an experienced maintainer. Breakdown roughly: 2 hours for failing specs + WorldState + atomicity (Phase 3); 2–3 hours for PieceProducer extension + chapter Thor rewrite (Phase 4); 1 hour for legacy deletion + spec migration (Phase 5); 30 min for verification (Phase 6). The legacy deletion is fast because every deleted spec is an entire file removal; the spec migrations (T025/T026) are the slowest part of US3 because they require careful rewriting.

---

## Notes

- [P] tasks = different files, no dependencies. Most US2 implementation is sequential because `WorldState` (T006) is imported by `CanonDelta#apply!` (T007) and by `PieceProducer` (T015 in US1).
- [Story] label maps a task to a user story; Setup / Foundational / Polish carry no Story label.
- T003/T004/T012 (failing specs) → Tx (verify failing) → Ty (implement) → Tz (verify passing) ordering is non-negotiable per Constitution Principle I.
- Capture wall-clock for T028 (full suite) and T029 (impl-qa --behavioral) in the PR description; together they're the empirical "feature complete" signal.
- Do NOT commit until T028 (full suite) green AND T029 (impl-qa --behavioral) PASS verdict. Per project standing rule, commits happen only on explicit user request.
- The FR-006 in-place migration code added in T006 is **temporary scaffolding**. 018c will retire it. Do NOT add code that depends on its long-term existence.
