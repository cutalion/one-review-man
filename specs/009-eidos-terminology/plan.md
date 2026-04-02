# Implementation Plan: Eidos Terminology Refactoring

**Branch**: `009-eidos-terminology` | **Date**: 2026-04-01 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/009-eidos-terminology/spec.md`

## Summary

Rename the project from "book-generator" to "Eidos" — a mechanical refactoring that replaces book-centric terminology with IP/storyworld language across the entire codebase. The monolithic `bin/book` CLI is split into six domain-specific binaries (`world`, `bible`, `canon`, `produce`, `translate`, `publish`). The `BookCore::` and `Book::` namespaces merge into `Eidos::`. Configuration files and YAML keys are renamed. A migration command handles existing data.

## Technical Context

**Language/Version**: Ruby 3.3.5, `frozen_string_literal: true`
**Primary Dependencies**: Thor ~> 1.3 (CLI), ruby-openai ~> 7.3 (LLM), tty-prompt ~> 0.23, rainbow ~> 3.1
**Storage**: YAML files on disk (world config, state, story bible)
**Testing**: RSpec with `MOCK_AI=true` mode
**Target Platform**: Linux/macOS CLI
**Project Type**: CLI tool / Ruby gem
**Performance Goals**: N/A (rename only — no behavior changes)
**Constraints**: Clean break, no backward compatibility. All tests must pass after rename.
**Scale/Scope**: ~46 core Ruby files, ~2400-line CLI file, 1 existing world dataset, ~20 spec files

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Test-First with Mock AI | PASS | All tests updated to new namespaces, must pass with MOCK_AI=true |
| II. Producer Contract | PASS → UPDATE NEEDED | Constitution references `book-generator/bin/book` and `--book-dir` — must be updated as part of FR-010 |
| III. Dependency Injection | PASS | No change to DI patterns — rename only |
| IV. Canon Integrity with Versioned IP | PASS → UPDATE NEEDED | Constitution references `books/*/content/` — must become `worlds/*/content/` |
| V. Security by Default | PASS | No security impact |
| VI. Pluggable AI Services | PASS | No change to service interfaces |
| VII. Separation of Concerns | PASS | CLI split actually improves layer separation — each binary maps to one concern |

**Gate result**: PASS (with documentation updates required as part of the feature itself)

## Project Structure

### Documentation (this feature)

```text
specs/009-eidos-terminology/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/
│   └── cli-commands.md  # CLI contract
└── tasks.md             # Phase 2 output (from /speckit.tasks)
```

### Source Code (repository root)

```text
eidos/                          # was: book-generator/
├── bin/
│   ├── world                   # was: bin/book (world management subset)
│   ├── bible                   # was: book bible *
│   ├── canon                   # was: book canon/snapshot/branch/changeset *
│   ├── produce                 # was: book generate/agent *
│   ├── translate               # was: book translate *
│   └── publish                 # was: book jekyll *
├── lib/
│   ├── eidos.rb                # Main entry point (was: implicit via book/cli)
│   └── eidos/
│       ├── cli/
│       │   ├── helpers.rb      # Shared CLI helpers (resolve_project_root, etc.)
│       │   ├── world.rb        # World CLI class
│       │   ├── bible.rb        # Bible CLI class
│       │   ├── canon.rb        # Canon CLI class (snapshot, branch, changeset subcommands)
│       │   ├── produce.rb      # Produce CLI class
│       │   ├── translate.rb    # Translate CLI class
│       │   ├── publish.rb      # Publish CLI class
│       │   └── version.rb
│       ├── translator.rb       # was: book/translator.rb
│       ├── reset.rb            # was: book_core/reset.rb
│       ├── world_config.rb     # was: book_core/book_config.rb
│       ├── content_adapter.rb  # was: book_core/book_content_adapter.rb
│       ├── utils.rb            # was: book_core/book_utils.rb
│       ├── configuration.rb    # unchanged name
│       ├── chapter_generator.rb
│       ├── story_bible.rb
│       ├── writer_agent.rb
│       ├── llm_service.rb
│       ├── jekyll_adapter.rb
│       ├── prompt_provider.rb
│       ├── snapshot_store.rb
│       ├── branch_manager.rb
│       ├── revision_store.rb
│       ├── changeset_manager.rb
│       ├── diff_engine.rb
│       ├── impact_analyzer.rb
│       ├── producer.rb
│       ├── illustration_generator.rb
│       ├── story_bible_exporter.rb
│       ├── story_bible_migrator.rb
│       ├── world_utils.rb
│       ├── prompt_utils.rb
│       ├── validation_utils.rb
│       ├── env_utils.rb
│       ├── file_utils.rb
│       ├── config.rb
│       ├── models/             # unchanged internal structure
│       ├── producers/          # unchanged internal structure
│       ├── prompts/            # unchanged internal structure
│       ├── defaults/           # unchanged internal structure
│       ├── agent_tools/        # unchanged internal structure
│       └── schemas/            # unchanged internal structure
├── templates/                  # Jekyll templates (unchanged)
├── spec/                       # Tests (namespaces updated)
├── eidos.gemspec               # was: book-generator.gemspec
├── Gemfile
└── README.md

worlds/                         # was: books/
└── one-review-man/
    ├── content/                # unchanged
    ├── data/
    │   ├── world_config.yml    # was: book_config.yml
    │   ├── world_state.yml     # was: book_state.yml (key: book: → world:)
    │   ├── world_metadata.yml  # was: book_metadata.yml (if exists)
    │   ├── settings.yml        # unchanged
    │   ├── strings.yml         # unchanged
    │   ├── world.yml           # unchanged
    │   ├── generation_log.yml  # unchanged
    │   └── story_bible/        # unchanged
    ├── assets/                 # unchanged
    └── prompts/                # unchanged

site/                           # unchanged (publishing target)
```

**Structure Decision**: Single gem (`eidos`) with six CLI entry points. The monolithic `lib/book/cli.rb` (~2400 lines) is split into `lib/eidos/cli/*.rb` (one file per domain binary). Core library files move from `lib/book_core/` to `lib/eidos/`. Both `Book::` and `BookCore::` namespaces merge into `Eidos::`.

## Complexity Tracking

No constitution violations to justify. The CLI split into 6 binaries is explicitly requested and aligns with Principle VII (Separation of Concerns).
