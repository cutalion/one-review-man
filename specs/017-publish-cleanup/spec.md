# Feature Specification: `eidos publish jekyll` must not write into the source world

**Feature Branch**: `017-publish-cleanup`
**Created**: 2026-04-29
**Status**: Draft
**Input**: User description: "Stop `eidos publish jekyll` from polluting the source world's `data/` directory. `Eidos::StoryBibleExporter#export_for_jekyll!` writes legacy files (`data/world.yml`, `data/story_facts.yml`) into the source world's `data/` directory before publish copies content to the destination. Those files were intentionally deleted in commit 9622734 (feat(012): unify lore store) when the bible storage migrated to per-entity directories under `data/story_bible/`. The exporter still regenerates them every time publish runs."

## Context

The publish command — invoked as `eidos publish jekyll -w worlds/<name> --dest <site>` — is supposed to be a **read-only** operation against the source world: read content + canon, write a Jekyll site tree at the destination, leave the world untouched. Today it isn't. As a side effect of the Story-Bible-export step that runs before the destination copy, it writes two legacy YAML files (`data/world.yml`, `data/story_facts.yml`) directly into the source world's `data/` directory. Those files were intentionally removed in feature 012 when the bible storage migrated to per-entity directories under `data/story_bible/`; the publish path still regenerates them.

The visible symptom: after running publish, `git status` on the source world shows two untracked files the user did not author.

The deeper problem is a violation of the principle that publish should be a one-way, idempotent transformation. A user running publish in a sandbox, in a CI step, or against a directory they consider read-only has every reason to expect the source world is left exactly as they found it. The current behaviour quietly mutates the source.

This spec covers fixing the publish path so writes go to the destination only, and verifying that downstream Jekyll templates still find what they need.

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Creator publishes their world without surprise side-effects (Priority: P1)

A creator runs `eidos publish jekyll -w worlds/<name> --dest site` to build a Jekyll site from their world. After the command finishes, `git status` against their world directory shows no new or modified files. The source world is exactly as it was before they ran publish.

**Why this priority**: This is the primary contract of publish. Any user — human or CI — who treats publish as read-only is currently silently wrong. Every user who publishes is affected.

**Independent Test**: From a clean source world (`git status` shows no changes under `worlds/<name>/`), run publish to a sandbox destination, then re-run `git status` against `worlds/<name>/`. Output MUST be unchanged. The destination MUST contain a complete, build-able Jekyll source tree.

**Acceptance Scenarios**:

1. **Given** a clean source world (no untracked or modified files under `worlds/<name>/`), **When** the user runs `eidos publish jekyll -w worlds/<name> --dest <fresh-dir>`, **Then** `git status` against the source world shows no new or modified files, and `<fresh-dir>` contains a Jekyll source tree that builds successfully (`bundle exec jekyll build` succeeds with no errors and no unsubstituted template placeholders).
2. **Given** the same clean world, **When** the user runs publish twice in a row to the same destination, **Then** the second run produces identical output to the first (idempotence) and the source world remains unchanged.
3. **Given** the same clean world, **When** the user runs publish to a destination on a read-only filesystem, **Then** publish fails at the destination boundary — never as a result of failing to write into the source world.

---

### User Story 2 — Maintainer publishes from CI without polluting the workspace (Priority: P2)

A maintainer wires `eidos publish jekyll` into a CI pipeline that builds the public site from the latest committed world content. After the publish step, the CI workspace's source world directory has no uncommitted changes, so the next pipeline step (e.g. a "fail if dirty" check, or a subsequent commit) does not see spurious writes attributable to publish.

**Why this priority**: Publish in CI is the most common automation; surprise writes there can fail strict pipelines or worse, get accidentally committed. Solving User Story 1 likely solves this too, but the CI scenario warrants its own acceptance because the CI worktree is often more sensitive to dirty state than a developer's local checkout.

**Independent Test**: Simulate a "fail if dirty" check by running publish followed by `git diff --quiet --exit-code worlds/<name>/`. The check MUST exit 0.

**Acceptance Scenarios**:

1. **Given** a CI workspace with a clean checkout of the world, **When** the publish step runs, **Then** `git diff --quiet --exit-code worlds/<name>/` returns exit code 0 (no uncommitted changes in the source world).
2. **Given** the same workspace, **When** the publish step runs against a destination outside the worktree, **Then** the destination contains the expected Jekyll output and the worktree is untouched.

---

### Edge Cases

- The user has *legitimately* modified files under `worlds/<name>/data/` before running publish (e.g. just edited `world_config.yml`). Publish must not introduce *additional* changes. Pre-existing user changes are not the publish step's concern.
- The user has a legacy world that was created before feature 012 and still has its own hand-authored `data/world.yml` and `data/story_facts.yml` (not generated by the exporter). Publish must not overwrite those files in the source world. The destination's data block can still be populated, but never by mutating files in the source. (See Assumptions for how legacy worlds are detected.)
- The destination already contains a previous Jekyll build with a custom `_config.yml`. Publish already preserves user-customized destination files (per the existing `existing_site?` check). The fix must not alter that behavior — we are changing where the *exporter* writes, not the file-copy behavior.
- A second user runs publish concurrently against the same source world from a different process. Today both can race on writing into the source's `data/` directory; after the fix, neither writes there at all, so concurrent publishes can no longer collide on those files (they may still race on the destination, which is each invocation's own concern).
- A future user invokes the underlying `Eidos::StoryBibleExporter#export_for_jekyll!` directly (not via `eidos publish jekyll`) and *expects* it to populate the source world's `data/` directory. This usage is undocumented; the fix MAY remove or rename the method as part of cleanup. (See Assumptions.)

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: After `eidos publish jekyll` completes successfully, the source world directory (`worlds/<name>/`) MUST be byte-identical to its pre-publish state. No new files, no modified files, no removed files.
- **FR-002**: The Jekyll site assembled at the publish destination MUST contain whatever per-world data the Jekyll templates require (currently a `_data/` subdirectory with the world's character / location / fact / relationship / plot-thread information rendered into Jekyll-friendly shape). The published site MUST build successfully via `bundle exec jekyll build` with zero unsubstituted template placeholders.
- **FR-003**: Running `eidos publish jekyll` twice in succession against the same destination MUST produce identical Jekyll output on the second run as on the first. (Idempotence — no state in the source world causing later runs to differ from earlier ones.)
- **FR-004**: The fix MUST NOT regress any working publish behavior. Specifically: the existing-site detection (`existing_site?` — preserves a destination's custom `_config.yml`), the asset merge (additive copy into `assets/`), the language switcher, and the per-chapter / per-character page rendering MUST all continue to work as they do today.
- **FR-005**: The fix MUST NOT require the user to delete pre-existing `data/world.yml` or `data/story_facts.yml` files in legacy worlds. Existing files that the user authored (or that prior publish runs left behind) MAY remain on disk; the fix only changes that publish stops *adding* or *modifying* them.
- **FR-006**: The fix MUST update or supersede any documentation, comments, or method names in the codebase that imply `Eidos::StoryBibleExporter#export_for_jekyll!` writes into the world's data directory. If the method is retained, its name and docstring MUST reflect the new behavior. If it is removed, every call site MUST be updated.
- **FR-007**: After the fix, any cleanup step a user takes to undo the *previous* incarnation of this bug — deleting the spurious `data/world.yml` and `data/story_facts.yml` from their world — MUST remain effective. Publish MUST NOT re-create those files on the next run.

### Key Entities

- **Source world** — the directory at `worlds/<name>/` that holds the canonical state of the user's storyworld (config, bible, content, settings). Read-only target of publish.
- **Publish destination** — the directory passed via `--dest` (default `./site`) that receives a Jekyll source tree. Write target of publish; rebuilt or merged on each run.
- **Jekyll `_data/` block** — per-world metadata files the Jekyll templates read at build time (currently `world.yml`, `story_facts.yml`, plus character / location data). Must end up at the destination, not at the source.
- **Story Bible** — the per-entity YAML storage at `worlds/<name>/data/story_bible/` introduced in feature 012. The authoritative form of the bible. Read-only input to the publish step.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of publish runs against a clean source world leave the source world in a byte-identical state (verified by `git diff --quiet --exit-code worlds/<name>/` returning 0). Measured by an acceptance test that scaffolds a fresh world, commits it, runs publish, and asserts no diff.
- **SC-002**: 100% of publish runs produce a Jekyll site that builds with zero unsubstituted template placeholders and zero "failed to process template" warnings. Measured by running `bundle exec jekyll build` in the destination and grepping the output for the placeholder pattern.
- **SC-003**: Publish is **idempotent** in the source-world dimension: running it any number of times never alters the source. Measured by running publish 3× in succession against a clean source world and asserting no diff after each run.
- **SC-004**: The `worlds/one-review-man` source world stops accumulating untracked `data/world.yml` and `data/story_facts.yml` files between publish runs. Demonstrated by deleting those files (if present), running publish, and confirming `git status` against the source world is clean.
- **SC-005**: The full RSpec suite (`MOCK_AI=true bundle exec rspec` from `eidos/`) continues to pass with zero failures after the fix. Coverage stays at or above the committed `EIDOS_COVERAGE_FLOOR`.

## Assumptions

- The publish destination is a directory the user has authority to write into. Publish never needs write access to the source world; only to the destination.
- The Jekyll templates currently expect the `_data/` block to contain the legacy-shaped `world.yml` and `story_facts.yml` files. If they don't actually need these files (e.g. the templates were updated to read from `data/story_bible/` directly), the fix MAY drop the export step entirely instead of relocating it. The implementation must verify which path applies.
- The `Eidos::StoryBibleExporter` class already exposes an `export_to(dest_dir)` method that writes the same files at a caller-supplied destination. The fix can plausibly call that method with the publish destination's `_data/` directory.
- Legacy worlds (created before feature 012) that have the legacy `data/world.yml` / `data/story_facts.yml` on disk are tolerated as historical artifacts. The fix does not need to migrate or delete them. If the user wants to clean them up, they delete them manually; publish will not regenerate them.
- The fix is scoped to the publish path (`eidos/lib/eidos/cli/publish.rb` and `eidos/lib/eidos/story_bible_exporter.rb`). It does not touch unrelated CLI surfaces, scaffolding, or content production.
- Test coverage for publish is currently thin (no `publish_spec.rb` exists in the suite); the fix SHOULD add at least one test that asserts the source-world-untouched invariant, so a future regression is caught immediately.
- This spec is independent of feature 016 (usage guide + QA agents). The fix does not modify `docs/usage-guide.md` or any agent definitions. (The guide already correctly describes what publish *should* do; it does not describe the broken side effect.)
