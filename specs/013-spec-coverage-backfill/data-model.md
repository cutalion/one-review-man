# Data Model: Comprehensive Test Coverage & Spec Coverage Tooling

This feature is primarily a test-harness + audit work stream, not a feature that introduces persistent domain state. The "data" that matters is:

1. **Configuration values** (coverage threshold, override env var)
2. **In-test-session entities** (the assertion-harness failure record)
3. **The durable audit log** (one row per IP-neutrality finding)
4. **The `world_config.yml` schema change** (BOOK_* → STORY_* key rename with back-compat)

No database tables, no new persistent stores, no state machines of any consequence.

---

## E1. Coverage Threshold (configuration)

**Scope**: Single integer, committed to the repo as the default of `EIDOS_COVERAGE_FLOOR` inside `spec/support/coverage_setup.rb`.

**Fields**:

| Field | Type | Source | Notes |
|---|---|---|---|
| `configured_floor` | Integer (0..100) | Committed default in `coverage_setup.rb` | Single source of truth; changes are a one-line diff |
| `override` | Integer (0..100) or nil | `ENV['COVERAGE_THRESHOLD']` | Per-run override; `0` disables the check for that run |
| `effective_floor` | Integer (0..100) | Computed: `override if override else configured_floor` | What the suite actually enforces |

**Validation rules**:
- `configured_floor` MUST be in `[0, 100]`.
- `override`, if present, MUST parse as an integer; otherwise the run fails at startup with a clear error message (no silent fallback).
- When `override < configured_floor`, an audit line prints to `$stderr` (FR-003).

**Lifecycle**: Read at `bundle exec rspec` startup (in `coverage_setup.rb`); never mutated at runtime.

---

## E2. Prompt Assertion Failure (in-memory, per-spec-failure)

**Scope**: In-memory object raised when the prompt-call harness detects a violation. Lives only for the duration of the spec run; RSpec formats it as a regular test failure.

**Fields**:

| Field | Type | Notes |
|---|---|---|
| `prompt` | String | The full prompt string that triggered the failure (truncated to ~500 chars in the message) |
| `unfilled_placeholders` | Array<String> | Deduped list of unfilled tokens (both `{SINGLE}` and `{{DOUBLE}}` forms, no braces in values) |
| `emitted_warnings` | Array<String> | Captured `"⚠️  Warning: Unused placeholders provided: ..."` lines |
| `caller_desc` | String | Description of where the call originated (e.g. `"MockLLMService#generate_chapter_structured"` + the enclosing RSpec example description, if available) |

**Validation rules**:
- Exactly one of `unfilled_placeholders.any?` or `emitted_warnings.any?` is sufficient to raise — both signal a distinct failure category.
- The failure message MUST name the category explicitly: `"unfilled placeholder"` vs `"unused placeholder warning"` (FR-006).

**Lifecycle**: Constructed at the moment of detection inside `PromptAssertionHarness.assert!`; raised as a `PromptAssertionFailure < StandardError`; RSpec surfaces it with the enclosing spec's context in the failure backtrace.

---

## E3. Audit Log Row (durable, in-repo)

**Scope**: One row per finding in `specs/013-spec-coverage-backfill/audit-log.md`, persisted as a markdown table. This is the US5 artifact (FR-019).

**Fields**:

| Field | Type | Notes |
|---|---|---|
| `file_line` | String | e.g. `eidos/lib/eidos/chapter_generator.rb:147` — the original leak site at the time of the audit |
| `original` | String | Short quote or description of the ORM-specific content that was found |
| `decision` | Enum | One of: `generalize` / `parameterize` / `relocate` / `document-as-intentional` |
| `new_location` | String or `—` | Where the ORM-specific content lives now (e.g. `worlds/one-review-man/data/character_aliases.yml`); `—` if generalized/removed |
| `commit` | String | Short SHA of the commit that applied the change |

**Validation rules**:
- `file_line` MUST reference the pre-audit commit so it's reproducible against the historical state.
- `decision` MUST match the enum; reviewers can scan the table for `relocate` rows to audit the ORM content tree.
- The file MUST be committed in the same PR as the code changes it describes.

**Lifecycle**: Append-only during implementation; not mutated after this feature ships.

---

## E4. `world_config.yml` schema: `BOOK_*` → `STORY_*` migration

**Scope**: The `generation.localized.<locale>` section of each world's `world_config.yml`.

**Before**:
```yaml
generation:
  localized:
    en:
      title: "..."
      # (the template-facing fields used {BOOK_TITLE/GENRE/SETTING/STYLE}
      #  placeholders internally; no explicit BOOK_* keys in YAML for most worlds,
      #  but the template fill code referenced them)
```

**After**:
```yaml
generation:
  localized:
    en:
      story_title: "..."
      story_genre: "..."
      story_setting: "..."
      story_style: "..."
```

**Back-compat read rule** (FR-021): If `story_<field>` is absent but the legacy `book_<field>` or `title`/`genre`/`setting`/`style` equivalent exists, the loader maps it to `story_<field>` and emits a single deprecation notice per config file per run:

```
⚠️  DEPRECATED: worlds/one-review-man/data/world_config.yml uses legacy `book_*` keys.
   These will be read as `story_*` for this release; please rename in the source file.
   See specs/013-spec-coverage-backfill/spec.md Clarifications Q2.
```

**Validation rules**:
- New worlds scaffolded by `eidos world new` MUST emit only `story_*` keys (per FR-021).
- The back-compat read path has a dedicated spec that loads a synthetic legacy config, asserts the values flow through correctly, and asserts the deprecation notice is emitted exactly once.

**Lifecycle**: Read on every CLI invocation that touches world config. Writes (via `eidos world new`, `eidos world edit`) only emit the new keys.

---

## Non-entities (explicitly out of scope)

- No new database schema, no new snapshot/revision schema changes.
- No change to the Canon Integrity contract (Principle IV).
- No change to the Producer Contract (Principle II).
- No new credentials / settings beyond the `COVERAGE_THRESHOLD` env var.
