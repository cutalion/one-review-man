# Feature Specification: Scaffold Hardening

**Feature Branch**: `015-scaffold-hardening`
**Created**: 2026-04-18
**Status**: Draft
**Input**: User description: "Scaffold hardening — fix six Tier-1 defects 014 shipped (canon-delta silent drops, apply_delta non-persistence, world new --quick stdin corruption, genre/style/setting silent fallback, orphan scaffold dirs, chapter-centric world status), add a user-scale integration test harness, and ban the silent-fallback code patterns that let them through review."

**Background**: See `specs/014-storyworld-pivot/postmortem.md` for the root-cause analysis that produced this feature. The six defects were discovered by `/user-qa` auditing a freshly generated `~/worlds/job-hunt` world after 014 was declared done on the strength of a green RSpec suite. Every defect passed unit tests and still broke the product from the user's perspective.

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Canon-delta drops are visible, not silent (Priority: P1)

When the language model emits a canon-delta entry that does not match the expected mapping shape (for example, a bare string where a named-object record is expected), the system currently skips the entry with a stderr warning and records no indication of the drop. A user inspecting `eidos canon review` sees "0 findings." A user inspecting `data/canon_deltas/*.yml` sees an empty `new_characters: []` field with `parse_error: null` — indistinguishable from a delta the model intentionally left empty.

A user creating pieces needs drops to be first-class events: recorded on the delta, surfaced in `canon review`, and countable.

**Why this priority**: This defect masks data loss. In the 014 demo run, three of four generated pieces lost all their extracted entities this way with zero user-visible signal. Until this is fixed, no QA check downstream can trust that an empty delta means "model produced nothing" vs. "parser dropped everything."

**Independent Test**: Feed the system a canon-delta whose LLM output contains bare-string entries. After parsing, `parse_error` on the delta record is non-null and names the dropped entries. `eidos canon review` reports at least one finding for that delta. Remains testable even if US2–US6 are not yet built.

**Acceptance Scenarios**:

1. **Given** a delta whose LLM output contains `new_characters: ["Arthur is a poet"]` (bare string), **When** the producer writes the delta, **Then** the delta's `parse_error` field contains a non-null record naming the dropped entry and the category (`new_characters`).
2. **Given** a world with at least one such delta on disk, **When** the user runs `eidos canon review`, **Then** the output includes a finding per dropped entry with the piece id, delta id, category, and dropped value.
3. **Given** an LLM output that is fully well-formed, **When** the producer writes the delta, **Then** `parse_error` remains null and `canon review` reports no parse findings for that delta.

---

### User Story 2 — Canon-delta entities actually appear in the bible (Priority: P1)

When a canon-delta is applied (its `applied_at` timestamp is set and `parse_error` is null), the entities it declared must materialize as files on disk under `data/story_bible/`. Today this does not happen: the 014 demo produced a delta declaring `Arthur` and `Arthur's Apartment`, stamped `applied_at` on it, and left `data/story_bible/characters/` and `data/story_bible/locations/` empty.

A user producing pieces needs "delta applied" to mean "bible updated" — not a ceremonial flag with no filesystem effect.

**Why this priority**: This is the feature promise of 014 ("every piece feeds canon deltas back into the bible so the world stays consistent"). Without it, the Storyworld model is silently broken even when the LLM cooperates and the parser succeeds.

**Independent Test**: Apply a delta with one known character and one known location against an empty bible. After apply, `data/story_bible/characters/<id>.yml` and `data/story_bible/locations/<id>.yml` exist with contents matching the delta's declarations. Verifiable without US1 being fixed — the delta is hand-written, so parser drops are not in play.

**Acceptance Scenarios**:

1. **Given** a freshly scaffolded world and a hand-crafted delta declaring one new character named "Arthur" with description "A programmer", **When** the system applies that delta, **Then** `data/story_bible/characters/arthur.yml` exists on disk and its description field matches "A programmer".
2. **Given** the same scenario plus one new location, **When** the system applies the delta, **Then** a corresponding location file exists under `data/story_bible/locations/`.
3. **Given** an applied delta with entity updates (not new entities), **When** the user reads the bible entry for the named entity, **Then** the update is reflected in the on-disk record.
4. **Given** an applied delta, **When** the user runs `eidos character list` or the equivalent SDK call, **Then** the declared entities appear in the listing.

---

### User Story 3 — Quick-setup accepts the full premise without corrupting it (Priority: P1)

When a user scaffolds a new world non-interactively (via pipe, script, or automation), the premise they provide must be preserved verbatim in the resulting `data/world_config.yml`, regardless of whether the premise contains newlines. Today, the quick-setup path treats every `\n` as the end of one answer and the start of the next, so a multi-line premise bleeds into the `languages` field and `default_language`.

A user scripting world creation (for CI, for demos, for testing) needs a setup path that survives realistic multi-line prose input.

**Why this priority**: This defect blocks every downstream smoke test and QA run. Without it, no automated test that creates a fresh world produces a valid `world_config.yml`, which means US1 and US2 cannot be validated end-to-end against a trustworthy substrate. It is the foundation for every integration test in the new user-scale harness.

**Independent Test**: Invoke the non-interactive world-setup path with a six-line premise. The resulting `world_config.yml` contains that full six-line premise in the subtitle/description fields; `languages` contains only language codes; `default_language` is a valid language code.

**Acceptance Scenarios**:

1. **Given** a six-line premise passed to the non-interactive setup, **When** setup completes, **Then** `world_config.yml` `subtitle` and `description` contain the full six-line premise verbatim.
2. **Given** the same invocation, **When** setup completes, **Then** `world_config.yml` `languages` is a list of language codes (e.g., `["en"]`), and `default_language` is a valid language code (e.g., `"en"`), with no prose fragments anywhere.
3. **Given** a user running setup interactively at a real TTY, **When** they answer prompts as before, **Then** the flow continues to work as it does today (no regression for interactive users).
4. **Given** a user invoking setup non-interactively with missing required values, **When** setup runs, **Then** it exits with an error naming the missing values — it does not silently fall back to empty or guessed values.

---

### User Story 4 — World metadata either reflects the premise or admits it doesn't (Priority: P2)

When the system infers world metadata (genre, style, setting, thematic focus) from a premise, it must either produce values that accurately reflect the premise OR record explicitly that inference failed and leave the fields in a state the user can see is unfilled. Today it emits real-looking defaults (`fiction`, `narrative`, `contemporary setting`, `adventure`) regardless of what the premise said. A programmer-comedy premise produces the same metadata as a fantasy-epic premise.

A user scaffolding a world needs metadata that is either correct or visibly absent — never a plausible-looking lie.

**Why this priority**: This defect silently degrades every downstream prompt that uses world metadata as context. It is lower priority than US1–US3 because its damage is cosmetic-to-prompt-drift rather than data-loss or tooling-failure. But it's the clearest example of the "silent fallback that looks like real output" anti-pattern the feature is meant to kill.

**Independent Test**: Scaffold a world with a premise that unambiguously implies comedy. The resulting `world_config.yml` either has a genre field that communicates comedy/satire OR has a genre field with a sentinel value (e.g., `unspecified`) plus a visible indication in `world status` that the field needs user attention.

**Acceptance Scenarios**:

1. **Given** a premise that unambiguously implies a non-default genre (e.g., "deadpan programmer comedy about job hunting"), **When** setup completes, **Then** `world_config.yml` genre/style/setting/theme fields are NOT all four of `fiction` / `narrative` / `contemporary setting` / `adventure`.
2. **Given** a premise that is genuinely generic or unspecifiable, **When** setup completes, **Then** the metadata fields contain a visible sentinel that marks them as unspecified AND `eidos world status` output calls this out as an item needing user attention — not hidden behind silence.
3. **Given** a user explicitly provides genre/style/setting/theme via flags, **When** setup completes, **Then** those values are used verbatim without any inference layer overriding them.

---

### User Story 5 — New worlds have no orphan scaffold directories (Priority: P2)

When a user creates a new world, the filesystem they get should reflect the forms the world will actually use. Today every new world is scaffolded with empty `content/chapters/` and `content/characters/` directories regardless of intent, inherited from pre-014 "chapter is the organizing unit" assumptions.

A user exploring a newly created world with `ls content/` needs to see directories that mean something, not book-era vestiges.

**Why this priority**: Cosmetic but high-visibility — it's the first thing a new user sees after `world new`. Doesn't block data integrity, but signals that the project still thinks in chapter terms after 014.

**Independent Test**: Create a new world. Walk the `content/` directory tree. No directory exists that contains zero files.

**Acceptance Scenarios**:

1. **Given** a user runs world creation on a fresh filesystem, **When** it completes, **Then** `content/` exists but contains no empty subdirectories.
2. **Given** the same newly created world, **When** the user runs `eidos produce vignette --prompt "..."`, **Then** `content/pieces/vignette/` is created on demand and contains the produced piece.
3. **Given** an existing world that was scaffolded under the old behavior (e.g., `worlds/one-review-man`), **When** the user runs any command, **Then** the existing directories keep working — no migration required for existing content.

---

### User Story 6 — World status speaks in pieces, not chapters (Priority: P3)

When a user runs `eidos world status`, the output must describe the world in terms of the content forms that actually exist, not in terms of chapters as a universal unit. Today it reports "Progress: 0 chapters written" and suggests "Run: produce chapter" even in a world whose intended forms have nothing to do with chapters.

A user who has generated vignettes, haiku, or comic scripts needs a status view that reflects what they've actually made.

**Why this priority**: Cosmetic and informational — it does not corrupt data or block any workflow, but it's chapter-era language leaking into a piece-first world.

**Independent Test**: Produce two vignettes and one haiku in a world. Run the status command. Output includes counts for each form produced AND does NOT recommend "produce chapter" as the next step.

**Acceptance Scenarios**:

1. **Given** a world with two vignette pieces and one haiku piece on disk, **When** the user runs the status command, **Then** the output lists piece counts broken down by form (at minimum, total-piece-count and one line per form that has at least one piece).
2. **Given** a world with zero pieces, **When** the user runs the status command, **Then** the output reports an empty world and suggests a generic "produce" action — not specifically "produce chapter."
3. **Given** a world that has actually produced chapters, **When** the user runs the status command, **Then** chapter counts still appear (chapters remain one valid form among many).

---

### Edge Cases

- **Non-mapping canon-delta entries in mixed form** (US1): LLM emits `new_characters: [{"name": "Arthur", ...}, "Marcus is a colleague"]`. Parser keeps Arthur, records the Marcus string as a parse error, both facts are visible to the user.
- **Delta application against a bible that already contains the entity** (US2): delta says "new character Arthur" but Arthur already exists. Either the application promotes to an entity-update (preferred) or the application declines with a canon finding — must not silently overwrite and must not silently ignore.
- **Interactive TTY setup after the flag-based non-interactive path is added** (US3): user at a real terminal running the command with no flags falls through to the existing interactive prompt flow.
- **Premise that legitimately has no clear genre** (US4): e.g., "a test world for CI." System must still scaffold, but the unfilled metadata state must be visible — not hidden behind comfortable defaults.
- **Backwards compatibility with existing worlds** (US5, US6): `worlds/one-review-man` and any other existing worlds must continue to work with all their current directories. The directory-scaffolding change is for new worlds only.
- **LLM response truncation** (beyond US1's bare-string case): output ends mid-JSON, output has a missing required key on a record. Both should surface as `parse_error` + canon findings, not silent drops.

## Requirements *(mandatory)*

### Functional Requirements

**Canon-delta parsing and application (US1, US2)**

- **FR-001**: When a canon-delta section is parsed, every entry that does not satisfy the expected record shape MUST be recorded on the delta's `parse_error` field with the category, the raw dropped value, and a brief reason.
- **FR-002**: `eidos canon review` MUST surface every parse-error record as a distinct finding, with the piece id, delta id, category, and dropped value visible in the user-facing output.
- **FR-003**: `parse_error` MUST remain null only when zero entries were dropped across all categories of the delta.
- **FR-004**: When a canon-delta is applied, every entity it declares (new characters, locations, relationships, facts, events, entity updates) MUST be persisted to disk under `data/story_bible/` in the format other parts of the system already read.
- **FR-005**: After a delta is applied, the declared entities MUST be retrievable by the same listing/lookup commands the user uses for entities created by any other path.
- **FR-006**: If delta application encounters a conflict (e.g., the declared new entity already exists), the application MUST surface a canon finding rather than silently overwriting or silently skipping.

**Non-interactive world setup (US3)**

- **FR-007**: The system MUST provide a non-interactive world-creation path that accepts all setup values (title, author, premise/description, languages, default language) without reading from standard input line-by-line.
- **FR-008**: The non-interactive path MUST preserve multi-line values verbatim — no value may be split, truncated, or reinterpreted as a subsequent field.
- **FR-009**: The interactive (TTY) setup flow MUST continue to work for users running the command at a real terminal.
- **FR-010**: When the non-interactive path is invoked without a required value, the system MUST exit with a clear error naming the missing value — it MUST NOT fall back to guessed or empty values.

**World metadata (US4)**

- **FR-011**: When the system infers world metadata (genre, style, setting, theme) from a premise, the result MUST either accurately reflect the premise's semantic content OR be an explicit sentinel value (e.g., `unspecified`) — never a real-looking default value passed off as inferred.
- **FR-012**: When any metadata field is set to the unspecified sentinel, `eidos world status` output MUST surface this as an action item for the user.
- **FR-013**: Users MUST be able to provide genre/style/setting/theme values explicitly via the non-interactive setup path, and those explicit values MUST be used verbatim with no inference overlay.

**Scaffolding (US5)**

- **FR-014**: A newly created world MUST NOT contain empty directories under `content/`.
- **FR-015**: Form-specific directories under `content/pieces/<form>/` MUST be created lazily when the first piece of that form is produced.
- **FR-016**: Worlds created under the previous scaffolding behavior MUST continue to work unchanged; no migration is required.

**Status (US6)**

- **FR-017**: The world-status output MUST describe content progress in terms of pieces broken down by form — not in terms of chapters as a universal unit.
- **FR-018**: When a world has zero pieces, the status output MUST suggest a generic production action — not specifically "produce chapter" — unless the world's declared intent is specifically a chapter-based work.

**User-scale integration test harness (cross-cutting)**

- **FR-019**: The project MUST include a suite of integration tests that invoke the installed command-line surface end-to-end (not by calling classes directly) with realistic multi-line input, and assert on the resulting on-disk artifacts.
- **FR-020**: The integration suite MUST be separately runnable from the fast unit-test suite, so that local iteration is not blocked by its cost.
- **FR-021**: At minimum one integration scenario MUST cover the full demo flow (scaffold a world from a multi-line premise, produce pieces of at least two different forms, inspect the resulting bible, run canon review) and assert disk artifacts match what was requested.

**Silent-fallback ban (cross-cutting)**

- **FR-022**: The project's development guidelines MUST document that silent fallback patterns are not permitted in new code: any method that can return a sentinel (a plausible-looking default in the absence of real data, a `nil` return where the caller cannot distinguish "no data" from "error", an early exit that silently no-ops) must either raise, return a result object that communicates success/failure to the caller, or emit a message in a channel the user actually reads.
- **FR-023**: Stderr warnings MUST NOT be the sole user-visible signal for any data-loss or degradation event — such events must also surface through `eidos canon review`, `eidos world status`, or an equivalent user-facing command.

**LLM response fuzz coverage (cross-cutting)**

- **FR-024**: For every canon-delta parsing routine, the test suite MUST include at least one case with an intentionally malformed input (bare strings where mappings are expected, missing required keys, truncated structure) asserting that the failure surfaces as a `parse_error` record AND a canon finding, not as silence.

### Key Entities

- **Canon-delta parse-error record**: A field on a canon-delta that captures information about entries the parser could not interpret. Attributes: category (which delta section the drop came from), raw dropped value, reason. Not present (null) when parsing succeeded fully.
- **Canon finding**: A record surfaced by `eidos canon review` that names something the user should look at. New kind introduced by this feature: parse-error findings, distinguishable from the existing application-conflict findings.
- **Bible entity**: An on-disk record under `data/story_bible/` (character, location, fact, relationship, etc.). Produced by entity creation via any path — CLI, SDK, or canon-delta application. Must be addressable and queryable identically regardless of origin.
- **World metadata**: Genre, style, setting, theme fields on the world config. New state introduced: an explicit sentinel value that marks a field as unspecified and visible as such to the user.
- **Integration scenario**: A test file that invokes the installed command-line surface end-to-end with realistic input and asserts against on-disk artifacts, distinguishable from unit tests that call classes directly.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Re-running the project's demo scaffolding flow (`scripts/demo_job_hunt.sh`) against a freshly wiped world produces a `data/world_config.yml` whose `subtitle` and `description` fields contain the full multi-line premise verbatim, whose `languages` field contains only language codes, and whose `default_language` is a valid language code.
- **SC-002**: The same demo run produces non-default values for `genre`, `style`, `setting`, and `theme` that a reader can recognize as reflecting the premise (OR produces an explicit unspecified sentinel that `eidos world status` surfaces as an action item).
- **SC-003**: After the same demo run, the story bible contains at least one entity per unique character/location named in the generated pieces' canon deltas — verifiable by listing files under `data/story_bible/characters/` and `data/story_bible/locations/`.
- **SC-004**: Feeding a canon-delta YAML that contains bare-string entries in any of its record sections produces a `parse_error` record on the delta AND a finding visible in the text output of `eidos canon review`.
- **SC-005**: A freshly created world contains no empty directories under `content/`; all form-specific directories appear only after their first piece is produced.
- **SC-006**: `eidos world status` output for a world with pieces shows piece counts broken down by form AND does not recommend "produce chapter" as the next step unless the world's declared intent is specifically a chapter-based work.
- **SC-007**: The user-QA audit (`/user-qa` command) run against a freshly generated world (live LLM mode) returns a PASS verdict across all three tiers — structural, intent consistency, UX smoke — with zero Tier-1 failures.
- **SC-008**: The user-scale integration suite, run end-to-end, covers at least the scaffold → produce → review cycle for at least two distinct non-chapter forms, and can be invoked by a single documented command from the repository root.
- **SC-009**: The contributor guidelines explicitly document the silent-fallback ban in a location that future contributors will discover before writing code (primary agent-instructions file).

## Assumptions

- Existing worlds under `worlds/` are authoritative and must not be migrated, rewritten, or silently restructured by this work. All changes apply to new-world behavior only.
- The canon-delta YAML schema remains unchanged at the document level — `parse_error` already exists as a nullable field, so recording drops on it is a population change, not a schema change.
- The world-metadata sentinel for "unspecified" is a new value (e.g., the string `unspecified` or equivalent) that templates and adapters must treat as "render nothing" or "show a blank." Implementation may choose the exact sentinel.
- "Live LLM" in the success criteria means the project's normal production LLM provider configured via existing settings — this feature does not introduce new LLM-provider infrastructure.
- The user-scale integration suite runs under mock-LLM mode for day-to-day CI cost, with a documented mode to run against a live LLM for the SC-007 validation. VCR-style recorded-fixture infrastructure is NOT in scope (tracked separately).
- Backwards compatibility for CLI help text, existing command names, and existing flags is preserved — this work adds flags and behaviors, it does not remove or rename.
- The "silent fallback" convention is enforced socially (documentation + code review + user-QA gate), not by a new linter or CI rule, in this feature. A linter is welcome future work but not blocking.

## Dependencies

- `specs/014-storyworld-pivot/postmortem.md` — authoritative source for defect inventory and root-cause analysis.
- The `.claude/agents/user-qa.md` and `.claude/commands/user-qa.md` QA gate — invoked by SC-007.
- The `CLAUDE.md` Definition of Done section — enforcement mechanism for the silent-fallback ban.
- Existing Eidos command-line surface — this feature modifies behavior of existing commands but does not introduce new top-level commands.
- Existing mock-AI test infrastructure — this feature extends it with a user-scale integration suite but does not redesign it.

## Out of Scope

- VCR-style recorded LLM fixtures for integration tests (tracked in project memory `project_vcr_llm_fixtures.md` and postmortem "Future work").
- Automated linting for the silent-fallback ban (social enforcement only in this feature).
- Publishing / theming / Jekyll changes.
- Arc redesign, chapter-content-generator rewrite, prompt-template overhaul.
- Multi-user / concurrent-edit handling.
- Migrating or rewriting `worlds/one-review-man` or any other existing world.
