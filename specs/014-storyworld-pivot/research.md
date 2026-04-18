# Phase 0 Research: IP-Generator Pivot

**Feature**: 014-storyworld-pivot
**Date**: 2026-04-18

## Scope

All three clarification questions were resolved in the spec's Clarifications session (2026-04-18). No `NEEDS CLARIFICATION` markers remain in plan.md. This research.md records the design decisions that still deserve an explicit rationale — form-registry discovery, canon-delta extraction, audit-log storage, chapter back-compat strategy, and the test coverage floor impact.

---

## Decision 1: Form registry — filesystem-based discovery, world-local overrides win

**Decision**: Ship built-in forms as YAML files under `eidos/lib/eidos/forms/*.yml`. On every CLI invocation, `FormRegistry` loads built-ins plus any YAML files under `worlds/<name>/data/forms/*.yml`. World-local forms override built-ins on name collision; the CLI prints a one-line notice on invocation when an override is used.

**Rationale**:
- Matches Principle VII (Separation of Concerns) — forms are producer-layer data, not engine logic.
- Matches Assumption "custom form templates are per-world" and FR-009/FR-011 (no gem rebuild for new forms).
- YAML aligns with every other per-world data file (settings.yml, story_bible/*.yml). No new serialization format.
- Per-invocation load is cheap (small YAML files, ~10 of them max per world) and avoids caching bugs.

**Alternatives considered**:
- *Ruby DSL form definitions* — rejected: forces users to edit Ruby to add a form, violates FR-009 spirit.
- *JSON form defs* — rejected: YAML is already the project's convention; consistency over variety.
- *Single `forms.yml` aggregating all forms* — rejected: file-per-form scales cleanly, makes diffs readable, and matches how story_bible/characters/*.yml is organized.

## Decision 2: Canon delta extraction — structured tail-of-response contract

**Decision**: Every form's prompt template ends with an instruction block requesting a delimited canon-delta section in a fixed shape (YAML block after a sentinel line, e.g. `---CANON-DELTA---` followed by a YAML document). `CanonDelta.parse(response_text)` splits on the sentinel, parses the YAML, and validates against a small schema (characters/locations/facts/events/relationships/updates keys, each a list). On parse failure, `CanonDelta.empty_with_error(reason)` returns a zero-delta record and the producer writes an `:malformed-delta` audit finding (FR-022).

**Rationale**:
- Today's ChapterGenerator already extracts new characters from the generated text using a dedicated parse step; this generalizes that approach to every form.
- Sentinel-delimited YAML block is the simplest structure that survives whitespace variance from the model. It's easy for humans to read in debug output and easy to parse deterministically.
- Keeping the delta section at the tail of the response lets forms that don't care about canon (e.g. pure illustration prompts) emit an empty block trivially.
- Separate structured section avoids re-parsing narrative prose for extraction, which is brittle and hard to test.

**Alternatives considered**:
- *Function-calling / JSON-mode LLM API* — rejected for MVP: locks us to providers that support it; project already uses provider-agnostic text completion and has MOCK_AI fixtures to maintain.
- *Second LLM pass to extract deltas* — rejected for MVP: doubles token cost, complicates MOCK_AI, introduces eval-suite obligation per Principle VI.
- *Regex extraction of character mentions from prose* — rejected: current chapter-only approach is fragile; generalizing it across forms would amplify the fragility.

## Decision 3: Audit log — append-only per-world YAML with closed-item retention

**Decision**: `AuditLog` stores findings in `worlds/<name>/data/audit_log/findings.yml` as a YAML array of records. Each record has an id (ULID-style), kind, status, originating_piece_id, canon_version_before, canon_version_after, explanation, created_at, resolved_at (nullable), resolution (nullable). Closed findings are kept in place with `status: closed` rather than being removed, to preserve provenance (FR-030). `AuditLog.append(finding)` locks the file during write. Backend is pluggable via the existing `Eidos::Storage` abstraction (`:yaml_file` default, `:memory` for tests).

**Rationale**:
- Per-world state per Assumption "Canon-review audit log is per-world."
- Append-only with retention matches FR-030 (closed findings remain queryable).
- Single file per world keeps the directory clean; file is small (hundreds of entries at most per the scale target).
- Storage abstraction reuses what was built in feature 010; no new backend.

**Alternatives considered**:
- *One file per finding* — rejected: unnecessary fanout for hundreds of entries; harder to query / list.
- *SQLite* — rejected: introduces a new dependency and violates "reuse existing primitives."
- *In-bible `audit` section* — rejected: conflates canon state with audit metadata; the audit log should survive snapshots and branches independently of canon content.

## Decision 4: Chapter back-compat — wrapper, not rename

**Decision**: `ChapterGenerator` keeps its current public method signature and output shape. Internally it constructs a `PieceProducer` with the built-in `chapter` form and delegates. The existing `eidos produce chapter` CLI keeps its current flags and writes to `worlds/<name>/content/chapters/` with the same frontmatter keys. A byte-identical-shape test (SC-002) locks this in.

**Rationale**:
- Principle II (Producer Contract) is satisfied — chapters move onto the generic contract.
- FR-002 / FR-026 / SC-002 require zero behavioral change for existing workflows; wrapping is the lowest-risk path.
- Keeps the diff reviewable: the chapter file layout, the chapter frontmatter, and the `produce chapter` command all stay exactly where they are.

**Alternatives considered**:
- *Deprecate ChapterGenerator and replace with PieceProducer everywhere* — rejected for MVP: larger blast radius, harder rollback, violates the "no breaking changes" spec constraint.
- *Route chapter through the generic path with a new `--form chapter` default* — rejected as user-facing change: users typing `produce chapter` today should see exactly the same behavior.

## Decision 5: Optimistic apply — canon delta goes through existing RevisionStore

**Decision**: Each applied Canon Delta is translated into one or more revisions written to the existing `RevisionStore` (same primitive used by today's new-character insertion). The piece record cites the resulting canon version. Revert in `canon review` creates a *new* reverse revision rather than mutating history — canon lineage stays append-only. Piece record's `canon_status` flips to `reverted` but the piece file on disk is untouched (Q2 answer).

**Rationale**:
- Reuses Principle IV infrastructure. No new versioning mechanism.
- Append-only history means revert is auditable: the reverse revision shows exactly what was undone and when.
- Non-destructive piece file (Q2) matches SC-010 (zero silent data loss).
- Revert semantics naturally support the cascade-revert edge case because the reverse revision can itself be reverted if the user later changes their mind.

**Alternatives considered**:
- *Mutate revisions in place on revert* — rejected: breaks history integrity, makes audit meaningless.
- *Snapshot before each delta apply* — rejected: unnecessary fanout for small deltas; snapshots remain user-driven (via `canon snapshot` CLI).

## Decision 6: Test coverage — raise the floor only if coverage rises, never lower

**Decision**: Run `bundle exec rspec` (full suite, MOCK_AI=true) at the end of every story and record the new SimpleCov line-coverage number. The committed floor `EIDOS_COVERAGE_FLOOR` in `eidos/spec/support/coverage_setup.rb` is raised to match the new number only if it grew and stayed above the current 47.15%. If a change would drop coverage below the floor, investigate the drop before committing. Single-file runs remain exempt.

**Rationale**:
- The coverage-floor convention was introduced by feature 013 to prevent silent erosion; a multi-story feature is exactly when erosion is most likely. Treating the floor as a one-way ratchet matches the intent.

**Alternatives considered**:
- *Ignore coverage for this feature* — rejected: violates Principle I's spirit.
- *Temporarily lower the floor while stories are in flight* — rejected: documented anti-pattern in `specs/013-spec-coverage-backfill/quickstart.md`.

## Decision 7: MOCK_AI fixtures — one fixture per new form, plus delta variants

**Decision**: Add one mock response per new built-in form (haiku, vignette, short-story, comic-script, portrait, social-post, illustration) to `spec/support/mock_responses.yml`. Each fixture includes the expected delta tail block. Add two failure-mode fixtures: `malformed_delta_missing_sentinel` and `malformed_delta_bad_yaml` to exercise FR-022. The existing `mock_chapter_*` fixtures are preserved unchanged to guarantee back-compat.

**Rationale**:
- Principle I requires `MOCK_AI=true` covers new code; new forms → new fixtures is one-to-one.
- Malformed-delta fixtures are the only way to test the zero-data-loss promise (SC-010) without live API flakiness.
- Keeping existing fixtures intact is part of the byte-identical-shape guarantee (SC-002).

**Alternatives considered**:
- *Generate fixtures dynamically in specs* — rejected: defeats the purpose of mock responses as a versioned ground truth.

---

## Open items (tracked but not blocking this plan)

- **Constitution MINOR amendment to codify canon-feedback obligation** — flagged in the v2.0.1 Sync Impact Report as future work. This plan *implements* the behavior; the constitutional text change is separate.
- **Future Work / Deferred Review Capabilities** — section in spec.md lists orphaned-ref proactive scan, duplicate-entity heuristic, shape-drift detection, LLM-assisted semantic divergence, LLM-assisted hallucination detection, background/watch mode, severity taxonomy, cross-world review. None are in MVP.
