# Research: Instagram Comic Producer

## Decision 1: Image generation integration

**Decision**: Use existing `LLMService.generate_image` method, which already supports OpenAI (DALL-E) and OpenRouter providers, returns base64-encoded image data, and handles size/style/quality parameters.

**Rationale**: The IllustrationGenerator already proves this integration works. The Instagram producer follows the same pattern: call `generate_image` with a prompt, get base64, decode to PNG. No new AI service interface needed.

**Alternatives considered**:
- New ImageService abstraction: Over-engineering for now. LLMService already abstracts multiple providers. Can extract later if needed.
- Direct API calls: Violates constitution Principle III (Dependency Injection) and VI (Pluggable AI).

## Decision 2: Character appearance extraction

**Decision**: New `CharacterAppearance` class that reads StoryBible character data and builds a structured visual description prompt. Extracts `physical_appearance` fields (age, skin_tone, hair, eyes, outfit, distinguishing_features) plus name and description.

**Rationale**: The IllustrationGenerator already does a simpler version of this in `inject_character_context`. The Instagram producer needs a richer, reusable extraction because the same appearance prompt must be injected into every panel to maintain consistency.

**Alternatives considered**:
- Reuse IllustrationGenerator's `inject_character_context`: Too tightly coupled to that class's internal format. Better to have a standalone extractor.
- Store character visual prompts in the Story Bible: Would require Story Bible schema changes. Better to derive at generation time from existing data.

## Decision 3: Panel description generation (LLM pipeline)

**Decision**: Two-step pipeline: (1) Send chapter content + character appearances to text LLM with a structured prompt asking for N scene descriptions, each with characters involved, visual action, and mood. (2) For each scene, compose a complete image generation prompt combining scene description + character appearance details + art style.

**Rationale**: Separating scene selection from image prompting allows the description-only mode (FR-012) and lets users edit descriptions before paying for image generation. The text LLM excels at creative scene selection from narrative text.

**Alternatives considered**:
- Single-step: Send chapter directly to image model with instructions. Image models don't understand long-form narrative well; they need focused scene descriptions.
- Manual scene selection: Not automated enough for the target use case.

## Decision 4: Image size mapping for Instagram

**Decision**: Map Instagram formats to AI image generation sizes:
- Square (1080x1080) → generate at `1024x1024` (DALL-E native), then resize to 1080x1080
- Portrait (1080x1350) → generate at `1024x1792` (DALL-E native portrait), then resize to 1080x1350

**Rationale**: DALL-E and most image models have fixed size options that don't match Instagram exactly. Generating at the closest native size and resizing preserves quality. The resize step is minimal (1024→1080 is only 5.5% upscale).

**Alternatives considered**:
- Generate at exact Instagram dimensions: Most image APIs don't support arbitrary sizes. Would require API-specific hacks.
- Skip resize, use native sizes: Instagram accepts various sizes but 1080px is the recommended standard for feed quality.

## Decision 5: YAML sidecar file structure

**Decision**: One sidecar file per generation run, named `panels_NNN.yml` where NNN is the source identifier (chapter number). Contains full metadata and panel descriptions.

**Rationale**: Keeps all metadata for one panel set together. The file serves triple duty: metadata record, description-only output, and input for re-generation from saved descriptions.

**Alternatives considered**:
- One file per panel: Too many small files, harder to manage as a set.
- Single global file for all panel sets: Would grow unbounded and create merge conflicts.

## Decision 6: Image resizing approach

**Decision**: Use Ruby's built-in capabilities or a lightweight gem for the 1024→1080 resize. If no image processing gem is available, output at native AI size (1024x1024 or 1024x1792) and document that images are near-Instagram-ready. The resize is a nice-to-have, not a blocker.

**Rationale**: Adding an image processing dependency (e.g., MiniMagick, ImageMagick) for a 5% upscale may be overkill. The native 1024px images are visually indistinguishable from 1080px on mobile screens. If exact sizing matters later, it can be added as a polish step.

**Alternatives considered**:
- Require ImageMagick: Heavy dependency for minimal gain.
- Use chunky_png for resize: Pure Ruby but very slow for large images.
- Output at native size: Simplest. Instagram will auto-resize anyway.
