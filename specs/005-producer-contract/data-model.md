# Data Model: Producer Contract Interface

## Entities

### Producer (Module)

The common interface all content producers implement.

| Attribute | Description |
|-----------|-------------|
| name | Unique identifier for the producer (Symbol, e.g., `:chapter`) |
| description | Human-readable description of what this producer creates |
| default_output | Default output path relative to project root |

**Behavior contract**:
- `produce(snapshot:, config:, output:)` — Main entry point. Returns ProducerResult.
- `validate!(snapshot:, config:, output:)` — Pre-flight check. Raises on invalid inputs.

**Registry (class-level)**:
- `Producer.register(name, klass)` — Add producer to registry
- `Producer.find(name)` — Look up producer by name
- `Producer.all` — List all registered producers

### ProducerResult (Value Object)

The outcome of a producer invocation.

| Field | Type | Description |
|-------|------|-------------|
| success | Boolean | Whether production completed without errors |
| output_path | String | Absolute path where artifacts were written |
| canon_version | Hash or String | Canon version reference used (hash with snapshot/version/branch, or "unversioned") |
| artifacts | Array<String> | List of file paths created/modified |
| error | String or nil | Error message if success is false |

**State transitions**: None — immutable value object created once at end of production.

### ProducerRegistry (Class-level store)

Internal registry mapping producer names to implementation classes.

| Key | Value |
|-----|-------|
| Symbol (e.g., `:chapter`) | Class that includes Producer module |

**Lifecycle**: Populated at require-time when producer files are loaded. Read-only after that.

## Relationships

```
Producer (module)
  ├── included by → ChapterProducer
  ├── included by → [future: InstagramProducer]
  └── class-level registry → maps names to classes

ChapterProducer
  └── delegates to → ChapterGenerator (existing)
       ├── uses → LLMService (injected)
       ├── uses → OutputAdapter (injected, configured with output path)
       ├── uses → PromptProvider (injected)
       └── uses → SnapshotStore + CanonVersionReference
```

## Storage

No new on-disk storage. The producer interface is a runtime abstraction. Output artifacts are written by the underlying generators using their existing adapters. The only change is that `canon_version` metadata (already implemented in feature 004) is guaranteed to be present in all producer output.
