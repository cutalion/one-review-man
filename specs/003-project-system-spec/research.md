# Research: One Review Man System Specification

**Feature**: 003-project-system-spec
**Date**: 2026-03-31

## R1: AI Provider Abstraction Strategy

**Decision**: LLMService provides a unified interface across multiple AI providers (OpenAI, OpenRouter). Provider selection is configured per task (generation, translation, summarization, illustration, agent writing) via `data/settings.yml`. The service resolves the correct provider, model, and parameters at call time based on task type.

**Rationale**: Different tasks benefit from different models (e.g., cheaper models for translation, image-capable models for illustration, reasoning models for chapter generation). Per-task configuration lets the author optimize cost and quality without code changes.

**Alternatives considered**:
- **Single provider/model for everything**: Simpler but forces tradeoffs between quality and cost across all tasks.
- **Provider-specific service classes**: More explicit but duplicates common logic (prompt formatting, error handling, debug logging).

## R2: Configuration Layering Strategy

**Decision**: Configuration is resolved by deep-merging four layers in priority order: CLI options > environment variables > project settings (`data/settings.yml`) > default settings (`lib/book_core/defaults/settings.yml`). The `BookCore::Configuration` class handles this merge.

**Rationale**: Layered configuration lets the author set project-wide defaults while overriding per-invocation for experimentation (e.g., `--content-model gpt-4o` to test a different model). Environment variables handle deployment-specific values (API keys).

**Alternatives considered**:
- **Single config file only**: No CLI overrides, less flexible for experimentation.
- **Per-command config files**: Too many files to manage for a single-user tool.

## R3: Content Storage Strategy (Flat Files)

**Decision**: All content (chapters, characters) is stored as Markdown files with YAML frontmatter. All data (Story Bible, configuration, state) is stored as YAML files. No external database.

**Rationale**: Human-readable and git-friendly. The author can inspect, edit, and version-control content with standard tools. At the project's scale (dozens of chapters, dozens of characters), flat files perform well and add zero operational complexity.

**Alternatives considered**:
- **SQLite**: Better query performance but breaks human readability and the "files as source of truth" principle.
- **JSON**: Valid but YAML is more readable for multi-line content and already established in the project.

## R4: Mock AI Testing Strategy

**Decision**: When `MOCK_AI=true`, the MockLLMService replaces the real LLMService via RUBYOPT injection. It returns deterministic canned responses from `spec/support/mock_responses.yml`. All tests run in this mode by default.

**Rationale**: Deterministic tests that never flake, never burn API credits, and run fully offline. The RUBYOPT injection approach means test code doesn't need conditional logic — the mock is injected transparently.

**Alternatives considered**:
- **WebMock/VCR recording**: Requires initial live API calls and recordings become stale when prompts change.
- **Conditional logic in tests**: Pollutes test code with `if mock_mode?` branches.
- **Constructor injection only**: Requires every test to explicitly set up the mock; RUBYOPT is simpler globally.

## R5: Translation Architecture

**Decision**: Translation uses the same LLMService with a structured prompt that includes character name glossary, terminology rules, and cultural adaptation guidelines from `book_config.yml`. The LLM returns structured JSON (translated title, summary, content). Output is written as a language-suffixed file alongside the original.

**Rationale**: Using AI for translation (rather than machine translation APIs) preserves the comedic tone, handles programming humor, and applies project-specific glossary rules. The structured JSON response enables reliable parsing of translated components.

**Alternatives considered**:
- **Machine translation APIs (Google Translate, DeepL)**: Cheaper but loses comedic nuance and can't apply custom glossary rules.
- **Separate translation pipeline**: More modular but unnecessary complexity for a two-language project.

## R6: Jekyll Site Generation Strategy

**Decision**: The `jekyll generate` command copies templates from `book-generator/templates/jekyll/`, processes placeholders (book title, author, etc.), and copies content files into Jekyll-compatible collections. The site is a build artifact — always regenerable from source.

**Rationale**: Template-based generation with placeholder replacement is simple and deterministic. The author can customize the Jekyll site (adding pages, changing styles) and regeneration only overwrites template-sourced files.

**Alternatives considered**:
- **Direct Jekyll plugin**: Tighter integration but couples the book data model to Jekyll's plugin API.
- **Static site generators other than Jekyll**: Jekyll is well-known, Ruby-native (matching the project), and has GitHub Pages support.

## R7: Story Bible as Single Source of Truth

**Decision**: The Story Bible (`data/story_bible/`) is the canonical data store for all story entities (characters, locations, facts, relationships, plot threads). Character Markdown profile files in `content/characters/` are generated artifacts. When generating chapters, context is drawn from the Story Bible, not from content files.

**Rationale**: A single source of truth prevents drift between the canonical universe and published content. The Story Bible supports structured queries (list, search, filter by chapter) that would be difficult with unstructured Markdown files.

**Alternatives considered**:
- **Content files as source of truth**: Simpler but can't support structured queries, revision tracking, or branching.
- **Dual source of truth**: Inevitable sync bugs and confusion about which is authoritative.

## R8: Error Handling Strategy

**Decision**: AI failures (timeouts, API errors, rate limits) cause immediate abort with a clear error message. No retry logic. Malformed AI output (missing required fields) is rejected entirely with a validation error — no files are saved. Missing API keys cause abort before any AI call is attempted.

**Rationale**: For a single-user CLI tool where the author watches the terminal, fail-fast is the simplest and most predictable behavior. The author can diagnose the issue and re-run. Partial saves of broken output would create downstream problems (broken site generation, inconsistent Story Bible).

**Alternatives considered**:
- **Automatic retry with backoff**: Adds complexity and masks persistent issues.
- **Save partial output**: Creates more problems than it solves — broken frontmatter, incomplete chapters.

## R9: Agent-Based Writing Architecture

**Decision**: The WriterAgent uses LLM function calling (tool use) to query the Story Bible before composing a chapter. It loops up to 20 iterations, making tool calls (get_character, list_characters, get_location, get_chapter_summaries, get_plot_threads, search_facts, etc.) until it calls `submit_chapter` with the complete output.

**Rationale**: Agent-based generation produces more contextually aware chapters because the AI decides what context it needs. The tool-calling interface is natural for LLMs and keeps the Story Bible query logic in the tool definitions rather than the prompt.

**Alternatives considered**:
- **Dump all context into the prompt**: Simpler but wastes tokens on irrelevant context and hits token limits for large Story Bibles.
- **Pre-selected context by the system**: The system can't predict which context the AI needs for creative writing.

## R10: Prompt Template System

**Decision**: Prompt templates are plain text files with `{PLACEHOLDER}` markers. PromptProvider searches for templates first in the project's `prompts/` directory (project-specific overrides), then in the core library's `prompts/` directory (defaults). Placeholders are replaced by the generation engine with contextual data.

**Rationale**: Plain text templates are easy to edit, version, and customize per project. The two-tier search (project → core) enables per-book customization without modifying the shared library.

**Alternatives considered**:
- **ERB or Liquid templates**: More powerful but overkill for simple placeholder replacement and adds template engine complexity.
- **Inline prompts in Ruby code**: Harder to edit and customize; mixes concerns.
