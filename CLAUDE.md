# AI Agent Rules and Guidelines

This document provides a comprehensive guide for AI agents working with this repository.

---

## Project Overview: One Review Man

This repository contains "One Review Man," an AI‑generated programming comedy IP (storyworld). The project is a monorepo hosting:

- The **Eidos** gem — a reusable Ruby engine, SDK, and CLI for managing storyworlds.
- The **One Review Man** storyworld — content (chapters, characters, comics) produced by Eidos.
- A **Jekyll site** — the generated public reading surface.

The Eidos gem is responsible for:
*   **World Management:** Creating and managing storyworlds (`eidos world` / `bin/world`).
*   **Story Bible:** Managing canonical world lore (`eidos bible` / `bin/bible`).
*   **Canon Versioning:** Tracking and versioning world state with revisions, snapshots, and branches (`eidos canon` / `bin/canon`).
*   **Content Production:** Generating chapters, comics, and illustrations (`eidos produce` / `bin/produce`).
*   **Translation:** Translating content to other languages (`eidos translate` / `bin/translate`).
*   **Publishing:** Assembling content into a Jekyll website (`eidos publish` / `bin/publish`).
*   **SDK-powered browsing:** `eidos chapter` and `eidos character` subcommands built on the Ruby SDK.

The world's content is stored in `worlds/one-review-man/`, and the Jekyll site is built into `site/`.

## Project Structure

```
├── eidos/                     # Core Ruby gem (engine + SDK + CLI)
│   ├── lib/eidos/             # Eidos:: namespace (engine, SDK, CLI classes)
│   ├── lib/eidos/cli/         # Thor-based CLI classes (Main, World, Bible, …)
│   ├── exe/eidos              # Unified `eidos` binary (installed by the gem)
│   ├── bin/world              # Dev-time binaries — one per domain
│   ├── bin/bible              # (identical to `eidos <name>`)
│   ├── bin/canon
│   ├── bin/produce
│   ├── bin/translate
│   ├── bin/publish
│   ├── templates/jekyll/      # Jekyll site template
│   ├── eidos.gemspec          # Gem manifest (installable)
│   └── spec/                  # RSpec tests
├── worlds/one-review-man/     # Storyworld content and configuration
│   ├── content/               # Generated chapters, characters, comics
│   └── data/                  # world_config.yml, story_bible/, settings.yml
└── site/                      # Generated Jekyll site (build target)
```

## Three-Layer Architecture

Eidos is organized as three layers over the same storyworld data:

1. **Engine** — low-level classes (`PieceProducer`, `ChapterGenerator`, `FormRegistry`, `StoryBible`, `LLMService`, `RevisionStore`, `SnapshotStore`, `BranchManager`, `DiffEngine`, …). Use when full control is needed.
2. **SDK** — object-oriented façade (`Eidos::World`, `Chapter`, `Character`, `Location`, `Bible`, `Canon`). Convention over configuration; mutations persist immediately.
3. **CLI** — `Eidos::CLI::Main` Thor router in `lib/eidos/cli/main.rb`, started by `exe/eidos`. Includes both legacy domain subcommands and new SDK-based ones.

## Common Development Commands

#### Setup
```bash
# Docker Setup
docker compose build
docker compose up -d

# Manual Setup
cd eidos
bundle install

# Jekyll site dependencies
cd site
bundle install
```

#### Testing
```bash
# Run all tests from the eidos directory
cd eidos
MOCK_AI=true bundle exec rspec          # 630 examples, 0 failures

# Run a specific test file
MOCK_AI=true bundle exec rspec spec/eidos/sdk_integration_spec.rb
```

**Coverage (SimpleCov, enforced on full-suite runs)**. A full `bundle exec rspec` measures line coverage on `eidos/lib/` and fails if it drops below the committed floor. Single-file runs (e.g. `rspec spec/eidos/foo_spec.rb`) bypass coverage — no summary, no threshold check. Overrides:

```bash
# Default full-suite — summary on stdout, HTML at eidos/coverage/index.html
MOCK_AI=true bundle exec rspec

# Lower the floor for one run (audit line printed to $stderr, exit 0)
COVERAGE_THRESHOLD=40 bundle exec rspec

# Disable the check entirely for one run
COVERAGE_THRESHOLD=0 bundle exec rspec
```

The committed floor lives in `eidos/spec/support/coverage_setup.rb` as `EIDOS_COVERAGE_FLOOR`. Raise it by bumping that constant + running the suite to confirm it still passes. Never lower it to unblock a red run — investigate the drop first. Details in `specs/013-spec-coverage-backfill/quickstart.md`.

**Prompt-assertion harness (runtime gate in `MockLLMService`)**. Every mock LLM call fails the enclosing spec if the outgoing prompt carries an unfilled `{PLACEHOLDER}` / `{{PLACEHOLDER}}` token OR if prompt construction emitted an `"Unused placeholders"` stderr warning. Failure shape:

```
Prompt assertion failed during <spec_description> → MockLLMService#<method>:
  category: unfilled placeholder          # or: unused placeholder warning
  placeholders: CHAPTER_NUMBR, BOOK_TITL   # the specific tokens
  prompt (first 500 chars): "..."
```

When you see this: (1) `category` tells you whether the leak is an *unfilled* token in the outgoing prompt or an *unused* token the template declared but the fill site didn't supply; (2) `placeholders` names the offending tokens; (3) the prompt excerpt shows what actually shipped. Fix the template or the fill site, not the harness.

#### Content Generation & Management
```bash
# The unified CLI (installed as `eidos` via `gem install eidos`,
# or runnable from the monorepo as `eidos/exe/eidos`):
eidos/exe/eidos world status -w worlds/one-review-man
eidos/exe/eidos chapter list -w worlds/one-review-man
eidos/exe/eidos character show kenji_yamamoto -w worlds/one-review-man

# Pieces are the generic unit — chapter is one form among many.
# Built-in forms: chapter, vignette, short-story, haiku, comic-script,
#                 portrait, social-post, illustration.
# Worlds can register custom forms in data/forms/<name>.yml.
eidos/exe/eidos piece list -w worlds/one-review-man
eidos/exe/eidos piece list --form vignette -w worlds/one-review-man
eidos/exe/eidos piece show VIGNETTE001 -w worlds/one-review-man

# Generate a piece of any form. --length is a per-invocation override;
# without it the form's declared default shape/length is used.
# Chapters fall back to world_config.chapter_length_target (pre-014 behavior).
eidos/exe/eidos produce piece --form haiku --prompt "about a silent code review"
eidos/exe/eidos produce piece --form vignette --length 400 \
  --prompt "Arthur reviews his own forgotten commit."
eidos/exe/eidos produce piece --form chapter --dry-run --prompt "Act 3 opener"

# Cheap smoke-test for a provider/model (auth, reachability, latency).
# Does NOT mutate world files; uses one tiny round-trip (~30 in / ~5 out tokens).
eidos/exe/eidos probe gpt-4o-mini
eidos/exe/eidos probe anthropic/claude-3.5-haiku --provider openrouter --metrics

# Side-by-side model comparison: same prompt, diff the outputs.
# --prompt turns probe into a cheap free-form generator (default max-tokens bumps to 500).
eidos/exe/eidos probe gpt-4o-mini --prompt "Write a haiku about code review." > a.txt
eidos/exe/eidos probe gpt-5-turbo --prompt "Write a haiku about code review." > b.txt
diff a.txt b.txt

# The domain-specific binaries in `eidos/bin/` are equivalent:
eidos/bin/world new -w worlds/one-review-man
eidos/bin/produce chapter -w worlds/one-review-man
MOCK_AI=true eidos/bin/produce chapter -w worlds/one-review-man --auto
eidos/bin/produce prompt [CHAPTER_NUMBER] -w worlds/one-review-man
eidos/bin/translate all ru -w worlds/one-review-man
eidos/bin/translate chapter 1 ru -w worlds/one-review-man
```

#### Website
```bash
# Generate the Jekyll site
eidos/bin/publish jekyll -w worlds/one-review-man --dest site

# Run the Jekyll server locally
cd site
bundle exec jekyll serve   # Site at http://localhost:4000
```

#### SDK from Ruby
```ruby
require 'eidos'

Eidos.configure { |c| c.worlds_path = 'worlds' }

world = Eidos::World.new('one-review-man')
world.status
world.chapters.count
world.bible.characters.map(&:name)
world.canon.current_branch
```

#### Sanity Checks
```bash
./quick_test.sh   # Quick tests
./e2e_test.sh     # Full end-to-end tests
```

## Development Conventions

### Coding Style & Naming
*   **Language:** Ruby 3.3.5.
*   **Indentation:** 2 spaces.
*   **Encoding:** UTF-8.
*   **Magic Comment:** Add `# frozen_string_literal: true` to all Ruby files.
*   **Naming:**
    *   Files: `snake_case.rb`
    *   Classes/Modules: `CamelCase`
    *   RSpec files: `*_spec.rb`
*   **Linting:** Adhere to RuboCop rules defined in `eidos/.rubocop.yml`. Run `bundle exec rubocop` to check.

### Development Modes
*   `MOCK_AI=true`: Use deterministic mock AI responses from `spec/support/mock_responses.yml` instead of making live API calls. Preferred for tests and local iteration.
*   `DEBUG_AI=1` or `--debug` flag: Enable verbose LLM debug logging. Artifacts are saved to `tmp/ai_debug/`.

### Definition of Done

**Green unit tests are not the end state for user-facing work.** `bundle exec rspec` verifies that individual classes behave correctly under controlled inputs. It does *not* verify that the program — driven as a user drives it — produces the world the user asked for. Scaffolding regressions, canon-delta silent drops, prompt placeholders that leak, and world-config heuristics that fall back to defaults all pass rspec and still break the product.

Before declaring any of the following complete, you MUST run the `/user-qa` command (or invoke the `user-qa` subagent directly) against a **freshly generated world** and confirm a PASS verdict:

*   Changes to CLI UX (Thor subcommands, help text, flags).
*   Changes to world scaffolding (`eidos world new`, `collect_quick_setup_info`, templates, `strings.yml`).
*   Changes to content production (`produce piece`, `produce chapter`, form registry, prompt templates).
*   Changes to canon-delta extraction, parsing, or application (delta YAML shape, audit log, bible merge).
*   Changes to any file under `eidos/lib/eidos/prompts/`.

The QA agent reports three tiers of findings (structural health, intent consistency, UX smoke). Tier-1 failures are blocking — the feature is not done while any Tier-1 check fails, regardless of rspec status. Tier-2 failures should be explicitly accepted or fixed; do not paper over them in a commit message. See `.claude/agents/user-qa.md` for the full check list.

When you finish a spec-kit task involving any of the above, before marking it `[X]`:

1. Build or identify a minimal user-scale scenario (usually a quickstart acceptance scenario).
2. Generate a fresh world from it (not the one you developed against).
3. Run `/user-qa` with the intent + the new world path, **live LLM** unless the change is purely structural.
4. Only after PASS: mark the task complete, commit, open PR.

If `/user-qa` surfaces a regression, fix the root cause — do not weaken the QA check or special-case it away. The check exists precisely because we shipped a premise-aware-scaffolding feature whose unit tests passed and whose generated worlds did not reflect the premise.

#### Doc-QA and Impl-QA — keeping the pitch, the guide, and the code in sync

`docs/pitch.md` is the project's vision source-of-truth and `docs/usage-guide.md` is the operational source-of-truth. Two additional QA agents keep them honest, alongside the user-qa requirement above:

**Run `/doc-qa` and confirm a PASS verdict before declaring complete any change that modifies `docs/pitch.md` or `docs/usage-guide.md`.** Doc-qa compares the two documents and flags vision-alignment failures (a guide section that contradicts what the pitch says the project is or is not), guide internal-consistency failures (terminology drift, contradictions between sections), or pitch self-consistency failures. Tier-1 (vision) and Tier-2 (internal consistency) failures are blocking. Doc-qa runs without an API key.

**Run `/impl-qa` and confirm a PASS verdict before declaring complete any change that modifies user-facing CLI surface, world scaffolding output, content-production workflow, or `docs/usage-guide.md`.** Default mode (Tier 1 + 3 + 4 only) is fast, runs without an API key, and catches surface drift (commands/flags/paths the guide names but the codebase doesn't expose). For changes that touch scaffolding output or content production, also run `/impl-qa --behavioral` to verify the guide's post-state claims against a freshly scaffolded world (`MOCK_AI=true` is the default; pass `--live` only when you specifically need to verify LLM-dependent behavior).

Both agents emit structured reports with `attribution:` lines on every drift finding — `guide stale` means update the guide, `codebase changed` means update the codebase or the guide depending on whether the codebase change was intentional. Tier 3 of impl-qa surfaces undocumented user-facing surface; treat each item as a candidate for *either* documentation *or* removal — the agent does not assume a direction.

The three QA agents serve distinct purposes and are not interchangeable: **user-qa** verifies a generated world matches user intent; **doc-qa** verifies the usage guide matches the project pitch; **impl-qa** verifies the implementation matches the usage guide. Run all three for any change that affects user-facing behavior plus its documentation.

### Banned patterns: silent fallbacks

**The rule**: No method may silently substitute a real-looking value, swallow a degraded input, or no-op on missing data. Every degradation must surface to a user-visible channel. Reviews reject code that violates this rule; tests that only assert on the happy path get flagged for missing the degradation assertion.

**Why this rule exists**: Feature 014-storyworld-pivot shipped with six Tier-1 defects. All six passed their unit tests. All six involved a silent-fallback pattern:

1. **`collect_quick_setup_info`** returned hardcoded `"fiction"` / `"narrative"` / `"contemporary setting"` / `"adventure"` on regex miss. The generated world looked like inference had succeeded — it had not.
2. **`apply_character` / `apply_location`** had `return nil unless id`. LLM-emitted entries with `name` but no `id` silently no-op'd. `applied_at` was stamped, `parse_error` was null, `data/story_bible/characters/` stayed empty.
3. **`CanonDelta.normalize_section`** emitted `warn "..." ; next nil` on non-mapping entries. Three of four demo deltas lost their entities. Stderr is not a user-visible channel.

**The three acceptable alternatives**:

1. **Raise.** If the caller should have caught this, let them catch it. Prefer a typed exception with a message that names the field and the invariant.
2. **Return a `Result`-like record.** `{success: bool, error: string, drops: [...]}` — the caller inspects it; the degradation is explicit. Good for parsers and validators.
3. **Open an `AuditFinding` or surface via `world status` / `canon review`.** User-visible channels users actually read. Stderr does not count; log files do not count unless the CLI prints a pointer to them.

**Anti-patterns to flag in review**:

- `return nil unless <arg>` / `return if …` at the top of a business-logic method
- Hardcoded sentinel values (`"fiction"`, `"adventure"`, `"TODO"`, `"default"`) substituted when real inference fails
- `warn` / `puts` / `$stderr.puts` as the only signal of a data-loss or degradation event
- `rescue => e ; next` in a loop that processes structured input
- Empty arrays, empty hashes, or empty strings returned from methods whose contract implies presence

**Test corollary**: every parser / validator / apply-path spec must include at least one failing-input case that asserts the failure surfaces via `parse_error`, `AuditFinding`, or a raise. Unit suites that only exercise the happy path are incomplete.

Adopted 2026-04-18 as part of feature 015-scaffold-hardening. Postmortem evidence: `specs/014-storyworld-pivot/postmortem.md` §3.

### Commit & PR Guidelines
*   **Commits:** Use imperative present tense (e.g., "Fix CLI robustness"). Keep commits small and focused.
*   **PRs:** Include a summary, motivation, and verification steps. Note any visual changes with screenshots. Ensure all tests and linters pass before submitting. For user-facing work (per Definition of Done above), attach the `/user-qa` PASS report or state why it wasn't required.

### Security
*   **Secrets:** Do not commit API keys or other secrets. Provide LLM keys via environment variables (`OPENAI_API_KEY`, etc.).
*   **Debug Artifacts:** Use the `--debug` flag or `DEBUG_AI=1` environment variable for verbose logging.

## Project Architecture

### Engine (`lib/eidos/`)
*   **`Eidos::PieceProducer`** — generic piece generation engine for any registered form (haiku, vignette, portrait, …). Uses dependency injection for LLM, form registry, world config, bible, and canon.
*   **`Eidos::FormRegistry`** — discovers built-in forms under `eidos/lib/eidos/forms/` and per-world custom forms under `<world>/data/forms/`. Every form declares `name`, `category` (`text`/`image`/`script`), `default_length`/`default_shape`, and the canon context it needs.
*   **`Eidos::ChapterGenerator`** — chapter-form generator, predates the generic piece model. Keeps its structured flow (title/summary/new_characters JSON contract) for SC-002 byte-identical chapter frontmatter. Chapter is one form among many, not the organizing unit.
*   **`Eidos::LLMService`** — abstracted LLM interface. OpenAI implementation included.
*   **`Eidos::StoryBible`** — canonical world lore (characters, locations, facts, relationships, plot threads). Backed by pluggable storage.
*   **`Eidos::RevisionStore`, `SnapshotStore`, `BranchManager`, `DiffEngine`** — canon versioning primitives.
*   **`Eidos::WorldConfig`** — per-world configuration loading.
*   **`Eidos::JekyllAdapter`** — Jekyll output adapter.
*   **`Eidos::Producer`** — content production contract (pieces of any form).
*   **`Eidos::PromptProvider`** — prompt templates.

### SDK (also in `lib/eidos/`)
*   **`Eidos::World`** — root object; resolves by name / path / cwd.
*   **`Eidos::Chapter`, `ChapterCollection`** — chapter access from `world.chapters`.
*   **`Eidos::Bible`** — façade over `StoryBible` exposing `#characters`, `#locations`, `#facts`, `#relationships`, `#plot_threads`, `#search`.
*   **`Eidos::Character`, `Location`** — data-hash-backed domain objects with `method_missing` key proxies, `#[]`, `#to_h`, and `#update(changes, reason:)` (persists immediately).
*   **`Eidos::CharacterCollection`, `LocationCollection`** — `Enumerable`, indexable by id.
*   **`Eidos::Canon`** — façade over `RevisionStore`/`SnapshotStore`/`BranchManager`/`DiffEngine`. Methods: `#history`, `#diff`, `#snapshots`, `#create_snapshot`, `#branches`, `#current_branch`, `#create_branch`, `#compare_branches`, `#merge_branch`.
*   **`Eidos.configure` / `Eidos::SdkConfiguration`** — global SDK config (`worlds_path`, `storage_backend`).

### CLI (`lib/eidos/cli/`)
*   **`Eidos::CLI::Main`** — top-level Thor router (`exe/eidos` starts it).
*   **Domain CLIs:** `World`, `Bible`, `Canon`, `Produce`, `Translate`, `Publish` — the existing Thor classes registered as subcommands.
*   **SDK-based CLIs:** `ChapterCli`, `CharacterCli` — thin Thor classes that include `SdkHelpers` and drive the SDK domain objects.
*   **`Eidos::CLI::SdkHelpers`** — `resolve_world(options)` mixin shared by SDK-based subcommands.

### Configuration System
*   **LLM Configuration** is managed in `worlds/*/data/settings.yml`:
    ```yaml
    llm:
      provider: openai
      model: gpt-4o-mini
      temperature: 0.7
      timeout: 240
      default_options:
        max_tokens: 12000
      task_options:
        generation:
          max_tokens: 8000
        translation:
          max_tokens: 12000
    ```
*   **World Detection:** The CLI/SDK resolves a world by absolute path, by name (searching `Eidos.configuration.worlds_path` and `~/.eidos/worlds/`), or by walking up from `pwd` looking for `data/world_config.yml` (or legacy `data/world_metadata.yml`).

### Key Development Patterns
*   **Dependency Injection:** Engine classes accept injectable collaborators via constructor keyword args; used heavily in tests.
*   **Multi-language Support:** Content is generated in English and then translated into other languages using the AI; glossary built from existing translations.
*   **CLI structure:** One unified `eidos` Thor router with both legacy domain subcommands (`world`, `bible`, `canon`, `produce`, `translate`, `publish`) and new SDK-based ones (`chapter`, `character`). Each legacy binary in `eidos/bin/` is a shim for the same Thor class.
*   **Namespace:** All core classes live under `Eidos::` (e.g., `Eidos::ChapterGenerator`, `Eidos::StoryBible`, `Eidos::World`, `Eidos::Canon`).
*   **Storage abstraction:** Character/Location/etc. storage is pluggable (`:yaml_file` default, `:memory` for tests).
*   **Immediate persistence:** SDK mutations like `Character#update` write through to disk immediately.

## Active Technologies
- Ruby 3.3.5, `# frozen_string_literal: true`
- Thor ~> 1.3 (CLI), ruby-openai ~> 7.3 (LLM), tty-prompt ~> 0.23, tty-spinner ~> 0.9, rainbow ~> 3.1, dotenv ~> 3.1
- YAML files on disk for world config / state / story bible / revisions / snapshots; in-memory hashes available for tests
- Ruby 3.3.5, `# frozen_string_literal: true` on every file + Thor ~> 1.3 (CLI), ruby-openai ~> 7.3 (LLM), tty-prompt ~> 0.23 (interactive prompts), tty-spinner ~> 0.9, YAML (stdlib) (012-fix-ux-unify-bible)
- YAML files under `worlds/<name>/data/story_bible/` (pluggable via `Eidos::Storage` backends: `:yaml_file` default, `:memory` for tests) (012-fix-ux-unify-bible)
- Ruby 3.3.5, `frozen_string_literal: true` on every file (013-spec-coverage-backfill)
- No storage schema changes — all work is in `eidos/spec/`, `eidos/lib/eidos/prompts/`, and engine Ruby files (013-spec-coverage-backfill)
- Ruby 3.3.5, `# frozen_string_literal: true` on every file + Thor ~> 1.3 (CLI), ruby-openai ~> 7.3 (LLM), tty-prompt ~> 0.23, tty-spinner ~> 0.9, rainbow ~> 3.1, dotenv ~> 3.1, YAML (stdlib). No new runtime gems required. (014-storyworld-pivot)
- YAML files under `worlds/<name>/data/` (story bible, audit log, custom forms) and `worlds/<name>/content/` (piece files). Pluggable via `Eidos::Storage` backends (`:yaml_file` default, `:memory` for tests). Reuses existing RevisionStore / SnapshotStore primitives for canon versioning. No schema migration for existing worlds. (014-storyworld-pivot)
- Ruby 3.3.5, `# frozen_string_literal: true` on every file + Thor ~> 1.3 (CLI), ruby-openai ~> 7.3 (LLM), tty-prompt ~> 0.23 (interactive prompts only — non-interactive path bypasses), tty-spinner ~> 0.9, rainbow ~> 3.1, dotenv ~> 3.1, YAML (stdlib). **No new runtime gems.** (015-scaffold-hardening)
- YAML files under `worlds/<name>/data/` (story bible, canon deltas, audit log, world config, strings, custom forms) and `worlds/<name>/content/` (piece files). Pluggable `Eidos::Storage` backends (`:yaml_file` default, `:memory` for tests). (015-scaffold-hardening)
- Markdown (CommonMark) for docs and agent prompts; YAML frontmatter for agent metadata. No Ruby code authored in this feature. Existing Ruby (Thor CLI, FormRegistry) is *read* by impl-qa but not modified here. + None new. The agents are Claude Code subagents — runtime is Claude Code itself; no gems, no scripts. Existing project tooling (`eidos` CLI, RSpec, RuboCop) is unchanged. (016-usage-guide)
- Plain files only. `docs/pitch.md`, `docs/usage-guide.md`, `.claude/agents/doc-qa.md`, `.claude/agents/impl-qa.md`, `.claude/commands/doc-qa.md`, `.claude/commands/impl-qa.md`, plus an edit to `CLAUDE.md` and `README.md`. (016-usage-guide)
- Ruby 3.3.5, `# frozen_string_literal: true` on every file + Thor (CLI), existing `Eidos::StoryBibleExporter` (engine class), Jekyll (downstream consumer of published output, not a runtime dependency of this gem) (017-publish-cleanup)
- YAML files on disk under `worlds/<name>/data/` (read-only) and `<dest>/_data/` (write target after the fix) (017-publish-cleanup)
- Ruby 3.3.5, `# frozen_string_literal: true` on every file + existing — Thor (CLI), ruby-openai (LLM), tty-prompt, tty-spinner, rainbow, dotenv, YAML stdlib. No new gems (018-unify-piece-producer)
- YAML files on disk under `worlds/<name>/data/`. New: a `canon` mapping with `revision: N` integer in `world_state.yml`. Modified: every piece's frontmatter (chapter included) carries a hash `id` + `canon_version` (integer or snapshot label) (018-unify-piece-producer)

## Recent Changes
- 011-eidos-sdk-and-installable-cli: Unified `eidos` CLI (`exe/eidos`), Ruby SDK (`Eidos::World`, `Chapter`, `Character`, `Location`, `Bible`, `Canon`), `Eidos.configure` global config, installable gem (`gem install eidos`), new SDK-based `eidos chapter` and `eidos character` subcommands.
- 010-storage-abstraction-layer: Storage abstraction for Story Bible (YamlFile + Memory backends).
