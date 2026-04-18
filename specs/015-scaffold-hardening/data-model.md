# Data Model — 015 Scaffold Hardening

This feature touches five existing records plus introduces no new ones. Fields added, removed, or restructured are enumerated below. Every on-disk YAML already present in existing worlds continues to deserialize.

---

## 1. Canon-delta record (`data/canon_deltas/<id>.yml`)

**Changes**: field `parse_error` restructured from `String | null` to `Hash | null`. Field positions, other fields, and the file path are unchanged.

### `parse_error` — new shape

```yaml
parse_error:
  summary: "2 non-mapping entries dropped across new_characters, new_facts"
  drops:
    - section: new_characters
      value: "Arthur is a programmer"
      reason: "expected mapping, got String"
    - section: new_facts
      value: "the office is grim"
      reason: "expected mapping, got String"
```

Rules:

- **`parse_error` is `null`** iff no drops occurred AND no document-level parse issue was raised.
- **`parse_error.summary`** is a human-readable single-line description of what went wrong. Required when `parse_error` is non-null.
- **`parse_error.drops`** is an array, possibly empty. Each element has:
  - `section` (String, required) — one of `SECTIONS` on `CanonDelta` (`new_characters`, `new_locations`, `new_facts`, `new_events`, `new_relationships`, `entity_updates`).
  - `value` (Any, required) — the raw dropped entry, serialized verbatim for auditability.
  - `reason` (String, required) — short explanation (`"expected mapping, got String"`, `"missing both id and name"`, `"missing required key: description"`).
- **Document-level failures** (bad YAML, missing sentinel) populate `summary` with the existing legacy string and leave `drops` empty (`[]`).

### Backwards compatibility (read path)

`CanonDelta.from_hash` accepts either:

- `parse_error: null` → no change.
- `parse_error: "YAML parse error: ..."` (legacy string) → converted in-memory to `{ summary: <string>, drops: [] }`. On-disk file is not rewritten.
- `parse_error: { summary: ..., drops: [...] }` (new) → passed through.

### State transitions

No change to lifecycle:

```
[parse] ──ok, no drops──► created (parse_error: null)    ──apply!──► applied
       ──ok, with drops─► created (parse_error: {drops:…})──apply!──► applied
                                                                        + one AuditFinding per drop opened (kind: parse-drop)
       ──doc error───────► created (parse_error: {summary: "…"}) ──apply!──► AuditFinding opened (kind: malformed-delta, unchanged)
```

Note: a delta with drops but otherwise well-formed entries STILL applies the well-formed entries. The `parse_error` does not block application; it only records the loss.

---

## 2. Audit-finding record (`data/audit_findings.yml`)

**Changes**: new `kind` value. Schema unchanged.

### New `kind: 'parse-drop'`

Existing kinds: `malformed-delta`, `conflict`, `orphaned-reference`.
New kind: `parse-drop`.

Finding shape (all kinds share the same fields):

```yaml
- id: <ulid>
  kind: parse-drop
  piece_id: <piece-id or null>
  canon_delta_id: <delta-id>
  canon_version_before: <version>
  canon_version_after: <version>
  explanation: "Dropped non-mapping entry in new_characters: \"Arthur is a programmer\" (reason: expected mapping, got String)"
  opened_at: <utc-timestamp>
  closed_at: null
  resolution: null
```

Rules:

- Opened automatically by `CanonDelta#apply!` — one finding per element of `parse_error.drops`.
- Closure follows the same resolution path as other findings (user dismisses via `eidos canon review --resolve` or equivalent existing flow; no new closure path introduced).
- Surfaced by `eidos canon review` alongside the existing kinds. Output formatting may differentiate (e.g., label `[parse-drop]`), but the data is the same record type.

---

## 3. World config (`data/world_config.yml`)

**Changes**: metadata fields may now carry an explicit sentinel value. No field added or removed.

### Metadata sentinel

Four existing String-typed fields — `genre`, `style`, `setting`, `theme` — may now hold the value `"unspecified"` in addition to arbitrary user-supplied strings.

Rules:

- A newly scaffolded world with no explicit `--genre` / `--style` / `--setting` / `--theme` flags writes those fields as `"unspecified"`.
- A user may edit `data/world_config.yml` to replace `"unspecified"` with any value; the system takes the new value verbatim on next read.
- The `"unspecified"` literal string is the sentinel. Downstream code (prompts, templates, status) must recognize it and either omit the value from context or surface it as an action item (`world status`, per R5/R7).

### `subtitle`, `description` — population change only

Today these fields are already String-typed. Under US3 (non-interactive flag surface), the `--premise` flag value lands here verbatim, including newlines. No schema change.

### `languages`, `default_language` — population change only

Today `languages` is a list of ISO language codes. Under US3 the non-interactive flag `--languages en,ru` is split on comma into the list. `default_language` is a single ISO code and must be a member of `languages`. No schema change; US3 just stops corrupting them with prose fragments.

---

## 4. World scaffold template

**Changes**: scaffold-time directory list reduced. No file-format change.

### Directories removed from scaffold

Not created at `eidos world new`:

- `content/chapters/`
- `content/characters/`

Rules:

- Piece producers create `content/pieces/<form>/` (and for chapters, `content/chapters/`) at first write via `FileUtils.mkdir_p`. This behavior already exists in practice; change is deletion of pre-creation from the scaffold, not addition of lazy-mkdir (it's already there).
- Directories created at scaffold time (unchanged): `data/`, `data/story_bible/`, `data/canon_deltas/`, `data/forms/`, `content/`, plus any template YAML files.
- **Existing worlds unchanged.** No migration, no cleanup of pre-existing empty `content/chapters/` directories.

---

## 5. Integration-scenario fixture (new, test-only)

Not a production entity; included here because it is an artifact this feature produces and it lives in the repo.

### `eidos/spec/integration/user_scale/`

Each file defines one end-to-end scenario that:

1. Creates a temp dir (`Dir.mktmpdir`).
2. Shells `exe/eidos` via `Open3.capture3` with realistic flags (including multi-line `--premise`).
3. Asserts on files, directory structure, and YAML contents on disk.

Shared helper at `eidos/spec/support/integration_world_builder.rb` (or similar) provides `build_world(premise:, title:, …)` which returns the temp world path.

Rules:

- Specs do NOT instantiate `Eidos::CLI::*` classes directly.
- Specs do NOT read from `worlds/one-review-man` or any other persistent world.
- `MOCK_AI=true` is set per-spec before shelling.
- Each scenario is independent; order-independent.

Initial scenarios planned (final list comes from `/speckit.tasks`):

- Scaffold + one piece + bible assertions (covers SC-001, SC-002, SC-003, SC-005).
- Canon-delta fuzz (covers SC-004).
- Two-form produce + status assertions (covers SC-006, SC-008).

---

## Summary of data-model changes

| Entity | Change |
|--------|--------|
| Canon-delta `parse_error` | String → Hash `{summary, drops[]}`. Legacy string tolerated on read. |
| AuditFinding `kind` | New value `'parse-drop'` added to existing enum. |
| World config metadata | New sentinel value `"unspecified"` recognized for `genre`/`style`/`setting`/`theme`. |
| World scaffold dirs | `content/chapters/` and `content/characters/` no longer created eagerly. |
| Integration fixtures | New directory `eidos/spec/integration/user_scale/` with scenario specs and helper. |

No new on-disk file types. No field removed. No required field added to existing records. Every existing world file continues to parse unchanged.
