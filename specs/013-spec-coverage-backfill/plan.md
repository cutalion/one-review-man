# Implementation Plan: Comprehensive Test Coverage & Spec Coverage Tooling

**Branch**: `013-spec-coverage-backfill` | **Date**: 2026-04-17 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/013-spec-coverage-backfill/spec.md`

## Summary

Close the "specs pass but user sees bugs" gap with four complementary gates, all wired into the default `bundle exec rspec` run:

1. **Runtime prompt-call assertion** — wrap `MockLLMService` in an RSpec-aware harness that fails any enclosing spec if the prompt string arriving at the mock contains unfilled placeholders (both `{SINGLE}` and `{{DOUBLE}}` forms) or if a "Unused placeholders" warning fired on stdout while that prompt was being built.
2. **SimpleCov line-coverage floor** — measure `eidos/lib/` coverage; fail the full-suite run if below a committed threshold; override via `COVERAGE_THRESHOLD=<int>`; suppress the check for single-file runs.
3. **Regression integration specs** — three named canaries for the escaped regressions (`CHAPTER_NUMBER` warning, `--prompt` threading, `target_chapters` residue) plus a scripted-stdin spec for interactive `world new`.
4. **IP-neutrality audit** — walk every shipped template and engine code path for ORM-specific vocabulary; generalize, parameterize, or relocate; rename `BOOK_*` placeholders → `STORY_*` with one-release back-compat; record findings in `specs/013-spec-coverage-backfill/audit-log.md`.

The runtime assertion replaces the originally-scoped file-scan meta-spec (per Clarifications Q1); coverage is what guarantees every template's fill path is exercised by at least one spec.

## Technical Context

**Language/Version**: Ruby 3.3.5, `frozen_string_literal: true` on every file
**Primary Dependencies (test-only, new)**: SimpleCov ~> 0.22 (line coverage); no production dependency changes
**Primary Dependencies (existing, touched)**: RSpec ~> 3.12, Thor ~> 1.3, tty-prompt ~> 0.23
**Storage**: No storage schema changes — all work is in `eidos/spec/`, `eidos/lib/eidos/prompts/`, and engine Ruby files
**Testing**: RSpec under `MOCK_AI=true`, offline-only, using `spec/support/mock_llm_service.rb` + `spec/support/mock_responses.yml`
**Target Platform**: Developer workstation + CI (Linux / macOS); `bundle exec rspec` is the single entry point
**Project Type**: Ruby gem (single project: `eidos/`) + storyworld content tree (`worlds/one-review-man/`)
**Performance Goals**: Full-suite runtime MUST NOT more than 2× the current baseline under `MOCK_AI=true` (SC-007). Baseline is measured on the pre-feature commit during T001.
**Constraints**: No live-network specs; no new production runtime dependencies; `MOCK_AI=true` remains the default test mode
**Scale/Scope**: ~85 Ruby source files under `eidos/lib/`, ~610 existing specs, 6 shipped prompt templates, ~dozen ORM-leak sites identified in the spec

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Verdict | Notes |
|---|---|---|
| I. Test-First with Mock AI | ✅ **Reinforced** | All new gates run under `MOCK_AI=true`; no live-network specs added. |
| II. Producer Contract | ✅ **Unaffected** | No producer-interface changes. |
| III. Dependency Injection | ✅ **Unaffected** | The prompt-assertion harness wraps the existing injected `LLMService` seam. |
| IV. Canon Integrity with Versioned IP | ✅ **Unaffected** | Canon data schema unchanged. |
| V. Security by Default | ✅ **Unaffected** | No secret handling; no new credentials in play. |
| VI. Pluggable AI Services with Evals | ✅ **Reinforced** | Runtime prompt-assertion is effectively an eval-of-prompts-under-test; quality regressions now surface synchronously. |
| VII. Separation of Concerns: Engine/Producers/Publishing | ✅ **Reinforced** | US5 audit moves ORM-specific content out of the engine; generalizes templates; separates world-local content from engine defaults. |

**Gate status (Pre-Phase 0): PASS.** No violations; no Complexity Tracking entries needed.

**Gate status (Post-Phase 1 re-check): PASS.** The Phase 1 design artifacts (`research.md`, `data-model.md`, `contracts/*.md`, `quickstart.md`) introduce no new dependencies that conflict with Principle III (DI — the harness wraps the already-injected `LLMService` seam), no persistent state that touches Principle IV (Canon Integrity — no schema changes), and no new credentials touching Principle V. The runtime prompt-call assertion and the SimpleCov floor both operate strictly at the test-harness level, so Principle I (Test-First with Mock AI) is reinforced. No violations introduced by the design.

## Project Structure

### Documentation (this feature)

```text
specs/013-spec-coverage-backfill/
├── plan.md              # This file
├── research.md          # Phase 0 output (SimpleCov config, stdin-driven Thor, BOOK→STORY migration strategy)
├── data-model.md        # Phase 1 output (config schemas, audit-log row schema)
├── quickstart.md        # Phase 1 output (contributor workflow walkthrough)
├── contracts/
│   ├── coverage-cli.md         # How coverage is invoked + what the summary/override lines look like
│   ├── prompt-assertion.md     # How the MockLLMService wrapper detects violations and fails specs
│   ├── audit-log-schema.md     # Structure of audit-log.md
│   └── story-placeholder-compat.md  # BOOK_* → STORY_* back-compat contract
├── audit-log.md         # US5 output; populated during implementation
├── checklists/
│   └── requirements.md
├── spec.md
└── tasks.md             # Phase 2 output (NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
eidos/                           # The gem being hardened
├── lib/eidos/
│   ├── chapter_generator.rb     # Touched: BOOK_* → STORY_* rename; "programming comedy" fallback generalized; 'One Review Man' lookup relocated
│   ├── writer_agent.rb          # Touched: default "programming comedy book" framing parameterized via world_config
│   ├── world_config.rb          # Touched: title-based ORM branching removed; BOOK_* key back-compat loader added
│   ├── prompt_utils.rb          # Touched (minor): emit warnings via $stderr so the harness can intercept deterministically
│   ├── prompts/*.txt            # Touched: BOOK_TITLE/GENRE/SETTING/STYLE → STORY_TITLE/GENRE/SETTING/STYLE; genre-specific phrasing parameterized
│   └── defaults/                # New (if needed): genre-agnostic default templates lifted out of ORM assumptions
├── spec/
│   ├── spec_helper.rb           # Touched: load SimpleCov at the top when full-suite; wire assertion harness
│   ├── support/
│   │   ├── mock_llm_service.rb  # Touched: expose pre-call prompt inspection hook
│   │   ├── prompt_assertion_harness.rb   # NEW: fails the enclosing spec on unfilled-placeholder / emitted-warning
│   │   ├── coverage_setup.rb    # NEW: SimpleCov bootstrap + threshold enforcement (detects single-file runs)
│   │   └── stdin_driver.rb      # NEW: helper for the scripted-stdin interactive specs
│   ├── integration/
│   │   ├── chapter_number_regression_spec.rb        # NEW (US3 / FR-009 / SC-003)
│   │   ├── produce_chapter_prompt_flag_spec.rb      # NEW (US3 / FR-010 / SC-003)
│   │   ├── world_new_target_chapters_residue_spec.rb # NEW (US3 / FR-011 / SC-003)
│   │   ├── world_new_interactive_flow_spec.rb       # NEW (US4 / FR-012 / SC-006)
│   │   └── ip_neutrality_non_orm_world_spec.rb      # NEW (US5 / FR-018 / SC-008)
│   └── prompt_assertion_harness_spec.rb             # NEW: self-test of the harness (smoke test + regression canary)
├── .simplecov                   # NEW (or inlined in spec_helper.rb): coverage config (lib-only, exclusions)
└── coverage/                    # Generated; already gitignored (verify)

worlds/one-review-man/            # ORM storyworld content
└── data/
    ├── world_config.yml         # Touched: migrate BOOK_* keys → STORY_*; ORM-specific overrides (e.g. character alias for the POV character) moved here from engine

docs/                             # Contributor-facing docs
└── (existing AGENTS.md / README.md updated per FR-015)

specs/013-spec-coverage-backfill/
└── audit-log.md                  # NEW: durable record of every audit finding (FR-019)
```

**Structure Decision**: Single-project layout (Option 1) — all changes land inside the existing `eidos/` gem and the ORM world directory. No new top-level directories. The `specs/013-spec-coverage-backfill/` feature folder grows an `audit-log.md` file as a versioned artifact of the US5 audit (per Clarifications Q5).

## Complexity Tracking

> Fill ONLY if Constitution Check has violations that must be justified

*No violations; section intentionally empty.*
