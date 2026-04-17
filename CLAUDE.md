# AI Agent Rules and Guidelines

This document provides a comprehensive guide for AI agents working with this repository.

---

## Project Overview: One Review Man

This repository contains "One Review Man," an AI‑generated programming comedy IP (storyworld). The project is a monorepo hosting:

- The **Eidos** gem — a reusable Ruby engine, SDK, and CLI for managing storyworlds.
- The **One Review Man** storyworld — content (chapters, characters, comics) produced by Eidos.
- A **Jekyll site** — the generated public reading surface.

The Eidos gem is responsible for:
*   **World Management:** Creating and managing storyworlds (`eidos world` / `bin/world`).
*   **Story Bible:** Managing canonical world lore (`eidos bible` / `bin/bible`).
*   **Canon Versioning:** Tracking and versioning world state with revisions, snapshots, and branches (`eidos canon` / `bin/canon`).
*   **Content Production:** Generating chapters, comics, and illustrations (`eidos produce` / `bin/produce`).
*   **Translation:** Translating content to other languages (`eidos translate` / `bin/translate`).
*   **Publishing:** Assembling content into a Jekyll website (`eidos publish` / `bin/publish`).
*   **SDK-powered browsing:** `eidos chapter` and `eidos character` subcommands built on the Ruby SDK.

The world's content is stored in `worlds/one-review-man/`, and the Jekyll site is built into `site/`.

## Project Structure

```
├── eidos/                     # Core Ruby gem (engine + SDK + CLI)
│   ├── lib/eidos/             # Eidos:: namespace (engine, SDK, CLI classes)
│   ├── lib/eidos/cli/         # Thor-based CLI classes (Main, World, Bible, …)
│   ├── exe/eidos              # Unified `eidos` binary (installed by the gem)
│   ├── bin/world              # Dev-time binaries — one per domain
│   ├── bin/bible              # (identical to `eidos <name>`)
│   ├── bin/canon
│   ├── bin/produce
│   ├── bin/translate
│   ├── bin/publish
│   ├── templates/jekyll/      # Jekyll site template
│   ├── eidos.gemspec          # Gem manifest (installable)
│   └── spec/                  # RSpec tests
├── worlds/one-review-man/     # Storyworld content and configuration
│   ├── content/               # Generated chapters, characters, comics
│   └── data/                  # world_config.yml, story_bible/, settings.yml
└── site/                      # Generated Jekyll site (build target)
```

## Three-Layer Architecture

Eidos is organized as three layers over the same storyworld data:

1. **Engine** — low-level classes (`ChapterGenerator`, `StoryBible`, `LLMService`, `RevisionStore`, `SnapshotStore`, `BranchManager`, `DiffEngine`, …). Use when full control is needed.
2. **SDK** — object-oriented façade (`Eidos::World`, `Chapter`, `Character`, `Location`, `Bible`, `Canon`). Convention over configuration; mutations persist immediately.
3. **CLI** — `Eidos::CLI::Main` Thor router in `lib/eidos/cli/main.rb`, started by `exe/eidos`. Includes both legacy domain subcommands and new SDK-based ones.

## Common Development Commands

#### Setup
```bash
# Docker Setup
docker compose build
docker compose up -d

# Manual Setup
cd eidos
bundle install

# Jekyll site dependencies
cd site
bundle install
```

#### Testing
```bash
# Run all tests from the eidos directory
cd eidos
MOCK_AI=true bundle exec rspec          # 544 examples, 0 failures

# Run a specific test file
MOCK_AI=true bundle exec rspec spec/eidos/sdk_integration_spec.rb
```

#### Content Generation & Management
```bash
# The unified CLI (installed as `eidos` via `gem install eidos`,
# or runnable from the monorepo as `eidos/exe/eidos`):
eidos/exe/eidos world status -w worlds/one-review-man
eidos/exe/eidos chapter list -w worlds/one-review-man
eidos/exe/eidos character show kenji_yamamoto -w worlds/one-review-man

# Cheap smoke-test for a provider/model (auth, reachability, latency).
# Does NOT mutate world files; uses one tiny round-trip (~30 in / ~5 out tokens).
eidos/exe/eidos probe gpt-4o-mini
eidos/exe/eidos probe anthropic/claude-3.5-haiku --provider openrouter --metrics

# Side-by-side model comparison: same prompt, diff the outputs.
# --prompt turns probe into a cheap free-form generator (default max-tokens bumps to 500).
eidos/exe/eidos probe gpt-4o-mini --prompt "Write a haiku about code review." > a.txt
eidos/exe/eidos probe gpt-5-turbo --prompt "Write a haiku about code review." > b.txt
diff a.txt b.txt

# The domain-specific binaries in `eidos/bin/` are equivalent:
eidos/bin/world new -w worlds/one-review-man
eidos/bin/produce chapter -w worlds/one-review-man
MOCK_AI=true eidos/bin/produce chapter -w worlds/one-review-man --auto
eidos/bin/produce prompt [CHAPTER_NUMBER] -w worlds/one-review-man
eidos/bin/translate all ru -w worlds/one-review-man
eidos/bin/translate chapter 1 ru -w worlds/one-review-man
```

#### Website
```bash
# Generate the Jekyll site
eidos/bin/publish jekyll -w worlds/one-review-man --dest site

# Run the Jekyll server locally
cd site
bundle exec jekyll serve   # Site at http://localhost:4000
```

#### SDK from Ruby
```ruby
require 'eidos'

Eidos.configure { |c| c.worlds_path = 'worlds' }

world = Eidos::World.new('one-review-man')
world.status
world.chapters.count
world.bible.characters.map(&:name)
world.canon.current_branch
```

#### Sanity Checks
```bash
./quick_test.sh   # Quick tests
./e2e_test.sh     # Full end-to-end tests
```

## Development Conventions

### Coding Style & Naming
*   **Language:** Ruby 3.3.5.
*   **Indentation:** 2 spaces.
*   **Encoding:** UTF-8.
*   **Magic Comment:** Add `# frozen_string_literal: true` to all Ruby files.
*   **Naming:**
    *   Files: `snake_case.rb`
    *   Classes/Modules: `CamelCase`
    *   RSpec files: `*_spec.rb`
*   **Linting:** Adhere to RuboCop rules defined in `eidos/.rubocop.yml`. Run `bundle exec rubocop` to check.

### Development Modes
*   `MOCK_AI=true`: Use deterministic mock AI responses from `spec/support/mock_responses.yml` instead of making live API calls. Preferred for tests and local iteration.
*   `DEBUG_AI=1` or `--debug` flag: Enable verbose LLM debug logging. Artifacts are saved to `tmp/ai_debug/`.

### Commit & PR Guidelines
*   **Commits:** Use imperative present tense (e.g., "Fix CLI robustness"). Keep commits small and focused.
*   **PRs:** Include a summary, motivation, and verification steps. Note any visual changes with screenshots. Ensure all tests and linters pass before submitting.

### Security
*   **Secrets:** Do not commit API keys or other secrets. Provide LLM keys via environment variables (`OPENAI_API_KEY`, etc.).
*   **Debug Artifacts:** Use the `--debug` flag or `DEBUG_AI=1` environment variable for verbose logging.

## Project Architecture

### Engine (`lib/eidos/`)
*   **`Eidos::ChapterGenerator`** — main content generation engine. Uses dependency injection for LLM, output adapter, and prompt provider.
*   **`Eidos::LLMService`** — abstracted LLM interface. OpenAI implementation included.
*   **`Eidos::StoryBible`** — canonical world lore (characters, locations, facts, relationships, plot threads). Backed by pluggable storage.
*   **`Eidos::RevisionStore`, `SnapshotStore`, `BranchManager`, `DiffEngine`** — canon versioning primitives.
*   **`Eidos::WorldConfig`** — per-world configuration loading.
*   **`Eidos::JekyllAdapter`** — Jekyll output adapter.
*   **`Eidos::Producer`** — content production contract (chapters, comics, illustrations).
*   **`Eidos::PromptProvider`** — prompt templates.

### SDK (also in `lib/eidos/`)
*   **`Eidos::World`** — root object; resolves by name / path / cwd.
*   **`Eidos::Chapter`, `ChapterCollection`** — chapter access from `world.chapters`.
*   **`Eidos::Bible`** — façade over `StoryBible` exposing `#characters`, `#locations`, `#facts`, `#relationships`, `#plot_threads`, `#search`.
*   **`Eidos::Character`, `Location`** — data-hash-backed domain objects with `method_missing` key proxies, `#[]`, `#to_h`, and `#update(changes, reason:)` (persists immediately).
*   **`Eidos::CharacterCollection`, `LocationCollection`** — `Enumerable`, indexable by id.
*   **`Eidos::Canon`** — façade over `RevisionStore`/`SnapshotStore`/`BranchManager`/`DiffEngine`. Methods: `#history`, `#diff`, `#snapshots`, `#create_snapshot`, `#branches`, `#current_branch`, `#create_branch`, `#compare_branches`, `#merge_branch`.
*   **`Eidos.configure` / `Eidos::SdkConfiguration`** — global SDK config (`worlds_path`, `storage_backend`).

### CLI (`lib/eidos/cli/`)
*   **`Eidos::CLI::Main`** — top-level Thor router (`exe/eidos` starts it).
*   **Domain CLIs:** `World`, `Bible`, `Canon`, `Produce`, `Translate`, `Publish` — the existing Thor classes registered as subcommands.
*   **SDK-based CLIs:** `ChapterCli`, `CharacterCli` — thin Thor classes that include `SdkHelpers` and drive the SDK domain objects.
*   **`Eidos::CLI::SdkHelpers`** — `resolve_world(options)` mixin shared by SDK-based subcommands.

### Configuration System
*   **LLM Configuration** is managed in `worlds/*/data/settings.yml`:
    ```yaml
    llm:
      provider: openai
      model: gpt-4o-mini
      temperature: 0.7
      timeout: 240
      default_options:
        max_tokens: 12000
      task_options:
        generation:
          max_tokens: 8000
        translation:
          max_tokens: 12000
    ```
*   **World Detection:** The CLI/SDK resolves a world by absolute path, by name (searching `Eidos.configuration.worlds_path` and `~/.eidos/worlds/`), or by walking up from `pwd` looking for `data/world_config.yml` (or legacy `data/world_metadata.yml`).

### Key Development Patterns
*   **Dependency Injection:** Engine classes accept injectable collaborators via constructor keyword args; used heavily in tests.
*   **Multi-language Support:** Content is generated in English and then translated into other languages using the AI; glossary built from existing translations.
*   **CLI structure:** One unified `eidos` Thor router with both legacy domain subcommands (`world`, `bible`, `canon`, `produce`, `translate`, `publish`) and new SDK-based ones (`chapter`, `character`). Each legacy binary in `eidos/bin/` is a shim for the same Thor class.
*   **Namespace:** All core classes live under `Eidos::` (e.g., `Eidos::ChapterGenerator`, `Eidos::StoryBible`, `Eidos::World`, `Eidos::Canon`).
*   **Storage abstraction:** Character/Location/etc. storage is pluggable (`:yaml_file` default, `:memory` for tests).
*   **Immediate persistence:** SDK mutations like `Character#update` write through to disk immediately.

## Active Technologies
- Ruby 3.3.5, `# frozen_string_literal: true`
- Thor ~> 1.3 (CLI), ruby-openai ~> 7.3 (LLM), tty-prompt ~> 0.23, tty-spinner ~> 0.9, rainbow ~> 3.1, dotenv ~> 3.1
- YAML files on disk for world config / state / story bible / revisions / snapshots; in-memory hashes available for tests

## Recent Changes
- 011-eidos-sdk-and-installable-cli: Unified `eidos` CLI (`exe/eidos`), Ruby SDK (`Eidos::World`, `Chapter`, `Character`, `Location`, `Bible`, `Canon`), `Eidos.configure` global config, installable gem (`gem install eidos`), new SDK-based `eidos chapter` and `eidos character` subcommands.
- 010-storage-abstraction-layer: Storage abstraction for Story Bible (YamlFile + Memory backends).
