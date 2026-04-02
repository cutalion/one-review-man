# Feature Specification: Eidos Terminology Refactoring

**Feature Branch**: `009-eidos-terminology`
**Created**: 2026-04-01
**Status**: Draft
**Input**: User description: "Rename project from book-generator to Eidos. Redefine all terminology from book-centric to IP/storyworld language. New gem name: eidos. Domain-specific CLI binaries (world, bible, canon, produce, translate, publish). BookCore namespace becomes Eidos namespace. books/ becomes worlds/."

## Clarifications

### Session 2026-04-01

- Q: Do YAML keys inside config files also rename (e.g., `book:` → `world:`)? → A: Yes, full key rename — both file names and internal YAML keys change to match new terminology.
- Q: Which file is the canonical world detection marker? → A: `world_metadata.yml` — sole detection marker, direct successor to `book_metadata.yml`.
- Q: Where does the agent-based writer command (`bible write`) go in the new multi-binary CLI? → A: Under `produce` — all content creation commands (direct and agent-driven) live under `produce`.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Use Domain-Specific CLI Commands (Priority: P1)

An IP world creator uses domain-named CLI binaries to manage their storyworld. Instead of a single `book` command with deeply nested subcommands, each domain area has its own binary that reads naturally: `world new`, `bible list characters`, `canon snapshot create`, `produce chapter`, `translate all ru`, `publish jekyll`. This makes the CLI self-documenting and allows each domain tool to evolve independently.

**Why this priority**: The CLI is the primary user interface. If commands don't map to the new mental model (IP/storyworld, not book), the terminology change has no user-visible impact.

**Independent Test**: Run each domain binary with `--help` and verify it responds with commands relevant to its domain. Execute a representative command from each binary against a test world.

**Acceptance Scenarios**:

1. **Given** Eidos is installed, **When** the creator runs `world --help`, **Then** the output lists world management commands (new, init, config) with no references to "book".
2. **Given** an existing world at `worlds/one-review-man`, **When** the creator runs `bible list characters -w worlds/one-review-man`, **Then** the story bible lists all characters from that world.
3. **Given** an existing world, **When** the creator runs `produce chapter -w worlds/one-review-man`, **Then** a new chapter is generated and saved under the world's content directory.
4. **Given** an existing world, **When** the creator runs `canon snapshot create v1 -w worlds/one-review-man`, **Then** a canon snapshot is created, identical in behavior to the previous system but using the new command structure.

---

### User Story 2 - Migrate Existing World Data (Priority: P1)

A creator with existing content under the old `books/` structure needs their data to work seamlessly after the rename. Configuration files (`book_config.yml`, `book_state.yml`, `book_metadata.yml`) are renamed to their `world_*` equivalents. The directory `books/` becomes `worlds/`. All internal references update accordingly.

**Why this priority**: Without data continuity, existing users cannot adopt the new terminology. This is tied with P1 because it blocks all other functionality for existing projects.

**Independent Test**: Take the existing `books/one-review-man` directory, run the migration, and verify all CLI commands work against the migrated `worlds/one-review-man` with no data loss.

**Acceptance Scenarios**:

1. **Given** a project with `books/one-review-man/data/book_config.yml`, **When** the migration runs, **Then** the file exists at `worlds/one-review-man/data/world_config.yml` with identical content.
2. **Given** a project with `books/one-review-man/data/book_state.yml`, **When** the migration runs, **Then** the file exists at `worlds/one-review-man/data/world_state.yml` with identical content.
3. **Given** a project with content under `books/one-review-man/content/`, **When** the migration runs, **Then** all content files exist under `worlds/one-review-man/content/` with unchanged content.
4. **Given** a migrated world, **When** the creator runs any CLI command against it, **Then** the command succeeds with no errors about missing files or invalid paths.

---

### User Story 3 - Initialize a New World with New Terminology (Priority: P2)

A creator starts a fresh IP world project. The `world new` command scaffolds the world directory structure using the new naming conventions (`world_config.yml`, `world_state.yml`, story bible under `data/story_bible/`). No references to "book" appear in any generated files, prompts, or output messages.

**Why this priority**: New project creation is the first touchpoint for new users and sets expectations. Depends on the CLI structure from US1.

**Independent Test**: Run `world new` to create a fresh world, inspect all generated files and verify no "book" terminology appears in file names, YAML keys, or content.

**Acceptance Scenarios**:

1. **Given** an empty directory, **When** the creator runs `world new -w worlds/my-world`, **Then** the directory structure is created with `world_config.yml`, `world_state.yml`, and `data/story_bible/`.
2. **Given** a newly created world, **When** the creator inspects all generated YAML files, **Then** no keys or values reference "book" (except where "book" is a valid content format name, e.g., a book producer).
3. **Given** a newly created world, **When** the creator runs `bible list characters -w worlds/my-world`, **Then** the command succeeds (returning empty results for a new world).

---

### User Story 4 - Produce Content Using the New Structure (Priority: P2)

A creator generates content (chapters, comics) using `produce` commands that work against worlds. The producer system reads from the renamed configuration files and writes output to the same content directories. All AI prompts and internal messaging use IP/storyworld language.

**Why this priority**: Content production is the core value of the tool. Depends on correct file resolution from US2/US3.

**Independent Test**: Generate a chapter and a comic panel in a world, verify the output files are correct and all log/debug output uses storyworld terminology.

**Acceptance Scenarios**:

1. **Given** a configured world, **When** the creator runs `produce chapter -w worlds/one-review-man`, **Then** a chapter is generated and saved to `worlds/one-review-man/content/chapters/`.
2. **Given** a configured world, **When** the creator runs `produce comic -w worlds/one-review-man`, **Then** comic panels are generated and saved to `worlds/one-review-man/content/comics/`.
3. **Given** any produce command, **When** the creator observes console output, **Then** all status messages use "world" terminology (e.g., "Generating chapter for world 'One Review Man'..." not "Generating chapter for book...").

---

### User Story 5 - Publish World Content (Priority: P3)

A creator publishes world content to a Jekyll site using `publish jekyll`. The publishing system reads from the new world directory structure and generates the site correctly.

**Why this priority**: Publishing is downstream of content production. It depends on all prior stories but is the final step in the pipeline.

**Independent Test**: Run `publish jekyll` against a world with existing content and verify the generated site is functionally identical to what the old system produced.

**Acceptance Scenarios**:

1. **Given** a world with generated content, **When** the creator runs `publish jekyll -w worlds/one-review-man --dest site`, **Then** the Jekyll site is generated with all chapters, characters, and assets.
2. **Given** a generated Jekyll site, **When** the creator inspects the site data files, **Then** metadata references use "world" terminology where appropriate.

---

### Edge Cases

- What happens when a creator has both `books/` and `worlds/` directories? The system MUST only look in `worlds/`. The old `books/` directory is ignored unless explicitly migrated.
- What happens when config files use old names (`book_config.yml`) in a `worlds/` directory? The system MUST report a clear error message suggesting migration, not silently fail.
- How does the system handle partial migration (e.g., directory renamed but config files not)? The system MUST detect inconsistencies and report them with actionable guidance.
- What happens when `--world-dir` points to a path containing `book_metadata.yml` but not `world_metadata.yml`? The system MUST report that the world needs migration and suggest the migration command.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The gem MUST be named `eidos` and all Ruby source files MUST use the `Eidos::` namespace instead of `BookCore::` and `Book::`.
- **FR-002**: The system MUST provide separate CLI binaries for each domain: `world`, `bible`, `canon`, `produce`, `translate`, `publish`.
- **FR-003**: Each CLI binary MUST accept `--world-dir` (short: `-w`) to specify the target world directory. The old `--book-dir` flag MUST NOT exist.
- **FR-004**: The top-level content directory MUST be `worlds/` instead of `books/`. The system MUST detect worlds by looking for `data/world_metadata.yml` — this is the sole canonical detection marker (successor to `book_metadata.yml`).
- **FR-005**: Configuration files MUST be renamed: `book_config.yml` to `world_config.yml`, `book_state.yml` to `world_state.yml`, `book_metadata.yml` to `world_metadata.yml`. YAML keys inside these files MUST also be renamed to match (e.g., top-level `book:` key becomes `world:`, `book_title` becomes `world_title`). The migration tool MUST rewrite both file names and internal keys.
- **FR-006**: All user-facing output (console messages, error messages, help text) MUST use IP/storyworld terminology. No references to "book" except where "book" is a valid content format (e.g., a book is one type of product a producer can create).
- **FR-007**: The `StoryBible` class and `data/story_bible/` directory MUST retain their current names.
- **FR-008**: Content-type-specific names (`ChapterGenerator`, `ChapterProducer`, `content/chapters/`, `content/comics/`) MUST retain their current names, as these describe the content format, not the project paradigm.
- **FR-013**: The agent-based writer (currently `bible write` using `WriterAgent`) MUST be moved under the `produce` binary. All content creation commands — direct generation and agent-driven authoring — MUST live under `produce`.
- **FR-009**: All existing automated tests MUST pass after the refactoring, with test code updated to use new names, paths, and namespaces.
- **FR-010**: The constitution document MUST be updated to reflect new binary names, namespaces, and directory paths.
- **FR-011**: The CLAUDE.md project documentation MUST be updated to reflect the new structure, commands, and terminology.
- **FR-012**: A one-time migration path MUST exist to rename `books/*/data/book_*.yml` files to their `world_*` equivalents and move `books/` to `worlds/`.

### Key Entities

- **World**: The top-level container for an IP universe (replaces "book" as the project unit). Identified by a `world_config.yml` in its data directory. Contains canon (story bible), content (chapters, comics, etc.), and assets.
- **Domain CLI**: A standalone Thor-based binary focused on one architectural concern (world management, story bible, canon versioning, content production, translation, publishing).
- **Producer**: A content generator that creates artifacts from a canon version. Producers are content-type-specific (chapter, comic) and live within the `Eidos::` namespace.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Zero references to "BookCore", "Book::CLI", or `book-generator` remain in Ruby source files after refactoring.
- **SC-002**: All six domain CLI binaries (`world`, `bible`, `canon`, `produce`, `translate`, `publish`) respond to `--help` with correct, domain-specific documentation.
- **SC-003**: 100% of existing automated tests pass after refactoring (same test count, updated namespaces/paths).
- **SC-004**: A world created with `world new` contains zero references to "book" in generated file names or YAML keys.
- **SC-005**: An existing project under `books/` can be migrated to `worlds/` and all CLI commands succeed against the migrated data with no manual intervention beyond running the migration command.
- **SC-006**: The constitution and CLAUDE.md documents contain zero stale references to old terminology.

## Assumptions

- The project has a single existing world (`one-review-man`) that serves as the migration test case.
- The `story_bible` name is intentionally retained — it is correct industry terminology and does not need to change.
- Content-type names (chapter, comic, character) are format descriptors, not paradigm terms — they stay as-is.
- The future `eidos` wrapper binary is out of scope for this refactoring. Only the domain-specific binaries are created now.
- The Jekyll site templates may reference "book" in user-facing content (e.g., "Read the book") — these are content decisions, not terminology bugs, and are out of scope.
- No backward compatibility with old `book` CLI or `--book-dir` flag is needed. This is a clean break.
- The gem rename from implicit `book` to explicit `eidos` includes updating the Gemfile, gemspec (if any), and all `require` statements.
