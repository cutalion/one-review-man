# Snapshot Storage Contract

The snapshot storage adapter manages point-in-time copies of story bible state.

## Required Operations

| Operation | Signature | Returns | Description |
|-----------|-----------|---------|-------------|
| create | `(name:, branch: "main")` | `Hash` | Create a snapshot from current entity state. Returns manifest hash. |
| list | `()` | `Array<Hash>` | All snapshots ordered by version, each with metadata fields. |
| get | `(name_or_version)` | `Hash or nil` | Find snapshot by name (String) or version (Integer). Returns manifest or nil. |
| latest | `()` | `Hash or nil` | Most recent snapshot or nil. |
| snapshot_data | `(name_or_version)` | `Hash or nil` | Returns full entity data for a snapshot: `{characters: {}, locations: {}, facts: {}, relationships: [], plot_threads: []}` |

## Manifest Hash Fields

| Field | Type | Description |
|-------|------|-------------|
| name | String | Snapshot name |
| version | Integer | Auto-assigned version number |
| branch | String | Branch captured |
| created_at | String (ISO 8601) | Creation timestamp |
| entity_counts | Hash | `{characters: N, locations: N, facts: N, relationships: N, plot_threads: N}` |

## Name Validation

- Must match pattern: `/\A[a-z0-9][a-z0-9\-]*\z/`
- Maximum 64 characters
- Must not start with a hyphen
- Duplicate names are rejected (raises `DuplicateSnapshotError`)

## Behavioral Requirements

- Version numbers start at 1 and increment monotonically.
- `list` returns an empty array when no snapshots exist (not nil, not an error).
- `get` accepts both String (name lookup) and Integer (version lookup).
- `get` returns nil for non-existent snapshots (not an error).
- `snapshot_data` returns the complete entity state as plain Ruby hashes — not filesystem paths.
- Snapshots are immutable — once created, their data cannot change even if live entities are modified.
- `create` captures the current state of all entities at the moment of creation.
