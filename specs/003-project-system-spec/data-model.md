# Data Model: One Review Man System

**Feature**: 003-project-system-spec
**Date**: 2026-03-31

## Entities

### Chapter

An episode of the book, stored as Markdown with YAML frontmatter.

**Storage**: `content/chapters/NNN-chapter.md` (English), `NNN-chapter.LANG.md` (translations)

| Field                    | Type     | Required | Description                                              |
|--------------------------|----------|----------|----------------------------------------------------------|
| layout                   | String   | Yes      | Always "chapter"                                         |
| title                    | String   | Yes      | Chapter title including number (e.g., "Chapter 6: ...")  |
| chapter_number           | Integer  | Yes      | Sequential chapter number                                |
| characters               | Array    | Yes      | List of character slugs featured in this chapter         |
| new_characters           | Array    | No       | Character slugs introduced for the first time            |
| summary                  | String   | Yes      | Brief synopsis of chapter events                         |
| programming_themes       | Array    | Yes      | Programming topics referenced (e.g., code_review)        |
| comedy_elements          | Array    | Yes      | Humor types used (e.g., absurd_situation, tech_parody)   |
| word_count               | Integer  | Yes      | Approximate word count                                   |
| difficulty_level         | String   | Yes      | One of: beginner, intermediate, advanced                 |
| one_punch_man_references | Array    | No       | Parody references to source material                     |
| permalink                | String   | Yes      | URL path for Jekyll (e.g., "/chapters/006-chapter/")     |
| generated_date           | String   | Yes      | ISO 8601 date of generation                              |
| status                   | String   | Yes      | One of: generated, reviewed, published                   |
| lang                     | String   | Yes      | Language code (e.g., "en", "ru")                         |

**Identity**: Unique by chapter_number + lang.

**Lifecycle**: generated → reviewed → published (transitions are manual/status-tracked, not enforced).

---

### Character (Story Bible)

A canonical character profile in the Story Bible.

**Storage**: `data/story_bible/characters/{slug}.yml`

| Field                | Type     | Required | Description                                          |
|----------------------|----------|----------|------------------------------------------------------|
| id                   | String   | Yes      | Unique slug (snake_case, e.g., "kenji_yamamoto")     |
| name                 | String   | Yes      | Display name                                         |
| description          | String   | Yes      | Character description                                |
| personality_traits   | Array    | Yes      | List of personality descriptors                      |
| physical_appearance  | Hash     | Yes      | Nested: age, skin_tone, hair, eyes, outfit, distinguishing_features |
| programming_skills   | String   | Yes      | Description of coding abilities                      |
| catchphrase          | String   | No       | Signature phrase                                     |
| backstory            | String   | Yes      | Background history                                   |
| quirks               | String   | No       | Behavioral quirks                                    |
| first_appearance     | Integer  | Yes      | Chapter number of first appearance                   |
| created_date         | String   | Yes      | ISO 8601 date of creation                            |
| role                 | String   | Yes      | Story role (e.g., "protagonist", "rival")            |

**Identity**: Unique by id (slug).

**Lifecycle**: Created during chapter generation or manually. Updated via `canon update` or changesets. May be soft-deleted via revision with operation "delete".

---

### Character (Content Profile)

A Markdown profile file for website display.

**Storage**: `content/characters/{slug}.md` (English), `{slug}.LANG.md` (translations)

| Field          | Type   | Required | Description                              |
|----------------|--------|----------|------------------------------------------|
| layout         | String | Yes      | Always "character"                       |
| title          | String | Yes      | Character display name                   |
| slug           | String | Yes      | Unique identifier matching Story Bible   |
| lang           | String | Yes      | Language code                            |
| permalink      | String | Yes      | URL path for Jekyll                      |

**Body**: Markdown content with character description, traits, and backstory.

**Identity**: Unique by slug + lang.

---

### Location

A place in the story world.

**Storage**: `data/story_bible/locations/{slug}.yml`

| Field       | Type   | Required | Description                   |
|-------------|--------|----------|-------------------------------|
| id          | String | Yes      | Unique slug                   |
| name        | String | Yes      | Display name                  |
| description | String | Yes      | Location description          |
| type        | String | Yes      | Category (e.g., "location")   |

**Identity**: Unique by id.

---

### Fact

A piece of canonical knowledge about the story world.

**Storage**: `data/story_bible/facts.yml` (nested by category)

| Field               | Type    | Required | Description                                   |
|---------------------|---------|----------|-----------------------------------------------|
| category            | String  | Yes      | Top-level grouping (e.g., "events", "world_rules") |
| id                  | String  | Yes      | Unique within category                        |
| name                | String  | Yes      | Short name                                    |
| description         | String  | Yes      | Full description                              |
| chapter_introduced  | Integer | No       | Chapter where first established               |
| rule                | String  | No       | For world_rules: the rule statement           |

**Identity**: Unique by (category, id).

**Storage format**:
```yaml
facts:
  events:
    standup_anomaly:
      name: "Standup Meeting Anomaly"
      description: "..."
      chapter: 6
  world_rules:
    perfect_code:
      rule: "Perfect code can be written instantly"
      description: "..."
```

---

### Relationship

A connection between two characters.

**Storage**: `data/story_bible/relationships.yml`

| Field        | Type    | Required | Description                              |
|--------------|---------|----------|------------------------------------------|
| character1   | String  | Yes      | First character slug                     |
| character2   | String  | Yes      | Second character slug                    |
| type         | String  | Yes      | Relationship type (e.g., "mentor-student") |
| since        | Integer | Yes      | Chapter where established                |
| description  | String  | Yes      | Relationship description                 |

**Identity**: Unique by (character1, character2, type).

---

### Plot Thread

An ongoing or resolved storyline.

**Storage**: `data/story_bible/plot_threads.yml`

| Field                | Type   | Required | Description                            |
|----------------------|--------|----------|----------------------------------------|
| id                   | String | Yes      | Unique thread identifier               |
| title                | String | Yes      | Thread title                           |
| introduced_chapter   | Integer| Yes      | Chapter where introduced               |
| status               | String | Yes      | One of: active, resolved               |
| description          | String | Yes      | Thread description                     |
| characters_involved  | Array  | Yes      | Character slugs involved               |

**Identity**: Unique by id.

**Lifecycle**: active → resolved.

---

### Revision

An immutable snapshot of a canon entity at a point in time.

**Storage**: `data/story_bible/revisions/{entity_type}/{entity_id}/{sequence}.yml`

| Field         | Type     | Required | Description                                              |
|---------------|----------|----------|----------------------------------------------------------|
| sequence      | Integer  | Yes      | Auto-incrementing per entity                             |
| entity_type   | String   | Yes      | One of: character, location, fact, relationship, plot_thread |
| entity_id     | String   | Yes      | Entity identifier                                        |
| snapshot      | Hash     | Yes      | Full entity state at this revision                       |
| timestamp     | DateTime | Yes      | ISO 8601                                                 |
| change_reason | String   | No       | Explanation of the change                                |
| parent_seq    | Integer  | No       | Previous revision (null for first)                       |
| operation     | String   | Yes      | One of: create, update, delete, rollback                 |
| branch        | String   | Yes      | Branch context (default: "main")                         |
| changeset_id  | String   | No       | Batch changeset reference                                |

**Identity**: Unique by (entity_type, entity_id, branch, sequence).

**Lifecycle**: Append-only. Never modified or deleted.

---

### Branch

An independent copy of the story universe.

**Storage**: Metadata in `data/story_bible/branches/_index.yml`. Data in `data/story_bible/branches/{name}/`.

| Field         | Type     | Required | Description                               |
|---------------|----------|----------|-------------------------------------------|
| name          | String   | Yes      | Unique slug identifier                    |
| display_name  | String   | No       | Human-readable name                       |
| parent_branch | String   | Yes      | Parent branch name                        |
| created_at    | DateTime | Yes      | ISO 8601                                  |
| created_from  | Hash     | Yes      | `{branch: name, revision: seq}`           |
| status        | String   | Yes      | One of: active, archived, deleted         |
| archived_at   | DateTime | No       | When archived                             |
| description   | String   | No       | Purpose of this branch                    |

**Identity**: Unique by name.

**Lifecycle**: active → archived → deleted.

**Constraints**:
- "main" branch always exists and cannot be archived or deleted.
- Archived branches are read-only.
- Cannot delete a branch with active children.

---

### Changeset

A batch of canon operations for atomic commit.

**Storage**: `data/changesets/{id}.yml`

| Field          | Type     | Required | Description                            |
|----------------|----------|----------|----------------------------------------|
| id             | String   | Yes      | Unique changeset identifier            |
| branch         | String   | Yes      | Branch context                         |
| created_at     | DateTime | Yes      | ISO 8601                               |
| status         | String   | Yes      | One of: draft, previewed, committed, discarded |
| operations     | Array    | Yes      | List of ChangeOperation                |
| preview_report | Hash     | No       | Preview results (after preview step)   |
| committed_at   | DateTime | No       | When committed                         |

**ChangeOperation** (embedded):

| Field         | Type   | Required | Description                            |
|---------------|--------|----------|----------------------------------------|
| operation     | String | Yes      | One of: create, update, delete         |
| entity_type   | String | Yes      | Entity type                            |
| entity_id     | String | Yes      | Entity identifier                      |
| changes       | Hash   | Yes      | Field changes to apply                 |
| change_reason | String | No       | Explanation                            |

**Lifecycle**: draft → previewed → committed | discarded.

---

### Impact Report

Analysis of content affected by a canon change.

**Storage**: `data/story_bible/impact_reports/{id}.yml`

| Field          | Type     | Required | Description                                        |
|----------------|----------|---------|----------------------------------------------------|
| id             | String   | Yes      | Unique report identifier                           |
| trigger        | Hash     | Yes      | `{entity_type, entity_id, revision_seq, branch}`   |
| created_at     | DateTime | Yes      | When analysis ran                                  |
| branch         | String   | Yes      | Branch context                                     |
| affected_items | Array    | Yes      | List of AffectedItem                               |
| summary        | Hash     | Yes      | `{total, by_severity: {high, medium, low}}`        |

**AffectedItem** (embedded):

| Field         | Type     | Required | Description                             |
|---------------|----------|----------|-----------------------------------------|
| content_type  | String   | Yes      | chapter, translation, character_profile |
| content_path  | String   | Yes      | Relative file path                      |
| references    | Array    | Yes      | Lines/passages mentioning entity        |
| severity      | String   | Yes      | One of: high, medium, low              |
| review_status | String   | Yes      | One of: pending, approved, needs_revision |
| reviewed_at   | DateTime | No       | When last reviewed                      |

---

### Book Configuration

Static project settings.

**Storage**: `data/book_config.yml`

| Section           | Description                                                  |
|-------------------|--------------------------------------------------------------|
| generation        | Chapter length target, complexity, character consistency, main characters |
| translation_rules | Per-language: character mappings, name style, technical terms, custom rules |
| content_rules     | Parody source, humor style, world physics, character dynamics, style guidelines |
| localized         | Per-language: title, subtitle, author, genre, themes         |

---

### Book State

Dynamic project state.

**Storage**: `data/book_state.yml`

| Field              | Type    | Description                          |
|--------------------|---------|--------------------------------------|
| book.target_chapters | Integer | Target total chapters              |
| book.current_chapter | Integer | Last generated chapter number      |
| status.last_generated | String | Date of last generation            |
| status.generation_count | Integer | Total generations performed      |
| status.characters_created | Integer | Characters created in session   |
| status.chapters_written | Integer | Chapters written in session      |

---

### Settings

AI provider and model configuration.

**Storage**: `data/settings.yml` (project), `lib/book_core/defaults/settings.yml` (defaults)

| Section        | Description                                                    |
|----------------|----------------------------------------------------------------|
| llm            | Default provider, model, temperature, timeout, token limits    |
| llm.task_options | Per-task token limits (generation, translation, summarization) |
| providers      | Per-provider: API key env var, base URL                        |
| illustration   | Provider, model, style, orientation for image generation       |
| summarization  | Provider, model for text summarization                         |
| content        | Provider, model for chapter generation                         |
| agent          | Provider, model, token limits for agent writing                |
| translation    | Provider, model for translation                                |

## Entity Relationships

```
Chapter ──references──► Character (via characters[] field)
Chapter ──introduces──► Character (via new_characters[] field)
Chapter ──reveals────► Fact (via story facts extraction)
Character ◄──linked──► Character (via Relationship)
Character ──appears_at──► Location
Plot Thread ──involves──► Character (via characters_involved[])
Revision ──snapshots──► Any canon entity (character, location, fact, etc.)
Branch ──contains──► Canon entities (independent copy)
Changeset ──modifies──► Canon entities (via operations[])
Impact Report ──references──► Revision (via trigger)
Impact Report ──affects──► Chapter/Character files (via affected_items[])
```
