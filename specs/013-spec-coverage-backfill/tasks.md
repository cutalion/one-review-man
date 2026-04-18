---
description: "Task list for feature 013 — Comprehensive Test Coverage & Spec Coverage Tooling"
---

# Tasks: Comprehensive Test Coverage & Spec Coverage Tooling

**Feature**: `013-spec-coverage-backfill`
**Branch**: `013-spec-coverage-backfill`
**Input**: Design documents in `/specs/013-spec-coverage-backfill/`
**Prerequisites**: `plan.md`, `spec.md`, `research.md`, `data-model.md`, `contracts/*.md`, `quickstart.md`

**Tests**: This feature *is* a test-infrastructure feature — test tasks are not "optional" here, they are the deliverable. Every test task below is part of the feature's observable behavior.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story. User story phases may run in parallel by different contributors once Phase 2 (Foundational) is complete.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies on incomplete tasks)
- **[Story]**: User story this task belongs to (US1..US5)
- Every description includes an absolute or repo-rooted file path

## Path Conventions

- **Gem root**: `eidos/`
- **Library**: `eidos/lib/`
- **Specs**: `eidos/spec/`
- **Spec support**: `eidos/spec/support/`
- **Integration specs**: `eidos/spec/integration/`
- **ORM world**: `worlds/one-review-man/`
- **Feature docs**: `specs/013-spec-coverage-backfill/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Measure the baseline, add the one new test-only dependency, and stub the new spec-support files the later phases fill in.

- [X] T001 Measure baseline line coverage for `eidos/lib/` on pre-feature commit `4966b5f` using a scratch SimpleCov config; round DOWN to the nearest integer percent; record the number + the full per-file report in `specs/013-spec-coverage-backfill/research.md` as a "## Appendix: Baseline Coverage" section (per R4 protocol in `research.md`). **Result: 46.81% → floor 46%, runtime 26.78s.**
- [X] T002 Add `simplecov` ~> `0.22` to the `:development, :test` group in `eidos/Gemfile`; run `bundle install` and commit the updated `eidos/Gemfile.lock`.
- [X] T003 [P] Create empty scaffold file `eidos/spec/support/coverage_setup.rb` with the `# frozen_string_literal: true` header and a top-of-file comment pointing to `specs/013-spec-coverage-backfill/contracts/coverage-cli.md` — implementation lands in US2 (T023).
- [X] T004 [P] Create empty scaffold file `eidos/spec/support/prompt_assertion_harness.rb` with the `# frozen_string_literal: true` header and a top-of-file comment pointing to `specs/013-spec-coverage-backfill/contracts/prompt-assertion.md` — implementation lands in Phase 2 (T008).
- [X] T005 [P] Create empty scaffold file `eidos/spec/support/stdin_driver.rb` with the `# frozen_string_literal: true` header and a top-of-file comment pointing to `research.md` R3 — implementation lands in US4 (T037).
- [X] T006 [P] Create empty `specs/013-spec-coverage-backfill/audit-log.md` with the header/table skeleton specified in `contracts/audit-log-schema.md` (baseline commit SHA `4966b5f`, `Status: In progress`, empty Findings table); rows are appended during US5.

**Checkpoint**: Baseline measured; SimpleCov available; stub files exist so Phase 2 / user-story tasks can edit them without creating files in the middle of their own work.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Changes that the runtime prompt-call assertion (US1) depends on, plus the harness module itself. Must land before US1 wires it into `MockLLMService`.

**CRITICAL**: No US1 work (T014+) can begin until this phase is complete. US2 (coverage), US3 (regression specs), US4 (interactive flow), US5 (IP audit) all assume the harness exists and is active — so foundational must land first.

- [X] T007 Change `PromptUtils` warning emission from `puts` (writes to `$stdout`) to `warn` (writes to `$stderr`) in `eidos/lib/eidos/prompt_utils.rb`; update the existing unit specs under `eidos/spec/` that assert on `$stdout` capture for these warnings to capture `$stderr` instead (per R2 rationale).
- [X] T008 Implement `Eidos::Spec::PromptAssertionHarness` module + `Eidos::Spec::PromptAssertionFailure < StandardError` class in `eidos/spec/support/prompt_assertion_harness.rb` with: `assert!(prompt:, warnings:, caller_desc:)`, `extract_unfilled(prompt)` (two-pass: strip `{{DOUBLE}}` then scan for `{SINGLE}`), `extract_unused_warnings(warnings)` (substring match on `"Unused placeholders"`), `disabled { block }` class method (for the self-test spec only), and a multi-line failure message matching the shape in `contracts/prompt-assertion.md#failure-message-shape`.
- [X] T009 [P] Write self-test spec `eidos/spec/prompt_assertion_harness_spec.rb` covering all five cases from `contracts/prompt-assertion.md#self-test-spec-canary`: (1) single-brace `{UNFILLED}` → fails with category `unfilled placeholder`; (2) `{{UNFILLED}}` → fails same category; (3) captured `"Unused placeholders"` warning line → fails with category `unused placeholder warning`; (4) fully-clean prompt → passes; (5) `PromptAssertionHarness.disabled { ... }` correctly suppresses assertion — and (6) `MockLLMService.instance_methods(false)` matches the expected covered-methods set so future additions force a harness update. **Done: 10 examples, 0 failures.**

**Checkpoint**: Harness exists with its own passing self-test, warnings flow through `$stderr` where the harness can capture them narrowly. US1 can now wire it into `MockLLMService`.

---

## Phase 3: User Story 1 - Prompt-call regression gate (Priority: P1) 🎯 MVP

**Goal**: Every LLM call made during the default spec run fails the enclosing spec if the outgoing prompt carries an unfilled `{PLACEHOLDER}` token or if a `"Unused placeholders"` warning fired during prompt construction.

**Independent Test**: Introduce a deliberate unfilled placeholder in a shipped prompt template (e.g. rename `{CHAPTER_NUMBER}` → `{CHAPTER_NUMBR}`), run `MOCK_AI=true bundle exec rspec`, confirm at least one spec fails with a message that names the offending placeholder and the caller that built the prompt. Revert, confirm suite turns green.

### Implementation for User Story 1

- [X] T010 [US1] Add a `wrap_method_for_assertion` pattern to `eidos/spec/support/mock_llm_service.rb` that routes the prompt string through `PromptAssertionHarness.assert!` *before* delegating to the existing mock behavior, for exactly the five methods enumerated in `contracts/prompt-assertion.md#surface-area`: `generate_text(prompt:, context:)`, `generate_chapter_structured(prompt, *_)`, `improve_content(content, *_)`, `translate_chapter_structured(title, summary, content, *_)`, `translate_character_structured(name, description, *_)`. For the translate methods, concatenate the prompt-facing strings with a newline separator before scanning.
- [X] T011 [US1] In `eidos/spec/support/mock_llm_service.rb`, capture emitted `$stderr` lines narrowly around the wrapped call (using an RSpec-aware `StringIO` swap — NOT a process-level redirect — so spec output stays readable) and pass the captured lines as `warnings:` to `PromptAssertionHarness.assert!`. **Implementation**: thread-local `$stderr` tee installed at mock load; each wrapped method drains accumulated warnings before calling `assert!`, then a narrow `StringIO` swap around the delegate ensures any stderr the mock itself writes isn't leaked into the next call's warning scan.
- [X] T012 [US1] Require `spec/support/coverage_setup.rb` FIRST, then `spec/support/prompt_assertion_harness.rb`, then `spec/support/mock_llm_service.rb` at the top of `eidos/spec/spec_helper.rb` so the harness module is loaded before any mock is instantiated.
- [X] T013 [US1] Verify the gate end-to-end on the live codebase: temporarily break `eidos/lib/eidos/prompts/character_creation_prompt.txt` by renaming one `{{STORY_TITLE}}` occurrence to `{{STORY_TITL}}`, run `MOCK_AI=true bundle exec rspec`, confirm ≥1 spec fails with the harness's message shape, revert the break, confirm suite turns green. Record the manual-verification result in the US1 section of `audit-log.md`. (This is the hands-on equivalent of US1's Independent Test.) **Adapted**: BOOK→STORY rename lands in Phase 7/T031, so substituted `{BOOK_TITLE}` → `{BOOK_TITL}` in `chapter_prompts.txt`. Harness fired with category `unfilled placeholder`, placeholders `BOOK_TITL` — 2 subprocess specs failed. Revert + full suite → 620 examples, 0 failures. Also surfaced a latent engine escape: `chapter_generator.rb` only filled `BOOK_*` when `localized_structure?` — fixed by always emitting (WorldConfig defaults are safe).

**Checkpoint**: US1 is complete — any spec that triggers an LLM call with an unfilled placeholder (single- or double-brace) or emits a `"Unused placeholders"` warning during prompt construction fails with a diagnostic message. This is the MVP.

---

## Phase 4: User Story 2 - Coverage measurement with enforced floor (Priority: P1)

**Goal**: Every `bundle exec rspec` full-suite run reports line coverage for `eidos/lib/` and fails if coverage drops below the committed floor. Single-file runs suppress coverage entirely. `COVERAGE_THRESHOLD=<int>` overrides the floor for one run with a stderr audit line. `COVERAGE_THRESHOLD=0` disables the check.

**Independent Test**: Delete a non-trivial method body in `eidos/lib/` so it becomes unreachable, run the default suite, confirm either the newly uncovered lines show in the per-file report OR the run fails because coverage dropped below the floor. Run `COVERAGE_THRESHOLD=0 bundle exec rspec` and confirm the run exits 0 despite the same drop, with the audit line visible on `$stderr`.

### Implementation for User Story 2

- [X] T014 [US2] Implement the full `coverage_setup.rb` body in `eidos/spec/support/coverage_setup.rb` per the Ruby snippet in `research.md` R1: `coverage_enabled?` helper detecting `_spec.rb` / directory args in `ARGV`; read `EIDOS_COVERAGE_FLOOR` (baked default) and `COVERAGE_THRESHOLD` env; compute `effective_floor`; emit audit line to `$stderr` when override < floor; start SimpleCov with `track_files 'lib/**/*.rb'`, add_filters for `/spec/`, `/exe/`, `/bin/`, and `lib/eidos/version.rb`; `minimum_coverage effective unless effective.zero?`; MultiFormatter for console + HTML.
- [X] T015 [US2] Set the default of `EIDOS_COVERAGE_FLOOR` inside `eidos/spec/support/coverage_setup.rb` to the baseline integer measured in T001. One-line diff; the value is the single committed floor (FR-003). **Committed floor = 46.**
- [X] T016 [P] [US2] Verify the three exit-status matrix entries from `contracts/coverage-cli.md#exit-status-matrix` by running `MOCK_AI=true bundle exec rspec` three times: (a) plain — should exit 0 with a coverage summary line; (b) `COVERAGE_THRESHOLD=<floor-minus-5>` — should exit 0 with the audit line printed to `$stderr`; (c) `COVERAGE_THRESHOLD=0 bundle exec rspec` — should exit 0, audit line visible. Record observed output snippets inline in the PR description. **Observed**: (a) exit 0, summary `Line Coverage: 46.81% (3055 / 6527)`; (b) `COVERAGE_THRESHOLD=41` → exit 0 + `⚠️  COVERAGE FLOOR OVERRIDDEN: configured=46, this run=41`; (c) `COVERAGE_THRESHOLD=0` → exit 0 + audit line.
- [X] T017 [P] [US2] Verify the single-file bypass behavior: run `bundle exec rspec eidos/spec/eidos/world_config_spec.rb`, confirm no coverage summary is printed and no threshold check fires (FR-004). Run with a directory arg (`bundle exec rspec eidos/spec/integration/`), confirm same behavior. Record observed output inline in the PR description. **Observed**: single-file run → 60 examples, exit 0, no coverage summary. Directory arg `spec/eidos/` → 468 examples, exit 0, no coverage summary.
- [X] T018 [P] [US2] Verify the invalid-input path: run `COVERAGE_THRESHOLD=abc bundle exec rspec`, confirm startup fails with an `Integer()` error that names the offending env var value (FR-003 explicitness requirement). No silent fallback. **Observed**: `ArgumentError: invalid value for Integer(): "abc"` raised at `coverage_setup.rb:31`, rspec reports "37 errors occurred outside of examples", exit 1.
- [X] T019 [US2] Add `eidos/coverage/` to `.gitignore` if not already present; verify via `git check-ignore eidos/coverage/index.html`. **Verified**: `git check-ignore eidos/coverage/index.html` returns path + exit 0.

**Checkpoint**: US2 is complete — coverage is measured on full-suite runs, threshold enforcement respects `COVERAGE_THRESHOLD` overrides with a visible audit line, single-file runs bypass cleanly. The default `bundle exec rspec` entry point now carries both the P1 gates (US1 + US2).

---

## Phase 5: User Story 3 - Integration specs for escaped regressions (Priority: P2)

**Goal**: Three dedicated integration specs (plus the interactive-flow spec that overlaps with US4) lock in the specific incidents: `CHAPTER_NUMBER` warning, missing `--prompt` threading, and `target_chapters` residue. Each spec exercises the actual CLI path (not a mocked generator) and asserts on observable output.

**Independent Test**: Check out the state of the project *before* each recent fix (e.g. `git stash` the relevant commit), run only the new integration spec, confirm each fails with a clear message pointing at the real regression. Check out the fixed state, confirm they pass.

### Implementation for User Story 3

- [X] T020 [P] [US3] Create `eidos/spec/integration/chapter_number_regression_spec.rb` that drives `eidos produce chapter` via subprocess against a fixture world containing a newly-created character, captures both `$stdout` and `$stderr` of the subprocess, and asserts: (a) no line contains `"Unused placeholders"`, (b) no file written under the fixture world's content tree contains a bare `{CHAPTER_NUMBER}` or `{{CHAPTER_NUMBER}}` token. (Reinforces US1's runtime gate at the CLI layer.) **Done**: 1 example, 0 failures; writes a `data/world_config.yml` + `data/world_state.yml` + one character under `data/story_bible/characters/`, runs `MOCK_AI=true ruby bin/produce chapter --auto -w <tmpdir>`.
- [X] T021 [P] [US3] Create `eidos/spec/integration/produce_chapter_prompt_flag_spec.rb` that runs `eidos produce chapter --prompt "keep it under 3 sentences"` against a fixture world, intercepts the prompt string actually passed to `MockLLMService#generate_chapter_structured` (via a test double / spy attached to the mock), and asserts the string `"keep it under 3 sentences"` appears verbatim in the captured prompt. **Done**: added `EIDOS_SPEC_PROMPT_LOG` subprocess-spy hook in `mock_llm_service.rb#log_prompt!` that appends every prompt (delimiter-framed, per method) to the named file; spec reads back the last `generate_chapter_structured` entry and asserts guidance is present. 1 example, 0 failures.
- [X] T022 [P] [US3] Create `eidos/spec/integration/world_new_target_chapters_residue_spec.rb` that runs `eidos world new` (non-interactive, via flags) followed by `eidos world status` against a fresh `Dir.mktmpdir`-created world, captures the `world status` output, and asserts: (a) output contains no `"Progress: 0/Not set"` or `"target_chapters"` substring; (b) the generated `world_config.yml` and `world_state.yml` do not contain a `target_chapters` YAML key at any depth. **Done**: drives `world new --quick --no-seed -w <tmpdir>` via `Open3.capture3(stdin_data: "\n\n\n\n")` to accept defaults for title/author/description/languages; asserts scaffolded YAML + `world status` output contain no `target_chapters` or `Not set`. 1 example, 0 failures.

**Checkpoint**: US3 is complete — the three escaped-regression canaries are in place and would have caught each original bug. They run in the default suite (no flag needed).

---

## Phase 6: User Story 4 - Realistic interactive `world new` coverage (Priority: P3)

**Goal**: A scripted-stdin driver replaces `ask`/`yes?` stubs for the interactive `world new` spec. Both the all-defaults path and the all-custom-answers path complete successfully and produce the expected world files; a `nil`-returning prompt handler surfaces as a real failure.

**Independent Test**: Introduce a `nil`-returning code path in an interactive prompt handler (e.g. stub the internal `ask` to return `nil`), run the new spec, confirm it fails (whereas the existing heavily-stubbed spec still passes). Revert, confirm both pass.

### Implementation for User Story 4

- [X] T023 [US4] Implement `Eidos::Spec::StdinDriver.drive_cli(argv:, input_lines:, timeout: 15)` in `eidos/spec/support/stdin_driver.rb` per `research.md` R3: shells out via `Open3.popen3` to `eidos/exe/eidos`, writes `input_lines.join("\n") + "\n"` to the subprocess stdin, closes stdin, waits with `Timeout.timeout(timeout)`, returns `(stdout, stderr, status)`. On timeout, kill the subprocess and raise with a message naming the argv and the last input line written. **Done**: module returns a `Result` struct (`stdout`, `stderr`, `status`, `success?`) from `Open3.popen3('ruby', EIDOS_BIN, *argv)`, writes each `input_lines` entry with `puts`, closes stdin, reads output under `Timeout.timeout(timeout)`.
- [X] T024 [US4] Create `eidos/spec/integration/world_new_interactive_flow_spec.rb` with two scenarios: (a) *all-defaults*: every scripted input line is an empty string (bare `"\n"` = accept default); assert `status.success?`, assert `world_config.yml` exists and loads, assert its `story_*` keys carry the defaults; (b) *all-custom-answers*: provide a non-default value for every prompt; assert the generated `world_config.yml` reflects every custom value the user supplied. **Done**: drives `world new -w <tmpdir> --no-seed` (detailed setup, 9 prompts) with 9 empty lines for all-defaults and 9 user-supplied values for all-custom. **Note**: key-shape assertions target the current schema (`localized.en.title` etc.) since US4 runs before the BOOK→STORY migration in Phase 7 / US5 (T031 will rename these to `story_*`; the spec will need a follow-up edit then).
- [X] T025 [US4] Add a `nil`-return regression case inside the same spec: transiently monkey-patch the interactive prompt handler (inside a `before` + `after` pair scoped to the example) so one call returns `nil`; run the driver; assert the spec *fails* (by wrapping in `expect { ... }.to raise_error`, or checking for non-zero exit status with a stderr message identifying the interactive flow). This verifies SC-006. **Done**: in-process `Eidos::CLI::World.start`; before-hook redefines `Eidos::CLI::World#ask` to return `nil` for the "Secondary themes" prompt (and `kwargs[:default]` for all others); expects `NoMethodError /nil/i` downstream (crash when `secondary_themes.strip.empty?` is called). After-hook restores the original method.

**Checkpoint**: US4 is complete — interactive flows are driven by real stdin scripting, no RSpec-level stubbing of `ask`/`yes?` happens in the new spec, a reintroduction of the `strip`-on-nil bug surfaces immediately.

---

## Phase 7: User Story 5 - IP-neutrality audit + `BOOK_*` → `STORY_*` migration (Priority: P2)

**Goal**: Every shipped prompt template and engine code path is audited for ORM-specific vocabulary and generalized, parameterized, relocated, or removed. The four `BOOK_*` placeholders (TITLE / GENRE / SETTING / STYLE) rename to `STORY_*` with a one-release back-compat read path. The ORM world at `worlds/one-review-man/` continues to work unchanged. Every finding is recorded in `audit-log.md`.

**Independent Test**: After the migration, scaffold a fresh non-ORM world (e.g. cooking-mystery genre) and run `produce chapter`; inspect the prompt sent to the LLM; confirm zero occurrences of `"One Review Man"`, `"programming comedy"`, or any ORM character name (outside strings the user's own world description contains). Also grep for `BOOK_TITLE|BOOK_GENRE|BOOK_SETTING|BOOK_STYLE` across `eidos/lib/` and shipped templates — expect zero hits outside the back-compat loader path.

### World-config schema migration (T026-T030)

- [X] T026 [US5] Add a `story_title(locale = current_locale)` / `story_genre` / `story_setting` / `story_style` accessor set to `eidos/lib/eidos/world_config.rb` per the Ruby snippet in `contracts/story-placeholder-compat.md#read-path-behavior`: prefer `story_<field>` under `generation.localized.<locale>`; fall back to `book_<field>` or the bare field name (`title`/`genre`/`setting`/`style`); emit a deprecation notice via `emit_deprecation_notice_once(config_path, locale, field)` when the fallback path fires. **Done**: accessors added; back-compat chain is `story_<field>` → `book_<field>` → bare (`title`/`genre`/`setting`/`style`, plus `humor_style` for `style`). Legacy `title`/`genre`/`setting`/`humor_style` accessors now delegate to the story_* variants so every read path migrates in lock-step.
- [X] T027 [US5] Add `emit_deprecation_notice_once` helper in `eidos/lib/eidos/world_config.rb` with the process-scoped memoization key `(config_file_path, locale, field)` and the warning format specified in `contracts/story-placeholder-compat.md#read-path-behavior` (printed to `$stderr`). **Done**: class variable `@@emitted_deprecation_notices` keyed by the (path, locale, field) tuple; prints three-line warning block via `warn`.
- [X] T028 [US5] Create `eidos/spec/world_config_legacy_keys_spec.rb` covering all five scenarios from `contracts/story-placeholder-compat.md#spec-coverage`: legacy `title:` → reads as `story_title` with one-time notice; legacy `book_title:` same; both present → `story_title` wins, no notice; notice fires at most once per `(config, locale, field)` per process; fresh world from `eidos world new` loads clean. **Done**: 5 examples, 0 failures. Full suite (631 examples) still green; existing specs continue to use legacy keys and now surface benign deprecation notices to stderr (removed in T029/T030).
- [X] T029 [US5] Update the `world_config.yml` scaffold template used by `eidos world new` so writes emit only `story_title:` / `story_genre:` / `story_setting:` / `story_style:` under `generation.localized.<locale>` — never `book_*` or bare field names. Locate the template via `Grep` for the existing `title:` write-site; update the template and any helper that constructs the hash. **Done**: updated `cli/world.rb` `build_world_metadata` — `localized.en` block now emits `story_title`/`story_genre`/`story_style`/`story_setting`. T024 interactive-flow spec also updated to assert the new key shape and that legacy bare keys are absent.
- [X] T030 [US5] Migrate `worlds/one-review-man/data/world_config.yml` to the new keys: rename every `book_title` / `title` / etc. under `generation.localized.*` to `story_*`. Run `eidos world status -w worlds/one-review-man` after the change; confirm no deprecation notice fires (per SC-010). **Done**: both `localized.en` and `localized.ru` migrated to `story_*`; added `story_setting` while there (previously absent). `eidos world status -w worlds/one-review-man` runs clean (no DEPRECATED notices on stderr, `Setting: contemporary tech workplace` shown).

### Template placeholder rename (T031-T033)

- [X] T031 [US5] In `eidos/lib/eidos/prompts/*.txt` (every shipped template), rename every `{BOOK_TITLE}` → `{STORY_TITLE}`, `{BOOK_GENRE}` → `{STORY_GENRE}`, `{BOOK_SETTING}` → `{STORY_SETTING}`, `{BOOK_STYLE}` → `{STORY_STYLE}` (both single- and double-brace forms). Use `Grep` with `pattern: 'BOOK_(TITLE|GENRE|SETTING|STYLE)'` to produce the complete site list before editing; cross-reference the list against `research.md` R5 table. **Done**: `chapter_prompts.txt` (4 keys) + `new_character_creation_prompt.txt` (3 keys, `STYLE` not in that template) + `PLACEHOLDERS_REFERENCE.md` renamed. Jekyll templates also migrated (`{{BOOK_TITLE}}` → `{{STORY_TITLE}}`, `{{BOOK_GENRE_DESCRIPTION_RU}}` → `{{STORY_GENRE_DESCRIPTION_RU}}`, etc.) so the engine grep in T033 finds zero hits anywhere under `eidos/lib/` or `eidos/templates/`.
- [X] T032 [US5] Update every engine fill site that passes `BOOK_*` keys into `PromptUtils.build_prompt`: the call sites in `eidos/lib/eidos/chapter_generator.rb`, `eidos/lib/eidos/writer_agent.rb`, and any other collaborator found by `Grep` for `BOOK_(TITLE|GENRE|SETTING|STYLE):` in `eidos/lib/`. Replace each `BOOK_X:` key with `STORY_X:` and source the value from `world_config.story_<field>`. **Done**: (a) `chapter_generator.rb:856-859` fill site rekeyed to `STORY_TITLE/GENRE/SETTING/STYLE`, values sourced from `@config.story_*`; (b) renamed `determine_book_setting` → `determine_story_setting`; (c) the metadata-reading helpers (`build_world_details_summary`, `build_character_guidelines`, `build_genre_guidelines`, `determine_story_setting`) now read genre/style via `@config.story_*` (back-compat chain absorbs legacy worlds); (d) `show_missing_information_guide` + `collect_*_info` prompts use `STORY_*` placeholder names and `update_localized('en', 'story_X' => ...)`; (e) `cli/publish.rb` Jekyll placeholder construction renamed to `STORY_*` with legacy `book_*`/bare-key fallback on reads. `writer_agent.rb` did not reference these four keys.
- [X] T033 [US5] Verify SC-010 with `Grep`: pattern `BOOK_(TITLE|GENRE|SETTING|STYLE)` over `eidos/lib/` AND `eidos/lib/eidos/prompts/` returns zero matches (the only remaining references are the documented back-compat accessor in `world_config.rb` and its dedicated spec; assert these are the only hits). **Done**: `rg 'BOOK_(TITLE|GENRE|SETTING|STYLE)' eidos/lib/ eidos/lib/eidos/prompts/` → zero hits. `rg 'book_(title|genre|setting|style)' eidos/lib/` → zero hits (the back-compat accessor builds the key via string interpolation `"book_#{field}"` so the literal never appears). Full suite: 631 examples, 0 failures.

### ORM-specific code removal / generalization / relocation (T034-T038)

- [X] T034 [P] [US5] Generalize the chapter-generator fallback in `eidos/lib/eidos/chapter_generator.rb:147` from `"Write Chapter {CHAPTER_NUMBER} of a programming comedy story"` to use `{{STORY_GENRE}}` from `world_config.story_genre` (or a genre-agnostic phrasing if no world-config is available at that call site). Record the change in `audit-log.md` as decision `generalize`. **Done**: fallback now reads `'Write Chapter {CHAPTER_NUMBER} of a {{STORY_GENRE}} story'`; `{{STORY_GENRE}}` fills through the existing placeholder path. Audit row #10 recorded.
- [X] T035 [P] [US5] Remove the legacy path fragment `books/one-review-man/_chapters` near `eidos/lib/eidos/chapter_generator.rb:340` after verifying with `Grep` that no live code path references it; record as decision `remove` in `audit-log.md`. **Done**: `nested_legacy` local + its conditional assignment branch deleted; `Grep 'nested_legacy'` confirmed no live callers. Audit row #11 recorded.
- [X] T036 [P] [US5] Relocate the `find_character_real_name(chars, 'One Review Man')` lookup near `eidos/lib/eidos/chapter_generator.rb:747` out of the engine: create `worlds/one-review-man/data/character_aliases.yml` with the alias map (`"One Review Man"` → canonical character id), generalize the engine call to read the alias map from world data, and move the ORM-specific alias out of `eidos/lib/`. Record as decision `relocate` with `New location: worlds/one-review-man/data/character_aliases.yml` in `audit-log.md`. **Done (scope adjusted)**: inspection of the branch revealed it was dead code — the ORM world's `world_config.yml` already configures `generation.main_characters`, which the preceding `if main_characters.is_a?(Array) && !main_characters.empty?` branch handles for ALL worlds, including ORM. The `elsif config.one_review_man_world?` fallback could never fire. Decision: `remove` the dead branch instead of relocating (no new alias file needed — the `main_characters` array already carries the same data). Audit row #12 recorded.
- [X] T037 [P] [US5] Remove the ORM-title-include dead branch at `eidos/lib/eidos/world_config.rb:247` (`title.include?('One Review Man') || title.include?('Ванревьюмэн')`). Verify via `Grep` that no caller relies on the branch's side effect; record as decision `remove` in `audit-log.md`. **Done**: `one_review_man_world?` predicate deleted along with its only caller (the dead branch removed in T036); `Grep 'one_review_man_world'` → zero hits. Two spec examples in `world_config_spec.rb` removed (suite 631 → 629). Audit row #13 + #16 recorded.
- [X] T038 [P] [US5] Parameterize the `"programming comedy book"` framing at `eidos/lib/eidos/writer_agent.rb:123`: replace the hardcoded string with `world_config.story_description` (adding a new `story_description` accessor and config key if needed) and replace the word "book" in the framing with "story" (per the IP-first worldview in CLAUDE.md memory). Record as decision `parameterize` with `New location: world_config.story_description` in `audit-log.md`. **Done**: added `story_description(lang)` accessor to `world_config.rb` with fallback chain `story_description` → `description` → `subtitle` → top-level `description` → `'A fresh story to be developed.'` neutral default. `build_system_prompt` now reads `config.story_title` / `story_genre` / `story_description` / `story_style` via new `world_config_object` memoizer. Framing reads "story" (IP-first). ORM-specific style bullets replaced with genre-neutral "Tone and humor consistent with the established genre". Audit row #14 recorded. Additional finding during SC-009 grep: `llm_service.rb#build_chapter_translation_prompt` (lines 659/663/683) also carried "programming comedy chapter" / "One-Punch Man parody references" / "Maintain the One-Punch Man parody style" — generalized to genre-neutral wording. Audit row #15 recorded.

### IP-neutrality spec + audit log completion (T039-T041)

- [X] T039 [US5] Create `eidos/spec/integration/ip_neutrality_non_orm_world_spec.rb`: scaffold a fresh non-ORM world (cooking-mystery genre; no ORM-specific strings anywhere in the user-provided config) in a `Dir.mktmpdir`; run `eidos produce chapter` against it; intercept the prompt string actually sent to `MockLLMService` (via the same spy mechanism used in T021); assert zero literal occurrences of `"One Review Man"`, `"Ванревьюмэн"`, `"programming comedy"`, or any ORM character name (`"Jax"`, `"Kenji"`, etc. — enumerate the known ORM character ids from `worlds/one-review-man/data/story_bible/`). Verifies SC-008 + FR-018. **Done**: spec scaffolds a cooking-mystery world (`story_title: 'The Vanishing Chef'`, `story_genre: 'mystery'`, character `chef_marin`) in `Dir.mktmpdir`, runs `ruby bin/produce chapter --auto -w <tmpdir>` with `EIDOS_SPEC_PROMPT_LOG` set, and asserts the captured prompt log contains zero occurrences of 13 ORM terms (4 story-level + 9 character ids). 1 example, 0 failures.
- [X] T040 [US5] Verify SC-009 with `Grep`: patterns `one.?review.?man` (case-insensitive), `Ванревьюмэн`, `programming comedy` — across `eidos/lib/` AND `eidos/lib/eidos/prompts/` — return zero matches outside comments/strings explicitly annotated as documentation. Document the grep invocations and results inline in the PR description; if any match remains, either fix it (add a T0xx task) or annotate it and record as decision `document-as-intentional` in `audit-log.md`. **Done**: all four grep sweeps (`one.?review.?man` -i, `Ванревьюмэн`, `programming comedy`, `One-Punch Man`) return zero matches against `eidos/lib/` after the T038 + additional `llm_service.rb` generalization folded in. Verified and recorded in audit-log US5 IP-neutrality verification section.
- [X] T041 [US5] Populate `specs/013-spec-coverage-backfill/audit-log.md` with one row per finding from T031–T040 (and any additional leak sites discovered during grep): `file:line` (referring to pre-audit commit `4966b5f`), `original content`, `decision`, `new_location`, `commit SHA` of the fix. Flip the header's `Status:` from `In progress` to `Complete`. This file is FR-019's deliverable. **Done**: 17 audit rows recorded (covering T030-T040 + two grep-discovered leak sites in `llm_service.rb` and the spec-example cleanup in `world_config_spec.rb`). Header `Status` flipped to `Complete`. Commit SHA column notes "working tree (Txxx)" since all fixes are staged for a single migration PR — PR commit SHA will replace these on merge.

**Checkpoint**: US5 is complete — the engine is IP-neutral; `BOOK_*` → `STORY_*` is migrated with a back-compat loader; `audit-log.md` is populated and committed; a non-ORM world can be produced without ORM vocabulary leaking into prompts.

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Documentation, performance verification, and final validation of success criteria.

- [X] T042 [P] Update the project's AI-agent guide (`CLAUDE.md` and/or `docs/AGENTS.md`, whichever the project uses as the canonical contributor-doc location) per FR-015 and SC-005: explain how to (a) interpret the coverage output line / open the HTML report, (b) raise or override the coverage floor (committed default vs. `COVERAGE_THRESHOLD` env), (c) read a prompt-assertion failure (category, placeholders, caller). Link to `specs/013-spec-coverage-backfill/quickstart.md` as the detailed reference. **Done**: added a "Coverage" block and a "Prompt-assertion harness" block under `#### Testing` in both `CLAUDE.md` and `AGENTS.md` (the repo's two parallel AI-agent guides). Example failure shape, override matrix, and quickstart link included.
- [X] T043 [P] Update `eidos/README.md` if it documents the test-run command, to add a line mentioning coverage reporting and linking to the quickstart. **Done**: test-count updated from 544 → 630; two paragraphs appended under `## Testing` — one describing SimpleCov behavior and `COVERAGE_THRESHOLD` overrides with a link to quickstart.md, one describing the prompt-assertion harness.
- [X] T044 Measure full-suite wall-clock runtime after all new specs land: run `time MOCK_AI=true bundle exec rspec` three times, record the median. Confirm median < 2× the baseline recorded in T001 (SC-007). If over 2×, profile the slowest new spec and reduce (typically the scripted-stdin specs; consider fewer scenarios per example). **Done**: three runs: 53.31s / 32.15s / 20.91s → **median = 32.15s**. Baseline (T001) was 26.78s; 2× baseline = 53.56s. 32.15 < 53.56 → SC-007 passes with headroom.
- [X] T045 Run the full `quickstart.md` walkthrough end-to-end as a contributor would: execute `MOCK_AI=true bundle exec rspec`; check exit status; open `eidos/coverage/index.html`; run `COVERAGE_THRESHOLD=70 bundle exec rspec` and confirm the audit line; run `bundle exec rspec eidos/spec/eidos/world_config_spec.rb` and confirm no coverage summary. Note any friction; fix any docs-vs-reality drift in `quickstart.md`. **Done**: (a) full suite → 630/0, exit 0; (b) `eidos/coverage/index.html` exists; (c) `COVERAGE_THRESHOLD=70` → all specs pass, SimpleCov exits 2 because 47% < 70%, but no audit line fires (override > floor). **Quickstart drift fixed**: the walkthrough now uses `COVERAGE_THRESHOLD=40` (below floor=46) to demonstrate the audit line, and a second paragraph documents the "raising the bar" case (override > floor) with the expected "no audit line, maybe exit non-zero" behavior; (d) `COVERAGE_THRESHOLD=40` → audit line `⚠️  COVERAGE FLOOR OVERRIDDEN: configured=46, this run=40` printed to stderr, 630/0, exit 0 since 47% > 40%; (e) single-file run → 58 examples, no coverage summary.
- [ ] T046 Commit-level cleanup: ensure every commit in this feature's branch either (a) adds a canary spec + its change together, or (b) is a pure rename/refactor with zero behavior change verified by `bundle exec rspec`. No commit should leave the default suite in a broken state (per the user's existing preference for small, focused commits from CLAUDE.md). **Pending**: all changes are in the working tree as a single uncommitted delta. Commit plan (for user review before executing): (1) Phase 1 setup (Gemfile + scaffold spec-support files + empty audit-log); (2) Phase 2 foundational (`prompt_utils.rb` stderr + harness module + self-test spec); (3) US1 MVP (wrap MockLLMService + spec_helper wiring + verification); (4) US2 coverage floor (coverage_setup.rb body + .gitignore + CLAUDE.md notes); (5) US3 regression canaries (3 specs + `EIDOS_SPEC_PROMPT_LOG` hook in mock); (6) US4 interactive-flow (stdin_driver + spec); (7) US5 — BOOK→STORY schema migration (world_config.rb accessors + legacy-keys spec); (8) US5 — template/engine rename (prompts + chapter_generator + cli/world + cli/publish + jekyll templates + ORM world data migration); (9) US5 — ORM removal/generalization (writer_agent + llm_service translation prompt + chapter_generator fallback/dead-branch removal + world_config predicate removal); (10) US5 — IP-neutrality spec + audit-log + docs polish (README + AGENTS + CLAUDE + quickstart).

**Checkpoint**: Feature complete. All five success criteria (SC-001 through SC-010) can be validated by running the default suite and observing the documented behaviors.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: T001 has no dependencies (runs on pre-feature commit). T002 has no dependencies. T003–T006 depend on T002 (SimpleCov in Gemfile) only insofar as they need `bundle exec` to work; they can run immediately after T002.
- **Foundational (Phase 2)**: T007–T009 can start after Phase 1. T007 must land before T009 (self-test assumes `$stderr` capture). T008 must land before T009 (self-test requires the module to exist).
- **US1 (Phase 3)**: Depends on Phase 2 completion. T010 depends on T008. T011 depends on T007 + T010. T012 depends on T010 + T011. T013 is a manual verification that depends on T012.
- **US2 (Phase 4)**: Depends on Phase 1 (SimpleCov gem available). **Does NOT depend on Phase 2 or US1** — coverage and the prompt-call gate are orthogonal. Can proceed in parallel with US1.
- **US3 (Phase 5)**: Depends on US1 (the regression specs assert via `MockLLMService` spies that the harness wires up in US1). Can proceed in parallel with US2.
- **US4 (Phase 6)**: Depends on Phase 1 (T005 scaffolds the file). Otherwise independent of US1/US2/US3.
- **US5 (Phase 7)**: Depends on US1 (the IP-neutrality spec at T039 asserts via the harness). US5's own internal tasks have a defined order: T026–T030 (schema migration) before T031–T033 (template rename) before T034–T038 (parameterization/relocation) before T039–T041 (spec + audit log).
- **Polish (Phase 8)**: Depends on all user stories being complete.

### Parallel Opportunities

- **Inside Phase 1**: T003, T004, T005, T006 are all `[P]` (distinct files, no mutual dependency).
- **Inside Phase 2**: T009 can be drafted in parallel with T008 implementation (skeleton of self-test expectations), but must run against the completed module.
- **Across user stories**: Once Phase 2 ships, **US1 + US2 + US4 can proceed in parallel** (different developers, different files). US3 and US5 both depend on US1 finishing, but once US1 is done US3 + US5 can proceed in parallel.
- **Inside US5**: T034–T038 are all `[P]` (each touches a distinct file/line and records a distinct audit row).
- **Inside Phase 8**: T042 and T043 are `[P]` (different doc files).

### Within Each User Story

- Harness module before its consumers (T008 before T010).
- Data-model schema before writers (T026 before T029).
- Data-model schema before template rename (T026–T028 before T031).
- Integration spec after the fill-code change it verifies (T039 after T031–T038).

---

## Parallel Example: Phase 7 (US5) mid-phase

```text
# After T030 (ORM world migrated to STORY_* keys) and T031–T033 (templates + fill sites renamed),
# T034 through T038 each touch a distinct file and can run in parallel:

T034: Generalize chapter_generator.rb:147 fallback
T035: Remove legacy path at chapter_generator.rb:340
T036: Relocate character alias lookup at chapter_generator.rb:747
T037: Remove title-include dead branch at world_config.rb:247
T038: Parameterize writer_agent.rb:123 framing

# Then converge on T039 (non-ORM world spec) and T040 (SC-009 grep verification),
# which depend on all five of the above.
```

---

## Implementation Strategy

### MVP First (US1 + US2 only)

1. Complete Phase 1 (Setup).
2. Complete Phase 2 (Foundational).
3. Complete Phase 3 (US1 — runtime prompt-call gate).
4. Complete Phase 4 (US2 — coverage floor).
5. **STOP and VALIDATE**: At this point the *category* of regression (invisible prompt bugs, missing test coverage) is closed. The default `bundle exec rspec` now carries both P1 gates. This is the MVP — ship this as a standalone PR if desired; US3/US4/US5 can follow.

### Incremental Delivery

1. Setup + Foundational → Foundation ready.
2. **Add US1** → Validate: broken placeholder fails a spec → Deploy/Merge (gate MVP slice).
3. **Add US2** → Validate: coverage reported, low coverage fails → Deploy/Merge.
4. **Add US3** → Validate: each named historical regression has its canary → Deploy/Merge.
5. **Add US4** → Validate: scripted-stdin flow catches a `nil`-return bug → Deploy/Merge.
6. **Add US5** → Validate: non-ORM world produces clean prompts, `audit-log.md` committed → Deploy/Merge.

### Parallel Team Strategy

With multiple developers, after Phase 2 ships:

- **Developer A**: US1 (Phase 3) → US3 (Phase 5)
- **Developer B**: US2 (Phase 4)
- **Developer C**: US4 (Phase 6) → US5 (Phase 7)

US3 and US5 both gate on US1; plan branches accordingly.

### Recommended Scope for a Single PR

Given the user's CLAUDE.md preference for small, focused commits and the project's constitution (Test-First with Mock AI reinforced), this feature is a candidate for **two PRs**:

- **PR 1**: Phases 1 + 2 + 3 + 4 (MVP — the two P1 gates).
- **PR 2**: Phases 5 + 6 + 7 + 8 (the canaries, the interactive-flow spec, the IP audit + migration, docs).

Both PRs leave the suite in a green state and the floor only goes up over time.

---

## Notes

- Every task has an exact file path. No task says "update the relevant file" — if you're not sure which file, the task references a `Grep` invocation or a contract document that enumerates it.
- [P] tasks = different files, no mutual dependency.
- [Story] labels enable future `git log --grep='\[US3\]'` traceability.
- Verification tasks (T013, T016, T017, T018, T033, T040, T044, T045) are not optional — they are SC-001 through SC-010 in executable form.
- Every audit decision in US5 lands a corresponding row in `audit-log.md` (T041 is the consolidation step, but each task in T031–T040 is responsible for appending its own row as it lands).
- Commit after each task or logical group; never leave the default suite broken between commits.
