# Research: Canon Versioning and Snapshots

**Date**: 2026-04-01
**Branch**: `004-canon-versioning`

## Research Areas

### 1. Snapshot Storage Strategy

**Decision**: Store each snapshot as a directory containing copied YAML files, plus a manifest.

**Rationale**: The existing `BranchManager` already uses this exact pattern — `copy_canon_data` copies characters/, locations/, facts.yml, relationships.yml, plot_threads.yml into a subdirectory. Snapshots follow the same approach but are immutable (no writes after creation).

**Alternatives considered**:
- **Single YAML file per snapshot** (serialize all entities into one file): Rejected because it diverges from existing patterns and makes partial reads harder.
- **Replay from RevisionStore**: Rejected — RevisionStore tracks per-entity changes, not global state. Reconstructing full state would require scanning all entities and finding the right revision for each at a point in time, which is complex and fragile.
- **Git-based tagging**: Rejected — would couple canon versioning to git, which is an external dependency not owned by the engine.

### 2. Snapshot Directory Layout

**Decision**: Store snapshots under `data/story_bible/snapshots/<version>-<name>/`

```
data/story_bible/snapshots/
├── _index.yml                     # Global manifest: list of all snapshots
├── 001-initial/
│   ├── manifest.yml               # Per-snapshot metadata
│   ├── characters/
│   │   ├── kenji_yamamoto.yml
│   │   └── ...
│   ├── locations/
│   │   └── ...
│   ├── facts.yml
│   ├── relationships.yml
│   └── plot_threads.yml
└── 002-after-chapter-10/
    ├── manifest.yml
    └── ... (same structure)
```

**Rationale**: Mirrors `branches/` layout. Version prefix ensures filesystem ordering matches creation order. The `_index.yml` file provides a quick lookup without scanning directories.

### 3. Loading a Snapshot into StoryBible

**Decision**: Add a `StoryBible.from_snapshot(project_root:, snapshot_name:)` class method that returns a read-only StoryBible instance pointing at the snapshot directory instead of the live directory.

**Rationale**: StoryBible already reads from a path. By pointing it at the snapshot directory, all existing read methods work unchanged. The instance disables write methods (save_character, add_fact, etc.) by either raising an error or not injecting a RevisionStore.

**Alternatives considered**:
- **Copy snapshot data into a temp directory**: Unnecessary overhead — StoryBible already reads from arbitrary paths.
- **Add a `version` parameter to every read method**: Invasive change touching every method signature. Rejected.

### 4. Canon Version Reference in Derivatives

**Decision**: Add a `canon_version` field to the generation log entry and to chapter front matter.

Format:
```yaml
canon_version:
  snapshot: "after-chapter-10"
  version: 2
  branch: "main"
```

Or when no snapshot exists:
```yaml
canon_version: "unversioned"
```

**Rationale**: Storing in both the generation log and the chapter file itself ensures traceability from either direction — "what version made this chapter?" and "what chapters came from this version?"

### 5. Integration with ChapterGenerator

**Decision**: Add optional `snapshot:` keyword argument to `ChapterGenerator#initialize`. When provided, the generator loads StoryBible from that snapshot. When omitted, it uses the latest snapshot (if any exist) or current live state.

**Rationale**: Minimal change to existing code. The `--snapshot` CLI flag maps directly to this argument. Auto-selection logic lives in the CLI layer, not the generator.

### 6. Snapshot Naming Constraints

**Decision**: Snapshot names must match `/\A[a-z0-9][a-z0-9\-]*\z/` (lowercase alphanumeric + hyphens, no leading hyphen). Maximum 64 characters.

**Rationale**: Consistent with branch naming in BranchManager. Safe for filesystem paths on all platforms.
