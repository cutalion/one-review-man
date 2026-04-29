# Data Model: Unify the chapter producer + add a global canon revision counter

**Feature**: 018-unify-piece-producer
**Date**: 2026-04-29

This feature introduces one new on-disk field, one new Ruby class, and a uniform reshape of piece frontmatter. No new YAML files; no new directories.

---

## On-disk: `data/world_state.yml` — the `canon` mapping

**Path**: `worlds/<name>/data/world_state.yml`

**New top-level key** (post-018a):

```yaml
canon:
  revision: 0   # non-negative integer; 0 on scaffold, advances by 1 per delta apply
```

**Pre-existing keys that remain unchanged**: `world` (with `current_chapter`, `target_chapters`, etc.), `status` (with `last_generated`, `generation_count`, etc.).

**Lifecycle**:

| Trigger | Effect on `canon.revision` |
|---|---|
| `eidos world new` (scaffold) | Written as `0` |
| Successful `eidos produce <form>` | Increments by exactly 1 (atomic with delta apply) |
| Successful `eidos canon accept --finding=<id>` | No change (accept closes audit record only; bible was already updated at produce time) |
| Successful `eidos canon revert --finding=<id>` | Increments by exactly 1 (revert is itself a canon mutation — it applies an inverse delta) |
| Successful `eidos canon rollback <type> <id> <rev>` | Increments by exactly 1 (per-entity rollback is also a canon mutation) |
| `eidos produce ... --dry-run` | No change (dry-run skips disk writes entirely) |
| Read against an existing world that lacks the field | One-shot in-place migration — see `contracts/world-state-migration.md` |

**Constraint**: the field MUST advance atomically with the bible-mutating operation that triggered it. Either both succeed (bible writes + counter writes) or both fail (rollback path runs, counter is never advanced). See `contracts/canon-revision-atomicity.md`.

---

## In-memory: `Eidos::WorldState` (new class)

**File**: `eidos/lib/eidos/world_state.rb`

**Purpose**: encapsulate read/write of `data/world_state.yml`'s `canon` mapping; run the FR-006 in-place migration once per process per world; expose a minimal API to `CanonDelta#apply!`.

**Public API** (sketch):

```ruby
module Eidos
  class WorldState
    # Raised when world_state.yml is missing entirely (corrupt world).
    class CorruptWorldError < StandardError; end

    def initialize(world_path:)
    end

    # Returns the current canon.revision integer.
    # Runs the FR-006 in-place migration if the field is missing.
    # Raises CorruptWorldError if world_state.yml itself is missing.
    def current_revision
    end

    # Atomically writes canon.revision = current + 1 to disk.
    # Returns the new revision number.
    # Caller MUST be inside the same transaction-scope as the bible mutation
    # it represents (typically inside CanonDelta#apply!'s rescue block).
    def advance_revision!
    end
  end
end
```

**Constructor injection**: `CanonDelta#apply!` accepts `world_state:` kwarg defaulting to `WorldState.new(world_path: world_path)`. Tests pass an in-memory double.

**Lifecycle of the migration code**: see FR-006a — this class's migration logic is **temporary scaffolding** to be removed in/after feature 018c. The class itself stays; only the `current_revision` method's "migrate if missing" branch goes away.

---

## Piece frontmatter (post-018a, all forms including chapter)

**Universal fields** (every form):

```yaml
---
id: 01J9XYZA1B2C3D4E5F6G7H8J9K   # ULID-style hash, generated via PieceProducer#generate_ulid
form: chapter                     # form name as registered in FormRegistry
generated_date: 2026-04-29
canon_version: 17                 # integer (revision the piece was built from); OR a snapshot label if --snapshot was passed
canon_delta_ref: data/canon_deltas/<id>.yml   # the delta this piece authored
---
```

**Form-specific fields** (in addition):

| Form | Extra frontmatter fields |
|---|---|
| `chapter` | `title`, `summary`, `chapter_number` (integer), plus `permalink`, `lang` for Jekyll downstream |
| `vignette`, `short-story` | `title` if extracted from output |
| `haiku` | none |
| `comic-script` | none (panel structure is in body) |
| `portrait`, `illustration` | image-specific (alt text, prompt context — TBD by form definition, unchanged from today) |
| `social-post` | none (or `platform` if the form definition adds one) |

**Chapter-specific note**: `chapter_number` is the form-specific field that drives the on-disk filename. The filename is `format('%03d-chapter.md', chapter_number)`. `id` and `chapter_number` are independent — `id` is opaque and uniform; `chapter_number` is human-meaningful and chapter-only.

**The `canon_version: 'unversioned'` legacy value**: MUST NOT appear on newly-written pieces post-018a. If `WorldState#current_revision` cannot resolve a value (e.g. `world_state.yml` is missing), the producer raises rather than writing `'unversioned'`. Pre-existing piece files in legacy worlds may carry `canon_version: unversioned` — those are read-tolerant via `Piece#from_file`'s default-synthesis (untouched by this feature).

---

## `Form` schema extension — the `structured_output` flag

**File**: `eidos/lib/eidos/forms/chapter.yml` (and the `Form` class at `eidos/lib/eidos/form.rb`)

**New optional field**:

```yaml
name: chapter
category: text
structured_output: true     # NEW — chapter's LLM output is a JSON envelope, not a single body blob
prompt_template_path: ./chapter.prompt.txt
canon_context:
  - all_characters
  - recent_events
  - current_chapter
default_length: 1500
```

**Semantics**: when `structured_output: true`, `PieceProducer#produce` parses the LLM's response as a JSON envelope `{title, summary, new_characters, body}` (or a superset; the exact schema is per-form), extracts each field, threads them into the piece's frontmatter and body. When the flag is absent or `false`, `PieceProducer#produce` treats the response as a single body blob (current behavior for vignette, haiku, etc.).

**Why a flag instead of two producer classes**: D-001 — keeps Constitution Principle II (one producer contract) intact while letting forms with structured outputs declare themselves.

---

## Out-of-band entities (referenced, modified)

- **`Eidos::Producers::PieceProducer`** — gains structured-output dispatch. Its existing `current_canon_version` method changes: instead of returning `'unversioned'` on no-snapshot, it now returns `WorldState.new(world_path:).current_revision` (an integer). When `--snapshot` is pinned, returns the snapshot label (unchanged from today).
- **`Eidos::CanonDelta#apply!`** — gains `world_state:` kwarg; calls `world_state.advance_revision!` inside the existing `begin/rescue` block before stamping `@applied_at`.
- **`Eidos::ChapterGenerator`** — DELETED.
- **`Eidos::Producers::ChapterProducer`** — DELETED. The `Producer.register(:chapter, ChapterProducer)` registration at the bottom of that file goes away.
- **`Eidos::CLI::Produce#chapter`** — rewrites to a thin shortcut over `PieceProducer.new(world_path: ..., llm_service: ...).produce(form: 'chapter', prompt: ..., dry_run: ...)` with `chapter_number` injected.
- **`Eidos::CLI::Produce#write`** — DELETED.
- **`Eidos::CLI::World#new`** scaffold — writes `canon: { revision: 0 }` into the new world's `world_state.yml`.
- **`Eidos::CLI::Helpers#render_status_report`** — gains a "Canon revision: N" line, sourced from `WorldState.new(world_path: abs_root).current_revision`.
