# Data Model: IP-Generator Pivot

**Feature**: 014-storyworld-pivot
**Date**: 2026-04-18

All entities below are new unless marked **(existing)**. Existing entities are listed only where this feature changes their usage. Storage is YAML files under `worlds/<name>/data/` and `worlds/<name>/content/`, read/written through the existing `Eidos::Storage` abstraction (`:yaml_file` default, `:memory` in tests).

## Entity diagram (logical)

```
World (existing)
  └── has many Pieces
        ├── form: Form (resolved via FormRegistry)
        ├── canon_version_at_production: CanonVersionReference (existing)
        ├── canon_status: :applied | :reverted
        └── canon_delta: CanonDelta (1:1)
                └── when conflicts or malformed → opens AuditFinding
  └── has one AuditLog
        └── has many AuditFindings
  └── has one FormRegistry (runtime view; not persisted)
        ├── built-in forms (from gem)
        └── world-local forms (from data/forms/*.yml)
```

---

## Entity: Piece

**Purpose**: A generated content artifact. Supersedes "chapter" as the general organizing unit.

**Storage**:
- File content: `worlds/<name>/content/chapters/NNN-chapter.md` for form=`chapter` (back-compat, unchanged); `worlds/<name>/content/pieces/<form>/<id>.md` for all other forms.
- Frontmatter YAML carries the record fields below.

**Fields**:

| Field | Type | Required | Notes |
|---|---|---|---|
| id | String | yes | Stable id. For chapters: existing `NNN` numbering. For other forms: ULID. |
| form | String | yes | Name of the form used (e.g. `chapter`, `haiku`). Must resolve against the active FormRegistry at read time. |
| category | Symbol | yes | `:text` / `:image` / `:script`. Copied from the form at production time so records survive form deletion. |
| generated_date | Date | yes | ISO-8601. |
| canon_version | String | yes | Canon version reference (existing `CanonVersionReference` format) at production time. |
| canon_status | Symbol | yes | `:applied` (default) or `:reverted`. Flipped by `canon review` revert action. |
| length_measured | Integer | yes | Words for text forms; lines for haiku; frames for comic-script; prompt-char-count for image forms. The unit is form-declared. |
| canon_delta_ref | String | yes | Id of the associated CanonDelta record. |
| content_path | String | conditional | Path to the piece file on disk; required for all forms. |
| asset_path | String | conditional | Path to the generated image asset; required only for image-form pieces. |

**Validation rules**:
- `form` MUST exist in the FormRegistry at read time *or* the piece MUST carry a `category` so it stays parseable even if the form was removed later.
- `canon_version` MUST be a resolvable reference at the time the piece was produced; staleness later is expected (pieces older than current canon version are normal).
- `canon_status` transitions allowed: `:applied → :reverted`. Reverse (`:reverted → :applied`) happens via a new piece/regeneration, not by flipping the field back. Append-only-ish.

**Chapter back-compat subset** (FR-002): for form=`chapter`, the following frontmatter keys MUST remain present in their current form and positions: `layout`, `title`, `chapter_number`, `characters`, `summary`, `word_count`, `permalink`, `generated_date`, `status`, `lang`, `new_characters`, `canon_version`. New fields from this feature (`form`, `category`, `canon_status`, `canon_delta_ref`) are appended and MUST NOT replace or reorder the existing keys.

---

## Entity: Form

**Purpose**: The recipe for generating a piece. Declares name, category, length/shape defaults, prompt template, and canon-context requirements.

**Storage**:
- Built-in: `eidos/lib/eidos/forms/<name>.yml` (shipped with gem).
- World-local: `worlds/<name>/data/forms/<name>.yml` (user-authored, optional).

**Fields** (YAML schema):

| Field | Type | Required | Notes |
|---|---|---|---|
| name | String | yes | Unique within a registry (world-local wins on collision). Must match `[a-z][a-z0-9-]*`. |
| category | Enum | yes | `text` / `image` / `script`. |
| default_length | Integer | no | Target length in the form's natural unit. Chapter form carries the world's chapter length target as its default; other forms carry their own. |
| default_shape | String | no | Free-form description for forms whose "length" isn't a number (e.g. haiku: `"3 lines, 5-7-5"`). |
| prompt_template_path | String | yes | Relative path to a prompt template file, resolved against the form file's directory. |
| canon_context | List<Symbol> | no | Which canon slices to inject. Supported: `:all_characters`, `:recent_events`, `:current_chapter`, `:all_locations`, `:none`. Default `[:all_characters]`. |
| origin | Symbol | derived | `:builtin` or `:world_local`. Set by FormRegistry at load, not stored in YAML. |

**Validation rules**:
- `default_length` or `default_shape` — at least one must be present.
- `prompt_template_path` MUST resolve to a file at load time; missing file means that form is not registered (registry logs a warning) rather than crashing the CLI.
- `canon_context` entries MUST be from the supported set; unknown entries cause the form to be skipped with a warning.

**Built-in forms shipped (MVP)**:
`chapter`, `haiku`, `vignette`, `short-story`, `comic-script`, `portrait`, `social-post`, `illustration` — one YAML per form under `eidos/lib/eidos/forms/`.

---

## Entity: FormRegistry (runtime, not persisted)

**Purpose**: Merge built-in forms and world-local forms into the set available for a single CLI invocation.

**Behavior**:
- Constructed per CLI invocation (not cached across invocations).
- Load order: built-ins first, then world-local. World-local forms with a name matching a built-in replace the built-in; the replacement is recorded on the registry so the CLI can print a `Using world-local form 'chapter' (overrides built-in)` notice (FR-013).
- `#find(name)` returns the resolved Form or raises `FormNotFound` with the list of available names (FR-014).
- `#each`, `#list`, `#categories` for CLI listings.

**Not persisted**. Every `eidos` invocation rebuilds it. Discovery cost is dominated by YAML reads (~10 files max per world).

---

## Entity: CanonDelta

**Purpose**: The structured record of bible changes implied by a produced piece.

**Storage**: One file per delta at `worlds/<name>/data/canon_deltas/<delta-id>.yml`. The owning Piece's `canon_delta_ref` field holds this id.

**Fields** (YAML schema):

| Field | Type | Required | Notes |
|---|---|---|---|
| id | String | yes | ULID. |
| piece_id | String | yes | Id of the owning Piece. |
| created_at | Timestamp | yes | ISO-8601. |
| applied_at | Timestamp | nullable | Set when delta is successfully written to canon; nil in dry-run. |
| reverted_at | Timestamp | nullable | Set when `canon review` revert action rolls it back. |
| new_characters | List<CharacterSeed> | no | Same shape as existing `Character` minus id (id is derived). May be empty. |
| new_locations | List<LocationSeed> | no | Same shape as existing `Location`. May be empty. |
| new_facts | List<FactSeed> | no | `{ subject, kind, value, source_ref }`. |
| new_events | List<EventSeed> | no | `{ when, who, what, where_ref, source_ref }`. |
| new_relationships | List<RelationshipSeed> | no | `{ subject_id, kind, object_id }`. |
| entity_updates | List<EntityUpdate> | no | `{ entity_kind, entity_id, attribute, old_value, new_value }`. |
| parse_error | String | nullable | Non-nil only when CanonDelta.parse failed (FR-022). Presence opens a `:malformed-delta` AuditFinding. |

**Validation rules**:
- All section lists default to empty; a delta with every section empty is valid (e.g. image-form with no extractable text, FR-023).
- Entity ids in `new_*` sections MUST be passed through `ValidationUtils.slugify` before insertion into the bible (matches existing seeded-id normalization; kebab-case).
- An `entity_updates` entry whose `old_value` does not match current canon triggers a `:conflict` AuditFinding at apply time; the update is still applied (optimistic, FR-020).

**Lifecycle**:
```
[constructed] ─parse_ok─► created
                │
                └──parse_err──► created (parse_error set) ──► always opens :malformed-delta finding
created ──apply──► applied (applied_at set)
applied ──canon-review revert──► reverted (reverted_at set; piece.canon_status flips)
```
There is no `deferred` state.

---

## Entity: AuditFinding

**Purpose**: A post-hoc issue flagged against applied canon; the unit of work for `canon review`.

**Storage**: Entries in `worlds/<name>/data/audit_log/findings.yml` (single YAML array, append-only).

**Fields**:

| Field | Type | Required | Notes |
|---|---|---|---|
| id | String | yes | ULID. |
| kind | Enum | yes | MVP: `conflict` / `malformed-delta` / `orphaned-reference`. Future kinds reserved (see Future Work in spec). |
| status | Enum | yes | `open` / `closed`. |
| piece_id | String | yes | Originating piece. |
| canon_delta_id | String | conditional | Required for `conflict` and `malformed-delta`; nullable for `orphaned-reference` findings discovered during revert cascade. |
| canon_version_before | String | yes | Canon version immediately before the delta applied. |
| canon_version_after | String | yes | Canon version immediately after. For `malformed-delta` these are equal. |
| explanation | String | yes | Human-readable one-paragraph description of the suspected issue. |
| severity_hint | Enum | no | `info` / `warn` / `error`. Default `warn`. |
| created_at | Timestamp | yes | |
| resolved_at | Timestamp | nullable | Set when status flips to `closed`. |
| resolution | Enum | nullable | `revert` / `accept` / `patch-canon` / `other`. Required when status is `closed`. |

**Validation rules**:
- `status: closed` MUST have both `resolved_at` and `resolution` populated.
- A finding MAY NOT be deleted; findings are append-only and closed findings remain queryable (FR-030).
- `kind` MUST be from the MVP set in MVP; unknown kinds are logged and skipped rather than crashing the review.

**Creation sites (MVP)**:
- FR-020: when CanonDelta apply detects an `entity_update` colliding with existing canon → new `:conflict` finding.
- FR-022: when CanonDelta.parse fails → new `:malformed-delta` finding.
- Revert cascade edge case: when a revert rolls back a delta whose entities were referenced by a later piece's delta → new `:orphaned-reference` finding.

No other creation sites in MVP.

---

## Entity: AuditLog

**Purpose**: Per-world append-only store of AuditFindings.

**Storage**: `worlds/<name>/data/audit_log/findings.yml`. File created on first finding; absent when the world has zero findings.

**Operations**:
- `#append(finding)` — serializes the finding and writes atomically (write-to-temp + rename).
- `#all` / `#open` / `#closed` / `#by_piece(piece_id)` — read operations over the whole file.
- `#close(finding_id, resolution:, at: Time.now)` — flips `status`, sets `resolved_at` and `resolution`; rewrites the file.

**Concurrency**: single-process CLI; no cross-process locking. If added later, an advisory file lock is trivial to drop in.

---

## Relationships summary

| From | To | Cardinality | Notes |
|---|---|---|---|
| World | Piece | 1 : many | Indexed by form in the Piece record. |
| Piece | Form | many : 1 | Resolved via FormRegistry at read time. |
| Piece | CanonDelta | 1 : 1 | Required (delta may be empty but must exist). |
| CanonDelta | AuditFinding | 1 : 0..many | Finding references `canon_delta_id` and `piece_id`. |
| World | AuditLog | 1 : 1 | Audit log lives with the world. |
| World | FormRegistry | 1 : 1 (runtime only) | Rebuilt per CLI invocation. |

---

## Migration impact

None. Existing worlds have zero pieces in non-chapter forms, zero custom forms, and zero audit findings. The new directories (`data/forms/`, `data/audit_log/`, `data/canon_deltas/`, `content/pieces/`) are created lazily on first use. Existing chapter files remain in place and are readable by the new Piece model through the form=`chapter` path.
