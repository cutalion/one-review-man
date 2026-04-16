# Eidos

IP world engine for AI‑powered content creation. Eidos is a Ruby gem that provides both a **CLI** and a **Ruby SDK** for building and managing storyworlds: generating chapters, managing canonical lore, versioning canon state, producing derivative content (comics, illustrations), and publishing to the web.

Eidos powers the *One Review Man* project but is usable for any storyworld.

## Install

```bash
gem install eidos
eidos --version   # eidos 0.2.0
```

Or, as a dependency in another project:

```ruby
# Gemfile
gem 'eidos'
```

Ruby ≥ 3.3.0 is required.

## Three layers: Engine → SDK → CLI

Eidos is organized as three thin layers over the same storyworld data:

1. **Engine** — the low-level machinery (`ChapterGenerator`, `StoryBible`, `LLMService`, `RevisionStore`, `SnapshotStore`, `BranchManager`, …). Use when you need full control.
2. **SDK** — an object-oriented façade designed for embedding Eidos inside Rails apps, scripts, or other hosts. Uses convention over configuration; mutations persist immediately.
3. **CLI** — a single `eidos` binary with domain-specific subcommands.

## CLI

```bash
eidos --version
eidos help

eidos world new -w /path/to/my-world           # Initialize a new world
eidos world status -w /path/to/my-world        # Show world status

eidos produce chapter -w /path/to/my-world --auto
eidos produce comic --chapter 1 -w /path/to/my-world

eidos bible list characters -w /path/to/my-world
eidos canon snapshot create v1 -w /path/to/my-world

eidos translate all ru -w /path/to/my-world
eidos publish jekyll -w /path/to/my-world --dest site

# SDK-powered browsing subcommands
eidos chapter list -w /path/to/my-world
eidos chapter show 1 -w /path/to/my-world
eidos character list -w /path/to/my-world
eidos character show kenji_yamamoto -w /path/to/my-world
eidos character update kenji_yamamoto role="senior engineer" --reason "promotion"
```

During development, each subcommand is also exposed as a standalone binary in `bin/` (`bin/world`, `bin/bible`, `bin/canon`, `bin/produce`, `bin/translate`, `bin/publish`). These are identical to `eidos <subcommand>` and exist for convenience inside the monorepo.

## SDK (Ruby API)

```ruby
require 'eidos'

# Optional global configuration — lets you resolve worlds by name.
Eidos.configure do |c|
  c.worlds_path = '/path/to/worlds'
end

world = Eidos::World.new('my-world')       # by name (uses worlds_path)
world = Eidos::World.new('/abs/path')      # by path
world = Eidos::World.new                   # current working directory

world.name         # => "my-world"
world.status       # => {title:, author:, genre:, chapters:, current_chapter:}

# Chapters
world.chapters.count
world.chapters[1].title
world.chapters.each { |ch| puts ch.title }

# Story Bible
hero = world.bible.characters['hero']
hero.name
hero.role               # method_missing proxies data-hash keys
hero.update('role' => 'legendary code reviewer', reason: 'promotion')

office = world.bible.locations['office']
office.description

# Canon versioning
world.canon.current_branch        # => "main"
world.canon.snapshots
world.canon.create_snapshot('v1')
world.canon.branches
```

### Domain objects

| Object | Key methods |
|---|---|
| `Eidos::World` | `#name`, `#status`, `#chapters`, `#bible`, `#canon` |
| `Eidos::Chapter` | `#chapter_number`, `#title`, `#content`, `#summary`, `#characters` |
| `Eidos::ChapterCollection` | `Enumerable`, `#[]`, `#last` |
| `Eidos::Bible` | `#characters`, `#locations`, `#facts`, `#relationships`, `#plot_threads`, `#search`, `#chapter_context` |
| `Eidos::Character` | `#id`, `#name`, `#[]`, `#to_h`, `#update(changes, reason:)`, dynamic getters via `method_missing` |
| `Eidos::Location` | same shape as `Character` |
| `Eidos::CharacterCollection` / `Eidos::LocationCollection` | `Enumerable`, `#[]` |
| `Eidos::Canon` | `#history`, `#diff`, `#snapshots`, `#create_snapshot`, `#branches`, `#current_branch`, `#create_branch`, `#compare_branches`, `#merge_branch` |

Mutations like `Character#update` persist to disk immediately via the underlying `StoryBible` (YAML files today; storage is abstracted for future backends).

## Configuration

### `Eidos.configure`

```ruby
Eidos.configure do |c|
  c.worlds_path = './worlds'     # Where Eidos looks up worlds by name.
  c.storage_backend = :yaml_file # :yaml_file (default) or :memory (tests)
end
```

Reset with `Eidos.reset_configuration!`.

### Per-world LLM settings

`worlds/<name>/data/settings.yml`:

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

Model compatibility: `gpt-5*` / `o3*` need `max_completion_tokens` and may ignore `temperature` — Eidos handles this automatically and retries on specific API errors.

### World configuration

`worlds/<name>/data/world_config.yml` marks a directory as a world. Eidos discovers it either by absolute path, by name (searching `Eidos.configuration.worlds_path` and `~/.eidos/worlds/`), or by walking up from the current directory.

## Dependency injection

Engine classes accept injectable collaborators for testability:

```ruby
generator = Eidos::ChapterGenerator.new(
  llm_service: CustomLLMService.new,
  output_adapter: CustomAdapter.new
)
```

## Testing

```bash
cd eidos
bundle install
MOCK_AI=true bundle exec rspec   # 544 examples, 0 failures
```

`MOCK_AI=true` uses deterministic responses from `spec/support/mock_responses.yml`. `DEBUG_AI=1` (or `--debug` on any CLI) writes request/response artifacts to `tmp/ai_debug/`.

## Environment

```bash
export OPENAI_API_KEY="sk-..."
export OPENAI_ORG_ID="..."         # optional
export OPENAI_PROJECT_ID="..."     # optional
```

## Architecture

### Core components

- **`Eidos::ChapterGenerator`** (`lib/eidos/chapter_generator.rb`) — main content generation engine
- **`Eidos::LLMService`** (`lib/eidos/llm_service.rb`) — abstracted LLM interface; OpenAI implementation included
- **`Eidos::StoryBible`** (`lib/eidos/story_bible.rb`) — canonical world lore (characters, locations, facts, relationships, plot threads)
- **`Eidos::RevisionStore`, `SnapshotStore`, `BranchManager`, `DiffEngine`** — canon versioning
- **`Eidos::WorldConfig`** — per-world configuration loading
- **`Eidos::JekyllAdapter`** (`lib/eidos/jekyll_adapter.rb`) — Jekyll output adapter
- **`Eidos::Producer`** — content production contract (chapters, comics)
- **`Eidos::CLI::Main`** (`lib/eidos/cli/main.rb`) — Thor router for the unified `eidos` command

### Namespace

All classes live under `Eidos::` (e.g. `Eidos::ChapterGenerator`, `Eidos::StoryBible`, `Eidos::World`).

## License

MIT.
