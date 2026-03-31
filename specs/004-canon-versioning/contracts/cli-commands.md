# CLI Contract: Snapshot Commands

**Date**: 2026-04-01
**Branch**: `004-canon-versioning`

## New Subcommand: `book snapshot`

### `book snapshot create NAME`

Create a named snapshot of the current Story Bible state.

**Arguments**:
- `NAME` (required): Human-readable snapshot name. Must match `[a-z0-9][a-z0-9-]*`, max 64 chars.

**Options**:
- `--book-dir, -b PATH`: Override project root.

**Output** (stdout):
```
Created snapshot "after-chapter-10" (version 3)
  Characters: 11
  Locations: 9
  Facts: 5 categories
  Relationships: 8
  Plot threads: 4
```

**Errors**:
- Name already exists → exit 1, stderr: `Error: Snapshot "NAME" already exists`
- Invalid name format → exit 1, stderr: `Error: Invalid snapshot name "NAME". Use lowercase alphanumeric and hyphens only.`

### `book snapshot list`

List all snapshots with metadata.

**Options**:
- `--book-dir, -b PATH`: Override project root.

**Output** (stdout):
```
Snapshots:
  v1  initial            2026-03-15  main  (11 chars, 9 locs, ...)
  v2  after-chapter-5    2026-03-20  main  (11 chars, 9 locs, ...)
  v3  after-chapter-10   2026-04-01  main  (11 chars, 9 locs, ...)
```

**Errors**:
- No snapshots exist → stdout: `No snapshots found.`

### `book snapshot show NAME`

Show detailed metadata for a specific snapshot.

**Arguments**:
- `NAME` (required): Snapshot name or version number (e.g., "after-chapter-10" or "3").

**Options**:
- `--book-dir, -b PATH`: Override project root.

**Output** (stdout):
```
Snapshot: after-chapter-10 (version 3)
Created: 2026-04-01T15:30:00+00:00
Branch: main
Entities:
  Characters: 11
  Locations: 9
  Facts: 5 categories
  Relationships: 8
  Plot threads: 4
```

**Errors**:
- Not found → exit 1, stderr: `Error: Snapshot "NAME" not found`

## Modified Commands

### `book generate chapter`

**New option**:
- `--snapshot NAME`: Pin generation to a specific canon snapshot. If omitted, auto-selects latest snapshot (or "unversioned" if none exist).

**Behavior change**: Generation metadata now includes `canon_version` in the chapter front matter and generation log.

### `book generate illustration`

**New option**:
- `--snapshot NAME`: Same behavior as chapter generation.
