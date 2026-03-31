# Data Model: Canon Branching and Change History

**Feature**: 002-canon-branching-history
**Date**: 2026-03-30

## Entities

### Revision

A versioned snapshot of a canon entry at a point in time.

**Storage**: `data/story_bible/revisions/{entity_type}/{entity_id}/{sequence}.yml`

| Field          | Type     | Required | Description                                      |
|----------------|----------|----------|--------------------------------------------------|
| sequence       | Integer  | Yes      | Auto-incrementing revision number per entity      |
| entity_type    | String   | Yes      | One of: character, location, fact, relationship, plot_thread |
| entity_id      | String   | Yes      | ID of the canon entry                            |
| snapshot       | Hash     | Yes      | Full entity state at this revision               |
| timestamp      | DateTime | Yes      | ISO 8601 timestamp of the change                 |
| change_reason  | String   | No       | Creator-provided explanation                     |
| parent_seq     | Integer  | No       | Previous revision sequence (null for first)      |
| operation      | String   | Yes      | One of: create, update, delete, rollback         |
| branch         | String   | Yes      | Branch name (default: "main")                    |
| changeset_id   | String   | No       | If part of a batch changeset                     |

**Identity**: Unique by (entity_type, entity_id, branch, sequence).

**Lifecycle**: Append-only. Revisions are never modified or deleted.

---

### Branch

A named, independent copy of a world's canon state.

**Storage**: Branch metadata in `data/story_bible/branches/_index.yml`. Branch data in `data/story_bible/branches/{branch_name}/`.

| Field          | Type     | Required | Description                                      |
|----------------|----------|----------|--------------------------------------------------|
| name           | String   | Yes      | Unique branch identifier (slug format)           |
| display_name   | String   | No       | Human-readable name                              |
| parent_branch  | String   | Yes      | Name of parent branch ("main" for top-level)     |
| created_at     | DateTime | Yes      | ISO 8601 creation timestamp                      |
| created_from   | Hash     | Yes      | `{branch: name, revision: seq}` — exact fork point |
| status         | String   | Yes      | One of: active, archived, deleted                |
| archived_at    | DateTime | No       | When archived (if applicable)                    |
| description    | String   | No       | Purpose of this branch                           |

**Identity**: Unique by name.

**Lifecycle**: active → archived (read-only, recoverable) → deleted (permanent, data removed). Transitions: archive, unarchive, delete.

**Constraints**:
- A branch cannot be deleted if it has active child branches (must archive/delete children first).
- An archived branch is read-only — no new revisions can be written to it.
- The "main" branch always exists and cannot be archived or deleted.

---

### Impact Report

The result of analyzing a canon change against dependent content.

**Storage**: `data/story_bible/impact_reports/{report_id}.yml`

| Field          | Type     | Required | Description                                      |
|----------------|----------|----------|--------------------------------------------------|
| id             | String   | Yes      | Unique report identifier (timestamp-based)       |
| trigger        | Hash     | Yes      | `{entity_type, entity_id, revision_seq, branch}` |
| created_at     | DateTime | Yes      | When the analysis ran                            |
| branch         | String   | Yes      | Branch context for the analysis                  |
| affected_items | Array    | Yes      | List of AffectedItem (see below)                 |
| summary        | Hash     | Yes      | `{total: N, by_severity: {high: N, medium: N, low: N}}` |

**AffectedItem** (embedded):

| Field          | Type     | Required | Description                                      |
|----------------|----------|----------|--------------------------------------------------|
| content_type   | String   | Yes      | chapter, translation, media_reference            |
| content_path   | String   | Yes      | Relative path to the content file                |
| references     | Array    | Yes      | List of specific passages/lines referencing the changed entry |
| severity       | String   | Yes      | high (direct contradiction), medium (likely affected), low (potentially affected) |
| review_status  | String   | Yes      | pending, reviewed, needs_update, deferred        |
| reviewed_at    | DateTime | No       | When status was last changed                     |

**Lifecycle**: Created automatically after canon changes. Items transition: pending → reviewed | needs_update | deferred. Report itself is immutable once created; review status updates modify individual items.

---

### Changeset

A batch of pending canon changes for atomic preview and commit.

**Storage**: `data/changesets/{changeset_id}.yml`

| Field          | Type     | Required | Description                                      |
|----------------|----------|----------|--------------------------------------------------|
| id             | String   | Yes      | Unique changeset identifier                      |
| branch         | String   | Yes      | Target branch                                    |
| created_at     | DateTime | Yes      | When the changeset was created                   |
| status         | String   | Yes      | draft, previewed, committed, discarded           |
| operations     | Array    | Yes      | List of ChangeOperation (see below)              |
| preview_report | Hash     | No       | Aggregate impact report from preview             |
| committed_at   | DateTime | No       | When committed (if applicable)                   |

**ChangeOperation** (embedded):

| Field          | Type     | Required | Description                                      |
|----------------|----------|----------|--------------------------------------------------|
| operation      | String   | Yes      | create, update, delete                           |
| entity_type    | String   | Yes      | character, location, fact, relationship, plot_thread |
| entity_id      | String   | Yes      | Target entity ID                                 |
| changes        | Hash     | Yes      | For update: field→new_value map. For create: full entity. For delete: empty. |
| change_reason  | String   | No       | Per-operation reason                             |

**Lifecycle**: draft → previewed → committed | discarded. Once committed or discarded, no further modifications.

**Constraints**:
- Only one active (draft/previewed) changeset per branch at a time.
- Preview can be re-run multiple times (status stays previewed or reverts to previewed).
- Commit fails if intra-batch conflicts are detected during preview.

---

### Conflict

A field-level inconsistency detected during merge or batch preview.

**Storage**: Transient — embedded in merge/preview results, not independently persisted.

| Field          | Type     | Required | Description                                      |
|----------------|----------|----------|--------------------------------------------------|
| entity_type    | String   | Yes      | character, location, fact, relationship, plot_thread |
| entity_id      | String   | Yes      | Entity with the conflict                         |
| field_path     | String   | Yes      | Dot-notation path to conflicting field (e.g., `physical_appearance.hair`) |
| base_value     | Any      | Yes      | Value at common ancestor                         |
| ours_value     | Any      | Yes      | Value in target branch                           |
| theirs_value   | Any      | Yes      | Value in source branch                           |
| resolution     | String   | No       | keep_ours, keep_theirs, custom                   |
| custom_value   | Any      | No       | If resolution is custom                          |

---

### Reference Index (cache)

Maps canon entries to dependent content for fast impact lookups.

**Storage**: `data/story_bible/references.yml`

| Field          | Type     | Required | Description                                      |
|----------------|----------|----------|--------------------------------------------------|
| entity_key     | String   | Yes      | `{entity_type}/{entity_id}` as the map key       |
| dependents     | Array    | Yes      | List of `{content_type, content_path, line_numbers}` |
| last_indexed   | DateTime | Yes      | When this entry was last scanned                 |

**Lifecycle**: Rebuilt on demand. Can be deleted and reconstructed from content files at any time.

## Relationships

```
World (existing)
  └── Branch (1:many, tree structure via parent_branch)
        ├── Canon Entries (characters, locations, facts, etc.)
        │     └── Revision (1:many, append-only per entry per branch)
        ├── Impact Report (1:many per branch)
        │     └── AffectedItem (1:many, embedded)
        └── Changeset (0..1 active per branch)
              └── ChangeOperation (1:many, embedded)

Merge produces:
  Conflict (transient, 0:many per merge attempt)
```

## State Transitions

### Branch Status
```
[create] → active → archived → deleted
                  ↑           (permanent)
                  └── unarchive
```

### Changeset Status
```
[create] → draft → previewed → committed
                 ↑           → discarded
                 └── (re-preview)
```

### Impact Report Item Review Status
```
[create] → pending → reviewed
                   → needs_update
                   → deferred
```
