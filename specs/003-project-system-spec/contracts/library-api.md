# Library API Contract: One Review Man

**Feature**: 003-project-system-spec
**Date**: 2026-03-31

## Core Services

### BookCore::ChapterGenerator

Primary engine for AI chapter generation.

```ruby
# Initialize
generator = ChapterGenerator.new(model_override, config: nil, llm_service: nil, prompt_provider: nil)

# Generate next chapter (auto-determines number)
generator.generate_next_chapter(auto_generate: false) → void

# Build prompt for inspection
generator.build_chapter_prompt(chapter_number) → String

# Write chapter file from structured data
generator.write_chapter_file(number, data, character_slugs) → void
```

**Dependencies** (injected via constructor):
- `BookCore::BookConfig` — book metadata
- `BookCore::Configuration` — LLM settings
- `BookCore::LLMService` — AI calls
- `BookCore::PromptProvider` — prompt templates

---

### BookCore::LLMService

Unified interface to AI providers.

```ruby
# Initialize with merged configuration
service = LLMService.new(config)

# Text generation
service.generate_text(prompt:, context:) → String

# Structured chapter generation (returns parsed JSON)
service.generate_chapter_structured(prompt, options) → Hash
# Returns: {title:, summary:, content:, new_characters:, story_facts:}

# Character generation
service.generate_character(character_prompt) → Hash
# Returns: {name:, description:, personality_traits:, ...}

# Translation (structured JSON response)
service.translate_chapter_structured(title, summary, content, target_lang, glossary, metadata) → Hash
# Returns: {title:, summary:, content:}

service.translate_character_structured(name, description, ..., target_lang) → Hash

# Image generation
service.generate_image(prompt, size:, provider:, model:) → String (base64)

# Text summarization
service.summarize_text(text) → String

# Tool-calling (for agent mode)
service.call_llm_with_tools(messages, tools) → Hash

# Task-specific model resolution
service.get_model_for_task(task_type) → String
service.get_provider_for_task(task_type) → String
```

**Mock mode**: When `MOCK_AI=true`, MockLLMService is transparently substituted, returning deterministic canned responses.

---

### BookCore::PromptProvider

Resolves prompt templates with project override support.

```ruby
provider = PromptProvider.new(book_root: Dir.pwd)

# Load template by name
# Search order: {book_root}/prompts/{name} → lib/book_core/prompts/{name}
provider.load(name) → String
```

---

### BookCore::StoryBible

Manages the canonical story universe.

```ruby
bible = StoryBible.new(project_root, revision_store: nil, branch_manager: nil)

# Setup
bible.setup → void  # Initialize directory structure

# Characters
bible.characters → Hash                          # All characters (cached)
bible.get_character(id) → Hash                   # Single character
bible.list_characters(appeared_in: nil) → Array  # Summaries, optionally filtered
bible.save_character(id, data, change_reason:) → void

# Locations
bible.locations → Hash
bible.get_location(id) → Hash
bible.save_location(id, data, change_reason:) → void

# Facts
bible.facts → Hash
bible.get_facts_by_category(category) → Hash
bible.add_fact(category, id, data, change_reason:) → void
bible.search_facts(query) → Array  # Case-insensitive keyword search

# Relationships
bible.relationships → Array
bible.get_relationships_for(character_id) → Array
bible.add_relationship(data, change_reason:) → void

# Plot Threads
bible.plot_threads → Array
bible.add_plot_thread(data, change_reason:) → void
bible.update_plot_thread(id, data, change_reason:) → void
```

---

### BookCore::WriterAgent

Agent-based chapter generation using function calling.

```ruby
agent = WriterAgent.new(llm_service:, story_bible:, project_root:, debug: false)

# Generate chapter (loops up to 20 iterations with tool calls)
agent.generate_chapter(chapter_number, requirements: nil) → Hash
# Returns: {title:, content:, summary:, characters_featured:, new_characters:, new_facts:}
```

**Available tools** (via `AgentTools::StoryBibleTools`):
- `get_character(id)`, `list_characters(appeared_in:)`
- `get_location(id)`, `list_locations()`
- `get_chapter_summaries(count:)`
- `get_plot_threads()`, `get_world_rules()`
- `search_facts(query)`, `get_relationships(character_id)`
- `submit_chapter(title, content, summary, characters_featured, new_characters, new_facts)`

---

### BookCore::BookConfig

Book metadata with language-specific content.

```ruby
# Load from project (handles both split and legacy formats)
config = BookConfig.load_from_project(project_root)

# Access metadata
config.en_metadata → Hash
config.ru_metadata → Hash
config.localized_data(lang) → Hash
config.content_rules → Hash
config.main_characters → Array
config.chapter_length_target → String
config.translation_rules_for(lang) → Hash
config.generation_config → Hash

# Update and persist
config.update_localized(lang, updates) → void
config.save! → void
```

---

### BookCore::Configuration

Layered configuration resolution.

```ruby
# Load and merge: defaults → project → CLI options
config = Configuration.load(project_root, cli_options)
config.resolve → Hash  # Fully merged configuration
```

---

### Book::Translator

Translation orchestration.

```ruby
translator = Translator.new(model_override:, llm_service:, project_root:, config:)

translator.translate_chapter_with_ai(chapter_number, target_lang) → void
translator.translate_character_with_ai(character_slug, target_lang) → void
translator.translate_all_chapters(target_lang) → void
translator.build_name_glossary(target_lang) → Hash
```

---

## Canon Management Services

### BookCore::RevisionStore

Append-only revision history.

```ruby
store = RevisionStore.new(story_bible_root)

store.record(entity_type:, entity_id:, snapshot:, operation:, branch:, change_reason:, changeset_id:) → Revision
store.history(entity_type:, entity_id:, branch:) → Array[Revision]
store.get(entity_type:, entity_id:, sequence:, branch:) → Revision
store.latest(entity_type:, entity_id:, branch:) → Revision
```

---

### BookCore::BranchManager

Branch lifecycle management.

```ruby
manager = BranchManager.new(story_bible_root, revision_store:)

manager.create(name:, from_branch:, at_revision:, description:) → Branch
manager.list(include_archived:) → Array[Branch]
manager.current_branch → String
manager.checkout(name) → void
manager.compare(branch_a, branch_b) → Hash  # {only_in_a, only_in_b, conflicts, identical}
manager.merge(source, target) → Hash  # {merged_state, conflicts}
manager.archive(name) → void
manager.delete(name) → void
```

---

### BookCore::ChangesetManager

Atomic batch operations.

```ruby
manager = ChangesetManager.new(story_bible_root, revision_store:)

manager.create(branch:) → String  # changeset_id
manager.active(branch:) → Changeset
manager.add_operation(changeset_id:, operation:, entity_type:, entity_id:, changes:, change_reason:) → void
manager.preview(changeset_id:) → Hash  # {operations_count, conflicts, preview_timestamp}
manager.commit(changeset_id:, reason:) → void  # Atomic: all or nothing
manager.discard(changeset_id:) → void
```

---

### BookCore::ImpactAnalyzer

Canon change impact analysis.

```ruby
analyzer = ImpactAnalyzer.new(story_bible_root, content_root)

analyzer.analyze(entity_type:, entity_id:, revision:, branch:) → ImpactReport
analyzer.rebuild_index! → void
analyzer.update_review_status(report_id:, item_index:, status:) → void
analyzer.load_report(report_id) → ImpactReport
```

---

### BookCore::DiffEngine

Field-level diff and merge.

```ruby
engine = DiffEngine.new

engine.diff(snapshot_a, snapshot_b) → Hash  # {field → {old, new}}
engine.find_conflicts(base:, ours:, theirs:) → Array[Conflict]
engine.three_way_merge(base:, ours:, theirs:) → Hash  # {merged, conflicts}
```

---

## Supporting Services

### BookCore::JekyllAdapter

Jekyll site generation.

```ruby
adapter = JekyllAdapter.new(project_root, dest)
adapter.setup_project(project_root) → void
adapter.write_chapter(chapter_number, content, metadata) → void
```

---

### BookCore::IllustrationGenerator

Image generation and embedding.

```ruby
generator = IllustrationGenerator.new(llm_service:, project_root:, config:)
generator.generate(chapter_number, prompt, style:, orientation:, anchor_text:, provider:, model:, dry_run:, alt_text:) → void
```

---

### BookCore::StoryBibleExporter

Export to Jekyll data files.

```ruby
exporter = StoryBibleExporter.new(story_bible, project_root)
exporter.export_for_jekyll! → void
exporter.export_to(dest_dir) → void
```

---

### BookCore::Reset

Content reset operations.

```ruby
reset = Reset.new(project_root)
reset.reset_all(force:) → void
reset.reset_chapters(force:) → void
reset.reset_characters(force:) → void
reset.reset_data_files → void
reset.reset_generated_site → void
```
