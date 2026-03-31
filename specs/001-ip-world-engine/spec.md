# Feature Specification: IP World Consistency Engine

**Feature Branch**: `001-ip-world-engine`
**Created**: 2026-03-30
**Status**: Draft
**Input**: User description: "An engine to build and support consistency of IP worlds with various content types (text, media, translations). Side tools to publish that content will eventually migrate to separate projects but for now may be in this repo."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Define a World and Its Canon (Priority: P1)

A world creator defines a new IP world by establishing its foundational elements: setting, characters, rules, tone, and lore. The engine stores these as the canonical source of truth. The creator can update canon entries and the engine tracks what changed, ensuring all references remain consistent.

**Why this priority**: Without a well-defined world model, no content can be validated for consistency. This is the foundation everything else depends on.

**Independent Test**: Create a new world, add characters and setting rules, update a character's backstory, and verify the engine detects which existing content references the changed element.

**Acceptance Scenarios**:

1. **Given** no world exists, **When** the creator initializes a new world with a name and core setting description, **Then** the engine creates a world record with the provided details and an empty canon.
2. **Given** a world exists, **When** the creator adds a character with name, role, backstory, and relationships, **Then** the character is stored as a canon entry and is available for consistency checks.
3. **Given** a world with existing content referencing a character, **When** the creator updates that character's backstory, **Then** the engine identifies all content pieces that reference the changed character and flags them for consistency review.

---

### User Story 2 - Author Content with Consistency Validation (Priority: P2)

A content author creates new text content (chapters, stories, descriptions) within an established world. Before the content is finalized, the engine validates it against the world's canon and flags inconsistencies (e.g., a character acting out of established personality, contradicting established lore, using wrong terminology).

**Why this priority**: Content creation with built-in consistency checking is the core value proposition of the engine. It depends on the world model from US1.

**Independent Test**: Create a world with defined characters and rules, author a chapter that intentionally contradicts one canon element, and verify the engine flags the contradiction with a specific reference to the violated canon entry.

**Acceptance Scenarios**:

1. **Given** a world with established canon, **When** the author submits new text content, **Then** the engine validates the content against canon and returns a consistency report.
2. **Given** content that contradicts a character's established traits, **When** the consistency check runs, **Then** the report identifies the specific contradiction, quotes the conflicting passage, and references the relevant canon entry.
3. **Given** content that is fully consistent with canon, **When** the consistency check runs, **Then** the report confirms consistency with no flags.

---

### User Story 3 - Translate Content While Preserving World Consistency (Priority: P3)

A translator produces translations of existing content into other languages. The engine ensures that translated content preserves world-specific terminology (character names, place names, invented terms) according to a translation glossary maintained per world and target language.

**Why this priority**: Multi-language support extends the world's reach. It builds on existing content (US2) and world definitions (US1) but is independently valuable once those exist.

**Independent Test**: Define a world with a translation glossary for one language, translate a chapter, and verify the engine flags any glossary term that was not translated according to the glossary.

**Acceptance Scenarios**:

1. **Given** a world with a translation glossary for a target language, **When** a translation is submitted, **Then** the engine checks all glossary terms are used correctly and flags deviations.
2. **Given** a translated chapter where a character name is inconsistently translated, **When** the consistency check runs, **Then** the engine identifies the inconsistency and suggests the glossary-approved term.
3. **Given** no glossary exists for a target language, **When** translation begins, **Then** the engine prompts the creator to establish a glossary or proceeds without terminology enforcement (documenting this as a warning).

---

### User Story 4 - Manage Media Assets Linked to Canon (Priority: P4)

A content author or artist registers media assets (images, audio, video references) and associates them with canon elements (characters, locations, scenes). The engine tracks these associations so that when canon changes, affected media assets are flagged for review.

**Why this priority**: Media management extends the engine beyond text. It reuses the canon model from US1 but adds a new content type.

**Independent Test**: Register an image associated with a character, change that character's description in canon, and verify the media asset is flagged for review.

**Acceptance Scenarios**:

1. **Given** a world with canon elements, **When** a media asset is registered with associations to specific canon entries, **Then** the asset is stored with its associations and appears in canon dependency reports.
2. **Given** a media asset linked to a character, **When** that character's visual description changes, **Then** the engine flags the media asset for review with the reason for the flag.

---

### User Story 5 - Publish Content via Side Tools (Priority: P5)

A publisher uses side tools to export world content into publishable formats (e.g., a website, an e-book, a document). These tools consume the engine's content and canon data. The publishing tools are designed to eventually migrate to separate projects.

**Why this priority**: Publishing is the final step in the content pipeline. It depends on all upstream content being ready and consistent. The tools are explicitly scoped as temporary residents in this repository.

**Independent Test**: Generate a world with chapters and translations, run the publishing tool, and verify the output contains the expected content in the correct format.

**Acceptance Scenarios**:

1. **Given** a world with finalized content, **When** the publisher runs the export tool, **Then** the tool produces output in the requested format containing all selected content.
2. **Given** content with unresolved consistency warnings, **When** the publisher attempts to export, **Then** the tool warns about unresolved issues and requires explicit confirmation to proceed.

---

### Edge Cases

- What happens when a canon entry is deleted that has dependent content? The engine MUST prevent deletion and require the creator to resolve dependencies first, or archive the entry (keeping it available for reference but marked as deprecated).
- How does the system handle circular references in canon (e.g., Character A's backstory references Character B, whose backstory references Character A)? The engine MUST detect circular dependencies and report them without failing.
- What happens when content references a canon element that does not exist? The engine MUST flag this as an "unresolved reference" during consistency validation.
- How does the system handle bulk imports of existing content that predates the engine? The engine MUST support importing existing content and running a full consistency audit against current canon.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The engine MUST allow creators to define a world with a unique name, setting description, and configurable canon categories (characters, locations, rules, terminology, etc.).
- **FR-002**: The engine MUST store canon entries with structured metadata: name, category, description, relationships to other entries, and revision history.
- **FR-003**: The engine MUST validate new or updated text content against the world's canon and produce a structured consistency report listing each issue with the conflicting passage and the referenced canon entry.
- **FR-004**: The engine MUST track dependencies between content pieces and canon entries so that canon changes trigger review notifications for affected content.
- **FR-005**: The engine MUST support a per-world, per-language translation glossary that maps canonical terms to their approved translations.
- **FR-006**: The engine MUST validate translated content against the translation glossary and flag terminology deviations.
- **FR-007**: The engine MUST allow media assets to be registered and associated with one or more canon entries.
- **FR-008**: The engine MUST support content in multiple formats: plain text, structured chapters (with metadata like title, sequence number, summary), and media references.
- **FR-009**: The engine MUST expose all functionality through both a library API and a CLI that wraps it, so that publishing side tools and future external projects can either import the library directly or invoke CLI commands.
- **FR-010**: The engine MUST support importing existing content and running a full consistency audit.
- **FR-011**: The engine MUST maintain a revision history for canon entries, allowing creators to see what changed and when.
- **FR-012**: Publishing side tools MUST consume the engine's data through a well-defined boundary so they can be extracted to separate projects without modifying the engine.

### Key Entities

- **World**: The top-level container for an IP universe. Has a unique name, setting description, and configuration. Contains all other entities.
- **Canon Entry**: A single element of world lore (character, location, rule, term, etc.). Has a category, structured metadata, relationships to other entries, and revision history.
- **Content Piece**: A unit of authored content (chapter, story, description) belonging to a world. Associated with canon entries it references. Has a language and consistency status.
- **Translation Glossary**: A per-world, per-language mapping of canonical terms to approved translations.
- **Media Asset**: A registered media file (image, audio, video reference) associated with canon entries. Tracked for consistency when linked canon changes.
- **Consistency Report**: The output of a validation run against a content piece or translation. Lists issues, their severity, and references to the violated canon entries.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Creators can define a new world and populate it with 50+ canon entries in a single session without errors or data loss.
- **SC-002**: Content consistency checks complete within 30 seconds for a chapter of up to 10,000 words against a world with 200+ canon entries.
- **SC-003**: 95% of intentional canon contradictions in test content are detected and reported by the consistency engine.
- **SC-004**: Translation glossary violations are detected with 95% accuracy when glossary terms appear in translated content.
- **SC-005**: A world with 10 chapters, 3 languages, and 100 canon entries can be fully exported by publishing tools in under 2 minutes.
- **SC-006**: Publishing side tools can be extracted to a separate project by changing only import paths, with no modifications to the core engine.

## Assumptions

- The engine is primarily used by individual creators or small teams (not enterprise-scale concurrent editing).
- Content is authored outside the engine (in text editors, writing tools, etc.) and submitted to the engine for validation — the engine is not a content editor.
- Media assets are stored as references (file paths or URLs); the engine does not manage binary storage or transcoding.
- The current repository already has content generation and translation tooling (the existing book-generator) that will inform but not constrain the engine's design.
- Publishing side tools will coexist in this repository during initial development but are designed with a clean separation boundary from day one.
- "Consistency" is primarily semantic (does the content match established lore?) rather than grammatical or stylistic.
