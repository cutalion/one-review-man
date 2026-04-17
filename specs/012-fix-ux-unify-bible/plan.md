# Implementation Plan: Fix UX Bugs and Unify Story Bible

**Branch**: `012-fix-ux-unify-bible` | **Date**: 2026-04-17 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/012-fix-ux-unify-bible/spec.md`

## Summary

Two interlocking workstreams:

1. **First-run UX polish (P1)** — remove alarming diagnostic output and latent bugs that undermine a new user's first `eidos world new` → `eidos produce chapter` run. Specifically: drop auto-migration from `ChapterGenerator`, suppress/rewrite the `CHARACTER_NAME`/`CHARACTER_DESCRIPTION` placeholder path in `prompt_utils.rb`, omit "Not specified" metadata fields, give chapters substantive titles, align interactive defaults with their option lists in `cli/world.rb`, stop asking for language twice, and route `--content-model` to the slot the generator actually reads.

2. **Story Bible as the single canonical lore store (P2, P3)** — make `data/story_bible/` the one and only lore store. Delete all runtime code paths that read or write `data/world.yml` / `data/story_facts.yml` in `chapter_generator.rb`, `story_bible_exporter.rb`, `cli/world.rb`, `cli/helpers.rb`, and `utils.rb`. `ChapterGenerator` reads characters/locations/facts from `StoryBible` instead of the legacy YAMLs. Interactive `world new` offers an optional premise-to-bible seed step (default Yes; skipped by `--quick` or `--no-seed`) that runs a short LLM call and persists any extracted entities with `origin: seed`. The one existing dual-state world (`worlds/one-review-man/`) is cleaned up manually as a one-shot data fix in this PR.

Approach: test-first per constitution principle I — each behavioral change gets an RSpec example in `MOCK_AI=true` mode before the code changes, so regressions light up immediately. Code removal is preferred over code addition wherever possible; the bulk of this feature is deletion.

## Technical Context

**Language/Version**: Ruby 3.3.5, `# frozen_string_literal: true` on every file
**Primary Dependencies**: Thor ~> 1.3 (CLI), ruby-openai ~> 7.3 (LLM), tty-prompt ~> 0.23 (interactive prompts), tty-spinner ~> 0.9, YAML (stdlib)
**Storage**: YAML files under `worlds/<name>/data/story_bible/` (pluggable via `Eidos::Storage` backends: `:yaml_file` default, `:memory` for tests)
**Testing**: RSpec with `MOCK_AI=true`; mocks in `eidos/spec/support/mock_responses.yml`; 544 existing examples must stay green
**Target Platform**: Linux / macOS terminal; invoked via `eidos/exe/eidos` or the domain binaries under `eidos/bin/`
**Project Type**: Ruby gem (library + CLI) in a monorepo with one storyworld at `worlds/one-review-man/` and a Jekyll site at `site/`
**Performance Goals**: Not latency-sensitive; LLM round-trip dominates. Seed extraction step target: ≤ 10 s with default model; hard ceiling that does not block world creation.
**Constraints**: All tests pass in `MOCK_AI=true`. No new runtime dependencies. No new LLM providers. Default model stays `openrouter/google/gemini-3-flash-preview`. Code paths touching `data/world.yml` / `data/story_facts.yml` are removed, not preserved behind flags.
**Scale/Scope**: ~15 files touched; ~700 LOC likely net-negative (more deletion than addition). One storyworld in production use today.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Check | Status |
|---|---|---|
| I. Test-First with Mock AI | Every behavioral change lands with an RSpec example using `MOCK_AI=true`. New seed-extraction path gets a mock response entry. | PASS |
| II. Producer Contract | `ChapterGenerator` continues to implement the producer contract; its inputs and outputs don't change — only its internal data source (story bible instead of world.yml). | PASS |
| III. Dependency Injection | Seed extractor (new) takes `LLMService` and `StoryBible` via constructor. No direct `OpenAI::Client.new` calls in business logic. | PASS |
| IV. Canon Integrity with Versioned IP | **This feature is a direct enforcement of Principle IV.** It eliminates the parallel lore store and makes the Story Bible the actual single source of truth. Canon versioning (`RevisionStore`, `SnapshotStore`) is untouched; every producer run still records its canon version. | PASS (strengthens) |
| V. Security by Default | No secret handling changes. No debug artifact changes. | PASS |
| VI. Pluggable AI Services with Evals | Seed extraction calls `LLMService` (same abstraction used by chapter generation). An eval entry is added to verify seed-extraction output structure on the mocked example. | PASS |
| VII. Separation of Concerns | Engine (StoryBible) stays in charge of canon. Producer (ChapterGenerator) reads through the engine instead of going around it via `data/world.yml`. Publishing (JekyllAdapter) keeps its export contract. `story_bible_exporter.rb` writing `data/world.yml` to the Jekyll `_data` dir is publishing-layer output — allowed and kept, because that's the Jekyll site contract, not the engine's canon store. | PASS |

**Initial gate result**: PASS. No justified violations. No complexity-tracking entries required.

## Project Structure

### Documentation (this feature)

```text
specs/012-fix-ux-unify-bible/
├── plan.md                 # This file
├── research.md             # Phase 0 output
├── data-model.md           # Phase 1 output
├── quickstart.md           # Phase 1 output
├── contracts/              # Phase 1 output
│   ├── cli-surface.md      # CLI command/flag changes
│   ├── sdk-surface.md      # SDK/engine contract
│   └── on-disk-layout.md   # File layout before/after
├── checklists/
│   └── requirements.md     # Already exists
└── tasks.md                # Created by /speckit.tasks (not here)
```

### Source Code (repository root)

Eidos is a Ruby gem living in `eidos/`; a storyworld lives in `worlds/one-review-man/`; the Jekyll build target is `site/`. This feature touches the gem and the real world's data directory; no new top-level directories.

```text
eidos/
├── lib/eidos/
│   ├── chapter_generator.rb          # DROP auto-migration + world.yml/story_facts.yml paths; read via StoryBible
│   ├── prompt_utils.rb               # Placeholder handling: omit section vs interpolate literal tokens
│   ├── story_bible.rb                # (unchanged API; may gain a read helper for generator)
│   ├── story_bible_exporter.rb       # Kept (Jekyll publishing output — not the canonical store)
│   ├── story_bible_migrator.rb       # KEEP only as one-shot CLI utility; NOT called at runtime
│   ├── cli/
│   │   ├── world.rb                  # Interactive prompts: defaults in option lists, no double-ask, seed step, no world.yml write
│   │   ├── helpers.rb                # Drop world.yml from world-detection / listing paths
│   │   └── produce_cli.rb            # (verify no world.yml references)
│   ├── producers/
│   │   └── chapter_producer.rb       # --content-model → writes to content.model (already fixed on main)
│   ├── reset.rb                      # (already fixed on main: content/chapters/)
│   ├── seed_extractor.rb             # NEW: one small class that turns a premise into Bible entries
│   └── utils.rb                      # DROP legacy world.yml loader
├── spec/eidos/
│   ├── chapter_generator_spec.rb     # Remove migration-related expectations; add StoryBible-backed tests
│   ├── cli/
│   │   ├── world_spec.rb             # New: interactive prompts, defaults-in-options, no double-ask, seed flag
│   │   └── produce_spec.rb           # No "Migrated" on fresh world; no CHARACTER_NAME placeholder leak
│   ├── seed_extractor_spec.rb        # NEW
│   └── integration/
│       └── first_run_spec.rb         # End-to-end: world new → produce chapter on a tmp world, assert clean output
└── spec/support/
    └── mock_responses.yml            # Add mock for seed extraction

worlds/one-review-man/
└── data/
    ├── story_bible/                  # Canonical (unchanged)
    ├── world.yml                     # MANUAL CLEANUP: merged into story_bible/, then removed (or renamed .bak-legacy)
    └── story_facts.yml               # MANUAL CLEANUP: ditto
```

**Structure Decision**: Single-project Ruby gem. Existing `eidos/lib/eidos/` and `eidos/spec/eidos/` layout is reused. The only new files are `lib/eidos/seed_extractor.rb`, its spec, and an integration spec for the first-run flow. Everything else is modification or deletion inside the current structure.

## Complexity Tracking

> None. Constitution check passed with no justified violations. This feature is a simplification — it removes a parallel data path rather than adding one. No table entries.
