# Generic Placeholder Reference

This document lists all placeholders used in the generic prompt templates that must be replaced when making LLM requests.

**Note:** These placeholders are used by the `PromptUtils.build_prompt()` method to replace template variables with actual content.

## Story Context Placeholders
- `{STORY_TITLE}` - The title of the story being generated
- `{STORY_GENRE}` - The genre/style of the story (e.g., "fantasy", "mystery", "comedy")
- `{STORY_PREMISE}` - The one-paragraph premise/description for the whole story (the driving conflict the LLM must stay anchored to)
- `{STORY_SETTING}` - The primary setting of the story
- `{STORY_STYLE}` - Writing style guidelines
- `{PRIMARY_LOCATION}` - Main location where story takes place
- `{WORLD_DETAILS}` - Important world-building information

## Piece Placeholders (all forms)

A "piece" is any generated artifact — chapter, haiku, vignette, short-story,
comic-script, portrait prompt, social-post, illustration prompt, or a custom
form a world defines in `data/forms/`. These placeholders are available to
every form's template.

- `{USER_PROMPT}` - Free-form user guidance passed via `--prompt` on the CLI
- `{LENGTH_TARGET}` - Form shape/length hint (e.g. "1500 words", "3 lines — 5/7/5 syllables", "single image, square aspect ratio"). Resolution order: `--length` flag → form's `default_length`/`default_shape` → (chapter form only) `world_config.chapter_length_target`
- `{CANON_CONTEXT}` - Canon material the form declared it needs: characters,
  locations, facts, recent events — formatted for the LLM
- `{CHARACTER_CONTEXT}` - Context about existing characters (subset of canon context)
- `{CHARACTER_GUIDELINES}` - Guidelines for how characters should behave
- `{SPECIAL_INSTRUCTIONS}` - Any extra instructions for this piece

## Chapter Form Placeholders

The chapter form predates the generic piece model and carries extra tokens:

- `{CHAPTER_NUMBER}` - The current chapter number being generated
- `{TARGET_LENGTH}` - Alias for `{LENGTH_TARGET}` on the chapter form (word count, e.g. "1500")
- `{PREVIOUS_CHAPTERS_SUMMARY}` - Summary of previous chapters for continuity

## World Consistency Placeholders
- `{ESTABLISHED_LOCATIONS}` - Locations already mentioned in previous chapters
- `{CULTURAL_PATTERNS}` - Cultural elements and patterns established
- `{ESTABLISHED_FACTS}` - Important facts established in previous chapters

## Character Generation Placeholders
- `{CHARACTER_NAME}` - Name of character being created or referenced
- `{CHARACTER_DESCRIPTION}` - Description of existing character
- `{GENRE_GUIDELINES}` - Genre-specific guidelines for character creation

## Plot Development Placeholders
- `{USED_PLOT_DEVICES}` - List of recently used plot devices to avoid repetition

## Notes
- All placeholders MUST be replaced before sending prompts to LLM
- Story-specific placeholders should be consistent across all chapters
- Character context should include relevant character information for the specific generation task
- Special instructions should be empty string if not needed