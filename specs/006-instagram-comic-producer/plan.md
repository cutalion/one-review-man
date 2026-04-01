# Implementation Plan: Instagram Comic Producer

**Branch**: `006-instagram-comic-producer` | **Date**: 2026-04-01 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/006-instagram-comic-producer/spec.md`

## Summary

Build an Instagram comic producer that implements the Producer Contract interface. It reads narrative content (currently book chapters) and character descriptions from the Story Bible, uses the text LLM to generate panel scene descriptions, then calls the image generation service to create Instagram-ready comic panels. Outputs are PNG images with a YAML sidecar file containing metadata and panel descriptions.

## Technical Context

**Language/Version**: Ruby 3.3.5, `frozen_string_literal: true`
**Primary Dependencies**: Thor (CLI), Bundler, BookCore (Producer, LLMService, StoryBible, SnapshotStore)
**Storage**: PNG images + YAML sidecar files on disk
**Testing**: RSpec with `MOCK_AI=true` (deterministic, offline)
**Target Platform**: CLI tool (Linux/macOS)
**Project Type**: CLI / library
**Performance Goals**: 4 panels in under 5 minutes (dominated by image generation API latency)
**Constraints**: Must not modify Producer base or registry code; image generation via injected LLMService
**Scale/Scope**: Second producer in the system; validates Producer Contract extensibility

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Test-First with Mock AI | PASS | All tests run under MOCK_AI=true; LLMService returns mock images in test mode |
| II. Producer Contract | PASS | Implements Producer interface with snapshot + config + output |
| III. Dependency Injection | PASS | LLMService injected; no hardcoded AI provider |
| IV. Canon Integrity | PASS | Reads from snapshot when specified; records canon_version in sidecar |
| V. Security by Default | PASS | API keys via environment variables; no secrets in code |
| VI. Pluggable AI with Evals | PASS | Uses LLMService abstraction for both text and image generation |
| VII. Separation of Concerns | PASS | Producer layer only; no publishing (Instagram posting is Layer 3) |

No violations. Gate passes.

## Project Structure

### Documentation (this feature)

```text
specs/006-instagram-comic-producer/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
│   └── ruby-api.md      # Instagram producer interface contract
└── tasks.md             # Phase 2 output (/speckit.tasks)
```

### Source Code (repository root)

```text
book-generator/
├── lib/book_core/
│   ├── producers/
│   │   ├── chapter_producer.rb          # Existing (feature 005)
│   │   └── instagram_comic_producer.rb  # NEW: Instagram comic producer
│   ├── models/
│   │   ├── comic_panel.rb              # NEW: Panel value object
│   │   └── panel_set.rb               # NEW: Panel set with sidecar I/O
│   ├── character_appearance.rb          # NEW: Extract visual descriptions from Story Bible
│   └── panel_description_generator.rb   # NEW: LLM-driven scene selection
└── spec/
    ├── book_core/
    │   ├── producers/
    │   │   └── instagram_comic_producer_spec.rb  # NEW
    │   ├── models/
    │   │   ├── comic_panel_spec.rb               # NEW
    │   │   └── panel_set_spec.rb                 # NEW
    │   ├── character_appearance_spec.rb           # NEW
    │   └── panel_description_generator_spec.rb    # NEW
    └── ...existing specs...
```

**Structure Decision**: New producer under `producers/`, value objects under `models/`, helper services at `book_core/` level. Follows existing patterns (Snapshot model, SnapshotStore service).

## Complexity Tracking

No violations to justify.
