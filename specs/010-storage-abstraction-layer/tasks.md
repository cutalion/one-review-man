# Tasks: Storage Abstraction Layer

**Input**: Design documents from `/specs/010-storage-abstraction-layer/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Included — spec requires contract conformance tests to prove backend equivalence (SC-001, SC-002).

**Organization**: Tasks grouped by user story. US1 (backend switching) and US3 (backward compatibility) are co-P1 and handled together since extracting the file backend IS preserving backward compatibility. US2 (in-memory) builds on the contracts. US4 (extensibility) is validated by the design itself.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: Setup

**Purpose**: Create directory structure and contract modules

- [x] T001 Create storage directory structure: `eidos/lib/eidos/storage/`, `eidos/lib/eidos/storage/yaml_file/`, `eidos/lib/eidos/storage/memory/`
- [x] T002 [P] Define EntityStorage contract module with required method signatures in `eidos/lib/eidos/storage/entity_storage.rb`
- [x] T003 [P] Define RevisionStorage contract module with required method signatures in `eidos/lib/eidos/storage/revision_storage.rb`
- [x] T004 [P] Define SnapshotStorage contract module with required method signatures in `eidos/lib/eidos/storage/snapshot_storage.rb`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Shared examples (contract conformance tests) and StorageFactory — MUST complete before backend implementations

- [x] T005 [P] Create shared EntityStorage conformance examples in `eidos/spec/eidos/storage/shared_entity_storage_examples.rb` — tests all operations from contracts/entity_storage.md
- [x] T006 [P] Create shared RevisionStorage conformance examples in `eidos/spec/eidos/storage/shared_revision_storage_examples.rb` — tests all operations from contracts/revision_storage.md
- [x] T007 [P] Create shared SnapshotStorage conformance examples in `eidos/spec/eidos/storage/shared_snapshot_storage_examples.rb` — tests all operations from contracts/snapshot_storage.md
- [x] T008 Implement StorageFactory in `eidos/lib/eidos/storage/factory.rb` — reads `data/settings.yml` `storage.backend` key, returns adapter instances, defaults to `yaml_file`
- [x] T009 Create StorageFactory spec in `eidos/spec/eidos/storage/factory_spec.rb` — tests backend resolution, default fallback, and invalid backend error

**Checkpoint**: Contract test harness and factory ready — backend implementations can now begin

---

## Phase 3: User Story 1 + 3 — Extract YamlFile Backend & Preserve Backward Compatibility (Priority: P1)

**Goal**: Extract current filesystem logic into YamlFile adapters. All existing behavior preserved exactly. All 388 existing tests pass unchanged.

**Independent Test**: Run `bundle exec rspec` — all 388 examples pass. Run CLI commands (`bible list characters`, `canon history`, `canon snapshot create`) — identical output.

### Tests

- [x] T010 [P] [US1] Create YamlFile EntityStorage spec in `eidos/spec/eidos/storage/yaml_file/entity_storage_spec.rb` — includes shared examples from T005
- [x] T011 [P] [US1] Create YamlFile RevisionStorage spec in `eidos/spec/eidos/storage/yaml_file/revision_storage_spec.rb` — includes shared examples from T006
- [x] T012 [P] [US1] Create YamlFile SnapshotStorage spec in `eidos/spec/eidos/storage/yaml_file/snapshot_storage_spec.rb` — includes shared examples from T007

### Implementation

- [x] T013 [US1] Extract filesystem methods from `eidos/lib/eidos/story_bible.rb` into `eidos/lib/eidos/storage/yaml_file/entity_storage.rb` — move `load_yaml_file`, `write_yaml_file`, `load_entities_from_dir`, `touch_yaml_file` and all path construction; implement EntityStorage contract
- [x] T014 [US1] Extract filesystem logic from `eidos/lib/eidos/revision_store.rb` into `eidos/lib/eidos/storage/yaml_file/revision_storage.rb` — move all File/Dir/YAML operations; implement RevisionStorage contract
- [x] T015 [US1] Extract filesystem logic from `eidos/lib/eidos/snapshot_store.rb` into `eidos/lib/eidos/storage/yaml_file/snapshot_storage.rb` — move all FileUtils/File/Dir operations; implement SnapshotStorage contract; add `snapshot_data` method that returns entity data as hashes
- [x] T016 [US1] Refactor `eidos/lib/eidos/story_bible.rb` to accept and delegate to EntityStorage adapter — replace private filesystem methods with adapter calls; accept `entity_storage:` constructor parameter; keep caching, frozen checks, revision recording in StoryBible
- [x] T017 [US1] Refactor `eidos/lib/eidos/revision_store.rb` to become a thin wrapper around RevisionStorage adapter — accept `revision_storage:` or maintain backward-compatible constructor with `revisions_path:`
- [x] T018 [US1] Refactor `eidos/lib/eidos/snapshot_store.rb` to become a thin wrapper around SnapshotStorage adapter — accept `snapshot_storage:` or maintain backward-compatible constructor with `story_bible_path:`
- [x] T019 [US1] Refactor `StoryBible.from_snapshot` in `eidos/lib/eidos/story_bible.rb` to use `snapshot_data` (returns hashes) instead of `snapshot_path` (returns filesystem path)
- [x] T020 [US1] Update CLI helper methods in `eidos/lib/eidos/cli/canon.rb` — `build_revision_store` and snapshot commands use StorageFactory
- [x] T021 [US1] Update CLI helper methods in `eidos/lib/eidos/cli/bible.rb` — StoryBible creation uses StorageFactory for entity storage
- [x] T022 [US1] Update CLI helper methods in `eidos/lib/eidos/cli/produce.rb` — StoryBible and SnapshotStore creation uses StorageFactory
- [x] T023 [US1] Update inline store instantiation in `eidos/lib/eidos/producers/chapter_producer.rb`, `eidos/lib/eidos/producers/instagram_comic_producer.rb`, `eidos/lib/eidos/chapter_generator.rb`, `eidos/lib/eidos/producer.rb`, `eidos/lib/eidos/story_bible_exporter.rb`, `eidos/lib/eidos/story_bible_migrator.rb` — use StorageFactory or accept injected adapter
- [x] T024 [US1] Run full test suite (`bundle exec rspec`) — verify all 388 examples pass with zero changes to test files

**Checkpoint**: YamlFile backend extracted. All existing behavior preserved. `bundle exec rspec` green.

---

## Phase 4: User Story 2 — In-Memory Storage Backend (Priority: P2)

**Goal**: Implement in-memory adapters for all three contracts. Tests can use them for speed and isolation.

**Independent Test**: Run shared conformance tests against memory backend — all pass. Run full test suite with memory backend configured — all pass.

### Tests

- [x] T025 [P] [US2] Create Memory EntityStorage spec in `eidos/spec/eidos/storage/memory/entity_storage_spec.rb` — includes shared examples from T005
- [x] T026 [P] [US2] Create Memory RevisionStorage spec in `eidos/spec/eidos/storage/memory/revision_storage_spec.rb` — includes shared examples from T006
- [x] T027 [P] [US2] Create Memory SnapshotStorage spec in `eidos/spec/eidos/storage/memory/snapshot_storage_spec.rb` — includes shared examples from T007

### Implementation

- [x] T028 [P] [US2] Implement Memory EntityStorage in `eidos/lib/eidos/storage/memory/entity_storage.rb` — Hash-based storage for all entity types, search via Enumerable
- [x] T029 [P] [US2] Implement Memory RevisionStorage in `eidos/lib/eidos/storage/memory/revision_storage.rb` — Array-based append-only storage with branch-scoped hashes
- [x] T030 [P] [US2] Implement Memory SnapshotStorage in `eidos/lib/eidos/storage/memory/snapshot_storage.rb` — Hash-based with deep-copy for immutability
- [x] T031 [US2] Register `memory` backend in StorageFactory in `eidos/lib/eidos/storage/factory.rb`
- [x] T032 [US2] Run shared conformance tests for all three Memory adapters — verify 100% pass

**Checkpoint**: Memory backend complete. Both backends pass identical conformance tests.

---

## Phase 5: User Story 4 — Extensibility Validation (Priority: P3)

**Goal**: Validate that a new backend can be added without modifying core code. Ensure contract validation catches incomplete backends.

**Independent Test**: Implement a minimal "null" backend using only the documented contract. Register it. Verify it works without any changes to StoryBible, CLI, or other application code.

- [x] T033 [US4] Add contract validation to StorageFactory in `eidos/lib/eidos/storage/factory.rb` — verify backend implements all required methods before returning; raise clear error listing missing methods
- [x] T034 [US4] Create extensibility validation spec in `eidos/spec/eidos/storage/extensibility_spec.rb` — test that a minimal conforming backend plugs in without core changes; test that incomplete backend raises descriptive error

**Checkpoint**: Extensibility proven. Contract validation catches incomplete backends.

---

## Phase 6: Polish & Cross-Cutting Concerns

- [x] T035 [P] Add `storage` configuration section to `eidos/lib/eidos/configuration.rb` if needed — ensure StorageFactory can read from Configuration object
- [x] T036 [P] Update `eidos/lib/eidos/cli/world.rb` `new` command to include `storage.backend: yaml_file` in generated `data/settings.yml`
- [x] T037 Run full test suite with both backends (`bundle exec rspec`) — final regression check
- [x] T038 Run RuboCop (`bundle exec rubocop`) on all new and modified files — RuboCop not in Gemfile, skipped

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 (contract modules exist)
- **US1+US3 (Phase 3)**: Depends on Phase 2 (shared examples + factory exist)
- **US2 (Phase 4)**: Depends on Phase 2 (shared examples + factory exist). Can run in parallel with Phase 3.
- **US4 (Phase 5)**: Depends on Phase 3 (factory and at least one backend exist)
- **Polish (Phase 6)**: Depends on Phases 3-5

### User Story Dependencies

- **US1+US3 (P1)**: Foundational phase only — no dependency on other stories
- **US2 (P2)**: Foundational phase only — can run in parallel with US1+US3
- **US4 (P3)**: Requires at least one backend registered in factory (US1 or US2)

### Within Each User Story

- Tests written first (T010-T012 before T013-T024)
- Contract modules before implementations
- Entity storage before revision/snapshot (revision depends on entity for snapshot_data)
- Core adapters before CLI wiring
- CLI wiring before full regression run

### Parallel Opportunities

**Phase 1**: T002, T003, T004 in parallel (separate contract files)
**Phase 2**: T005, T006, T007 in parallel (separate shared example files)
**Phase 3**: T010, T011, T012 in parallel (separate test files); T013, T014, T015 partially parallel (separate adapter files, but T016 depends on T013)
**Phase 4**: T025-T027 in parallel; T028-T030 in parallel (all independent files)
**Phase 6**: T035, T036 in parallel

---

## Parallel Example: Phase 4 (User Story 2)

```
# Launch all memory adapter tests together:
Task: T025 "Memory EntityStorage spec"
Task: T026 "Memory RevisionStorage spec"
Task: T027 "Memory SnapshotStorage spec"

# Launch all memory adapter implementations together:
Task: T028 "Memory EntityStorage implementation"
Task: T029 "Memory RevisionStorage implementation"
Task: T030 "Memory SnapshotStorage implementation"
```

---

## Implementation Strategy

### MVP First (User Story 1+3 Only)

1. Complete Phase 1: Setup (contract modules)
2. Complete Phase 2: Foundational (shared tests + factory)
3. Complete Phase 3: US1+US3 (extract YamlFile, preserve compatibility)
4. **STOP and VALIDATE**: `bundle exec rspec` — all 388 green
5. This alone delivers the core abstraction with zero regression

### Incremental Delivery

1. Setup + Foundational → Test harness ready
2. US1+US3 → File backend extracted, all tests pass (MVP!)
3. US2 → Memory backend, fast test mode available
4. US4 → Contract validation, extensibility proven
5. Polish → Configuration, RuboCop, final check

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- US1 and US3 are merged because extracting the file backend IS preserving backward compatibility — they cannot be implemented independently
- Commit after each task or logical group
- Stop at any checkpoint to validate independently
