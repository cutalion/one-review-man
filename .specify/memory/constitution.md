<!--
  Sync Impact Report
  ===================
  Version change: 2.0.0 → 2.0.1
  Bump rationale: PATCH — naming refresh only, no principle changes.
    Paths, flags, and namespaces renamed to match the post-restructure
    codebase (book-generator → eidos, BookCore → Eidos, books/ →
    worlds/, --book-dir → --world-dir). No obligations added, removed,
    or redefined.
  Modified principles: none
  Modified sections (naming-only clarifications):
    - Principle II: CLI path `book-generator/bin/book` → `eidos/exe/eidos`;
      `--book-dir` → `--world-dir`
    - Principle IV: `books/*/content/` → `worlds/*/content/`
    - Principle VII: example "book chapter generator" → "chapter generator"
    - Development Constraints: RuboCop config path refreshed
    - Architecture Layers: namespaces (`BookCore::` → `Eidos::`) and
      directories (`book_core/` → `eidos/lib/eidos/`, `books/*/data/`
      → `worlds/*/data/`) refreshed
  Added sections: none
  Removed sections: none
  Templates requiring updates:
    - .specify/templates/plan-template.md ✅ no updates needed (generic gates)
    - .specify/templates/spec-template.md ✅ no updates needed (generic structure)
    - .specify/templates/tasks-template.md ✅ no updates needed (generic phases)
  Follow-up TODOs: Principle IV may need a MINOR amendment in the
    upcoming IP-generator pivot spec to codify the canon-feedback
    obligation (every produced piece must record the canon deltas
    it introduces).
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

### II. Producer Contract

Every product generator (book, comic, Instagram, video, etc.) MUST
implement a common producer interface that accepts:

1. **IP version reference** — a specific canon snapshot to build from.
2. **Product description** — what to produce (format, scope, parameters).
3. **Output location** — where to write the resulting artifacts.

Producers MUST be invocable through the Thor-based CLI at
`eidos/exe/eidos` (or the equivalent domain-named binaries under
`eidos/bin/`). The `--world-dir` / `-w` flag MUST be supported so
commands work from the repository root. No feature may require
manual file manipulation that could instead be a CLI subcommand.

**Rationale**: A common contract enables multiple product types
(books, comics, Instagram posts) to be built from the same IP
without coupling producers to each other or to the canon engine.

### III. Dependency Injection

Major components (LLMService, ImageService, PromptProvider,
OutputAdapter, Producer) MUST accept their collaborators via
constructor arguments. Hard-coded service instantiation inside
business logic is prohibited. This enables test doubles and
alternative implementations without monkey-patching.

**Rationale**: Loose coupling makes the codebase testable and
extensible as new AI providers, output targets, or producers
are added.

### IV. Canon Integrity with Versioned IP

The canon (Story Bible) is the single source of truth for all
intellectual property: characters, locations, facts, relationships,
plot threads, reference images, style guides, and any other
canonical asset — text or binary.

Canon state MUST be versionable. Every derivative artifact MUST
record which canon version it was produced from. The system MUST
support snapshotting or tagging canon state so that:

- A derivative can be reproduced from the same canon version.
- A derivative can be compared against a newer canon version to
  detect staleness.

Generated content under `worlds/*/content/` MUST use consistent
naming. Publishing targets (Jekyll site, Instagram, etc.) MUST be
rebuildable from canon + generated content at any time. No
hand-edited content may live only in a publishing target; the
source of truth is always the canon and its derivatives.

**Rationale**: Versioned IP prevents drift between the canonical
world state and its products. Linking derivatives to canon versions
makes regeneration, comparison, and variant selection reliable.

### V. Security by Default

API keys and secrets MUST be provided via environment variables
(`OPENAI_API_KEY`, etc.) and MUST NOT appear in committed files.
Debug artifacts (`tmp/ai_debug/`) MUST be gitignored. The
`--debug` flag controls verbose logging; production paths MUST
NOT leak credentials or full prompt payloads.

**Rationale**: The project interacts with paid AI APIs; leaked
keys cause direct financial exposure.

### VI. Pluggable AI Services with Evals

AI capabilities (text generation, image generation, translation,
etc.) MUST be accessed through abstract service interfaces, not
directly through vendor SDKs. Each service interface MUST support
multiple provider backends (e.g., OpenAI, Anthropic, Stability,
local models).

Every AI service MUST have an eval suite that verifies output
quality against reference examples. Evals MUST run when switching
providers or models to confirm quality parity. Eval results MUST
be recorded so regressions are detectable.

**Rationale**: AI models and providers evolve rapidly. Abstracting
behind interfaces with quality gates prevents vendor lock-in and
ensures that model upgrades or provider switches do not silently
degrade output quality.

### VII. Separation of Concerns: Engine, Producers, Publishing

The system MUST maintain three distinct architectural layers:

1. **Engine (IP Core)** — manages the canon: story bible, revisions,
   branches, versioning. Format-agnostic. No knowledge of specific
   products or publishing targets.
2. **Producers (Derivative Generators)** — create artifacts from a
   canon version. Each producer is independent and follows the
   Producer Contract (Principle II). Examples: chapter generator,
   comic panel producer, illustration producer, Instagram image
   producer.
3. **Publishing (Distribution)** — takes ready artifacts and
   distributes them. Examples: Jekyll site, Instagram post, YouTube
   upload. Publishing MAY be a separate project that consumes
   producer output through a clear public API.

Cross-layer dependencies MUST flow downward: Publishing depends on
Producers, Producers depend on Engine. No upward dependencies.

**Rationale**: Clean layer separation allows each concern to evolve
independently. New product types or publishing channels can be
added without modifying the canon engine.

## Development Constraints

- **Language**: Ruby 3.3.5, UTF-8 encoding, `frozen_string_literal: true`
  on every file.
- **Style**: 2-space indentation, snake_case files, CamelCase classes.
  RuboCop (`eidos/.rubocop.yml`) MUST pass before merge.
- **Testing**: RSpec with `MOCK_AI=true` as the default mode.
  `DEBUG_AI=1` for verbose logging during development only.
- **Dependencies**: Managed via Bundler. Gemfile changes require
  justification in the PR description.

## Architecture Layers

1. **Engine** — `Eidos::StoryBible`, `Eidos::RevisionStore`,
   `Eidos::BranchManager`, and related classes manage canon state
   under `worlds/*/data/story_bible/`. The engine provides canon
   snapshots and version references to producers.
2. **Producers** — `Eidos::ChapterGenerator`,
   `Eidos::IllustrationGenerator`, `Eidos::PanelDescriptionGenerator`,
   and future producers (comic panels, Instagram images) live under
   `eidos/lib/eidos/` and implement the common producer contract.
   Each producer records the canon version it built from.
3. **AI Services** — `LLMService`, `ImageService` (future), and
   other AI interfaces are injected into producers. Provider
   backends are swappable. Eval suites validate quality.
4. **Publishing** — `JekyllAdapter` and the `site/` directory
   handle web publishing. Future publishing targets (Instagram,
   YouTube) follow the same pattern: consume ready artifacts,
   format for the platform, distribute.

## Governance

- This constitution is the highest-authority document for development
  decisions. When a PR conflicts with a principle, the principle wins
  unless the constitution is amended first.
- **Amendments** require: (1) a PR updating this file, (2) a version
  bump following semver (MAJOR for principle removals/redefinitions,
  MINOR for additions, PATCH for clarifications), and (3) a Sync
  Impact Report updated at the top of this file.
- **Compliance** is verified during code review. Every PR MUST be
  checked against the seven core principles before approval.

**Version**: 2.0.1 | **Ratified**: 2026-03-30 | **Last Amended**: 2026-04-18
