# Tasks: Comic Prompt Quality

**Input**: Design documents from `/specs/007-comic-prompt-quality/`
**Prerequisites**: plan.md, spec.md, research.md, quickstart.md

**Tests**: Included — constitution Principle I (Test-First with Mock AI) requires RSpec coverage.

**Organization**: Tasks are grouped by user story. Both stories modify the same files but target different aspects of prompt composition.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2)
- Include exact file paths in descriptions

## Phase 1: Setup

**Purpose**: Update foundational model and mock data to support text elements

- [x] T001 Add `text_elements` attribute to ComicPanel in `book-generator/lib/book_core/models/comic_panel.rb` — add `text_elements` (default: []) to attr_reader, initialize, and to_h serialization
- [x] T002 Update ComicPanel spec in `book-generator/spec/book_core/models/comic_panel_spec.rb` — add tests for text_elements attribute: default empty array, initialization with text elements, to_h includes text_elements
- [x] T003 Update mock panel descriptions in `book-generator/spec/support/mock_responses.yml` — add `text_elements` field to panel_descriptions JSON: panels 1 and 4 get speech bubbles, panel 3 gets a sound effect, panel 2 gets empty text_elements
- [x] T004 Update `generate_mock_panels` method in `book-generator/lib/book_core/panel_description_generator.rb` — return mock panels with text_elements (some with speech bubbles, some empty) to test both paths

**Checkpoint**: ComicPanel carries text_elements, mock data includes text elements for testing

---

## Phase 2: User Story 1 — Explicitly controlled text in panels (Priority: P1) 🎯 MVP

**Goal**: Every piece of text in a comic panel is explicitly specified in the prompt. Image prompts include safeguard instruction against model-invented text.

**Independent Test**: Generate comic panels from a chapter and verify that (1) PanelDescriptionGenerator prompt instructs LLM to specify exact text, (2) every image prompt contains safeguard instruction, (3) text elements from descriptions appear as explicit text instructions in image prompts, (4) text-free panels explicitly state "no text"

### Tests for User Story 1

- [x] T005 [P] [US1] Add text control specs to `book-generator/spec/book_core/panel_description_generator_spec.rb` — test that build_prompt output includes instructions for exact text specification (speech bubbles, signs, sound effects), includes instruction to indicate no-text panels, and requests text_elements in JSON schema
- [x] T006 [P] [US1] Add text safeguard specs to `book-generator/spec/book_core/producers/instagram_comic_producer_spec.rb` — test that build_image_prompt appends "Do not add any text, words, or letters beyond what is explicitly specified" to every prompt (regardless of text_elements content), test that panels with text_elements include exact text instructions (e.g., "speech bubble reading exactly: '...'"), test that panels with empty text_elements include "no text, no words, no letters, no speech bubbles anywhere in the image"

### Implementation for User Story 1

- [x] T007 [US1] Update `build_prompt` in `book-generator/lib/book_core/panel_description_generator.rb` — add instructions for the text LLM to: (1) specify exact wording of every text element (speech bubbles, signs, screens, sound effects), (2) indicate when a panel has no text, (3) include `text_elements` array in JSON schema with type/speaker/text fields
- [x] T008 [US1] Update `parse_response` in `book-generator/lib/book_core/panel_description_generator.rb` — extract `text_elements` from parsed JSON and pass to ComicPanel constructor
- [x] T009 [US1] Update `build_image_prompt` in `book-generator/lib/book_core/producers/instagram_comic_producer.rb` — (1) compose text element instructions from panel.text_elements (e.g., "speech bubble reading exactly: '...'"), (2) for panels with no text_elements add "no text, no words, no letters, no speech bubbles anywhere in the image", (3) always append safeguard: "Do not add any text, words, or letters beyond what is explicitly specified in this prompt."

**Checkpoint**: User Story 1 complete — all prompts control text explicitly, safeguard appended, text-free panels declared

---

## Phase 3: User Story 2 — Stronger visual storytelling prompts (Priority: P2)

**Goal**: Scene descriptions include rich visual direction — expressions, body language, camera angles, lighting, composition

**Independent Test**: Generate panel descriptions and verify each prompt includes at least 4 of 5 visual storytelling elements (character appearance, action/pose, expression, camera/framing, lighting/mood)

### Tests for User Story 2

- [x] T010 [P] [US2] Add visual storytelling specs to `book-generator/spec/book_core/panel_description_generator_spec.rb` — test that build_prompt instructs LLM to include visual storytelling elements: character expressions, body language, camera angle/framing, lighting/mood, composition direction

### Implementation for User Story 2

- [x] T011 [US2] Update `build_prompt` in `book-generator/lib/book_core/panel_description_generator.rb` — add visual storytelling instructions: each panel description must include character appearance/pose, facial expression, camera angle/framing, lighting/mood direction, and composition notes

**Checkpoint**: User Story 2 complete — scene descriptions include rich visual storytelling direction

---

## Phase 4: Polish & Cross-Cutting Concerns

**Purpose**: Validation and final checks

- [x] T012 Run full test suite with `MOCK_AI=true bundle exec rspec` from `book-generator/` and fix any failures
- [x] T013 Update PanelSet sidecar serialization in `book-generator/lib/book_core/models/panel_set.rb` — ensure text_elements are included in YAML sidecar output (to_h of panels already includes them via ComicPanel#to_h) and round-trip correctly via load_sidecar; default text_elements to [] when loading old sidecars that lack the field
- [x] T014 Validate quickstart.md scenarios work against implemented code (manual smoke test)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **User Story 1 (Phase 2)**: Depends on Setup (T001-T004) — model must support text_elements first
- **User Story 2 (Phase 3)**: Depends on Setup only — modifies same file as US1 but different section (visual storytelling vs text control). Should run after US1 to avoid merge conflicts.
- **Polish (Phase 4)**: Depends on both user stories being complete

### User Story Dependencies

- **US1 (P1)**: Depends on Phase 1 (Setup). Modifies panel_description_generator.rb and instagram_comic_producer.rb
- **US2 (P2)**: Depends on Phase 1 (Setup). Modifies panel_description_generator.rb only. Run after US1 since both touch the same file.

### Within Each User Story

- Tests written first (T005/T006 before T007-T009, T010 before T011)
- Prompt changes in PanelDescriptionGenerator before InstagramComicProducer (descriptions feed into image prompts)

### Parallel Opportunities

- T001 and T003 can run in parallel (different files: comic_panel.rb vs mock_responses.yml)
- T005 and T006 can run in parallel (different spec files)
- T010 can run in parallel with T006 (different spec files)

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001-T004)
2. Complete Phase 2: User Story 1 (T005-T009)
3. **STOP and VALIDATE**: Run `MOCK_AI=true bundle exec rspec` — all tests green
4. Text control and safeguard working — MVP complete

### Incremental Delivery

1. Setup → text_elements model + mock data ready
2. Add US1 → Text control + safeguard in all prompts → MVP!
3. Add US2 → Rich visual storytelling direction in prompts
4. Polish → Full validation and sidecar round-trip

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- All tests run under MOCK_AI=true per constitution Principle I
- This feature modifies 2 implementation files + their specs — no new files created
- text_elements is an array of hashes: `[{ "type" => "speech_bubble", "speaker" => "char_id", "text" => "Exact words" }]`
- Safeguard instruction appended to ALL image prompts, not just those with text elements
