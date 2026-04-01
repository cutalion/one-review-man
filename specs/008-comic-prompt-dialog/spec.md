# Feature Specification: Comic Prompt Dialog

**Feature Branch**: `008-comic-prompt-dialog`
**Created**: 2026-04-01
**Status**: Draft
**Input**: User description: "strengthen comic prompt so LLM always populates text_elements with dialog from chapter narrative"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - LLM populates text_elements with chapter dialog (Priority: P1)

As a content creator, I want the panel description prompt to strongly instruct the text LLM to extract dialog from the chapter narrative and place it in the structured `text_elements` field rather than embedding dialog descriptions inside the `scene_description` field, so that the image generation prompt can reliably render speech bubbles with exact wording.

**Why this priority**: This is the core problem. The current prompt asks for `text_elements` but the LLM ignores the field, setting it to `[]` and instead embedding dialog references inside `scene_description` (e.g., "a small speech bubble in stylized text indicating: '...'"). This defeats the text control system built in feature 007.

**Independent Test**: Generate panel descriptions from a chapter that contains character dialog. Verify that the returned panels have non-empty `text_elements` arrays with speech bubbles containing the actual dialog from the narrative, and that `scene_description` does not contain embedded dialog text or speech bubble references.

**Acceptance Scenarios**:

1. **Given** a chapter narrative containing character dialog, **When** panel descriptions are generated, **Then** at least one panel has a non-empty `text_elements` array with `speech_bubble` entries containing dialog from the narrative.
2. **Given** a generated panel with dialog, **When** the `text_elements` field is inspected, **Then** each speech bubble entry includes the speaker's character ID and the exact dialog text.
3. **Given** a generated panel description, **When** the `scene_description` field is inspected, **Then** it does not contain embedded dialog text, speech bubble descriptions, or phrases like "a speech bubble indicating" or "text reading".
4. **Given** a chapter narrative with no dialog in a particular scene, **When** the panel description for that scene is generated, **Then** `text_elements` is an empty array `[]`.

---

### User Story 2 - Scene description focuses on visual elements only (Priority: P2)

As a content creator, I want the `scene_description` to contain only visual direction (composition, lighting, poses, expressions) without any text content mixed in, so that the image generation prompt is clean and focused on visual output.

**Why this priority**: Secondary to getting text_elements populated, but ensures the scene_description doesn't duplicate or conflict with the text_elements instructions sent to the image model.

**Independent Test**: Generate panel descriptions and verify that scene_description fields contain visual storytelling elements (camera angle, lighting, expressions, body language) but no inline dialog or text content descriptions.

**Acceptance Scenarios**:

1. **Given** a generated panel description, **When** reviewed, **Then** `scene_description` contains visual direction only — no quoted dialog, no "speech bubble" references, no "text reading" phrases.
2. **Given** a panel where a character speaks, **When** the description is generated, **Then** the character's expression and body language are in `scene_description`, while the actual words spoken are only in `text_elements`.

---

### Edge Cases

- What happens when the chapter has very long dialog passages? The prompt should instruct the LLM to select only the most impactful 1-2 lines per panel, keeping text short for image rendering.
- What happens when the same character speaks multiple times in one panel's scene? Each utterance should be a separate `text_elements` entry.
- What happens when the LLM still embeds dialog in scene_description despite instructions? The system should work with whatever the LLM returns — the prompt improvement is best-effort.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The panel description prompt MUST explicitly instruct the LLM that all character dialog from the narrative MUST be placed in the `text_elements` array as `speech_bubble` entries, never embedded in `scene_description`.
- **FR-002**: The prompt MUST instruct the LLM that `scene_description` should contain ONLY visual direction (poses, expressions, camera angles, lighting, composition) and MUST NOT include any quoted dialog, "speech bubble" references, or "text reading" phrases.
- **FR-003**: The prompt MUST include a concrete example showing a scene with dialog where the dialog is correctly placed in `text_elements` and the `scene_description` is purely visual.
- **FR-004**: The prompt MUST instruct the LLM to keep dialog text short (1-2 sentences per speech bubble) for optimal image rendering.
- **FR-005**: The prompt MUST instruct the LLM to use character IDs (not display names) in the `speaker` field of speech bubble text elements.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: When generating panels from a chapter with dialog, at least 50% of panels have non-empty `text_elements` with `speech_bubble` entries.
- **SC-002**: 100% of generated `scene_description` fields are free of embedded dialog text (no quoted speech, no "speech bubble" or "text reading" phrases).
- **SC-003**: The prompt includes at least one concrete JSON example demonstrating correct dialog placement in `text_elements`.

## Assumptions

- Feature 007 (Comic Prompt Quality) is complete — `text_elements` field exists on ComicPanel, `build_image_prompt` composes text instructions from `text_elements`, and the safeguard instruction is appended.
- The text LLM is capable of following structured output instructions when given clear examples and strong directive language. The current prompt is too weak — the LLM treats `text_elements` as optional.
- This feature only changes the prompt template in `PanelDescriptionGenerator#build_prompt`. No changes to ComicPanel, InstagramComicProducer, or any other file.
- Prompt improvements are best-effort — LLM behavior cannot be guaranteed, but stronger instructions with examples significantly improve compliance.
