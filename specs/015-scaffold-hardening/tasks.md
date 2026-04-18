# Tasks: Scaffold Hardening (015)

**Input**: Design documents from `/specs/015-scaffold-hardening/`
**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅, data-model.md ✅, contracts/cli-flags.md ✅, quickstart.md ✅

**Tests**: **INCLUDED and required.** The postmortem (`specs/014-storyworld-pivot/postmortem.md` §3.2) identified the mock-too-clean unit suite as the primary reason 014 shipped with six Tier-1 defects. Every user story in 015 gets both unit coverage (for regression) and integration coverage (for user-scale reality). Fuzz tests (FR-024) are mandatory for the canon-delta parser.

**Organization**: Tasks grouped by user story in the user-stated implementation order (US3 → US4 → US1 → US2 → US5 → US6 — surface-then-substrate). P1 stories (US1, US2, US3) still block the feature from shipping; P2/P3 stories land incrementally.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Different files, no dependencies on incomplete tasks — parallelizable.
- **[Story]**: US1–US6 (see `spec.md`) or no label for Setup / Foundational / Polish.
- Every task lists exact file paths.

## Path Conventions

Single monorepo. All Ruby source and specs live under `eidos/`. CLAUDE.md and `scripts/` live at repo root. All paths below are absolute from repo root.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Prepare the integration harness, the fuzz-fixture loader, and the spec exclusion wiring so subsequent phases have a place to add tests.

- [X] T001 Create directory `eidos/spec/integration/user_scale/` with an empty `.keep` file so it is checked in before the first spec lands.
- [X] T002 Create `eidos/spec/support/integration_world_builder.rb` providing `build_world(premise:, title:, author:, languages: "en", extra_flags: {})` helper that shells `exe/eidos world new --quick ...` via `Open3.capture3` into a `Dir.mktmpdir`, returns `{world_path:, stdout:, stderr:, status:}`. Yielding block receives the world_path and auto-cleans on exit. Uses stdlib `Open3`, `Dir.mktmpdir`, `FileUtils` only — no new gems.
- [X] T003 Add `.rspec` config at `eidos/.rspec` (create file) with `--exclude-pattern "spec/integration/user_scale/**/*_spec.rb"` so the fast loop does not descend into the user-scale suite by default.
- [X] T004 [P] Document in `eidos/spec/integration/user_scale/README.md` how to invoke the suite: `MOCK_AI=true bundle exec rspec spec/integration/user_scale/`. Include a short note that the suite shells the CLI and asserts on disk.
- [X] T005 [P] Extend `eidos/spec/support/mock_llm_service.rb` (or the responses fixture it consults) with fixture keys `canon_delta_bare_string`, `canon_delta_missing_required_key`, `canon_delta_truncated_yaml`, and `canon_delta_arthur_well_formed`. These are the named mocks the fuzz specs and integration specs will request via `MOCK_RESPONSE=<key>`.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Land contributor guidance before any implementation lands, so US1–US6 code all follows the silent-fallback ban from day one. No code-level foundational work — each US is nearly independent.

**⚠️ CRITICAL**: T006 must land before any implementation task so the convention applies to new code authored in this feature.

- [X] T006 Add section "Banned patterns: silent fallbacks" to `CLAUDE.md` adjacent to the existing "Definition of Done" section. Content per research R9: the pattern, three 014-postmortem examples (`"fiction"`, `return unless @bible`, `next nil` after stderr warn), the three acceptable alternatives (raise / Result / user-visible channel via `canon review` or `world status`), and the reason stderr is not user-visible. Covers FR-022, FR-023, SC-009.

**Checkpoint**: Foundation ready — user story implementation can proceed. All subsequent tasks cite this convention; reviews enforce it.

---

## Phase 3: User Story 3 — Non-interactive `world new --quick` (Priority: P1)

**Goal**: Multi-line premise passed via Thor flags lands verbatim in `world_config.yml` subtitle/description; missing required flags produce a clear error; interactive TTY flow unchanged.

**Independent Test**: Shell `exe/eidos world new --quick --title T --author A --premise "line1\nline2\nline3" --languages en -w /tmp/qa` and assert `YAML.load_file('/tmp/qa/data/world_config.yml')` contains those three lines verbatim in `subtitle` and `description`, `languages: ["en"]`, `default_language: "en"`. No dependency on US1, US2, US4, US5, US6.

### Tests for User Story 3

- [X] T007 [P] [US3] Unit spec for CLI flag parsing in `eidos/spec/eidos/cli/world_new_quick_flags_spec.rb`: asserts Thor `--title`, `--author`, `--premise`, `--languages`, `--default-language`, `--genre`, `--style`, `--setting`, `--theme` options are declared on `Eidos::CLI::World#new` with correct types and defaults per `contracts/cli-flags.md`. (US3 scope covers the five required flags; --genre/--style/--setting/--theme assertions land in T017 under US4.)
- [X] T008 [P] [US3] Unit spec for missing-flag error in `eidos/spec/eidos/cli/world_new_quick_flags_spec.rb` (same file as T007, grouped together): asserts non-interactive invocation with only `--title` exits non-zero and stderr names `--author`, `--premise` as missing. No world directory created.
- [X] T009 [P] [US3] Unit spec for TTY fallthrough in `eidos/spec/eidos/cli/world_new_interactive_flow_spec.rb` (extend existing file): asserts that with stdin TTY AND zero quick-setup flags, the existing `tty-prompt` interactive flow still runs (use existing interactive-flow spec patterns).
- [X] T010 [US3] Integration spec `eidos/spec/integration/user_scale/world_new_multiline_premise_spec.rb`: uses the T002 helper to shell `world new --quick` with a three-line premise containing commas, quotes, em-dashes. Asserts `subtitle` and `description` contain all three lines verbatim; `languages == ["en"]`; `default_language == "en"`; no prose fragments in `languages` or `default_language`. Covers SC-001.
- [X] T011 [US3] Integration spec `eidos/spec/integration/user_scale/world_new_missing_flags_spec.rb`: shells `world new --quick --title X` only, asserts exit code non-zero, stderr mentions missing `--author` / `--premise`, and no world directory is created at the target path. Covers FR-010.

### Implementation for User Story 3

- [X] T012 [US3] Add Thor `method_option` declarations for `--title`, `--author`, `--premise`, `--languages`, `--default-language` to `Eidos::CLI::World#new` in `eidos/lib/eidos/cli/world.rb` around line 22 (extend the existing `option :quick` block). Types per `contracts/cli-flags.md`.
- [X] T013 [US3] Add `quick_setup_from_flags(options)` method in `eidos/lib/eidos/cli/world.rb` that returns the same hash shape `collect_quick_setup_info` returns today but sourced from Thor options. No stdin reads. Comma-split `--languages`; validate `--default-language` is a member of the list.
- [X] T014 [US3] Add `non_interactive?` detection in `eidos/lib/eidos/cli/world.rb`: true when any of the new flags is passed OR `$stdin.tty?` is false. Dispatch `new` action: non-interactive → `quick_setup_from_flags`; TTY + no flags → `collect_quick_setup_info`.
- [X] T015 [US3] Add required-flag validation in `eidos/lib/eidos/cli/world.rb`: when `non_interactive? && options[:quick]`, missing any of `--title`/`--author`/`--premise` → exit 1 after writing one-line error naming each missing flag to `$stderr`. Covers FR-010 and the silent-fallback ban.
- [X] T016 [US3] Update `scripts/demo_job_hunt.sh` to drive the new flag surface instead of here-doc stdin. Pass premise via `--premise "$(cat <<'EOF'...)"` or equivalent quoted single-string. Covers the SC-001 assertion when rerun.

**Checkpoint**: US3 complete. `scripts/demo_job_hunt.sh` produces a `world_config.yml` with a clean multi-line premise. Integration suite passes for US3 scenarios. Ready for US4 to extend the flag surface with metadata fields.

---

## Phase 4: User Story 4 — World metadata sentinel (Priority: P2)

**Goal**: Without explicit `--genre`/`--style`/`--setting`/`--theme`, metadata fields are written as the sentinel `"unspecified"`. With explicit flags, values are used verbatim. `eidos world status` surfaces unspecified fields as action items. Regex heuristics deleted.

**Independent Test**: Scaffold a world without metadata flags → `world_config.yml` has `genre: unspecified` (and style/setting/theme); `world status` output includes "⚠️ Unspecified fields". Scaffold with `--genre comedy --style deadpan` → those values verbatim, no overlay. Depends on US3's flag surface being present.

### Tests for User Story 4

- [X] T017 [P] [US4] Unit spec for metadata-flag routing in `eidos/spec/eidos/cli/world_new_metadata_spec.rb`: explicit `--genre comedy` lands in `world_config.yml` `genre` field verbatim; absent flag lands as `"unspecified"`.
- [X] T018 [P] [US4] Unit spec for world_config sentinel rendering: in `eidos/spec/eidos/world_config_spec.rb` (extend existing or create `eidos/spec/eidos/world_config_sentinel_spec.rb`): a world with `genre: unspecified` loads without error; any code that reads `world_config.genre` gets the literal string `"unspecified"` — not substituted, not raised.
- [X] T019 [US4] Integration spec `eidos/spec/integration/user_scale/world_new_metadata_sentinel_spec.rb`: scaffolds without metadata flags, asserts `world_config.yml` shows all four metadata fields as `unspecified`; then shells `world status`, asserts stdout contains "Unspecified fields need your attention: genre, style, setting, theme" or equivalent action-item line per `contracts/cli-flags.md`. Covers SC-002 (first half).
- [X] T020 [US4] Integration spec `eidos/spec/integration/user_scale/world_new_metadata_explicit_spec.rb`: scaffolds with `--genre comedy --style deadpan --setting office --theme "AI revolution"`; asserts `world_config.yml` contains literally those values. Covers SC-002 (second half).

### Implementation for User Story 4

- [X] T021 [US4] Add Thor `method_option` declarations for `--genre`, `--style`, `--setting`, `--theme` to `Eidos::CLI::World#new` in `eidos/lib/eidos/cli/world.rb` (extend the option block added in T012). All four optional, default `"unspecified"`.
- [X] T022 [US4] In `eidos/lib/eidos/cli/world.rb`, wire the four new options through `quick_setup_from_flags(options)` (T013) into the metadata hash passed to `build_world_metadata`. Explicit values used verbatim; absent → `"unspecified"`.
- [X] T023 [US4] Delete regex heuristics in `collect_quick_setup_info` / `infer_genre` / equivalent methods in `eidos/lib/eidos/cli/world.rb`. Interactive flow now asks the user for these four fields directly (tty-prompt), OR writes `"unspecified"` if user presses enter. NO regex fallback to `"fiction"`/`"narrative"`/`"contemporary setting"`/`"adventure"`. Covers FR-011 and the silent-fallback ban (deleting the biggest violator).
- [X] T024 [US4] In `Eidos::CLI::World#status` (same file), add an "action items" block that checks `world_config.genre`/`style`/`setting`/`theme` against the `"unspecified"` sentinel and prints `"⚠️  Unspecified fields need your attention: <list>"` per `contracts/cli-flags.md`. Covers FR-012.
- [X] T025 [US4] [P] Audit `eidos/lib/eidos/prompts/` for places that inject world metadata into prompts. Where a metadata field is used as context, ensure `"unspecified"` values either render as empty/omitted OR the prompt is authored to tolerate the sentinel. Do NOT substitute. File path varies; run via `grep -l "genre\|style\|setting\|theme" eidos/lib/eidos/prompts/`.
- [X] T026 [US4] [P] Same audit for `eidos/templates/` (Jekyll template, strings templates). Ensure `{{ genre }}` renders cleanly when the value is `"unspecified"`.

**Checkpoint**: US4 complete. No world ever ships with a plausible-looking metadata lie. `world status` surfaces unspecified fields as action items.

---

## Phase 5: User Story 1 — Canon-delta drops are visible (Priority: P1)

**Goal**: When `CanonDelta.normalize_section` encounters a non-mapping entry (LLM emitted a bare string), the drop is recorded on `parse_error.drops[]` and surfaced as a `parse-drop` AuditFinding in `eidos canon review`. No stderr-only signal.

**Independent Test**: Feed a canon-delta YAML with `new_characters: ["Arthur is a programmer"]` through `CanonDelta.parse`. Assert `parse_error.drops.size == 1` with `section: new_characters`, `value: "Arthur is a programmer"`, `reason: /expected mapping/`. After `apply!`, assert one `AuditFinding` with `kind: "parse-drop"` exists. Depends on: nothing from US3/US4.

### Tests for User Story 1

- [X] T027 [P] [US1] Unit spec for `parse_error` new shape in `eidos/spec/eidos/canon_delta_spec.rb` (extend existing file): `CanonDelta.parse` of a delta with bare-string `new_characters` entries produces `parse_error: { summary:, drops: [...] }` structure per data-model.md §1.
- [X] T028 [P] [US1] Unit spec for legacy-string tolerance in `eidos/spec/eidos/canon_delta_spec.rb`: `CanonDelta.from_hash({ "parse_error" => "YAML parse error: ..." })` deserializes to the same in-memory shape as `parse_error: { summary: "YAML parse error: ...", drops: [] }`. Covers backwards-compat from data-model.md §1.
- [X] T029 [P] [US1] **Fuzz spec** for each malformed LLM shape in `eidos/spec/eidos/canon_delta_fuzz_spec.rb` (new file): (a) bare-string entry, (b) missing required key `description`, (c) truncated YAML tail mid-mapping. For each, assert `parse_error.drops` or `parse_error.summary` populated and no stderr output. Covers FR-024.
- [X] T030 [P] [US1] Unit spec for new `AuditFinding` kind in `eidos/spec/eidos/audit_log_spec.rb` (extend existing or create): `AuditFinding.open(kind: 'parse-drop', ...)` is valid; `AuditLog` persists it; `kind == 'parse-drop'` survives round-trip.
- [X] T031 [US1] Integration spec `eidos/spec/integration/user_scale/canon_delta_drops_visible_spec.rb`: uses `MOCK_RESPONSE=canon_delta_bare_string` (from T005) to produce a piece, then shells `eidos canon review` and asserts stdout contains `[parse-drop]` plus the dropped value and section. Covers SC-004.

### Implementation for User Story 1

- [X] T032 [US1] Rewrite `CanonDelta.normalize_section` in `eidos/lib/eidos/canon_delta.rb` (around line 73) to (a) return a pair `[normalized_entries, drops]` instead of a single array, (b) on non-mapping entry push `{section:, value:, reason:}` to drops instead of `warn ... ; next nil`. Remove the stderr `warn` call. Per research R1.
- [X] T033 [US1] Update `CanonDelta.parse` in the same file to collect drops from all six `SECTIONS.each` calls, then construct `parse_error: { summary: <one-line count>, drops: <aggregated>}` if any drops exist, else `nil`. Preserve existing document-level `parse_error` behavior (missing sentinel, bad YAML) but migrate its value into the new Hash shape (`{summary: <existing string>, drops: []}`).
- [X] T034 [US1] Update `CanonDelta.from_hash` in the same file to accept `parse_error` as String (legacy) or Hash (new). String → `{summary: <string>, drops: []}`. Hash → pass through with string-keyed normalization. Covers data-model.md §1 backwards-compat.
- [X] T035 [US1] Update `CanonDelta#to_hash` to serialize `parse_error` as the new Hash shape when non-nil, or `null` when empty. Round-trip via YAML must preserve shape.
- [X] T036 [US1] Update `CanonDelta#apply!` in the same file (around line 132) to, after the existing applied-actions loop, iterate `@parse_error.dig('drops') || []` and append one `AuditFinding.open(kind: 'parse-drop', piece_id: @piece_id, canon_delta_id: @id, explanation: "Dropped <section> entry: <value> (reason: <reason>)", ...)` per drop. Existing `malformed-delta` behavior preserved for document-level `parse_error.summary` without drops.
- [X] T037 [US1] Add `canon_review_parse_drop_render` logic in `eidos/lib/eidos/cli/canon.rb` `review` command: when enumerating findings, render `parse-drop` kind with a `[parse-drop]` label plus section/value/reason lines per `contracts/cli-flags.md`. File path verified via `eidos/lib/eidos/cli/canon.rb`.
- [X] T038 [US1] [P] Search `eidos/lib/` for any other `warn` calls that signal a data-loss or degradation event (the broader silent-fallback-via-stderr pattern beyond canon-delta). Convert each into either a raise, a structured result, or an AuditFinding open. Per FR-023.

**Checkpoint**: US1 complete. A user running `eidos canon review` on a world with a malformed LLM response sees every dropped entry as a finding. No silent stderr warns remain in the canon-delta pipeline.

---

## Phase 6: User Story 2 — Canon-delta entities persist to bible (Priority: P1)

**Goal**: When a canon-delta is applied with a well-formed entity declaration (e.g., `{name: "Arthur", description: "A programmer"}`), a file appears on disk at `data/story_bible/characters/arthur.yml`. Works whether the LLM emitted `id`, `name`, or both. Depends on US1 being landed (uses new drop-recording for the "neither id nor name" case).

**Independent Test**: Hand-craft a canon-delta YAML declaring one character by name only. Call `CanonDelta.parse` then `apply!`. Assert `data/story_bible/characters/arthur.yml` exists with description `"A programmer"`. Then craft one with neither id nor name; assert `parse_error.drops` names the entry.

### Tests for User Story 2

- [X] T039 [P] [US2] Unit spec in `eidos/spec/eidos/canon_delta_spec.rb`: `normalize_section` derives `id` from `name` via `ValidationUtils.slugify` when `id` is absent. `{"name" => "Arthur's Apartment"}` → normalized `id == "arthurs-apartment"` (per existing slugify rules).
- [X] T040 [P] [US2] Unit spec in the same file: entry with neither `id` nor `name` lands in `parse_error.drops` with reason `"missing both id and name"`. Covers the safety net from R3.
- [X] T041 [P] [US2] Unit spec for apply-path raise in `eidos/spec/eidos/canon_delta_spec.rb`: directly constructing a `CanonDelta` with a `new_characters` entry that has no `id` (bypassing normalization) and calling `apply!` raises a clear error — not `return nil` silently. Defense-in-depth per R3.
- [X] T042 [US2] Integration spec `eidos/spec/integration/user_scale/canon_delta_persists_to_bible_spec.rb`: uses `MOCK_RESPONSE=canon_delta_arthur_well_formed` (T005) to produce a piece in a fresh world, then asserts `data/story_bible/characters/arthur.yml` exists on disk and its `description` field matches the mock's declaration. Covers SC-003.

### Implementation for User Story 2

- [X] T043 [US2] Update `CanonDelta.normalize_section` in `eidos/lib/eidos/canon_delta.rb` (the method already changed in T032) to, after the `entry.is_a?(Hash)` guard, derive `id` from `name` via `ValidationUtils.slugify(normalized['name'])` when `normalized['id']` is absent. If both are absent, push a drop record and skip. Covers R3 fix (1) and the corresponding US1 "missing both" case.
- [X] T044 [US2] Update `CanonDelta#apply_character` in the same file (line 235): replace `return nil unless id` with `raise ArgumentError, "canon-delta new_characters entry reached apply with no id (should have been dropped in normalize_section)"`. Same change in `apply_location` (line 248). Per R3 fix (2) and the silent-fallback ban.
- [X] T045 [US2] Same replace pattern in `CanonDelta#apply_update` (line 284): current early return on `id.nil? || attr.empty?` — split the conditions, raise on `id.nil?`, keep graceful handling for `attr.empty?` (or raise both — choose per spec FR-022 to raise; empty attr should also have been caught earlier).
- [X] T046 [US2] [P] Verify no other engine path relies on `apply_*` silently no-oping on missing id. Search `eidos/lib/` for `return nil unless id` and similar patterns. Per FR-022, each needs to raise, return a Result, or emit a finding.

**Checkpoint**: US2 complete. Produced pieces whose LLM emitted well-formed canon deltas result in bible entries on disk. The demo run's empty `data/story_bible/characters/` is fixed.

---

## Phase 7: User Story 5 — No orphan scaffold directories (Priority: P2)

**Goal**: `eidos world new` creates no empty directories under `content/`. Form-specific directories appear on first `produce` of that form via `FileUtils.mkdir_p` at write time. Existing worlds unchanged.

**Independent Test**: Shell `world new --quick ...` into a temp dir, then `find <dir>/content -type d` returns only `content/` itself. Then shell `produce piece --form haiku`, re-run find, and assert `content/pieces/haiku/` now exists. Depends on US3 (non-interactive world creation).

### Tests for User Story 5

- [X] T047 [P] [US5] Unit spec in `eidos/spec/eidos/cli/world_new_scaffold_layout_spec.rb` (new file): calls `create_directories(target)` directly and asserts `Dir.children(File.join(target, 'content'))` is empty.
- [X] T048 [US5] Integration spec `eidos/spec/integration/user_scale/fresh_world_no_orphan_dirs_spec.rb`: shells `world new --quick`, walks `<world>/content/` with `Find.find`, asserts zero directory entries other than `content/` itself. Covers SC-005.
- [X] T049 [US5] Integration spec `eidos/spec/integration/user_scale/lazy_form_dir_mkdir_spec.rb`: shells `world new --quick` then `produce piece --form haiku --prompt x` (with `MOCK_AI=true`), asserts `<world>/content/pieces/haiku/` now exists with at least one `.md` file. Covers FR-015.
- [X] T050 [P] [US5] Regression spec in `eidos/spec/integration/user_scale/existing_world_untouched_spec.rb`: asserts the path `worlds/one-review-man/content/chapters` exists on disk before and after running the feature's CLI commands; no migration, no removal. Covers FR-016.

### Implementation for User Story 5

- [X] T051 [US5] Delete lines creating `content/chapters/` and `content/characters/` from `Eidos::CLI::World#create_directories` in `eidos/lib/eidos/cli/world.rb` (lines 303-304 today). Keep `data/` and the `content/` root directory creation.
- [X] T052 [US5] [P] Grep-audit `eidos/lib/` for other eager `mkdir_p` of form-specific content dirs. Likely none but confirm — produce/chapter-generator code paths should already `mkdir_p(File.dirname(output_path))` at write time. If a gap is found, add `mkdir_p` at the write site, not at the scaffold site.

**Checkpoint**: US5 complete. Newly created worlds have clean `content/` trees. `worlds/one-review-man` untouched.

---

## Phase 8: User Story 6 — Piece-first `world status` (Priority: P3)

**Goal**: `eidos world status` reports piece counts grouped by form, enumerated from `content/pieces/<form>/*.md` and `content/chapters/*.md`. Empty-world suggestion is generic (`produce piece --form <form>`), not chapter-specific. Chapters remain one row in the counts table.

**Independent Test**: Produce 2 vignettes and 1 haiku in a fresh world. Shell `world status`. Assert stdout contains `vignette: 2` and `haiku: 1`, does NOT contain `Run: produce chapter` as a hint. Depends on US3 (to scaffold the test world); independent of US1/US2/US4/US5.

### Tests for User Story 6

- [ ] T053 [P] [US6] Unit spec in `eidos/spec/eidos/cli/world_status_piece_first_spec.rb` (new file): given a world path with `content/pieces/vignette/a.md`, `b.md`, `content/pieces/haiku/c.md`, `Eidos::CLI::World#status` output contains `vignette: 2` and `haiku: 1` and total 3.
- [ ] T054 [P] [US6] Unit spec in the same file: empty world (zero piece files) output contains generic "produce piece" hint and does NOT contain `produce chapter` as the primary suggestion. Covers FR-018.
- [ ] T055 [P] [US6] Unit spec in the same file: world containing `content/chapters/chapter-01.md` (legacy chapter form) shows `chapter: 1` in the counts table — chapters remain a valid form.
- [ ] T056 [US6] Integration spec `eidos/spec/integration/user_scale/world_status_piece_first_spec.rb`: uses T002 helper to scaffold + produce two forms (mock LLM), shells `world status`, asserts stdout per the above scenarios. Covers SC-006.

### Implementation for User Story 6

- [ ] T057 [US6] Rewrite the progress/next-step section of `Eidos::CLI::World#status` in `eidos/lib/eidos/cli/world.rb` to: (a) enumerate `content/pieces/*/` and `content/chapters/` on disk, (b) build a `{form => count}` hash, (c) render the `[Pieces by form]` block per `contracts/cli-flags.md`, (d) choose the next-step hint based on total count (generic when zero; optional when non-zero). Remove any hardcoded "chapters written" / "produce chapter" strings.
- [ ] T058 [US6] Extract the disk-enumeration helper to a small private method `enumerate_pieces_by_form(world_path)` returning the hash, so it is reusable and testable in isolation.

**Checkpoint**: US6 complete. `world status` describes any world (chapter-based, piece-based, or mixed) in terms of what is on disk.

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: Validate the feature end-to-end, confirm SC-007 via `/user-qa`, and leave the repo in a reviewer-ready state.

- [ ] T059 [P] Run full unit suite: `cd eidos && MOCK_AI=true bundle exec rspec`. Expected 0 failures and coverage floor not dropped. If coverage rose, bump `EIDOS_COVERAGE_FLOOR` in `eidos/spec/support/coverage_setup.rb` to the new minimum.
- [ ] T060 [P] Run user-scale integration suite: `cd eidos && MOCK_AI=true bundle exec rspec spec/integration/user_scale/`. Expected 0 failures.
- [ ] T061 Run `scripts/demo_job_hunt.sh` against a fresh `~/worlds/job-hunt`: verify `world_config.yml` preserves premise, `data/story_bible/characters/arthur.yml` exists (when LLM cooperates), `content/chapters/` does NOT exist, `world status` is piece-first, `canon review` surfaces any drops.
- [ ] T062 Execute `/user-qa` via Claude Code against the demo world with **live LLM**: `/user-qa scripts/demo_job_hunt.sh "..."` with the full demo-intent string. Expected verdict: PASS across Tier-1, Tier-2, Tier-3. Covers SC-007 and CLAUDE.md Definition of Done.
- [ ] T063 [P] Cross-reference all SC-001..SC-009 against executed tests. Create a short "SC → task ID" table at the top of `specs/015-scaffold-hardening/quickstart.md` so a reviewer can trace each success criterion to the covering task.
- [ ] T064 [P] Run RuboCop: `cd eidos && bundle exec rubocop`. Fix any new violations introduced by 015 tasks. Do NOT mass-fix pre-existing issues; stay in scope.
- [ ] T065 Update `specs/015-scaffold-hardening/tasks.md` — mark every task `[X]` only after validating it via the quickstart. Commit.

---

## Dependencies & Execution Order

### Phase dependencies

- **Phase 1 (Setup)**: No dependencies. T001–T005 can overlap.
- **Phase 2 (Foundational)**: Depends on Phase 1 (needs the integration dir to exist for future cross-references). T006 should land before any implementation task lands so the silent-fallback ban is in effect for new code.
- **Phase 3 (US3)**: Depends on Phase 2 (CLAUDE.md ban) only. Otherwise independent.
- **Phase 4 (US4)**: Depends on Phase 3 — US4 tasks T021, T022 extend the Thor flag surface added in T012.
- **Phase 5 (US1)**: Independent of Phase 3/4. Can land in parallel once Phase 2 is done.
- **Phase 6 (US2)**: Depends on Phase 5 — US2's normalize-section changes (T043) extend the method rewritten in T032.
- **Phase 7 (US5)**: Depends on Phase 3 (integration tests shell `world new --quick`).
- **Phase 8 (US6)**: Depends on Phase 3 for its integration tests; US4 for the metadata action-item rendering hook in status output. Can reuse the enumeration helper.
- **Phase 9 (Polish)**: Depends on all prior phases.

### User story dependencies

- **US3 (P1)**: Standalone within its phase. Unblocks every integration test downstream.
- **US4 (P2)**: Extends US3's flag surface; US4's status-surfacing (T024) ties into US6's status output (T057) — overlap in same file.
- **US1 (P1)**: Standalone. No cross-story dependency.
- **US2 (P1)**: Depends on US1's `normalize_section` rewrite (T032) — US2's T043 extends it to derive `id` from `name`.
- **US5 (P2)**: Standalone implementation; integration tests depend on US3.
- **US6 (P3)**: Standalone implementation; integration tests depend on US3 and US4 (metadata line).

### Within each user story

- Tests authored first per postmortem §3 prevention rule. Each unit/fuzz spec should fail before its implementation task lands; each integration spec drives a real CLI shell invocation.
- Implementation tasks follow TDD: fail → implement → green.
- Integration spec closes out the story.

### Parallel opportunities

- T004, T005 are `[P]` within Phase 1 — no file overlap.
- T007, T008, T009 are `[P]` within US3 tests — different files or isolatable sections.
- T017, T018 are `[P]` within US4 tests.
- T027, T028, T029, T030 are `[P]` within US1 tests — four different spec files.
- T039, T040, T041 are `[P]` within US2 tests — same file (canon_delta_spec.rb); CAN be authored together in one sitting but the `[P]` is loose here since they touch the same file.
- T047, T050 are `[P]` within US5.
- T053, T054, T055 are `[P]` within US6 tests (same file, grouped contexts).
- T059, T060 are `[P]` in Phase 9.
- US1 and US3 can be worked on by different developers in parallel once Phase 2 is done (different files, different stories).
- US5's implementation (T051) is a tiny deletion and can land in parallel with any US1/US2 work.

---

## Parallel Example: User Story 1

```bash
# Author all US1 unit specs in parallel (different files):
Task: "T027 [P] [US1] Unit spec for parse_error new shape in eidos/spec/eidos/canon_delta_spec.rb"
Task: "T028 [P] [US1] Unit spec for legacy-string tolerance in eidos/spec/eidos/canon_delta_spec.rb"
Task: "T029 [P] [US1] Fuzz spec in eidos/spec/eidos/canon_delta_fuzz_spec.rb"
Task: "T030 [P] [US1] Unit spec for AuditFinding kind in eidos/spec/eidos/audit_log_spec.rb"

# Then implement sequentially (same file — canon_delta.rb):
Task: "T032 [US1] Rewrite CanonDelta.normalize_section"
Task: "T033 [US1] Update CanonDelta.parse to aggregate drops"
Task: "T034 [US1] Update CanonDelta.from_hash for legacy tolerance"
Task: "T035 [US1] Update CanonDelta#to_hash for new parse_error shape"
Task: "T036 [US1] Update CanonDelta#apply! to open parse-drop findings"
# T037 (canon CLI render) can run in parallel with T036 — different file
Task: "T037 [US1] canon review render for parse-drop in eidos/lib/eidos/cli/canon.rb"
```

---

## Implementation Strategy

### MVP definition

**US3 alone is the MVP.** Rationale: every integration test in 015 depends on non-corrupting non-interactive world creation; landing US3 unblocks the user-scale harness, which in turn becomes the safety net for US1/US2. A shipping US3 plus Phase 1 plus the CLAUDE.md ban (T006) is the smallest increment that delivers both a user-visible fix and a regression-prevention mechanism.

### Increment 1 — MVP (US3 + infrastructure)

1. Phase 1 complete (T001–T005).
2. Phase 2 complete (T006).
3. Phase 3 complete (T007–T016).
4. Run T060 (integration suite), verify US3 scenarios pass.
5. Commit + push — ready for early review.

### Increment 2 — substrate restoration (US1 + US2)

1. Phase 5 complete (T027–T038) — US1 surfaces canon-delta drops.
2. Phase 6 complete (T039–T046) — US2 persists entities to bible.
3. Run T060, verify canon-delta scenarios pass.
4. Commit + push.

### Increment 3 — metadata honesty (US4)

1. Phase 4 complete (T017–T026) — US4 sentinel, no more silent fallback to "fiction".
2. Run T060. Commit + push.

### Increment 4 — cosmetic cleanup (US5 + US6)

1. Phase 7 + Phase 8 complete (T047–T058).
2. Run T060. Commit + push.

### Increment 5 — validation

1. Phase 9 complete (T059–T065).
2. **Blocking gate: T062 `/user-qa` live-LLM PASS.**
3. Mark all tasks `[X]`. Commit + push. Open PR.

### Parallel team strategy

If two developers available after Phase 2:

- Dev A: US3 → US4 (Phase 3 → Phase 4 — tied by same Thor options block).
- Dev B: US1 → US2 (Phase 5 → Phase 6 — tied by same `canon_delta.rb` file).
- After both land: either dev picks up US5 + US6 + polish.

Three devs: split US3, US1, and US5 after Phase 2. US5 is small enough to land inside one Phase-1 timebox.

---

## Notes

- `[P]` = different files AND no dependency on incomplete task.
- `[USx]` label required for Phase 3–Phase 8 tasks.
- Every integration spec in `eidos/spec/integration/user_scale/` must use the T002 helper — no direct `Eidos::CLI::*.new.invoke(...)`. If you find yourself reaching for the class, step back and shell the CLI.
- TDD per postmortem §3.1: write failing test → watch it fail → implement → green. Do not skip the "watch it fail" step; that is how we caught 014's silent-fallback gaps.
- Do NOT weaken `/user-qa` to unblock CI. If it fails, fix the root cause.
- Verify task completion per quickstart.md before marking `[X]`. Green unit tests alone do not satisfy Definition of Done.
- Commit after each task or logical group. Reference the task ID in the commit subject (`feat(015/T032): rewrite CanonDelta.normalize_section to record drops`).

**Task count**: 65 (T001–T065).
**Per user story**: US1=12 (T027–T038), US2=8 (T039–T046), US3=10 (T007–T016), US4=10 (T017–T026), US5=6 (T047–T052), US6=6 (T053–T058). Setup=5, Foundational=1, Polish=7.
**Parallel markers**: 27 tasks tagged `[P]`.
**MVP scope**: Phase 1 + Phase 2 + Phase 3 = T001..T016 (16 tasks).
