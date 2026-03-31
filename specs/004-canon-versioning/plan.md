# Implementation Plan: Canon Versioning and Snapshots

**Branch**: `004-canon-versioning` | **Date**: 2026-04-01 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/004-canon-versioning/spec.md`

## Summary

Add a snapshot/tagging system to the Story Bible that captures the full canon state at a point in time with a human-readable name and version number. Snapshots are immutable, stored as copied YAML files (mirroring the existing branch storage pattern), and can be loaded as read-only StoryBible instances. Derivative generation (chapters, illustrations) records which canon snapshot it was produced from, with auto-selection of the latest snapshot as default and explicit `--snapshot` flag for pinning.

## Technical Context

**Language/Version**: Ruby 3.3.5
**Primary Dependencies**: Thor (CLI), YAML (stdlib), FileUtils (stdlib)
**Storage**: Filesystem — YAML files under `data/story_bible/snapshots/`
**Testing**: RSpec with `MOCK_AI=true`
**Target Platform**: Linux/macOS CLI
**Project Type**: CLI + library (BookCore gem)
**Performance Goals**: Snapshot create <5s, list/load <2s for 50+ snapshots
**Constraints**: No external database, no new gem dependencies
**Scale/Scope**: ~20 entity files per snapshot, up to hundreds of snapshots

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Test-First with Mock AI | ✅ Pass | All new classes (SnapshotStore, from_snapshot, CLI) will have RSpec tests using MOCK_AI=true. No live API calls needed — snapshots are pure filesystem operations. |
| II. Producer Contract | ✅ Pass | This feature creates the IP version reference that the Producer Contract requires. ChapterGenerator gains `snapshot:` parameter — first step toward the contract. |
| III. Dependency Injection | ✅ Pass | SnapshotStore injected into StoryBible.from_snapshot and ChapterGenerator. No hard-coded instantiation. |
| IV. Canon Integrity with Versioned IP | ✅ Pass | This feature directly implements Principle IV — canon snapshots with version references in derivatives. |
| V. Security by Default | ✅ Pass | No API keys involved. Snapshot data is the same YAML already on disk. No new credential exposure. |
| VI. Pluggable AI Services | ✅ N/A | No AI service changes in this feature. |
| VII. Separation of Concerns | ✅ Pass | SnapshotStore lives in Engine layer. ChapterGenerator integration is in Producer layer. No publishing changes. |

**Post-design re-check**: All gates still pass. No new violations introduced.

## Project Structure

### Documentation (this feature)

```text
specs/004-canon-versioning/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/
│   ├── cli-commands.md  # CLI contract
│   └── ruby-api.md      # Ruby API contract
└── tasks.md             # Phase 2 output (created by /speckit.tasks)
```

### Source Code (repository root)

```text
book-generator/
├── lib/book_core/
│   ├── snapshot_store.rb           # NEW: Core snapshot CRUD
│   ├── canon_version_reference.rb  # NEW: Version reference helper
│   ├── story_bible.rb              # MODIFIED: Add .from_snapshot
│   ├── chapter_generator.rb        # MODIFIED: Add snapshot: kwarg
│   └── models/
│       └── snapshot.rb             # NEW: Snapshot value object (optional)
├── lib/book/
│   └── cli.rb                      # MODIFIED: Add snapshot subcommand, --snapshot flag
└── spec/book_core/
    ├── snapshot_store_spec.rb      # NEW
    ├── canon_version_reference_spec.rb  # NEW
    ├── story_bible_spec.rb         # MODIFIED: Add from_snapshot tests
    └── chapter_generation_spec.rb  # MODIFIED: Add canon version recording tests
```

**Structure Decision**: All new code lives within the existing `book-generator/` gem structure. SnapshotStore follows the same pattern as RevisionStore and BranchManager. No new projects or packages needed.

## Complexity Tracking

No constitution violations to justify. All new code follows existing patterns.
