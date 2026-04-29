# Phase 0 Research: Unify the chapter producer + add a global canon revision counter

**Feature**: 018-unify-piece-producer
**Date**: 2026-04-29
**Status**: Resolved — no `NEEDS CLARIFICATION` markers remain

The two architectural forks (Q1: chapter id strategy; Q2: existing-world migration) were resolved during `/speckit.clarify`. This document captures the implementation-design decisions that fall out of those answers, plus the codebase grep findings that ground them.

---

## Codebase grep findings (the empirical baseline)

- `Eidos::ChapterGenerator` (at `eidos/lib/eidos/chapter_generator.rb`) is the legacy class. It owns: `generate_next_chapter`, `generate_chapter_structured` (the title/summary/new_characters JSON contract), `build_chapter_prompt`, `load_chapter_template`, `write_chapter_file`, `update_book_progress`, `determine_next_chapter_number`, `resolve_canon_version`. Roughly 370 lines.
- Direct callers: `eidos/lib/eidos/cli/produce.rb:362` (the `produce chapter` Thor action) and `eidos/lib/eidos/producers/chapter_producer.rb:76` (a thin wrapper class). Plus `eidos/spec/chapter_generation_spec.rb` and several other chapter-named specs.
- `Eidos::Producers::ChapterProducer` (at `eidos/lib/eidos/producers/chapter_producer.rb`) is the registered producer for the `chapter` form via `Producer.register(:chapter, ChapterProducer)` at line 99 of that file. It is a thin wrapper that instantiates a `ChapterGenerator` and adapts to the producer registry's interface.
- `Eidos::Producers::PieceProducer` (at `eidos/lib/eidos/producers/piece_producer.rb`) is the unified producer used by every other form. Public entry: `produce(form:, prompt:, length:, dry_run:)`. Internal hooks: `apply_delta`, `current_canon_version` (currently returns the literal `'unversioned'` when no snapshot is anchored — line 217), `next_chapter_id` (line 204 — already chapter-aware!), `generate_ulid` (line 212 — the hash-id generator), `split_delta` (line 164 — parses a body+delta envelope from the LLM output).
- `Eidos::CanonDelta#apply!` (at `eidos/lib/eidos/canon_delta.rb:205`) takes `bible:`, `audit_log:`, `canon_version_before:`, `canon_version_after:`, `piece_id:`, `world_path:`. The `canon_version_before/after` parameters are *already threaded* through the apply path — they're just consistently set to `'unversioned'` today by callers, because there's no actual revision counter to read from. After 018a, the integer values populate them.
- `data/world_state.yml` for the existing `worlds/one-review-man` world has top-level keys `world` and `status`. No `canon` key. Adding a top-level `canon` mapping with `revision: <N>` is a clean addition.
- `eidos world status` output is rendered by `render_status_report` in `eidos/lib/eidos/cli/helpers.rb:71`. It calls `show_basic_info`, `enumerate_pieces_by_form`, `show_configuration_status`, `show_file_structure_status`. None of these read `world_state.yml` today; they read `world_config.yml` for title/author and walk the filesystem for piece counts.
- `eidos produce write` is a Thor method at `eidos/lib/eidos/cli/produce.rb:373` (`def write(chapter = nil)`), declared with `desc 'write [CHAPTER]', 'Agent-based chapter writing (experimental)'` at line 369.
- Existing chapter-related specs: `chapter_generation_spec.rb`, `eidos/chapter_generator_spec.rb`, `eidos/producers/chapter_producer_spec.rb`, `eidos/producers/chapter_producer_back_compat_spec.rb`, `integration/chapter_number_regression_spec.rb`, `integration/produce_chapter_prompt_flag_spec.rb`. The first four exercise classes that 018a deletes; the last two exercise integration paths that 018a migrates.

---

## D-001 — How to fold chapter's structured-output contract into `PieceProducer`

**Decision**: extend `PieceProducer` with a per-form **structured-output dispatch**. Add a `structured_output: true` flag to the `chapter` form's YAML definition (or to the `Form` class as a recognized field). Inside `PieceProducer#produce`, after the LLM returns the body+delta envelope, branch on whether the form has `structured_output` set: if yes, parse the body as a JSON envelope (`{title, summary, new_characters, body}`) and write those fields into the piece's frontmatter; if no, treat the body as a single blob (current behavior). Other forms keep their current single-body behavior.

**Rationale**:
- Preserves Constitution Principle II (Producer Contract): one producer path, one entry point, one canon-delta-write contract. Different forms can have different *output shapes* without needing different producer *classes*.
- Localizes the chapter-special-case to a single dispatch point (a few lines), not a 370-line companion class.
- Future forms that want structured output (e.g. an "interview" form with question/answer pairs, a "letter" form with date/recipient/body) can opt in via the same flag.

**Alternatives considered**:
- *Keep `ChapterGenerator` and have `PieceProducer` delegate to it for the chapter form.* Rejected: doesn't actually retire the legacy code, just hides it behind a redirect. SC-005 (`grep -r "ChapterGenerator" eidos/lib/` returns zero) would fail.
- *Parse all forms as structured JSON.* Rejected: most forms (haiku, vignette, social-post) don't have structured fields; forcing JSON adds parsing brittleness and overhead with no payoff.
- *Make every form's prompt template emit a structured envelope as a forcing function.* Rejected: this is a prompt-engineering change with downstream effects on every form's mock fixtures, and chapter is the only form that benefits today.

---

## D-002 — Where the revision counter lives and who owns its read/write

**Decision**: a new small class `Eidos::WorldState` at `eidos/lib/eidos/world_state.rb`. Public surface:

```ruby
class Eidos::WorldState
  def initialize(world_path:); end
  def current_revision; end                  # integer; runs migration if missing
  def advance_revision!; end                 # integer; atomic write + return new value
end
```

It encapsulates: reading `data/world_state.yml`, the in-place migration when `canon.revision` is missing (per FR-006: counts `data/canon_deltas/*.yml`, writes the result, logs one line), atomic increment-and-write, and the typed error path when migration cannot run (e.g. the `world_state.yml` file itself is missing — that means a corrupt world; raise).

**Rationale**:
- Single responsibility: one class, two methods. Easy to test.
- Constructor-injectable (Constitution Principle III). `CanonDelta#apply!` accepts `world_state:` defaulting to `WorldState.new(world_path:)`; tests pass an in-memory double.
- The migration code lives in *one* place, so when it's retired (FR-006a, in/after 018c), the deletion is mechanical.

**Alternatives considered**:
- *Fold into `WorldConfig`*. Rejected: `WorldConfig` is for static, user-authored configuration (genre, style, premise). The revision counter is dynamic state. Mixing them muddies both classes.
- *Fold into `Canon` (the SDK façade)*. Rejected: `CanonDelta#apply!` runs deep inside the engine, before the SDK is in scope. Pulling the SDK class into apply! would be a layering inversion.
- *Inline the YAML read/write in `CanonDelta#apply!` directly*. Rejected: tightly couples canon-delta application to world-state file mechanics; no place to hang the migration logic; harder to test.

---

## D-003 — Atomic apply: how to ensure bible mutation + revision counter increment succeed together

**Decision**: `CanonDelta#apply!` accepts a new `world_state:` injectable kwarg (defaulting to `WorldState.new(world_path: world_path)`). After all bible-mutating sub-operations succeed (just before the existing `@applied_at = Time.now.utc` stamp at approximately line 243 of `canon_delta.rb`), call `world_state.advance_revision!` *inside* the existing `begin/rescue` block that wraps the bible mutations. If the increment write fails, the `rescue StandardError => e` clause fires `rollback!(bible, applied_actions)` (which already exists) and re-raises. Both the bible mutations and the counter increment succeed together, or the existing rollback path undoes the bible mutations and the counter is never advanced.

**Rationale**:
- Constitution Principle IV (Canon Integrity with Versioned IP): the canon and the counter are the same versioned thing. They cannot diverge.
- Reuses the existing rollback path — no new error-handling surface.
- One call site (apply!) services every code path that mutates the canon: produce, revert (which calls apply! with an inverse delta), rollback (which writes a per-entity revision marker via apply! semantics).

**Alternatives considered**:
- *Increment first, then mutate*. Rejected: a mid-mutation failure leaves the counter ahead of the bible. That's harder to detect and harder to recover from than the inverse.
- *Delegate the increment to `PieceProducer` after `apply_delta` returns*. Rejected: `apply!` is also called from `canon revert` and `canon rollback`. Putting the increment in `PieceProducer` means duplicating it in those callers too — risks drift.
- *Add a separate `CanonOperation` orchestrator class that wraps apply! + advance!*. Rejected: over-engineering. apply! already has the rollback machinery; the increment is one line of well-placed code.

---

## D-004 — Chapter `id` generation

**Decision**: chapter uses the same hash-id strategy as other forms — call the existing `generate_ulid` method in `PieceProducer` (line 212). The chapter-specific `chapter_number` field is computed by the existing `next_chapter_id` method in `PieceProducer` (line 204), *renamed* to `next_chapter_number` (since it now produces a number, not an id, post-018a). The on-disk filename is derived from `chapter_number` in the writer: `format('%03d-chapter.md', chapter_number)`.

**Rationale**:
- Pinned by Q1 clarification: hash `id` for uniformity, `chapter_number` as a separate frontmatter field.
- The existing `next_chapter_id` method already implements "find max NNN under content/chapters/, return next" — we're keeping the logic and just relabeling its output.
- Filename derivation lives in `PieceProducer#target_path` (line 247) — small case-statement on the form.

**Alternatives considered**:
- *Numeric chapter id (e.g. `id: "001"`)*. Rejected by Q1.
- *Compute chapter_number lazily from filename position*. Rejected: filename should be derived from frontmatter, not the other way around. Otherwise renaming the file would silently change the chapter number.

---

## D-005 — Removal of `eidos produce write`

**Decision**: delete the Thor method `def write(chapter = nil)` at `produce.rb:373` along with its `desc/option` lines (369–372). Grep `eidos/lib/` for any agent-runner support code that *only* this command uses; if found, delete those too. Specs that exercise `produce write` are deleted, not migrated. The `UnknownCommandHelp` mixin already on `Eidos::CLI::Produce` will surface a friendly error for `eidos produce write` after the deletion.

**Rationale**:
- The command is documented as experimental ("Agent-based chapter writing (experimental)"). Experimental commands without clear graduation paths should be retired, not preserved as zombie code.
- Once chapter goes through `PieceProducer`, the agent-based path has no obvious audience: `produce piece --form chapter` covers the standard case, and any future agent-based writer would be a separate spec with its own user stories.
- Friendly unknown-command help is better than a stub command that says "removed in 018a" — Thor handles the error path, the Definition of Done has fewer moving parts.

**Alternatives considered**:
- *Keep `produce write` as a stub redirect to `produce piece --form chapter`*. Rejected: aliases without distinct behavior become maintenance burden. Users who used the old command can adapt; the unknown-command help points them at the alternatives.
- *Move the agent-based logic into `PieceProducer` as an opt-in mode*. Rejected: there's no concrete user story for it today. Adding it without a story violates the project's "don't design for hypothetical future requirements" rule.

---

## Risks and mitigations

- **Risk: silent fallback hazard around the FR-006 migration.** If `WorldState#current_revision` writes `0` when `data/canon_deltas/` doesn't exist (vs. exists-but-empty), it hides a corrupt-world condition. **Mitigation**: contract `world-state-migration.md` requires the directory to exist for migration to proceed; absence raises `Eidos::CorruptWorldError` with a message naming the missing path. Code review checklist item.
- **Risk: chapter form's structured-output parsing fails for malformed LLM JSON.** Today, `ChapterGenerator` has its own retry-and-error-prompt path. **Mitigation**: `PieceProducer`'s structured-output path uses the existing `MockLLMService` prompt-assertion harness for tests; for the live path, wrap parsing in the existing `handle_unfilled_placeholders` style retry (one attempt) or surface a parse-drop finding. Detail in `chapter-piece-parity.md`.
- **Risk: existing `chapter_number_regression_spec` covers behavior only `ChapterGenerator` exhibits.** **Mitigation**: read the spec carefully during migration; whatever invariants it asserts about chapter numbering must be preserved by the new `next_chapter_number` method.
- **Risk: the `Producer.register(:chapter, ChapterProducer)` registration affects code paths beyond `produce chapter`.** **Mitigation**: grep for `Producer.lookup`, `Producer.find`, etc. to confirm. If the registry is consulted by anything other than the deleted `produce chapter` Thor action, replace those lookups with direct `PieceProducer` instantiation.
