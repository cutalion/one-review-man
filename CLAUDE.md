# AI Agent Rules and Guidelines

This document provides a comprehensive guide for AI agents working with this repository.

---

## Project Overview: One Review Man

This repository contains "One Review Man," an AI-generated programming comedy IP (storyworld). The project is structured as a monorepo and includes domain-specific CLI tools for world management, content production, and publication. The content is written in English and translated into Russian.

The core of the project is the `eidos` gem, a Ruby engine responsible for:
*   **World Management:** Creating and managing IP worlds (storyworlds) via the `world` CLI.
*   **Story Bible:** Managing canonical world lore via the `bible` CLI.
*   **Canon Versioning:** Tracking and versioning world state via the `canon` CLI.
*   **Content Production:** Generating chapters, comics, and illustrations via the `produce` CLI.
*   **Translation:** Translating content to other languages via the `translate` CLI.
*   **Publishing:** Assembling content into a Jekyll website via the `publish` CLI.

The world's content is stored in `worlds/one-review-man`, and the Jekyll website is in `site/`.

## Project Structure

```
├── eidos/                     # Core Ruby gem and CLI
│   ├── lib/eidos/            # Modular generation engine (Eidos:: namespace)
│   ├── lib/eidos/cli/        # Domain-specific CLI classes
│   ├── bin/world             # World management CLI
│   ├── bin/bible             # Story Bible CLI
│   ├── bin/canon             # Canon versioning CLI
│   ├── bin/produce           # Content production CLI
│   ├── bin/translate         # Translation CLI
│   ├── bin/publish           # Publishing CLI
│   └── templates/jekyll/     # Jekyll site template
│   └── spec/                 # RSpec tests
├── worlds/one-review-man/    # World-specific content and configuration
│   ├── content/             # Generated chapters, characters, comics
│   └── data/                # Metadata, characters, and LLM configuration
└── site/                    # Generated Jekyll site (build target)
```

## Common Development Commands

#### Setup
```bash
# Docker Setup
docker compose build
docker compose up -d

# Manual Setup
cd eidos
bundle install

# Install dependencies for the Jekyll site
cd site
bundle install
```

#### Testing
```bash
# Run all tests from the eidos directory
cd eidos
bundle exec rspec

# Run a specific test file
bundle exec rspec spec/cli_spec.rb

# Run tests with mocked AI (deterministic and offline)
MOCK_AI=true bundle exec rspec
```

#### Content Generation & Management
```bash
# All commands use --world-dir (or -w) to specify the world directory.
# Initialize a new world
eidos/bin/world new -w worlds/one-review-man

# Generate the next chapter
eidos/bin/produce chapter -w worlds/one-review-man

# Generate with auto-acceptance of prompts (for scripting)
MOCK_AI=true eidos/bin/produce chapter -w worlds/one-review-man --auto

# Show the generation prompt without calling the AI
eidos/bin/produce prompt [CHAPTER_NUMBER] -w worlds/one-review-man

# Translate all content to Russian
eidos/bin/translate all ru -w worlds/one-review-man

# Translate a specific chapter
eidos/bin/translate chapter 1 ru -w worlds/one-review-man
```

#### Website
```bash
# Generate the Jekyll site
eidos/bin/publish jekyll -w worlds/one-review-man --dest site

# Run the Jekyll server locally
cd site
bundle exec jekyll serve # Site available at http://localhost:4000
```

#### Sanity Checks
```bash
# Run quick tests
./quick_test.sh

# Run full end-to-end tests
./e2e_test.sh
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
*   `MOCK_AI=true`: Use deterministic mock AI responses from `spec/support/mock_responses.yml` instead of making live API calls. This is the preferred mode for testing.
*   `DEBUG_AI=1` or `--debug` flag: Enable verbose LLM debug logging. Artifacts are saved to `tmp/ai_debug/`.

### Commit & PR Guidelines
*   **Commits:** Use imperative present tense (e.g., "Fix CLI robustness"). Keep commits small and focused.
*   **PRs:** Include a summary, motivation, and verification steps. Note any visual changes with screenshots. Ensure all tests and linters pass before submitting.

### Security
*   **Secrets:** Do not commit API keys or other secrets. Provide LLM keys via environment variables (`OPENAI_API_KEY`, etc.).
*   **Debug Artifacts:** Use the `--debug` flag or `DEBUG_AI=1` environment variable for verbose logging.

## Project Architecture

### Core Components
*   **ChapterGenerator** (`eidos/lib/eidos/chapter_generator.rb`): The main content generation engine. It uses dependency injection for services like the LLM, output adapter, and prompt provider.
*   **LLMService** (`eidos/lib/eidos/llm_service.rb`): An abstracted interface for interacting with AI models. The current implementation uses OpenAI.
*   **JekyllAdapter** (`eidos/lib/eidos/jekyll_adapter.rb`): Formats and writes content for the Jekyll website.
*   **PromptProvider** (`eidos/lib/eidos/prompt_provider.rb`): Manages and provides prompt templates for content generation.

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
*   **Project Detection**: The CLI automatically finds the world root by searching for a `data/world_config.yml` or `data/world_metadata.yml` file.

### Key Development Patterns
*   **Dependency Injection**: Major components are designed to have their dependencies injected via constructor arguments, which is heavily used in tests.
*   **Multi-language Support**: Content is generated in English and then translated into other languages using the AI.
*   **CLI Structure**: The CLI is split into 6 domain-specific binaries: `world`, `bible`, `canon`, `produce`, `translate`, `publish`. Each is a Thor-based CLI with focused commands.
*   **Namespace**: All core classes live under `Eidos::` namespace (e.g., `Eidos::ChapterGenerator`, `Eidos::StoryBible`, `Eidos::WorldConfig`).

## Active Technologies
- Ruby 3.3.5, `frozen_string_literal: true` + Thor ~> 1.3 (CLI), ruby-openai ~> 7.3 (LLM), tty-prompt ~> 0.23, rainbow ~> 3.1
- YAML files on disk (world config, state, story bible)
- Eidos gem (ChapterGenerator, StoryBible, LLMService, WorldConfig, WriterAgent, Producer)
