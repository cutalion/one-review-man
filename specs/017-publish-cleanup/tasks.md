---

description: "Task list for feature 017: eidos publish jekyll must not write into the source world"
---

# Tasks: `eidos publish jekyll` must not write into the source world

**Input**: Design documents from `/specs/017-publish-cleanup/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/source-world-untouched.md, quickstart.md

**Tests**: REQUIRED. Constitution Principle I (Test-First with Mock AI) mandates RSpec coverage for any bug fix. The regression spec at `eidos/spec/eidos/cli/publish_spec.rb` is written FIRST (failing), then the fix lands, then the spec passes.

**Organization**: Tasks are grouped by the two user stories from `spec.md`. US1 (creator) carries the implementation; US2 (CI maintainer) is satisfied automatically by the same fix and contains a verification-only task to confirm the CI-style usage holds.

## Format: `[ID] [P?] [Story?] Description`

- **[P]**: Different files, no dependencies on incomplete tasks — runnable in parallel
- **[Story]**: Maps a task to a user story (US1, US2). Setup / Foundational / Polish tasks carry no Story label.
- File paths are absolute under `/home/cutalion/code/one-review-man/`.

---

## Phase 1: Setup

No new directories, no new dependencies. The fix lives entirely in two existing locations (`eidos/lib/eidos/cli/publish.rb` modification + `eidos/spec/eidos/cli/publish_spec.rb` new file under an existing tree). Setup is a single confirmation task.

- [X] T001 Confirm working tree is clean and on branch `017-publish-cleanup`. Run `git status --short` from `/home/cutalion/code/one-review-man/`; expect output to show only untracked `tmp/` (the sandbox dir) plus the new `specs/017-publish-cleanup/` files. No staged or modified files outside this feature dir.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Establish the failing-test baseline before touching production code, per Constitution Principle I.

**⚠️ CRITICAL**: User-story phases cannot begin until this phase completes.

- [X] T002 Reproduce the bug manually to confirm the starting state. From `/home/cutalion/code/one-review-man/`, scaffold a temporary world: `eidos/exe/eidos world new --quick -w tmp/repro-world --title "Repro" --author "Test" --premise "Bug repro test." --languages en`. Then run `eidos/exe/eidos publish jekyll -w tmp/repro-world --dest tmp/repro-site`. Inspect `tmp/repro-world/data/`: it MUST contain freshly-written `world.yml` and `story_facts.yml`. Record this in your local notes as the baseline. Clean up: `rm -rf tmp/repro-world tmp/repro-site` (the proper regression test in T003 doesn't depend on these artifacts).

**Checkpoint**: starting state confirmed. The bug reproduces deterministically.

---

## Phase 3: User Story 1 — Creator publishes their world without surprise side-effects (Priority: P1) 🎯 MVP

**Goal**: After `eidos publish jekyll`, the source world directory is byte-identical to its pre-publish state. The destination contains a complete, build-able Jekyll source tree.

**Independent Test**: Run `eidos publish jekyll -w <fresh-world> --dest <fresh-dir>` against a freshly-scaffolded world; assert SHA-256 snapshots of every file under the source are identical before and after; assert `bundle exec jekyll build` in the destination produces zero unsubstituted placeholders.

> **Sequencing constraint**: T003–T007 are strictly ordered. Test-first (T003) MUST land before the implementation (T005). The implementation MUST land before the verification runs (T006–T007).

- [X] T003 [US1] Create `/home/cutalion/code/one-review-man/eidos/spec/eidos/cli/publish_spec.rb` per the contract at `specs/017-publish-cleanup/contracts/source-world-untouched.md`. The spec MUST contain at minimum three examples: (a) "leaves the source world byte-identical" — scaffold a temp world via `Dir.mktmpdir`, snapshot all file SHA-256s under the source, run publish via `Eidos::CLI::Publish.start(['jekyll', '-w', source, '--dest', dest])`, re-snapshot, assert sets are equal; (b) "is idempotent" — run publish twice, snapshot the destination after each, assert equal; (c) "populates the destination `_data/` with files Jekyll templates need" — assert `<dest>/_data/characters.yml` and `<dest>/_data/strings.yml` exist after publish. Use `MOCK_AI=true` in test setup (Constitution I). Use `Dir.mktmpdir` for both source and destination; clean up in `after(:each)`.
- [X] T004 [US1] **Verify the new spec fails on the current `main` baseline.** From `/home/cutalion/code/one-review-man/eidos/`, run `MOCK_AI=true bundle exec rspec spec/eidos/cli/publish_spec.rb`. The "leaves the source world byte-identical" example MUST fail (the snapshot diff will show new `data/world.yml` and `data/story_facts.yml` in the post-publish source). If the test passes pre-fix, the test isn't strong enough — strengthen it (e.g. ensure the snapshot covers `data/` and not just one subdir) before continuing.
- [X] T005 [US1] Apply the publish fix in `/home/cutalion/code/one-review-man/eidos/lib/eidos/cli/publish.rb`. Two changes:
  1. Move the exporter invocation block (current lines 44–48) from BEFORE the template-copy step to AFTER the data-copy step (i.e., place it after the `[ {dst_name: '_data', ...}, ... ].each` block at lines 75–114, just before the closing `say` calls).
  2. Change `exporter.export_for_jekyll!` to `exporter.export_to(File.join(dest_dir, '_data'))`.
  Update or remove any nearby comments that imply the exporter writes into the source world. Per research D-003, leave `eidos/lib/eidos/story_bible_exporter.rb` and `eidos/lib/eidos/cli/bible.rb` untouched — `bible export` is a legitimate caller of `export_for_jekyll!` that intentionally writes to the source.
- [X] T006 [US1] Re-run the regression spec from T003 and verify all three examples now PASS. From `eidos/`: `MOCK_AI=true bundle exec rspec spec/eidos/cli/publish_spec.rb`. Expected: 3 examples, 0 failures.
- [X] T007 [US1] Run the full RSpec suite to confirm no regressions elsewhere. From `eidos/`: `MOCK_AI=true bundle exec rspec`. Expected: 775+ examples (was 772 before T003 added 3), 0 failures. SimpleCov coverage stays at or above the committed `EIDOS_COVERAGE_FLOOR`.
- [X] T008 [US1] Manual quickstart verification (Steps 4–7 of `specs/017-publish-cleanup/quickstart.md`) against `worlds/one-review-man`. From `/home/cutalion/code/one-review-man/`: clean any prior pollution (`rm -f worlds/one-review-man/data/world.yml worlds/one-review-man/data/story_facts.yml`); run `eidos/exe/eidos publish jekyll -w worlds/one-review-man --dest tmp/site-test-017`; verify `git status --short worlds/one-review-man/` returns no new files; run publish twice more and verify still clean (idempotence); `cd tmp/site-test-017 && bundle exec jekyll build`; verify `grep -rE '\{\{[A-Z_]+\}\}' _site/` returns zero matches and `<title>All Chapters - One Review Man</title>` appears in `_site/index.html`.

**Checkpoint**: User Story 1 functional and regression-tested. The byte-identical invariant holds against both a temp-world test (T006) and the real `worlds/one-review-man` (T008). MVP is complete.

---

## Phase 4: User Story 2 — Maintainer publishes from CI without polluting the workspace (Priority: P2)

**Goal**: A CI workspace running `eidos publish jekyll` against a clean checkout passes a `git diff --quiet --exit-code worlds/<name>/` check after the publish step.

**Independent Test**: From a clean checkout, run publish, then run `git diff --quiet --exit-code worlds/one-review-man/`; expect exit code 0.

> No new implementation in this phase. The fix from US1 satisfies US2 directly (byte-identical source → clean `git diff`). This phase contains a single verification task confirming the CI-style usage holds.

- [X] T009 [US2] **CI-style verification.** From `/home/cutalion/code/one-review-man/`, ensure `worlds/one-review-man/` is clean: `git diff --quiet --exit-code worlds/one-review-man/` returns 0 (if not, clean up first). Then run `eidos/exe/eidos publish jekyll -w worlds/one-review-man --dest tmp/site-test-017`. Re-run `git diff --quiet --exit-code worlds/one-review-man/`. Expected exit code: 0. (This mirrors what a CI "fail-if-dirty" check would do.)

**Checkpoint**: User Story 2 verified. Both user stories satisfied.

---

## Phase 5: Polish & Cross-Cutting Concerns

**Purpose**: Sanity-check the legitimate caller of `export_for_jekyll!` still works, lint the changed file, and clean up sandboxes.

- [X] T010 [P] **Sanity-check the legitimate caller.** Verify `eidos bible export` still writes to the source world's `data/` directory as designed. From `/home/cutalion/code/one-review-man/`: `eidos/exe/eidos bible export -w worlds/one-review-man`; expect `git status --short worlds/one-review-man/` to show new untracked `data/world.yml`, `data/story_facts.yml`, `data/characters.yml`. Reset: `rm -f worlds/one-review-man/data/world.yml worlds/one-review-man/data/story_facts.yml`; restore `data/characters.yml` from `git checkout HEAD -- worlds/one-review-man/data/characters.yml` if it was modified. (`bible export` is correctly preserved by this fix; this task confirms.)
- [X] T011 [P] **Lint the changed Ruby file.** From `/home/cutalion/code/one-review-man/eidos/`, run `bundle exec rubocop lib/eidos/cli/publish.rb spec/eidos/cli/publish_spec.rb` if rubocop is available in the bundle. If rubocop is not installed locally (per the bundler exec failure observed during feature 016), note that the CI rubocop check will run on PR; the local skip is acceptable.
- [X] T012 Clean up sandbox artifacts: `rm -rf tmp/site-test-017 tmp/repro-world tmp/repro-site` from `/home/cutalion/code/one-review-man/`. Pre-existing `tmp/` content from feature 016 may remain — only this feature's sandboxes are removed here.

**Checkpoint**: Feature is mergeable. PR description should include the wall-clock RSpec time from T007 and a sentence confirming Steps 4–7 + T009 + T010 all pass.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: T001 only; no dependencies.
- **Phase 2 (Foundational)**: T002 depends on T001 (must be on the right branch with a clean tree). T002 does not modify the codebase — it only confirms the bug exists.
- **Phase 3 (US1)**: depends on Phase 2 complete. T003 → T004 → T005 → T006 → T007 → T008 are strictly sequential. T003 must precede T004 (failing test before implementation, Principle I). T005 is the only production-code change; T006/T007/T008 are verifications.
- **Phase 4 (US2)**: depends on Phase 3 complete (the fix from T005 satisfies US2). T009 is verification only.
- **Phase 5 (Polish)**: depends on Phase 4 complete. T010 and T011 are [P] (different concerns, different commands). T012 is final cleanup.

### User Story Dependencies (file-level)

US1 modifies `eidos/lib/eidos/cli/publish.rb` and adds `eidos/spec/eidos/cli/publish_spec.rb`. US2 has no implementation; it inherits the fix from US1.

### Parallel Opportunities

- T010 and T011 (Polish): different concerns, different commands → [P].
- All other tasks are sequential (test-first ordering, single-file modification, sequential verification).

---

## Parallel Example: Phase 5 Polish

```bash
# Run these two together:
Task: "Sanity-check eidos bible export still writes to source data/"   # T010
Task: "Run rubocop on publish.rb and publish_spec.rb"                  # T011
```

---

## Implementation Strategy

### MVP (User Story 1 only)

1. T001 → T002 (setup + reproduce).
2. T003 (write failing test) → T004 (verify it fails).
3. T005 (apply fix) → T006 (verify spec passes) → T007 (full suite green) → T008 (manual quickstart on real world).
4. **STOP and VALIDATE**: at this point the byte-identical invariant holds against both a temp-world spec and the real `worlds/one-review-man`. The MVP is mergeable.

### Incremental Delivery

For this small bug fix, MVP and "complete" are nearly identical. The only thing US2 + Polish add is verification and lint. Recommend: do them all in one push to merge in a single PR.

### Single-Maintainer Strategy

Whole feature should fit in one focused work session. Estimated wall-clock for an experienced maintainer: ~30–45 minutes (most of it RSpec runs). The implementation diff is ~5 moved lines + 1 changed line in `publish.rb` + ~30–60 lines of new spec.

---

## Notes

- [P] tasks = different files, no dependencies. Most of this feature is sequential because the fix is a single-file modification and the verification is sequential test runs.
- [Story] label maps a task to a user story; Setup / Foundational / Polish carry no Story label.
- T003 → T004 → T005 ordering is non-negotiable (Constitution Principle I: failing test before implementation).
- Capture the wall-clock for T007 (full suite) in the PR description; this is the proxy for "no test-suite regression."
- Do NOT commit until the full suite (T007) is green and the manual quickstart (T008) passes. Per the project's standing rule, commits happen only on explicit user request.
