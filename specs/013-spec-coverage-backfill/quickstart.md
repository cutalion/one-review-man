# Quickstart: Feature 013 — Comprehensive Test Coverage & Spec Coverage Tooling

This document walks a contributor through the new controls introduced by this feature. After implementation, this file is the landing page a maintainer reads when they see a coverage-threshold failure or an unexpected prompt-assertion failure in CI.

---

## Running the default spec suite

```bash
cd eidos
MOCK_AI=true bundle exec rspec
```

**What happens**:
1. SimpleCov starts (loaded before any `eidos/**` code), instrumenting `eidos/lib/`.
2. Every spec runs under `MOCK_AI=true` against the wrapped `MockLLMService`.
3. Every LLM call routes through `PromptAssertionHarness`, which fails the enclosing spec if the outgoing prompt carries unfilled placeholders or fired a "Unused placeholders" warning.
4. SimpleCov writes `coverage/index.html` and prints a one-line summary.
5. If overall line coverage for `eidos/lib/` dropped below the committed floor, SimpleCov fails the run.

**Exit status**:
- `0` — all specs passed AND coverage ≥ floor.
- non-zero — a spec failed OR coverage dropped below the floor.

---

## Reading the coverage report

The summary line appears just before `rspec`'s final output:

```
Coverage report generated for RSpec to /path/to/eidos/coverage. XX.XX% covered.
```

For per-file detail, open `eidos/coverage/index.html` in a browser. Uncovered lines are highlighted in red. Search the file tree for files whose coverage percentage surprises you — they're often the ones where new behavior was added without a new spec.

---

## Adjusting the coverage floor

The committed floor is defined in `eidos/spec/support/coverage_setup.rb` as the default of `EIDOS_COVERAGE_FLOOR`. **To raise the floor** (the normal case): edit the default value and commit. The diff makes the change reviewable.

**To temporarily override the floor for one run** (emergency unblocking):

```bash
COVERAGE_THRESHOLD=40 bundle exec rspec
```

When the override is *below* the committed floor, the run prints an audit line to `stderr` before RSpec starts:
```
⚠️  COVERAGE FLOOR OVERRIDDEN: configured=46, this run=40
```
This makes the override visible in CI logs and PR output. Use this only when genuinely unblocking a build; do not commit code that relies on the override.

**Raising the bar for one run** (e.g. sanity-checking before bumping the committed floor):

```bash
COVERAGE_THRESHOLD=70 bundle exec rspec
```

Overrides above the committed floor do **not** print the audit line (nothing is being lowered). If actual coverage is below the override, SimpleCov exits non-zero with `Line coverage (X%) is below the expected minimum coverage (70%)`.

**To disable the threshold check entirely for one run** (e.g. while measuring something):

```bash
COVERAGE_THRESHOLD=0 bundle exec rspec
```

---

## Single-file / directory spec runs

```bash
bundle exec rspec spec/eidos/chapter_generator_spec.rb
bundle exec rspec spec/integration/
```

Coverage is **not measured** in these invocations — the coverage setup detects file/directory arguments in `ARGV` and skips SimpleCov entirely. This prevents misleading "coverage dropped" failures when running just one spec. The prompt-call assertion still runs and still fails on violations.

---

## The runtime prompt-call assertion

Every spec that causes an LLM call — whether directly or via a CLI subprocess — feeds its prompt through `PromptAssertionHarness`. If the prompt contains a `{PLACEHOLDER}` token (single- or double-brace) or if `PromptUtils` emitted a "Unused placeholders" warning while building the prompt, the spec fails with a message like:

```
Prompt assertion failed during MockLLMService#generate_chapter_structured:
  category: unfilled placeholder
  placeholders: CHAPTER_NUMBER
  prompt (first 500 chars): "Write Chapter {CHAPTER_NUMBER} of One Review Man..."
```

**Diagnosis**:
- `unfilled placeholder` → check whether you forgot to pass a key to `PromptUtils.build_prompt`, or whether the template uses `{SINGLE}` syntax without a `prefill_single_brace_placeholders` call upstream.
- `unused placeholder warning` → the template doesn't reference a placeholder you're passing. Either remove the extra key from the fill site, or add the placeholder to the template.

The harness has no opt-out list. The design is intentional: if a spec asserts that a specific `UnfilledPlaceholdersError` *is raised*, wrap just that assertion in `PromptAssertionHarness.disabled { ... }` — used today only by the harness's own self-test spec.

---

## Regression canaries

Three named integration specs exist under `eidos/spec/integration/` specifically to lock in the previously-escaped bugs:

| Spec | Guards against |
|---|---|
| `chapter_number_regression_spec.rb` | "Unused placeholders: CHAPTER_NUMBER" warning during character creation in the `produce chapter` flow |
| `produce_chapter_prompt_flag_spec.rb` | Missing `--prompt` threading: the user's extra guidance not appearing in the prompt sent to the LLM |
| `world_new_target_chapters_residue_spec.rb` | Stale `target_chapters` field in `world new`-created configs or in `world status` output |
| `world_new_interactive_flow_spec.rb` | Over-stubbed interactive flow: scripted-stdin subprocess driver, not `ask`/`yes?` stubs |
| `ip_neutrality_non_orm_world_spec.rb` | ORM vocabulary leaking into prompts for non-ORM worlds |

These specs are **canaries** — they are single-purpose and should never be deleted. If you're tempted to delete one, re-read US3 in `spec.md`.

---

## `BOOK_*` → `STORY_*` migration

Per Clarifications Q2, the four world-config placeholders renamed:

| Old | New |
|---|---|
| `{BOOK_TITLE}` | `{STORY_TITLE}` |
| `{BOOK_GENRE}` | `{STORY_GENRE}` |
| `{BOOK_SETTING}` | `{STORY_SETTING}` |
| `{BOOK_STYLE}` | `{STORY_STYLE}` |

**For existing worlds** (ORM is the only first-party example): `world_config.yml` is migrated in the same PR. The back-compat loader accepts legacy `title:` / `genre:` / `setting:` / `style:` (and `book_*` variants) keys under `generation.localized.<locale>` for one release, emitting a one-shot deprecation notice.

**For new worlds** (`eidos world new`): only `story_*` keys are ever written.

**If you see the deprecation notice**: open the named `world_config.yml` and rename the keys under `generation.localized.<locale>` to `story_title:`, `story_genre:`, `story_setting:`, `story_style:`. The back-compat path is scheduled for removal in a follow-up feature.

---

## IP-neutrality audit log

`specs/013-spec-coverage-backfill/audit-log.md` records every ORM-specific leak that was found in `eidos/lib/` and shipped prompts during this feature, along with the decision taken (generalize / parameterize / relocate / document / remove) and the destination of any relocated content. When future maintainers need to know *where* an ORM-specific piece of content lives after the audit, this file is the answer.

---

## Measuring baseline coverage (one-time, pre-implementation)

Before this feature's own work lands, baseline coverage must be measured on the pre-feature commit (`4966b5f`) with a scratch SimpleCov config. The value is rounded down to the nearest integer percent and committed as the default `EIDOS_COVERAGE_FLOOR`. This is T001 in `tasks.md`.
