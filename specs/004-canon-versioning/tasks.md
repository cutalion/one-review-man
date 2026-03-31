# Tasks: Canon Versioning and Snapshots

**Input**: Design documents from `/specs/004-canon-versioning/`
**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, contracts/

**Tests**: Tests are included — this feature is foundational infrastructure that other features depend on, and the constitution requires Test-First with Mock AI (Principle I).

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- Source: `book-generator/lib/book_core/`
- Models: `book-generator/lib/book_core/models/`
- CLI: `book-generator/lib/book/cli.rb`
- Tests: `book-generator/spec/book_core/`

---

## Phase 1: Setup

**Purpose**: Project initialization and shared infrastructure

- [x] T001 Create Snapshot value object in book-generator/lib/book_core/models/snapshot.rb — Struct with name, version, timestamp, branch, entity_counts fields; include to_yaml_hash and from_yaml class method (mirror Models::Revision pattern)
- [x] T002 Create custom error classes (DuplicateSnapshotError, InvalidSnapshotNameError, SnapshotNotFoundError, SnapshotCorruptError, FrozenSnapshotError) in book-generator/lib/book_core/snapshot_errors.rb

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core snapshot storage that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T003 Implement SnapshotStore#initialize and name validation in book-generator/lib/book_core/snapshot_store.rb — accept story_bible_path:, set up snapshots_path and index_path; implement private validate_name! method enforcing /\A[a-z0-9][a-z0-9\-]*\z/ regex, max 64 chars
- [x] T004 Implement SnapshotStore private helpers in book-generator/lib/book_core/snapshot_store.rb — load_index, save_index (_index.yml read/write), next_version (monotonic from index), copy_canon_data (copy characters/, locations/, facts.yml, relationships.yml, plot_threads.yml into snapshot dir), write_manifest (manifest.yml with entity counts)
- [x] T005 Write RSpec tests for SnapshotStore setup and helpers in book-generator/spec/book_core/snapshot_store_spec.rb — test initialization, name validation (valid names, invalid chars, too long, duplicates), index file creation

**Checkpoint**: SnapshotStore skeleton ready — user story implementation can now begin

---

## Phase 3: User Story 1 — Create a Canon Snapshot (Priority: P1) 🎯 MVP

**Goal**: Content creator can freeze the current Story Bible state as a named, immutable snapshot

**Independent Test**: Create a snapshot, modify Story Bible, verify snapshot still reflects original state

### Tests for User Story 1 ⚠️

- [x] T006 [P] [US1] Write RSpec tests for SnapshotStore#create in book-generator/spec/book_core/snapshot_store_spec.rb — test: creates snapshot directory with version-name prefix, copies all entity files, writes manifest.yml with correct entity counts, updates _index.yml, assigns monotonic version numbers, rejects duplicate names, rejects invalid name formats
- [x] T007 [P] [US1] Write RSpec tests for snapshot immutability in book-generator/spec/book_core/snapshot_store_spec.rb — test: snapshot files match original Story Bible state, modifying live Story Bible after snapshot does not affect snapshot data

### Implementation for User Story 1

- [x] T008 [US1] Implement SnapshotStore#create in book-generator/lib/book_core/snapshot_store.rb — validate name, check no duplicate in index, compute next version, create snapshot dir as "<version>-<name>/", call copy_canon_data, count entities, write manifest.yml, append to _index.yml, return manifest hash
- [x] T009 [US1] Add require for snapshot_store in book-generator/lib/book_core.rb (or wherever BookCore modules are loaded) to ensure autoloading

**Checkpoint**: `SnapshotStore.new(story_bible_path: path).create(name: "test")` works and creates immutable snapshot directory

---

## Phase 4: User Story 2 — Load Story Bible from a Snapshot (Priority: P1)

**Goal**: Load a read-only StoryBible instance from a named snapshot, without modifying live state

**Independent Test**: Create snapshot, modify live data, load from snapshot, verify original data returned

### Tests for User Story 2 ⚠️

- [x] T010 [P] [US2] Write RSpec tests for SnapshotStore#get and SnapshotStore#latest in book-generator/spec/book_core/snapshot_store_spec.rb — test: get by name, get by version number (Integer and String), returns nil for non-existent, latest returns most recent, latest returns nil when empty
- [x] T011 [P] [US2] Write RSpec tests for StoryBible.from_snapshot in book-generator/spec/book_core/story_bible_spec.rb — test: returns StoryBible reading from snapshot directory, characters/locations/facts/relationships/plot_threads match snapshot state not live state, raises SnapshotNotFoundError for unknown name, raises FrozenSnapshotError on write attempts (save_character, add_fact, etc.)
- [x] T012 [P] [US2] Write RSpec test for snapshot integrity validation in book-generator/spec/book_core/story_bible_spec.rb — test: raises SnapshotCorruptError when snapshot directory is missing required files

### Implementation for User Story 2

- [x] T013 [US2] Implement SnapshotStore#get in book-generator/lib/book_core/snapshot_store.rb — accept name_or_version (String or Integer), search index by name or version, return manifest hash or nil
- [x] T014 [US2] Implement SnapshotStore#latest in book-generator/lib/book_core/snapshot_store.rb — return last entry from index or nil
- [x] T015 [US2] Implement StoryBible.from_snapshot class method in book-generator/lib/book_core/story_bible.rb — resolve snapshot via SnapshotStore#get, validate snapshot directory has required files (characters/, locations/, facts.yml, relationships.yml, plot_threads.yml), create StoryBible instance with project_root overridden to snapshot directory path, mark instance as frozen (set @frozen = true)
- [x] T016 [US2] Add write-guard to StoryBible in book-generator/lib/book_core/story_bible.rb — add private check_frozen! method that raises FrozenSnapshotError if @frozen is true; call it at the start of save_character, save_location, add_fact, add_relationship, add_plot_thread

**Checkpoint**: `StoryBible.from_snapshot(project_root: path, snapshot_name: "test")` returns read-only bible with snapshot data

---

## Phase 5: User Story 3 — List and Inspect Snapshots (Priority: P2)

**Goal**: Content creator can see what snapshots exist and inspect their metadata

**Independent Test**: Create multiple snapshots, list them, verify all shown with correct metadata

### Tests for User Story 3 ⚠️

- [x] T017 [P] [US3] Write RSpec tests for SnapshotStore#list in book-generator/spec/book_core/snapshot_store_spec.rb — test: returns all snapshots ordered by version, returns empty array when no snapshots, each entry has name/version/timestamp/branch/entity_counts
- [x] T018 [P] [US3] Write RSpec tests for CLI snapshot commands in book-generator/spec/cli_snapshot_spec.rb — test: `book snapshot create NAME` output, `book snapshot list` output format, `book snapshot show NAME` output format, error cases (duplicate name, not found)

### Implementation for User Story 3

- [x] T019 [US3] Implement SnapshotStore#list in book-generator/lib/book_core/snapshot_store.rb — load index, return array of manifest hashes ordered by version
- [x] T020 [US3] Add SnapshotCli subcommand class in book-generator/lib/book/cli.rb — Thor subcommand `snapshot` with `create NAME`, `list`, `show NAME` actions; use resolve_project_root! and SnapshotStore; format output per CLI contract (contracts/cli-commands.md)
- [x] T021 [US3] Register SnapshotCli subcommand in main Runner class in book-generator/lib/book/cli.rb — add `subcommand "snapshot", SnapshotCli`

**Checkpoint**: `book snapshot create/list/show` CLI commands work end-to-end

---

## Phase 6: User Story 4 — Record Canon Version in Derivatives (Priority: P2)

**Goal**: Generated chapters/illustrations automatically record which canon snapshot they were produced from

**Independent Test**: Create snapshot, generate chapter, verify generation metadata includes canon version reference

### Tests for User Story 4 ⚠️

- [x] T022 [P] [US4] Write RSpec tests for CanonVersionReference.resolve in book-generator/spec/book_core/canon_version_reference_spec.rb — test: returns versioned hash when explicit snapshot given, returns latest snapshot hash when no explicit given, returns "unversioned" string when no snapshots exist, raises SnapshotNotFoundError for invalid explicit name
- [x] T023 [P] [US4] Write RSpec tests for ChapterGenerator snapshot integration in book-generator/spec/book_core/chapter_generation_spec.rb — test: generated chapter front matter includes canon_version field, generation uses snapshot StoryBible when snapshot: kwarg provided, generation uses latest snapshot by default when snapshots exist, generation records "unversioned" when no snapshots exist

### Implementation for User Story 4

- [x] T024 [US4] Implement CanonVersionReference.resolve in book-generator/lib/book_core/canon_version_reference.rb — accept snapshot_store: and explicit_snapshot: nil; if explicit, look up and return hash; if nil, check latest; if no snapshots, return "unversioned"
- [x] T025 [US4] Modify ChapterGenerator#initialize to accept snapshot: kwarg in book-generator/lib/book_core/chapter_generator.rb — when snapshot provided, load StoryBible.from_snapshot; store SnapshotStore instance for version reference resolution
- [x] T026 [US4] Modify ChapterGenerator#write_chapter_file to include canon_version in chapter front matter in book-generator/lib/book_core/chapter_generator.rb — call CanonVersionReference.resolve, merge result into metadata hash passed to output adapter
- [x] T027 [US4] Add --snapshot option to `generate chapter` and `generate illustration` CLI commands in book-generator/lib/book/cli.rb — pass snapshot value to ChapterGenerator/IllustrationGenerator constructor

**Checkpoint**: `book generate chapter --snapshot initial` produces chapter with `canon_version` in front matter

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [x] T028 [P] Add snapshot_store require to book-generator/lib/book_core.rb and verify all new files have frozen_string_literal: true
- [x] T029 [P] Run `bundle exec rubocop` on all new and modified files and fix any violations
- [x] T030 Run full test suite with `MOCK_AI=true bundle exec rspec` to verify no regressions
- [x] T031 Run quickstart.md validation — execute the quickstart commands against a test book project to confirm end-to-end workflow

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion — BLOCKS all user stories
- **US1 (Phase 3)**: Depends on Foundational — creates snapshots
- **US2 (Phase 4)**: Depends on Foundational — loads snapshots (can run parallel with US1 if T008 create is done)
- **US3 (Phase 5)**: Depends on US1 (needs snapshots to list/show) — CLI layer
- **US4 (Phase 6)**: Depends on US1 + US2 (needs create + load) — integration layer
- **Polish (Phase 7)**: Depends on all user stories complete

### User Story Dependencies

- **US1 (P1)**: Can start after Foundational — No dependencies on other stories
- **US2 (P1)**: Can start after Foundational — Independent from US1 (uses SnapshotStore#get, not #create in tests — tests create their own fixtures)
- **US3 (P2)**: Can start after Foundational — CLI wraps SnapshotStore methods already built in US1/US2
- **US4 (P2)**: Depends on US1 + US2 being complete (needs both create and load to work)

### Within Each User Story

- Tests MUST be written and FAIL before implementation
- SnapshotStore methods before StoryBible integration
- StoryBible integration before ChapterGenerator integration
- Core implementation before CLI wiring

### Parallel Opportunities

- T001 and T002 can run in parallel (different files)
- T006 and T007 can run in parallel (same file but independent test contexts)
- T010, T011, T012 can run in parallel (different test files)
- T017 and T018 can run in parallel (different test files)
- T022 and T023 can run in parallel (different test files)
- T028 and T029 can run in parallel (independent tasks)

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001-T002)
2. Complete Phase 2: Foundational (T003-T005)
3. Complete Phase 3: User Story 1 (T006-T009)
4. **STOP and VALIDATE**: Create a snapshot in a test project, verify files on disk
5. Demo: `book snapshot create initial -b books/one-review-man`

### Incremental Delivery

1. Setup + Foundational → SnapshotStore skeleton ready
2. Add US1 → Snapshots can be created → Validate independently
3. Add US2 → Snapshots can be loaded as read-only StoryBible → Validate independently
4. Add US3 → CLI commands for create/list/show → Validate independently
5. Add US4 → Generation records canon version → Validate end-to-end
6. Polish → Rubocop, full test suite, quickstart validation

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Verify tests fail before implementing
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- SnapshotStore pattern mirrors existing RevisionStore and BranchManager — follow their conventions
