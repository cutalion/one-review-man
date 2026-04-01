# Tasks: Instagram Comic Producer

**Input**: Design documents from `/specs/006-instagram-comic-producer/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/ruby-api.md, quickstart.md

**Tests**: Included — constitution Principle I (Test-First with Mock AI) requires RSpec coverage.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Phase 1: Setup

**Purpose**: Project structure and shared infrastructure for the Instagram comic producer

- [x] T001 Create directory structure: `book-generator/lib/book_core/producers/`, `book-generator/lib/book_core/models/`, and corresponding spec directories under `book-generator/spec/book_core/`
- [x] T002 Add mock image response entry to `book-generator/spec/support/mock_responses.yml` for MOCK_AI=true image generation (base64-encoded small PNG)
- [x] T003 Add mock text response entry to `book-generator/spec/support/mock_responses.yml` for MOCK_AI=true panel description generation (JSON array of scene descriptions)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core value objects and services that ALL user stories depend on

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T004 [P] Implement ComicPanel value object in `book-generator/lib/book_core/models/comic_panel.rb` — attrs: sequence, scene_description, characters, image_path; methods: to_h, initialize with keyword args
- [x] T005 [P] Implement ComicPanel spec in `book-generator/spec/book_core/models/comic_panel_spec.rb` — test initialization, to_h serialization, nil image_path default
- [x] T006 [P] Implement PanelSet model in `book-generator/lib/book_core/models/panel_set.rb` — attrs: source, art_style, image_format, canon_version, panels, generated_at; methods: to_h, save_sidecar(output_dir), self.load_sidecar(path), fully_generated?
- [x] T007 [P] Implement PanelSet spec in `book-generator/spec/book_core/models/panel_set_spec.rb` — test initialization, to_h, save_sidecar YAML output, load_sidecar round-trip, fully_generated? logic
- [x] T008 Implement CharacterAppearance in `book-generator/lib/book_core/character_appearance.rb` — initialize from character YAML hash, extract physical_appearance fields (age, skin_tone, hair, eyes, outfit, distinguishing_features), to_prompt method composing visual description string, self.extract_all(story_bible_path) class method reading all character YAML files
- [x] T009 Implement CharacterAppearance spec in `book-generator/spec/book_core/character_appearance_spec.rb` — test initialization from character hash, to_prompt output, extract_all with fixture character files, handling of missing physical_appearance fields
- [x] T010 Implement PanelDescriptionGenerator in `book-generator/lib/book_core/panel_description_generator.rb` — initialize with llm_service; generate(content:, characters:, panel_count:, art_style:) sends chapter text + character appearances to text LLM, parses response into Array<ComicPanel> with scene_description and characters populated
- [x] T011 Implement PanelDescriptionGenerator spec in `book-generator/spec/book_core/panel_description_generator_spec.rb` — test generate method returns correct panel count, scene descriptions populated, character references mapped, uses MOCK_AI text responses

**Checkpoint**: Foundation ready — all value objects, character extraction, and panel description pipeline tested and working

---

## Phase 3: User Story 1 — Generate comic panels from a source (Priority: P1) 🎯 MVP

**Goal**: Turn a narrative source (chapter) into a set of comic panel images with consistent character appearances

**Independent Test**: Run producer with a chapter number and verify it outputs the configured number of PNG files at the specified location, plus a YAML sidecar file with metadata and panel descriptions

### Tests for User Story 1

- [x] T012 [P] [US1] Write InstagramComicProducer spec in `book-generator/spec/book_core/producers/instagram_comic_producer_spec.rb` — test Producer module inclusion, producer_name/description/default_output_path DSL, produce method with mock LLM returning panel descriptions + mock images, verify ProducerResult fields, verify sidecar file written, verify PNG files created from base64 decode, verify character appearance injected into image prompts

### Implementation for User Story 1

- [x] T013 [US1] Implement InstagramComicProducer in `book-generator/lib/book_core/producers/instagram_comic_producer.rb` — include Producer module, set DSL (producer_name :instagram_comic, producer_description, default_output_path "content/comics"), initialize(project_root:, llm_service: nil), implement produce(snapshot:, config:, output:) that: (1) validates config, (2) reads chapter content from source, (3) extracts character appearances from Story Bible, (4) calls PanelDescriptionGenerator for scene descriptions, (5) for each panel calls LLMService.generate_image with scene + character prompt, (6) decodes base64 to PNG, (7) builds PanelSet and saves sidecar, (8) returns ProducerResult. Self-register with Producer.register(:instagram_comic, ...)
- [x] T014 [US1] Implement validate! override in `book-generator/lib/book_core/producers/instagram_comic_producer.rb` — validate source is present and valid (type + number), chapter file exists, panel_count > 0
- [x] T015 [US1] Add validation error specs to `book-generator/spec/book_core/producers/instagram_comic_producer_spec.rb` — test missing source raises ArgumentError, invalid source type raises ArgumentError, non-existent chapter raises ArgumentError, panel_count <= 0 raises ArgumentError

**Checkpoint**: User Story 1 complete — producer generates panels from a chapter with character consistency, outputs PNGs + YAML sidecar

---

## Phase 4: User Story 2 — Configure art style and panel layout (Priority: P2)

**Goal**: Allow configurable art style and panel count

**Independent Test**: Generate panels with different art_style and panel_count values, verify output reflects configuration

### Implementation for User Story 2

- [x] T016 [P] [US2] Add art style and panel count config handling in `book-generator/lib/book_core/producers/instagram_comic_producer.rb` — extract art_style from config with default "manga", extract panel_count with default 4, pass both to PanelDescriptionGenerator and include art_style in image generation prompts
- [x] T017 [P] [US2] Add art style and panel count specs to `book-generator/spec/book_core/producers/instagram_comic_producer_spec.rb` — test custom art_style appears in prompts, test custom panel_count produces correct number of panels, test defaults (4 panels, manga style)

**Checkpoint**: User Story 2 complete — art style and panel count are configurable with sensible defaults

---

## Phase 5: User Story 3 — Choose image dimensions for Instagram formats (Priority: P2)

**Goal**: Support square (1080x1080) and portrait (1080x1350) image formats

**Independent Test**: Generate panels with "square" and "portrait" format configs, verify generate_image called with correct size parameters

### Implementation for User Story 3

- [x] T018 [P] [US3] Add image format/size mapping in `book-generator/lib/book_core/producers/instagram_comic_producer.rb` — map "square" to "1024x1024" and "portrait" to "1024x1792" for generate_image size parameter, default to "square"
- [x] T019 [P] [US3] Add image format specs to `book-generator/spec/book_core/producers/instagram_comic_producer_spec.rb` — test square format passes "1024x1024" to generate_image, test portrait format passes "1024x1792", test default is square

**Checkpoint**: User Story 3 complete — both Instagram image formats supported

---

## Phase 6: User Story 4 — Generate panel descriptions before image generation (Priority: P3)

**Goal**: Support description-only mode that writes YAML sidecar without generating images, and re-generation from saved descriptions

**Independent Test**: Run producer with description_only: true, verify sidecar written with descriptions but no image generation calls made. Then run again without description_only, verify images generated from saved descriptions.

### Implementation for User Story 4

- [x] T020 [US4] Add description-only mode to `book-generator/lib/book_core/producers/instagram_comic_producer.rb` — when config[:description_only] is true, skip image generation loop, save PanelSet sidecar with nil image_paths, return ProducerResult with sidecar as only artifact
- [x] T021 [US4] Add re-generation from saved descriptions in `book-generator/lib/book_core/producers/instagram_comic_producer.rb` — before generating descriptions, check if sidecar file exists at output path; if so, load PanelSet from sidecar and use existing descriptions instead of calling text LLM
- [x] T022 [P] [US4] Add description-only mode specs to `book-generator/spec/book_core/producers/instagram_comic_producer_spec.rb` — test description_only skips image generation (verify LLMService.generate_image not called), test sidecar written with descriptions, test re-generation loads from existing sidecar
- [x] T023 [US4] Add edge case specs to `book-generator/spec/book_core/producers/instagram_comic_producer_spec.rb` — test missing character description warns but continues with placeholder, test partial image generation failure saves successful panels and reports error

**Checkpoint**: User Story 4 complete — description-only preview and re-generation from saved descriptions both work

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Registry integration, edge cases, and final validation

- [x] T024 Add producer registry spec to `book-generator/spec/book_core/producers/instagram_comic_producer_spec.rb` — test Producer.find(:instagram_comic) returns InstagramComicProducer, test Producer.all includes :instagram_comic
- [x] T025 Run full test suite with `MOCK_AI=true bundle exec rspec` from `book-generator/` and fix any failures
- [x] T026 Run `bundle exec rubocop` from `book-generator/` and fix any style violations
- [x] T027 Validate quickstart.md scenarios work against implemented code (manual smoke test)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion — BLOCKS all user stories
- **User Stories (Phase 3+)**: All depend on Foundational phase completion
  - US1 (Phase 3): Must complete first — establishes the producer
  - US2 (Phase 4): Can start after US1 — adds config options to existing producer
  - US3 (Phase 5): Can start after US1 — adds format mapping to existing producer
  - US4 (Phase 6): Can start after US1 — adds description-only mode
- **Polish (Phase 7)**: Depends on all user stories being complete

### User Story Dependencies

- **US1 (P1)**: Depends on Phase 2 only — core producer implementation
- **US2 (P2)**: Depends on US1 — extends config handling in the same producer file
- **US3 (P2)**: Depends on US1 — extends config handling in the same producer file. Can run in parallel with US2.
- **US4 (P3)**: Depends on US1 — adds mode to the same producer file. Can run in parallel with US2/US3.

### Within Each User Story

- Tests written alongside implementation (same producer file)
- Models/services before producer integration
- Core implementation before edge cases

### Parallel Opportunities

- T002 and T003 (mock responses) can run in parallel
- T004, T005, T006, T007, T008, T009 (foundational models/services) can run in parallel by pairs (implementation + spec)
- T010 depends on T004 (uses ComicPanel)
- T012, T016/T017, T018/T019 can run in parallel (different aspects of producer)
- US2 and US3 can run in parallel after US1 completes

---

## Parallel Example: Foundational Phase

```bash
# Launch all model implementations in parallel:
Task: "Implement ComicPanel in book-generator/lib/book_core/models/comic_panel.rb"
Task: "Implement PanelSet in book-generator/lib/book_core/models/panel_set.rb"
Task: "Implement CharacterAppearance in book-generator/lib/book_core/character_appearance.rb"

# Launch all model specs in parallel:
Task: "Implement ComicPanel spec in book-generator/spec/book_core/models/comic_panel_spec.rb"
Task: "Implement PanelSet spec in book-generator/spec/book_core/models/panel_set_spec.rb"
Task: "Implement CharacterAppearance spec in book-generator/spec/book_core/character_appearance_spec.rb"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (mock responses, directories)
2. Complete Phase 2: Foundational (ComicPanel, PanelSet, CharacterAppearance, PanelDescriptionGenerator)
3. Complete Phase 3: User Story 1 (InstagramComicProducer core)
4. **STOP and VALIDATE**: Run `MOCK_AI=true bundle exec rspec` — all tests green
5. Producer generates panels from a chapter — MVP complete

### Incremental Delivery

1. Setup + Foundational → Foundation ready
2. Add US1 → Test independently → MVP!
3. Add US2 → Art style + panel count configurable
4. Add US3 → Instagram image formats supported
5. Add US4 → Description-only preview + re-generation
6. Polish → Registry, rubocop, full validation

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- All tests run under MOCK_AI=true per constitution Principle I
- Image generation uses LLMService.generate_image (returns base64), decode with Base64.decode64
- Character appearance extraction follows IllustrationGenerator.inject_character_context pattern but as standalone class
- Output at native AI sizes (1024x1024 / 1024x1792) — Instagram auto-resizes
- YAML sidecar named panels_NNN.yml where NNN is zero-padded source identifier
