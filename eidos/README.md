# Eidos

IP world engine for AI-powered content creation. This gem provides the core engine for building and managing storyworlds — generating chapters, managing canon, producing derivative content (comics, illustrations), and publishing to the web.

## Features

- **Pluggable LLM Services**: Support for multiple AI providers (OpenAI, Anthropic, local models)
- **Dependency Injection**: Clean, testable architecture with injectable dependencies
- **Content Production**: AI-powered chapter, comic, and illustration generation
- **Story Bible**: Canonical world lore management with versioning
- **Canon Versioning**: Snapshots, branches, changesets for world state
- **Translation Support**: Multi-language content generation and translation
- **Publishing**: Jekyll static site generation from world content

## CLI Tools

Eidos provides 6 domain-specific CLI binaries:

```bash
world new -w /path/to/my-world --quick    # Initialize a new world
world status -w /path/to/my-world          # Show world status

produce chapter -w /path/to/my-world --auto  # Generate next chapter
produce comic --chapter 1 -w /path/to/my-world  # Generate comic panels

bible list characters -w /path/to/my-world  # List Story Bible entries
canon snapshot create v1 -w /path/to/my-world  # Snapshot canon state

translate all ru -w /path/to/my-world      # Translate all content
publish jekyll -w /path/to/my-world --dest site  # Generate Jekyll site
```

## Quick Start

```bash
cd eidos
bundle install

# Initialize a new world (interactive)
bin/world new -w /path/to/my-world

# Generate next chapter (mock AI for deterministic output)
MOCK_AI=true bin/produce chapter -w /path/to/my-world --auto

# Prepare a Jekyll site
bin/publish jekyll -w /path/to/my-world --dest /path/to/site
```

## Architecture

### Core Components

- **`Eidos::ChapterGenerator`**: Main content generation engine
- **`Eidos::LLMService`**: Abstract LLM service interface and implementations
- **`Eidos::WorldConfig`**: World configuration management
- **`Eidos::StoryBible`**: Canonical world lore
- **`Eidos::Producer`**: Content production contract (chapters, comics)
- **`Eidos::JekyllAdapter`**: Jekyll output adapter

### Dependency Injection

```ruby
generator = Eidos::ChapterGenerator.new(
  llm_service: CustomLLMService.new,
  output_adapter: CustomAdapter.new
)
```

## Configuration

### LLM Configuration

Each world keeps its own LLM config at `data/settings.yml`:

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
      temperature: 0.8
      max_tokens: 8000
    translation:
      temperature: 0.3
      max_tokens: 12000
```

### World Configuration

Stored in `data/world_config.yml` inside the world directory.

## Testing

```bash
cd eidos
MOCK_AI=true bundle exec rspec
```

## Environment Variables

```bash
export OPENAI_API_KEY="your-api-key-here"
export OPENAI_ORG_ID="your-org-id"        # optional
export OPENAI_PROJECT_ID="your-project"   # optional
```

## License

The gem is available as open source under the terms of the MIT License.
