# AI Agent Rules and Guidelines

This document provides a comprehensive guide for AI agents working with this repository.

---

## Project Overview: One Review Man

This repository contains "One Review Man," an AI-generated programming comedy book. The project is structured as a monorepo and includes a command-line interface (CLI) for generating book content, the book's source files, and a Jekyll-based website for publication. The content is written in English and translated into Russian.

The core of the project is the `book-generator` CLI, a Ruby application responsible for:
*   **Chapter Generation:** Creating new chapters using AI models.
*   **Character Generation:** Creating new characters that appear in the story.
*   **Translation:** Translating chapters and character descriptions.
*   **Jekyll Site Generation:** Assembling the book content into a runnable Jekyll website.

The book's content is stored in `books/one-review-man`, and the Jekyll website is in `site/`.

## Project Structure

```
├── book-generator/          # Core Ruby gem and CLI
│   ├── lib/book_core/      # Modular generation engine
│   ├── lib/book/           # Legacy CLI interfaces
│   ├── bin/book            # Main CLI entrypoint (Thor-based)
│   └── templates/jekyll/   # Jekyll site template
│   └── spec/               # RSpec tests
├── books/one-review-man/   # Book-specific content and configuration
│   ├── content/           # Generated chapters and characters
│   └── data/              # Metadata, characters, and LLM configuration
└── site/                  # Generated Jekyll site (build target)
```

## Common Development Commands

#### Setup
```bash
# Install dependencies for the CLI
cd book-generator
bundle install

# Install dependencies for the Jekyll site
cd site
bundle install
```

#### Testing
```bash
# Run all tests from the book-generator directory
cd book-generator
bundle exec rspec

# Run a specific test file
bundle exec rspec spec/cli_spec.rb

# Run tests with mocked AI (deterministic and offline)
MOCK_AI=true bundle exec rspec
```

#### Content Generation & Management
```bash
# All commands can be run from the repo root using the --book-dir (or -b) flag.
# Initialize a new book
book-generator/bin/book init --book-dir books/one-review-man

# Generate the next chapter
book-generator/bin/book generate chapter --model gpt-4o-mini -b books/one-review-man

# Generate with auto-acceptance of prompts (for scripting)
MOCK_AI=true book-generator/bin/book generate chapter -b books/one-review-man --auto

# Show the generation prompt without calling the AI
book-generator/bin/book generate prompt [CHAPTER_NUMBER] -b books/one-review-man

# Translate all content to Russian
book-generator/bin/book translate all ru -b books/one-review-man

# Translate a specific chapter
book-generator/bin/book translate chapter 1 ru -b books/one-review-man
```

#### Website
```bash
# Generate the Jekyll site
book-generator/bin/book jekyll generate --book-dir books/one-review-man --dest site

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
*   **Linting:** Adhere to RuboCop rules defined in `book-generator/.rubocop.yml`. Run `bundle exec rubocop` to check.

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
*   **ChapterGenerator** (`book-generator/lib/book_core/chapter_generator.rb`): The main content generation engine. It uses dependency injection for services like the LLM, output adapter, and prompt provider.
*   **LLMService** (`book-generator/lib/book_core/llm_service.rb`): An abstracted interface for interacting with AI models. The current implementation uses OpenAI.
*   **JekyllAdapter** (`book-generator/lib/book_core/jekyll_adapter.rb`): Formats and writes content for the Jekyll website.
*   **PromptProvider** (`book-generator/lib/book_core/prompt_provider.rb`): Manages and provides prompt templates for content generation.

### Configuration System
*   **LLM Configuration** is managed in `books/*/data/settings.yml`:
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
*   **Project Detection**: The CLI automatically finds the book root by searching for a `data/book_metadata.yml` file.

### Key Development Patterns
*   **Dependency Injection**: Major components are designed to have their dependencies injected via constructor arguments, which is heavily used in tests.
*   **Multi-language Support**: Content is generated in English and then translated into other languages using the AI.
*   **CLI Structure**: The CLI is built with Thor and organized into subcommands (`generate`, `translate`, `jekyll`, `init`, `reset`).