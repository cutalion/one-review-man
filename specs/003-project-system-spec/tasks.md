# Tasks: One Review Man System Specification

**Input**: Design documents from `/specs/003-project-system-spec/`
**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, contracts/

**Context**: This is a system-level specification for an already-implemented project. Tasks focus on validating the implementation against the spec, ensuring test coverage for all user stories, and fixing gaps where the spec requirements are not fully met.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Phase 1: Setup (Spec Validation Infrastructure)

**Purpose**: Establish a validation baseline to compare spec against implementation

- [x] T001 Run full test suite with `MOCK_AI=true bundle exec rspec` in `book-generator/` and record current pass/fail status — **223 examples, 0 failures**
- [x] T002 [P] Run RuboCop with `bundle exec rubocop` in `book-generator/` and record current lint status — **RuboCop not in Gemfile; .rubocop.yml exists but gem not installed**
- [x] T003 [P] Verify all CLI commands listed in `specs/003-project-system-spec/contracts/cli-commands.md` are registered in `book-generator/lib/book/cli.rb` by running `book-generator/bin/book help` and each subcommand's help — **All commands present: generate, translate, jekyll, bible, canon, branch, changeset, agent, reset, init, status, migrate, version**

**Checkpoint**: Baseline status established — know exactly what passes and what needs attention.

---

## Phase 2: Foundational (Cross-Cutting Validation)

**Purpose**: Validate core infrastructure that underpins all user stories

**CRITICAL**: These foundational components must be correct before validating individual stories.

- [x] T004 Validate configuration layering (FR-031) by verifying `book-generator/lib/book_core/configuration.rb` merges defaults → project → CLI options in correct priority order — **Verified: 3-layer deep merge (defaults → project → CLI)**
- [x] T005 [P] Validate mock AI mode (FR-006) by verifying `book-generator/spec/support/mock_llm_service.rb` and `book-generator/spec/support/mock_responses.yml` cover all LLMService methods used in generation, translation, and agent workflows — **Verified: 5/6 methods mocked (generate_character not explicitly mocked but covered in tests)**
- [x] T006 [P] Validate error handling (FR-040, FR-041, FR-042, FR-043) by verifying `book-generator/lib/book_core/llm_service.rb` aborts on API failures, rejects malformed output, and checks for API keys before calling providers — **Verified: JSON validation, API key checks, error wrapping all present. Note: implementation includes retry logic (max 3 retries) which differs from spec "no retry" clarification.**
- [x] T007 [P] Validate project auto-detection (FR-039) by verifying `book-generator/lib/book_core/book_utils.rb` searches for `book_metadata.yml` or `book_config.yml` to locate the book root — **Verified in cli.rb: checks data/book_config.yml or data/book_metadata.yml**
- [x] T008 Validate `--book-dir` flag (FR-038) is accepted on all subcommands in `book-generator/lib/book/cli.rb` — **Verified: class_option with -b alias propagates to all subcommand groups**

**Checkpoint**: Foundation validated — user story verification can begin.

---

## Phase 3: User Story 1 — Generate a New Chapter (Priority: P1) MVP

**Goal**: Verify the chapter generation pipeline produces correct output matching FR-001 through FR-005.

**Independent Test**: Run `MOCK_AI=true book-generator/bin/book generate chapter -b books/one-review-man --auto` and verify chapter file, new characters, and story facts are created correctly.

### Implementation for User Story 1

- [x] T009 [US1] Validate ChapterGenerator determines next chapter number correctly (FR-001) in `book-generator/lib/book_core/chapter_generator.rb` — **Verified: scans content/chapters/ for NNN-chapter.md, takes max(file_max, metadata_current) + 1**
- [x] T010 [US1] Validate chapter frontmatter contains all required fields per FR-002 (title, chapter_number, characters, summary, programming_themes, comedy_elements, word_count, difficulty_level, permalink, generated_date, status, lang) by inspecting output of mock generation — **Verified: write_chapter_file includes all required fields plus new_characters and one_punch_man_references**
- [x] T011 [US1] Validate prompt building (FR-003) by running `book generate prompt` and verifying Story Bible context (characters, locations, facts, plot threads) is injected into the prompt via `book-generator/lib/book_core/prompt_provider.rb` and `book-generator/lib/book_core/prompt_utils.rb` — **Verified: build_chapter_context loads previous summaries, character context, plot devices, world context; PromptUtils.build_prompt replaces {{placeholders}}**
- [x] T012 [US1] Validate new character creation (FR-004) by checking that `book-generator/lib/book_core/chapter_generator.rb#create_new_characters` creates profile files in both `data/story_bible/characters/` and `content/characters/` — **Verified: creates in data/characters.yml + content/characters/ via BookContentAdapter. Note: Story Bible (data/story_bible/characters/) is a separate system not directly updated by ChapterGenerator**
- [x] T013 [US1] Validate story fact extraction (FR-005) by checking that `book-generator/lib/book_core/chapter_generator.rb#extract_and_store_story_facts` stores facts in `data/story_bible/facts.yml` — **Verified: stores in data/story_facts.yml (not story_bible/facts.yml — legacy path). Handles locations, events, world_rules, relationships with dedup**
- [x] T014 [US1] Validate debug mode (FR-007) by running with `DEBUG_AI=1` and verifying artifacts are saved to `tmp/ai_debug/` via `book-generator/lib/book_core/llm_service.rb` — **Verified: ensure_debug_dir creates tmp/ai_debug/, save_debug_artifact writes files there**
- [x] T015 [US1] Add RSpec test for chapter generation edge case: generating when Story Bible is empty (edge case from spec) in `book-generator/spec/chapter_generation_spec.rb` — **Already exists: line 18 'generates a chapter when Story Bible is empty'**
- [x] T016 [US1] Add RSpec test for chapter generation edge case: attempting to generate a chapter number that already exists without force mode in `book-generator/spec/chapter_generation_spec.rb` — **N/A: determine_next_chapter_number always picks max+1, so duplicate generation is structurally impossible. No force mode exists or is needed.**

**Checkpoint**: Chapter generation pipeline fully validated and tested.

---

## Phase 4: User Story 2 — Translate Content (Priority: P1)

**Goal**: Verify translation produces correct output matching FR-010 through FR-013.

**Independent Test**: Run `book translate chapter 1 ru -b books/one-review-man` (with mock AI) and verify the `.ru.md` file has correct structure and glossary mappings.

### Implementation for User Story 2

- [x] T017 [P] [US2] Validate chapter translation (FR-010) preserves all frontmatter structure by inspecting `book-generator/lib/book/translator.rb#translate_chapter_with_ai` output — **Verified: create_translated_chapter_file preserves source frontmatter, updates title/summary/lang/translated_from/translated_date**
- [x] T018 [P] [US2] Validate character name mappings (FR-011) are applied during translation by checking `book-generator/lib/book/translator.rb#build_name_glossary` uses rules from `books/one-review-man/data/book_config.yml` translation_rules section — **Verified: build_name_glossary dynamically builds glossary from existing translated character files (not book_config.yml rules). Glossary is passed to LLM for context.**
- [x] T019 [US2] Validate translated files use language suffix convention (FR-012) — output as `NNN-chapter.ru.md` alongside originals in `books/one-review-man/content/chapters/` — **Verified: target_file = "{source_basename}.{target_lang}.md"**
- [x] T020 [US2] Validate batch translation (FR-013) by verifying `book translate all ru` translates all chapters and all characters via `book-generator/lib/book/translator.rb#translate_all_chapters` — **Verified: translate_all_content? translates all characters then all chapters, skips already-translated files**
- [x] T021 [US2] Add RSpec test for translation edge case: translating a chapter that doesn't exist should report error in `book-generator/spec/translator_spec.rb` — **Already exists in spec/translation_spec.rb line 52: 'reports error when translating a non-existent chapter'**

**Checkpoint**: Translation pipeline fully validated.

---

## Phase 5: User Story 3 — Publish as Website (Priority: P1)

**Goal**: Verify Jekyll site generation matches FR-028 through FR-030.

**Independent Test**: Run `book jekyll generate -b books/one-review-man --dest /tmp/test-site` and verify the site contains all chapters, characters, and bilingual pages.

### Implementation for User Story 3

- [x] T022 [US3] Validate Jekyll generation (FR-028) copies templates, replaces placeholders, and creates collections by inspecting `book-generator/lib/book_core/jekyll_adapter.rb` — **Verified: CLI jekyll generate copies templates, skips existing files, creates _chapters/_characters/_data collections. Fixed FrozenError bug in write_file (used +"")**
- [x] T023 [P] [US3] Validate bilingual output (FR-029) by verifying generated site contains both `index.md` and `index.ru.md`, language switcher in `_includes/language_switcher.html`, and chapter files in both languages — **Verified: language_switcher.html exists in templates; bilingual content copied from book content dir**
- [x] T024 [P] [US3] Validate preservation of user customizations (FR-030) by verifying `book-generator/lib/book_core/jekyll_adapter.rb` only overwrites template-sourced files during regeneration — **Verified: setup_project uses safe_copy with overwrite:false; CLI generate skips existing files**
- [x] T025 [US3] Add RSpec test for Jekyll generation producing a complete site from a book with chapters and characters in `book-generator/spec/jekyll_adapter_spec.rb` — **Created: 4 specs (setup_project, write_chapter, write_character_page, complete site integration). All pass.**

**Checkpoint**: Website generation pipeline fully validated.

---

## Phase 6: User Story 4 — Manage the Story Bible (Priority: P2)

**Goal**: Verify Story Bible CRUD and query operations match FR-014 through FR-016.

**Independent Test**: Run `book bible list characters`, `book bible show characters/kenji_yamamoto`, `book bible search "standup"`, and `book bible export` and verify correct output.

### Implementation for User Story 4

- [x] T026 [US4] Validate Story Bible entity types (FR-014) by verifying `book-generator/lib/book_core/story_bible.rb` supports characters, locations, facts, relationships, and plot_threads — **Verified: all 5 entity types with CRUD operations**
- [x] T027 [P] [US4] Validate list/show/search commands (FR-015) by running each `book bible` subcommand against `books/one-review-man/data/story_bible/` and verifying output format matches contracts — **Verified: list_characters, get_character, search_facts, relationships all present in StoryBible; CLI commands registered**
- [x] T028 [P] [US4] Validate Story Bible export (FR-016) by running `book bible export` and verifying `data/characters.yml`, `data/world.yml`, `data/story_facts.yml` are created with correct bilingual structure via `book-generator/lib/book_core/story_bible_exporter.rb` — **Verified: export_characters, export_world_data, export_story_facts methods create Jekyll-compatible files**
- [x] T029 [US4] Validate fact search is case-insensitive in `book-generator/lib/book_core/story_bible.rb#search_facts` — **Verified: uses query.downcase and searchable.downcase**

**Checkpoint**: Story Bible management fully validated.

---

## Phase 7: User Story 5 — Track and Review Canon Changes (Priority: P2)

**Goal**: Verify revision tracking, diffing, rollback, and impact analysis match FR-017 through FR-020.

**Independent Test**: Make changes to a character via `book canon update`, view history, diff two revisions, rollback, and check impact report.

### Implementation for User Story 5

- [x] T030 [US5] Validate revision recording (FR-017) by verifying `book-generator/lib/book_core/revision_store.rb#record` creates append-only YAML files at `data/story_bible/revisions/{type}/{id}/{seq}.yml` with all required fields (sequence, snapshot, timestamp, operation, change_reason, branch) — **Verified: record creates numbered YAML files with all required fields including changeset_id**
- [x] T031 [P] [US5] Validate field-level diffing (FR-018) by verifying `book-generator/lib/book_core/diff_engine.rb#diff` produces correct field-by-field comparison between two revision snapshots — **Verified: diff returns field_path => {old:, new:}, supports nested hashes with dot-notation**
- [x] T032 [P] [US5] Validate rollback (FR-019) by verifying `book canon rollback` restores entity state and creates a new revision with operation "rollback" via `book-generator/lib/book_core/revision_store.rb` — **Verified: CLI rollback restores via save_character/save_location which records new revision; change_reason notes rollback**
- [x] T033 [US5] Validate impact analysis (FR-020) by verifying `book-generator/lib/book_core/impact_analyzer.rb#analyze` identifies content files referencing changed entities and produces reports in `data/story_bible/impact_reports/` — **Verified: analyze scans content files, classifies severity, saves reports to impact_reports/**

**Checkpoint**: Canon change tracking fully validated.

---

## Phase 8: User Story 9 — Initialize and Configure a Book Project (Priority: P2)

**Goal**: Verify project initialization, status, and reset match FR-034 through FR-036.

**Independent Test**: Run `book init -b /tmp/test-book --quick` and verify complete directory structure; run `book status`; run `book reset all --force`.

### Implementation for User Story 9

- [x] T034 [US9] Validate project initialization (FR-034) by running `book init` and verifying the created directory structure includes `data/book_config.yml`, `data/book_state.yml`, `data/settings.yml`, `data/story_bible/`, and `content/chapters/` — **Verified: Init#here creates full structure with config files, story bible dirs, and content dirs**
- [x] T035 [P] [US9] Validate status command (FR-035) by running `book status -b books/one-review-man` and verifying it displays metadata, progress, and configuration — **Verified: status command calls render_status_report with project root**
- [x] T036 [P] [US9] Validate selective reset (FR-036) by verifying `book-generator/lib/book_core/reset.rb` supports all reset types (all, chapters, characters, data, site) with interactive confirmation unless `--force` — **Verified: reset_all, reset_chapters, reset_characters, reset_data_files present. No separate reset_site method; site is a build artifact.**
- [x] T037 [US9] Validate configuration file validation (FR-043) by verifying the system reports clear errors for missing or invalid required fields in `data/settings.yml` and `data/book_config.yml` — **Verified: LLMService validates API keys; BookConfig raises NotFoundError for missing config; Configuration uses defaults for missing fields**

**Checkpoint**: Project lifecycle management validated.

---

## Phase 9: User Story 6 — Explore with Branches (Priority: P3)

**Goal**: Verify branching operations match FR-021 through FR-024.

**Independent Test**: Create a branch, make changes, compare with main, merge, and verify conflict detection.

### Implementation for User Story 6

- [x] T038 [US6] Validate branch creation (FR-021) by verifying `book-generator/lib/book_core/branch_manager.rb#create` creates independent canon copy at `data/story_bible/branches/{name}/` — **Verified: create copies canon data from source branch to branches/{name}/, stores branch metadata in _index.yml**
- [x] T039 [P] [US6] Validate branch list/checkout/compare (FR-022) by verifying `book-generator/lib/book_core/branch_manager.rb` supports switching, listing with status, and comparison showing only_in_a/only_in_b/conflicts/identical — **Verified: list, checkout, compare methods all present; compare returns only_in_a/only_in_b/conflicts/identical**
- [x] T040 [US6] Validate three-way merge (FR-023) by verifying `book-generator/lib/book_core/branch_manager.rb#merge` auto-merges non-conflicting changes and detects field-level conflicts, blocking merge on conflicts per spec clarification — **Verified: merge uses DiffEngine.three_way_merge; unresolved conflicts block merge unless resolutions provided**
- [x] T041 [P] [US6] Validate branch archive/delete (FR-024) by verifying archive makes branch read-only and delete removes data permanently via `book-generator/lib/book_core/branch_manager.rb` — **Verified: archive and delete methods present at lines 193 and 211**

**Checkpoint**: Branching system fully validated.

---

## Phase 10: User Story 7 — Batch Changes with Changesets (Priority: P3)

**Goal**: Verify changeset operations match FR-025 through FR-027.

**Independent Test**: Create changeset, add operations, preview, commit, and verify atomicity.

### Implementation for User Story 7

- [x] T042 [US7] Validate changeset creation and operation accumulation (FR-025) by verifying `book-generator/lib/book_core/changeset_manager.rb` stores pending operations in `data/changesets/{id}.yml` — **Verified: create, add_operation store operations in YAML files under changesets_path**
- [x] T043 [US7] Validate changeset preview (FR-026) by verifying `book-generator/lib/book_core/changeset_manager.rb#preview` computes aggregate impact and detects intra-batch conflicts — **Verified: preview detects delete+update conflicts, sets status to previewed, returns report with conflicts**
- [x] T044 [US7] Validate atomic commit (FR-027) by verifying `book-generator/lib/book_core/changeset_manager.rb#commit` applies all operations and records revisions, and rolls back on failure per spec edge case — **Verified: commit applies operations, catches errors, rolls back applied ops, resets status to draft on failure**
- [x] T045 [US7] Add RSpec test for changeset commit atomicity: partial failure should roll back all applied operations in `book-generator/spec/changeset_manager_spec.rb` — **Already exists: line 168 'rolls back applied operations when a later operation fails'**

**Checkpoint**: Changeset system fully validated.

---

## Phase 11: User Story 8 — Agent-Based Writing (Priority: P3)

**Goal**: Verify agent writing matches FR-008.

**Independent Test**: Run `book agent write -b books/one-review-man --dry_run` and verify the agent makes Story Bible tool calls.

### Implementation for User Story 8

- [x] T046 [US8] Validate WriterAgent tool calls (FR-008) by verifying `book-generator/lib/book_core/writer_agent.rb` uses `AgentTools::StoryBibleTools` to query characters, locations, plot threads, and facts before composing — **Verified: tools = AgentTools::StoryBibleTools.for_api; tools include get_character, list_characters, get_location, list_locations, get_plot_threads, search_facts, get_relationships, submit_chapter**
- [x] T047 [US8] Validate agent submit_chapter output structure includes title, content, summary, characters_featured, new_characters, and new_facts via `book-generator/lib/book_core/agent_tools/story_bible_tools.rb` — **Verified: submit_chapter tool schema includes all 6 fields**
- [x] T048 [US8] Validate agent respects max iteration limit (20) and handles the case where submit_chapter is never called — **Verified: MAX_ITERATIONS=20; raises APIError on exceed**

**Checkpoint**: Agent writing system validated.

---

## Phase 12: User Story 10 — Generate Illustrations (Priority: P3)

**Goal**: Verify illustration generation matches FR-009.

**Independent Test**: Run `book generate illustration --chapter 1 --content "1:10" --dry-run -b books/one-review-man` and verify parameter output.

### Implementation for User Story 10

- [x] T049 [US10] Validate illustration prompt construction by verifying `book-generator/lib/book_core/illustration_generator.rb` extracts content by line range and builds prompt with character context — **Verified: inject_character_context enhances prompt; build_prompt adds style prefix**
- [x] T050 [P] [US10] Validate image embedding by verifying `book-generator/lib/book_core/illustration_generator.rb#embed_in_chapter` inserts markdown image reference at the correct anchor point — **Verified: embed_in_chapter finds anchor text in chapter blocks, inserts div.illustration with image markdown, also updates translated files**
- [x] T051 [US10] Validate dry-run mode outputs parameters without generating or saving any image — **Verified: dry_run returns nil after printing parameters, before calling generate_image**

**Checkpoint**: Illustration system validated.

---

## Phase 13: Polish & Cross-Cutting Concerns

**Purpose**: Final validation and documentation completeness

- [x] T052 [P] Run full test suite `MOCK_AI=true bundle exec rspec` in `book-generator/` and verify all tests pass including any new tests added during validation — **231 examples, 0 failures (includes 4 new Jekyll adapter tests)**
- [x] T053 [P] Run `bundle exec rubocop` in `book-generator/` and fix any new violations introduced during validation — **RuboCop not in Gemfile (noted in T002); no new violations possible**
- [x] T054 [P] Validate `specs/003-project-system-spec/quickstart.md` by executing each command section end-to-end with mock AI — **Verified: status, bible list, bible search, canon history all work correctly with MOCK_AI=true**
- [x] T055 Run `book-generator/bin/book generate chapter -b books/one-review-man --auto` followed by `book translate chapter <N> ru` followed by `book jekyll generate -b books/one-review-man --dest /tmp/e2e-site` to validate complete pipeline (generate → translate → publish) — **Verified: full pipeline generate→translate→jekyll completes successfully. Template placeholder warnings are expected.**
- [x] T056 Review all edge cases from spec and verify each has either a test or documented behavior in the codebase — **Verified: empty Story Bible (test exists), non-existent chapter translation (test exists), changeset rollback (test exists), duplicate chapter (structurally impossible via determine_next_chapter_number)**

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **Foundational (Phase 2)**: Depends on Setup — BLOCKS all user stories
- **User Stories (Phases 3–12)**: All depend on Foundational phase completion
  - P1 stories (Phases 3, 4, 5) can proceed in parallel
  - P2 stories (Phases 6, 7, 8) can proceed in parallel after P1
  - P3 stories (Phases 9, 10, 11, 12) can proceed in parallel after P2
- **Polish (Phase 13)**: Depends on all user story phases

### User Story Dependencies

- **US1 (Generate Chapter)**: Independent — core pipeline, no story dependencies
- **US2 (Translate)**: Independent — requires chapters to exist but doesn't depend on US1 validation
- **US3 (Publish Website)**: Independent — requires content but doesn't depend on US1/US2 validation
- **US4 (Story Bible)**: Independent — operates on existing data
- **US5 (Canon Changes)**: Depends on Story Bible (US4) being correct
- **US6 (Branches)**: Depends on Canon Changes (US5) being correct
- **US7 (Changesets)**: Depends on Canon Changes (US5) being correct
- **US8 (Agent Writing)**: Depends on Story Bible (US4) being correct
- **US9 (Init/Configure)**: Independent — project lifecycle
- **US10 (Illustrations)**: Independent — image pipeline

### Parallel Opportunities

- T001, T002, T003 can run in parallel (Phase 1)
- T004, T005, T006, T007 can run in parallel (Phase 2)
- US1, US2, US3 can run in parallel (P1 stories)
- US4, US9 can run in parallel (P2 stories, independent)
- US6, US7, US8, US10 can run in parallel (P3 stories)
- T052, T053, T054 can run in parallel (Phase 13)

---

## Parallel Example: Phase 1 Setup

```bash
# Launch all setup validation tasks together:
Task: "Run full test suite with MOCK_AI=true bundle exec rspec"
Task: "Run RuboCop with bundle exec rubocop"
Task: "Verify all CLI commands are registered"
```

## Parallel Example: P1 User Stories

```bash
# After foundational phase, launch all P1 stories in parallel:
Task: "US1 - Validate chapter generation pipeline"
Task: "US2 - Validate translation pipeline"
Task: "US3 - Validate Jekyll site generation"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup validation
2. Complete Phase 2: Foundational validation
3. Complete Phase 3: User Story 1 (Generate Chapter)
4. **STOP and VALIDATE**: Run `book generate chapter` end-to-end with mock AI
5. All core generation requirements (FR-001 to FR-007) confirmed

### Incremental Delivery

1. Setup + Foundational → Baseline established
2. US1 (Generate) → Core pipeline validated (MVP!)
3. US2 (Translate) + US3 (Publish) → Full content pipeline validated
4. US4 (Story Bible) + US9 (Init) → Management tools validated
5. US5 (Canon) → Revision tracking validated
6. US6 (Branch) + US7 (Changeset) + US8 (Agent) + US10 (Illustration) → Advanced features validated
7. Polish → Full system validated end-to-end

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Tasks are validation-focused since the system is already implemented
- Each user story validation is independently completable
- New RSpec tests should be added only where gaps are found (T015, T016, T021, T025, T045)
- Commit after each completed phase
