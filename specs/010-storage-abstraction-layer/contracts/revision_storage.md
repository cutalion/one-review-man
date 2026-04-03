# Revision Storage Contract

The revision storage adapter handles append-only revision history for canon entries.

## Required Operations

| Operation | Signature | Returns | Description |
|-----------|-----------|---------|-------------|
| record | `(entity_type:, entity_id:, snapshot:, operation:, branch: "main", change_reason: nil, changeset_id: nil)` | `Models::Revision` | Append a new revision. Auto-assigns next sequence number. |
| history | `(entity_type:, entity_id:, branch: "main")` | `Array<Models::Revision>` | All revisions in chronological order |
| get | `(entity_type:, entity_id:, sequence:, branch: "main")` | `Models::Revision or nil` | Specific revision by sequence |
| latest | `(entity_type:, entity_id:, branch: "main")` | `Models::Revision or nil` | Most recent revision |

## Behavioral Requirements

- Sequence numbers start at 1 and increment monotonically per (entity_type, entity_id, branch) tuple.
- `record` sets `parent_seq` to `sequence - 1` (or nil for first revision).
- `record` sets `timestamp` to current time in ISO 8601 format.
- `history` returns an empty array for non-existent entities (not nil, not an error).
- `get` returns nil for non-existent revisions (not an error).
- Revisions are immutable — once recorded, they cannot be modified or deleted.
- Branch-scoped revisions are stored separately from main branch revisions.
- All returned revisions are `Models::Revision` structs (not storage-specific objects).
