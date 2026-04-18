# Feature Specification: Comprehensive Test Coverage & Spec Coverage Tooling

**Feature Branch**: `013-spec-coverage-backfill`
**Created**: 2026-04-17
**Status**: Draft
**Input**: User description: "Comprehensive test coverage and spec coverage tooling — add automated coverage measurement (SimpleCov or equivalent) with a target threshold, backfill integration-level specs for the gaps that escaped recent releases (real prompt output for chapter + character templates, CLI end-to-end flow for `produce chapter --prompt`, realistic `world new` interactive flow), add a meta-spec that asserts no 'Unused placeholders' warning is emitted for any shipped prompt template, and wire coverage + the meta-spec into the default `bundle exec rspec` run so regressions like the recent CHAPTER_NUMBER warning and target_chapters field removal cannot escape again."

## Clarifications

### Session 2026-04-17

- Q: Should prompt-template correctness be guarded by a static file-scan meta-spec, or by a runtime assertion inside every LLM call made during the spec suite? → A: **Runtime assertion at the LLM call boundary.** Prompt templates are prepared statements — testing them as files in isolation is fragile and forces a second registry (an opt-out list). Instead, the mock LLM service used in the default spec run fails the enclosing spec if the outgoing prompt contains any unfilled `{PLACEHOLDER}` token or if any warning (e.g. "Unused placeholders", "Missing required placeholder") was emitted while constructing that prompt. No file-scan, no opt-out list, no hand-maintained allowlist. Coverage (US2) is what guarantees every template's fill path is actually exercised by at least one spec.
- Q: For the `{BOOK_*}` placeholders (TITLE / GENRE / SETTING / STYLE) used in shipped templates and world_config keys — rename now, document as historical synonym, or defer? → A: **Rename during this audit.** The placeholders and their backing world_config keys move from `BOOK_*` to `STORY_*`; templates and fill code migrate in the same pass. A one-time back-compat read accepts the old key names on load (emitting a deprecation notice) so existing worlds keep loading, but no new code writes `BOOK_*`. The runtime prompt assertion from the first clarification catches any template that misses the migration.
- Q: Which source paths contribute to the coverage percentage that the threshold checks against? → A: **`eidos/lib/` only.** Binaries (`eidos/exe/`, `eidos/bin/`) are one-line Thor shims — including them either inflates the percentage trivially or pollutes it with unreachable branches. The denominator stays focused on code that can actually regress. SimpleCov config must exclude `eidos/spec/`, generated files, and the `eidos/lib/eidos/version.rb` constant file (single-line, no branches) so the number reflects real behavioral coverage.
- Q: What is the environment toggle that lets maintainers override the coverage threshold for a single run, and how does it behave? → A: **`COVERAGE_THRESHOLD=<int>`** overrides the configured floor for one `bundle exec rspec` invocation. `COVERAGE_THRESHOLD=0` means "skip the check for this run." When the env var is set to a value below the committed floor, the suite prints a prominent audit line to stderr (e.g. `COVERAGE FLOOR OVERRIDDEN: configured=<X>, this run=<Y>`) so the escape is visible in CI logs and code-review output. No silent relaxations.
- Q: Where does the IP-neutrality audit's per-finding decision log live? → A: **A versioned file in the repo at `specs/013-spec-coverage-backfill/audit-log.md`**, structured as a table with one row per finding (`file:line` → original content → decision taken → new location if relocated). In-repo means it survives, is greppable from a working copy, diffable by future audits, and discoverable alongside this feature's other specs. PR descriptions remain the *announcement* channel, but the source of truth is the repo file.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Prompt-call regression gate (Priority: P1)

Every LLM call made during the default spec run goes through an assertion harness that inspects the outgoing prompt string. Any leftover `{PLACEHOLDER}` token, or any warning emitted while constructing that prompt (e.g. "Unused placeholders", "Missing required placeholder"), fails the enclosing spec. The assertion lives inside the mock LLM boundary every spec already goes through — no separate meta-spec, no file-scan, no opt-out registry.

**Why this priority**: Two recent user-facing regressions (the `CHAPTER_NUMBER` warning leaking to the console on first character creation; the single-brace/double-brace chapter-template mismatch that earlier required a `prefill_single_brace_placeholders` workaround) both ship clean to green CI today. Both are *runtime* phenomena — the prompt string at call time is wrong — so a runtime assertion at the exact seam where the call happens is the cheapest, least-fragile gate. Pairing it with coverage (US2) guarantees every template's fill path is actually exercised by at least one spec.

**Independent Test**: Introduce a deliberate unfilled placeholder in any shipped prompt template that is used by the default spec suite (e.g. rename `{CHAPTER_NUMBER}` to `{CHAPTER_NUMBR}`), run the suite, and confirm at least one spec fails with a message that names the offending placeholder and the caller that built the prompt. Revert the change, confirm the suite turns green again.

**Acceptance Scenarios**:

1. **Given** any spec that triggers an LLM call, **When** the prompt passed into the mock LLM service contains an unfilled `{PLACEHOLDER}` token, **Then** that spec fails with a message identifying the offending placeholder and the caller/code path that built the prompt.
2. **Given** any spec that triggers an LLM call, **When** the prompt-construction code emits a warning (e.g. "Unused placeholders", "Missing required placeholder") while building the prompt, **Then** that spec fails with a message naming the category and the placeholder(s) involved.
3. **Given** a template that is filled in stages by downstream code before the LLM call, **When** the LLM call actually happens, **Then** only the final outgoing prompt string is checked — staged filling is not special-cased because by the time the call fires every stage has already run; if a placeholder remains at that point, that is itself the bug.

---

### User Story 2 - Coverage measurement with an enforced floor (Priority: P1)

Every `bundle exec rspec` run reports a line-coverage percentage for the `eidos` library, and the run fails if coverage drops below an agreed minimum threshold. Maintainers can see, in a single summary line, how well the current specs cover the library, and reviewers can point to a concrete number during PR review.

**Why this priority**: The user's direct feedback — "this is a second time of such an error, I think our test suite is not full" — is fundamentally a coverage signal. Without an automated number, the team has no way to see the gap except by watching it fail in production. Coverage is P1 alongside the prompt gate because both address the same underlying problem (invisible regressions).

**Independent Test**: Delete a non-trivial method's body so it becomes unreachable in the specs, run the default spec suite, and confirm the coverage summary either shows the newly uncovered lines in the report output or the run fails because coverage dropped below the floor.

**Acceptance Scenarios**:

1. **Given** the spec suite finishes, **When** the summary is printed, **Then** it includes the overall line-coverage percentage for `eidos/lib/` and a human-readable pointer to the full per-file report.
2. **Given** a change lowers coverage below the configured minimum threshold, **When** the spec suite finishes, **Then** the run exits non-zero with a message that names the threshold, the actual value, and the files most responsible for the drop.
3. **Given** a contributor runs a single-file spec (`bundle exec rspec path/to/one_spec.rb`), **When** the run finishes, **Then** coverage reporting is suppressed or clearly marked partial so nobody mistakes a single-file run for a real coverage measurement.

---

### User Story 3 - Integration specs for gaps that escaped recent releases (Priority: P2)

Three specific user-observable behaviors that shipped broken — the `CHAPTER_NUMBER` warning in the character-creation flow, the missing `--prompt` threading in `produce chapter`, and the stale `target_chapters` field in `world new` / `world status` — each have a dedicated integration-level spec that would have caught them before release. The specs exercise the actual CLI path (not a mocked generator) and assert on observable output (captured stdout/stderr, the built prompt string, generated file contents).

**Why this priority**: These are the specific escapes the user called out. They are P2 (not P1) because the P1 gates from US1 and US2 prevent the *category* of regression; these specs lock in the *specific incidents* so they cannot silently re-emerge even if the meta-gates are relaxed later.

**Independent Test**: Check out the state of the project *before* each recent fix, run only the new integration specs, and confirm each one fails with a clear message pointing at the real regression. Check out the fixed state, confirm they pass.

**Acceptance Scenarios**:

1. **Given** the `produce chapter` flow creates a new character, **When** the integration spec captures the console output, **Then** the spec asserts there is no "Unused placeholders" warning and no bare `{CHAPTER_NUMBER}`-style token in any file written to disk.
2. **Given** the `produce chapter --prompt "keep it under 3 sentences"` command, **When** the integration spec intercepts the string actually sent to the language model, **Then** it contains the literal user-supplied guidance verbatim.
3. **Given** a freshly initialised world, **When** `world status` is rendered, **Then** the spec asserts the rendered text contains no stale `target_chapters` artifact (no "Progress: 0/Not set chapters", no nil-ish placeholder) and matches the agreed format (e.g. "Progress: N chapter(s) written").
4. **Given** the interactive `world new` flow runs with the default answers, **When** the spec captures every prompt presented to the user, **Then** no prompt asks for "Target number of chapters", and the resulting `world_config.yml` + `world_state.yml` do not carry a `target_chapters` key.

---

### User Story 4 - Realistic interactive `world new` coverage (Priority: P3)

The existing `world new` spec stubs `ask` and `yes?` so aggressively that the spec passes even when the real interactive flow crashes (as happened when an `ask` returned `nil` and `build_world_metadata` called `.strip` on it). A more realistic spec drives the CLI with a scripted stdin stream and asserts the full flow completes without raising, under both the "all defaults" and "all custom answers" paths.

**Why this priority**: This is a quality-of-testing improvement rather than a named regression. It's P3 because US1 + US2 + US3 already close the visible gaps; this is about making the safety net genuinely load-bearing for future interactive-flow work.

**Independent Test**: Introduce a nil-returning code path in an interactive prompt handler, run the new spec, and confirm it fails — whereas the existing heavily-stubbed spec still passes. Revert, confirm both pass.

**Acceptance Scenarios**:

1. **Given** the interactive `world new` command runs with a scripted input stream, **When** the user accepts every default by pressing Enter, **Then** the command exits successfully and writes a valid world directory.
2. **Given** the same command runs with a scripted input stream that provides a custom value for every prompt, **When** it finishes, **Then** the generated `world_config.yml` reflects every custom value the user supplied.
3. **Given** the interactive flow is run in the spec, **When** a prompt handler returns a `nil`-like value, **Then** the spec surfaces a clear failure rather than silently passing, because the spec does not globally stub the prompt methods.

---

### User Story 5 - IP-neutrality audit of shipped prompts and engine defaults (Priority: P2)

Eidos is packaged as a reusable engine that powers *One Review Man* but is supposed to work for any storyworld. Today, a fresh non-ORM world that runs `eidos produce chapter` would still inherit ORM-specific vocabulary and fallbacks from the shipped prompts and engine defaults (e.g. "programming comedy story" in the chapter-template fallback, a hardcoded `'One Review Man'` character name in the chapter generator, a legacy `books/one-review-man` path, a default "programming comedy book" framing in the writer agent, `title.include?('One Review Man')` branches in world-config detection). This user story audits every shipped prompt template and engine default for IP-specific leaks, generalizes the ones that belong in the engine, and relocates anything genuinely ORM-specific into the `worlds/one-review-man/` content tree where it can be overridden per world.

**Why this priority**: This is a correctness issue for anyone but the first-party ORM author. It is P2 (not P1) because it does not block the ORM world itself — ORM continues to work either way — but it does block the engine's claim to be reusable, and it compounds over time (every new template written with ORM-flavored vocabulary becomes harder to extract later). Closing it now, alongside the P1 gates, prevents future drift.

**Independent Test**: Create a non-ORM world with a deliberately different genre (e.g. a cooking-mystery world), run the full content flow (`world new` → `produce chapter`), inspect every prompt actually sent to the language model and every on-disk artifact produced, and confirm *zero* references to "One Review Man", "programming comedy", "Jax/Kenji", "book" (as the container metaphor), or any other ORM-specific vocabulary slip through — every genre/setting/style word should trace back to the user's own world configuration.

**Acceptance Scenarios**:

1. **Given** the shipped prompt templates and their reference documentation, **When** the audit reads each template end-to-end, **Then** every template either (a) speaks generically about "the story / the world / the chapter" using world-provided placeholders only, or (b) is explicitly annotated as ORM-specific and relocated outside the engine's default template directory.
2. **Given** any engine-level fallback string (e.g. the chapter-generator fallback "Write Chapter N of a programming comedy story"), **When** the audit examines it, **Then** it either becomes genre-agnostic or is parameterized through `world_config.yml` so the user's genre/setting/style drives the wording.
3. **Given** any engine branch keyed on a specific character name or world title (e.g. `title.include?('One Review Man')`, `find_character_real_name(chars, 'One Review Man')`), **When** the audit examines it, **Then** the branch is either removed, generalized to read the name from world configuration, or moved into an ORM-world-local override file — never left in the engine.
4. **Given** the existing ORM world, **When** the audit's changes are applied, **Then** running the ORM chapter-generation flow continues to produce output of equivalent quality to the pre-audit baseline (i.e. the audit does not regress the ORM experience in the name of generality).
5. **Given** a new, non-ORM world is scaffolded after the audit ships, **When** a chapter is produced, **Then** no prompt string sent to the LLM contains the literal text "One Review Man", "programming", or any other ORM-brand vocabulary unless the user's own world description introduced it.

---

### Edge Cases

- Coverage floor drift: a legitimate refactor that deletes unreachable code will *raise* coverage. The rule must not penalize this — the floor is a minimum, not a moving target, and it is allowed to go up silently. Deliberate downward changes to the floor require a maintainer action (edit a single configured value) and must be visible in diffs.
- Single-file spec runs: a contributor running one spec file must not receive a misleading "coverage dropped below threshold" failure. Coverage enforcement applies to the full suite only.
- New prompt templates added by future features: the runtime LLM-call assertion applies automatically as soon as any spec exercises the new template's fill path. If no spec exercises it, the coverage floor is what makes the gap visible — the gate is never silently skipped, but it is the responsibility of coverage (US2), not a second registry.
- Interactive-flow specs must not hang indefinitely if stdin is not scripted correctly: every interactive spec must time out with a clear failure message rather than block the whole run.
- IP-neutrality audit vs. engine vocabulary drift: the engine today uses the word "book" in several placeholder names (`{BOOK_TITLE}`, `{BOOK_GENRE}`, `{BOOK_SETTING}`, `{BOOK_STYLE}`) and in `world_config.yml` keys, even though the project's own worldview treats the output as a storyworld, not a book. **Resolution (Clarifications / Session 2026-04-17):** rename placeholders and config keys to `STORY_*` during this audit; ship a one-time back-compat read that accepts the old `BOOK_*` keys on load and emits a deprecation notice, so existing worlds continue to load without editing their config.
- Documentation files (`LLM_README.md`, `CONFIG_STRUCTURE.md`, `README.md`) legitimately reference ORM as an example. The audit applies to *code and shipped prompts*, not to documentation examples; docs may reference ORM as an illustrative world as long as nothing in the executable path depends on that reference.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The default spec run MUST report overall line coverage for the `eidos/lib/` code (only — binaries under `eidos/exe/` and `eidos/bin/` are excluded from the coverage denominator, as are `eidos/spec/`, generated files, and the single-line `eidos/lib/eidos/version.rb` constant file) and expose a path to a full per-file report readable by a human after the run.
- **FR-002**: The default spec run MUST fail when overall line coverage drops below a configured minimum threshold.
- **FR-003**: The minimum coverage threshold MUST live in a single configuration location, be obvious in diffs when changed, and be overridable per-run via the `COVERAGE_THRESHOLD=<int>` environment variable (where `0` disables the check for that run). Whenever `COVERAGE_THRESHOLD` is set below the committed floor, the suite MUST print an audit line to stderr identifying the configured floor, the effective floor for this run, and the fact that an override is active; this makes the override visible in CI logs and PR output rather than silent.
- **FR-004**: Coverage enforcement MUST apply to full-suite runs and MUST NOT fail single-file or focused runs for coverage reasons.
- **FR-005**: The default spec run MUST intercept every LLM call made by the system under test and fail the enclosing spec if (a) the outgoing prompt string contains any unfilled `{PLACEHOLDER}` token, or (b) any warning was emitted by the prompt-construction path (e.g. "Unused placeholders", "Missing required placeholder") while building that prompt.
- **FR-006**: The failure message from FR-005 MUST identify the offending placeholder(s), the category of failure (unfilled token vs. emitted warning), and enough context (the spec file and/or the code path that built the prompt) to locate the bug without opening additional tooling.
- **FR-009**: A dedicated integration spec MUST exercise the full `produce chapter` path (not the mocked generator) with a world containing an unreferenced new character and assert no "Unused placeholders" warning is emitted and no unfilled placeholder token appears in any file written to disk.
- **FR-010**: A dedicated integration spec MUST exercise `produce chapter --prompt "<text>"` end-to-end, capture the prompt string actually sent to the language model, and assert the user-supplied text is present verbatim in that string.
- **FR-011**: A dedicated integration spec MUST run `world new` followed by `world status` against a fresh directory and assert the rendered status contains no stale `target_chapters` artifact and that the generated world files carry no `target_chapters` key.
- **FR-012**: A dedicated integration spec MUST drive the interactive `world new` flow with a scripted stdin stream (not by stubbing `ask`/`yes?`) and assert both the all-defaults path and an all-custom-answers path complete successfully and produce the expected world files.
- **FR-013**: The default spec run MUST remain runnable under `MOCK_AI=true` with no live network access, and the new integration specs MUST use the existing mock-LLM mechanism rather than calling real providers.
- **FR-014**: The default spec run SHOULD finish in under a reasonable time bound for local iteration (a baseline should be captured, and new specs should not more than double the current wall-clock runtime of the full suite).
- **FR-015**: Contributor-facing documentation (the project's AI-agent guide and/or README) MUST explain how to read the coverage report, how to adjust the threshold, and how the runtime prompt-call assertion works (what a failure from it looks like, how to diagnose it), so maintainers do not re-learn these controls from scratch each time.
- **FR-016**: Every shipped prompt template under the engine's default template directory MUST be reviewed for IP-specific vocabulary; any language that is specific to *One Review Man* (including but not limited to the title itself, named characters, "programming comedy", and the "book" container metaphor where it implies the ORM framing) MUST either be generalized, driven by world-config placeholders, or relocated outside the engine's default template directory.
- **FR-017**: Every engine-level code path that is keyed on a hardcoded string tied to *One Review Man* (the title, the character `'One Review Man'`, legacy path fragments like `books/one-review-man/`, etc.) MUST be generalized, removed, or moved into an ORM-world-local override mechanism — the engine's default behavior MUST NOT special-case ORM.
- **FR-018**: A spec MUST verify that, when `eidos produce chapter` runs against a non-ORM world whose configuration contains none of the ORM vocabulary, the prompt string actually sent to the language model also contains none of the ORM vocabulary (beyond strings the user themselves introduced via their world description).
- **FR-019**: The audit's output MUST be recorded as a versioned file at `specs/013-spec-coverage-backfill/audit-log.md`, structured as a table with one row per finding: (a) the file and line of the original leak, (b) a short quote or description of the original content, (c) the decision taken (generalize / parameterize / relocate / document as intentional), and (d) the resulting location of any ORM-specific content that was moved. The file MUST be committed alongside the audit's code changes so future maintainers can trace *where* ORM content lives after the audit.
- **FR-020**: The shipped templates, the prompt-fill code paths, and the `world_config.yml` keys MUST be migrated from the `BOOK_*` naming (`BOOK_TITLE`, `BOOK_GENRE`, `BOOK_SETTING`, `BOOK_STYLE`) to `STORY_*` (`STORY_TITLE`, `STORY_GENRE`, `STORY_SETTING`, `STORY_STYLE`). After the migration, no shipped template or engine code path may produce, consume, or advertise a `BOOK_*` placeholder for these four fields.
- **FR-021**: World-config loading MUST accept the legacy `BOOK_*` keys for one release as a back-compat read, mapping them transparently onto the new `STORY_*` keys and emitting a single deprecation notice per key so existing worlds continue to load without user-visible breakage. New worlds created after this feature MUST only be written with `STORY_*` keys.

### Key Entities

- **Coverage Report**: The per-run artifact that records which source lines executed and which did not. Consumed by humans (debugging a drop) and by the threshold check (pass/fail decision).
- **Coverage Threshold**: A single numeric value representing the minimum acceptable line-coverage percentage. Versioned in the repository; changes to it are reviewable.
- **LLM Call Assertion Harness**: The in-test wrapper around the mock LLM service. Every outgoing prompt string is inspected for unfilled `{PLACEHOLDER}` tokens; warnings emitted during the prompt's construction are captured. Either condition fails the enclosing spec. This harness replaces the idea of a separate template registry or opt-out list.
- **Regression Spec**: A single-purpose integration spec tied to a previously-shipped bug, intended to stay in the suite indefinitely as a canary for that specific failure mode.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A maintainer who introduces a broken placeholder token into any shipped prompt template sees the default spec run fail within one local test cycle: at least one spec that exercises the broken template's fill path fails with an error message naming the offending placeholder and the spec/code path that built the prompt. (Tested by deliberately breaking a template and re-running the suite.)
- **SC-002**: The default spec run prints a single-line coverage percentage summary and exits non-zero when that percentage falls below the configured threshold. (Tested by artificially dropping coverage and observing the exit status.)
- **SC-003**: Each of the three named historical regressions (the `CHAPTER_NUMBER` warning; the missing `--prompt` threading; the `target_chapters` residue in `world status`) has a dedicated spec in the suite that, when run against a pre-fix version of the code, fails with a human-readable message referencing the original symptom.
- **SC-004**: A new prompt template added to the shipped directory is automatically covered by the runtime LLM-call assertion as soon as any spec exercises its fill path — adding the template and running the suite either passes (if the fill is sound) or fails at the LLM call (if it is not). If no spec exercises the new template, the coverage floor (SC-002) is what makes the gap visible; the gate is never silently skipped.
- **SC-005**: A contributor can determine, from reading the project's AI-agent guide alone, (a) how to interpret the coverage output, (b) how to change the threshold, and (c) how the runtime prompt-call assertion works and what a failure from it looks like, without needing to read source code. (Verified by a documentation review against the three tasks.)
- **SC-006**: The interactive `world new` spec catches a reintroduction of the `nil`-return bug (`undefined method 'strip' for nil`) the first time the suite is run, with a failure message that identifies the interactive flow as the failing code path.
- **SC-007**: The full spec suite's wall-clock runtime, measured locally under `MOCK_AI=true`, does not increase by more than 2× after this feature ships, relative to the baseline measured on the pre-feature commit.
- **SC-008**: After the audit ships, scaffolding a fresh non-ORM world and producing one chapter results in a built prompt string (captured from the LLM service) that contains zero literal occurrences of "One Review Man" (in any language), "programming comedy", or any character name from the ORM world — unless such a string appears in the user's own world description. (Verified by an automated spec driving a non-ORM world.)
- **SC-009**: After the audit ships, a grep of the engine source tree (`eidos/lib/`) and the shipped prompt templates for the regex `one.?review.?man` (case-insensitive), `программное?\s?ревью`/`Ванревьюмэн`, and `programming comedy` returns zero matches outside of comments/strings explicitly annotated as documentation or historical examples.
- **SC-010**: After the migration ships, a grep of shipped prompt templates and engine fill code for `BOOK_TITLE`, `BOOK_GENRE`, `BOOK_SETTING`, or `BOOK_STYLE` returns zero matches; the only occurrences remaining in `eidos/lib/` are inside the documented back-compat loader path and its dedicated spec. The ORM world continues to load unchanged thanks to the back-compat read (verified by running the ORM `world status` against an unmodified `world_config.yml`).

## Assumptions

- The existing `MOCK_AI=true` pathway and the `spec/support/mock_responses.yml` fixtures are the right mechanism for the new integration specs; no live LLM calls are introduced.
- A line-coverage tool from the standard Ruby ecosystem (SimpleCov or equivalent) is acceptable; the specific choice is an implementation detail and is not gated by this spec.
- The initial coverage threshold will be set to the *current* measured coverage rounded down (so adopting the feature does not immediately block the suite); raising it over time is an ongoing project exercise outside this feature's scope.
- All prompt construction in the engine flows through a single prompt-building utility whose output can be intercepted in tests (either by hooking the utility itself or by inspecting the string handed to the mock LLM service). If a future code path bypasses that utility to call an LLM directly with a hand-built string, the runtime assertion must be extended to cover it.
- The interactive-flow specs assume the CLI can be driven with a scripted stdin stream. This is true for the current Thor-based CLI; if a future CLI rewrite removes this capability, the spec strategy must be revisited.
- The project's constitution permits expanding the default spec command's responsibilities (coverage + runtime prompt assertion), rather than keeping them in a separate opt-in command. If a strong preference for an opt-in model exists, the plan phase can reopen this.
- The new specs run entirely offline. No integration spec requires the project to be published or any external service to be reachable.
