# Phase 0 Research: `eidos publish jekyll` must not write into the source world

**Feature**: 017-publish-cleanup
**Date**: 2026-04-29
**Status**: Resolved — no `NEEDS CLARIFICATION` markers remain

## D-001 — Relocate vs. drop the exporter call

**Decision**: Relocate the call to write at the publish destination instead of removing it.

**Rationale**:
- A grep of `eidos/templates/jekyll/` (`grep -rnE 'site\.data\.|_data/'`) shows the templates reference `site.data.characters.characters[...]`, `site.data.characters.ru.characters[...]`, and `site.data.strings[...]`. They do *not* reference `site.data.world` or `site.data.story_facts`.
- The exporter writes three files: `world.yml`, `story_facts.yml`, and `characters.yml`. The first two are currently unreferenced by templates; `characters.yml` is the one templates need.
- `worlds/<name>/data/characters.yml` exists as a stand-alone file too (top-level, not under `data/story_bible/`), and the data-copy step in publish copies it to the destination's `_data/`. But that file may go stale relative to the per-entity bible files at `data/story_bible/characters/`. The exporter regenerates it from the canonical per-entity sources.
- Dropping the exporter call would mean `<dest>/_data/characters.yml` is whatever the user last wrote (or whatever a prior `bible export` left behind), which can drift from the canonical bible. Relocating preserves the freshness guarantee.

**Alternatives considered**:
- *Drop the exporter call entirely; rely on the data-copy step.* Rejected: would silently produce stale character data on the published site whenever the user adds or edits a character via `produce` and then publishes without first running `bible export`. The bug we'd fix is "publish writes into source"; the bug we'd introduce is "publish silently uses stale data."
- *Update Jekyll templates to read from `_data/story_bible/characters/<id>.yml` directly.* Rejected: scope creep. This feature is about stopping the source-world write; template restructuring would be a separate spec.

## D-002 — Where to call `export_to(...)`

**Decision**: Call `exporter.export_to(File.join(dest_dir, '_data'))` AFTER the data-copy step, so the exporter's output overlays whatever the data-copy already placed at the destination.

**Rationale**:
- The current `publish.rb` flow runs the exporter at line 47 (BEFORE template + data copying), so the exporter writes into the source's `data/`, and the data-copy step (line 75–91) then copies the source's `data/` to `<dest>/_data/` — this is how the exporter's output transitively reached the destination.
- If we redirect the exporter to write at `<dest>/_data/` but keep it BEFORE the data-copy, the data-copy step's `FileUtils.rm_rf(dst)` would nuke the exporter's freshly-written files before the copy happens. Bad.
- Reversing the order — data-copy first, exporter second — keeps the exporter's output as the *final* word on `<dest>/_data/{world,story_facts,characters}.yml`. The data-copy step still places everything else (`strings.yml`, the per-entity `story_bible/` tree, `settings.yml`, etc.) at the destination from the source.
- The data-copy's `_data/characters.yml` (sourced from `worlds/<name>/data/characters.yml`) gets overwritten by the exporter's freshly regenerated `characters.yml`. That's the desirable outcome — fresher data wins.

**Alternatives considered**:
- *Have the exporter write to a temp dir, then merge into `<dest>/_data/` after the data-copy.* Rejected: more code, more failure modes (cleanup of temp dir on failure, etc.), no functional gain over a simple reorder.
- *Keep the exporter call where it is and add a "no-op in source" mode to `StoryBibleExporter`.* Rejected: introduces conditional behavior into the exporter class that complicates `bible export`'s contract; the simpler answer is to use the `export_to` method that already exists.

## D-003 — Should `Eidos::StoryBibleExporter#export_for_jekyll!` be removed or renamed?

**Decision**: Keep `export_for_jekyll!` exactly as it is.

**Rationale**:
- The method has *two* call sites:
  - `eidos/lib/eidos/cli/publish.rb:47` — the buggy call we're removing.
  - `eidos/lib/eidos/cli/bible.rb:32` — the `eidos bible export` user-facing subcommand. Its registered description is `"Export Story Bible to Jekyll-compatible format (updates data/*.yml files)"`. The "(updates data/*.yml files)" parenthetical makes the intent explicit: this command *deliberately* writes Jekyll-shaped YAML into the source world's `data/` directory. A creator who wants those files committed alongside their world (e.g. for a downstream tool that reads them) uses this command on purpose.
- After the publish fix lands, `bible export` is the only caller of `export_for_jekyll!`. The method's contract — "write Jekyll-data files into this project's `data/` directory" — perfectly matches that one user-facing intent. No reason to rename or remove.
- Keeping the public API unchanged also avoids needing a deprecation cycle for any downstream consumer who happens to call this engine method directly (the method lives in the public `Eidos::` namespace).

**Alternatives considered**:
- *Rename to `export_to_world_data!` for clarity.* Rejected: pure cosmetic change. The current name is already accurate within the bible-export use case (it does export "for Jekyll" by producing Jekyll-shaped data files). Breaking the public API for a clarity-only renaming would cost more than it saves.
- *Remove the method and inline the logic into `bible.rb` and the new publish.rb path.* Rejected: code duplication; `bible export` and `publish` would both grow inline references to the same write logic.

## Other decisions left to plan execution (no research needed)

- **Test scaffolding shape.** The new `publish_spec.rb` uses RSpec's `Dir.mktmpdir` to create a throwaway source world and a sibling destination. Snapshot via `Dir.glob` + `Digest::SHA256.hexdigest`. No Eidos-specific test infrastructure needed; this is straightforward Ruby + Thor.
- **MOCK_AI handling.** The publish path doesn't invoke the LLM. The test still sets `MOCK_AI=true` to comply with Constitution Principle I (every spec must run cleanly under mock mode), even though no AI call would happen.
- **Coverage impact.** Adding ~30–60 lines of test code increases the SimpleCov denominator by 0; coverage is computed against `eidos/lib/`, not `eidos/spec/`. The covered surface in `publish.rb` increases slightly because the new test exercises a publish path that may not have been covered before. Net: coverage either stays flat or rises; it cannot fall as a result of this fix.
