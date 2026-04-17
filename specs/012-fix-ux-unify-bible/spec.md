# Feature Specification: Fix UX Bugs and Unify Story Bible Across SDK and Generator

**Feature Branch**: `012-fix-ux-unify-bible`
**Created**: 2026-04-17
**Status**: Draft
**Input**: User description: "fix all bugs and improve eidos architecture"

## Clarifications

### Session 2026-04-17

- Q: When unifying the lore store, which layout wins? → A: Adopt `data/story_bible/` as canonical; legacy `data/world.yml` + `data/story_facts.yml` migrate into it once, with originals kept as `.backup` for one release cycle.
- Q: How does `eidos world new` trigger premise-to-bible seed extraction? → A: Prompt in interactive mode (default Yes); `--quick` skips; `--no-seed` forces skip.
- Q: How should Eidos handle worlds that have both `data/story_bible/` and legacy `data/world.yml`/`story_facts.yml` populated? → A: Eidos only supports the new layout. No in-code migration or conflict resolution. The one existing dual-state world (`worlds/one-review-man/`) is fixed manually as a one-time data cleanup, outside Eidos' runtime.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - First-run output is polished and trustworthy (Priority: P1)

A new user installs Eidos, creates a world from a premise ("a programmer searching for a job"), and runs `eidos produce chapter` for the very first time. They should see clean, coherent output — no alarming "Migrated..." messages about a world they just created, no warnings about unresolved `CHARACTER_NAME` / `CHARACTER_DESCRIPTION` placeholders, no "Difficulty: Not specified" noise, no duplicated language prompts. Interactive prompts during `eidos world new` must offer and accept defaults that actually appear in the options list.

**Why this priority**: This is the first impression. Confusing diagnostic output on a brand-new, empty world makes users doubt the tool is working at all. Every downstream value — bible, canon, chapters, translations — depends on the user trusting what they see in the terminal.

**Independent Test**: Running `eidos world new` followed by `eidos produce chapter` on a fresh temp directory must produce output free of the listed diagnostic noise, and the generated chapter must have a meaningful title (not the literal placeholder "Chapter 1") and no "Difficulty: Not specified" line.

**Acceptance Scenarios**:

1. **Given** a freshly created world (no characters, no prior chapters), **When** the user runs `eidos produce chapter`, **Then** the terminal output contains no message about migrating legacy data.
2. **Given** a chapter is being generated with zero characters in the Story Bible, **When** the generator builds its prompt, **Then** no warnings about unresolved `CHARACTER_NAME` or `CHARACTER_DESCRIPTION` placeholders appear, and the generated chapter does not contain those literal tokens.
3. **Given** the user runs `eidos world new` interactively, **When** they press Enter at each prompt to accept the suggested defaults, **Then** every suggested default matches an entry in the options list shown for that prompt (or the prompt allows free-form input and states so).
4. **Given** the user is asked for a language once during `eidos world new`, **When** the wizard proceeds, **Then** the user is not asked the same language question a second time in the same run.
5. **Given** a generated chapter is displayed, **When** the user reads its header/title, **Then** the title is a meaningful phrase derived from the premise — not the literal string "Chapter 1" — and there is no "Difficulty: Not specified" line.

---

### User Story 2 - One canonical lore store (Priority: P2)

A user creates characters, locations, or facts via the SDK / CLI (e.g. `eidos bible add-character`), runs `eidos produce chapter`, and expects the generated chapter to actually use that lore. Today the CLI/SDK and the chapter generator read and write to different files (`data/story_bible/` vs. `data/world.yml` + `data/story_facts.yml`), so lore entered through one surface is invisible to the other.

**Why this priority**: Without this, the Story Bible is effectively decorative — users add characters but chapters ignore them. It undermines the whole point of a "canonical world." It's P2 only because P1 blocks the first impression; once the first run is sane, this is the biggest structural flaw.

**Independent Test**: Add a character via `eidos bible add-character` (or the SDK), then generate a chapter with no other seeding. The character's name and traits must appear in the prompt the generator sends to the LLM (verifiable via debug artifacts in `tmp/ai_debug/`) and therefore in the generated chapter text, without any manual copy of data between files.

**Acceptance Scenarios**:

1. **Given** a character added through the Story Bible surface, **When** a chapter is generated, **Then** the generator's prompt references that character by name and description.
2. **Given** a fact or location added through the Story Bible surface, **When** a chapter is generated, **Then** the generator has access to that fact/location in its context.
3. **Given** a world whose directory contains stray legacy files (`data/world.yml` and/or `data/story_facts.yml`), **When** the user runs any Eidos command, **Then** Eidos ignores those files (no read, no write, no migration message) and operates solely on `data/story_bible/`.
4. **Given** a chapter is generated, **When** the user later inspects the Story Bible via `eidos bible list`, **Then** any new characters or facts introduced by the LLM during generation are discoverable through the same Story Bible surface (not hidden in a parallel file).

---

### User Story 3 - Premise becomes a Story Bible seed (Priority: P3)

A user runs `eidos world new` and describes their world in a few sentences ("a programmer searching for a job in a recession"). After setup, `eidos bible list` shows at least one seed character, location, or fact derived from that premise — enough that the first chapter doesn't have to invent everything from scratch.

**Why this priority**: This is a quality-of-life improvement on top of P2. Once there's one canonical bible (P2), it's worth populating it with something from the user's premise so the first chapter is coherent with the world description. Without P2 this is moot, hence P3.

**Independent Test**: Run `eidos world new` with a non-trivial premise, then run `eidos bible list`. The list must be non-empty and contain at least one entry whose content is recognizably derived from the premise.

**Acceptance Scenarios**:

1. **Given** a user provides a premise during `eidos world new`, **When** setup completes, **Then** the Story Bible contains at least one seed entity (character, location, or fact) whose text references the premise.
2. **Given** the premise is very short or generic (e.g., a single adjective), **When** setup completes, **Then** the Story Bible is either empty or contains a clearly-labeled placeholder — never garbled or hallucinated content that contradicts the premise.
3. **Given** the user declines any interactive seed-extraction step (or runs in `--quick` mode), **When** setup completes, **Then** the world is still usable; seed extraction is best-effort and never blocks world creation.

---

### Edge Cases

- **Empty Story Bible at chapter generation time**: generator must produce a coherent chapter without emitting warnings about unresolved character placeholders. The prompt should simply omit the character section rather than interpolate literal tokens like `CHARACTER_NAME`.
- **Stray legacy files on disk**: Eidos does not auto-migrate. If a user's world directory contains stray `data/world.yml` or `data/story_facts.yml` files (e.g., from an older checkout), Eidos ignores them entirely. No warning, no migration, no implicit read.
- **Chapter generation on a brand-new world**: a freshly created world must never log a "migrated X to Y" message — there is nothing to migrate, and the auto-migration code path is removed.
- **Interactive defaults not in the options list**: the wizard must either (a) include the default in the options list, (b) state that free-form input is accepted, or (c) pick a default that is in the list.
- **User runs `eidos world reset chapters` on a world that uses the current content layout**: the reset must actually delete the chapter files it reports as targets. It must not silently glob a legacy path and claim success.
- **User overrides the content model via a CLI flag**: the override must reach the slot the generator actually reads from, not a sibling slot that is ignored.
- **LLM seed-extraction fails or times out during `eidos world new`**: world creation still completes; the failure is logged, not fatal.

## Requirements *(mandatory)*

### Functional Requirements

**First-run UX (US1):**

- **FR-001**: `eidos produce chapter` MUST NOT emit any message about migrating, converting, or upgrading data when the world contains no legacy data to migrate.
- **FR-002**: The chapter-generation prompt MUST NOT contain literal placeholder tokens such as `CHARACTER_NAME` or `CHARACTER_DESCRIPTION` when the Story Bible has no characters; the character section MUST be omitted or replaced with coherent text.
- **FR-003**: No warning MUST be emitted for placeholders that were intentionally omitted because the corresponding data is absent.
- **FR-004**: Generated chapters MUST have a title derived from the premise or chapter content, not the literal placeholder "Chapter 1" (the number may still appear; the title itself must be substantive).
- **FR-005**: Generated chapter metadata MUST NOT include fields whose value is "Not specified" — such fields MUST be omitted instead.
- **FR-006**: Every interactive default offered during `eidos world new` MUST either appear in the displayed options list, or the prompt MUST indicate that free-form input is accepted.
- **FR-007**: `eidos world new` MUST ask the user for each piece of setup information at most once per run.
- **FR-008**: CLI overrides for LLM configuration (e.g., `--content-model`) MUST write to the configuration slot that the generator actually reads from, so the override takes effect.
- **FR-009**: `eidos world reset chapters` MUST delete chapter files at the canonical content layout (`content/chapters/`), not a legacy path.

**Unified Story Bible (US2):**

- **FR-010**: There MUST be exactly one canonical lore store per world, located at `data/story_bible/`. All surfaces (CLI, SDK, ChapterGenerator, translator) MUST read from and write to that store.
- **FR-011**: Lore added via the Story Bible surface (characters, locations, facts, relationships, plot threads) MUST be visible to the chapter generator without any manual copy step.
- **FR-012**: Lore added or discovered during chapter generation MUST be visible via the Story Bible surface afterwards.
- **FR-013**: Eidos MUST NOT read from or write to the legacy lore files `data/world.yml` or `data/story_facts.yml`. Code paths that reference them (including any auto-migration logic in the chapter generator) MUST be removed.
- **FR-014**: Fresh worlds created by `eidos world new` MUST NOT produce `data/world.yml` or `data/story_facts.yml`. The world starts on the canonical `data/story_bible/` layout only.
- **FR-014a**: The existing dual-state world at `worlds/one-review-man/` MUST be brought into the canonical layout as a one-time manual data cleanup performed as part of this feature's delivery (outside Eidos' runtime code paths). After this cleanup, its `data/world.yml` and `data/story_facts.yml` MUST be removed or archived out of the active world directory so Eidos does not encounter them on future runs.

**Premise-to-bible seeding (US3):**

- **FR-015**: In interactive mode, `eidos world new` MUST prompt the user with "Seed the Story Bible from your premise? [Y/n]" (default Yes) after capturing the premise. `--quick` MUST skip the prompt and the seed step. `--no-seed` MUST force-skip the step without prompting.
- **FR-016**: Seed extraction failures (LLM errors, timeouts, empty responses) MUST be logged but MUST NOT abort world creation; the world is left in a usable empty-bible state.
- **FR-017**: Seeded entries MUST be clearly attributed as "seed" / "premise-derived" (e.g., via an `origin: seed` marker on each entry) so the user can review and edit them before generating chapters.

### Key Entities *(include if feature involves data)*

- **World**: A storyworld project on disk. Owns exactly one Story Bible, one set of chapters, one configuration. Today it accidentally owns two parallel lore stores; after this work it owns one.
- **Story Bible**: The canonical collection of characters, locations, facts, relationships, and plot threads for a world. Must be readable and writable through a single API used by every surface.
- **Chapter Generation Context**: The bundle of information passed to the LLM when generating a chapter (characters, facts, recent chapters, premise, language, etc.). Must be built from the one canonical Story Bible.
- **Settings**: Per-world LLM and output configuration (`data/settings.yml`). CLI overrides must target the same slots the engine reads.
- **Premise**: The user-authored description captured during `eidos world new`. Input to (optional) seed extraction that populates the Story Bible.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A fresh `eidos world new` → `eidos produce chapter` run on an empty directory produces zero occurrences of the substrings "Migrated", "CHARACTER_NAME", "CHARACTER_DESCRIPTION", and "Not specified" in its output.
- **SC-002**: 100% of interactive defaults offered during `eidos world new` are accepted without error when the user presses Enter to take the default.
- **SC-003**: A character added via the Story Bible surface appears, by name, in the next generated chapter's prompt in at least 95% of runs (measured against debug artifacts).
- **SC-004**: After this feature ships, zero references to `data/world.yml` or `data/story_facts.yml` remain in Eidos' runtime code paths (migration, read, or write). The only canonical store exercised by tests and code is `data/story_bible/`.
- **SC-005**: For a non-trivial premise, `eidos bible list` after `eidos world new` returns at least one seed entry recognizably derived from the premise, on at least 80% of runs with the default model. For short/generic premises, the list is either empty or contains only clearly labeled placeholders — never garbled content.
- **SC-006**: Time from `eidos world new` (non-quick mode, with seed extraction) to first successful `eidos produce chapter` on a fresh machine is under 5 minutes, assuming working API credentials and normal network latency.

## Assumptions

- The primary user is a developer comfortable with a Ruby CLI, working from a terminal on macOS or Linux.
- LLM access is available via environment variables (`OPENAI_API_KEY`, `OPENROUTER_API_KEY`); this feature does not change authentication.
- The default LLM remains `openrouter/google/gemini-3-flash-preview` for content and fallback; model changes are out of scope for this feature.
- Seed extraction uses the same LLM configured for content — no new model tier or provider is introduced.
- Only one real-world dual-state world exists today (`worlds/one-review-man/`); it will be cleaned up manually as part of this feature's delivery. Eidos itself does not need general-purpose legacy migration code.
- Stray legacy files (`data/world.yml`, `data/story_facts.yml`) found in any other world directory are ignored silently by Eidos, not migrated.
- The Jekyll publishing pipeline does not need to change for this feature — it continues to read from whatever the canonical Story Bible exposes.
- Translations continue to work against the unified `data/story_bible/` store.
- Backwards compatibility for external scripts that directly read `data/world.yml` is NOT a requirement; Eidos is the only supported reader/writer of world data.
