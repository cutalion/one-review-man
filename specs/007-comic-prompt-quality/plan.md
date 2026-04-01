# Implementation Plan: Comic Prompt Quality

**Branch**: `007-comic-prompt-quality` | **Date**: 2026-04-01 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/007-comic-prompt-quality/spec.md`

## Summary

Improve comic panel prompt generation to explicitly control all text in images (speech bubbles, signs, sound effects) and add rich visual storytelling direction (expressions, body language, camera angles, lighting). Changes are limited to prompt templates in `PanelDescriptionGenerator#build_prompt` and `InstagramComicProducer#build_image_prompt`.

## Technical Context

**Language/Version**: Ruby 3.3.5, `frozen_string_literal: true`
**Primary Dependencies**: BookCore (existing), LLMService (existing)
**Storage**: N/A — no new storage; existing YAML sidecar format unchanged
**Testing**: RSpec with MOCK_AI=true
**Target Platform**: CLI (existing)
**Project Type**: CLI tool (existing feature modification)
**Performance Goals**: N/A — prompt template changes only
**Constraints**: No changes to Producer Contract, CLI interface, image generation service, or data model
**Scale/Scope**: 2 files modified (panel_description_generator.rb, instagram_comic_producer.rb), corresponding spec files updated

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Test-First with Mock AI | PASS | Will update specs to verify prompt content contains text control and visual storytelling elements. Mock responses in mock_responses.yml may need update to include text elements. |
| II. Producer Contract | PASS | No changes to producer interface. Only internal prompt composition changes. |
| III. Dependency Injection | PASS | No new services. Uses existing LLMService injection. |
| IV. Canon Integrity with Versioned IP | PASS | No canon changes. |
| V. Security by Default | PASS | No secrets or credential changes. |
| VI. Pluggable AI Services with Evals | PASS | Prompt improvements apply regardless of AI provider. Mock mode handles text elements. |
| VII. Separation of Concerns | PASS | Changes within Producer layer only (Layer 2). |

All gates pass. No violations.

## Project Structure

### Documentation (this feature)

```text
specs/007-comic-prompt-quality/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── quickstart.md        # Phase 1 output
└── tasks.md             # Phase 2 output (/speckit.tasks)
```

### Source Code (files to modify)

```text
book-generator/
├── lib/book_core/
│   ├── panel_description_generator.rb   # Modify build_prompt — add text control + visual storytelling instructions
│   └── producers/
│       └── instagram_comic_producer.rb  # Modify build_image_prompt — append text safeguard instruction
└── spec/book_core/
    ├── panel_description_generator_spec.rb  # Add specs for text control + visual elements in prompts
    └── producers/
        └── instagram_comic_producer_spec.rb # Add specs for safeguard instruction in image prompts
```

**Structure Decision**: No new files or directories. This feature modifies prompt templates in 2 existing implementation files and their corresponding spec files.

## Implementation Approach

### Change 1: PanelDescriptionGenerator#build_prompt (FR-001, FR-002, FR-005, FR-006)

The text LLM prompt must instruct the model to:
- Specify the exact wording of every text element in each panel (speech bubbles, signs, screens, sound effects, captions)
- Indicate when a panel should have no text at all
- Include rich visual storytelling: character expressions, body language, camera angle/framing, lighting/mood, and composition
- Output a JSON schema that includes a `text_elements` field for each panel

Updated JSON schema for LLM response:
```json
[
  {
    "sequence": 1,
    "scene_description": "Detailed visual description with camera angle, lighting, expressions...",
    "characters": ["character_id"],
    "text_elements": [
      { "type": "speech_bubble", "speaker": "character_id", "text": "Exact words here" },
      { "type": "sound_effect", "text": "TAP TAP TAP" }
    ]
  }
]
```

When `text_elements` is empty or absent, the panel has no text.

### Change 2: InstagramComicProducer#build_image_prompt (FR-003, FR-004)

The image generation prompt must:
- Include exact text from `text_elements` (e.g., "speech bubble reading exactly: 'Another perfect review... how boring.'")
- Append safeguard: "Do not add any text, words, or letters beyond what is explicitly specified in this prompt."
- When panel has no text elements: include "no text, no words, no letters, no speech bubbles anywhere in the image."

### Change 3: ComicPanel model (minor)

Add `text_elements` attribute to ComicPanel to carry text element data from description generation to image prompt composition.

### Change 4: Mock responses update

Update `mock_responses.yml` panel descriptions to include `text_elements` in the mock JSON to test the full pipeline.
