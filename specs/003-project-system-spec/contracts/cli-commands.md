# CLI Commands Contract: One Review Man

**Feature**: 003-project-system-spec
**Date**: 2026-03-31

## Global Options

All commands accept:

| Flag | Short | Type | Description |
|------|-------|------|-------------|
| `--book-dir` | `-b` | String | Path to book project directory |

## Commands

### `book init`

Create a new book project.

| Option | Type | Description |
|--------|------|-------------|
| `--quick` | Boolean | Skip interactive wizard, use defaults |

**Output**: Directory structure with `data/`, `content/`, and configuration files.

---

### `book status`

Show project status.

**Output**: Book metadata, generation progress, configuration summary, file counts.

---

### `book version`

Display version number.

**Aliases**: `--version`, `-v`

---

### `book migrate`

Migrate legacy `book_metadata.yml` to split format (`book_config.yml` + `book_state.yml`).

---

### `book generate chapter [NUMBER]`

Generate a chapter.

| Option | Type | Description |
|--------|------|-------------|
| `--content-model` | String | Override AI model |
| `--auto` | Boolean | Skip interactive prompts |
| `--debug` | Boolean | Enable debug logging |

**Output**: Chapter file at `content/chapters/NNN-chapter.md` + character profiles for new characters + story facts stored in Story Bible.

---

### `book generate prompt [NUMBER]`

Display the generation prompt for a chapter without calling the AI.

| Option | Type | Description |
|--------|------|-------------|
| `--content-model` | String | Override AI model |
| `--debug` | Boolean | Enable debug logging |

**Output**: Full prompt text to stdout.

---

### `book generate illustration`

Generate an illustration for chapter content.

| Option | Type | Required | Description |
|--------|------|----------|-------------|
| `--chapter` | Integer | Yes | Chapter number |
| `--content` | String | Yes | Line range (format: "10:17") |
| `--anchor` | Integer | No | Anchor line for placement |
| `--prompt` | String | No | Additional prompt text |
| `--alt-text` | String | No | Alt text for image |
| `--style` | String | No | Style override |
| `--orientation` | String | No | landscape, portrait, or square |
| `--provider` | String | No | openai or openrouter |
| `--content-model` | String | No | Model name |
| `--summarization-model` | String | No | Model for alt text |
| `--debug` | Boolean | No | Debug mode |
| `--dry-run` | Boolean | No | Print parameters only |

**Output**: Image saved to `assets/images/`, embedded in chapter file.

---

### `book translate chapter NUMBER LANG`

Translate a chapter.

| Option | Type | Description |
|--------|------|-------------|
| `--content-model` | String | Override AI model |
| `--debug` | Boolean | Enable debug logging |

**Output**: Translated file at `content/chapters/NNN-chapter.LANG.md`.

---

### `book translate character SLUG LANG`

Translate a character profile.

**Output**: Translated file at `content/characters/SLUG.LANG.md`.

---

### `book translate all LANG`

Translate all chapters and characters to a language.

**Output**: Translated files for every chapter and character.

---

### `book jekyll generate [DEST]`

Generate or update a Jekyll website.

| Argument | Default | Description |
|----------|---------|-------------|
| `DEST` | `./site` | Destination directory |

**Output**: Complete Jekyll site in destination directory.

---

### `book bible list TYPE`

List Story Bible entities.

| Argument | Values | Description |
|----------|--------|-------------|
| `TYPE` | characters, locations, facts, relationships, plot_threads | Entity type |

**Output**: Formatted list with IDs and names.

---

### `book bible show PATH`

View a Story Bible entity.

| Argument | Format | Description |
|----------|--------|-------------|
| `PATH` | Dot notation (e.g., `characters/kenji`) | Entity path |

**Output**: Full YAML representation.

---

### `book bible search QUERY`

Search facts by keyword.

**Output**: Matching facts with category and description.

---

### `book bible context CHAPTER`

Show context for a chapter (characters, locations, facts relevant to it).

**Output**: Contextual summary useful for generation prompts.

---

### `book bible migrate`

Migrate legacy character data to Story Bible format.

---

### `book bible export`

Export Story Bible to Jekyll data files (`characters.yml`, `world.yml`, `story_facts.yml`).

---

### `book canon history ENTITY_TYPE ENTITY_ID`

Show revision history.

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `--branch` | String | main | Branch context |

**Output**: Chronological list of revisions with operation, timestamp, change reason.

---

### `book canon diff ENTITY_TYPE ENTITY_ID REV1 REV2`

Compare two revisions.

**Output**: Field-level diff showing changed fields with before/after values.

---

### `book canon rollback ENTITY_TYPE ENTITY_ID REVISION`

Restore entity to a previous revision.

**Output**: New revision recording the rollback.

---

### `book canon update ENTITY_TYPE ENTITY_ID [FIELD=VALUE...]`

Update a canon entity.

**Output**: Updated entity, new revision, impact analysis triggered.

---

### `book canon impact`

List all impact reports.

---

### `book canon impact_review REPORT_ID ITEM_INDEX STATUS`

Update review status of an affected item.

| Argument | Values |
|----------|--------|
| `STATUS` | approved, needs_revision, pending |

---

### `book branch create NAME`

Create a new branch.

| Option | Type | Description |
|--------|------|-------------|
| `--description` | String | Branch description |

---

### `book branch list`

List all branches with name, parent, status, description.

---

### `book branch checkout NAME`

Switch active branch context.

---

### `book branch compare BRANCH1 BRANCH2`

Compare two branches.

**Output**: Entities only_in_a, only_in_b, conflicts, identical.

---

### `book branch merge SOURCE TARGET`

Merge source branch into target.

**Output**: Merged state + conflict report (if any). Conflicts block merge; author resolves by editing YAML files.

---

### `book branch archive NAME`

Archive a branch (read-only).

---

### `book branch delete NAME`

Delete a branch permanently.

---

### `book changeset create`

Start a new changeset.

**Output**: Changeset ID.

---

### `book changeset add OPERATION ENTITY_TYPE ENTITY_ID [FIELD=VALUE...]`

Add operation to active changeset.

| Argument | Values |
|----------|--------|
| `OPERATION` | create, update, delete |

---

### `book changeset preview`

Preview aggregate impact.

**Output**: Operation count, detected conflicts, preview timestamp.

---

### `book changeset commit`

Commit changeset atomically.

---

### `book changeset discard`

Discard active changeset.

---

### `book agent write [CHAPTER]`

Generate chapter via agent-based writing.

| Option | Short | Type | Description |
|--------|-------|------|-------------|
| `--requirements` | `-r` | String | Additional requirements |
| `--dry_run` | | Boolean | Show plan without writing |
| `--debug` | | Boolean | Enable debug output |
| `--force` | | Boolean | Overwrite existing chapter |

---

### `book reset all`

Reset all content.

| Option | Type | Description |
|--------|------|-------------|
| `--force` | Boolean | Skip confirmation |

---

### `book reset chapters` / `book reset characters` / `book reset data` / `book reset site`

Reset specific content types.

---

### `book reset status`

Show what would be deleted.

## Error Behavior

All commands follow these error conventions:

- **Missing API keys** (without mock mode): Abort with credential error before any AI call.
- **AI provider failure**: Abort with clear error message. No retry, no partial save.
- **Malformed AI output**: Reject entirely with validation error. No files saved.
- **Invalid configuration**: Abort at startup with validation error.
- **Missing source files** (e.g., translate non-existent chapter): Report error and skip.
- **Duplicate chapter** (without `--force`): Refuse and report existing file.
