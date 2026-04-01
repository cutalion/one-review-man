# Research: Producer Contract Interface

## Decision 1: Interface mechanism — base class vs module

**Decision**: Ruby module with `included` hook that adds both instance and class methods. Producers `include BookCore::Producer` rather than inherit from a base class.

**Rationale**: ChapterGenerator already inherits no base class and includes `WorldUtils` as a module. A module preserves this pattern and avoids forcing single inheritance. The module can enforce the contract via `def self.included(base)` hooks that register required methods.

**Alternatives considered**:
- Abstract base class: Would require ChapterGenerator to change its inheritance chain. Ruby doesn't have abstract classes natively, so enforcement would still rely on runtime checks.
- Duck typing only: No enforcement, relies on convention. Too loose for a contract that must hold across multiple producers.

## Decision 2: Retrofit approach — wrapper vs inline

**Decision**: Thin wrapper class `ChapterProducer` that delegates to the existing `ChapterGenerator`. ChapterGenerator internals stay largely unchanged.

**Rationale**: ChapterGenerator is complex (~500 lines) with deep integration into story bible, world utils, output adapters, and book config. Rewriting it to directly implement the producer interface risks regressions. A wrapper translates between the producer contract's `produce(snapshot:, config:, output:)` signature and ChapterGenerator's existing constructor/method signatures.

**Alternatives considered**:
- Inline refactor: Modify ChapterGenerator to directly implement Producer module. Higher risk, larger diff, harder to review. Benefits (removing one indirection layer) don't justify the risk for this feature.
- Adapter pattern with separate class: Same as chosen approach — "wrapper" and "adapter" are the same thing here.

## Decision 3: Output location plumbing

**Decision**: The producer contract passes `output:` to the wrapper. ChapterProducer configures the output adapter with the specified path before delegating to ChapterGenerator. ChapterGenerator already accepts an injected `output_adapter`, so the wrapper constructs one pointed at the right directory.

**Rationale**: ChapterGenerator delegates all file writes to `@output_adapter`. The adapter's `setup_project(project_root)` call determines where files land. By constructing an adapter with a custom root or overriding `setup_project`, we control output location without modifying ChapterGenerator internals.

**Alternatives considered**:
- Add `output_dir` parameter to ChapterGenerator constructor: Leaks producer concerns into the generator. The generator shouldn't know about the producer contract.
- Post-move: Generate to default location, then move files. Fragile and wasteful.

## Decision 4: ProducerResult design

**Decision**: Simple Struct-based value object (like `Models::Snapshot`). Fields: `success`, `output_path`, `canon_version`, `artifacts` (array of file paths), `error` (nil on success).

**Rationale**: Follows existing pattern in codebase (Snapshot uses Struct). Keeps it lightweight — no need for a full class hierarchy for what is essentially a data bag.

**Alternatives considered**:
- Return raw hash: Less self-documenting, no method access.
- Exception-only flow: Raise on failure, return nothing on success. Loses the ability to return metadata about what was produced.

## Decision 5: Registry design

**Decision**: Class-level registry on the Producer module itself. `Producer.register(name, klass)` and `Producer.find(name)`. Producers self-register when their file is loaded via `register :chapter, ChapterProducer` at class definition time.

**Rationale**: Minimal infrastructure. No configuration files, no scanning, no autoloading magic. When a producer file is required, it registers. The CLI or tests can call `Producer.find(:chapter)` to get the class.

**Alternatives considered**:
- YAML configuration file listing producers: Over-engineered for in-process registration.
- Convention-based autoloading: Requires file naming conventions and directory scanning. Too much magic for 1-2 producers.

## Decision 6: CLI wiring

**Decision**: The existing `generate chapter` CLI command continues to construct ChapterGenerator directly (or via ChapterProducer). No new CLI subcommand in this feature. The `--output` flag is added to `generate chapter` and passed through to the producer/adapter.

**Rationale**: Clarification Q1 decided to keep CLI surface unchanged. The producer contract is internal architecture. The `--output` flag (FR-007) is the only visible CLI change, and it's additive.

**Alternatives considered**:
- New `book produce chapter` command: Deferred per clarification. Will be added when a second producer arrives.
