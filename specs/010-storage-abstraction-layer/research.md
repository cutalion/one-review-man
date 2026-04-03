# Research: Storage Abstraction Layer

## Decision 1: Contract Granularity

**Decision**: Three separate contracts — Entity Storage, Revision Storage, Snapshot Storage.

**Rationale**: The current codebase already has three distinct classes (StoryBible, RevisionStore, SnapshotStore) with independent lifecycles. RevisionStore is optional (Bible CLI doesn't use it). SnapshotStore is created on-demand and never injected into core classes. Keeping them separate preserves this natural separation.

**Alternatives considered**:
- Single unified contract: Rejected — would force backends to implement all three concerns even when only one is needed.
- Two contracts (entity+search, revision+snapshot): Rejected — revision and snapshot have different lifecycles and are independently optional.

## Decision 2: Where to Place the Abstraction Boundary

**Decision**: The abstraction sits at the level of StoryBible's private filesystem methods and the entirety of RevisionStore/SnapshotStore. StoryBible delegates to an EntityStorage adapter for its CRUD/search operations. RevisionStore and SnapshotStore become the contracts themselves, with their current implementations extracted into filesystem-backed adapters.

**Rationale**: 
- StoryBible has 6 private filesystem methods (`load_yaml_file`, `write_yaml_file`, `load_entities_from_dir`, `touch_yaml_file`) plus `File.join` path construction scattered through public methods. The public API (characters, save_character, facts, search_facts, etc.) stays unchanged.
- RevisionStore (99 lines) and SnapshotStore (~180 lines) are already clean interfaces — their public APIs *are* the contract. The implementation just needs to be extractable behind the same interface.

**Alternatives considered**:
- Abstracting at a higher level (replacing StoryBible entirely): Rejected — StoryBible has business logic (caching, frozen checks, revision recording) that shouldn't be duplicated per backend.
- Abstracting only StoryBible: Rejected — RevisionStore and SnapshotStore also have filesystem coupling.

## Decision 3: Snapshot Data Format

**Decision**: Snapshots return entity data as hashes (not filesystem paths). The file backend reads from disk into hashes; the memory backend returns hashes directly.

**Rationale**: `StoryBible.from_snapshot` currently creates a read-only StoryBible pointing at a snapshot directory. With the abstraction, it should instead receive entity data and wrap it in a frozen StoryBible. This removes the filesystem coupling from the contract.

**Alternatives considered**:
- Path-based (non-file backends materialize to temp dirs): Rejected — adds unnecessary I/O and complexity.
- Dual mode (path or data): Rejected — adds complexity for no benefit.

## Decision 4: Error Handling

**Decision**: Let exceptions propagate as-is from backends.

**Rationale**: Single-process CLI tool. Current behavior already propagates filesystem exceptions. No retry logic needed for initial version.

## Decision 5: Configuration Mechanism

**Decision**: Storage backend is configured in `data/settings.yml` under a new `storage` key. Default is `yaml_file` (current behavior). The backend is resolved at store instantiation time in the CLI command helper methods.

**Rationale**: `settings.yml` already exists and holds LLM configuration. Adding storage configuration here is natural. The CLI helper methods (`build_revision_store`, etc.) are the centralized instantiation points — ideal places to read configuration and select the backend.

**Alternatives considered**:
- Environment variable: Rejected — less discoverable, doesn't persist per-project.
- Constructor argument on every class: Rejected — too much plumbing; configuration is a project-level concern.

## Decision 6: Instantiation Sites

**Analysis of current codebase** (from research):

| Store | Instantiation Sites | Pattern |
|-------|---------------------|---------|
| StoryBible | 13 (5 in lib/, 3 in CLI, 5 in spec/) | Created per-command, sometimes with RevisionStore |
| RevisionStore | 7 (3 in CLI, 4 in spec/) | Built by `build_revision_store` helper in CLI |
| SnapshotStore | 11 (4 in lib/, 3 in CLI, 4 in spec/) | Created on-demand, inline |

**Decision**: Introduce a `StorageFactory` that reads settings and returns the appropriate adapter instances. CLI helpers delegate to the factory. Tests can use the factory with explicit backend selection, or construct adapters directly.

## Codebase Dependency Map

```
CLI Commands
  └─> build_* helpers (Canon CLI, Bible CLI, Produce CLI)
        └─> StoryBible.new(project_root:, revision_store:, ...)
        └─> RevisionStore.new(revisions_path:)
        └─> SnapshotStore.new(story_bible_path:)

StoryBible
  ├─> private: load_yaml_file, write_yaml_file, load_entities_from_dir
  ├─> optional: RevisionStore (injected)
  ├─> optional: ImpactAnalyzer (injected, uses RevisionStore)
  └─> optional: BranchManager (injected, uses RevisionStore)

RevisionStore
  └─> direct FS: FileUtils.mkdir_p, File.write, Dir.glob, File.read, YAML.safe_load

SnapshotStore
  └─> direct FS: FileUtils.mkdir_p, FileUtils.cp_r, FileUtils.cp, File.write, Dir.glob, File.read
```
