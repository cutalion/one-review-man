# System Specification: One Review Man

**Feature Branch**: `003-project-system-spec`  
**Created**: 2026-03-31  
**Status**: Draft  
**Input**: Comprehensive top-level project specification covering the entire One Review Man system

## Overview

One Review Man is an AI-powered book generation and publishing system. It produces an episodic comedy novel parodying programming culture (inspired by One-Punch Man), manages a canonical story universe, translates content into multiple languages, and publishes the result as a static website.

The system serves a single author/operator who interacts through a command-line interface to generate, curate, translate, and publish book content. All content and configuration is stored as flat files (YAML and Markdown) within the project directory structure.

## Clarifications

### Session 2026-03-31

- Q: When an AI provider call fails (timeout, rate limit, API error), what should the system do? → A: Abort with a clear error message; do not retry or save partial output.
- Q: When a branch merge produces field-level conflicts, how does the author resolve them? → A: Author manually edits entity YAML files after viewing the conflict report, then re-attempts the merge.
- Q: When the AI returns malformed output (invalid structure, missing required fields), what should the system do? → A: Reject entirely and report the validation error; do not save any files.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Generate a New Chapter (Priority: P1)

The author generates the next chapter of the book. The system determines which chapter number comes next, assembles context from the story universe (characters, locations, facts, plot threads, previous chapter summaries), builds a prompt from templates, sends it to an AI model, and writes the resulting chapter as a Markdown file with structured metadata. Any new characters introduced are automatically created as separate profiles. Story facts mentioned in the chapter are extracted and stored in the canonical universe.

**Why this priority**: Chapter generation is the core value proposition — without it, there is no book.

**Independent Test**: Can be fully tested by running the chapter generation command with mock AI and verifying that a properly structured chapter file is created with correct metadata, that new characters are persisted, and that story facts are recorded.

**Acceptance Scenarios**:

1. **Given** a book project with 6 existing chapters, **When** the author runs the chapter generation command, **Then** chapter 7 is created as a Markdown file with frontmatter containing title, chapter number, character list, summary, programming themes, comedy elements, word count, and generation date.
2. **Given** a chapter generation that introduces new characters, **When** the chapter is written, **Then** each new character has a dedicated profile file created with name, description, personality traits, physical appearance, programming skills, catchphrase, backstory, and first appearance chapter.
3. **Given** a chapter generation that reveals new story facts, **When** the chapter is written, **Then** each fact is stored in the Story Bible under its appropriate category (events, world rules, etc.) with a reference to the introducing chapter.
4. **Given** mock AI mode is enabled, **When** the author generates a chapter, **Then** the system uses deterministic canned responses and requires no network access or API keys.

---

### User Story 2 - Translate Content to Another Language (Priority: P1)

The author translates chapters and character profiles into a target language (currently Russian). The system loads the English source, builds a translation prompt that includes a glossary of character name mappings, terminology rules, and cultural adaptation guidelines, sends it to an AI model, and writes the translated content as a language-suffixed file alongside the original.

**Why this priority**: Multi-language publishing is a core product requirement — the book is published in both English and Russian.

**Independent Test**: Can be tested by translating a single chapter and verifying the output file has correct structure, language suffix, and that character names follow the configured glossary mappings.

**Acceptance Scenarios**:

1. **Given** an English chapter file exists, **When** the author translates it to Russian, **Then** a `.ru.md` file is created alongside the original with translated title, summary, and content while preserving all frontmatter structure.
2. **Given** translation rules define character name mappings (e.g., "One Review Man" → "Ванревьюмен"), **When** a chapter is translated, **Then** all character names in the translated text follow the configured mappings consistently.
3. **Given** the author runs "translate all" for a language, **When** the command completes, **Then** every chapter and every character profile has a corresponding translated file.

---

### User Story 3 - Publish as a Website (Priority: P1)

The author generates a static website from the book content. The system copies Jekyll templates, processes placeholders (book title, author, genre), copies chapter and character content into Jekyll-compatible collections, sets up bilingual navigation and language switching, and produces a ready-to-serve Jekyll site.

**Why this priority**: Publication is the delivery mechanism — content must reach readers.

**Independent Test**: Can be tested by running the Jekyll generation command and verifying that the output directory contains a valid Jekyll site with all chapters, characters, and bilingual pages.

**Acceptance Scenarios**:

1. **Given** a book project with chapters and characters in English and Russian, **When** the author generates the Jekyll site, **Then** the output directory contains chapter pages, character pages, navigation, and language switcher for both languages.
2. **Given** the author updates book metadata (title, subtitle, author), **When** the site is regenerated, **Then** all template placeholders reflect the updated metadata.
3. **Given** the site has been generated previously, **When** the author regenerates it, **Then** new chapters and characters are added without losing any user customizations to non-template files.

---

### User Story 4 - Manage the Story Bible (Priority: P2)

The author queries and manages the canonical story universe through the Story Bible. This includes listing, viewing, and searching characters, locations, facts, relationships, and plot threads. The author can also export the Story Bible to data files suitable for the website, and view contextual information relevant to a specific chapter.

**Why this priority**: Story consistency is essential for quality — the Story Bible prevents contradictions and maintains continuity across chapters.

**Independent Test**: Can be tested by creating Story Bible entries, querying them via list/show/search commands, and verifying correct retrieval and formatting.

**Acceptance Scenarios**:

1. **Given** the Story Bible contains characters, locations, and facts, **When** the author lists entities of a given type, **Then** all entities of that type are displayed with their IDs and names.
2. **Given** a character exists in the Story Bible, **When** the author views it by path (e.g., `characters/kenji`), **Then** the full profile is displayed.
3. **Given** facts are stored with descriptions, **When** the author searches by keyword, **Then** all matching facts are returned regardless of case.
4. **Given** the Story Bible has been populated, **When** the author exports it, **Then** Jekyll-compatible YAML data files are created for characters, world data, and story facts.

---

### User Story 5 - Track and Review Canon Changes (Priority: P2)

The author tracks the revision history of any canonical entity (character, location, fact, etc.), compares any two revisions to see what changed, and rolls back to a previous state if needed. When a canon entry changes, the system identifies which content files reference that entity and flags them for review.

**Why this priority**: Revision tracking prevents accidental data loss and enables confident iteration on the story universe.

**Independent Test**: Can be tested by making a series of changes to a character, viewing the history, diffing two revisions, rolling back, and verifying impact reports list affected chapters.

**Acceptance Scenarios**:

1. **Given** a character has been updated multiple times, **When** the author views its history, **Then** all revisions are shown chronologically with operation type, timestamp, and change reason.
2. **Given** two revisions of a character, **When** the author diffs them, **Then** a field-level comparison shows exactly which fields changed and their before/after values.
3. **Given** a character was changed incorrectly, **When** the author rolls back to revision 1, **Then** the character data is restored to its state at revision 1 and a new revision is recorded documenting the rollback.
4. **Given** a character referenced in chapters 3 and 5 is updated, **When** the author views impact reports, **Then** both chapters are listed as affected with severity and review status.

---

### User Story 6 - Explore Alternative Story Directions with Branches (Priority: P3)

The author creates independent branches of the story universe to explore alternative character arcs, plot directions, or "what-if" scenarios without affecting the main canon. Branches can be compared, merged back into the main canon (with conflict detection), or archived/deleted.

**Why this priority**: Branching enables creative experimentation without risk, but is an advanced workflow used less frequently than day-to-day generation.

**Independent Test**: Can be tested by creating a branch, making changes within it, comparing with main, merging, and verifying conflict detection works correctly.

**Acceptance Scenarios**:

1. **Given** the main canon exists, **When** the author creates a branch, **Then** an independent copy of the canon state is created from main.
2. **Given** changes were made on a branch, **When** the author compares the branch with main, **Then** the comparison shows entities only in one branch, entities in both with conflicts, and identical entities.
3. **Given** a branch has non-conflicting changes, **When** the author merges it into main, **Then** changes are applied to main and revisions are recorded.
4. **Given** both main and a branch changed the same field of the same entity, **When** a merge is attempted, **Then** the conflict is detected and reported for manual resolution.

---

### User Story 7 - Batch Canon Changes with Changesets (Priority: P3)

The author groups multiple canon changes into a single atomic changeset. Operations (create, update, delete) are accumulated, previewed for aggregate impact and intra-batch conflicts, and then either committed atomically or discarded.

**Why this priority**: Changesets ensure consistency when making related changes across multiple entities, but are an advanced workflow.

**Independent Test**: Can be tested by creating a changeset, adding multiple operations, previewing, and committing — then verifying all changes were applied atomically.

**Acceptance Scenarios**:

1. **Given** the author starts a new changeset, **When** they add multiple update operations, **Then** all operations are recorded in the changeset.
2. **Given** a changeset has operations, **When** the author previews it, **Then** the aggregate impact is shown including operation count and detected conflicts.
3. **Given** a changeset is previewed without conflicts, **When** the author commits it, **Then** all operations are applied atomically and revisions are recorded for each change.
4. **Given** the author decides against a changeset, **When** they discard it, **Then** no changes are applied and the changeset is marked as discarded.

---

### User Story 8 - Generate Chapters via Agent-Based Writing (Priority: P3)

The author uses an agent-based writing mode where the AI autonomously queries the Story Bible using tool calls (getting characters, locations, plot threads, facts) before composing the chapter. This produces more contextually aware content than template-based generation.

**Why this priority**: Agent writing is an experimental enhancement to the core generation pipeline — valuable but not required for basic operation.

**Independent Test**: Can be tested by running the agent write command and verifying the agent makes appropriate Story Bible tool calls and produces a complete chapter.

**Acceptance Scenarios**:

1. **Given** a Story Bible with characters and plot threads, **When** the author runs agent-based chapter generation, **Then** the agent queries relevant Story Bible entries before composing the chapter.
2. **Given** the agent has gathered context, **When** it submits a chapter, **Then** the chapter includes title, content, summary, featured characters, and any new characters or facts.
3. **Given** additional requirements are provided, **When** the agent generates a chapter, **Then** the requirements are incorporated into the output.

---

### User Story 9 - Initialize and Configure a Book Project (Priority: P2)

The author creates a new book project from scratch. An interactive wizard collects book metadata, creates the required directory structure, and initializes all configuration files. The author can also view project status and reset content for development/testing purposes.

**Why this priority**: Project initialization is required before any other operation, but only happens once per book.

**Independent Test**: Can be tested by running the init command and verifying the complete directory structure and all configuration files are created correctly.

**Acceptance Scenarios**:

1. **Given** an empty directory, **When** the author initializes a book project, **Then** the complete directory structure is created with `data/`, `content/`, and all required configuration files.
2. **Given** an initialized project, **When** the author views status, **Then** the system displays book metadata, generation progress, configuration, and file structure summary.
3. **Given** a project with generated content, **When** the author resets all content with force mode, **Then** all generated chapters, characters, data files, and site files are removed.

---

### User Story 10 - Generate Illustrations (Priority: P3)

The author generates illustrations for specific passages within chapters. The system extracts content by line range, builds an image generation prompt with character context, calls an image generation AI model, saves the image, and embeds a markdown image reference in the chapter at the specified anchor point.

**Why this priority**: Illustrations enhance the reading experience but are supplementary to the text content.

**Independent Test**: Can be tested by running the illustration command in dry-run mode and verifying prompt construction and parameter resolution.

**Acceptance Scenarios**:

1. **Given** a chapter with content, **When** the author requests an illustration for a line range, **Then** an image is generated and saved to the assets directory.
2. **Given** an illustration is generated, **When** it is embedded in the chapter, **Then** a markdown image reference with alt text appears at the specified anchor point.
3. **Given** the author uses dry-run mode, **When** the illustration command runs, **Then** parameters are displayed without generating or saving any image.

---

### Edge Cases

- When the AI returns malformed or incomplete output (missing title, content, or required fields), the system rejects the output entirely with a validation error and does not save any files.
- When an AI provider call fails (timeout, rate limit, API error, network issue), the system aborts with a clear error message. No retry is attempted and no partial output is saved.
- When translation is requested but the source chapter does not exist, the system reports an error and skips the missing chapter.
- When a branch merge encounters conflicts (including on every field of an entity), the conflicts are reported to the author. The author manually edits the entity YAML files to resolve conflicts, then re-attempts the merge.
- When the Story Bible is empty and chapter generation needs context, the system generates the chapter with minimal context (no characters, locations, or facts injected into the prompt).
- When a changeset commit fails partway through, the system rolls back all applied operations to maintain atomicity — either all succeed or none are applied.
- When the author attempts to generate a chapter number that already exists (without force mode), the system refuses and reports that the chapter already exists.
- When the configuration file has invalid or missing required fields, the system reports a validation error at startup and refuses to proceed.
- When API keys are missing and mock mode is not enabled, the system reports a clear credential error and aborts before attempting any AI call.

## Requirements *(mandatory)*

### Functional Requirements

#### Content Generation

- **FR-001**: System MUST generate chapters sequentially, automatically determining the next chapter number based on existing content.
- **FR-002**: System MUST produce chapters as Markdown files with structured frontmatter containing: title, chapter number, character list, new characters, summary, programming themes, comedy elements, word count, difficulty level, parody references, permalink, generation date, status, and language.
- **FR-003**: System MUST build generation prompts by combining templates with contextual data from the Story Bible (characters, locations, facts, plot threads, previous chapter summaries).
- **FR-004**: System MUST automatically create profile files for any new characters introduced during chapter generation.
- **FR-005**: System MUST extract and store story facts revealed in generated chapters into the Story Bible under appropriate categories.
- **FR-006**: System MUST support a mock AI mode that produces deterministic output without network access, enabling offline testing.
- **FR-007**: System MUST support a debug mode that logs all AI interactions to a debug directory.
- **FR-008**: System MUST support an agent-based generation mode where the AI autonomously queries the Story Bible via tool calls before composing a chapter.
- **FR-009**: System MUST support illustration generation for chapter content, including prompt construction from line ranges, image generation via AI, and embedding in chapter Markdown.

#### Translation

- **FR-010**: System MUST translate chapters and character profiles to any configured target language while preserving all frontmatter structure.
- **FR-011**: System MUST apply configurable character name mappings and terminology rules during translation to ensure consistency.
- **FR-012**: System MUST write translated content as language-suffixed files (e.g., `.ru.md`) alongside the originals.
- **FR-013**: System MUST support batch translation of all chapters and characters to a target language.

#### Story Bible & Canon

- **FR-014**: System MUST maintain a canonical story universe ("Story Bible") containing characters, locations, facts, relationships, and plot threads.
- **FR-015**: System MUST support querying the Story Bible: listing entities by type, viewing individual entities by path, and searching facts by keyword.
- **FR-016**: System MUST export the Story Bible to data files compatible with the website publishing system.
- **FR-017**: System MUST record an append-only revision history for every canon entity change, including: sequence number, snapshot, timestamp, operation type, change reason, and branch context.
- **FR-018**: System MUST support field-level diffing between any two revisions of a canon entity.
- **FR-019**: System MUST support rolling back a canon entity to any previous revision, recording the rollback as a new revision.
- **FR-020**: System MUST analyze the impact of canon changes by identifying which content files reference the changed entity, assigning severity levels, and tracking review status per affected item.

#### Branching & Merging

- **FR-021**: System MUST support creating independent story branches from the main canon (or from another branch).
- **FR-022**: System MUST support switching between branches, comparing branches, and listing all branches with their status.
- **FR-023**: System MUST implement three-way merge for branch merging, with automatic merging of non-conflicting changes and detection/reporting of field-level conflicts. When conflicts are detected, the merge is blocked and a conflict report is produced; the author resolves conflicts by manually editing entity YAML files and re-attempting the merge.
- **FR-024**: System MUST support archiving and deleting branches.

#### Changesets

- **FR-025**: System MUST support grouping multiple canon operations (create, update, delete) into atomic changesets.
- **FR-026**: System MUST support previewing changeset impact and detecting intra-batch conflicts before commit.
- **FR-027**: System MUST apply all changeset operations atomically on commit, recording revisions for each change.

#### Website Generation

- **FR-028**: System MUST generate a static website from book content by processing templates, replacing placeholders with book metadata, and copying content into website-compatible collections.
- **FR-029**: System MUST support bilingual website output with language switching between all configured languages.
- **FR-030**: System MUST preserve user customizations to non-template files when regenerating the site.

#### Configuration

- **FR-031**: System MUST resolve configuration by merging layers in priority order: CLI options > environment variables > project settings > default settings.
- **FR-032**: System MUST support per-task model and provider configuration (separate models for generation, translation, summarization, illustration, and agent writing).
- **FR-033**: System MUST support multiple AI providers (at minimum: OpenAI and OpenRouter) with provider-specific credentials via environment variables.

#### Project Management

- **FR-034**: System MUST support initializing a new book project with an interactive wizard that collects metadata and creates the complete directory structure.
- **FR-035**: System MUST support viewing project status including metadata, generation progress, and configuration.
- **FR-036**: System MUST support selective reset of generated content (all, chapters only, characters only, data, site) with interactive safety confirmation.

#### CLI Interface

- **FR-037**: System MUST provide a command-line interface organized into subcommand groups: `generate`, `translate`, `jekyll`, `bible`, `canon`, `branch`, `changeset`, `agent`, `reset`, `init`, `status`, `migrate`, and `version`.
- **FR-038**: System MUST accept a `--book-dir` (or `-b`) flag on all commands to specify the book project directory.
- **FR-039**: System MUST auto-detect the book project root by searching for the metadata configuration file.

#### Error Handling

- **FR-040**: System MUST abort with a clear error message when an AI provider call fails (timeout, rate limit, API error, network issue), without retrying or saving partial output.
- **FR-041**: System MUST validate AI-generated output against required structure (title, content, and other mandatory fields) and reject entirely with a validation error if malformed, saving no files.
- **FR-042**: System MUST report a clear credential error and abort before attempting any AI call when required API keys are missing and mock mode is not enabled.
- **FR-043**: System MUST validate configuration files at startup and refuse to proceed if required fields are invalid or missing.

### Key Entities

- **Chapter**: An episode of the book. Has a number, title, summary, content, featured characters, programming themes, comedy elements, word count, and generation metadata. Exists as a Markdown file with YAML frontmatter.
- **Character**: A person or entity in the story. Has a name, description, personality traits, physical appearance, programming skills, catchphrase, backstory, quirks, role, and first appearance chapter. Exists both as a Story Bible YAML entry and as a Markdown profile file.
- **Location**: A place in the story world. Has a name, description, and type. Stored in the Story Bible.
- **Fact**: A piece of canonical knowledge about the story world. Organized by category (events, world rules). Has a name, description, and optionally a chapter reference.
- **Relationship**: A connection between two characters. Has character references, type, description, and the chapter where it was established.
- **Plot Thread**: An ongoing storyline. Has an ID, title, description, status (active/resolved), introducing chapter, and involved characters.
- **Revision**: An immutable snapshot of an entity at a point in time. Has a sequence number, entity reference, full snapshot, timestamp, operation type, change reason, parent revision, branch context, and optional changeset ID.
- **Branch**: An independent copy of the story universe for exploring alternatives. Has a name, parent branch, creation point, status (active/archived/deleted), and description.
- **Changeset**: A batch of canon operations to be applied atomically. Has an ID, branch context, status (draft/previewed/committed/discarded), list of operations, and optional preview report.
- **Impact Report**: An analysis of which content is affected by a canon change. Has a trigger reference, list of affected items with severity and review status.
- **Book Configuration**: Static project settings including generation rules, character definitions, translation rules, content rules, and localized metadata per language.
- **Book State**: Dynamic project state including target chapters, current chapter count, generation statistics, and active storylines.
- **Settings**: AI provider and model configuration including provider credentials, per-task model assignments, token limits, and illustration parameters.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: An author can generate a new chapter from scratch (with mock AI) in under 30 seconds, producing a valid Markdown file with all required frontmatter fields.
- **SC-002**: All generated chapters maintain story continuity — characters, locations, and facts referenced in a chapter are consistent with the Story Bible.
- **SC-003**: Translation of a chapter produces a complete language-suffixed file with all character names following the configured glossary (100% mapping consistency).
- **SC-004**: Website generation from a 10-chapter book with 10 characters in 2 languages produces a complete, navigable site with all content accessible in both languages.
- **SC-005**: Revision history accurately captures every canon change — no update, create, or delete operation is lost.
- **SC-006**: Three-way branch merge correctly auto-merges non-conflicting changes and detects 100% of field-level conflicts.
- **SC-007**: Changeset commit is atomic — either all operations succeed or none are applied.
- **SC-008**: Impact analysis identifies all content files referencing a changed entity with zero false negatives.
- **SC-009**: The system operates fully offline when mock AI mode is enabled — no network calls are made.
- **SC-010**: Configuration layering correctly resolves settings with CLI options taking highest priority, followed by environment variables, project settings, and defaults.
- **SC-011**: All tests pass with mock AI enabled, providing a reliable CI/CD-compatible test suite.
- **SC-012**: A new book project can be initialized and produce its first chapter (with mock AI) in under 5 minutes of author time.

## Assumptions

- The primary user is a single author/operator with command-line proficiency who manages book projects locally.
- AI model access requires valid API keys provided via environment variables; the system does not manage or store credentials.
- All persistent data is stored as flat files (YAML and Markdown) within the project directory — no external database is used.
- The system currently supports English as the source language and Russian as the primary translation target, but the architecture is language-agnostic.
- The Story Bible is the single source of truth for canonical story data; content files (chapters, character profiles) are generated artifacts.
- Mock AI mode is the standard for testing and development; live AI calls are only used for actual content generation.
- The Jekyll website is the primary publication channel; other publication formats are out of scope.
- The book follows a sequential chapter structure — chapters are numbered and generated in order.
- Branching and merging operates on Story Bible data only, not on chapter content files.
- The system is designed for local use; concurrent multi-user access to the same project directory is not supported.
