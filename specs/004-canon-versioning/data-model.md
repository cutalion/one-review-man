# Data Model: Canon Versioning and Snapshots

**Date**: 2026-04-01
**Branch**: `004-canon-versioning`

## Entities

### Snapshot

A named, immutable point-in-time capture of the full Story Bible state.

**Attributes**:
- `name` (String, required): Human-readable identifier. Unique across all snapshots. Must match `/\A[a-z0-9][a-z0-9\-]*\z/`, max 64 chars.
- `version` (Integer, required): Auto-assigned monotonically increasing number (1, 2, 3...).
- `timestamp` (String, ISO 8601): When the snapshot was created.
- `branch` (String, default: "main"): Which branch was captured.
- `entity_counts` (Hash): Summary counts per entity type.
  - `characters` (Integer)
  - `locations` (Integer)
  - `facts` (Integer): Count of fact categories
  - `relationships` (Integer)
  - `plot_threads` (Integer)

**Identity**: Unique by both `name` and `version`. Either can be used to reference a snapshot.

**Lifecycle**: Created → Immutable. No update or delete operations.

**Storage**: Each snapshot is a directory containing:
- `manifest.yml` — the attributes above
- Full copies of all Story Bible entity files (characters/*.yml, locations/*.yml, facts.yml, relationships.yml, plot_threads.yml)

### Snapshot Index

Global registry of all snapshots.

**Storage**: `data/story_bible/snapshots/_index.yml`

**Format**:
```yaml
snapshots:
  - name: "initial"
    version: 1
    timestamp: "2026-04-01T12:00:00+00:00"
    branch: "main"
  - name: "after-chapter-10"
    version: 2
    timestamp: "2026-04-01T15:30:00+00:00"
    branch: "main"
```

### Canon Version Reference

A lightweight pointer embedded in derivative metadata.

**Attributes**:
- `snapshot` (String, nullable): Snapshot name. Null if unversioned.
- `version` (Integer, nullable): Snapshot version number. Null if unversioned.
- `branch` (String): Branch context.

**Format when versioned**:
```yaml
canon_version:
  snapshot: "after-chapter-10"
  version: 2
  branch: "main"
```

**Format when unversioned**:
```yaml
canon_version: "unversioned"
```

**Embedded in**: Chapter front matter (`content/chapters/*.md`), generation log entries (`data/generation_log.yml`).

## Relationships

```
Snapshot Index (1) ──contains──> (*) Snapshot
Snapshot (1) ──captures──> (1) Story Bible State (characters, locations, facts, relationships, plot_threads)
Derivative Artifact (*) ──references──> (0..1) Snapshot (via Canon Version Reference)
```

## Storage Layout

```
data/story_bible/
├── snapshots/                        # NEW
│   ├── _index.yml                    # Snapshot registry
│   ├── 001-initial/                  # First snapshot
│   │   ├── manifest.yml
│   │   ├── characters/
│   │   ├── locations/
│   │   ├── facts.yml
│   │   ├── relationships.yml
│   │   └── plot_threads.yml
│   └── 002-after-chapter-10/         # Second snapshot
│       ├── manifest.yml
│       └── ...
├── characters/                       # Live state (unchanged)
├── locations/
├── facts.yml
├── relationships.yml
├── plot_threads.yml
├── revisions/                        # Existing (unchanged)
└── branches/                         # Existing (unchanged)
```
