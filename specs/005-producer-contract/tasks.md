# Tasks: Producer Contract Interface

**Input**: Design documents from `/specs/005-producer-contract/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/ruby-api.md

**Tests**: Included — project constitution (Principle I) requires test-first with MOCK_AI=true.

**Organization**: Tasks grouped by user story for independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: Setup

**Purpose**: Create directory structure and placeholder files for the producer subsystem.

- [x] T001 Create producers directory at `book-generator/lib/book_core/producers/`
- [x] T002 [P] Create empty producer module file at `book-generator/lib/book_core/producer.rb`
- [x] T003 [P] Create empty producer result file at `book-generator/lib/book_core/producer_result.rb`
- [x] T004 [P] Create spec directory at `book-generator/spec/book_core/producers/`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Implement the Producer module, ProducerResult, and ProducerRegistry that all user stories depend on.

**CRITICAL**: No user story work can begin until this phase is complete.

- [x] T005 Implement ProducerResult struct in `book-generator/lib/book_core/producer_result.rb` with fields: success, output_path, canon_version, artifacts, error (keyword_init, following Models::Snapshot pattern)
- [x] T006 [P] Implement Producer module in `book-generator/lib/book_core/producer.rb` with: ClassMethods (producer_name, producer_description, default_output_path), instance method `produce(snapshot:, config:, output:)` raising NotImplementedError, `validate!` base implementation checking snapshot existence via CanonVersionReference and output path writability, and class-level registry methods (register, find, all)
- [x] T007 [P] Write specs for ProducerResult in `book-generator/spec/book_core/producer_result_spec.rb` — test struct creation, field access, keyword_init
- [x] T008 Write specs for Producer module in `book-generator/spec/book_core/producer_spec.rb` — test: including module adds class methods, produce raises NotImplementedError, validate! checks snapshot and output writability, register/find/all registry methods work, producer_name/description/default_output_path DSL

**Checkpoint**: Producer interface and registry are functional. User story implementation can begin.

---

## Phase 3: User Story 1 & 2 — Producer Interface + ChapterProducer Retrofit (Priority: P1)

**Goal**: Create ChapterProducer that wraps ChapterGenerator and implements the Producer interface. US1 and US2 are merged here because the interface is only validated by its first implementation.

**Independent Test**: Invoke ChapterProducer.new(...).produce and verify it returns a ProducerResult with success: true, correct canon_version, and artifacts written to the output path.

### Tests for User Stories 1 & 2

- [x] T009 [P] [US1] Write specs for ChapterProducer in `book-generator/spec/book_core/producers/chapter_producer_spec.rb` — test: includes Producer module, producer_name is :chapter, produce delegates to ChapterGenerator and returns ProducerResult, canon_version is recorded, validate! rejects invalid snapshots, default output path is content/chapters
- [x] T010 [P] [US2] Write integration spec verifying ChapterProducer produces identical output to direct ChapterGenerator usage in `book-generator/spec/book_core/producers/chapter_producer_integration_spec.rb` — test with MOCK_AI, compare front matter and content

### Implementation for User Stories 1 & 2

- [x] T011 [US1] Implement ChapterProducer in `book-generator/lib/book_core/producers/chapter_producer.rb` — include Producer, set producer_name/description/default_output_path, implement initialize(project_root:, llm_service: nil, **deps), implement produce(snapshot:, config:, output:) that constructs ChapterGenerator with appropriate kwargs and calls generate_next_chapter, wrap result in ProducerResult
- [x] T012 [US2] Register ChapterProducer in the Producer registry — add `BookCore::Producer.register(:chapter, BookCore::Producers::ChapterProducer)` at end of `book-generator/lib/book_core/producers/chapter_producer.rb`
- [x] T013 [US2] Verify all existing ChapterGenerator tests still pass by running `bundle exec rspec spec/chapter_generation_spec.rb spec/book_core/story_bible_spec.rb spec/cli_spec.rb` — zero regressions

**Checkpoint**: ChapterProducer works through the producer interface. US1 and US2 are independently testable.

---

## Phase 4: User Story 3 — Configurable Output Location (Priority: P2)

**Goal**: Producers accept an explicit output location, falling back to their default. ChapterProducer configures its output adapter to write to the specified path.

**Independent Test**: Invoke ChapterProducer.produce(output: '/tmp/test-output') and verify artifacts are written there, not to the default content/chapters.

### Tests for User Story 3

- [x] T014 [P] [US3] Add specs for output location in `book-generator/spec/book_core/producers/chapter_producer_spec.rb` — test: produce with explicit output writes to that path, produce without output writes to default, output directory is created if missing

### Implementation for User Story 3

- [x] T015 [US3] Update ChapterProducer.produce in `book-generator/lib/book_core/producers/chapter_producer.rb` to pass output location to the output adapter — configure BookContentAdapter (or injected adapter) with the specified output root before delegating to ChapterGenerator
- [x] T016 [US3] Ensure output directory auto-creation in ChapterProducer.produce — create output dir with FileUtils.mkdir_p before delegating if it doesn't exist

**Checkpoint**: Output location is fully configurable. US3 testable independently.

---

## Phase 5: User Story 4 — CLI Wiring (Priority: P3)

**Goal**: The existing `book generate chapter` CLI routes through ChapterProducer internally. Add `--output` flag. Behavior is identical to before from the user's perspective.

**Independent Test**: Run `book generate chapter -b books/one-review-man --output /tmp/test` and verify it works identically to the old command but artifacts appear at the specified output path.

### Tests for User Story 4

- [x] T017 [P] [US4] Add CLI integration specs in `book-generator/spec/cli_spec.rb` — test: `generate chapter` with `--output` flag passes output to producer, `generate chapter` without `--output` uses default behavior, existing CLI options (--snapshot, --auto, --debug) still work

### Implementation for User Story 4

- [x] T018 [US4] Add `--output` method_option to Generate#chapter in `book-generator/lib/book/cli.rb` — type: :string, desc: 'Output directory for generated artifacts'
- [x] T019 [US4] Wire Generate#chapter to use ChapterProducer internally in `book-generator/lib/book/cli.rb` — construct ChapterProducer with project_root and call produce(snapshot:, config:, output:), mapping existing CLI options (auto, model, debug) into the config hash
- [x] T020 [US4] Verify full CLI test suite passes — run `bundle exec rspec spec/cli_spec.rb spec/cli_snapshot_spec.rb` with zero failures

**Checkpoint**: CLI works identically to before, routed through producer interface. US4 testable independently.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final validation and cleanup.

- [x] T021 Run full test suite `MOCK_AI=true bundle exec rspec` — all tests pass (existing 282 + new producer tests)
- [x] T022 [P] Verify quickstart.md examples work — manually test Ruby API and CLI examples from `specs/005-producer-contract/quickstart.md`
- [x] T023 [P] Update CLAUDE.md Active Technologies section if needed
- [x] T024 Verify SC-002 (extensibility): create a minimal test-only producer in specs that includes Producer, registers itself, and produces dummy output — confirms no existing code changes needed to add a new producer

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on Setup — BLOCKS all user stories
- **US1 & US2 (Phase 3)**: Depends on Foundational phase
- **US3 (Phase 4)**: Depends on Phase 3 (needs ChapterProducer to exist)
- **US4 (Phase 5)**: Depends on Phase 4 (needs output location support before CLI wiring)
- **Polish (Phase 6)**: Depends on all phases complete

### Within Each Phase

- Tests written FIRST, verified to fail before implementation
- Value objects before modules
- Modules before implementations
- Implementation before registration
- Registration before CLI wiring

### Parallel Opportunities

- T001, T002, T003, T004 (Phase 1 file/dir creation) — all parallel
- T006, T007 (Producer module + result specs) — parallel
- T009, T010 (Phase 3 tests) — parallel
- T014, T017 (Phase 4 & 5 tests) — parallel if written ahead

---

## Parallel Example: Phase 2

```bash
# Launch foundational value object and module in parallel:
Task: "T005 - Implement ProducerResult in book-generator/lib/book_core/producer_result.rb"
Task: "T006 - Implement Producer module in book-generator/lib/book_core/producer.rb"
Task: "T007 - Write specs for ProducerResult in book-generator/spec/book_core/producer_result_spec.rb"
```

---

## Implementation Strategy

### MVP First (Phase 1-3 Only)

1. Complete Phase 1: Setup (5 min)
2. Complete Phase 2: Foundational — Producer, ProducerResult, Registry
3. Complete Phase 3: ChapterProducer wrapping ChapterGenerator
4. **STOP and VALIDATE**: All existing tests pass + ChapterProducer tests pass
5. This is a fully functional MVP — the producer contract works

### Incremental Delivery

1. Setup + Foundational → Interface ready
2. Add US1+US2 → ChapterProducer works → MVP
3. Add US3 → Output location configurable
4. Add US4 → CLI wired through producer
5. Polish → Full validation

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story
- Each user story independently completable and testable
- Commit after each phase
- US1 and US2 are merged in Phase 3 because the interface (US1) is only proven by its first implementation (US2)
