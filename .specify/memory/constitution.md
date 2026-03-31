<!--
  Sync Impact Report
  ===================
  Version change: (none) → 1.0.0 (initial creation)
  Modified principles: N/A (all new)
  Added sections:
    - Core Principles (5 principles)
    - Development Constraints
    - Content Workflow
    - Governance
  Removed sections: N/A
  Templates requiring updates:
    - .specify/templates/plan-template.md ✅ no updates needed (generic gates)
    - .specify/templates/spec-template.md ✅ no updates needed (generic structure)
    - .specify/templates/tasks-template.md ✅ no updates needed (generic phases)
  Follow-up TODOs: none
-->

# One Review Man Constitution

## Core Principles

### I. Test-First with Mock AI

All features and bug fixes MUST be covered by RSpec tests that pass
in `MOCK_AI=true` mode. Live API calls are never required for the
test suite to go green. Mock responses live in
`spec/support/mock_responses.yml` and MUST be kept in sync with
any prompt or output format changes.

**Rationale**: Deterministic, offline-capable tests prevent flaky CI
and avoid burning API credits on every run.

### II. CLI as the Single Entry Point

Every operation (generation, translation, site building, reset) MUST
be executable through the Thor-based CLI at `book-generator/bin/book`.
No feature may require manual file manipulation that could instead be
a CLI subcommand. The `--book-dir` flag MUST be supported so commands
work from the repository root.

**Rationale**: A consistent CLI surface keeps scripting, CI, and
developer workflows predictable and composable.

### III. Dependency Injection

Major components (LLMService, PromptProvider, OutputAdapter) MUST
accept their collaborators via constructor arguments. Hard-coded
service instantiation inside business logic is prohibited. This
enables test doubles and alternative implementations without
monkey-patching.

**Rationale**: Loose coupling makes the codebase testable and
extensible as new AI providers or output targets are added.

### IV. Content Integrity

Generated chapters and translations MUST be stored as structured
files under `books/*/content/` with consistent naming. The Jekyll
site generator MUST be able to rebuild the full site from these
source files at any time. No hand-edited content may live only in
`site/`; the source of truth is always `books/*/content/`.

**Rationale**: A single source of truth prevents drift between the
raw content and the published site.

### V. Security by Default

API keys and secrets MUST be provided via environment variables
(`OPENAI_API_KEY`, etc.) and MUST NOT appear in committed files.
Debug artifacts (`tmp/ai_debug/`) MUST be gitignored. The
`--debug` flag controls verbose logging; production paths MUST
NOT leak credentials or full prompt payloads.

**Rationale**: The project interacts with paid AI APIs; leaked
keys cause direct financial exposure.

## Development Constraints

- **Language**: Ruby 3.3.5, UTF-8 encoding, `frozen_string_literal: true`
  on every file.
- **Style**: 2-space indentation, snake_case files, CamelCase classes.
  RuboCop (`book-generator/.rubocop.yml`) MUST pass before merge.
- **Testing**: RSpec with `MOCK_AI=true` as the default mode.
  `DEBUG_AI=1` for verbose logging during development only.
- **Dependencies**: Managed via Bundler. Gemfile changes require
  justification in the PR description.

## Content Workflow

1. **Generate** — `book generate chapter` creates the next chapter
   using the configured LLM model and settings from
   `books/*/data/settings.yml`.
2. **Translate** — `book translate all <lang>` or
   `book translate chapter <n> <lang>` produces translations stored
   alongside originals.
3. **Publish** — `book jekyll generate` assembles the Jekyll site
   from source content. The site is a build artifact, not a source
   of truth.
4. **Verify** — `quick_test.sh` for fast checks, `e2e_test.sh` for
   full end-to-end validation.

## Governance

- This constitution is the highest-authority document for development
  decisions. When a PR conflicts with a principle, the principle wins
  unless the constitution is amended first.
- **Amendments** require: (1) a PR updating this file, (2) a version
  bump following semver (MAJOR for principle removals/redefinitions,
  MINOR for additions, PATCH for clarifications), and (3) a Sync
  Impact Report updated at the top of this file.
- **Compliance** is verified during code review. Every PR MUST be
  checked against the five core principles before approval.

**Version**: 1.0.0 | **Ratified**: 2026-03-30 | **Last Amended**: 2026-03-30
