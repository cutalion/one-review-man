# Quickstart: Eidos Terminology Refactoring

**Feature**: 009-eidos-terminology
**Date**: 2026-04-01

## What Changes

This refactoring renames the project from "book-generator" to "Eidos" and replaces book-centric terminology with IP/storyworld language. It is a mechanical rename — no behavior changes.

## After Migration

```bash
# Create a new world
world new -w worlds/my-world

# Check status
world status -w worlds/one-review-man

# Story Bible
bible list characters -w worlds/one-review-man
bible show characters/saitama -w worlds/one-review-man

# Canon management
canon snapshot create v1 -w worlds/one-review-man
canon branch create alternate-timeline -w worlds/one-review-man

# Produce content
produce chapter -w worlds/one-review-man --model gpt-4o-mini
produce comic -w worlds/one-review-man
produce write -w worlds/one-review-man  # agent-based

# Translate
translate all ru -w worlds/one-review-man

# Publish
publish jekyll -w worlds/one-review-man --dest site
```

## Migrating Existing Data

```bash
# One command migrates everything:
# - Moves books/ → worlds/
# - Renames book_config.yml → world_config.yml
# - Renames book_state.yml → world_state.yml
# - Rewrites YAML keys (book: → world:)
world migrate -w books/one-review-man
```

## For Developers

### Namespace Changes

```ruby
# Before
require 'book_core/chapter_generator'
BookCore::ChapterGenerator.new(...)

# After
require 'eidos/chapter_generator'
Eidos::ChapterGenerator.new(...)
```

### Running Tests

```bash
cd eidos
MOCK_AI=true bundle exec rspec
```
