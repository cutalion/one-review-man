# Contract: Coverage CLI behavior

The default test entry point is `bundle exec rspec`. This contract describes what the command prints and how it exits, depending on invocation shape.

## Environment variables

| Variable | Type | Default | Meaning |
|---|---|---|---|
| `COVERAGE_THRESHOLD` | integer | — | Per-run override of the committed floor. `0` disables threshold enforcement entirely for that run. |
| `SIMPLECOV` | `"false"` or unset | unset | Hard kill-switch — disables SimpleCov loading even for full-suite runs. Escape hatch for debugging Ruby loading. |
| `MOCK_AI` | `"true"` or unset | `"true"` in CI/dev | Existing control; unchanged by this feature. |

## Invocation shapes

### 1. Full-suite run (canonical)

```
bundle exec rspec
```

- SimpleCov loads, measures `eidos/lib/` only.
- Prints a one-line coverage summary to `$stdout` at the end (via the SimpleFormatter):
  ```
  Coverage report generated for RSpec to /.../eidos/coverage. NN.NN% covered.
  ```
- Writes full HTML report to `eidos/coverage/index.html`.
- **Exit 0** if coverage >= `effective_floor`.
- **Exit non-zero** if coverage < `effective_floor`, with SimpleCov's standard message naming threshold, actual, and files most responsible.

### 2. Full-suite run with lowered floor

```
COVERAGE_THRESHOLD=70 bundle exec rspec
```

- Prints audit line to `$stderr` *before* RSpec banner:
  ```
  ⚠️  COVERAGE FLOOR OVERRIDDEN: configured=<committed>, this run=70
  ```
- Otherwise identical to (1), using `70` as the effective floor.

### 3. Full-suite run with check disabled

```
COVERAGE_THRESHOLD=0 bundle exec rspec
```

- Audit line to `$stderr` as in (2).
- Coverage is still *measured and reported*, but the threshold check is skipped (no fail from low coverage).
- Exits 0 regardless of coverage percentage (subject to normal spec pass/fail).

### 4. Single-file / directory run

```
bundle exec rspec spec/eidos/world_spec.rb
bundle exec rspec spec/integration/
```

- SimpleCov does **not** load (`coverage_setup.rb` detects file/dir args in `ARGV`).
- No coverage summary printed; no threshold enforcement (FR-004).
- Exit status is purely the spec pass/fail result.

### 5. CI mode

Same as (1). CI must not set `COVERAGE_THRESHOLD` below the committed floor unless explicitly unblocking a documented emergency (the audit line surfaces the override in PR logs).

## Exit status matrix

| Scenario | Exit |
|---|---|
| All specs pass, coverage ≥ floor | 0 |
| All specs pass, coverage < floor (full-suite) | non-zero (SimpleCov) |
| All specs pass, coverage < floor, `COVERAGE_THRESHOLD=0` | 0 |
| All specs pass, single-file invocation | 0 |
| Any spec fails | non-zero (RSpec) |
| `COVERAGE_THRESHOLD` is not an integer | non-zero (startup error) |

## Failure message contract

When coverage falls below the floor in a full-suite run, SimpleCov's default output is sufficient:
```
Coverage (XX.XX%) is below the expected minimum coverage (YY.YY%).
```
Plus the per-file table that SimpleCov writes to stdout and HTML. FR-002 and SC-002 are satisfied by this default behavior — no custom formatter is required.
