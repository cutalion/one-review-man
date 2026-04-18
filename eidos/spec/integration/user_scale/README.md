# User-scale integration suite

These specs shell `exe/eidos` end-to-end via `Open3.capture3` and assert on
**disk artifacts** — file contents, directory structure, YAML shape — not
method calls.

## Invocation

```bash
cd eidos
MOCK_AI=true bundle exec rspec --exclude-pattern "" spec/integration/user_scale/
```

This suite is **excluded from the default `rspec` run** via `eidos/.rspec`
(`--exclude-pattern`). Pass `--exclude-pattern ""` (empty override) plus
the target directory, or point rspec at individual files, to invoke it.

## Conventions

- Every spec uses `Eidos::Spec::IntegrationWorldBuilder.build_world(...)` to
  scaffold a temp world. Do **not** instantiate `Eidos::CLI::*` classes
  directly — shell the binary.
- Each scenario creates and cleans up its own `Dir.mktmpdir`. No state
  leaks to `worlds/`.
- `MOCK_AI=true` is set per-spec before shelling when the scenario
  exercises content production. Named mocks are selected via
  `MOCK_RESPONSE=<key>` — see `eidos/spec/support/mock_responses.yml`.

## Background

Added in feature 015-scaffold-hardening to close the gap identified in
the 014 postmortem (§3.2): unit tests mocked too cleanly and missed six
Tier-1 defects. This suite exists to catch scaffolding regressions,
silent-fallback classes, and canon-delta drops at the user scale.
