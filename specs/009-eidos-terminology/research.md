# Research: Eidos Terminology Refactoring

**Feature**: 009-eidos-terminology
**Date**: 2026-04-01

## Decision 1: Namespace Unification Strategy

**Decision**: Merge `Book::` and `BookCore::` into a single `Eidos::` namespace.

**Rationale**: The current codebase has two top-level modules: `Book` (CLI, translator, reset) and `BookCore` (all core business logic — 46 files). This dual-namespace split is an artifact of the gem structure, not an intentional architectural boundary. Under Eidos, all code lives under `Eidos::` with sub-modules for organization:
- `Eidos::CLI::*` — CLI classes (replaces `Book::CLI::*`)
- `Eidos::*` — Core classes (replaces `BookCore::*`)
- `Eidos::Translator` (replaces `Book::Translator`)

**Alternatives considered**:
- Keep two namespaces (`Eidos::CLI` + `EidosCore::`) — rejected because the original split was accidental, not architectural
- Three namespaces (one per architectural layer) — premature; the user wants to split later but not now

## Decision 2: CLI Binary Split Strategy

**Decision**: Split the monolithic `bin/book` into six domain binaries, each being a thin Thor entry point that requires shared helpers from `Eidos::CLI::Helpers`.

**Binary → Current subcommands mapping**:

| Binary | Current Subcommands | New Top-Level Commands |
|--------|-------------------|----------------------|
| `bin/world` | `init`, `status`, `migrate`, `reset` | `new`/`init`, `status`, `migrate`, `reset` |
| `bin/bible` | `bible list`, `bible show`, `bible search`, `bible context`, `bible migrate`, `bible export` | `list`, `show`, `search`, `context`, `migrate`, `export` |
| `bin/canon` | `canon show/history/diff/rollback/update/impact`, `snapshot *`, `branch *`, `changeset *` | `show`, `history`, `diff`, `rollback`, `update`, `impact`, `snapshot *`, `branch *`, `changeset *` |
| `bin/produce` | `generate chapter/comic/illustration/prompt`, `agent *` (WriterAgent) | `chapter`, `comic`, `illustration`, `prompt`, `write` (agent) |
| `bin/translate` | `translate chapter/character/all` | `chapter`, `character`, `all` |
| `bin/publish` | `jekyll generate` | `jekyll` |

**Rationale**: Each binary maps to one architectural concern. Commands that were nested 2+ levels deep (`book generate chapter`) become natural top-level commands (`produce chapter`).

**Alternatives considered**:
- Keep single binary with renamed subcommands — rejected; user explicitly wants domain-specific binaries
- More binaries (separate `snapshot`, `branch`, `changeset`) — rejected; these are all canon-management concerns and belong together

## Decision 3: YAML Key Rename Mapping

**Decision**: Rename YAML keys in config files as follows:

**book_state.yml → world_state.yml**:
- `book:` → `world:` (top-level key)
- `book.target_chapters` → `world.target_chapters`
- `book.current_chapter` → `world.current_chapter`

**book_config.yml → world_config.yml**:
- No top-level `book:` key exists — keys are `generation:`, `localized:`, etc. These are content-neutral and stay as-is.

**Rationale**: Only keys that literally contain "book" need renaming. The `generation:` and `localized:` keys are already IP-neutral.

**Alternatives considered**:
- Rename `generation:` to `production:` — rejected; not requested and would be scope creep

## Decision 4: File Structure Under eidos/

**Decision**: Rename `book-generator/` to `eidos/`. Internal structure:

```
eidos/
├── bin/
│   ├── world
│   ├── bible
│   ├── canon
│   ├── produce
│   ├── translate
│   └── publish
├── lib/
│   ├── eidos.rb              # Main require entry point
│   └── eidos/
│       ├── cli/
│       │   ├── helpers.rb    # Shared CLI helpers (resolve_project_root, etc.)
│       │   ├── world.rb      # World CLI
│       │   ├── bible.rb      # Bible CLI
│       │   ├── canon.rb      # Canon CLI (includes snapshot, branch, changeset)
│       │   ├── produce.rb    # Produce CLI
│       │   ├── translate.rb  # Translate CLI
│       │   ├── publish.rb    # Publish CLI
│       │   └── version.rb
│       ├── world_config.rb   # (was book_config.rb)
│       ├── configuration.rb
│       ├── chapter_generator.rb
│       ├── ... (all other core files, unchanged names except BookCore→Eidos)
│       ├── models/
│       ├── producers/
│       ├── prompts/
│       ├── defaults/
│       └── agent_tools/
├── templates/
├── spec/
├── eidos.gemspec
├── Gemfile
└── README.md
```

**Rationale**: Mirrors current structure but under `eidos/` with `lib/eidos/` instead of `lib/book_core/`. CLI files are reorganized from one monolithic `cli.rb` into per-domain files.

## Decision 5: Require Path Strategy

**Decision**: All `require 'book_core/...'` become `require 'eidos/...'`. All `require 'book/...'` become `require 'eidos/cli/...'` or `require 'eidos/...'`.

**Key mappings**:
- `require 'book/cli'` → `require 'eidos/cli/world'` (or whichever binary)
- `require 'book_core/book_config'` → `require 'eidos/world_config'`
- `require 'book_core/chapter_generator'` → `require 'eidos/chapter_generator'`
- `require 'book_core/story_bible'` → `require 'eidos/story_bible'`

## Decision 6: Migration Approach for Existing Data

**Decision**: The `world migrate` command handles the one-time migration:
1. Move `books/<name>/` to `worlds/<name>/`
2. Rename `data/book_config.yml` → `data/world_config.yml`
3. Rename `data/book_state.yml` → `data/world_state.yml`
4. Rewrite `book:` key to `world:` in world_state.yml
5. Rename `data/book_metadata.yml` → `data/world_metadata.yml` (if exists)
6. Rewrite keys in world_metadata.yml (if exists)

**Rationale**: Single command, idempotent, with clear error messages for partial states.

## Decision 7: Test Migration Strategy

**Decision**: Tests are updated mechanically — find-and-replace namespaces/paths, then verify all pass. No test logic changes needed since behavior is identical.

**Key changes**:
- `BookCore::` → `Eidos::`
- `Book::CLI::` → `Eidos::CLI::`
- `book_dir` variables → `world_dir`
- File path references to `books/` → `worlds/`
- Config file references updated
- `require` statements updated
