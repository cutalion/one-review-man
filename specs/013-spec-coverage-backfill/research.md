# Phase 0 Research: Comprehensive Test Coverage & Spec Coverage Tooling

All Technical Context fields are resolved — no NEEDS CLARIFICATION remaining after the `/speckit.clarify` pass. This document records the narrow design/tooling decisions that govern implementation.

---

## R1: SimpleCov — tool choice and configuration shape

**Decision**: Use SimpleCov ~> 0.22 as a `group :development, :test` Gemfile entry. Configure it at the very top of `spec_helper.rb` (before any `eidos/**` `require` happens) via a dedicated `spec/support/coverage_setup.rb` that is required at the top of the file, not from RSpec's configure block.

**Rationale**:
- SimpleCov is the de-facto Ruby coverage tool; ships with Ruby's built-in `Coverage` stdlib as the engine.
- It must be started *before* the code being measured is loaded — placing it in `spec/support/coverage_setup.rb` with a top-of-file `require` in `spec_helper.rb` guarantees that ordering.
- Threshold enforcement is a first-class feature (`SimpleCov.minimum_coverage`), including per-file vs. global.

**Alternatives considered**:
- **deep-cover**: more accurate branch coverage, but significantly slower and noisier with false positives on metaprogrammed classes (heavy in `eidos/lib/eidos/cli/*`). Rejected.
- **coverband**: designed for production coverage; overkill for a spec-time gate. Rejected.
- **Ruby's bare `Coverage` stdlib**: we'd reimplement SimpleCov. Rejected.

**Configuration shape** (`spec/support/coverage_setup.rb`):

```ruby
# Only enable coverage for full-suite runs. Single-file invocations
# (e.g. `bundle exec rspec path/to/one_spec.rb`) skip coverage entirely
# to avoid misleading "coverage dropped" failures.
def coverage_enabled?
  return false if ENV['SIMPLECOV'] == 'false'
  return false if ENV['COVERAGE'] == 'false'
  # ARGV contains individual files only when rspec is invoked with a file path.
  # When rspec runs with no file args (or with --pattern), ARGV is empty of paths.
  has_file_arg = ARGV.any? { |a| a.end_with?('_spec.rb') || File.directory?(a) }
  !has_file_arg
end

if coverage_enabled?
  require 'simplecov'

  configured_floor = Integer(ENV.fetch('EIDOS_COVERAGE_FLOOR', '0'))
  override = ENV['COVERAGE_THRESHOLD']
  effective = override ? Integer(override) : configured_floor

  if override && Integer(override) < configured_floor
    warn "⚠️  COVERAGE FLOOR OVERRIDDEN: configured=#{configured_floor}, this run=#{override}"
  end

  SimpleCov.start do
    enable_coverage :line
    track_files 'lib/**/*.rb'
    add_filter '/spec/'
    add_filter '/exe/'
    add_filter '/bin/'
    add_filter %r{lib/eidos/version\.rb\z}
    minimum_coverage effective unless effective.zero?
    formatter SimpleCov::Formatter::MultiFormatter.new([
      SimpleCov::Formatter::SimpleFormatter, # console summary line
      SimpleCov::Formatter::HTMLFormatter    # coverage/index.html
    ])
  end
end
```

The `EIDOS_COVERAGE_FLOOR` constant is the single committed value (per FR-003). It lives in one place: an `ENV.fetch` default baked into the Rakefile or the support file itself. Changes to the floor are a single-line diff.

**Single-file run detection**: The check inspects `ARGV` for arguments ending in `_spec.rb` or matching an existing directory. If any is found, coverage is disabled for that run (FR-004). This is more robust than checking `RSpec.configuration.files_to_run.size == 1` because RSpec's configuration is populated *after* `spec_helper` is loaded.

---

## R2: Runtime prompt-call assertion — where it hooks in

**Decision**: Wrap `MockLLMService` (in `spec/support/mock_llm_service.rb`) so every public method that accepts a prompt string runs the prompt through a shared assertion helper before delegating to the real mock behavior. The assertion is enforced for all specs by default (no opt-in). Capture emitted warnings by redirecting `$stdout` to a recording IO for the duration of prompt construction — but do this narrowly, only around the wrapped methods, so spec output stays readable.

**Rationale**:
- MockLLMService is the narrow waist every specless-run-produced prompt flows through. The assertion lives at exactly the point where the string is about to leave the system-under-test.
- `PromptUtils.build_prompt` already raises `UnfilledPlaceholdersError` when `{{DOUBLE}}` placeholders remain — so half the check is already enforced. The new work is: (a) detect *single-brace* `{SINGLE}` stragglers (which `PromptUtils` ignores — this is what caused the `CHAPTER_NUMBER` bug), and (b) capture the "Unused placeholders" warning that `PromptUtils` emits to `$stdout` via `puts`.
- Modifying `PromptUtils` to write warnings to `$stderr` (minor change) lets the harness capture them without redirecting `$stdout` globally.

**Alternatives considered**:
- **RSpec `before(:each)` global hook**: unclear how to intercept mid-method state. Rejected.
- **Monkey-patch `PromptUtils.build_prompt` under test**: couples the assertion to internals, breaks if callers bypass `PromptUtils`. Rejected.
- **Static file-scan meta-spec** (the original US1 design): rejected in Clarifications Q1 — fragile, forces a second registry.

**Detection contract**:

```ruby
module Eidos
  module Spec
    module PromptAssertionHarness
      SINGLE_BRACE_TOKEN = /\{([A-Z_][A-Z0-9_]*)\}/.freeze
      DOUBLE_BRACE_TOKEN = /\{\{([A-Z_][A-Z0-9_]*)\}\}/.freeze

      # Call this on every prompt string entering the mock LLM service.
      # Raises if the string carries unfilled placeholder tokens.
      # `warnings` is the list of "⚠️  Warning: Unused placeholders..."
      # lines captured by the harness while the prompt was being built.
      def self.assert!(prompt, warnings:, caller_desc:)
        unfilled = extract_unfilled(prompt)
        unused   = extract_unused_warnings(warnings)

        if unfilled.any? || unused.any?
          raise PromptAssertionFailure.new(
            prompt: prompt,
            unfilled: unfilled,
            unused_warnings: unused,
            caller_desc: caller_desc
          )
        end
      end

      def self.extract_unfilled(prompt)
        double = prompt.scan(DOUBLE_BRACE_TOKEN).flatten
        # Remove double-brace matches before single-brace scan so we don't
        # report `{FOO}` twice when the original template was `{{FOO}}`.
        remainder = prompt.gsub(DOUBLE_BRACE_TOKEN, '')
        single = remainder.scan(SINGLE_BRACE_TOKEN).flatten
        (double + single).uniq
      end

      def self.extract_unused_warnings(warnings)
        warnings.select { |w| w.include?('Unused placeholders') }
      end
    end

    class PromptAssertionFailure < StandardError
      # ... builds a failure message naming category + placeholders + caller
    end
  end
end
```

---

## R3: Thor CLI + stdin scripting for interactive specs

**Decision**: For US4's scripted-stdin flow, shell out to the `eidos/exe/eidos` binary as a subprocess via `Open3.popen3`, writing the scripted answer stream to stdin and asserting on exit status + the final on-disk artifacts. Add a per-spec hard timeout (e.g. 15 s via `Timeout.timeout`) so a misordered stdin never hangs the suite (Edge Case).

**Rationale**:
- Thor's `ask`/`yes?` delegate to `$stdin.gets` and `HighLine`/`tty-prompt`, which happily read from a piped stdin. Driving via subprocess is the most realistic reproduction of the user's experience and sidesteps the RSpec-level stubbing trap (the whole point of US4).
- The existing `spec_helper.rb` already sets `RUBYOPT` to inject the mock LLM into subprocess CLI invocations (line 11), so this pattern is pre-wired.

**Alternatives considered**:
- **In-process invocation via `Eidos::CLI::Main.start`** with `$stdin = StringIO.new(...)`: simpler, but `tty-prompt` checks for a TTY on `$stdin` and falls back to non-interactive prompts, which doesn't exercise the real code path. Rejected for US4 (still fine for simpler flows).
- **`pty`-based driver with expect-style scripting**: overkill; we only need blind write-then-assert. Rejected.

**Harness location**: `spec/support/stdin_driver.rb` exports a `drive_cli(argv:, input_lines:, timeout: 15)` helper used by both US4 and US3's interactive-flow integration spec.

---

## R4: Baseline coverage measurement and threshold selection

**Decision**: Measure baseline coverage as the *first* implementation task (T001). Round down to the nearest whole percent. Commit that value as the initial `EIDOS_COVERAGE_FLOOR` default. Subsequent tasks that *add* specs raise the measured value, but the committed floor stays at the baseline for this feature's scope — raising it is tracked as future work (per Assumption).

**Rationale**:
- Per FR-002/FR-003 + Assumption: adopting the feature must not immediately block the suite. A baseline-rounded-down floor guarantees green-on-merge.
- Measuring up front lets the plan name a concrete starting point instead of a hypothetical.

**Alternatives considered**:
- **Pick an aspirational number (e.g. 80%)**: violates the Assumption; immediately red on merge. Rejected.
- **Measure post-all-new-specs and use that**: would silently include this feature's own new specs, making the number unrepresentative of steady-state. Rejected — the baseline should reflect the codebase's true state before this feature.

**Baseline protocol (T001)**:
1. On the pre-feature commit (`4966b5f`), run `MOCK_AI=true SIMPLECOV=force bundle exec rspec` with a scratch SimpleCov config.
2. Read the reported percentage from `coverage/.last_run.json`.
3. Round down to the nearest integer percent; record in `research.md` as an appendix and set as the default in `coverage_setup.rb`.

---

## R5: `BOOK_*` → `STORY_*` placeholder migration strategy

**Decision**: Execute as a mechanical two-step migration:

1. **Step A — rename the data keys.** In `world_config.yml` loader (`lib/eidos/world_config.rb`), support both key shapes on read: if a `STORY_*` key is absent but a `BOOK_*` key is present, use the `BOOK_*` value and emit a single deprecation notice per config load (keyed by file path so multiple worlds don't spam). Writers only ever emit `STORY_*` keys. The ORM `worlds/one-review-man/data/world_config.yml` is migrated in the same PR.
2. **Step B — rename the template placeholders.** Every shipped template under `eidos/lib/eidos/prompts/` has `{BOOK_TITLE}` → `{STORY_TITLE}` etc. The engine fill code passes `STORY_TITLE: world_config.story_title` (where `.story_title` is the new accessor). The existing `prefill_single_brace_placeholders` workaround stays in place for this migration but is explicitly tagged for removal in a follow-up feature.

**Rationale**:
- Back-compat read (Clarifications Q2) guarantees the ORM and any hypothetical external users' existing configs keep loading.
- Mechanical rename + runtime prompt assertion = if anyone forgets to rename a template, the runtime assertion catches it on the first spec that exercises the fill path. No risk of silent partial migration.

**Discovery inventory** (ORM leak sites enumerated in `spec.md` edge cases; authoritative list lives in `audit-log.md` after implementation):

| File | Symptom | Decision |
|---|---|---|
| `chapter_generator.rb:147` | fallback `'Write Chapter {CHAPTER_NUMBER} of a programming comedy story'` | generalize → `'Write Chapter {CHAPTER_NUMBER} of {STORY_GENRE}'` |
| `chapter_generator.rb:340` | path `books/one-review-man/_chapters` (legacy) | remove (unused — confirm via grep + spec) |
| `chapter_generator.rb:747` | `find_character_real_name(chars, 'One Review Man')` | relocate → ORM-world `character_aliases.yml` override |
| `world_config.rb:247` | `title.include?('One Review Man') \|\| title.include?('Ванревьюмэн')` | remove (dead branch — replaced by story-type detection via config) |
| `writer_agent.rb:123` | default `'programming comedy book'` framing | parameterize → `world_config.story_description` |
| `lib/eidos/prompts/*.txt` | `{BOOK_TITLE}`, `{BOOK_GENRE}`, `{BOOK_SETTING}`, `{BOOK_STYLE}` | rename → `{STORY_*}` |

Each row becomes a row in `audit-log.md` with the actual code-change commit SHA.

---

## R6: Emitting the coverage override audit line

**Decision**: The `COVERAGE FLOOR OVERRIDDEN:` line (FR-003) is printed to `$stderr` inside `coverage_setup.rb` at startup. Printing it before SimpleCov starts means it shows up *before* RSpec's output banner, making it the first thing a reviewer sees when scrolling a CI log.

**Format**: `⚠️  COVERAGE FLOOR OVERRIDDEN: configured=<floor>, this run=<override>` — matches the warning glyph used by `PromptUtils` for visual consistency.

---

## Resolved Clarifications Recap (from spec.md)

| Q | A |
|---|---|
| Q1 file-scan vs runtime | Runtime assertion at LLM call boundary |
| Q2 `{BOOK_*}` disposition | Rename to `{STORY_*}` with one-release back-compat read |
| Q3 coverage denominator | `eidos/lib/` only (no `exe/`, `bin/`, `version.rb`) |
| Q4 override env var | `COVERAGE_THRESHOLD=<int>`, `0` disables, audit line to stderr when below floor |
| Q5 audit artifact | Versioned `specs/013-spec-coverage-backfill/audit-log.md` |

All Phase 0 unknowns resolved. Proceeding to Phase 1.

---

## Appendix: Baseline Coverage Measurement (T001 result)

**Measured on**: commit `4966b5f` (`feat(012): SeedExtractor + UX fixes for world new / produce chapter`), the pre-feature tip.

**Method**: Added `gem 'simplecov', '~> 0.22', require: false` to a scratch Gemfile in a detached git worktree, inserted a minimal `SimpleCov.start` block at the top of `spec/spec_helper.rb` (same filter shape as R1: `track_files 'lib/**/*.rb'`, exclude `/spec/`, `/exe/`, `/bin/`, `lib/eidos/version.rb`), and ran `MOCK_AI=true bundle exec rspec`.

**Result**:

| Metric | Value |
|---|---|
| Line coverage | **46.81%** (3056 / 6528 tracked lines) |
| Examples | 610 (0 failures) |
| Wall-clock runtime | 26.78 s |

**Rounded-down integer floor** (per protocol): **46%**.

**Runtime baseline** for SC-007 (≤ 2×): **53.56 s**.

The 46% floor is baked into `coverage_setup.rb` as the default of `EIDOS_COVERAGE_FLOOR` (T015). The runtime baseline is what T044 compares against.
