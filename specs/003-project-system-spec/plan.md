# Implementation Plan: One Review Man System Specification

**Branch**: `003-project-system-spec` | **Date**: 2026-03-31 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/003-project-system-spec/spec.md`

**Note**: This is a system-level specification documenting the entire existing project. The system is already implemented. This plan serves as the canonical technical reference for how the system works, what design decisions were made, and how the components fit together. It is the foundation that feature-level specs (001, 002) extend.

## Summary

One Review Man is an AI-powered book generation and publishing system built as a Ruby CLI tool. It generates episodic comedy chapters using AI models, maintains a canonical story universe (Story Bible) with revision tracking and branching, translates content into multiple languages, and publishes the result as a bilingual Jekyll website. The system uses flat-file storage (YAML + Markdown), dependency injection for testability, and a mock AI mode for deterministic offline testing.

## Technical Context

**Language/Version**: Ruby 3.3.5
**Primary Dependencies**: Thor (CLI framework), Bundler (dependency management), OpenAI Ruby client (LLM access)
**Storage**: YAML files and Markdown files on disk — no external database
**Testing**: RSpec with `MOCK_AI=true` for deterministic offline tests
**Target Platform**: Linux/macOS CLI
**Project Type**: Library (`BookCore` gem) + CLI (`book-generator/bin/book`)
**Performance Goals**: Chapter generation with mock AI <30s; Story Bible queries <1s; site generation <60s for 10+ chapters
**Constraints**: Fully offline-capable in mock mode; single-user local tool; no external database; YAML-based persistence throughout
**Scale/Scope**: Individual author; books with 50+ chapters, 20+ characters, dozens of locations/facts/plot threads

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Test-First with Mock AI | PASS | All components are tested under `MOCK_AI=true`. Mock responses in `spec/support/mock_responses.yml`. No live API calls in test suite. |
| II. CLI as Single Entry Point | PASS | All operations exposed via Thor CLI subcommands: `generate`, `translate`, `jekyll`, `bible`, `canon`, `branch`, `changeset`, `agent`, `reset`, `init`, `status`, `migrate`, `version`. All accept `--book-dir`. |
| III. Dependency Injection | PASS | ChapterGenerator, LLMService, WriterAgent, and all Story Bible services accept collaborators via constructor. Test doubles injected in specs. |
| IV. Content Integrity | PASS | Source of truth is `books/*/content/` and `books/*/data/`. Jekyll `site/` is a build artifact regenerated from source. Story Bible is canonical. |
| V. Security by Default | PASS | API keys via environment variables only (`OPENAI_API_KEY`, `OPENROUTER_API_KEY`). Debug artifacts gitignored. No credentials in prompt logs. |

**Gate result**: ALL PASS — proceed to Phase 0.

## Project Structure

### Documentation (this feature)

```text
specs/003-project-system-spec/
├── plan.md              # This file
├── research.md          # Phase 0: design decisions and rationale
├── data-model.md        # Phase 1: complete entity model
├── quickstart.md        # Phase 1: getting started guide
├── contracts/           # Phase 1: interface contracts
│   ├── cli-commands.md  # CLI interface contract
│   └── library-api.md   # Ruby API contract
└── checklists/
    └── requirements.md  # Spec quality checklist
```

### Source Code (repository root)

```text
book-generator/
├── bin/
│   └── book                           # CLI entry point
├── lib/
│   ├── book/
│   │   ├── cli.rb                     # Thor CLI with all subcommands
│   │   ├── cli/version.rb             # Version constant
│   │   └── translator.rb              # Translation orchestration
│   └── book_core/
│       ├── chapter_generator.rb       # AI chapter generation engine
│       ├── llm_service.rb             # Multi-provider LLM interface
│       ├── prompt_provider.rb         # Template resolution (project → core)
│       ├── story_bible.rb             # Canonical universe management
│       ├── story_bible_exporter.rb    # Export to Jekyll data files
│       ├── story_bible_migrator.rb    # Legacy data migration
│       ├── book_config.rb             # Book metadata (config + state)
│       ├── configuration.rb           # Settings resolution (layered merge)
│       ├── writer_agent.rb            # Agent-based chapter generation
│       ├── jekyll_adapter.rb          # Jekyll site generation
│       ├── illustration_generator.rb  # Image generation + embedding
│       ├── revision_store.rb          # Append-only revision history
│       ├── branch_manager.rb          # Branch create/compare/merge
│       ├── changeset_manager.rb       # Atomic batch operations
│       ├── impact_analyzer.rb         # Canon change impact analysis
│       ├── diff_engine.rb             # Field-level diff + 3-way merge
│       ├── reset.rb                   # Content reset operations
│       ├── models/
│       │   ├── revision.rb            # Revision value object
│       │   ├── branch.rb              # Branch value object
│       │   ├── changeset.rb           # Changeset + ChangeOperation
│       │   ├── impact_report.rb       # ImpactReport + AffectedItem
│       │   └── conflict.rb            # Merge conflict value object
│       ├── agent_tools/
│       │   └── story_bible_tools.rb   # Tool definitions for WriterAgent
│       ├── prompts/
│       │   ├── chapter_prompts.txt    # Chapter generation template
│       │   ├── new_character_creation_prompt.txt
│       │   ├── clarity_improvement_prompt.txt
│       │   ├── humor_improvement_prompt.txt
│       │   ├── consistency_improvement_prompt.txt
│       │   └── general_improvement_prompt.txt
│       ├── defaults/
│       │   └── settings.yml           # Default LLM/provider config
│       ├── env_utils.rb               # Environment variable helpers
│       ├── book_utils.rb              # File loading/saving utilities
│       ├── world_utils.rb             # World data resolution
│       ├── prompt_utils.rb            # Prompt building helpers
│       ├── validation_utils.rb        # Config/structure validation
│       ├── file_utils.rb              # Safe file operations
│       └── book_content_adapter.rb    # Content format adapter
├── templates/
│   └── jekyll/                        # Jekyll site template
│       ├── _config.yml
│       ├── _layouts/
│       ├── _includes/
│       ├── _data/
│       ├── _sass/
│       ├── index.md, index.ru.md
│       ├── characters.md, characters.ru.md
│       ├── Gemfile
│       └── 404.html
├── spec/
│   ├── spec_helper.rb
│   ├── support/
│   │   ├── mock_llm_service.rb        # Deterministic test double
│   │   ├── inject_mock_llm.rb         # Auto-injection via RUBYOPT
│   │   └── mock_responses.yml         # Canned AI responses
│   └── *_spec.rb                      # Unit/integration tests
├── Gemfile, Gemfile.lock
├── .rubocop.yml
└── book-generator.gemspec

books/one-review-man/
├── data/
│   ├── book_config.yml                # Static metadata + generation rules
│   ├── book_state.yml                 # Dynamic state (progress, counts)
│   ├── settings.yml                   # LLM provider/model config
│   ├── characters.yml                 # Exported character data (bilingual)
│   ├── world.yml                      # Exported world data
│   ├── story_facts.yml                # Exported facts
│   ├── strings.yml                    # UI/template strings (bilingual)
│   ├── generation_log.yml             # Chapter generation history
│   └── story_bible/
│       ├── characters/*.yml           # Canonical character profiles
│       ├── locations/*.yml            # Canonical locations
│       ├── facts.yml                  # Canonical facts by category
│       ├── relationships.yml          # Character relationships
│       ├── plot_threads.yml           # Active/resolved plot threads
│       ├── revisions/                 # Append-only revision history
│       ├── branches/                  # Branch metadata + data copies
│       ├── impact_reports/            # Impact analysis results
│       └── changesets/                # Pending batch changesets
├── content/
│   ├── chapters/
│   │   ├── NNN-chapter.md             # English chapters
│   │   └── NNN-chapter.ru.md          # Russian translations
│   └── characters/
│       ├── slug.md                    # English character profiles
│       └── slug.ru.md                 # Russian translations
├── prompts/                           # Project-specific prompt overrides
└── assets/images/                     # Generated illustrations

site/                                  # Generated Jekyll site (build artifact)
```

**Structure Decision**: Follows the established single-project layout. `book-generator/` contains the Ruby gem (library + CLI). `books/one-review-man/` contains content and data for the specific book project. `site/` is a build artifact regenerated from source.

## Complexity Tracking

> No constitution violations — no justifications needed.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| (none)    | —          | —                                   |
