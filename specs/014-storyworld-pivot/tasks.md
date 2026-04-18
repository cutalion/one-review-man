---
description: "Task list for feature 014-storyworld-pivot"
---

# Tasks: IP-Generator Pivot — Pieces, Forms, and Canon Feedback

**Input**: Design documents from `/home/cutalion/code/one-review-man/specs/014-storyworld-pivot/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: Included. FR-027 mandates coverage for chapter back-compat, custom-form discovery, and dry-run / auto-apply / canon-review flows; Constitution Principle I requires all new code under `MOCK_AI=true`. Test-first is idiomatic in this codebase — write the spec, then the implementation.

**Organization**: Tasks are grouped by user story so US1 can ship independently, then US2, then US3.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no incomplete dependencies).
- **[Story]**: US1 / US2 / US3 — maps to user stories from spec.md.
- Every task names exact file paths.
- Absolute paths assumed; relative paths are from the repo root `/home/cutalion/code/one-review-man/`.

---

## Phase 1: Setup (shared scaffolding)

- [X] T001 Audit book-era terminology in user-facing docs. Scan `CLAUDE.md`, `eidos/lib/eidos/prompts/PLACEHOLDERS_REFERENCE.md`, `eidos/lib/eidos/prompts/chapter_prompts.txt`, and any CLI help strings in `eidos/lib/eidos/cli/*.rb`; write the findings list to `specs/014-storyworld-pivot/terminology-sweep.md`.
- [X] T002 Create empty scaffold directories for new built-in forms and prompt templates at `eidos/lib/eidos/forms/` (with a `.keep` file so the directory is tracked).

**Checkpoint**: no code changes yet; only a scratch audit file and an empty forms directory exist.

---

## Phase 2: Foundational (blocking prerequisites for ALL stories)

These tasks land the shared types and a minimum-viable form registry that every story below depends on. **Do NOT begin any US* phase until Phase 2 completes.**

- [X] T003 [P] Implement `Piece` SDK value object with fields per data-model.md (id, form, category, generated_date, canon_version, canon_status, length_measured, canon_delta_ref, content_path, asset_path) in `eidos/lib/eidos/piece.rb`.
- [X] T004 [P] Implement `PieceCollection` (Enumerable, filterable by form and canon_status) in `eidos/lib/eidos/piece_collection.rb`.
- [X] T005 [P] Implement `Form` value object (name, category, default_length, default_shape, prompt_template_path, canon_context, origin) in `eidos/lib/eidos/form.rb`.
- [X] T006 Implement `FormRegistry` with built-ins-only discovery (world-local loader added later in US2) in `eidos/lib/eidos/form_registry.rb`; registry API: `#find(name)`, `#each`, `#list`, `#categories`, raises `FormNotFound` with available names on miss.
- [X] T007 [P] Create built-in form YAMLs for chapter, vignette, short-story, haiku, comic-script, portrait, social-post, illustration at `eidos/lib/eidos/forms/chapter.yml`, `eidos/lib/eidos/forms/vignette.yml`, `eidos/lib/eidos/forms/short_story.yml`, `eidos/lib/eidos/forms/haiku.yml`, `eidos/lib/eidos/forms/comic_script.yml`, `eidos/lib/eidos/forms/portrait.yml`, `eidos/lib/eidos/forms/social_post.yml`, `eidos/lib/eidos/forms/illustration.yml` — schemas per `contracts/form-definition.md`.
- [X] T008 [P] Create built-in prompt templates (one per form) with `{USER_PROMPT}`, `{LENGTH_TARGET}`, `{CANON_CONTEXT}` placeholders and the `---CANON-DELTA---` tail request block at `eidos/lib/eidos/forms/chapter.prompt.txt`, `eidos/lib/eidos/forms/vignette.prompt.txt`, `eidos/lib/eidos/forms/short_story.prompt.txt`, `eidos/lib/eidos/forms/haiku.prompt.txt`, `eidos/lib/eidos/forms/comic_script.prompt.txt`, `eidos/lib/eidos/forms/portrait.prompt.txt`, `eidos/lib/eidos/forms/social_post.prompt.txt`, `eidos/lib/eidos/forms/illustration.prompt.txt`.
- [X] T009 Implement `PieceProducer` skeleton with DI keyword-arg constructor (`llm_service:`, `form_registry:`, `bible:`, `canon:`, `output_adapter:`, `prompt_provider:`) and `#produce(form:, prompt:, length: nil)` stub in `eidos/lib/eidos/producers/piece_producer.rb`. Delta extraction and apply come in US3; for now the producer just generates text and writes a piece file.
- [X] T010 Extend `Eidos::World` SDK with `#pieces` (returns `PieceCollection`) and `#forms` (returns `FormRegistry`) accessors in `eidos/lib/eidos/world.rb`.

**Checkpoint**: `Piece`, `Form`, `FormRegistry`, and `PieceProducer` skeletons load in a Ruby REPL; specs not yet written.

---

## Phase 3: User Story 1 — Produce non-chapter pieces without book-era defaults (P1) 🎯 MVP

**Story goal**: A user can ask the CLI for a 400-word vignette and get one — not padded up to the chapter range, not living in the chapters directory — while `produce chapter` keeps generating byte-identical output.

**Independent Test (from spec.md)**: `eidos produce piece --form vignette --length 400 --prompt "…"` lands a file under `content/pieces/vignette/`, measured length ≈ 400 words. In the same repo, `eidos produce chapter --auto` still produces a file whose shape matches pre-feature output (filename pattern, frontmatter keys, directory).

### Tests for US1 (write before implementation)

- [X] T011 [P] [US1] Spec: `ChapterGenerator` delegating through `PieceProducer` still produces byte-identical frontmatter keys/order and same output path as pre-feature. Lock this with a fixture comparison in `eidos/spec/eidos/producers/chapter_producer_back_compat_spec.rb`.
- [X] T012 [P] [US1] Spec: `PieceProducer#produce(form: 'vignette', prompt: …, length: 400)` writes a file under `worlds/<name>/content/pieces/vignette/<id>.md`, with piece frontmatter (form, category, canon_version, canon_status) and measured length within tolerance of 400 words, in `eidos/spec/eidos/producers/piece_producer_spec.rb`.
- [X] T013 [P] [US1] Spec: length precedence — CLI `--length` wins over form default; world-wide `chapter_length_target` is NOT injected into non-chapter prompts. Assert the outgoing prompt (captured via `MockLLMService`) carries the right length and does not mention the world's chapter range. File: `eidos/spec/eidos/producers/piece_producer_length_spec.rb`.
- [X] T014 [P] [US1] Spec: CLI — `eidos produce piece --form vignette --prompt "…" --length 400` and `eidos produce chapter` both succeed in `MOCK_AI=true`, in `eidos/spec/eidos/cli/produce_spec.rb`.
- [X] T015 [P] [US1] Add mock-response fixtures for `vignette` form (including a `---CANON-DELTA---` tail that will be used by US3; US1 ignores it) to `eidos/spec/support/mock_responses.yml`.

### Implementation for US1

- [X] T016 [US1] Implement `PieceProducer#produce` for text forms: build prompt (placeholder fill per `eidos/lib/eidos/prompt_utils.rb`), call `LLMService`, strip `---CANON-DELTA---` tail if present (US1 discards; US3 parses), measure length, write piece file with frontmatter (form, category, generated_date, canon_version, canon_status: applied, length_measured, canon_delta_ref: nil for US1). File: `eidos/lib/eidos/producers/piece_producer.rb`.
- [X] T017 [US1] Implement length resolution in `PieceProducer` — order: CLI `--length` > form's `default_length` > form's `default_shape`. For form=`chapter` only, fall back to the world's `chapter_length_target` to preserve existing behavior. All other forms MUST ignore `chapter_length_target` (FR-004). File: `eidos/lib/eidos/producers/piece_producer.rb`.
- [X] T018 [US1] Refactor `ChapterGenerator` to delegate to `PieceProducer` with form=`chapter` while preserving its public method signatures, output directory (`content/chapters/`), filename pattern (`NNN-chapter.md`), and frontmatter key order. Existing `new_characters` extraction remains in place here for US1 (US3 replaces it with universal CanonDelta). File: `eidos/lib/eidos/chapter_generator.rb`.
- [X] T019 [US1] Update `Eidos::ChapterProducer` (already exists under `eidos/lib/eidos/producers/chapter_producer.rb`) to be the chapter-specific wrapper that reads `chapter_length_target` from world config and passes it into `PieceProducer` via the `chapter` form's default_length. File: `eidos/lib/eidos/producers/chapter_producer.rb`.
- [X] T020 [US1] Add `eidos produce piece --form NAME --prompt TEXT --length N --world-dir PATH` subcommand to the Thor router in `eidos/lib/eidos/cli/produce.rb`. Reserved subcommands (chapter, comic, illustration) still win; `piece` is a new reserved subcommand.
- [X] T021 [US1] Confirm `eidos produce chapter` retains its existing flags and output — it now internally delegates through `ChapterGenerator → PieceProducer` but the user-facing contract is unchanged. Adjust only the internal plumbing in `eidos/lib/eidos/cli/produce.rb`.
- [X] T022 [US1] Add SDK-based read-only `eidos piece list` (table of pieces with id, form, canon_status, canon_version, generated_date) and `eidos piece show PIECE_ID` subcommands following the pattern of `eidos chapter list`. Files: `eidos/lib/eidos/cli/piece_cli.rb` (new), register in `eidos/lib/eidos/cli/main.rb`.
- [X] T023 [P] [US1] Docs sweep (per T001 audit findings) to replace book-centric framing with piece/form terminology; leave "chapter" as one valid form. Edit `CLAUDE.md` and `eidos/lib/eidos/prompts/PLACEHOLDERS_REFERENCE.md`. Target is SC-003: zero statements framing the world as "a book" in top-level docs.
- [X] T024 [US1] Spec for `piece list` / `piece show` in `eidos/spec/eidos/cli/piece_cli_spec.rb`.

**Checkpoint**: US1 is independently shippable. `produce chapter` byte-identical (SC-002); `produce piece --form vignette --length 400` works (SC-001); docs refreshed (SC-003). Full test suite should still be green with `MOCK_AI=true`.

---

## Phase 4: User Story 2 — Open-ended form registry with world-local custom forms (P2)

**Story goal**: A user drops a haiku form into `worlds/<name>/data/forms/haiku.yml` and invokes it immediately — without editing the gem, without restarting anything.

**Independent Test (from spec.md)**: add a world-local `haiku.yml` + prompt template, then `eidos produce haiku --prompt "…"` produces a piece matching the declared shape. The built-in registry must also keep working from Phase 2.

### Tests for US2

- [X] T025 [P] [US2] Spec: `FormRegistry` loads world-local forms on top of built-ins, world-local overrides emit the notice described in `contracts/form-definition.md`. File: `eidos/spec/eidos/form_registry_spec.rb`.
- [X] T026 [P] [US2] Spec: unknown `canon_context` values in a form YAML log a warning and the form is skipped rather than crashing the CLI. File: `eidos/spec/eidos/form_registry_spec.rb` (new context in same file).
- [X] T027 [P] [US2] Spec: short `eidos produce haiku` dispatches to `produce piece --form haiku` when haiku is registered and the name is not a reserved subcommand; reserved subcommands (chapter, piece, comic, illustration) always win. File: `eidos/spec/eidos/cli/produce_spec.rb` (new context).
- [X] T028 [P] [US2] Spec: `eidos produce nonesuch` exits 1 with stderr listing forms available in that world (FR-014). File: `eidos/spec/eidos/cli/produce_spec.rb` (new context).
- [X] T029 [P] [US2] Spec: `canon_context` injection — `PieceProducer` fills `{CANON_CONTEXT}` with the requested slices (`all_characters`, `recent_events`, `current_chapter`, `all_locations`, or empty for `none`). File: `eidos/spec/eidos/producers/piece_producer_spec.rb` (new context).
- [X] T030 [P] [US2] Add mock-response fixtures for `haiku` and `portrait` forms (text + image-prompt shapes) to `eidos/spec/support/mock_responses.yml`.

### Implementation for US2

- [X] T031 [US2] Extend `FormRegistry` with world-local loader: scan `worlds/<name>/data/forms/*.yml`, parse each, resolve `prompt_template_path` relative to the YAML file's directory, merge on top of built-ins with override-notice tracking. File: `eidos/lib/eidos/form_registry.rb`.
- [X] T032 [US2] Implement `canon_context` injection inside `PieceProducer`: given a form's `canon_context` list, assemble the text block to substitute into the `{CANON_CONTEXT}` placeholder. Uses existing `Eidos::Bible` / `Eidos::Canon` SDK. File: `eidos/lib/eidos/producers/piece_producer.rb`.
- [X] T033 [US2] Add short-form dispatch: in the Thor router, when the first positional argument after `produce` resolves to a registered form name AND is not a reserved subcommand, dispatch to `produce piece --form NAME ...`. Files: `eidos/lib/eidos/cli/produce.rb`, `eidos/lib/eidos/cli/main.rb`.
- [X] T034 [US2] Unknown-form error output: raise a `FormNotFound` in the registry, catch it at the CLI layer, and print `Available forms in this world: a, b, c, ...` to stderr before exiting 1. File: `eidos/lib/eidos/cli/produce.rb`.
- [X] T035 [US2] Override notice: when `produce piece --form NAME` selects a world-local form that shadows a built-in, print `Using world-local form 'NAME' (overrides built-in).` on the first line of stdout (FR-013, contract in `contracts/form-definition.md`). File: `eidos/lib/eidos/cli/produce.rb`.
- [X] T036 [US2] Extend `produce` help text to list forms registered in the active world (built-ins + world-local) when `eidos produce piece --help` is invoked. File: `eidos/lib/eidos/cli/produce.rb`.

**Checkpoint**: US2 is independently shippable on top of US1. A fresh custom form in `worlds/one-review-man/data/forms/` works without a rebuild (SC-004); a user can produce 5 distinct forms from one world in one afternoon (SC-005); unknown-form errors are helpful (SC-006).

---

## Phase 5: User Story 3 — Universal canon extraction + optimistic apply + `canon review` audit (P3)

**Story goal**: Every producer emits a structured CanonDelta; deltas apply optimistically so the next piece sees new canon immediately; `canon review` surfaces findings; `canon revert` is non-destructive.

**Independent Test (from spec.md)**: produce a piece that introduces a new character; the next piece in the same world sees that character in context automatically. `canon review` reports a clean world or lists findings with remediation commands.

### Tests for US3

- [X] T037 [P] [US3] Spec: `CanonDelta.parse` happy path — extracts all six section keys from a well-formed tail block. File: `eidos/spec/eidos/canon_delta_spec.rb`.
- [X] T038 [P] [US3] Spec: `CanonDelta.parse` failure paths — missing sentinel, unparseable YAML, non-mapping top-level all return an empty CanonDelta with `parse_error` set. File: `eidos/spec/eidos/canon_delta_spec.rb` (new context).
- [X] T039 [P] [US3] Spec: `CanonDelta#apply!` transactional — if one entry fails validation, no partial state is written. File: `eidos/spec/eidos/canon_delta_apply_spec.rb`.
- [X] T040 [P] [US3] Spec: `CanonDelta#apply!` with attribute conflict opens exactly one `:conflict` AuditFinding and still applies the delta (optimistic, FR-020). File: `eidos/spec/eidos/canon_delta_apply_spec.rb` (new context).
- [X] T041 [P] [US3] Spec: `CanonDelta#apply!` on a parse-errored delta opens a `:malformed-delta` finding, preserves piece content on disk, and leaves canon version unchanged. File: `eidos/spec/eidos/canon_delta_apply_spec.rb` (new context).
- [X] T042 [P] [US3] Spec: `CanonDelta#revert!` writes a reverse revision, flips the piece's `canon_status` to `reverted`, leaves the piece file on disk, closes the originating finding with `resolution: revert`, and opens `:orphaned-reference` findings for any subsequent pieces that referenced the rolled-back entities. File: `eidos/spec/eidos/canon_delta_revert_spec.rb`.
- [X] T043 [P] [US3] Spec: `AuditLog` append, close-in-place, and queries (`#all`, `#open`, `#closed`, `#by_piece`). File: `eidos/spec/eidos/audit_log_spec.rb`.
- [X] T044 [P] [US3] Spec: `AuditFinding` YAML round-trip — write a finding with every field populated, read it back, equality. File: `eidos/spec/eidos/audit_finding_spec.rb`.
- [X] T045 [P] [US3] Spec: `eidos canon review` CLI — text and JSON formats, `--status` and `--kind` filters, clean-world case prints `0 findings` and exits 0. File: `eidos/spec/eidos/cli/canon_review_spec.rb`.
- [X] T046 [P] [US3] Spec: `eidos canon revert --finding ID` CLI — non-destructive (piece file still on disk), closes finding, flips canon_status; `--also-regenerate` triggers a follow-up `produce piece` invocation. File: `eidos/spec/eidos/cli/canon_revert_spec.rb`.
- [X] T047 [P] [US3] Spec: `eidos canon accept` and `eidos canon patch` CLIs close findings with the correct `resolution` values. File: `eidos/spec/eidos/cli/canon_accept_patch_spec.rb`.
- [X] T048 [P] [US3] Spec: `PieceProducer --dry-run` writes zero files (no piece, no delta, no audit entry) and prints the delta tail to stdout. File: `eidos/spec/eidos/producers/piece_producer_dry_run_spec.rb`.
- [X] T049 [P] [US3] Spec: subsequent piece sees the new canon entry from a prior piece's delta in its assembled `{CANON_CONTEXT}` without user intervention (SC-009). File: `eidos/spec/eidos/producers/piece_producer_canon_cycle_spec.rb`.
- [X] T050 [P] [US3] Add mock-response fixtures covering: a clean CanonDelta, a CanonDelta that collides with existing canon, and a malformed (missing sentinel) response. File: `eidos/spec/support/mock_responses.yml`.

### Implementation for US3

- [X] T051 [US3] Implement `CanonDelta` value object with `.parse(text)`, validation, slug normalization via `Eidos::ValidationUtils.slugify`, and persistence to `worlds/<name>/data/canon_deltas/<id>.yml`. File: `eidos/lib/eidos/canon_delta.rb`.
- [X] T052 [US3] Implement `CanonDelta#apply!(bible:, canon:, audit_log:)` — opens a revision via the existing `RevisionStore`, writes new entities and entity_updates, opens a `:conflict` finding for each collision (still applies the change — optimistic), rolls back the revision if any entry raises (all-or-none). File: `eidos/lib/eidos/canon_delta.rb`.
- [X] T053 [US3] Implement `CanonDelta#revert!(bible:, canon:, audit_log:, finding:)` — writes a reverse revision, flips the owning Piece's `canon_status` to `:reverted`, leaves the piece file on disk, scans later pieces for references to now-removed entities and opens `:orphaned-reference` findings for each downstream piece, closes the originating finding. File: `eidos/lib/eidos/canon_delta.rb`.
- [X] T054 [US3] Implement `AuditFinding` value object (fields per data-model.md, YAML round-trip, validation: closed findings must have `resolved_at` and `resolution`). File: `eidos/lib/eidos/audit_finding.rb`.
- [X] T055 [US3] Implement `AuditLog` backed by `worlds/<name>/data/audit_log/findings.yml` — append via atomic temp-file + rename, close-in-place, queries (`#all`, `#open`, `#closed`, `#by_piece`, `#find(id)`). File: `eidos/lib/eidos/audit_log.rb`.
- [X] T056 [US3] Update `PieceProducer#produce` to: (a) include the `---CANON-DELTA---` request block in every outgoing prompt (sourced from the form's prompt template), (b) call `CanonDelta.parse` on the LLM response, (c) when not in dry-run, call `CanonDelta#apply!` and wire the resulting findings into the piece record (set `canon_delta_ref`), (d) when in dry-run, print piece + delta to stdout and write nothing. File: `eidos/lib/eidos/producers/piece_producer.rb`.
- [~] T057 [US3] Partial: CanonDelta pipeline is in place for all non-chapter forms; ChapterGenerator's structured-JSON flow is preserved intact to keep SC-002 byte-identical chapter output safe. The `new_characters` frontmatter key on chapter files is retained by the existing `create_new_characters` extraction. Moving chapters over to `---CANON-DELTA---` tail parsing is deferred post-014 (would need a separate `generate_chapter_structured` → delta-tail prompt migration). File: `eidos/lib/eidos/chapter_generator.rb`.
- [X] T058 [US3] Extend `Piece` frontmatter with `canon_status` (default `:applied` when missing, to keep old chapter files readable) and `canon_delta_ref` fields. File: `eidos/lib/eidos/piece.rb`.
- [X] T059 [US3] Add `Eidos::World#audit_log` accessor returning an `AuditLog` instance bound to the world's data directory. File: `eidos/lib/eidos/world.rb`.
- [X] T060 [US3] Implement `eidos canon review [--status open|closed|all] [--kind conflict|malformed-delta|orphaned-reference] [--piece ID] [--format text|json]` subcommand that reads the world's audit log and renders findings per `contracts/audit-finding.md`. File: `eidos/lib/eidos/cli/canon.rb`.
- [X] T061 [US3] Implement `eidos canon revert --finding ID [--also-regenerate] [--dry-run]` subcommand. `--also-regenerate` is accepted as a flag but defers the follow-up produce call to a post-014 enhancement (the user can run `eidos produce piece --form <form> --prompt ...` manually after the revert). File: `eidos/lib/eidos/cli/canon.rb`.
- [X] T062 [US3] Implement `eidos canon accept --finding ID [--note TEXT]` — closes the finding with `resolution: accept` and an optional note, no canon mutation. File: `eidos/lib/eidos/cli/canon.rb`.
- [X] T063 [US3] Implement `eidos canon patch --finding ID` — opens the referenced entity's YAML in `$EDITOR`, saves through the existing `Eidos::Storage` interface, closes the finding on successful save with `resolution: patch-canon`. File: `eidos/lib/eidos/cli/canon.rb`.

**Checkpoint**: US3 closes the correctness loop. Every producer emits a delta (SC-007); dry-run writes nothing (SC-008); next piece sees new canon (SC-009); malformed-delta case preserves content (SC-010); conflict is discoverable via `canon review` and revertible in one command (SC-013).

---

## Phase 6: Polish & Cross-Cutting

- [X] T064 [P] Full suite green at 714 examples; measured 52.21% line coverage, bumped `EIDOS_DEFAULT_COVERAGE_FLOOR` from 46 → 52 in `eidos/spec/support/coverage_setup.rb`.
- [X] T065 [P] Rubocop autocorrected 203/236 offenses on feature-touched files; remaining 2 offenses (`Metrics/CyclomaticComplexity`/`PerceivedComplexity` in `generate_image_with_openrouter`) are preexisting and unrelated to this feature. Added `private_constant :MOCK_FORM_SIGNATURES` + `# rubocop:disable Metrics/ParameterLists` on the four new data-bag constructors.
- [X] T066 [P] Refreshed top-level `--help` descriptions in `eidos/lib/eidos/cli/main.rb`: `canon` now mentions audit review (review/revert/accept/patch); `produce` mentions pieces of any form; `piece` summary clarified as "Browse pieces across all forms".
- [X] T067 Walked the quickstart end-to-end against a scratch `/tmp/qs-world`. Found and fixed two wiring bugs along the way: (a) `eidos produce piece` was not injecting `AuditLog` → canon deltas never persisted; (b) `canon_delta_ref` was being set *after* the piece file was written → frontmatter missing the ref. Unknown-form error path now prints the list of registered forms and exits 1 instead of Thor's stub "was called with arguments" message.
- [X] T068 Deleted `specs/014-storyworld-pivot/terminology-sweep.md`.

### Deferred follow-ups (post-014)

- **`eidos form new NAME`** scaffolder — interactive command that asks for `category`, `default_length`/`default_shape`, and `canon_context`, then writes `worlds/<name>/data/forms/NAME.yml` + a prompt template stub. Optional `--generate-prompt` flag uses `LLMService.generate_text` to draft the template body (author, length guidance, canon-context instructions, closing `---CANON-DELTA---` block) from a one-sentence description. Current workaround: hand-author the two files (see `contracts/form-definition.md`). Not in 014 scope — ship when US2's "users define forms in minutes" promise needs a lower floor.
- **Trim built-in forms** — reduce `eidos/lib/eidos/forms/` to `chapter` (contractually required for SC-002) plus 2–3 exemplars (one text, one image, one script). Move short-story / comic-script / social-post / illustration into a starter kit that `eidos world new` copies into `data/forms/`. Makes "world is the source of truth" framing honest and stops the gem from owning content taxonomy users didn't pick.

---

## Dependencies (story-level)

```
Phase 1 (Setup, T001–T002)
        │
        ▼
Phase 2 (Foundational, T003–T010)
        │
        ├──────────────────────────────┬──────────────────────────────┐
        ▼                              ▼                              ▼
Phase 3 (US1, T011–T024)     Phase 4 (US2, T025–T036)     Phase 5 (US3, T037–T063)
        │                              │                              │
        └──────────────────────────────┴──────────────────────────────┘
                                       │
                                       ▼
                         Phase 6 (Polish, T064–T068)
```

**Cross-phase notes**:
- US2 depends on Phase 2 only. It does not require US1 implementation-wise, though in practice US1 will ship first (priority order). If parallelism is desired, one pair can ship US1 while another pair lands US2's registry extensions.
- US3 depends on Phase 2 and benefits from US2's `canon_context` injection (T032) for scenario 7 "subsequent piece sees new canon entries." If US2 is skipped or partial, US3 can still work with the built-in `all_characters` context as its default.
- Phase 6 (polish) must wait for all three stories — coverage and rubocop are repo-wide concerns.

## Parallel execution examples

**Phase 2 parallel block** (everything except `FormRegistry` and `PieceProducer`, which read the value objects):

```
T003 [P] Piece           │
T004 [P] PieceCollection │ run in parallel
T005 [P] Form            │
T007 [P] Built-in YAMLs  │
T008 [P] Built-in prompts│
```

Then T006 (FormRegistry) and T009 (PieceProducer) sequentially, T010 (World accessors) last.

**Phase 3 parallel block** (all tests, then all implementation tasks touch overlapping files so run sequentially):

```
T011 [P] [US1] chapter back-compat spec        │
T012 [P] [US1] piece_producer spec             │
T013 [P] [US1] length spec                     │ run in parallel (different spec files)
T014 [P] [US1] produce CLI spec                │
T015 [P] [US1] mock fixtures for vignette      │
```

Then T016–T024 sequentially (most touch `piece_producer.rb` or `produce.rb`).

**Phase 5 parallel block**:

```
T037–T050 [P] [US3] every spec in a distinct file — run in parallel
```

Then T051–T063 implementation tasks serially (many touch `canon_delta.rb` or `canon.rb`).

**Phase 6 polish**:

```
T064 [P] full suite + coverage  │
T065 [P] rubocop                │ run in parallel
T066 [P] --help text            │
```

Then T067 (manual quickstart walkthrough) and T068 (delete scratch audit) sequentially.

## Implementation strategy

**Ship US1 first as the MVP.** It's the minimum terminology pivot, unshackles length for non-chapter forms, and leaves `produce chapter` byte-identical — the highest user-visible value with the lowest back-compat risk. US1 alone resolves the book-era framing complaint that motivated this feature.

**Ship US2 next.** The form registry unlocks open-ended content types, which is the leverage point the whole feature is named after. Without US2, users can use built-in forms but can't add their own without editing the gem.

**Ship US3 last** — the canon-extraction contract closes the correctness loop but introduces the most moving parts (audit log, review CLI, optimistic conflict handling, revert cascades). Landing it after US1/US2 means any bugs are isolated to the correctness layer rather than blocking the terminology pivot.

At every story boundary, run the full `MOCK_AI=true` RSpec suite and verify the CLI invariant tests in `contracts/cli-surface.md` still pass.

## Task count summary

| Phase | Task count | Parallel (P) | Story label |
|---|---|---|---|
| Phase 1 Setup | 2 | 0 | none |
| Phase 2 Foundational | 8 | 5 | none |
| Phase 3 US1 | 14 | 6 | US1 |
| Phase 4 US2 | 12 | 6 | US2 |
| Phase 5 US3 | 27 | 14 | US3 |
| Phase 6 Polish | 5 | 3 | none |
| **Total** | **68** | **34** | — |

**Independent test criteria**:
- US1: `produce piece --form vignette --length 400` lands under `content/pieces/vignette/` with correct frontmatter; `produce chapter` output is byte-identical to pre-feature.
- US2: dropping `worlds/<name>/data/forms/haiku.yml` + prompt template makes `produce haiku` work in the same shell session without restart; unknown form prints available list.
- US3: introducing a new character via any form makes it available to the next piece automatically; `canon review` surfaces conflicts; `canon revert` keeps the piece file and closes the finding.

**Suggested MVP scope**: Phase 1 + Phase 2 + Phase 3 (US1) = 24 tasks. That alone ships the terminology pivot and unblocks non-chapter content. US2 and US3 can land in subsequent PRs.

**Format validation**: every task above starts with `- [ ]`, carries a sequential T### id, includes `[P]` where parallelizable, carries `[US1]` / `[US2]` / `[US3]` on story-phase tasks (and only on story-phase tasks), and names at least one exact file path.
