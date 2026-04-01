# Research: Comic Prompt Quality

**Feature**: 007-comic-prompt-quality
**Date**: 2026-04-01

## Research Topics

### 1. Best practices for controlling text in AI image generation prompts

**Decision**: Use explicit text specification with safeguard instruction.

**Rationale**: AI image models (DALL-E, Stable Diffusion, etc.) tend to invent text when scenes naturally suggest it (signs, screens, speech bubbles). The most effective approach is:
1. Specify exact text content in the prompt (e.g., "speech bubble reading exactly: 'Hello world'")
2. Append a negative instruction: "Do not add any text beyond what is specified"
3. For text-free panels, explicitly state: "no text, no words, no letters"

This two-layer approach (explicit text + safeguard) gives the best results because:
- Explicit text gives the model a clear target
- The safeguard prevents the model from adding extra text it "thinks" should be there
- Text-free panels need explicit declaration because models default to adding text in certain contexts (office scenes, street scenes, etc.)

**Alternatives considered**:
- Negative prompts only ("no text"): Less effective because it doesn't specify what text IS wanted
- Post-processing text removal: Too complex, loses intended text too
- Inpainting text after generation: Out of scope — this feature focuses on prompts

### 2. Structured text elements in panel descriptions

**Decision**: Add `text_elements` array to panel JSON schema. Each element has `type` (speech_bubble, sign, screen, sound_effect, caption), optional `speaker` (character ID), and `text` (exact wording).

**Rationale**: Structured data is better than embedding text instructions in free-form scene descriptions because:
- The image prompt builder can reliably extract and format text instructions
- Text elements can be validated (non-empty text, valid speaker references)
- The separation allows the scene_description to focus on visual storytelling

**Alternatives considered**:
- Embedding text in scene_description: Harder to parse, mixes concerns
- Separate text_description field: Less structured, harder to compose image prompt

### 3. Visual storytelling elements for image generation

**Decision**: Instruct the text LLM to include 5 visual storytelling elements in every scene description: (1) character appearance/pose, (2) facial expression, (3) camera angle/framing, (4) lighting/mood, (5) composition direction.

**Rationale**: These 5 elements map directly to what image generation models can control. The text LLM is good at translating narrative moments into visual direction when explicitly asked. Success criterion SC-003 requires at least 4 of 5 elements per panel.

**Alternatives considered**:
- Structured fields for each element: Over-engineering for prompt composition
- Fewer elements: Would not produce cinematic quality panels

### 4. ComicPanel model extension

**Decision**: Add `text_elements` attribute to ComicPanel. Default to empty array. Include in `to_h` serialization for YAML sidecar persistence.

**Rationale**: The text_elements data must flow from PanelDescriptionGenerator through to InstagramComicProducer#build_image_prompt. ComicPanel is the natural carrier. Adding an attribute is minimally invasive — existing code that doesn't use text_elements is unaffected.

**Alternatives considered**:
- Separate TextElement class: Unnecessary complexity for what amounts to a hash with 2-3 keys
- Storing text_elements outside ComicPanel: Breaks the natural data flow

### 5. Mock response updates

**Decision**: Update `mock_responses.yml` panel_descriptions to include `text_elements` in the mock JSON. Some mock panels will have text elements, others won't, to test both paths.

**Rationale**: Tests need to exercise both text-present and text-absent paths. The mock response is the input that PanelDescriptionGenerator returns in MOCK_AI mode.

Note: PanelDescriptionGenerator uses its own `generate_mock_panels` method (not mock_responses.yml) in MOCK_AI mode. This method also needs updating to return panels with text_elements.
