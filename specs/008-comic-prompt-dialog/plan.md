# Implementation Plan: Comic Prompt Dialog

**Branch**: `008-comic-prompt-dialog` | **Date**: 2026-04-01 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/008-comic-prompt-dialog/spec.md`

## Summary

Strengthen the panel description prompt so the text LLM reliably populates `text_elements` with dialog from the chapter narrative instead of embedding dialog in `scene_description`. The fix is a prompt template change in one method: `PanelDescriptionGenerator#build_prompt`.

## Technical Context

**Language/Version**: Ruby 3.3.5, `frozen_string_literal: true`
**Primary Dependencies**: BookCore (existing)
**Storage**: N/A
**Testing**: RSpec with MOCK_AI=true
**Target Platform**: CLI (existing)
**Project Type**: CLI tool (prompt template fix)
**Performance Goals**: N/A
**Constraints**: Single method change — `build_prompt` in `panel_description_generator.rb`
**Scale/Scope**: 1 file modified, corresponding spec updated

## Constitution Check

| Principle | Status |
|-----------|--------|
| I. Test-First with Mock AI | PASS |
| II. Producer Contract | PASS — no interface changes |
| III. Dependency Injection | PASS |
| IV. Canon Integrity | PASS |
| V. Security by Default | PASS |
| VI. Pluggable AI Services | PASS |
| VII. Separation of Concerns | PASS |

## Project Structure

### Source Code (files to modify)

```text
book-generator/
├── lib/book_core/
│   └── panel_description_generator.rb   # Modify build_prompt only
└── spec/book_core/
    └── panel_description_generator_spec.rb  # Add/update prompt content specs
```

## Implementation Approach

The current prompt has these weaknesses that cause the LLM to ignore `text_elements`:

1. **No concrete example** — The JSON schema example shows `text_elements` but doesn't demonstrate a realistic scene with dialog properly split between `scene_description` (visual only) and `text_elements` (dialog).
2. **Weak separation instruction** — The prompt says "every piece of text MUST be in text_elements" but doesn't explicitly say "DO NOT put dialog in scene_description".
3. **No negative example** — The LLM doesn't know what's wrong, only what's right.

### Fix strategy:

1. Add a **concrete positive example** showing a scene with dialog: `scene_description` has only visual direction, `text_elements` has the speech bubbles.
2. Add a **concrete negative example** showing what NOT to do: dialog embedded in `scene_description`.
3. Add **explicit separation rules** at the top of the prompt instructions, before the JSON schema.
4. Add instruction to keep dialog short (1-2 sentences) for image rendering.
5. Use character IDs (not display names) in the `speaker` field.
