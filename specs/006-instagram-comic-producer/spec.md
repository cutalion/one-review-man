# Feature Specification: Instagram Comic Producer

**Feature Branch**: `006-instagram-comic-producer`
**Created**: 2026-04-01
**Status**: Draft
**Input**: User description: "Instagram comic producer — Build an Instagram comic image producer that generates comic-style panels from book chapters. It should use the Producer Contract interface (feature 005) to accept a canon snapshot, configuration (chapter number, panel count, art style, image dimensions for Instagram), and output location. The producer reads chapter content and character descriptions from the Story Bible, generates panel descriptions, then calls an image generation AI service to create the comic panels. Output should be Instagram-ready images (1080x1080 or 1080x1350) with consistent character appearances across panels."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Generate comic panels from a chapter (Priority: P1)

As a content creator, I want to generate a set of comic-style image panels from a narrative source in my IP (e.g., a book chapter) so that I can post visually engaging content on Instagram that tells the story in comic form.

**Why this priority**: This is the core value proposition — turning text chapters into visual comic content. Without this, there is no Instagram comic producer.

**Independent Test**: Can be fully tested by running the producer with a chapter number and verifying it outputs a set of image files at the specified location, each depicting a scene from that chapter with consistent character appearances.

**Acceptance Scenarios**:

1. **Given** an IP with at least one narrative source and character descriptions in the Story Bible, **When** the user invokes the Instagram comic producer for that source, **Then** the system generates the configured number of comic panel images at the output location.
2. **Given** valid configuration (source reference, panel count, art style), **When** generation completes, **Then** each panel image is Instagram-ready (correct dimensions) and depicts a scene from the source narrative.
3. **Given** character descriptions exist in the Story Bible, **When** panels are generated, **Then** the same character appears visually consistent across all panels in the set (same colors, features, proportions).
4. **Given** a canon snapshot is specified, **When** panels are generated, **Then** the output metadata records which canon version was used.

---

### User Story 2 - Configure art style and panel layout (Priority: P2)

As a content creator, I want to choose the art style (e.g., manga, western comic, pixel art) and panel count so that I can match the visual style to my Instagram brand and vary the content format.

**Why this priority**: Customization is important for brand consistency but secondary to basic generation working at all.

**Independent Test**: Can be tested by generating panels with different art style and panel count configurations and verifying the outputs differ in style and quantity.

**Acceptance Scenarios**:

1. **Given** the user specifies an art style (e.g., "manga"), **When** panels are generated, **Then** all panels use that visual style consistently.
2. **Given** the user specifies a panel count of 4, **When** generation completes, **Then** exactly 4 panel images are produced.
3. **Given** no art style is specified, **When** panels are generated, **Then** a default art style is used.
4. **Given** no panel count is specified, **When** panels are generated, **Then** a default panel count (4) is used.

---

### User Story 3 - Choose image dimensions for Instagram formats (Priority: P2)

As a content creator, I want to choose between Instagram image formats (square 1080x1080 for feed, portrait 1080x1350 for feed/reels) so that the output fits my posting strategy.

**Why this priority**: Same level as US2 — format flexibility matters for Instagram but is secondary to basic generation.

**Independent Test**: Can be tested by generating panels with different dimension settings and verifying output images have the correct pixel dimensions.

**Acceptance Scenarios**:

1. **Given** the user specifies "square" format, **When** panels are generated, **Then** each image is 1080x1080 pixels.
2. **Given** the user specifies "portrait" format, **When** panels are generated, **Then** each image is 1080x1350 pixels.
3. **Given** no format is specified, **When** panels are generated, **Then** the default format (square 1080x1080) is used.

---

### User Story 4 - Generate panel descriptions before image generation (Priority: P3)

As a content creator, I want to preview the text descriptions of each panel before images are generated so that I can review or edit them to improve the visual output without paying for image generation.

**Why this priority**: This is a workflow optimization — useful for iteration and cost control, but not required for basic functionality.

**Independent Test**: Can be tested by running the producer in a "dry run" or "describe only" mode and verifying it outputs panel descriptions without calling the image generation service.

**Acceptance Scenarios**:

1. **Given** the user runs the producer in description-only mode, **When** generation completes, **Then** the system outputs text descriptions for each panel without generating images.
2. **Given** panel descriptions exist from a previous run, **When** the user runs full generation, **Then** the system can use those descriptions to generate images (skipping the description step).

---

### Edge Cases

- What happens when the specified source does not exist (e.g., chapter number with no content)? The system should raise a clear error before calling the image service.
- What happens when a character referenced in the narrative has no description in the Story Bible? The system should use a placeholder description and warn the user.
- What happens when the image generation service fails for one panel? The system should report the failure for that panel, save any successfully generated panels, and allow retry of the failed panel.
- What happens when the user specifies 0 panels or a negative panel count? The system should reject invalid panel counts with a clear error.
- What happens when the output directory already contains panels from a previous run? The system should overwrite existing files for the same source, preserving panels from other sources.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The Instagram comic producer MUST implement the Producer Contract interface (snapshot, config hash, output location).
- **FR-002**: The producer MUST read narrative content from the IP's available sources (currently: book chapters) using a `source` parameter that specifies the source type and identifier (e.g., `{ type: "chapter", number: 1 }`).
- **FR-003**: The producer MUST read character descriptions from the Story Bible to build visual consistency prompts.
- **FR-004**: The producer MUST generate a text description for each panel by sending the source narrative content to the text LLM, which selects the N most visually compelling scenes and writes a detailed image generation prompt for each.
- **FR-005**: The producer MUST call an image generation service to create each panel image from its text description.
- **FR-006**: The producer MUST include character appearance details in every panel description to maintain visual consistency across panels.
- **FR-007**: Output images MUST be in a standard web-ready format (PNG or JPEG).
- **FR-008**: The producer MUST support configurable panel count (default: 4 panels per source).
- **FR-009**: The producer MUST support configurable art style (default: manga style).
- **FR-010**: The producer MUST support configurable image dimensions: square (1080x1080) and portrait (1080x1350), defaulting to square.
- **FR-011**: The producer MUST record canon version, source reference, art style, and panel descriptions in a YAML sidecar file (e.g., `panels_001.yml`) in the output directory alongside the images. The sidecar includes a `source` field recording the type and identifier of the narrative content used.
- **FR-012**: The producer MUST support a description-only mode that writes the YAML sidecar file with panel descriptions without calling the image generation service. Subsequent full runs MUST be able to read and use these saved descriptions.
- **FR-013**: The producer MUST register itself in the Producer registry so it can be discovered and invoked by name.
- **FR-014**: The image generation service MUST be injected as a dependency, not hardcoded to a specific provider. The existing LLM service already supports image generation and should be used through dependency injection.

### Key Entities

- **ComicPanel**: A single panel in the comic. Has a sequence number, scene description, character references, and an image file path (nil until generated). Image files follow the naming pattern `panel_NNN_NN.png`.
- **PanelSet**: A collection of comic panels for one narrative source. Has a source reference (type + identifier), art style, image format, canon version, and an ordered list of ComicPanels. Persisted as a YAML sidecar file in the output directory.
- **CharacterAppearance**: Visual description of a character extracted from the Story Bible. Has a character name, physical description, and distinctive features — used to prompt consistent character depiction.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Given a narrative source with characters, the producer generates the requested number of panel images at the correct dimensions in under 5 minutes (for 4 panels).
- **SC-002**: Characters are visually recognizable across all panels in a set — verified by including the same appearance prompt in every panel's image generation request.
- **SC-003**: The producer can be invoked via the Producer Contract interface with zero modifications to the producer base or registry code, confirming the contract works for a second producer type.
- **SC-004**: Description-only mode completes without calling the image generation service, verifiable by mock/stub inspection in tests.

## Clarifications

### Session 2026-04-01

- Q: How should panel scenes be selected from chapter content? → A: LLM-driven — send chapter text to the text LLM, ask it to select N key scenes and write panel descriptions.
- Q: Where should panel descriptions be stored? → A: YAML sidecar file in the output directory (e.g., `panels_001.yml`) alongside the images.
- Q: What file naming convention for panel images? → A: `panel_NNN_NN.png` (no "chapter" in filename — IP-neutral). Metadata sidecar records `source: { type: "chapter", number: N }`.
- Q: Should terminology be book-specific or IP-neutral? → A: IP-neutral. The producer accepts a `source` parameter (currently chapter), not "chapter" directly. The IP is a Storyworld, not a book; books/comics/Instagram are all derivatives.

## Assumptions

- The Producer Contract interface (feature 005) is complete and available.
- An image generation AI service (e.g., DALL-E, Stability AI) is accessible via environment variable API keys, following the project's security-by-default principle.
- The existing `IllustrationGenerator` provides a reference for image generation patterns but this producer is independent — it does not extend or wrap IllustrationGenerator.
- The initial narrative source type is "chapter" — content files stored in the book's content directory in Markdown format with YAML front matter. Future source types (scripts, standalone stories) can be added without changing the producer interface.
- Character descriptions in the Story Bible include enough visual detail (physical appearance, clothing, distinctive features) to generate consistent comic depictions. If they don't, the producer will use what's available and warn about missing detail.
- This feature does not handle Instagram posting/publishing — it only generates the image files. Publishing is a separate Layer 3 concern.
- Panel count of 4 and manga art style are sensible defaults for Instagram comic content.
