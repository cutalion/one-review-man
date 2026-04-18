# Implementation Plan: Scaffold Hardening

**Branch**: `015-scaffold-hardening` | **Date**: 2026-04-18 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/015-scaffold-hardening/spec.md`

## Summary

Fix the six Tier-1 defects 014 shipped (canon-delta silent drops, `apply_delta` non-persistence, `world new --quick` stdin corruption, world-metadata silent fallbacks, orphan scaffold dirs, chapter-centric status), add a user-scale integration test harness that asserts on disk artifacts, and document a silent-fallback ban so this class of bug stops reaching review.

**Technical approach**: Six focused, independently-shippable user stories implemented surface-then-substrate (US3 → US4 → US1 → US2 → US5 → US6). Two cross-cutting deliverables — a new `eidos/spec/integration/user_scale/` suite and a CLAUDE.md convention — run alongside. No new runtime gems. No schema migrations. Existing worlds stay untouched; all behavior changes land in new-world paths or in read-path presentation.

Implementation order matches the spec's "Why this priority" rationale: US3 first because every downstream integration test needs a non-corrupting non-interactive setup to build on; US1/US2 next because they restore the Storyworld's core invariant (piece → delta → bible); US4/US5/US6 ride on the now-trustworthy substrate.

## Technical Context

**Language/Version**: Ruby 3.3.5, `# frozen_string_literal: true` on every file
**Primary Dependencies**: Thor ~> 1.3 (CLI), ruby-openai ~> 7.3 (LLM), tty-prompt ~> 0.23 (interactive prompts only — non-interactive path bypasses), tty-spinner ~> 0.9, rainbow ~> 3.1, dotenv ~> 3.1, YAML (stdlib). **No new runtime gems.**
**Storage**: YAML files under `worlds/<name>/data/` (story bible, canon deltas, audit log, world config, strings, custom forms) and `worlds/<name>/content/` (piece files). Pluggable `Eidos::Storage` backends (`:yaml_file` default, `:memory` for tests).
**Testing**: RSpec (`MOCK_AI=true` default); SimpleCov with `EIDOS_COVERAGE_FLOOR` (currently 52%, expected to rise with new specs); prompt-assertion harness in `MockLLMService`; **new** `eidos/spec/integration/user_scale/` directory that shells `exe/eidos` end-to-end and asserts on disk artifacts.
**Target Platform**: Linux / macOS terminal. CLI tool — no GUI, no server.
**Project Type**: Single Ruby gem (`eidos`) exposing an engine, an SDK, and a Thor CLI. Existing monorepo layout, no structural change.
**Performance Goals**: CLI commands (non-LLM) complete in <3s user-perceptible. Unit suite under 30s locally; integration suite runs separately (opt-in, not in fast loop).
**Constraints**:
- **No new runtime gems.**
- **No schema migration** — `parse_error` already exists on the canon-delta document; population change only.
- **Backwards-compat** for `worlds/one-review-man` and any pre-014 world — scaffolding changes are new-world-only.
- **No breaking CLI flag changes** — new flags added, existing flags/subcommands preserved.
- **Coverage floor must not drop** — new code lands with covering specs; floor may rise post-merge.
**Scale/Scope**: Six user stories (3×P1, 2×P2, 1×P3); ~24 functional requirements; ~9 success criteria. Expected code touch: `Eidos::CLI::World` (US3), `Eidos::WorldConfig` / scaffold templates (US3, US5), canon-delta parsers (US1), `Eidos::PieceProducer`/apply path (US2), `Eidos::CLI::World#status` (US6). New files: integration harness, fuzz specs, research + data-model + quickstart.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Evaluating against `.specify/memory/constitution.md` v2.0.1 (seven core principles).

| # | Principle | Status | Notes |
|---|-----------|--------|-------|
| I | Test-First with Mock AI | ✅ PASS | Every US ships with RSpec coverage. Integration harness runs primarily under `MOCK_AI=true`; live-LLM mode is an opt-in for SC-007. Prompt-assertion harness remains enforced. |
| II | Producer Contract | ✅ PASS | No producer interface changes. Fixes land *inside* existing producers (canon-delta pipeline) or *around* them (CLI scaffold, CLI status). `--world-dir` / `-w` preserved. |
| III | Dependency Injection | ✅ PASS | US2's persistence fix almost certainly surfaces a collaborator-wiring bug (e.g. a non-persisting in-memory bible instance being injected where the on-disk one is needed). Fix follows DI discipline — no hard-coded `StoryBible.new` inside business logic. |
| IV | Canon Integrity with Versioned IP | ✅ PASS — **this feature defends it.** US1 makes drops visible in the audit trail; US2 restores the piece → delta → bible write path. SC-003 verifies bible contents on disk. No derivative-to-canon link is weakened. |
| V | Security by Default | ✅ PASS | No credential handling changes. Integration harness uses the same env-var contract as the rest of the project. |
| VI | Pluggable AI Services with Evals | ✅ PASS | If US4 adopts LLM inference for metadata, it goes through the existing `Eidos::LLMService` abstraction (no direct vendor SDK). New canon-delta fuzz specs (FR-024) act as parser evals — they assert failure surfaces, not silent drops. |
| VII | Separation of Concerns | ✅ PASS | Changes are layer-local: US1/US2 in Engine, US3/US4/US5 in CLI + WorldConfig (scaffolding surface), US6 in CLI (read-path presentation). No upward dependencies added. Integration harness treats layers as black boxes (shells the installed CLI), which is exactly the layer boundary the constitution specifies. |

**Gate result: PASS.** No complexity-tracking entries required.

### Post-Phase-1 re-evaluation

Re-checked after `research.md`, `data-model.md`, `contracts/cli-flags.md`, and `quickstart.md` were drafted.

- Principle I (Test-First / Mock AI): reinforced. R8 commits the integration suite to `MOCK_AI=true` by default; SC-007 live-LLM check stays behind the human-in-the-loop `/user-qa` gate. No design choice forces live-LLM in CI.
- Principle II (Producer Contract): unchanged. `eidos world new --quick` adds flags; `--world-dir` / `-w` preserved (see `contracts/cli-flags.md`).
- Principle III (DI): R3 explicitly keeps the bible-wiring as-is unless the minimal fix (derive id, raise on missing) is insufficient. No hard-coded instantiation introduced.
- Principle IV (Canon Integrity): strengthened. R1 preserves dropped entries in `parse_error.drops`; R2 opens a per-drop `AuditFinding`; R3 makes bible persistence honest.
- Principle V (Security): unchanged. No credential paths touched.
- Principle VI (Pluggable AI + Evals): R5 defers the LLM-inference option deliberately; fuzz specs (FR-024) act as parser evals.
- Principle VII (Separation of Concerns): reinforced. Integration suite shells the CLI at the outermost layer; no engine-leaking test double introduced.

**Post-design gate result: PASS.** No new complexity to track; complexity table remains empty.

## Project Structure

### Documentation (this feature)

```text
specs/015-scaffold-hardening/
├── plan.md              # This file (/speckit.plan)
├── research.md          # Phase 0 output — resolved decisions on US4 inference, sentinel value, integration harness shape
├── data-model.md        # Phase 1 output — new/changed entities (parse_error record, metadata sentinel, integration scenario)
├── quickstart.md        # Phase 1 output — how to run the user-scale suite and validate this feature locally
├── contracts/
│   └── cli-flags.md     # Phase 1 output — `world new --quick` flag surface, world status output contract
├── checklists/
│   └── requirements.md  # From /speckit.specify — PASS
└── tasks.md             # Phase 2 output (/speckit.tasks — NOT created by /speckit.plan)
```

### Source Code (repository root)

The existing monorepo layout is preserved. Files touched and added:

```text
eidos/
├── lib/eidos/
│   ├── cli/
│   │   ├── world.rb                       # US3 (non-interactive flags), US6 (piece-first status)
│   │   └── main.rb                        # (unchanged — routing only)
│   ├── world_config.rb                    # US4 (metadata inference / sentinel handling)
│   ├── scaffold/                          # US5 (lazy form-dir creation) — if extracted
│   │   └── world_template.rb              #   (alternative: keep inline in cli/world.rb)
│   ├── piece_producer.rb                  # US2 (bible persistence wiring)
│   ├── canon_delta.rb                     # US1 (parse_error population)
│   ├── canon_delta_parser.rb              # US1 (promote drops to records instead of stderr+next)
│   │                                      #     (exact filename follows existing convention)
│   └── audit_log.rb                       # US1 (surface findings in `canon review`)
├── spec/
│   ├── eidos/                             # existing unit specs — extended with fuzz cases (FR-024)
│   │   └── canon_delta_parser_spec.rb     #   + bare-string, missing-key, truncated-json cases
│   ├── integration/
│   │   └── user_scale/                    # NEW directory (FR-019..FR-021)
│   │       ├── spec_helper.rb             # shells exe/eidos, asserts on disk
│   │       ├── demo_job_hunt_spec.rb      # covers SC-001..SC-006 in one scenario
│   │       └── produce_two_forms_spec.rb  # covers SC-008 (two non-chapter forms)
│   └── support/
│       └── integration_world_builder.rb   # helper — creates temp worlds, cleans up
├── exe/eidos                              # (unchanged)
└── bin/world                              # (unchanged)

scripts/
└── demo_job_hunt.sh                       # may be updated to drive new flag surface (US3)

CLAUDE.md                                  # silent-fallback ban (FR-022, FR-023, SC-009)

worlds/one-review-man/                     # UNCHANGED — backwards-compat constraint
```

**Structure Decision**: Single-project monorepo (no structural change). All US1–US6 changes land inside `eidos/lib/eidos/`. Integration harness is a new top-level spec directory `eidos/spec/integration/user_scale/` kept separate from the unit suite so it can be invoked on its own and so its cost does not block the fast loop.

## Complexity Tracking

*No constitutional violations. Table intentionally empty.*

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| *(none)* | *(none)* | *(none)* |
