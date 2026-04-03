# Data Model: Storage Abstraction Layer

## Entities

### Entity (generic)

All story bible entities share this pattern:

| Field | Type | Description |
|-------|------|-------------|
| id | String | Unique identifier (slug), e.g., "kenji_yamamoto" |
| type | Symbol | One of: :character, :location, :fact, :relationship, :plot_thread |
| data | Hash | Arbitrary key-value data specific to entity type |

### Character

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| id | String | Yes | Slug identifier |
| name | String | Yes | Display name |
| mentions | Array<Integer> | No | Chapter numbers where character appeared |
| physical_appearance | Hash | No | Visual description fields |
| *(other fields)* | Any | No | Open schema — characters can have arbitrary fields |

### Location

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| id | String | Yes | Slug identifier |
| name | String | Yes | Display name |
| *(other fields)* | Any | No | Open schema |

### Fact

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| category | String | Yes | Grouping key (e.g., "events", "world_rules") |
| id | String | Yes | Unique within category |
| name | String | No | Searchable name |
| description | String | No | Searchable description |
| rule | String | No | Searchable rule text |
| *(other fields)* | Any | No | Open schema |

### Relationship

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| character1 | String | Yes | First character ID |
| character2 | String | Yes | Second character ID |
| type | String | Yes | Relationship type |
| since | String | No | When relationship began |

### Plot Thread

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| id | String | No | Thread identifier |
| status | String | Yes | "active" or other status |
| *(other fields)* | Any | No | Open schema |

### Revision

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| sequence | Integer | Yes | Monotonically increasing per entity |
| entity_type | String | Yes | Type of entity being revised |
| entity_id | String | Yes | ID of entity being revised |
| snapshot | Hash | Yes | Complete entity state at this revision |
| timestamp | String (ISO 8601) | Yes | When revision was created |
| change_reason | String | No | Why the change was made |
| parent_seq | Integer | No | Previous revision sequence |
| operation | String | Yes | "create" or "update" |
| branch | String | Yes | Branch name (default: "main") |
| changeset_id | String | No | Batch changeset reference |

### Snapshot

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| name | String | Yes | Human-readable name (validated: lowercase alphanumeric + hyphens) |
| version | Integer | Yes | Monotonically increasing |
| branch | String | Yes | Branch captured (default: "main") |
| created_at | String (ISO 8601) | Yes | When snapshot was taken |
| entity_counts | Hash | Yes | Count of each entity type in snapshot |
| data | Hash | Yes | Complete story bible state (characters, locations, facts, relationships, plot_threads) |

## Relationships

```
StoryBible ──uses──> EntityStorageAdapter
StoryBible ──optionally uses──> RevisionStorageAdapter
SnapshotStorageAdapter ──reads from──> EntityStorageAdapter (to capture current state)

StorageFactory ──creates──> EntityStorageAdapter
StorageFactory ──creates──> RevisionStorageAdapter
StorageFactory ──creates──> SnapshotStorageAdapter

CLI Commands ──use──> StorageFactory
```
