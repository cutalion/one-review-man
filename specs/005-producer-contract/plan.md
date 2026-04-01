# Implementation Plan: Producer Contract Interface

**Branch**: `005-producer-contract` | **Date**: 2026-04-01 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/005-producer-contract/spec.md`

## Summary

Extract a common producer interface that all content generators implement. Retrofit ChapterGenerator as the first producer. The interface accepts an IP version reference (canon snapshot), product configuration (opaque options hash), and output location. The existing `book generate chapter` CLI stays unchanged on the surface but routes through the producer contract internally. A minimal in-code registry supports future producer lookup by name.

## Technical Context

**Language/Version**: Ruby 3.3.5, `frozen_string_literal: true`
**Primary Dependencies**: Thor (CLI), Bundler, BookCore gem (ChapterGenerator, StoryBible, LLMService, SnapshotStore)
**Storage**: YAML files on disk (story bible, snapshots, book metadata)
**Testing**: RSpec with `MOCK_AI=true` (deterministic, offline)
**Target Platform**: CLI tool (Linux/macOS)
**Project Type**: CLI / library
**Performance Goals**: N/A (batch content generation, not latency-sensitive)
**Constraints**: Must not break existing 282 passing tests; existing CLI behavior unchanged
**Scale/Scope**: 2 generators today (ChapterGenerator, IllustrationGenerator), Instagram producer next

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Test-First with Mock AI | PASS | All new code tested under MOCK_AI=true |
| II. Producer Contract | PASS | This feature implements the producer contract principle |
| III. Dependency Injection | PASS | Producer base uses DI for services; ChapterGenerator already uses DI |
| IV. Canon Integrity with Versioned IP | PASS | Producers receive snapshot reference; output records canon_version |
| V. Security by Default | PASS | No secrets involved; follows existing patterns |
| VI. Pluggable AI with Evals | PASS | LLMService injection preserved; no new AI dependencies |
| VII. Separation of Concerns | PASS | Producer layer sits between Engine and Publishing per constitution |

No violations. Gate passes.

## Project Structure

### Documentation (this feature)

```text
specs/005-producer-contract/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
│   └── ruby-api.md      # Producer interface contract
└── tasks.md             # Phase 2 output (/speckit.tasks)
```

### Source Code (repository root)

```text
book-generator/
├── lib/book_core/
│   ├── producer.rb              # NEW: Base producer module with built-in registry
│   ├── producer_result.rb       # NEW: Result value object
│   ├── producers/
│   │   └── chapter_producer.rb  # NEW: Wraps/adapts ChapterGenerator
│   ├── chapter_generator.rb     # MODIFIED: internal refactoring for output path flexibility
│   └── ...existing files...
├── lib/book/
│   └── cli.rb                   # MODIFIED: wire generate chapter through producer internally
└── spec/
    ├── book_core/
    │   ├── producer_spec.rb             # NEW: Base interface + registry tests
    │   └── producers/
    │       └── chapter_producer_spec.rb # NEW: Chapter producer tests
    └── chapter_generation_spec.rb       # MODIFIED: verify no regressions
```

**Structure Decision**: New producer files under `book_core/` following existing flat structure. Producer implementations in a `producers/` subdirectory to keep the namespace clean as more producers are added.

## Complexity Tracking

No violations to justify.
