# Data Model: Fix UX Bugs and Unify Story Bible

**Feature**: 012-fix-ux-unify-bible
**Date**: 2026-04-17

This feature is primarily a **simplification** of existing data flow — not an expansion of the domain. The only new entity is `SeedResult`. Everything else is a change of *where* data is read from, not *what shape it has*.

---

## Existing entities (unchanged shape, clarified ownership)

### World

- **Lives at**: `worlds/<name>/` directory.
- **Owns exactly one**: Story Bible (`data/story_bible/`).
- **Owns exactly one**: settings file (`data/settings.yml`).
- **Owns zero of**: `data/world.yml`, `data/story_facts.yml` (these stop existing for any world Eidos creates).

### Story Bible

- **Store**: `data/story_bible/` — directory of YAML files (one per domain: `characters.yml`, `locations.yml`, `facts.yml`, `relationships.yml`, `plot_threads.yml`).
- **Writers**: `Eidos::StoryBible` class and its storage backend (`Storage::YamlFile` or `Storage::Memory` in tests).
- **Readers**: ALL surfaces — SDK (`Eidos::World#bible`), CLI (`eidos bible ...`), and from now on `ChapterGenerator` (previously read `data/world.yml`/`data/story_facts.yml` directly).

### Character / Location / Fact / Relationship / PlotThread

No schema change to these engine entities. The only new field-level convention is the optional `origin` marker for seeded entries (see below).

**New field convention** (additive, backward compatible):

| Field | Type | Values | Purpose |
|---|---|---|---|
| `origin` | string, optional | `"seed"`, `"user"`, `"generated"` | Tag indicating how the entry came to exist. Missing field is treated as `"user"` for display purposes. |
| `origin_note` | string, optional | free text | Short human note (e.g., `"derived from premise"`). Displayed next to the entry in `eidos bible list`. |

Neither field is required. Existing entries with neither field continue to work.

### Chapter

No schema change. The **title** field that was effectively "Chapter N" becomes an LLM-supplied substantive string; the number and the title coexist.

### Settings

No schema change. The `content.model` slot is now the effective override target for `--content-model` (fix already on `main`; this feature adds a regression test).

---

## New entity: SeedResult

A small in-memory value object returned by `Eidos::SeedExtractor#extract`. Never persisted directly — its contents are written into the Story Bible as regular entries with `origin: "seed"`.

| Field | Type | Description |
|---|---|---|
| `characters` | `Array<Hash>` | Candidate character entries, each shaped like a Character record. Empty array on LLM failure. |
| `locations` | `Array<Hash>` | Candidate location entries. |
| `facts` | `Array<String>` | Candidate world facts (one-sentence strings). |
| `warnings` | `Array<String>` | Non-fatal warnings (e.g., "LLM returned malformed JSON; nothing seeded"). Empty on success. |

Validation rules:

- On LLM timeout or network error: return `SeedResult.new(characters: [], locations: [], facts: [], warnings: ["seed extraction skipped: <reason>"])`. Never raise.
- On malformed JSON: same pattern — empty arrays, single warning.
- On success: cap the arrays to a small fixed size (≤3 characters, ≤2 locations, ≤3 facts) to prevent runaway LLM output.

State transitions: none. This object is created, read once by `cli/world.rb`, and discarded.

---

## Relationships

```
World  ──owns──▶  StoryBible  ──contains──▶  Character, Location, Fact, Relationship, PlotThread
   │
   └──owns──▶  Settings
   │
   └──owns──▶  Chapter(s)  ──generated_by──▶  ChapterGenerator  ──reads_from──▶  StoryBible
                                                                 ▲
                                                                 │
                                           ChapterGenerator  ──(no longer reads)──▶  data/world.yml, data/story_facts.yml  [REMOVED]

SeedExtractor  ──consumes──▶  premise (string)
             ──writes_to──▶  StoryBible (via normal APIs)
```

Key rule: **no arrow from any runtime component to `data/world.yml` or `data/story_facts.yml`**. The only remaining writer of those paths is `StoryBibleExporter`, and its target is the Jekyll site's `_data` directory, not the world's `data/` directory.

---

## Migration rules

**None.** Per the clarification on Q3, Eidos does not carry any runtime migration code. Data in the one production world is cleaned up manually.

---

## Validation rules by requirement

| Requirement | Data-level validation |
|---|---|
| FR-010 | All lore reads in `ChapterGenerator` and `Translator` go through `StoryBible`; code review grep must return zero hits for `data/world.yml` / `data/story_facts.yml` in the engine layer after this feature. |
| FR-011, FR-012 | Integration test: add a character via SDK → generate a chapter → debug artifact (`tmp/ai_debug/last_prompt.txt`) contains that character's name. |
| FR-013, FR-014 | Code-level grep: runtime reads of legacy files must be zero. Spec assertion: `eidos produce chapter` output on a world with stray `data/world.yml` must not reference it. |
| FR-015 | Interactive prompt presence + `--quick` skip + `--no-seed` skip — three unit tests. |
| FR-017 | Seeded entries have `origin: "seed"` and are rendered as such by `eidos bible list`. |
