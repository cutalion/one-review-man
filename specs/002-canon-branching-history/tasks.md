# Tasks: Canon Branching and Change History

**Input**: Design documents from `/specs/002-canon-branching-history/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: Setup

**Purpose**: Project initialization — new directories and value objects

- [x] T001 Create `book-generator/lib/book_core/models/` directory and add `revision.rb` with Revision value object (fields: sequence, entity_type, entity_id, snapshot, timestamp, change_reason, parent_seq, operation, branch, changeset_id) in `book-generator/lib/book_core/models/revision.rb`
- [x] T002 [P] Create Branch value object (fields: name, display_name, parent_branch, created_at, created_from, status, archived_at, description) in `book-generator/lib/book_core/models/branch.rb`
- [x] T003 [P] Create ImpactReport and AffectedItem value objects (fields per data-model.md) in `book-generator/lib/book_core/models/impact_report.rb`
- [x] T004 [P] Create Changeset and ChangeOperation value objects (fields per data-model.md) in `book-generator/lib/book_core/models/changeset.rb`
- [x] T005 [P] Create Conflict value object (fields: entity_type, entity_id, field_path, base_value, ours_value, theirs_value, resolution, custom_value) in `book-generator/lib/book_core/models/conflict.rb`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that ALL user stories depend on — DiffEngine and RevisionStore

**CRITICAL**: No user story work can begin until this phase is complete.

- [x] T006 Implement `BookCore::DiffEngine` with `diff(snapshot_a, snapshot_b)` method returning field_path => {old:, new:} hash using deep hash comparison, in `book-generator/lib/book_core/diff_engine.rb`
- [x] T007 Extend `BookCore::DiffEngine` with `find_conflicts(base:, ours:, theirs:)` and `three_way_merge(base:, ours:, theirs:)` methods for field-level conflict detection per contracts/library-api.md, in `book-generator/lib/book_core/diff_engine.rb`
- [x] T008 Implement `BookCore::RevisionStore#initialize(revisions_path:)` and `#record(entity_type:, entity_id:, snapshot:, operation:, branch:, change_reason:, changeset_id:)` — writes numbered YAML revision files to `revisions/{entity_type}/{entity_id}/{sequence}.yml`, in `book-generator/lib/book_core/revision_store.rb`
- [x] T009 Implement `BookCore::RevisionStore#history`, `#get`, and `#latest` query methods per contracts/library-api.md, in `book-generator/lib/book_core/revision_store.rb`
- [x] T010 Create RSpec tests for DiffEngine (diff, find_conflicts, three_way_merge with nested hashes) in `book-generator/spec/diff_engine_spec.rb`
- [x] T011 [P] Create RSpec tests for RevisionStore (record, history, get, latest, append-only behavior) in `book-generator/spec/revision_store_spec.rb`

**Checkpoint**: DiffEngine and RevisionStore are independently tested and working. User story implementation can begin.

---

## Phase 3: User Story 1 — Track Change History for Canon Entries (Priority: P1) MVP

**Goal**: Every canon modification records a revision. Creators can view history, diff revisions, and rollback.

**Independent Test**: Create a world, modify a character's backstory three times, view revision history, compare revisions, and rollback to revision #2.

### Implementation for User Story 1

- [x] T012 [US1] Extend `BookCore::StoryBible` to accept `revision_store:` via constructor injection and call `revision_store.record(...)` on every character/location/fact/relationship/plot_thread write operation, in `book-generator/lib/book_core/story_bible.rb`
- [x] T013 [US1] Create `revisions/` directory structure under `books/one-review-man/data/story_bible/` with subdirectories for characters/, locations/, facts/, relationships/ — add to `.gitkeep` or initialization logic in `book-generator/lib/book_core/story_bible.rb`
- [x] T014 [US1] Add `book canon history <entity_type> <entity_id>` CLI subcommand with `--branch`, `--limit`, `--format` options per contracts/cli-commands.md, in `book-generator/lib/book/cli.rb`
- [x] T015 [US1] Add `book canon diff <entity_type> <entity_id> <rev1> <rev2>` CLI subcommand using DiffEngine per contracts/cli-commands.md, in `book-generator/lib/book/cli.rb`
- [x] T016 [US1] Add `book canon rollback <entity_type> <entity_id> <revision>` CLI subcommand — restores snapshot from target revision, records rollback as new revision, in `book-generator/lib/book/cli.rb`
- [x] T017 [US1] Create RSpec tests for StoryBible revision integration (update triggers record, history shows all revisions, rollback creates new revision) in `book-generator/spec/story_bible_revision_spec.rb`
- [x] T018 [US1] Create RSpec tests for canon CLI subcommands (history, diff, rollback) in `book-generator/spec/cli_canon_spec.rb`

**Checkpoint**: User Story 1 is fully functional. Canon changes are tracked, history is viewable, diffs work, rollback works.

---

## Phase 4: User Story 2 — Propagate Canon Changes to Dependent Content (Priority: P2)

**Goal**: Automatic non-blocking impact analysis identifies content affected by canon changes. Creators can view reports and update review status.

**Independent Test**: Create a world with a character referenced in three chapters, change the character's name, verify impact report lists all three chapters with specific line references.

### Implementation for User Story 2

- [x] T019 [US2] Implement `BookCore::ImpactAnalyzer#initialize(content_path:, reference_index_path:, revision_store:)` and `#rebuild_index!` — scans content files for canon entry references, writes `references.yml`, in `book-generator/lib/book_core/impact_analyzer.rb`
- [x] T020 [US2] Implement `BookCore::ImpactAnalyzer#analyze(entity_type:, entity_id:, revision:, branch:)` — looks up dependents in reference index, scans affected files for specific passages, returns ImpactReport with severity levels (high/medium/low), in `book-generator/lib/book_core/impact_analyzer.rb`
- [x] T021 [US2] Implement `BookCore::ImpactAnalyzer#update_review_status(report_id:, item_index:, status:)` — updates individual AffectedItem status (reviewed, needs_update, deferred), in `book-generator/lib/book_core/impact_analyzer.rb`
- [x] T022 [US2] Extend StoryBible canon write operations to automatically trigger `impact_analyzer.analyze(...)` after recording a revision, writing report to `data/story_bible/impact_reports/`, in `book-generator/lib/book_core/story_bible.rb`
- [x] T023 [US2] Add `book canon impact` CLI subcommand with `--latest`, `--report-id`, `--pending-only`, `--format` options per contracts/cli-commands.md, in `book-generator/lib/book/cli.rb`
- [x] T024 [US2] Add `book canon impact review <report_id> <item_index> <status>` CLI subcommand per contracts/cli-commands.md, in `book-generator/lib/book/cli.rb`
- [x] T025 [US2] Create RSpec tests for ImpactAnalyzer (rebuild_index, analyze with known references, severity classification, review status updates) in `book-generator/spec/impact_analyzer_spec.rb`
- [x] T026 [US2] Create RSpec tests for impact CLI subcommands in `book-generator/spec/cli_impact_spec.rb`

**Checkpoint**: User Stories 1 AND 2 work independently. Canon changes are tracked and their impact on content is automatically analyzed.

---

## Phase 5: User Story 3 — Branch a World to Explore Alternate Versions (Priority: P3)

**Goal**: Create nestable branches, switch between them, compare, and merge with field-level conflict detection.

**Independent Test**: Create a world, branch it, modify a character in the branch, compare branches, merge back with auto-merge of non-conflicting changes and manual resolution of conflicts.

### Implementation for User Story 3

- [x] T027 [US3] Implement `BookCore::BranchManager#initialize(story_bible_path:, revision_store:, diff_engine:)` and `#create(name:, from_branch:, at_revision:, description:)` — copies canon data into `branches/{name}/`, writes entry to `branches/_index.yml`, in `book-generator/lib/book_core/branch_manager.rb`
- [x] T028 [US3] Implement `BookCore::BranchManager#list`, `#current_branch`, and `#checkout(name)` — manages active branch context persisted in book state, in `book-generator/lib/book_core/branch_manager.rb`
- [x] T029 [US3] Implement `BookCore::BranchManager#compare(branch_a, branch_b)` — finds common ancestor, computes per-entity diffs using DiffEngine, returns `{only_in_a:, only_in_b:, conflicts:, identical:}`, in `book-generator/lib/book_core/branch_manager.rb`
- [x] T030 [US3] Implement `BookCore::BranchManager#merge(source:, target:, resolutions:)` — performs three-way merge using DiffEngine, auto-merges non-conflicting field changes, returns conflicts for manual resolution, in `book-generator/lib/book_core/branch_manager.rb`
- [x] T031 [US3] Implement `BookCore::BranchManager#archive(name)`, `#unarchive(name)`, and `#delete(name)` with child branch validation, in `book-generator/lib/book_core/branch_manager.rb`
- [x] T032 [US3] Extend `BookCore::StoryBible` to accept `branch_manager:` and route all read/write operations through current branch context, add `#on_branch(name) { ... }` method, in `book-generator/lib/book_core/story_bible.rb`
- [x] T033 [US3] Add `book branch create`, `book branch list`, `book branch checkout` CLI subcommands per contracts/cli-commands.md, in `book-generator/lib/book/cli.rb`
- [x] T034 [US3] Add `book branch compare`, `book branch merge`, `book branch resolve` CLI subcommands per contracts/cli-commands.md, in `book-generator/lib/book/cli.rb`
- [x] T035 [US3] Add `book branch archive` and `book branch delete` CLI subcommands per contracts/cli-commands.md, in `book-generator/lib/book/cli.rb`
- [x] T036 [US3] Create RSpec tests for BranchManager (create, list, checkout, compare, merge with conflicts, archive/delete lifecycle) in `book-generator/spec/branch_manager_spec.rb`
- [x] T037 [US3] Create RSpec tests for branch CLI subcommands in `book-generator/spec/cli_branch_spec.rb`

**Checkpoint**: User Stories 1, 2, AND 3 all work independently. Worlds can be branched, compared, and merged.

---

## Phase 6: User Story 4 — Batch Canon Changes with Consistency Preview (Priority: P4)

**Goal**: Group related canon changes into a changeset, preview aggregate impact, and commit atomically.

**Independent Test**: Create a changeset with three operations (rename location + update two characters), preview combined impact, commit atomically, verify single combined revision entry.

### Implementation for User Story 4

- [x] T038 [US4] Implement `BookCore::ChangesetManager#initialize(changesets_path:, story_bible:, revision_store:, impact_analyzer:)` and `#create(branch:)` — creates a new changeset YAML file with draft status, in `book-generator/lib/book_core/changeset_manager.rb`
- [x] T039 [US4] Implement `BookCore::ChangesetManager#active(branch:)` and `#add_operation(changeset_id:, operation:, entity_type:, entity_id:, changes:, change_reason:)` — appends operation to changeset file, in `book-generator/lib/book_core/changeset_manager.rb`
- [x] T040 [US4] Implement `BookCore::ChangesetManager#preview(changeset_id:)` — applies operations to in-memory copy, runs impact analysis, detects intra-batch conflicts, returns `{report:, conflicts:}`, in `book-generator/lib/book_core/changeset_manager.rb`
- [x] T041 [US4] Implement `BookCore::ChangesetManager#commit(changeset_id:, reason:)` — applies all operations sequentially with rollback-on-failure, records single combined revision entry, and `#discard(changeset_id:)`, in `book-generator/lib/book_core/changeset_manager.rb`
- [x] T042 [US4] Create `data/changesets/` directory under book data path, add to initialization logic in `book-generator/lib/book_core/story_bible.rb`
- [x] T043 [US4] Add `book changeset create`, `book changeset add`, `book changeset preview` CLI subcommands per contracts/cli-commands.md, in `book-generator/lib/book/cli.rb`
- [x] T044 [US4] Add `book changeset commit` and `book changeset discard` CLI subcommands per contracts/cli-commands.md, in `book-generator/lib/book/cli.rb`
- [x] T045 [US4] Create RSpec tests for ChangesetManager (create, add_operation, preview with conflicts, commit atomicity, discard, rollback on failure) in `book-generator/spec/changeset_manager_spec.rb`
- [x] T046 [US4] Create RSpec tests for changeset CLI subcommands in `book-generator/spec/cli_changeset_spec.rb`

**Checkpoint**: All user stories are independently functional. Batch changes can be previewed and committed atomically.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Integration, cleanup, and validation across all user stories

- [x] T047 [P] Add `book canon update <entity_type> <entity_id> [field=value...]` CLI subcommand (general-purpose canon update that works with revision tracking), in `book-generator/lib/book/cli.rb`
- [x] T048 [P] Ensure all new classes include `# frozen_string_literal: true` magic comment, pass RuboCop (`bundle exec rubocop`), in all new files under `book-generator/lib/book_core/`
- [x] T049 Run full test suite `MOCK_AI=true bundle exec rspec` and fix any failures across all specs
- [x] T050 Run quickstart.md scenarios end-to-end against `books/one-review-man/` to validate full workflow

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 (value objects) — BLOCKS all user stories
- **US1 (Phase 3)**: Depends on Phase 2 (RevisionStore, DiffEngine)
- **US2 (Phase 4)**: Depends on Phase 2. Can run in parallel with US1 but benefits from US1's StoryBible revision integration (T012)
- **US3 (Phase 5)**: Depends on Phase 2 (DiffEngine for merge). Can run in parallel with US1/US2 but benefits from US1's revision integration
- **US4 (Phase 6)**: Depends on Phase 2 (RevisionStore). Benefits from US2's ImpactAnalyzer for preview
- **Polish (Phase 7)**: Depends on all user stories being complete

### Recommended Execution Order

Sequential (single developer): Phase 1 → Phase 2 → US1 → US2 → US3 → US4 → Polish

### Within Each User Story

- Models/value objects from Phase 1 are already available
- Core service implementation before CLI wrappers
- Tests alongside or after implementation
- Story complete before moving to next priority

### Parallel Opportunities

- All Phase 1 tasks (T001-T005) marked [P] can run in parallel
- T010 and T011 (foundational specs) can run in parallel
- T047 and T048 (polish) can run in parallel
- Within US2: T019 and T021 are independent methods on the same class
- Within US3: T033, T034, T035 (CLI tasks) can run after T027-T032

---

## Parallel Example: Phase 1 (Setup)

```bash
# Launch all value object tasks together:
Task: "T002 Create Branch value object in book-generator/lib/book_core/models/branch.rb"
Task: "T003 Create ImpactReport value object in book-generator/lib/book_core/models/impact_report.rb"
Task: "T004 Create Changeset value object in book-generator/lib/book_core/models/changeset.rb"
Task: "T005 Create Conflict value object in book-generator/lib/book_core/models/conflict.rb"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (value objects)
2. Complete Phase 2: Foundational (DiffEngine + RevisionStore)
3. Complete Phase 3: User Story 1 (revision tracking + CLI)
4. **STOP and VALIDATE**: Test canon history, diff, rollback independently
5. Deploy/demo if ready

### Incremental Delivery

1. Phase 1 + 2 → Foundation ready
2. Add US1 → Revision tracking works → Demo (MVP!)
3. Add US2 → Impact analysis works → Demo
4. Add US3 → Branching works → Demo
5. Add US4 → Batch changesets work → Demo
6. Polish → Production-ready

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story is independently completable and testable
- All tests run under `MOCK_AI=true` — no live AI calls
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
