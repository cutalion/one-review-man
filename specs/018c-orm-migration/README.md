# Feature 018c — ORM Migration + WorldState Retirement

**Branch**: `018c-orm-migration`
**Date**: 2026-04-29
**Depends on**: 018a (chapter unification + canon revision counter), 018b (CLI cleanup)

## What this feature does

Two coupled changes:

### 1. Migrate `worlds/one-review-man` to the post-018a chapter shape

A one-shot Ruby script (`migrate.rb`) rewrites every English chapter file
under `worlds/one-review-man/content/chapters/` into the universal piece
shape produced by post-018a `PieceProducer`:

- Each chapter gains a hash `id` (ULID-shaped, 26-char uppercase hex), `form: chapter`, `category: text`, `canon_status: applied`, an integer `canon_version` (1..N in chapter-number order), and a `canon_delta_ref` pointing at a synthesized delta file.
- For each chapter, `data/canon_deltas/<delta_id>.yml` is written with empty section arrays (the original LLM tail block was never persisted, so we cannot reconstruct what entities each chapter introduced — we record a non-null `applied_at` timestamp matching the chapter's `generated_date`).
- `world_state.yml` gains `canon: { revision: 11 }` (the chapter count).

Existing chapter-specific frontmatter keys (`title`, `chapter_number`,
`summary`, `characters`, `new_characters`, `programming_themes`,
`comedy_elements`, `word_count`, `permalink`, etc.) are preserved
verbatim. Translated `*.ru.md` files are NOT touched — `Piece#from_file`'s
default-synthesis path still reads them.

The script is idempotent: a re-run skips any chapter that already has
both `id` and `canon_delta_ref` set.

### 2. Retire the FR-006a temporary in-place migration in `WorldState`

Per the FR-006a retirement plan baked into 018a's contract, once
`worlds/one-review-man` is migrated explicitly, the auto-recovery branch
in `Eidos::WorldState#current_revision` has no future caller. This
feature deletes that branch:

- `WorldState#current_revision` now raises `CorruptWorldError` when `canon.revision` is missing — same as it always did for a missing `world_state.yml` or non-integer / negative value.
- The error message names the migration script (`specs/018c-orm-migration/migrate.rb`) so a user with a similarly old world has a clear path forward.
- The `world_state_spec.rb` migration-specific examples are dropped; new strict-raise examples replace them.

## Running the migration

```bash
# Default: migrates worlds/one-review-man
ruby specs/018c-orm-migration/migrate.rb

# Preview only
ruby specs/018c-orm-migration/migrate.rb --dry-run

# Explicit world path
ruby specs/018c-orm-migration/migrate.rb path/to/world
```

## Verification

After running the migration:

- `eidos piece list --form chapter -w worlds/one-review-man` lists 11 chapters with hash ids and `canon_version` 1–11. ✓
- `eidos piece show <id> -w worlds/one-review-man` for any migrated chapter resolves cleanly. ✓
- `eidos canon review -w worlds/one-review-man` reports `0 findings.` ✓
- `eidos world status -w worlds/one-review-man` shows `Canon revision: 11`. ✓
- `data/canon_deltas/` contains 11 `.yml` files, one per chapter. ✓
- `data/world_state.yml` has `canon: { revision: 11 }`. ✓

## What this feature does NOT do

- Does not change any chapter body (only frontmatter is rewritten).
- Does not migrate translation files (`*.ru.md`) — they remain readable
  via `Piece#from_file`'s default synthesis.
- Does not reconstruct historical canon-delta entity entries — those
  were never persisted by the legacy generator. The synthesized deltas
  carry empty section arrays.
- Does not provide a Thor command. The migration is a one-shot script
  scoped to this project's single legacy world; turning it into a
  general-purpose CLI helper would re-introduce the kind of
  migration-helper surface 018b just retired.
