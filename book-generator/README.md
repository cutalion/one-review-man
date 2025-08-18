# Book Generator Core

The core book generation engine for AI-powered content creation. This library provides the fundamental building blocks for generating book content using Large Language Models (LLMs).

## Features

- **Pluggable LLM Services**: Support for multiple AI providers (OpenAI, Anthropic, local models)
- **Dependency Injection**: Clean, testable architecture with injectable dependencies
- **Chapter Generation**: AI-powered chapter creation with consistent world building
- **Configuration Management**: Flexible YAML-based configuration system
- **Translation Support**: Multi-language content generation and translation
- **Output Adapters**: Pluggable output formats (Jekyll, Hugo, PDF, etc.)

## Installation

This repository is structured as a monorepo. Use the CLI directly from this package without any root Gemfile:

```bash
# From the repo root
book-generator/bin/book --version
# Or if you're in a book directory with the CLI in PATH:
book --version
```

## Quick Start

```bash
# Initialize a new book (interactive)
book init --book-dir /path/to/my-book

# Generate next chapter (mock AI for deterministic output)
MOCK_AI=true book generate chapter --book-dir /path/to/my-book --auto

# Prepare a Jekyll site from the book content
book jekyll generate --book-dir /path/to/my-book --dest /path/to/site
```

## Architecture

### Core Components

- **`BookCore::ChapterGenerator`**: Main content generation engine
- **`BookCore::LLMService`**: Abstract LLM service interface and implementations
- **`BookCore::Config`**: Configuration management
- **`BookCore::JekyllAdapter`**: Jekyll output adapter

### Dependency Injection

The library is designed with dependency injection in mind:

```ruby
# Custom LLM service
class CustomLLMService
  def generate_text(prompt:, context: {})
    # Your custom implementation
  end
end

# Custom output adapter
class CustomAdapter
  def write_chapter(chapter_number, content, metadata = {})
    # Your custom output logic
  end
end

# Inject dependencies
generator = BookCore::ChapterGenerator.new(
  llm_service: CustomLLMService.new,
  output_adapter: CustomAdapter.new
)
```

## Configuration

### LLM Configuration

Each book keeps its own LLM config at `data/settings.yml`:

```yaml
llm:
  provider: openai
  model: gpt-4o-mini
  temperature: 0.7
  timeout: 240
  default_options:
    max_tokens: 12000

  # Task-specific models
  models:
    generation: gpt-4o
    translation: gpt-4o-mini
    chat: gpt-4o-mini

  # Task-specific options
  task_options:
    generation:
      temperature: 0.8
      max_tokens: 8000
    translation:
      temperature: 0.3
      max_tokens: 12000
```

### Book Configuration

Stored in `data/book_metadata.yml` inside the book directory. A minimal file is created by `init`.

```yaml
title: "My Amazing Book"
author: "AI Generated"
description: "A book generated with AI"

world:
  setting: "Modern tech company"
  tone: "Humorous, satirical"
  company: "TechCorp Solutions"

characters:
  - name: "Alex"
    role: "Senior Developer"
    personality: "Perfectionist, sarcastic"
```

## Testing

The library includes comprehensive testing support:

```ruby
# Use mock LLM service for testing
class MockLLMService
  def generate_text(prompt:, context: {})
    "Mock chapter content for testing"
  end
end

# Inject mock in tests
generator = BookCore::ChapterGenerator.new(
  llm_service: MockLLMService.new
)
```

## Environment Variables

Set your API keys via environment variables:

```bash
export OPENAI_API_KEY="your-api-key-here"
export OPENAI_ORG_ID="your-org-id"        # optional
export OPENAI_PROJECT_ID="your-project"   # optional
```

## Development

Run package tests in isolation:

```bash
cd book-generator
bundle exec rspec
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## License

The gem is available as open source under the terms of the MIT License.
