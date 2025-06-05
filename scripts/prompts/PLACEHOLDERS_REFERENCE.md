# Placeholder Reference for One Review Man Prompts

This document lists all placeholders used in the prompt files that must be replaced when making LLM requests.

## Core Character Placeholders
- `{ONE_REVIEW_MAN_REAL_NAME}` - The real name of the protagonist (not his secret identity)
- `{QUANTUM_ANDROID_REAL_NAME}` - The real name of the android companion

## Chapter Generation Placeholders
- `{CHAPTER_NUMBER}` - The current chapter number being generated
- `{TARGET_LENGTH}` - Target word count for the chapter (e.g., "1500")
- `{PREVIOUS_CHAPTERS_SUMMARY}` - Summary of previous chapters for continuity
- `{CHARACTER_CONTEXT}` - Context about existing characters
- `{SPECIAL_INSTRUCTIONS}` - Any special instructions for this chapter

## Character Generation Placeholders
- `{CHARACTER_TYPE}` - Type of character being created (e.g., "hero", "villain", "side character")
- `{EXISTING_CHARACTERS_CONTEXT}` - Context about already created characters
- `{SPECIAL_REQUIREMENTS}` - Special requirements for this character

## Character Consistency Placeholders
- `{CHARACTER_NAME}` - Name of existing character being maintained
- `{CHARACTER_DESCRIPTION}` - Description of existing character
- `{CHARACTER_TRAITS}` - Personality traits of existing character
- `{CHARACTER_CODING_LEVEL}` - Programming skill level of existing character
- `{CHARACTER_RELATIONSHIP}` - Relationship to One Review Man

## Plot Device Tracking
- `{USED_PLOT_DEVICES}` - List of recently used plot devices to avoid repetition

## Notes
- All placeholders MUST be replaced before sending prompts to LLM
- Real name placeholders should be consistent across all chapters
- Character context should include relevant character information for the specific generation task
- Special instructions should be empty string if not needed 
