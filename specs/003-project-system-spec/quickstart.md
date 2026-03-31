# Quickstart: One Review Man

**Feature**: 003-project-system-spec
**Date**: 2026-03-31

## Prerequisites

- Ruby 3.3.5
- Bundler
- An OpenAI API key (for live generation) or `MOCK_AI=true` (for testing)

## Setup

```bash
# Install CLI dependencies
cd book-generator
bundle install

# Install Jekyll site dependencies
cd ../site
bundle install
```

## First Run (Mock Mode)

Generate a chapter without any API keys:

```bash
MOCK_AI=true book-generator/bin/book generate chapter -b books/one-review-man --auto
```

This creates `books/one-review-man/content/chapters/NNN-chapter.md` with deterministic mock content.

## Live Generation

```bash
export OPENAI_API_KEY=sk-...

# Generate the next chapter
book-generator/bin/book generate chapter -b books/one-review-man

# Preview the prompt without calling the AI
book-generator/bin/book generate prompt -b books/one-review-man
```

## Translation

```bash
# Translate a single chapter to Russian
book-generator/bin/book translate chapter 1 ru -b books/one-review-man

# Translate everything
book-generator/bin/book translate all ru -b books/one-review-man
```

## Publish Website

```bash
# Generate the Jekyll site
book-generator/bin/book jekyll generate -b books/one-review-man --dest site

# Serve locally
cd site
bundle exec jekyll serve
# → http://localhost:4000
```

## Story Bible

```bash
# List characters
book-generator/bin/book bible list characters -b books/one-review-man

# View a character
book-generator/bin/book bible show characters/kenji_yamamoto -b books/one-review-man

# Search facts
book-generator/bin/book bible search "standup" -b books/one-review-man
```

## Canon Management

```bash
# View revision history
book-generator/bin/book canon history character kenji_yamamoto -b books/one-review-man

# Compare revisions
book-generator/bin/book canon diff character kenji_yamamoto 1 2 -b books/one-review-man

# Create a branch for experimentation
book-generator/bin/book branch create alternate-ending -b books/one-review-man
```

## Testing

```bash
cd book-generator

# Run all tests (mock mode, no API keys needed)
bundle exec rspec

# Run a specific test
bundle exec rspec spec/chapter_generation_spec.rb

# With debug output
DEBUG_AI=1 bundle exec rspec
```

## Project Status

```bash
book-generator/bin/book status -b books/one-review-man
```

## Key Directories

| Path | Purpose |
|------|---------|
| `book-generator/` | Ruby gem: CLI + library |
| `books/one-review-man/data/` | Configuration and Story Bible |
| `books/one-review-man/content/` | Generated chapters and characters |
| `site/` | Generated Jekyll website (build artifact) |

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `OPENAI_API_KEY` | For live generation | OpenAI API key |
| `OPENROUTER_API_KEY` | For OpenRouter tasks | OpenRouter API key |
| `MOCK_AI` | No | Set to `true` for offline testing |
| `DEBUG_AI` | No | Set to `1` for verbose AI logging |
