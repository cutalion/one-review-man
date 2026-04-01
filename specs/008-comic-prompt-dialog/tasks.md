# Tasks: Comic Prompt Dialog

**Input**: Design documents from `/specs/008-comic-prompt-dialog/`
**Prerequisites**: plan.md, spec.md, quickstart.md

**Tests**: Included — constitution Principle I (Test-First with Mock AI) requires RSpec coverage.

**Organization**: Single user story — all tasks are sequential on the same file.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2)
- Include exact file paths in descriptions

## Phase 1: User Story 1 — LLM populates text_elements with dialog (Priority: P1) 🎯 MVP

**Goal**: Strengthen build_prompt so LLM places dialog in text_elements, not scene_description

**Independent Test**: Verify prompt text includes concrete examples and separation rules for dialog vs visual description

### Tests for User Story 1

- [x] T001 [US1] Add prompt dialog specs to `book-generator/spec/book_core/panel_description_generator_spec.rb` — test that build_prompt includes: (1) a concrete JSON example with non-empty text_elements containing speech_bubble entries, (2) explicit instruction that scene_description must NOT contain dialog, (3) instruction to keep dialog short (1-2 sentences), (4) instruction to use character IDs in speaker field

### Implementation for User Story 1

- [x] T002 [US1] Rewrite `build_prompt` in `book-generator/lib/book_core/panel_description_generator.rb` — strengthen prompt with: (1) explicit separation rules (dialog → text_elements, visual only → scene_description), (2) concrete positive example with dialog in text_elements and visual-only scene_description, (3) concrete negative example showing what NOT to do (dialog in scene_description), (4) instruction to keep speech bubble text to 1-2 short sentences, (5) instruction to use character IDs in speaker field

**Checkpoint**: Prompt now strongly guides LLM to populate text_elements with dialog

---

## Phase 2: Polish & Validation

- [x] T003 Run full test suite with `MOCK_AI=true bundle exec rspec` from `book-generator/` and fix any failures
- [x] T004 Validate quickstart.md scenarios work against implemented code

---

## Dependencies & Execution Order

- T001 before T002 (test-first)
- T003 after T002 (validation)
- T004 after T003 (manual verification)

## Implementation Strategy

### MVP First

1. Write test (T001)
2. Rewrite prompt (T002)
3. Validate (T003, T004)
4. Done — single prompt template change

---

## Notes

- This is a prompt-only change — no model, service, or interface modifications
- The fix targets the observed LLM behavior: dialog placed in scene_description instead of text_elements
- Key technique: concrete positive + negative examples in the prompt
