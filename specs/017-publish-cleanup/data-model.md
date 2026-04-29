# Data Model: `eidos publish jekyll` must not write into the source world

**Feature**: 017-publish-cleanup
**Date**: 2026-04-29

This feature has no Ruby data model — no new classes, no new YAML schemas. The "data" is the on-disk shape of two directories during one publish run. The entities below are conceptual: file-tree shapes the implementation must respect.

---

## Publish Run

**Trigger**: `eidos publish jekyll -w <source-world> --dest <destination>`

**Inputs**:
- `<source-world>`: a directory containing `data/world_config.yml`, `data/story_bible/`, `content/`, etc. Read-only during this run.
- `<destination>`: a directory where the Jekyll source tree is assembled. Empty, partially populated, or already-customized — the existing-site detection (`existing_site?`) handles all three.

**Outputs**:
- `<destination>/`: Jekyll source tree containing `_layouts/`, `_includes/`, `_chapters/`, `_characters/`, `_data/`, `_sass/`, `assets/`, `index.md`, `404.html`, `_config.yml`, etc.
- **No outputs to `<source-world>`.** This is the central invariant.

**Pre-condition**: `<source-world>/data/story_bible/` exists. (If absent, the exporter step is skipped — see existing behavior at `publish.rb:44`.)

**Post-condition**: For every file `f` under `<source-world>/`, `SHA256(f) before run == SHA256(f) after run`. No new files appear under `<source-world>/`. No files are removed from `<source-world>/`.

---

## Source World

**Path**: `worlds/<name>/`

**Structure** (as scaffolded; per-world variations possible):

```
worlds/<name>/
├── data/
│   ├── world_config.yml
│   ├── world_state.yml
│   ├── settings.yml
│   ├── strings.yml
│   ├── story_bible/
│   │   ├── characters/<id>.yml      # per-entity files (post feature 012)
│   │   ├── locations/<id>.yml
│   │   ├── facts.yml
│   │   ├── relationships.yml
│   │   └── plot_threads.yml
│   ├── canon_deltas/<id>.yml
│   └── forms/<name>.yml             # custom forms (optional)
├── content/
│   ├── chapters/NNN-chapter.md
│   ├── chapters/NNN-chapter.<lang>.md
│   ├── characters/<id>.md
│   ├── characters/<id>.<lang>.md
│   └── pieces/<form>/<id>.md
└── assets/
```

**Constraint enforced by this feature**: read-only during a publish run. Any file under this tree that exists before the run must exist with the same content after the run.

**Files the bug currently *adds* to this tree (and the fix removes)**:
- `data/world.yml`
- `data/story_facts.yml`
- (`data/characters.yml` is also written by the exporter, but a separate `data/characters.yml` may legitimately exist as part of the world's storage; the fix simply stops the publish path from writing it. The `bible export` subcommand still maintains it.)

---

## Destination `_data/` Block

**Path**: `<destination>/_data/`

**Required content** (consumed by Jekyll templates):
- `_data/strings.yml` — UI strings keyed by language. Templates: `_layouts/default.html`, `_includes/chapter_nav.html`, `_includes/toc_menu.html`.
- `_data/characters.yml` — characters in flat `{characters: {<id>: {...}}}` shape. Templates: `characters.md`, `characters.ru.md`, `_layouts/character.html`. (Also a `ru.characters` sub-key for the Russian variant.)
- `_data/world.yml` — world overview (currently unreferenced by templates, but written for forward compatibility).
- `_data/story_facts.yml` — facts/events (currently unreferenced by templates, but written for forward compatibility).
- Plus passthrough copies of every other file from `<source-world>/data/` (e.g., `world_config.yml`, `story_bible/`, `settings.yml`).

**Source of truth**:
- `strings.yml`, `world_config.yml`, etc. — copied verbatim from `<source-world>/data/` by the data-copy step.
- `world.yml`, `story_facts.yml`, `characters.yml` — *generated fresh* by `Eidos::StoryBibleExporter.export_to(<destination>/_data)` from the canonical per-entity files at `<source-world>/data/story_bible/`.

**Order of operations** (post-fix):
1. Copy `<source-world>/data/` → `<destination>/_data/`. This includes a stale `characters.yml` if one exists in the source.
2. Run `exporter.export_to(<destination>/_data)`. This *overwrites* `_data/world.yml`, `_data/story_facts.yml`, `_data/characters.yml` with freshly-generated versions sourced from `data/story_bible/` (per-entity).

The overlay order ensures the freshly-generated `characters.yml` always wins over any stale version copied from the source.

---

## Out-of-band entities (referenced, not authored by this feature)

- **`Eidos::StoryBibleExporter`** — engine class at `eidos/lib/eidos/story_bible_exporter.rb`. Has two relevant methods:
  - `export_for_jekyll!` (writes into `<project_root>/data/`) — used by `eidos bible export`. Untouched by this fix.
  - `export_to(dest_dir)` — writes the same three files to a caller-supplied directory. Used by this fix.
- **`Eidos::CLI::Publish`** — Thor class at `eidos/lib/eidos/cli/publish.rb`. The single file modified by this fix. Two-line change: redirect the exporter call (line 47–48) and reorder it so it runs after the data-copy step (lines 75–91).
- **`eidos/spec/eidos/cli/publish_spec.rb`** — new RSpec file with the regression test. Defined precisely in `contracts/source-world-untouched.md`.
