# Eidos SDK & Installable CLI Design

**Date:** 2026-04-16
**Status:** Draft
**Author:** Alexander Glushkov + Claude

## Problem

Eidos is currently a collection of 6 CLI scripts (`world`, `bible`, `canon`, `produce`, `translate`, `publish`) that only work when run from inside the monorepo. It cannot be installed as a gem, has no unified entry point, and cannot be used programmatically from other Ruby applications (e.g., Rails).

## Goals

1. Make Eidos installable via `gem install eidos` with a single `eidos` CLI command.
2. Provide a public Ruby SDK so Eidos can be used as a library in Rails and other Ruby apps.
3. Design the SDK as the core, with the CLI as a thin consumer on top.
4. Keep the system storage-agnostic (disk now, database later).
5. Follow convention over configuration.
6. Migrate incrementally -- everything keeps working at every step.

## Non-Goals

- Extracting separate `eidos-core` and `eidos-cli` gems (future consideration).
- Homebrew or standalone binary distribution (future consideration).
- Moving `eidos/` out of the monorepo (stays as a subdirectory for now).
- Database storage backend (architecture supports it, implementation is later).

---

## Architecture

### Three-Layer Model

```
+------------------------------+
|  CLI Layer (exe/eidos)       |  Thor commands, prints output, writes files.
|  Depends on: SDK             |  One file per top-level command.
+------------------------------+
|  SDK Layer (Eidos::World)    |  Public API. Returns domain objects.
|  Depends on: Engine          |  Zero side effects. No stdout.
+------------------------------+
|  Engine Layer (internals)    |  ChapterGenerator, LLMService,
|  Depends on: nothing above   |  StoryBible, Translator, etc.
|                              |  Receives storage via injection.
+------------------------------+
```

**Dependency rules:**
- Engine never requires CLI or SDK classes.
- SDK never requires CLI classes.
- CLI depends on SDK only -- never reaches into Engine directly.
- All storage is injected, never hardcoded.

---

## SDK Public API

### Configuration

```ruby
Eidos.configure do |c|
  c.worlds_path = "./worlds"             # default: ./worlds
  c.storage_backend = :yaml_file         # default; also :memory, or custom adapter
  c.llm_provider = :openai               # default
  c.llm_api_key = ENV["OPENAI_API_KEY"]  # or read from settings.yml
end
```

**Configuration cascade** (last wins): hardcoded defaults -> `data/settings.yml` -> environment variables -> `Eidos.configure` block -> per-call overrides.

### World Discovery

```ruby
# Explicit path
world = Eidos::World.new("/full/path/to/my-world")

# By name -- searches worlds_path
world = Eidos::World.new("my-world")
# Looks in: ./worlds/my-world, then ~/.eidos/worlds/my-world

# Auto-detect from current directory (walks up looking for data/world_config.yml)
world = Eidos::World.new
```

`worlds_path` is configurable via `Eidos.configure` with a default of `./worlds`.

### Creating a World

```ruby
world = Eidos::World.create("my-new-world",
  title: "My Story",
  genre: "comedy",
  languages: [:en, :ru]
)
```

### World Status

```ruby
world.status
# => {chapters: 11, characters: 10, locations: 9, ...}
```

---

## Domain Object Model

```
Eidos::World
  |-- .chapters            -> ChapterCollection
  |     |-- .generate      -> Chapter
  |     |-- [n]            -> Chapter
  |     |     |-- .translate(:ru)     -> Translation
  |     |     |-- .illustrate(...)    -> Illustration
  |     |     |-- .comic(...)         -> Comic
  |     |     |-- .title, .content, .summary, .characters
  |     |     +-- .translations       -> Hash<Symbol, Translation>
  |     +-- .last, .count, .each
  |
  |-- .bible               -> Bible
  |     |-- .characters    -> CharacterCollection
  |     |     +-- ["kenji"] -> Character
  |     |           |-- .name, .role, ...
  |     |           |-- .update(...)     (immediate persist)
  |     |           |-- .history         -> Array<Revision>
  |     |           +-- .rollback(n)
  |     |-- .locations     -> LocationCollection
  |     |     +-- ["server_room"] -> Location (same interface as Character)
  |     |-- .facts         -> FactCollection
  |     |-- .relationships -> Array<Relationship>
  |     |-- .plot_threads  -> Array<PlotThread>
  |     +-- .search("query") -> Array<SearchResult>
  |
  |-- .canon               -> Canon
  |     |-- .snapshots     -> SnapshotCollection
  |     |     |-- .create("name")
  |     |     +-- ["pre-ch-5"] -> Snapshot
  |     +-- .branches      -> BranchCollection
  |           |-- .create("name", from: "main")
  |           |-- .current  -> Branch
  |           |-- ["what-if"] -> Branch
  |           |     |-- .compare_with("main")
  |           |     |-- .merge(into: "main")
  |           |     +-- .archive
  |           +-- .checkout("name")
  |
  |-- .publish(dest: "site/")  -> PublishResult
  +-- .status                  -> Hash
```

### Design Principles

- **Collections are enumerable and indexable:** `chapters[3]`, `characters.each`, `locations.count`.
- **Mutations persist immediately:** `character.update(role: "lead")` writes through to storage. No `.save` needed.
- **Every object carries its context:** The world reference (storage backend, config) is injected at construction and invisible to the caller.
- **Domain objects return domain objects:** `chapter.translate(:ru)` returns a `Translation`, not a raw hash.
- **No presentation side effects in SDK:** No stdout, no colored output, no interactive prompts. Storage writes happen through the injected backend (that's the SDK's job). The CLI layer handles presentation and user interaction.

---

## Unified CLI

Single `eidos` binary with flat, entity-first top-level commands.

### Command Map

```
eidos world new my-world [--genre comedy --languages en,ru]
eidos world status [-w my-world]

eidos chapter generate [-w my-world]
eidos chapter generate 12 [-w my-world --model gpt-4o]
eidos chapter list [-w my-world]
eidos chapter show 10 [-w my-world]
eidos chapter translate 1 ru [-w my-world]
eidos chapter illustrate 1 --lines 10:17 [-w my-world]
eidos chapter comic 1 --panels 4 --style manga [-w my-world]
eidos chapter prompt 11 [-w my-world]

eidos character list [-w my-world]
eidos character show kenji_yamamoto [-w my-world]
eidos character update kenji_yamamoto role="tech lead" --reason "promoted" [-w my-world]
eidos character history kenji_yamamoto [-w my-world]
eidos character rollback kenji_yamamoto 2 [-w my-world]

eidos location list [-w my-world]
eidos location show server_room [-w my-world]

eidos fact list [-w my-world]
eidos fact search "server room" [-w my-world]

eidos snapshot create pre-ch-5 [-w my-world]
eidos snapshot list [-w my-world]

eidos branch create what-if [--from main] [-w my-world]
eidos branch list [-w my-world]
eidos branch checkout what-if [-w my-world]
eidos branch compare main what-if [-w my-world]
eidos branch merge what-if main [-w my-world]

eidos publish jekyll --dest site/ [-w my-world]
```

### CLI Implementation Pattern

Each CLI command is a thin wrapper (~5-10 lines) that opens a world, calls the SDK, and handles output:

```ruby
# Eidos::CLI::ChapterCLI
desc "generate [NUMBER]", "Generate the next chapter"
def generate(number = nil)
  world = resolve_world(options)
  chapter = world.chapters.generate(number&.to_i, model: options[:model])
  say "Chapter #{chapter.chapter_number}: #{chapter.title}", :green
  say "Words: #{chapter.content.split.length}"
end
```

---

## Gem Packaging

### Gemspec

```ruby
# eidos/eidos.gemspec
Gem::Specification.new do |spec|
  spec.name     = "eidos"
  spec.version  = Eidos::VERSION     # single source of truth
  spec.summary  = "IP world engine for AI-powered content creation"
  spec.bindir   = "exe"              # RubyGems convention
  spec.executables = ["eidos"]       # single binary

  spec.add_dependency "thor", "~> 1.3"
  spec.add_dependency "ruby-openai", "~> 7.3"
  spec.add_dependency "tty-prompt", "~> 0.23"
  spec.add_dependency "rainbow", "~> 3.1"
  spec.add_dependency "tty-spinner", "~> 0.9"
  spec.add_dependency "dotenv", "~> 3.1"
end
```

### Version

Single source of truth in `lib/eidos/version.rb`:

```ruby
module Eidos
  VERSION = "0.2.0"
end
```

### Directory Convention

| Directory | Purpose | Shipped in gem? |
|-----------|---------|-----------------|
| `exe/` | Gem executable (`eidos`) | Yes |
| `lib/` | SDK + Engine + CLI code | Yes |
| `templates/` | Jekyll templates | Yes |
| `bin/` | Dev scripts (old CLIs, kept as shortcuts) | No |
| `spec/` | Tests | No |
| `worlds/` | Sibling in monorepo, not part of gem | No |

### Installation

```bash
gem install eidos
eidos world new my-world
```

Or in a Gemfile:

```ruby
gem "eidos"
```

```ruby
require "eidos"
world = Eidos::World.new("my-world")
```

---

## File Structure

```
eidos/
  exe/
    eidos                              # single entry point

  lib/
    eidos.rb                           # main require, autoload, Eidos.configure

    eidos/
      version.rb                       # Eidos::VERSION
      configuration.rb                 # Eidos::Configuration, Eidos.configure
      world.rb                         # Eidos::World
      bible.rb                         # Eidos::Bible
      canon.rb                         # Eidos::Canon
      result.rb                        # Eidos::Result (base)

      # Domain objects
      chapter.rb                       # Eidos::Chapter
      chapter_collection.rb            # Eidos::ChapterCollection
      character.rb                     # Eidos::Character
      character_collection.rb          # Eidos::CharacterCollection
      location.rb                      # Eidos::Location
      location_collection.rb           # Eidos::LocationCollection
      translation.rb                   # Eidos::Translation
      illustration.rb                  # Eidos::Illustration
      comic.rb                         # Eidos::Comic
      revision.rb                      # Eidos::Revision
      snapshot.rb                      # Eidos::Snapshot
      branch.rb                        # Eidos::Branch

      # CLI (thin wrappers)
      cli/
        main.rb                        # Eidos::CLI::Main (top-level Thor router)
        world_cli.rb
        chapter_cli.rb
        character_cli.rb
        location_cli.rb
        fact_cli.rb
        snapshot_cli.rb
        branch_cli.rb
        publish_cli.rb

      # Engine (existing internals, gradually moved here)
      engine/
        chapter_generator.rb
        llm_service.rb
        prompt_provider.rb
        translator.rb
        illustration_generator.rb
        panel_description_generator.rb
        story_bible.rb
        story_bible_migrator.rb
        story_bible_exporter.rb
        diff_engine.rb
        impact_analyzer.rb
        branch_manager.rb
        changeset_manager.rb
        snapshot_store.rb
        revision_store.rb
        writer_agent.rb
        world_config.rb
        prompt_utils.rb
        file_utils.rb
        jekyll_adapter.rb

      # Storage backends (existing)
      storage/
        factory.rb
        entity_storage.rb
        snapshot_storage.rb
        revision_storage.rb
        yaml_file/...
        memory/...
```

---

## SDK Usage Examples

### Rails Background Job

```ruby
class GenerateChapterJob < ApplicationJob
  def perform(world_name)
    world = Eidos::World.new(world_name)
    chapter = world.chapters.generate
    translation = chapter.translate(:ru)

    ChapterMailer.new_chapter(chapter).deliver_later
  end
end
```

### Rails Controller

```ruby
class ChaptersController < ApplicationController
  def index
    @chapters = current_world.chapters.to_a
  end

  def show
    @chapter = current_world.chapters[params[:id].to_i]
  end

  def generate
    GenerateChapterJob.perform_later(current_world.name)
    redirect_to chapters_path, notice: "Chapter generation started"
  end
end
```

### Console Exploration

```ruby
world = Eidos::World.new("one-review-man")
world.chapters.count          # => 11
world.chapters.last.title     # => "The Sprint Review From Hell"

kenji = world.bible.characters["kenji_yamamoto"]
kenji.role                    # => "senior dev"
kenji.history.length          # => 4
kenji.update(role: "tech lead", reason: "chapter 10 promotion")

world.canon.snapshots.map(&:name)
# => ["pre-villain-arc", "pre-chapter-5"]
```

### CLI Daily Workflow

```bash
eidos world status
eidos character kenji_yamamoto show
eidos character kenji_yamamoto update role="tech lead" --reason "promoted in ch10"
eidos chapter generate
eidos chapter translate 11 ru
eidos chapter comic 11 --panels 4 --style manga
eidos publish jekyll --dest site/
eidos snapshot create pre-villain-arc
```

---

## Migration Strategy

Four phases. Each is a shippable PR. Everything keeps working at every step.

### Phase 1: Plumbing

Establish the installable gem without changing any behavior.

- Create `exe/eidos` with a unified Thor router that delegates to existing CLI classes.
- Move version to `Eidos::VERSION` in `lib/eidos/version.rb`.
- Make `lib/eidos.rb` a proper entry point with requires.
- Update gemspec: `bindir = "exe"`, `executables = ["eidos"]`.
- Add `Eidos.configure` with `Configuration` class (worlds_path, storage_backend, provider settings).
- Old `bin/*` scripts remain functional as dev shortcuts.

**Result:** `gem install eidos` works. `eidos world status` works. No SDK yet.

### Phase 2: Domain Objects (one at a time)

Build SDK facade objects that wrap existing engine classes.

- `Eidos::World` wraps `WorldConfig` + status.
- `Eidos::Bible` + `Eidos::Character` + `Eidos::CharacterCollection` wrap `StoryBible`.
- `Eidos::Location` + `Eidos::LocationCollection` wrap location parts of `StoryBible`.
- `Eidos::Chapter` + `Eidos::ChapterCollection` wrap `ChapterGenerator`.
- `Eidos::Canon` wraps `RevisionStore`, `SnapshotStore`, `BranchManager`.
- `Eidos::Translation` wraps `Translator`.
- `Eidos::Illustration`, `Eidos::Comic` wrap their generators.

Each domain object delegates to the engine internally. No engine rewrite yet.

**Result:** `require 'eidos'; Eidos::World.new("my-world").chapters.generate` works.

### Phase 3: Rewrite CLI on Top of SDK

Replace each CLI command to use domain objects instead of engine classes.

- Create new CLI classes in `cli/` (one per top-level command).
- Each command: open world -> call SDK -> format output.
- Remove old `bin/*` scripts from gem packaging.
- Old scripts can remain in the repo for backwards compatibility during transition.

**Result:** CLI is thin. All logic lives in SDK.

### Phase 4: Engine Cleanup

Gradually improve internals behind the stable SDK facade.

- Move engine classes into `Eidos::Engine::` namespace.
- Remove stdout and file-I/O side effects from engine classes.
- Ensure all storage goes through injected backends.
- Expand storage abstraction to cover all entity types.

**Result:** Engine is clean, fully injectable, ready for a database backend.

---

## Decisions Log

| Decision | Choice | Rationale |
|----------|--------|-----------|
| CLI structure | Single `eidos` binary, flat subcommands | Standard pattern (git, rails). Discoverable. |
| SDK vs Hash API | OOP domain objects | Discoverable, behavior on data, Rails-familiar. |
| Persistence semantics | Immediate (no .save) | Matches current behavior, avoids dirty-tracking complexity. |
| Distribution | RubyGems only (for now) | Target audience has Ruby. Homebrew/standalone can come later. |
| Repo structure | Gem stays in `eidos/` subdirectory | Least disruptive. Can extract later. |
| Migration | 4 incremental phases | No big bang. Everything works at every step. |
| Configuration | Convention cascade with configurable worlds_path | Convention over configuration with escape hatches. |
| Storage | Agnostic, disk by default | Architecture supports DB later without SDK API changes. |
