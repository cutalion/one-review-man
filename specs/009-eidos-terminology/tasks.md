# Tasks: Eidos Terminology Refactoring

**Input**: Design documents from `/specs/009-eidos-terminology/`
**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, contracts/cli-commands.md

**Tests**: Tests are included — FR-009 requires all existing tests pass after refactoring. Test updates are mechanical (namespace/path renames).

**Organization**: Tasks are grouped by user story. Since this is a rename refactoring, the foundational phase does the heavy lifting (namespace/file renames), and user stories focus on CLI restructuring and verification.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Gem root**: `eidos/` (was `book-generator/`)
- **Core library**: `eidos/lib/eidos/` (was `book-generator/lib/book_core/`)
- **CLI**: `eidos/lib/eidos/cli/` (was `book-generator/lib/book/cli.rb`)
- **Binaries**: `eidos/bin/` (was `book-generator/bin/book`)
- **Tests**: `eidos/spec/` (was `book-generator/spec/`)
- **World data**: `worlds/one-review-man/` (was `books/one-review-man/`)

---

## Phase 1: Setup

**Purpose**: Rename directory structure and gem, establish new namespace

- [x] T001 Rename `book-generator/` directory to `eidos/`
- [x] T002 Rename `eidos/book-generator.gemspec` to `eidos/eidos.gemspec` and update gem name from `'book-generator'` to `'eidos'`, update `spec.require_paths` if needed
- [x] T003 Create `eidos/lib/eidos.rb` as the main entry point (replaces implicit `book/cli` require chain). This file should `require` core modules under `eidos/` namespace
- [x] T004 Rename `eidos/lib/book_core/` directory to `eidos/lib/eidos/` (move all core files)
- [x] T005 Move `eidos/lib/book/translator.rb` to `eidos/lib/eidos/translator.rb`
- [x] T006 Move `eidos/lib/book/cli/version.rb` to `eidos/lib/eidos/cli/version.rb` and update module from `Book::CLI::VERSION` to `Eidos::CLI::VERSION`
- [x] T007 Remove empty `eidos/lib/book/` and `eidos/lib/book_core/` directories after moves

**Checkpoint**: Directory structure matches plan. Files are in new locations but namespaces inside files are still old.

---

## Phase 2: Foundational (Namespace Rename)

**Purpose**: Mechanical find-and-replace of all namespaces, class names, require paths, and config file references. MUST complete before any user story work.

**CRITICAL**: No user story work can begin until this phase is complete.

### Core namespace renames (all files in eidos/lib/eidos/)

- [x] T008 [P] Rename `BookCore::WorldConfig` class (was `BookConfig`) in `eidos/lib/eidos/world_config.rb` (was `book_config.rb`): change `module BookCore` to `module Eidos`, class name `BookConfig` to `WorldConfig`, nested exceptions `BookConfig::ValidationError` to `WorldConfig::ValidationError`, `BookConfig::NotFoundError` to `WorldConfig::NotFoundError`
- [x] T009 [P] Rename `BookCore::Configuration` to `Eidos::Configuration` in `eidos/lib/eidos/configuration.rb`: update module declaration and all internal `BookCore::` references
- [x] T010 [P] Rename `BookCore::BookContentAdapter` to `Eidos::ContentAdapter` in `eidos/lib/eidos/content_adapter.rb` (was `book_content_adapter.rb`): update module, class name
- [x] T011 [P] Rename `BookUtils` to `Eidos::Utils` in `eidos/lib/eidos/utils.rb` (was `book_utils.rb`): update module declaration
- [x] T012 [P] Rename `BookCore::ChapterGenerator` to `Eidos::ChapterGenerator` in `eidos/lib/eidos/chapter_generator.rb`: update module declaration and all internal `BookCore::` references
- [x] T013 [P] Rename `BookCore::StoryBible` to `Eidos::StoryBible` in `eidos/lib/eidos/story_bible.rb`
- [x] T014 [P] Rename `BookCore::WriterAgent` to `Eidos::WriterAgent` in `eidos/lib/eidos/writer_agent.rb`
- [x] T015 [P] Rename `BookCore::LLMService` to `Eidos::LLMService` in `eidos/lib/eidos/llm_service.rb` (including `LLMError`, `ConfigurationError`, `APIError`)
- [x] T016 [P] Rename `BookCore::Producer` to `Eidos::Producer` in `eidos/lib/eidos/producer.rb`
- [x] T017 [P] Rename `BookCore::JekyllAdapter` to `Eidos::JekyllAdapter` in `eidos/lib/eidos/jekyll_adapter.rb`
- [x] T018 [P] Rename `BookCore::PromptProvider` to `Eidos::PromptProvider` in `eidos/lib/eidos/prompt_provider.rb`
- [x] T019 [P] Rename `BookCore::IllustrationGenerator` to `Eidos::IllustrationGenerator` in `eidos/lib/eidos/illustration_generator.rb`
- [x] T020 [P] Rename `BookCore::SnapshotStore` to `Eidos::SnapshotStore` in `eidos/lib/eidos/snapshot_store.rb` (including all snapshot error classes)
- [x] T021 [P] Rename `BookCore::BranchManager` to `Eidos::BranchManager` in `eidos/lib/eidos/branch_manager.rb`
- [x] T022 [P] Rename `BookCore::RevisionStore` to `Eidos::RevisionStore` in `eidos/lib/eidos/revision_store.rb`
- [x] T023 [P] Rename `BookCore::ChangesetManager` to `Eidos::ChangesetManager` in `eidos/lib/eidos/changeset_manager.rb` (including `ChangesetConflictError`)
- [x] T024 [P] Rename `BookCore::DiffEngine` to `Eidos::DiffEngine` in `eidos/lib/eidos/diff_engine.rb`
- [x] T025 [P] Rename `BookCore::ImpactAnalyzer` to `Eidos::ImpactAnalyzer` in `eidos/lib/eidos/impact_analyzer.rb`
- [x] T026 [P] Rename `BookCore::StoryBibleExporter` to `Eidos::StoryBibleExporter` in `eidos/lib/eidos/story_bible_exporter.rb`
- [x] T027 [P] Rename `BookCore::StoryBibleMigrator` to `Eidos::StoryBibleMigrator` in `eidos/lib/eidos/story_bible_migrator.rb`
- [x] T028 [P] Rename `BookCore::Reset` to `Eidos::Reset` in `eidos/lib/eidos/reset.rb`
- [x] T029 [P] Rename `Book::Translator` to `Eidos::Translator` in `eidos/lib/eidos/translator.rb`

### Utility module renames

- [x] T030 [P] Rename `WorldUtils` to `Eidos::WorldUtils` in `eidos/lib/eidos/world_utils.rb`
- [x] T031 [P] Rename `PromptUtils` to `Eidos::PromptUtils` in `eidos/lib/eidos/prompt_utils.rb`
- [x] T032 [P] Rename `ValidationUtils` to `Eidos::ValidationUtils` in `eidos/lib/eidos/validation_utils.rb`
- [x] T033 [P] Rename `EnvUtils` to `Eidos::EnvUtils` in `eidos/lib/eidos/env_utils.rb`
- [x] T034 [P] Rename remaining `BookCore::` to `Eidos::` in: `eidos/lib/eidos/config.rb`, `eidos/lib/eidos/file_utils.rb`, `eidos/lib/eidos/models/impact_report.rb`, `eidos/lib/eidos/models/revision.rb`, `eidos/lib/eidos/models/branch.rb`, `eidos/lib/eidos/models/changeset.rb`, `eidos/lib/eidos/models/conflict.rb`, `eidos/lib/eidos/models/snapshot.rb`, `eidos/lib/eidos/models/comic_panel.rb`, `eidos/lib/eidos/models/panel_set.rb`, `eidos/lib/eidos/producers/chapter_producer.rb`, `eidos/lib/eidos/producers/instagram_comic_producer.rb`, `eidos/lib/eidos/agent_tools/story_bible_tools.rb`

### Require path updates

- [x] T035 Update all `require 'book_core/...'` statements to `require 'eidos/...'` across all files in `eidos/lib/eidos/`
- [x] T036 Update all `require 'book/...'` statements to `require 'eidos/...'` or `require 'eidos/cli/...'` across all files
- [x] T037 Update `eidos/lib/eidos.rb` entry point to require all core modules with new paths

### Config file reference updates in code

- [x] T038 Update `WorldConfig` (was `BookConfig`) to look for `world_config.yml`, `world_state.yml`, `world_metadata.yml` instead of `book_config.yml`, `book_state.yml`, `book_metadata.yml` in `eidos/lib/eidos/world_config.rb`
- [x] T039 Update `WorldConfig` to read `world:` key instead of `book:` key from `world_state.yml` in `eidos/lib/eidos/world_config.rb`
- [x] T040 Update `resolve_project_root` helper to detect `world_metadata.yml` as the sole canonical marker (per spec FR-004 clarification) instead of `book_metadata.yml` and `book_config.yml`
- [x] T041 Update all user-facing strings that say "book" to say "world" (error messages, help text, status output) — grep for `book` in all `.rb` files under `eidos/lib/`

### Test updates

- [x] T042 Update all `require` statements in `eidos/spec/` files from `book_core/` to `eidos/` paths
- [x] T043 Update all `BookCore::` references to `Eidos::` in test files under `eidos/spec/`
- [x] T044 Update all `Book::CLI::` references to `Eidos::CLI::` in test files under `eidos/spec/`
- [x] T045 Update all `BookConfig` references to `WorldConfig` in test files
- [x] T046 Update all test fixtures and paths that reference `books/` to `worlds/` or `book_config.yml` to `world_config.yml` in test files
- [x] T047 Update mock responses and test support files in `eidos/spec/support/` if they reference old namespaces
- [x] T048 Run `MOCK_AI=true bundle exec rspec` in `eidos/` and fix any remaining failures

**Checkpoint**: All namespaces renamed. `MOCK_AI=true bundle exec rspec` passes. No user-facing changes yet (CLI still monolithic).

---

## Phase 3: User Story 1 - Domain-Specific CLI Commands (Priority: P1) — MVP

**Goal**: Split the monolithic `bin/book` CLI into six domain-specific binaries that read naturally.

**Independent Test**: Run each binary with `--help` and verify domain-specific output. Run a representative command from each binary.

### Implementation for User Story 1

- [x] T049 [US1] Extract shared CLI helpers from the monolithic CLI into `eidos/lib/eidos/cli/helpers.rb` — include `resolve_project_root`, `resolve_project_root!`, path validation, YAML write utilities. Module: `Eidos::CLI::Helpers`
- [x] T050 [P] [US1] Create `eidos/lib/eidos/cli/world.rb` — Thor class `Eidos::CLI::World` with commands: `new`/`init`, `status`, `migrate` (legacy config format), `reset`, `version`. Extract from old CLI's `Init`, `Reset`, `status`, `migrate`, `version` commands
- [x] T051 [P] [US1] Create `eidos/lib/eidos/cli/bible.rb` — Thor class `Eidos::CLI::Bible` with commands: `list`, `show`, `search`, `context`, `migrate` (story bible), `export`. Extract from old CLI's `Bible` class
- [x] T052 [P] [US1] Create `eidos/lib/eidos/cli/canon.rb` — Thor class `Eidos::CLI::Canon` with commands: `show`, `history`, `diff`, `rollback`, `update`, `impact`, `impact_review`, plus subcommands `snapshot`, `branch`, `changeset`. Extract from old CLI's `Canon`, `SnapshotCli`, `BranchCli`, `ChangesetCli` classes
- [x] T053 [P] [US1] Create `eidos/lib/eidos/cli/produce.rb` — Thor class `Eidos::CLI::Produce` with commands: `chapter`, `comic`, `illustration`, `prompt`, `write` (agent-based). Extract from old CLI's `Generate` and `Agent` classes
- [x] T054 [P] [US1] Create `eidos/lib/eidos/cli/translate.rb` — Thor class `Eidos::CLI::Translate` with commands: `chapter`, `character`, `all`. Extract from old CLI's `Translate` class
- [x] T055 [P] [US1] Create `eidos/lib/eidos/cli/publish.rb` — Thor class `Eidos::CLI::Publish` with commands: `jekyll`. Extract from old CLI's `Jekyll` class
- [x] T056 [P] [US1] Create `eidos/bin/world` executable — requires `eidos/cli/world` and calls `Eidos::CLI::World.start(ARGV)`
- [x] T057 [P] [US1] Create `eidos/bin/bible` executable — requires `eidos/cli/bible` and calls `Eidos::CLI::Bible.start(ARGV)`
- [x] T058 [P] [US1] Create `eidos/bin/canon` executable — requires `eidos/cli/canon` and calls `Eidos::CLI::Canon.start(ARGV)`
- [x] T059 [P] [US1] Create `eidos/bin/produce` executable — requires `eidos/cli/produce` and calls `Eidos::CLI::Produce.start(ARGV)`
- [x] T060 [P] [US1] Create `eidos/bin/translate` executable — requires `eidos/cli/translate` and calls `Eidos::CLI::Translate.start(ARGV)`
- [x] T061 [P] [US1] Create `eidos/bin/publish` executable — requires `eidos/cli/publish` and calls `Eidos::CLI::Publish.start(ARGV)`
- [x] T062 [US1] Remove old monolithic `eidos/lib/book/cli.rb` and `eidos/bin/book` after all new CLIs are working
- [x] T063 [US1] Update `eidos.gemspec` to declare all six binaries in `spec.executables`
- [x] T064 [US1] Replace all `--book-dir` / `-b` options with `--world-dir` / `-w` in all CLI files
- [x] T065 [US1] Update CLI spec tests in `eidos/spec/cli_spec.rb` (and related) to test new binary structure, command names, and `--world-dir` flag
- [x] T066 [US1] Verify each binary responds to `--help` with domain-specific commands and no "book" references

**Checkpoint**: All six binaries work. `world --help`, `bible --help`, etc. all respond correctly.

---

## Phase 4: User Story 2 - Migrate Existing World Data (Priority: P1)

**Goal**: Move `books/one-review-man` to `worlds/one-review-man` and rename config files + YAML keys.

**Independent Test**: Run migration, then run CLI commands against migrated world.

### Implementation for User Story 2

- [x] T067 [US2] Implement `world migrate` command in `eidos/lib/eidos/cli/world.rb` — moves `books/<name>/` to `worlds/<name>/`, renames `book_config.yml` → `world_config.yml`, `book_state.yml` → `world_state.yml`, `book_metadata.yml` → `world_metadata.yml`, rewrites `book:` key to `world:` in state/metadata YAML files
- [x] T068 [US2] Add edge case detection to `world migrate`: error if target `worlds/<name>/` already exists, error if source has partial old naming, report clear actionable messages
- [x] T069 [US2] Add legacy detection to `resolve_project_root` in `eidos/lib/eidos/cli/helpers.rb`: if `book_config.yml` or `book_metadata.yml` found but no `world_*` equivalent, print error suggesting `world migrate`
- [x] T070 [US2] Execute `world migrate -w books/one-review-man` on the actual project data to migrate `books/one-review-man/` to `worlds/one-review-man/`
- [x] T071 [US2] Update `.gitignore` if it references `books/` paths, and update any project-level references to `books/` in scripts (`quick_test.sh`, `e2e_test.sh`, `setup_jules.sh`, `docker-compose.yml`, etc.)
- [x] T072 [US2] Verify all CLI commands work against migrated `worlds/one-review-man` with no errors

**Checkpoint**: `worlds/one-review-man/` exists with renamed config files. All CLI commands succeed.

---

## Phase 5: User Story 3 - Initialize New World (Priority: P2)

**Goal**: `world new` scaffolds a world with new naming conventions, zero "book" references.

**Independent Test**: Run `world new`, inspect generated files.

### Implementation for User Story 3

- [x] T073 [US3] Update `world new`/`world init` in `eidos/lib/eidos/cli/world.rb` to scaffold `world_config.yml`, `world_state.yml`, `world_metadata.yml` (not `book_*`), with `world:` key in state file
- [x] T074 [US3] Update any template files in `eidos/templates/` that generate config YAML — replace `book` references with `world`
- [x] T075 [US3] Verify `world new -w worlds/test-world` creates correct structure with no "book" references in any generated file

**Checkpoint**: New world creation works with clean terminology.

---

## Phase 6: User Story 4 - Produce Content (Priority: P2)

**Goal**: `produce chapter` and `produce comic` work against worlds, with world-appropriate messaging.

**Independent Test**: Generate a chapter and comic, verify output and console messages.

### Implementation for User Story 4

- [x] T076 [US4] Verify `produce chapter -w worlds/one-review-man` generates content correctly (this should already work after Phase 2 namespace renames + Phase 3 CLI split)
- [x] T077 [US4] Verify `produce comic -w worlds/one-review-man` generates content correctly
- [x] T078 [US4] Grep all `produce` CLI output for any remaining "book" references in console messages and fix them in `eidos/lib/eidos/cli/produce.rb` and related files
- [x] T079 [US4] Verify `produce write -w worlds/one-review-man` (WriterAgent) works correctly under the new `produce` binary

**Checkpoint**: All produce commands work with world terminology.

---

## Phase 7: User Story 5 - Publish World Content (Priority: P3)

**Goal**: `publish jekyll` generates site from world directory.

**Independent Test**: Run `publish jekyll`, verify site output.

### Implementation for User Story 5

- [x] T080 [US5] Verify `publish jekyll -w worlds/one-review-man --dest site` generates the Jekyll site correctly
- [x] T081 [US5] Update Jekyll template data references in `eidos/lib/eidos/jekyll_adapter.rb` and `eidos/templates/jekyll/` if they use `book_metadata` key — change to `world_metadata` where appropriate
- [x] T082 [US5] Verify the generated `site/_data/` files use `world` terminology where appropriate (note: user-facing content like "Read the book" is out of scope)

**Checkpoint**: Publishing works end-to-end from world directory.

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Documentation updates, final cleanup, validation

- [x] T083 [P] Update constitution in `.specify/memory/constitution.md`: replace `book-generator/bin/book` with new binary references, `BookCore::` with `Eidos::`, `books/*/` with `worlds/*/`, `--book-dir` with `--world-dir`
- [x] T084 [P] Update `CLAUDE.md`: project structure, common commands, architecture sections — replace all `book-generator`, `BookCore`, `books/`, `--book-dir`, `bin/book` references
- [x] T085 [P] Update `docker-compose.yml` and `Dockerfile` if they reference `book-generator/` paths
- [x] T086 [P] Update `quick_test.sh` and `e2e_test.sh` scripts to use new paths and commands
- [x] T087 Run full test suite: `cd eidos && MOCK_AI=true bundle exec rspec` — all tests must pass
- [x] T088 Run `bundle exec rubocop` in `eidos/` — all checks must pass
- [x] T089 Final grep: search entire repo for remaining `BookCore`, `Book::CLI`, `book-generator`, `book_config.yml`, `book_state.yml`, `book_metadata.yml`, `--book-dir` references and fix any stragglers
- [x] T090 Run quickstart.md validation: execute the example commands from `specs/009-eidos-terminology/quickstart.md` and verify they work

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies — start immediately
- **Phase 2 (Foundational)**: Depends on Phase 1 — BLOCKS all user stories
- **Phase 3 (US1 - CLI Split)**: Depends on Phase 2
- **Phase 4 (US2 - Migration)**: Depends on Phase 2 + Phase 3 (needs new CLI commands to verify)
- **Phase 5 (US3 - New World)**: Depends on Phase 3 (needs `world new` CLI)
- **Phase 6 (US4 - Produce)**: Depends on Phase 2 + Phase 3 + Phase 4 (needs migrated world + new CLI)
- **Phase 7 (US5 - Publish)**: Depends on Phase 4 + Phase 6 (needs migrated world with content)
- **Phase 8 (Polish)**: Depends on all prior phases

### User Story Dependencies

- **US1 (CLI Split)**: Can start after Phase 2 — no dependencies on other stories
- **US2 (Migration)**: Depends on US1 (needs `world migrate` command from new CLI)
- **US3 (New World)**: Depends on US1 (needs `world new` command). Independent of US2
- **US4 (Produce)**: Depends on US1 + US2 (needs new CLI + migrated world data)
- **US5 (Publish)**: Depends on US1 + US2 (needs new CLI + migrated world data)

### Within Phase 2 (Foundational)

- T008–T034 (namespace renames) are all [P] — can run in parallel
- T035–T037 (require path updates) depend on T008–T034 completion
- T038–T041 (config references) depend on T008 (WorldConfig rename)
- T042–T048 (test updates) depend on T008–T041

### Parallel Opportunities

```
Phase 2 parallel batch 1: T008-T034 (all namespace renames — different files)
Phase 2 parallel batch 2: T035-T041 (require paths + config refs)
Phase 2 parallel batch 3: T042-T047 (test updates)

Phase 3 parallel batch: T050-T055 (CLI class files — different files)
Phase 3 parallel batch: T056-T061 (binary files — different files)
Phase 3 parallel batch: T083-T086 (docs — different files)
```

---

## Parallel Example: Phase 2 Namespace Renames

```bash
# All these can run simultaneously (different files):
Task: "Rename BookCore::WorldConfig in eidos/lib/eidos/world_config.rb"
Task: "Rename BookCore::Configuration in eidos/lib/eidos/configuration.rb"
Task: "Rename BookCore::ChapterGenerator in eidos/lib/eidos/chapter_generator.rb"
Task: "Rename BookCore::StoryBible in eidos/lib/eidos/story_bible.rb"
# ... all T008-T034
```

## Parallel Example: Phase 3 CLI Split

```bash
# All CLI class files can be written simultaneously:
Task: "Create eidos/lib/eidos/cli/world.rb"
Task: "Create eidos/lib/eidos/cli/bible.rb"
Task: "Create eidos/lib/eidos/cli/canon.rb"
Task: "Create eidos/lib/eidos/cli/produce.rb"
Task: "Create eidos/lib/eidos/cli/translate.rb"
Task: "Create eidos/lib/eidos/cli/publish.rb"
```

---

## Implementation Strategy

### MVP First (US1 Only)

1. Complete Phase 1: Setup (directory renames)
2. Complete Phase 2: Foundational (namespace renames + tests passing)
3. Complete Phase 3: US1 — CLI Split
4. **STOP and VALIDATE**: All six binaries respond to `--help`, tests pass
5. This is a functional MVP — old data still works via direct `-w books/...` path

### Incremental Delivery

1. Setup + Foundational → All code renamed, tests pass
2. US1 (CLI Split) → Six working binaries (MVP!)
3. US2 (Migration) → Existing data migrated to `worlds/`
4. US3 (New World) → Fresh world creation works
5. US4 (Produce) → Content generation verified
6. US5 (Publish) → Publishing verified
7. Polish → Docs updated, final validation

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- This is a mechanical refactoring — no behavior changes, only naming
- The monolithic `cli.rb` (~2400 lines) is the hardest part to split — take care with the extract
- Commit after each phase to have safe rollback points
- Run `MOCK_AI=true bundle exec rspec` after every phase as a smoke test
