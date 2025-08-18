# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Common Development Commands

### Testing
```bash
cd book-generator
bundle exec rspec                    # Run all tests
bundle exec rspec spec/cli_spec.rb   # Run specific test file
MOCK_AI=true bundle exec rspec       # Run tests with mocked AI (deterministic)
```

### Content Generation
```bash
# Generate next chapter (from book directory or with --book-dir)
book-generator/bin/book generate chapter --model gpt-4o-mini

# Show generation prompt without API call
book-generator/bin/book generate prompt [NUMBER]

# Translate content
book-generator/bin/book translate all ru
book-generator/bin/book translate chapter 1 ru

# Initialize new book
book-generator/bin/book init --book-dir books/new-book

# Generate Jekyll site
book-generator/bin/book jekyll generate --dest site
cd site && bundle exec jekyll serve
```

### Development Modes
- `MOCK_AI=true` - Use deterministic mock responses instead of API calls
- `DEBUG_AI=1` - Enable verbose LLM debug logging, saves artifacts to `tmp/ai_debug/`
- `--debug` flag - Same as DEBUG_AI=1 for CLI commands

## Project Architecture

### Monorepo Structure
```
├── book-generator/          # Core Ruby gem and CLI
│   ├── lib/book_core/      # Modular generation engine
│   ├── lib/book/           # Legacy CLI interfaces
│   ├── bin/book            # Main CLI entrypoint (Thor-based)
│   └── templates/jekyll/   # Jekyll site template
├── books/one-review-man/   # Book-specific content and configuration
│   ├── content/           # Generated chapters and characters
│   ├── data/             # Metadata, character database, generation log
│   └── scripts/          # LLM configuration (llm_config.yml)
└── site/                  # Generated Jekyll site (build target)
```

### Core Components

**ChapterGenerator** (`book-generator/lib/book_core/chapter_generator.rb`)
- Main content generation engine with dependency injection
- Accepts: `llm_service`, `output_adapter`, `prompt_provider`, `project_root`
- Generates structured chapter content with character management

**LLMService** (`book-generator/lib/book_core/llm_service.rb`)
- Abstracted AI service interface (currently OpenAI implementation)
- Supports model-specific parameter handling (gpt-5, o3 series)
- Configurable via `scripts/llm_config.yml`

**JekyllAdapter** (`book-generator/lib/book_core/jekyll_adapter.rb`)
- Output formatting for Jekyll sites
- Handles front matter, file structure, site template setup
- Called by ChapterGenerator for file writing

**PromptProvider** (`book-generator/lib/book_core/prompt_provider.rb`)
- Centralized prompt template management
- Layered lookup: project prompts → core templates
- Injectable dependency for generators

### Configuration System

**LLM Configuration** (`books/*/scripts/llm_config.yml`):
```yaml
provider: openai
model: gpt-4o-mini
temperature: 0.7
default_options:
  max_tokens: 12000
task_options:
  generation:
    max_tokens: 8000
  translation:
    max_tokens: 12000
```

**Project Detection**: CLI automatically finds book root by searching for `data/book_metadata.yml`

### Testing Architecture

- **RSpec** with dependency injection support
- **MockLLMService** for deterministic testing (loads from `spec/support/mock_responses.yml`)
- **Subprocess injection** via RUBYOPT for CLI testing
- **Temporary directory isolation** to avoid system tmp conflicts

### Key Development Patterns

**Dependency Injection**: All major components accept dependencies as constructor kwargs:
```ruby
generator = BookCore::ChapterGenerator.new(
  llm_service: custom_service,
  output_adapter: custom_adapter,
  prompt_provider: custom_provider,
  project_root: '/path/to/book'
)
```

**Zero-Breakage Refactoring**: The codebase follows strict compatibility principles during major refactoring (see `AI_AGENT_INSTRUCTIONS.md` and `REFACTORING_PLAN.md`)

**Multi-language Support**: Content generated in English, then translated using AI with character name consistency via glossaries

## CLI Structure

Main CLI is Thor-based with subcommands:
- `generate` - Content generation (chapters, prompts)
- `translate` - Multi-language translation
- `jekyll` - Site generation and management  
- `init` - Project scaffolding
- `reset` - Content cleanup

All commands support `--book-dir` (or `-b`) for working from any directory.