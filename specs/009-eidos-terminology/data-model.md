# Data Model: Eidos Terminology Refactoring

**Feature**: 009-eidos-terminology
**Date**: 2026-04-01

## Configuration Files

### world_config.yml (was: book_config.yml)

No key renames needed — existing keys (`generation:`, `localized:`) are already IP-neutral.

```yaml
---
generation:
  chapter_length_target: "1500-3000 words"
  complexity_level: medium
  character_consistency: true
  main_characters: [...]
  translation_rules: { ... }
  content_rules: { ... }
localized:
  en:
    title: "One Review Man"
    # ...
  ru:
    title: "Ванревьюмэн"
    # ...
```

### world_state.yml (was: book_state.yml)

Top-level `book:` key renamed to `world:`.

```yaml
# BEFORE (book_state.yml)
---
book:
  target_chapters: 50
  current_chapter: 11
status:
  last_generated: '2025-07-15'
  generation_count: 6

# AFTER (world_state.yml)
---
world:
  target_chapters: 50
  current_chapter: 11
status:
  last_generated: '2025-07-15'
  generation_count: 6
```

### world_metadata.yml (was: book_metadata.yml)

Legacy file. If present, `book:` key renamed to `world:`. Structure depends on legacy content (migration handles this).

## Directory Structure

### Before

```
books/
└── one-review-man/
    ├── content/
    │   ├── chapters/
    │   ├── characters/
    │   └── comics/
    ├── data/
    │   ├── book_config.yml
    │   ├── book_state.yml
    │   ├── settings.yml          # unchanged
    │   ├── strings.yml           # unchanged
    │   ├── world.yml             # unchanged
    │   ├── generation_log.yml    # unchanged
    │   └── story_bible/          # unchanged
    ├── assets/
    └── prompts/
```

### After

```
worlds/
└── one-review-man/
    ├── content/
    │   ├── chapters/
    │   ├── characters/
    │   └── comics/
    ├── data/
    │   ├── world_config.yml
    │   ├── world_state.yml
    │   ├── settings.yml          # unchanged
    │   ├── strings.yml           # unchanged
    │   ├── world.yml             # unchanged
    │   ├── generation_log.yml    # unchanged
    │   └── story_bible/          # unchanged
    ├── assets/
    └── prompts/
```

## Namespace Mapping

### Module/Class Renames

| Old | New | File (new path) |
|-----|-----|-----------------|
| `BookCore::BookConfig` | `Eidos::WorldConfig` | `lib/eidos/world_config.rb` |
| `BookCore::Configuration` | `Eidos::Configuration` | `lib/eidos/configuration.rb` |
| `BookCore::ChapterGenerator` | `Eidos::ChapterGenerator` | `lib/eidos/chapter_generator.rb` |
| `BookCore::StoryBible` | `Eidos::StoryBible` | `lib/eidos/story_bible.rb` |
| `BookCore::WriterAgent` | `Eidos::WriterAgent` | `lib/eidos/writer_agent.rb` |
| `BookCore::Producer` | `Eidos::Producer` | `lib/eidos/producer.rb` |
| `BookCore::LLMService` | `Eidos::LLMService` | `lib/eidos/llm_service.rb` |
| `BookCore::JekyllAdapter` | `Eidos::JekyllAdapter` | `lib/eidos/jekyll_adapter.rb` |
| `BookCore::BookContentAdapter` | `Eidos::ContentAdapter` | `lib/eidos/content_adapter.rb` |
| `BookCore::SnapshotStore` | `Eidos::SnapshotStore` | `lib/eidos/snapshot_store.rb` |
| `BookCore::BranchManager` | `Eidos::BranchManager` | `lib/eidos/branch_manager.rb` |
| `BookCore::RevisionStore` | `Eidos::RevisionStore` | `lib/eidos/revision_store.rb` |
| `BookCore::ChangesetManager` | `Eidos::ChangesetManager` | `lib/eidos/changeset_manager.rb` |
| `BookCore::DiffEngine` | `Eidos::DiffEngine` | `lib/eidos/diff_engine.rb` |
| `BookCore::ImpactAnalyzer` | `Eidos::ImpactAnalyzer` | `lib/eidos/impact_analyzer.rb` |
| `BookCore::StoryBibleExporter` | `Eidos::StoryBibleExporter` | `lib/eidos/story_bible_exporter.rb` |
| `BookCore::StoryBibleMigrator` | `Eidos::StoryBibleMigrator` | `lib/eidos/story_bible_migrator.rb` |
| `BookCore::PromptProvider` | `Eidos::PromptProvider` | `lib/eidos/prompt_provider.rb` |
| `BookCore::IllustrationGenerator` | `Eidos::IllustrationGenerator` | `lib/eidos/illustration_generator.rb` |
| `BookUtils` | `Eidos::Utils` (or inline) | `lib/eidos/utils.rb` |
| `WorldUtils` | `Eidos::WorldUtils` | `lib/eidos/world_utils.rb` |
| `PromptUtils` | `Eidos::PromptUtils` | `lib/eidos/prompt_utils.rb` |
| `Book::CLI::Runner` | Split into 6 CLI classes | `lib/eidos/cli/*.rb` |
| `Book::CLI::Helpers` | `Eidos::CLI::Helpers` | `lib/eidos/cli/helpers.rb` |
| `Book::Translator` | `Eidos::Translator` | `lib/eidos/translator.rb` |
| `Book::Reset` | `Eidos::Reset` | `lib/eidos/reset.rb` |

### Exception Classes

| Old | New |
|-----|-----|
| `BookCore::BookConfig::ValidationError` | `Eidos::WorldConfig::ValidationError` |
| `BookCore::BookConfig::NotFoundError` | `Eidos::WorldConfig::NotFoundError` |
| `BookCore::SnapshotNotFoundError` | `Eidos::SnapshotNotFoundError` |
| `BookCore::DuplicateSnapshotError` | `Eidos::DuplicateSnapshotError` |
| `BookCore::SnapshotCorruptError` | `Eidos::SnapshotCorruptError` |
| `BookCore::FrozenSnapshotError` | `Eidos::FrozenSnapshotError` |
| `BookCore::InvalidSnapshotNameError` | `Eidos::InvalidSnapshotNameError` |
| `BookCore::ChangesetConflictError` | `Eidos::ChangesetConflictError` |
| `BookCore::LLMError` | `Eidos::LLMError` |
| `BookCore::ConfigurationError` | `Eidos::ConfigurationError` |
| `BookCore::APIError` | `Eidos::APIError` |

## World Detection

**Detection marker**: `data/world_metadata.yml`

The `resolve_project_root` helper checks for this file to identify a directory as a world. Legacy detection (`book_metadata.yml`, `book_config.yml`) is removed — the migration command must be run first.

Edge case detection: if `book_config.yml` or `book_metadata.yml` is found but `world_metadata.yml` is not, the system reports a migration-needed error.
