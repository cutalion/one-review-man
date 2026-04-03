# Entity Storage Contract

The entity storage adapter handles CRUD and search for all story bible entities.

## Required Operations

### Characters

| Operation | Signature | Returns | Description |
|-----------|-----------|---------|-------------|
| all_characters | `()` | `Hash<String, Hash>` | All characters keyed by ID |
| get_character | `(id)` | `Hash or nil` | Single character by ID |
| save_character | `(id, data)` | `void` | Create or update character |
| list_characters | `(appeared_in: nil)` | `Array<Hash>` | List of `{id:, name:}`, optionally filtered by chapter |

### Locations

| Operation | Signature | Returns | Description |
|-----------|-----------|---------|-------------|
| all_locations | `()` | `Hash<String, Hash>` | All locations keyed by ID |
| get_location | `(id)` | `Hash or nil` | Single location by ID |
| save_location | `(id, data)` | `void` | Create or update location |

### Facts

| Operation | Signature | Returns | Description |
|-----------|-----------|---------|-------------|
| all_facts | `()` | `Hash<String, Hash>` | All facts organized by category |
| get_facts_by_category | `(category)` | `Hash` | Facts in a category |
| add_fact | `(category, id, data)` | `void` | Add or update a fact |
| search_facts | `(query)` | `Array<Hash>` | Case-insensitive keyword search across name, description, rule |

### Relationships

| Operation | Signature | Returns | Description |
|-----------|-----------|---------|-------------|
| all_relationships | `()` | `Array<Hash>` | All relationships |
| get_relationships_for | `(character_id)` | `Array<Hash>` | Relationships involving a character |
| add_relationship | `(data)` | `void` | Add a relationship |

### Plot Threads

| Operation | Signature | Returns | Description |
|-----------|-----------|---------|-------------|
| all_plot_threads | `()` | `Array<Hash>` | All plot threads |
| active_plot_threads | `()` | `Array<Hash>` | Plot threads with status "active" |
| add_plot_thread | `(data)` | `void` | Add a plot thread (auto-sets status to "active") |

### Setup

| Operation | Signature | Returns | Description |
|-----------|-----------|---------|-------------|
| setup | `()` | `void` | Initialize storage (create dirs, tables, etc.) |

## Behavioral Requirements

- `save_character` and `save_location` merge `{id: id}` into the data before storing.
- `search_facts` matches case-insensitively across `name`, `description`, and `rule` fields.
- `add_plot_thread` sets `status` to `"active"` on the stored data.
- All read operations return plain Ruby hashes (not ORM objects or storage-specific types).
- After any write operation, subsequent reads must reflect the change.
