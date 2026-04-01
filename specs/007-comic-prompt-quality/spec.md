# Feature Specification: Comic Prompt Quality

**Feature Branch**: `007-comic-prompt-quality`
**Created**: 2026-04-01
**Status**: Draft
**Input**: User description: "comics generator should have better prompts/descriptions for images. It should describe ALL the text exactly as it should be, do not let image generation model generate text. For instance, for chapter 1 example, which is not committed, it generated 'to be continued ... chapter 4'"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Explicitly controlled text in panels (Priority: P1)

As a content creator, I want every piece of text that appears in a comic panel to be explicitly specified in the prompt so that the image model renders exactly the words I intend, rather than inventing its own text (which is often wrong, garbled, or nonsensical).

**Why this priority**: This is the core problem. Left unconstrained, image models invent text like "to be continued... chapter 4" on a chapter 1 panel. The prompt must dictate exactly what text appears — including speech bubbles, signs, screen content, sound effects — and explicitly instruct the model not to add any text beyond what is specified.

**Independent Test**: Generate comic panels from a chapter and verify that (1) every image prompt contains an explicit instruction that the only text in the image must be exactly what the prompt specifies, and (2) the scene descriptions spell out the exact wording for any text elements (speech bubbles, signs, sound effects).

**Acceptance Scenarios**:

1. **Given** a scene where a character speaks, **When** the panel description is generated, **Then** the prompt specifies the exact dialogue text to appear in the speech bubble (e.g., "speech bubble reading exactly: 'Another perfect review... how boring.'").
2. **Given** a scene with a sign or monitor, **When** the panel description is generated, **Then** the prompt specifies the exact text to show on the sign/monitor, or explicitly states the sign/monitor should show no readable text.
3. **Given** any image generation prompt, **When** sent to the image model, **Then** it includes an explicit instruction: "Do not add any text, words, or letters beyond what is explicitly specified in this prompt."
4. **Given** a panel with no intended text elements, **When** the image prompt is composed, **Then** it explicitly states "no text, no words, no letters, no speech bubbles anywhere in the image."

---

### User Story 2 - Stronger visual storytelling prompts (Priority: P2)

As a content creator, I want the scene descriptions to include rich visual storytelling direction (expressions, body language, camera angles, lighting, composition) so that each panel is cinematic and communicates the story moment effectively.

**Why this priority**: Better visual direction produces higher-quality images regardless of the text control improvements.

**Independent Test**: Generate panel descriptions and verify that each prompt includes explicit visual storytelling elements: character expressions, body language, camera angle/framing, lighting/mood, and compositional direction.

**Acceptance Scenarios**:

1. **Given** a narrative scene with emotional content, **When** the panel description is generated, **Then** it includes specific facial expressions and body language for each character.
2. **Given** any generated panel prompt, **When** reviewed, **Then** it includes at least: character appearance, action/pose, expression, camera angle or framing, and lighting or mood direction.

---

### Edge Cases

- What happens when a scene is primarily dialogue with no physical action? The prompt should still describe conversational poses and body language, plus specify the exact dialogue text for speech bubbles.
- What happens when the narrative references code on a screen? The prompt should specify whether to show abstract code patterns (no readable text) or specific short text (e.g., "screen showing the text '// TODO: fix this'").
- What happens when a sound effect is part of the scene (e.g., typing sounds)? The prompt should specify the exact onomatopoeia text if sound effects are desired (e.g., "sound effect text reading exactly: 'TAP TAP TAP'"), or omit them.
- What happens when the text LLM includes unintended text in a scene description? The image prompt composition step should still append the "no additional text" instruction as a safeguard.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The scene description generation step MUST instruct the text LLM to explicitly spell out the exact wording of every text element in each panel (speech bubbles, signs, screens, sound effects, captions) rather than describing them generically.
- **FR-002**: The scene description generation step MUST instruct the text LLM to indicate when a panel should have no text at all.
- **FR-003**: Every image generation prompt MUST include a safeguard instruction: "Do not add any text, words, or letters beyond what is explicitly specified in this prompt."
- **FR-004**: When a panel includes no intended text elements, the image prompt MUST explicitly state "no text, no words, no letters, no speech bubbles anywhere in the image."
- **FR-005**: Each panel prompt MUST include explicit visual storytelling elements: character appearance details, action or pose, facial expression, camera angle or framing suggestion, and lighting or mood direction.
- **FR-006**: The scene description generation prompt MUST instruct the text LLM to describe scenes with rich visual direction — camera angles, lighting, character expressions, body language, and composition — not just what is happening narratively.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of image generation prompts contain the "no additional text beyond what is specified" safeguard instruction.
- **SC-002**: For panels with intended text, 100% of scene descriptions specify the exact wording (not just "a speech bubble" but "a speech bubble reading exactly: '...'").
- **SC-003**: 100% of panel prompts include at least 4 of 5 visual storytelling elements (character appearance, action/pose, expression, camera/framing, lighting/mood).

## Assumptions

- The Instagram comic producer (feature 006) is complete and working. This feature modifies the prompt generation logic within the existing producer pipeline.
- AI image models can render short, explicitly specified text with reasonable accuracy when the prompt is clear and constrained. Longer or more complex text may still be imperfect, but explicit prompts are significantly better than letting the model invent text.
- The text LLM used for scene description generation is capable of following instructions about specifying exact text content and visual storytelling when explicitly prompted.
- This feature only changes prompt templates and composition logic — no changes to the image generation service, Producer Contract, or CLI interface.
