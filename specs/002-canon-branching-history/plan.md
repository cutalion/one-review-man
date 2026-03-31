# Implementation Plan: Canon Branching and Change History

**Branch**: `002-canon-branching-history` | **Date**: 2026-03-30 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/002-canon-branching-history/spec.md`

## Summary

Add revision tracking, impact analysis, world branching, and batch changesets to the existing `StoryBible` engine. Every canon modification (character, location, fact, relationship, plot thread) records a revision with timestamp and reason. Impact analysis runs automatically in the background when canon changes, flagging dependent content (chapters, translations) for review. Creators can branch worlds into independent copies (nestable tree structure), compare branches, and merge with field-level conflict detection. Batch changesets allow grouping related changes for atomic commit with preview.

## Technical Context

**Language/Version**: Ruby 3.3.5
**Primary Dependencies**: Thor (CLI), Bundler, existing BookCore gem (StoryBible, BookConfig, LLMService, WriterAgent)
**Storage**: YAML files on disk (extending existing `data/story_bible/` structure)
**Testing**: RSpec with `MOCK_AI=true`
**Target Platform**: Linux/macOS CLI
**Project Type**: Library + CLI (both, per spec 001 clarification)
**Performance Goals**: Revision history lookup <5s (500+ revisions), impact report <30s (200+ entries, 50+ content pieces), branch creation <1min (200+ entries)
**Constraints**: Offline-capable, no external database, YAML-based persistence, append-only revision history
**Scale/Scope**: Individual creators or small teams; worlds with up to 1000+ canon entries, 100+ content pieces, dozens of branches

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Test-First with Mock AI | PASS | All new classes will have RSpec tests passing under `MOCK_AI=true`. No live AI calls needed for revision/branching logic. |
| II. CLI as Single Entry Point | PASS | New subcommands added to Thor CLI: `book canon history`, `book canon rollback`, `book canon impact`, `book branch create`, `book branch compare`, `book branch merge`, `book changeset`. |
| III. Dependency Injection | PASS | New services (RevisionStore, ImpactAnalyzer, BranchManager, ChangesetManager) accept collaborators via constructor. StoryBible receives them as injected dependencies. |
| IV. Content Integrity | PASS | All revisions and branches stored under `books/*/data/` as structured YAML. No data lives only in `site/`. Branch data is a source of truth alongside main canon. |
| V. Security by Default | PASS | No new API keys or secrets. Revision data is local YAML. No credentials in debug output. |

**Gate result**: ALL PASS — proceed to Phase 0.

## Project Structure

### Documentation (this feature)

```text
specs/002-canon-branching-history/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
│   ├── cli-commands.md  # CLI interface contract
│   └── library-api.md   # Ruby API contract
└── tasks.md             # Phase 2 output (/speckit.tasks)
```

### Source Code (repository root)

```text
book-generator/
├── lib/
│   └── book_core/
│       ├── story_bible.rb              # Extended: branch-aware, revision-aware
│       ├── revision_store.rb           # NEW: append-only revision storage
│       ├── impact_analyzer.rb          # NEW: dependency analysis + reporting
│       ├── branch_manager.rb           # NEW: create, compare, merge, archive branches
│       ├── changeset_manager.rb        # NEW: batch changes with preview + atomic commit
│       ├── diff_engine.rb              # NEW: field-level diff and conflict detection
│       └── models/
│           ├── revision.rb             # NEW: Revision value object
│           ├── impact_report.rb        # NEW: ImpactReport value object
│           ├── branch.rb               # NEW: Branch value object
│           ├── changeset.rb            # NEW: Changeset value object
│           └── conflict.rb             # NEW: Conflict value object
├── lib/book/
│   └── cli.rb                          # Extended: new subcommands
└── spec/
    ├── revision_store_spec.rb          # NEW
    ├── impact_analyzer_spec.rb         # NEW
    ├── branch_manager_spec.rb          # NEW
    ├── changeset_manager_spec.rb       # NEW
    ├── diff_engine_spec.rb             # NEW
    └── models/
        ├── revision_spec.rb            # NEW
        ├── impact_report_spec.rb       # NEW
        ├── branch_spec.rb              # NEW
        ├── changeset_spec.rb           # NEW
        └── conflict_spec.rb            # NEW

books/one-review-man/
└── data/
    ├── story_bible/
    │   ├── revisions/                  # NEW: revision log per entity
    │   │   ├── characters/             # e.g., kenji_yamamoto/001.yml, 002.yml
    │   │   ├── locations/
    │   │   ├── facts/
    │   │   └── relationships/
    │   └── branches/                   # NEW: branch metadata + snapshots
    │       ├── _index.yml              # Branch tree index
    │       └── {branch-name}/          # Per-branch canon copy
    │           ├── characters/
    │           ├── locations/
    │           ├── facts.yml
    │           └── relationships.yml
    └── changesets/                      # NEW: pending changesets
        └── {changeset-id}.yml
```

**Structure Decision**: Extends the existing single-project layout under `book-generator/`. New classes follow the established `book_core/` module pattern. Data stays under `books/*/data/story_bible/` with new subdirectories for revisions and branches.

## Complexity Tracking

> No constitution violations — no justifications needed.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| (none)    | —          | —                                   |
