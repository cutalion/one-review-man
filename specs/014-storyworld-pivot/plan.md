# Implementation Plan: IP-Generator Pivot — Pieces, Forms, and Canon Feedback

**Branch**: `014-storyworld-pivot` | **Date**: 2026-04-18 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/home/cutalion/code/one-review-man/specs/014-storyworld-pivot/spec.md`

## Summary

Pivot Eidos from book-generator framing to IP-management system. Every generated artifact becomes a **Piece** with a declared **Form**; the world-wide `chapter_length_target` stops acting as a universal floor; forms are pluggable via per-world YAML files; every producer emits a structured **Canon Delta**; deltas apply **optimistically** to canon and an on-demand `canon review` surfaces **Audit Findings** (conflicts, malformed deltas, orphaned references) with non-destructive remediation (revert keeps the piece file, marks `canon_status: reverted`).

Technical approach: extend the existing Eidos gem in place. Introduce a generic `PieceProducer` behind a `FormRegistry` (built-ins under `eidos/lib/eidos/forms/`, world-local overrides under `worlds/<name>/data/forms/*.yml`). Reuse existing canon primitives (RevisionStore, SnapshotStore, BranchManager, DiffEngine) — no new versioning mechanism. `ChapterGenerator` is refactored to delegate to `PieceProducer` via a `chapter` form while preserving its public API and output shape. Audit log is a new per-world YAML store at `worlds/<name>/data/audit_log/`. Canon Delta is already implicit today (ChapterGenerator's "new characters" handling); this feature promotes it to a first-class record.

## Technical Context

**Language/Version**: Ruby 3.3.5, `# frozen_string_literal: true` on every file
**Primary Dependencies**: Thor ~> 1.3 (CLI), ruby-openai ~> 7.3 (LLM), tty-prompt ~> 0.23, tty-spinner ~> 0.9, rainbow ~> 3.1, dotenv ~> 3.1, YAML (stdlib). No new runtime gems required.
**Storage**: YAML files under `worlds/<name>/data/` (story bible, audit log, custom forms) and `worlds/<name>/content/` (piece files). Pluggable via `Eidos::Storage` backends (`:yaml_file` default, `:memory` for tests). Reuses existing RevisionStore / SnapshotStore primitives for canon versioning. No schema migration for existing worlds.
**Testing**: RSpec with `MOCK_AI=true` default. SimpleCov line-coverage floor enforced on full-suite runs (currently 47.15%). Prompt-assertion harness catches unfilled/unused placeholders at mock-call time.
**Target Platform**: Linux/macOS CLI via unified `eidos` binary (`eidos/exe/eidos`) plus legacy domain binaries under `eidos/bin/`. Ruby SDK is consumed in-process by CLI and directly by Ruby scripts.
**Project Type**: Ruby gem with CLI + SDK layers, monorepo with one world (`worlds/one-review-man`) and a generated Jekyll site (`site/`). See Structure Decision below.
**Performance Goals**: No regression on existing chapter-production latency. `canon review` on-demand scan MUST return in under 2 seconds on a world with ≤ 1000 audit findings (read-only YAML load + print). Optimistic delta apply adds no measurable latency vs. today's chapter flow.
**Constraints**: `MOCK_AI=true` keeps the full test suite offline and deterministic. No storage-schema change beyond piece records, canon-delta records, and audit-log entries (FR-025). Byte-identical chapter output shape vs. pre-feature (SC-002). Zero silent data loss on malformed delta responses (SC-010). Per-world state only — no user-global or repo-global form catalog in MVP.
**Scale/Scope**: Target worlds: small (one-review-man has ~16 chapters today, ~30–50 pieces anticipated mid-term). Form registry: 7 built-in forms shipped (chapter, haiku, vignette, short-story, comic-script, portrait, social-post, illustration — note spec lists 8 including illustration). Audit log: hundreds of findings at most. Custom forms per world: typically < 10. No horizontal scale concerns; this is a single-user CLI tool.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Evaluated against constitution v2.0.1.

| # | Principle | Status | Notes |
|---|---|---|---|
| I | Test-First with Mock AI | PASS | All new classes (FormRegistry, PieceProducer, AuditLog, CanonDelta, AuditFinding) will ship with RSpec covering `MOCK_AI=true` paths. New mock-response fixtures added to `spec/support/mock_responses.yml` for haiku/vignette/portrait forms. Prompt-assertion harness already guards every mock LLM call. |
| II | Producer Contract | PASS | `PieceProducer` formalizes the (IP version, product description, output location) triple that today's `ChapterGenerator` implements implicitly. `ChapterGenerator` is preserved as a thin wrapper for back-compat (FR-002, SC-002). New CLI paths (`produce piece --form <name>`, short `produce <name>`) go through the same `eidos/exe/eidos` Thor router. `--world-dir` / `-w` flag remains supported. |
| III | Dependency Injection | PASS | `PieceProducer` accepts `llm_service:`, `form_registry:`, `bible:`, `canon:`, `audit_log:`, `output_adapter:`, `prompt_provider:` via keyword args. `FormRegistry` accepts `builtin_loader:` and `world_loader:`. `AuditLog` accepts a `storage_backend:`. No hard-coded service instantiation inside business logic. |
| IV | Canon Integrity with Versioned IP | STRENGTHENS | This feature advances the principle: FR-024 mandates every piece cite its canon version and every applied delta bump it. Optimistic apply + `canon review` + non-destructive revert preserve lineage through the existing RevisionStore. The Sync Impact Report follow-up TODO (v2.0.1) flagged a possible future MINOR amendment to codify the canon-feedback obligation; this plan implements the behavior; the constitution amendment itself is separate work and not blocking. |
| V | Security by Default | PASS | No new secrets introduced. Audit log stores no credentials. Debug artifacts (`tmp/ai_debug/`) remain gitignored. `--debug` flag unchanged. |
| VI | Pluggable AI Services with Evals | PASS | No new AI services added. Prompt templates are new but pass through the existing `LLMService` and `PromptProvider`. The Future Work items (LLM-assisted divergence / hallucination detection) would introduce new AI usage requiring eval suites; those are explicitly deferred. |
| VII | Separation of Concerns: Engine / Producers / Publishing | PASS | `FormRegistry`, `PieceProducer`, `CanonDelta`, `AuditFinding`, `AuditLog` live under `eidos/lib/eidos/` (Producers + Engine-adjacent layers). Jekyll / publishing layer is untouched; non-chapter pieces are written to `worlds/<name>/content/pieces/<form>/` and are not consumed by the current Jekyll theme in this feature. Cross-layer dependencies still flow downward. |

**Gate result: PASS.** No violations to track in Complexity Tracking.

**Post-design re-check (after Phase 1)**: All seven principles still PASS with the data model and contracts drafted. Principle IV is actively strengthened (see `contracts/canon-delta.md` revert semantics — reverse revisions through the existing `RevisionStore`, not in-place history mutation). Principle I is tightened by the ten RSpec invariants listed in `contracts/cli-surface.md` ("CLI invariant tests"). No new gate violations introduced by the design.

## Project Structure

### Documentation (this feature)

```text
specs/014-storyworld-pivot/
├── plan.md              # This file (/speckit.plan output)
├── spec.md              # Feature spec (with Clarifications)
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
│   ├── cli-surface.md           # New CLI commands + flag contracts
│   ├── form-definition.md       # YAML schema for custom forms
│   ├── canon-delta.md           # LLM-facing delta record structure
│   └── audit-finding.md         # Audit log entry schema
├── checklists/
│   └── requirements.md  # Already present
└── tasks.md             # /speckit.tasks output (not created here)
```

### Source Code (repository root)

Single-project layout (existing monorepo). No new top-level directories; this feature extends the Eidos gem in place.

```text
eidos/
├── lib/eidos/
│   ├── piece.rb                      # NEW  — Piece SDK value object
│   ├── piece_collection.rb           # NEW  — world.pieces, filterable by form
│   ├── form.rb                       # NEW  — Form value object
│   ├── form_registry.rb              # NEW  — built-ins + world-local discovery
│   ├── canon_delta.rb                # NEW  — delta record value + parse/apply
│   ├── audit_finding.rb              # NEW  — AuditFinding value object
│   ├── audit_log.rb                  # NEW  — per-world YAML store
│   ├── producers/
│   │   ├── piece_producer.rb         # NEW  — generic producer
│   │   └── chapter_producer.rb       # EXISTS — refactored to delegate to PieceProducer
│   ├── forms/                        # NEW  — built-in form definitions (YAML)
│   │   ├── chapter.yml
│   │   ├── haiku.yml
│   │   ├── vignette.yml
│   │   ├── short_story.yml
│   │   ├── comic_script.yml
│   │   ├── portrait.yml
│   │   ├── social_post.yml
│   │   └── illustration.yml
│   ├── prompts/
│   │   └── PLACEHOLDERS_REFERENCE.md # UPDATED  — BOOK→STORY drift + piece terms
│   ├── cli/
│   │   ├── produce.rb                # UPDATED — add `piece` + short <form> dispatch
│   │   ├── canon.rb                  # UPDATED — add `review` + `revert` subcommands
│   │   └── piece_cli.rb              # NEW  — eidos piece list/show (SDK-based)
│   ├── chapter_generator.rb          # UPDATED — delegate to PieceProducer
│   └── world.rb                      # UPDATED — add #pieces, #forms, #audit_log
├── exe/eidos                         # UNCHANGED — Thor router still entrypoint
├── bin/produce                       # UNCHANGED (shim)
├── bin/canon                         # UNCHANGED (shim)
└── spec/
    ├── eidos/
    │   ├── piece_producer_spec.rb
    │   ├── form_registry_spec.rb
    │   ├── canon_delta_spec.rb
    │   ├── audit_log_spec.rb
    │   ├── audit_finding_spec.rb
    │   ├── piece_spec.rb
    │   ├── cli/
    │   │   ├── produce_spec.rb
    │   │   ├── canon_review_spec.rb
    │   │   └── piece_cli_spec.rb
    │   └── producers/
    │       └── chapter_producer_back_compat_spec.rb
    └── support/
        └── mock_responses.yml        # UPDATED — new form fixtures

worlds/one-review-man/
├── data/
│   ├── forms/                        # NEW (optional, empty by default)
│   ├── audit_log/                    # NEW (created on first finding)
│   └── story_bible/                  # UNCHANGED
└── content/
    ├── chapters/                     # UNCHANGED (chapter pieces still land here)
    └── pieces/                       # NEW
        ├── haiku/
        ├── vignette/
        ├── portrait/
        └── ...
```

**Structure Decision**: Extend the existing Eidos gem (single-project layout). All new engine/SDK code lives under `eidos/lib/eidos/`; all new CLI dispatch under `eidos/lib/eidos/cli/`. Per-world state (custom forms, audit log, non-chapter pieces) lives under `worlds/<name>/`. No new top-level directories. ChapterGenerator's public API and output shape are preserved (FR-002) by making it a thin adapter over the new `PieceProducer`.

## Complexity Tracking

No constitutional violations; nothing to justify.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| — | — | — |
