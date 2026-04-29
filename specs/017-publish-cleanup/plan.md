# Implementation Plan: `eidos publish jekyll` must not write into the source world

**Branch**: `017-publish-cleanup` | **Date**: 2026-04-29 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/017-publish-cleanup/spec.md`

## Summary

Stop `eidos publish jekyll` from writing into the source world's `data/` directory. The publish path currently calls `Eidos::StoryBibleExporter#export_for_jekyll!` (which writes `data/world.yml`, `data/story_facts.yml`, and `data/characters.yml` into the source) and then copies the source's `data/` to `<dest>/_data/`. The fix relocates the exporter's writes to the destination directly, so the source world is left byte-identical. The exporter class itself is not modified — its other caller (`eidos bible export`) legitimately writes into the source and that contract is preserved.

## Technical Context

**Language/Version**: Ruby 3.3.5, `# frozen_string_literal: true` on every file
**Primary Dependencies**: Thor (CLI), existing `Eidos::StoryBibleExporter` (engine class), Jekyll (downstream consumer of published output, not a runtime dependency of this gem)
**Storage**: YAML files on disk under `worlds/<name>/data/` (read-only) and `<dest>/_data/` (write target after the fix)
**Testing**: RSpec with `MOCK_AI=true`. New `eidos/spec/eidos/cli/publish_spec.rb` (or equivalent) — none currently exists
**Target Platform**: Linux/macOS dev workstation, plus CI runners that use the same gem
**Project Type**: Single-project Ruby gem (CLI fix)
**Performance Goals**: No change. Publish runtime is dominated by `FileUtils.cp_r` for the content tree; reordering two adjacent calls in the publish path doesn't shift the curve
**Constraints**: No new gems. No public API change to `Eidos::StoryBibleExporter` (the `export_for_jekyll!` method must keep working for the `bible export` caller). No change to Jekyll template syntax or output. Source world must be byte-identical pre/post publish (the central contract from spec FR-001)
**Scale/Scope**: Single Ruby file edit in `eidos/lib/eidos/cli/publish.rb` (~5 lines moved + 1 line changed) plus one new RSpec file (~30–60 lines)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Engaged? | Disposition |
|---|---|---|
| I. Test-First with Mock AI | **Yes** | A new RSpec test asserting the source-world-byte-identical invariant is required by both the constitution and SC-005 of this spec. The test runs under `MOCK_AI=true` (no LLM calls in the publish path anyway). Discharged by the Phase-1 contract `contracts/source-world-untouched.md` and the corresponding `publish_spec.rb`. |
| II. Producer Contract | No | No producer added or changed. |
| III. Dependency Injection | **Yes (light)** | The fix doesn't introduce a new injectable, but the new test will need to instantiate `Publish` Thor class and exercise `publish jekyll` against a temp world. Existing `StoryBibleExporter` stays as-is — already injectable via `project_root:`. No DI violation. |
| IV. Canon Integrity | No | No canon mutation. The fix actually strengthens this: publish stops writing under `data/` so the canon's home stays read-only during publish. |
| V. Security by Default | No | No new key handling, no new logging. |
| VI. Pluggable AI Services | No | No AI service touched. |
| VII. Separation of Concerns | **Yes (reaffirmed)** | This fix *enforces* the existing layer separation: the Publishing layer should consume Engine outputs without mutating Engine state. Today's behavior is a quiet violation; the fix removes it. |

**Gate verdict: PASS** — no violations claimed; one principle (Test-First) is actively engaged and will be discharged by Phase 1's regression spec.

## Project Structure

### Documentation (this feature)

```text
specs/017-publish-cleanup/
├── spec.md              # Feature spec (already written, no clarifications)
├── plan.md              # This file
├── research.md          # Phase 0 — what templates need; relocate-vs-drop decision
├── data-model.md        # Phase 1 — entity/file shapes
├── contracts/
│   └── source-world-untouched.md  # The byte-identical invariant + how it's tested
├── quickstart.md        # Phase 1 — verification steps mirroring SC-001..005
├── checklists/
│   └── requirements.md  # already written
└── tasks.md             # Phase 2 (created later by /speckit.tasks)
```

### Source Code (repository root)

The fix is small. Affected files:

```text
eidos/
├── lib/eidos/cli/
│   └── publish.rb                # MODIFIED — reorder + redirect exporter call
└── spec/eidos/cli/
    └── publish_spec.rb           # NEW — regression test for source-world-untouched
```

Out of scope (untouched):

- `eidos/lib/eidos/story_bible_exporter.rb` — the exporter class itself. Its public contract (`export_for_jekyll!` writes into world's `data/`; `export_to(dest)` writes to `dest`) stays as-is.
- `eidos/lib/eidos/cli/bible.rb` — the `bible export` subcommand still calls `export_for_jekyll!`, which is correct for that user-facing command.
- `eidos/templates/jekyll/` — no template changes needed; the data they reference (`site.data.characters.*`, `site.data.strings.*`) will still be at `<dest>/_data/` after the fix.
- `docs/usage-guide.md` — doesn't describe this side effect; no doc update needed for this fix. (The guide will be merged when feature 016 lands.)

**Structure Decision**: Single-project Ruby gem. One file modified, one new spec file. No new directories.

## Phase 0: Outline & Research

The Technical Context has no `NEEDS CLARIFICATION` markers — every technical decision was either pinned by the spec or by the in-line research already done at the top of this session.

`research.md` documents three resolved decisions:

**D-001 — Relocate vs. drop the exporter call.** *Decision: relocate.* Templates at `eidos/templates/jekyll/` reference `site.data.characters.characters[...]` and `site.data.strings[...]` — both of which require a populated `_data/` block at the destination. The exporter's `characters.yml` output is one of those needed files. Dropping the call entirely would leave the destination's `_data/characters.yml` stale (sourced only from the data-copy of `worlds/<name>/data/characters.yml`, which may not be regenerated from the per-entity bible directory between publish runs). Relocating preserves the freshness guarantee. *Alternative considered:* drop the call and rely solely on the data-copy step; rejected because templates would render with stale character data after a bible update unless the user remembered to run `eidos bible export` first.

**D-002 — Where to call `export_to(...)`.** *Decision: AFTER the data-copy step, with `dest_dir = File.join(dest_dir, '_data')`.* The current publish flow runs the exporter BEFORE copying the data block. Reordering so the exporter runs after the copy means the exporter's output overlays the copied files — `characters.yml` gets a fresh regenerated copy from `data/story_bible/characters/`, and `world.yml`/`story_facts.yml` are added even though they're currently unused (low cost; future templates may reference them). *Alternative considered:* keep the export-then-copy order and have the exporter write to a tmp dir merged in by hand. Rejected: more code, more failure modes, no functional gain.

**D-003 — Should `Eidos::StoryBibleExporter#export_for_jekyll!` be removed or renamed?** *Decision: keep it as-is.* The method has a second user: `eidos bible export` (registered in `eidos/lib/eidos/cli/bible.rb:32` with the description "Export Story Bible to Jekyll-compatible format (updates data/*.yml files)"). That command's *deliberate* contract is to write into the source world's `data/` so a user can stage Jekyll-data files in version control alongside their world. Removing or repurposing the method would break that user-facing command. *Alternative considered:* rename `export_for_jekyll!` to `export_to_world_data!` for clarity. Rejected: cosmetic change with no observable user benefit; would also force a breaking API change to a public method on a public engine class for low value.

**Output**: `research.md` (written below).

## Phase 1: Design & Contracts

**Prerequisites**: research.md complete (Phase 0 above).

1. **Entities → `data-model.md`**:
   - **Publish Run** — one invocation of `eidos publish jekyll`. Inputs: source world path, destination path. Outputs: a Jekyll source tree at the destination. Critically: **must not modify the source world**.
   - **Source World** — `worlds/<name>/`. Read-only during publish.
   - **Destination `_data/` block** — `<dest>/_data/`. Where the Jekyll templates expect to find `world.yml`, `story_facts.yml`, `characters.yml`, `strings.yml`, etc.

2. **Contracts → `contracts/`**:
   - **`contracts/source-world-untouched.md`** — the byte-identical invariant. Defines what "untouched" means precisely (every file under `worlds/<name>/` that existed before publish has the same content + mtime; no new files appear; no files are removed). Defines the test methodology (snapshot all file SHA-256s before and after; assert sets equal).

3. **`quickstart.md`** — manual verification mirroring SC-001..005:
   - Step 1: scaffold a fresh world; commit it; record `git status` output.
   - Step 2: run `eidos publish jekyll -w <world> --dest tmp/site-test/`; verify `git status` against the world is unchanged.
   - Step 3: re-run publish twice; verify idempotence (`git status` still clean; site still builds).
   - Step 4: `cd tmp/site-test && bundle exec jekyll build`; verify zero unsubstituted placeholders.
   - Step 5: delete `worlds/<world>/data/world.yml` and `worlds/<world>/data/story_facts.yml` (if present); re-run publish; verify they are NOT regenerated in the source.
   - Step 6: run full RSpec from `eidos/`; verify 772+ green and coverage held.

4. **Agent context update**:
   - Run `.specify/scripts/bash/update-agent-context.sh claude` to refresh CLAUDE.md's footer with the 017 entry.

**Output**: `data-model.md`, `contracts/source-world-untouched.md`, `quickstart.md`.

## Post-Design Constitution Re-check

After Phase 1 artifacts are drafted:

- **Principle I (Test-First)**: the contract `contracts/source-world-untouched.md` defines the test before the implementation; `quickstart.md` Step 2 + RSpec coverage in Step 6 discharge the runtime invariant.
- **Principle VII (Separation of Concerns)**: re-affirmed. The fix moves the exporter call so its outputs land downstream (in the publishing layer's destination) instead of mutating the engine layer's storage.
- **No new violations introduced.**

**Gate re-verdict: PASS** (deferred to post-implementation review of the actual diff).

## Complexity Tracking

No constitution violations. No complexity entries.

## Implementation Sequence (informative — full ordering lands in `tasks.md`)

1. **Write the regression spec first** (`eidos/spec/eidos/cli/publish_spec.rb`). Constitution Principle I — failing test before implementation. The test scaffolds a temp world, takes a SHA-256 snapshot of every file under it, runs publish to a sibling temp dir, re-takes the snapshot, asserts equal.
2. **Verify the test fails** on current `main` (with the publish bug present).
3. **Apply the publish.rb fix**: move the exporter call from before the template copy to after the data-copy step, and change `exporter.export_for_jekyll!` → `exporter.export_to(File.join(dest_dir, '_data'))`.
4. **Verify the test passes** with the fix.
5. **Verify the full suite passes** (`MOCK_AI=true bundle exec rspec` from `eidos/`).
6. **Run the quickstart manually** against `worlds/one-review-man` — confirm the source stays clean and the site builds with zero unsubstituted placeholders.
7. **Verify Jekyll site equivalence** — diff the destination produced before and after the fix (excluding mtimes); content should be byte-identical.

## Phase 2 (out of scope for this command)

Tasks decomposition lives in `tasks.md` and is produced by `/speckit.tasks`.
