---
description: "Task list for feature 012-fix-ux-unify-bible"
---

# Tasks: Fix UX Bugs and Unify Story Bible

**Input**: Design documents from `/specs/012-fix-ux-unify-bible/`
**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/](./contracts/), [quickstart.md](./quickstart.md)

**Tests**: Tests are **REQUIRED** per Constitution Principle I (Test-First with Mock AI). Every behavioral change lands with an RSpec example that passes under `MOCK_AI=true`.

**Organization**: Tasks are grouped by user story (US1, US2, US3) so each story can be delivered as an independent increment.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies on incomplete tasks)
- **[Story]**: Which user story this task belongs to (US1, US2, US3)
- File paths are absolute from repo root

## Path Conventions

Ruby gem living in `eidos/`. Library code under `eidos/lib/eidos/`, specs under `eidos/spec/eidos/`. The one real storyworld is at `worlds/one-review-man/`.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Confirm the baseline is green before touching anything.

- [X] T001 Run `cd eidos && MOCK_AI=true bundle exec rspec` and confirm baseline (~544 examples) is green. Record the count in the PR description. **Baseline: 586 examples, 0 failures.**
- [X] T002 [P] Add an integration-spec scaffold file at `eidos/spec/eidos/integration/first_run_spec.rb` with a `pending` example that names SC-001's forbidden substrings. Fills in later; ensures the file path is reserved.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Shared test fixtures needed by multiple user stories.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [X] T003 [P] Add a `seed_extractor_default` entry to `eidos/spec/support/mock_responses.yml` that returns a small, deterministic JSON payload (≤3 characters, ≤2 locations, ≤3 facts). Used by US3 specs AND the first-run integration spec.
- [X] T004 [P] Add a `chapter_with_title` entry to `eidos/spec/support/mock_responses.yml` whose structured response includes a `title` field (a short substantive string). Used by US1 title-fix specs.

**Checkpoint**: Mock fixtures available; user-story phases can start in parallel.

---

## Phase 3: User Story 1 - Polished first-run output (Priority: P1) 🎯 MVP

**Goal**: A fresh `eidos world new` → `eidos produce chapter` run produces clean, trustworthy output — no "Migrated" message on fresh world, no `CHARACTER_NAME`/`CHARACTER_DESCRIPTION` literal tokens, no "Difficulty: Not specified", no duplicate language prompt, substantive chapter title, interactive defaults that match their option lists, and CLI overrides (`--content-model`, `reset chapters`) that actually work.

**Independent Test**: Run `MOCK_AI=true eidos/bin/world new --world-dir /tmp/w1 --quick` followed by `MOCK_AI=true eidos/bin/produce chapter --world-dir /tmp/w1`. Combined stdout must contain zero occurrences of `"Migrated"`, `"CHARACTER_NAME"`, `"CHARACTER_DESCRIPTION"`, and `"Not specified"`. The generated chapter's title is a substantive phrase, not the literal `"Chapter 1"`.

### Tests for User Story 1 (write first; must FAIL before implementation) ⚠️

- [X] T005 [P] [US1] Write RSpec example in `eidos/spec/eidos/chapter_generator_spec.rb` asserting that `ChapterGenerator#new` does NOT call `migrate_world_data_to_story_facts` and does NOT emit any "Migrated" string to stdout on a fresh tmp world.
- [X] T006 [P] [US1] Create `eidos/spec/eidos/prompt_utils_spec.rb` (if missing) with an example: given a template containing a character-section placeholder and an empty characters list, the rendered prompt contains no `"CHARACTER_NAME"` or `"CHARACTER_DESCRIPTION"` substrings, and no `ArgumentError` / placeholder-warning is emitted.
- [X] T007 [P] [US1] Add RSpec example in `eidos/spec/eidos/chapter_generator_spec.rb`: when the LLM returns a `title` field, the generated chapter uses it; when it doesn't, the chapter falls back to `"Chapter #{N}"`.
- [X] T008 [P] [US1] Add RSpec example in `eidos/spec/eidos/chapter_generator_spec.rb` asserting that chapter metadata output contains no `"Not specified"` line (e.g., `"Difficulty:"` with no value is omitted entirely).
- [X] T009 [P] [US1] Create `eidos/spec/eidos/cli/world_spec.rb` (if missing) with an example: every interactive default offered during `world new` appears in that prompt's option list (or the prompt accepts free-form input).
- [X] T010 [P] [US1] Add RSpec example in `eidos/spec/eidos/cli/world_spec.rb`: interactive `world new` asks for a language at most once per run (drive via `StringIO` stdin fixture).
- [X] T011 [P] [US1] Add regression RSpec example in `eidos/spec/eidos/producers/chapter_producer_spec.rb`: passing `--content-model=test-model` routes the override to the `content.model` slot of `data/settings.yml`, not `llm.model`.
- [X] T012 [P] [US1] Add regression RSpec example in `eidos/spec/eidos/reset_spec.rb` (create if missing): `Reset#reset_chapters(force: true)` deletes `*.md` files under `content/chapters/`, not `_chapters/`.

### Implementation for User Story 1

- [X] T013 [US1] In `eidos/lib/eidos/chapter_generator.rb`, remove the call to `migrate_world_data_to_story_facts` in `#initialize` (around line 60) and delete the private method body at line ~728 (keep method stub if any external caller exists; otherwise delete outright). Verifies T005.
- [X] T014 [US1] In `eidos/lib/eidos/prompt_utils.rb`, change placeholder handling so when the characters list is empty, the entire character section of the template is omitted and no warning is emitted for `CHARACTER_NAME` / `CHARACTER_DESCRIPTION`. Keep warnings for unrelated unresolved placeholders. Verifies T006.
- [X] T015 [US1] In `eidos/lib/eidos/chapter_generator.rb`, update the generation prompt to request a `title` field in the structured response. Parse `title` from the LLM response; set it on the chapter. Fall back to `"Chapter #{N}"` if `title` is missing or blank. Verifies T007.
- [X] T016 [US1] In `eidos/lib/eidos/chapter_generator.rb` (around line 280), filter the metadata that gets rendered into the chapter body so fields whose value is `nil`, empty string, or `"Not specified"` are omitted from the output. Verifies T008.
- [X] T017 [US1] In `eidos/lib/eidos/cli/world.rb` (around lines 203 and 206), change the hardcoded defaults for `genre` and `style` prompts so each default appears in its displayed options list; or, for truly free-form prompts, remove the options list. Verifies T009.
- [X] T018 [US1] In `eidos/lib/eidos/cli/world.rb` (around lines 161–162), remove the duplicate language prompt. Keep exactly one language question per `world new` run. Verifies T010.
- [X] T019 [US1] (Spec-only verification) Confirm `eidos/lib/eidos/producers/chapter_producer.rb` at line ~68 writes to `content.model`. Already fixed on `main`; this task is the regression spec (T011 already written). If T011 fails, diagnose and re-fix; otherwise no code change here.
- [X] T020 [US1] (Spec-only verification) Confirm `eidos/lib/eidos/reset.rb` globs `content/chapters/*.md` (already fixed). If T012 fails, diagnose and re-fix; otherwise no code change.

**Checkpoint**: Run `MOCK_AI=true bundle exec rspec` — baseline + T005..T012 new examples all green. Manually run steps 2–6 from `quickstart.md`; all must pass. US1 is independently shippable here.

---

## Phase 4: User Story 2 - One canonical lore store (Priority: P2)

**Goal**: Eliminate the dual lore store. `ChapterGenerator` (and every other Eidos runtime code path) reads/writes lore through `Eidos::StoryBible` only. All references to `data/world.yml` and `data/story_facts.yml` are removed from runtime code. The one existing dual-state world (`worlds/one-review-man/`) is cleaned up manually as part of this PR.

**Independent Test**: Add a character via the SDK (`world.bible.add_character(...)`) on a tmp world, then run `MOCK_AI=true eidos/bin/produce chapter --world-dir /tmp/w`. The newly added character's name must appear in at least one debug artifact under `tmp/ai_debug/`. Separately: `grep -r 'world\.yml\|story_facts\.yml' eidos/lib/` returns zero runtime hits (exporter + standalone `story_bible_migrator.rb` are documented exceptions).

### Tests for User Story 2 (write first; must FAIL before implementation) ⚠️

- [X] T021 [P] [US2] Add RSpec example in `eidos/spec/eidos/chapter_generator_spec.rb`: given a `StoryBible` populated with one character `"Jax Patel"` via the storage backend, and no `data/world.yml` file present, `ChapterGenerator#generate` builds a prompt that includes `"Jax Patel"`. Drive via the existing `:memory` storage backend.
- [X] T022 [P] [US2] Add integration test in `eidos/spec/eidos/integration/first_run_spec.rb`: spawn `ruby eidos/bin/world new --quick` on a tmp dir, add a character via the SDK, run `ruby eidos/bin/produce chapter`, then grep `tmp/ai_debug/last_prompt.txt` for the character's name. Asserts FR-011 end-to-end.
- [X] T023 [P] [US2] Add RSpec example in `eidos/spec/cli_spec.rb`: a fresh `world new --quick` tmp dir contains `data/story_bible/` but does NOT contain `data/world.yml` or `data/story_facts.yml`.
- [X] T024 [P] [US2] Add RSpec example in `eidos/spec/eidos/integration/first_run_spec.rb`: when stray `data/world.yml` and `data/story_facts.yml` files exist in a tmp world, running any Eidos command (e.g., `produce chapter`) does NOT read them, does NOT emit a "Migrated" log, and does NOT write updates back to them.

### Implementation for User Story 2

- [X] T025 [US2] In `eidos/lib/eidos/chapter_generator.rb`, replace the legacy loaders (around lines 488, 515, 638, 729–858, 1207) with reads from the injected `StoryBible`. Delete the `migrate_world_data_to_story_facts` private method outright. Character / location / fact assembly for the prompt goes through `StoryBible#characters`, `#locations`, `#facts`. Verifies T021, T022, T024.
- [X] T026 [US2] In `eidos/lib/eidos/cli/world.rb` at line 307, remove the `write_yaml_file(File.join(target, 'data', 'world.yml'), world_data)` call. A fresh world no longer creates `data/world.yml`. Verifies T023.
- [X] T027 [US2] [P] In `eidos/lib/eidos/cli/helpers.rb` at line 191, remove `'data/world.yml' => 'World data'` from the data-files status listing. Replace with `'data/story_bible/'` if the listing shows directories.
- [X] T028 [US2] [P] In `eidos/lib/eidos/utils.rb` at line 90, remove the legacy `world.yml` loader. Any remaining callers are rewritten to go through `StoryBible` via the world's `Eidos::World#bible` façade.
- [X] T029 [US2] [P] Audit every remaining reference to `data/world.yml` and `data/story_facts.yml` in `eidos/lib/` using `Grep` (excluding `story_bible_exporter.rb` and `story_bible_migrator.rb`). For each hit, either remove or document why it must stay. Target: zero runtime hits.
- [X] T030 [US2] Manual data cleanup: (a) diff `worlds/one-review-man/data/story_bible/` against `data/world.yml` + `data/story_facts.yml` and reconcile any canon-only content into the bible; (b) delete `worlds/one-review-man/data/world.yml` and `worlds/one-review-man/data/story_facts.yml`; (c) run `MOCK_AI=true eidos/bin/produce chapter -w worlds/one-review-man` and confirm output is clean; (d) commit the deletion with a message referencing this spec. Satisfies FR-014a.

**Checkpoint**: Run `MOCK_AI=true bundle exec rspec` — all green. Run `grep -r 'world\.yml\|story_facts\.yml' eidos/lib/` and verify hits only in `story_bible_exporter.rb` and `story_bible_migrator.rb`. US1 + US2 both independently shippable here.

---

## Phase 5: User Story 3 - Premise becomes a Story Bible seed (Priority: P3)

**Goal**: `eidos world new` in interactive mode offers to seed the Story Bible from the user's premise (default Yes). `--quick` skips silently. `--no-seed` forces skip without prompting. Seeded entries carry an `origin: "seed"` marker and are visible in `eidos bible list` with a `(seed)` tag.

**Independent Test**: Run interactive `MOCK_AI=true eidos/bin/world new --world-dir /tmp/w3` accepting the seed prompt. Then `eidos/bin/bible list -w /tmp/w3` shows at least one entry with a `(seed)` marker. Running the same flow with `--no-seed` or `--quick` yields an empty (or near-empty) bible list.

### Tests for User Story 3 (write first; must FAIL before implementation) ⚠️

- [ ] T031 [P] [US3] Create `eidos/spec/eidos/seed_extractor_spec.rb` with examples:
  - Success path: mocked LLM returns well-shaped JSON → `SeedResult` populated, arrays capped (≤3 characters, ≤2 locations, ≤3 facts), no warnings.
  - Malformed JSON: `SeedResult` has empty arrays and one warning; method does NOT raise.
  - Timeout / error: same — non-fatal, warning recorded.
  - Origin: every returned character/location hash has `origin: "seed"` and `origin_note: "derived from premise"`.
- [ ] T032 [P] [US3] Add RSpec examples in `eidos/spec/eidos/cli/world_spec.rb`:
  - Interactive mode shows the seed prompt and defaults to Yes.
  - `--no-seed` suppresses the prompt and does not call `SeedExtractor`.
  - `--quick` suppresses the prompt and does not call `SeedExtractor`.
  - On Yes, `SeedExtractor#extract` is invoked with the captured premise, and returned entities are persisted to `world.bible`.
- [ ] T033 [P] [US3] Add RSpec example in `eidos/spec/eidos/cli/bible_cli_spec.rb` (create if missing): a character with `origin: "seed"` renders with a `(seed)` marker in `bible list` output.

### Implementation for User Story 3

- [ ] T034 [US3] Create `eidos/lib/eidos/seed_extractor.rb` implementing `Eidos::SeedExtractor` per `contracts/sdk-surface.md`:
  - Constructor takes `llm_service:` and `story_bible:` (DI per Principle III).
  - `#extract(premise:)` returns `Eidos::SeedResult` (declared as `Struct.new(:characters, :locations, :facts, :warnings, keyword_init: true)` in the same file).
  - Builds a short prompt asking for ≤3 characters, ≤2 locations, ≤3 facts in strict JSON.
  - Never raises; maps all errors to an empty `SeedResult` + single warning.
  - Caps arrays to the documented sizes regardless of LLM output.
  - Tags every returned entity hash with `origin: "seed"`, `origin_note: "derived from premise"`. Verifies T031.
- [ ] T035 [US3] Add the `--no-seed` option to the `eidos world new` Thor command in `eidos/lib/eidos/cli/world.rb`. After the premise is captured, if not in `--quick` and not in `--no-seed`, prompt with tty-prompt `Yes?("Seed the Story Bible from your premise?")`. On Yes, instantiate `SeedExtractor` via the world's `LLMService` and `StoryBible`, call `#extract`, persist each returned entity through `world.bible.add_character` / `add_location` / `add_fact`. Print a one-line summary ("Seeded N characters, M locations, K facts.") or skip-reason on failure. Verifies T032.
- [ ] T036 [US3] In the bible-list CLI command (`eidos/lib/eidos/cli/bible_cli.rb` or wherever list rendering lives), append `(seed)` to the displayed name when the underlying record has `origin == "seed"`. Verifies T033.

**Checkpoint**: Run `MOCK_AI=true bundle exec rspec` — all green. Manually run quickstart step 7. US1 + US2 + US3 all independently shippable.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final verification against spec's measurable outcomes (SC-001 through SC-006) and constitutional compliance.

- [ ] T037 [P] Flesh out the first-run integration spec (`eidos/spec/eidos/integration/first_run_spec.rb`) to cover the full SC-001 check: spawn `world new --quick` + `produce chapter` via `Open3.capture3` on a tmp dir under `MOCK_AI=true`, assert combined stdout contains zero occurrences of `"Migrated"`, `"CHARACTER_NAME"`, `"CHARACTER_DESCRIPTION"`, `"Not specified"`. Replaces the `pending` scaffold from T002.
- [ ] T038 [P] Run each step of `quickstart.md` manually (steps 1–8), record pass/fail in the PR description. If any step fails, file a follow-up task, do not merge.
- [ ] T039 Run `MOCK_AI=true bundle exec rspec` one last time. Expected: 100% green, total count ≥ baseline + new examples.
- [ ] T040 Run `cd eidos && bundle exec rubocop` and fix any style violations introduced.
- [ ] T041 Update repo-level docs (`CLAUDE.md`, `AGENTS.md`, `eidos/README.md`) to note: there is no `data/world.yml` / `data/story_facts.yml` in the canonical world layout; any user-facing command snippets that reference them are corrected.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies. Start immediately.
- **Phase 2 (Foundational)**: Depends on Phase 1. Adds mock fixtures used by multiple stories. BLOCKS all user-story phases.
- **Phase 3 (US1)**: Depends on Phase 2 (needs `chapter_with_title` mock). Independent of US2, US3.
- **Phase 4 (US2)**: Depends on Phase 2. Independent of US1, US3 (US1 can ship before or after US2).
- **Phase 5 (US3)**: Depends on Phase 2 (needs `seed_extractor_default` mock) and Phase 4 (relies on `data/story_bible/` being the sole store). If US3 ships ahead of US2 it will work but will leave the dual-store inconsistency in place — ordering them US2 → US3 is cleanest.
- **Phase 6 (Polish)**: Depends on every story that is in-scope for the release.

### User Story Dependencies

- **US1 (P1)**: Independent. Ship as MVP.
- **US2 (P2)**: Independent of US1 (no US1 task is blocked by US2). Recommended to ship after US1 to maximize first-run polish first.
- **US3 (P3)**: Depends logically on US2 (seed entries land in `data/story_bible/`, which US2 makes canonical). Not scheduled before US2.

### Within Each User Story

- Tests are written FIRST and must FAIL before implementation lands (Constitution I).
- Parallel opportunities are marked `[P]`. Non-parallel tasks within a story operate on the same file (e.g., `chapter_generator.rb`) and must be serialized.

### Parallel Opportunities

- T002, T003, T004 can run in parallel (different files).
- Within US1: T005–T012 can all run in parallel (different spec files or additive to existing specs). T013–T018 mostly operate on the same two files (`chapter_generator.rb`, `cli/world.rb`) and must serialize within each file; cross-file pairs can go in parallel.
- Within US2: T025, T026, T027, T028, T029 touch five distinct files and can mostly run in parallel once their tests (T021–T024) are authored.
- Within US3: T034, T035, T036 touch distinct files and can run in parallel once T031–T033 are authored.

---

## Parallel Example: User Story 1

```bash
# Launch all US1 test-writing tasks in parallel (each touches a different file or
# adds a new file under spec/):
Task: "Write spec in eidos/spec/eidos/chapter_generator_spec.rb for no-Migrated (T005)"
Task: "Write spec in eidos/spec/eidos/prompt_utils_spec.rb for empty-characters (T006)"
Task: "Write spec in eidos/spec/eidos/chapter_generator_spec.rb for title (T007)"
Task: "Write spec in eidos/spec/eidos/cli/world_spec.rb for defaults-in-options (T009)"
Task: "Write spec in eidos/spec/eidos/producers/chapter_producer_spec.rb for --content-model (T011)"
Task: "Write spec in eidos/spec/eidos/reset_spec.rb for reset chapters path (T012)"
```

---

## Implementation Strategy

### MVP First (US1 only)

1. Phase 1 (Setup) + Phase 2 (Foundational) — shared fixtures ready.
2. Phase 3 (US1) — write failing specs T005–T012, then implement T013–T020.
3. **STOP and VALIDATE**: Run suite + quickstart steps 2–6 on a throwaway tmp dir.
4. Ship US1. First-run UX is already dramatically improved; users notice immediately.

### Incremental Delivery

1. Ship US1 (above) → clean first-run output.
2. Add US2 → ChapterGenerator routes through StoryBible; manually clean up `worlds/one-review-man/` legacy files.
3. Add US3 → seed extractor + wizard prompt; `bible list (seed)` marker.
4. Polish (Phase 6) → run SC-001 checks, quickstart, rubocop, doc updates.

### Parallel Team Strategy

With multiple developers after Phase 2 completes:

- Developer A: US1 (cli/world.rb + prompt_utils + chapter metadata).
- Developer B: US2 (chapter_generator.rb routing through StoryBible + legacy file removals).
- Developer C: US3 (new SeedExtractor class + wizard integration; waits for US2 checkpoint before merging).

US1 and US2 can land independently. US3 merges after US2.

---

## Notes

- `[P]` tasks = different files, no dependencies.
- `[Story]` label maps task to spec.md user story for traceability.
- Every behavioral change carries a failing RSpec example FIRST (Constitution Principle I).
- Commit after each task or tight logical group. Keep commits small.
- Stop at any checkpoint to validate the story in isolation before moving on.
- Avoid: vague tasks, same-file conflicts marked `[P]`, cross-story dependencies that break independence.
- The one-shot data cleanup in T030 is real work (not a code change) and must be verified by a post-cleanup `produce chapter` run, not just by file deletion.
