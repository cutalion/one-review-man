# Implementation Plan: Storage Abstraction Layer

**Branch**: `010-storage-abstraction-layer` | **Date**: 2026-04-02 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/010-storage-abstraction-layer/spec.md`

## Summary

Introduce a storage abstraction layer with three independent contracts (Entity, Revision, Snapshot) so that Eidos world data can be backed by different storage engines. Extract the current filesystem logic into a YamlFile backend, create an in-memory backend for testing, and make the backend configurable via `settings.yml`. All 388 existing tests must pass unchanged against the YamlFile backend.

## Technical Context

**Language/Version**: Ruby 3.3.5  
**Primary Dependencies**: Thor ~> 1.3 (CLI), ruby-openai ~> 7.3, tty-prompt ~> 0.23, rainbow ~> 3.1  
**Storage**: YAML files on disk (current), in-memory hashes (new for tests)  
**Testing**: RSpec with MOCK_AI=true  
**Target Platform**: Linux (CLI tool)  
**Project Type**: CLI / library gem  
**Performance Goals**: In-memory backend 30%+ faster than file-based for test suite  
**Constraints**: Single-process CLI; no concurrent write access required  
**Scale/Scope**: ~31 files across 3 stores, 13+7+11 instantiation sites to refactor

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Test-First with Mock AI | PASS | Contract tests will run in MOCK_AI=true mode; in-memory backend adds testing capability |
| II. Producer Contract | PASS | Producers are consumers of storage, not affected by internal refactor |
| III. Dependency Injection | PASS | Storage adapters injected via constructor — this feature *strengthens* DI |
| IV. Canon Integrity with Versioned IP | PASS | Snapshot contract preserves versioning; data-based snapshots maintain integrity |
| V. Security by Default | PASS | No secrets involved in storage layer |
| VI. Pluggable AI Services with Evals | N/A | AI services are separate from storage |
| VII. Separation of Concerns | PASS | Storage abstraction lives in Engine layer; clean downward dependencies maintained |

**Post-Phase 1 re-check**: All gates still pass. The three-contract design with StorageFactory aligns with Principle III (DI) and VII (layer separation).

## Project Structure

### Documentation (this feature)

```text
specs/010-storage-abstraction-layer/
├── plan.md              # This file
├── spec.md              # Feature specification
├── research.md          # Phase 0 — decisions and rationale
├── data-model.md        # Phase 1 — entity definitions
├── quickstart.md        # Phase 1 — developer guide
├── contracts/           # Phase 1 — contract definitions
│   ├── entity_storage.md
│   ├── revision_storage.md
│   └── snapshot_storage.md
└── tasks.md             # Phase 2 — task breakdown (via /speckit.tasks)
```

### Source Code (repository root)

```text
eidos/lib/eidos/
├── storage/                        # NEW — storage abstraction layer
│   ├── entity_storage.rb           # Contract module
│   ├── revision_storage.rb         # Contract module
│   ├── snapshot_storage.rb         # Contract module
│   ├── factory.rb                  # StorageFactory
│   ├── yaml_file/                  # File-based backend (extracted from current code)
│   │   ├── entity_storage.rb
│   │   ├── revision_storage.rb
│   │   └── snapshot_storage.rb
│   └── memory/                     # In-memory backend (new)
│       ├── entity_storage.rb
│       ├── revision_storage.rb
│       └── snapshot_storage.rb
├── story_bible.rb                  # MODIFIED — delegates to EntityStorage adapter
├── revision_store.rb               # MODIFIED — becomes thin wrapper or deprecated
├── snapshot_store.rb               # MODIFIED — becomes thin wrapper or deprecated
└── ...

eidos/spec/
├── eidos/storage/                  # NEW — contract conformance tests
│   ├── shared_entity_storage_examples.rb
│   ├── shared_revision_storage_examples.rb
│   ├── shared_snapshot_storage_examples.rb
│   ├── yaml_file/
│   │   ├── entity_storage_spec.rb
│   │   ├── revision_storage_spec.rb
│   │   └── snapshot_storage_spec.rb
│   └── memory/
│       ├── entity_storage_spec.rb
│       ├── revision_storage_spec.rb
│       └── snapshot_storage_spec.rb
└── ...
```

**Structure Decision**: New `storage/` directory under existing `eidos/lib/eidos/` namespace. Follows the existing pattern of organizing by concern. Contract modules define the interface; `yaml_file/` and `memory/` subdirectories hold implementations.

## Complexity Tracking

No constitution violations to justify.
