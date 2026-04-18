# Audit Finding Contract

**Feature**: 014-storyworld-pivot

Describes the shape of a single audit-log entry and the canonical text format used by `eidos canon review`.

## On-disk format

`worlds/<name>/data/audit_log/findings.yml` is a YAML array. Each entry:

```yaml
- id: 01ABCDEF123456789ABCDEFGH
  kind: conflict
  status: open
  piece_id: 017
  canon_delta_id: 01HBQ0...
  canon_version_before: v42
  canon_version_after: v43
  explanation: >
    Piece 017 introduced character 'brenda-20' with role "Automated HR department",
    but canon already carried 'brenda-20' with role "AI recruiter assistant".
    The new value was applied (optimistic); review and decide.
  severity_hint: warn
  created_at: 2026-04-18T10:32:19Z
  resolved_at: null
  resolution: null
```

Closed example:

```yaml
- id: 01ABCDEF123456789ABCDEFGH
  kind: conflict
  status: closed
  # ... same fields ...
  resolved_at: 2026-04-18T11:04:02Z
  resolution: revert
```

## Kind enum (MVP)

| Kind | Opened by | Meaning |
|---|---|---|
| `conflict` | `CanonDelta#apply!` when an update or insert collides with an existing entity | Delta was applied; prior canon state is captured in `canon_version_before`. |
| `malformed-delta` | `CanonDelta.parse` on parse failure | Piece was saved; no canon change happened; `canon_version_after == canon_version_before`. |
| `orphaned-reference` | `CanonDelta#revert!` when a later piece's delta references rolled-back entities | The later piece's references are now dangling. User decides whether to cascade-revert that piece too. |

Any other kind value in the YAML on disk is ignored by MVP code with a debug warning. Future kinds (see spec's "Future Work / Deferred Review Capabilities") extend this enum without renaming existing values.

## Status transitions

```
open ──accept/revert/patch-canon/other──► closed
```

There is no `closed → open` transition. If the user changes their mind after closing, they file a new finding (e.g. producing a new piece, which may itself open new findings).

## `eidos canon review` text-format rendering

```text
Finding 01ABCDEF...  [conflict]  OPEN
  Piece: 017
  Canon: v42 → v43
  Severity: warn
  Opened: 2026-04-18 10:32:19 UTC

  Piece 017 introduced character 'brenda-20' with role "Automated HR department",
  but canon already carried 'brenda-20' with role "AI recruiter assistant".
  The new value was applied (optimistic); review and decide.

  Remediate:
    eidos canon revert  --finding 01ABCDEF...         # roll back piece 017's delta
    eidos canon accept  --finding 01ABCDEF...         # leave canon as-is, close finding
    eidos canon patch   --finding 01ABCDEF...         # edit canon to resolve conflict
```

Closed findings render the same way, without the `Remediate` footer, and with a trailing `Resolved: 2026-04-18 11:04:02 UTC via revert` line.

## JSON-format rendering

The `--format json` flag emits a JSON array of objects whose keys match the YAML field names verbatim, with timestamps as ISO-8601 strings. No wrapper envelope.

## Invariants

- The audit log file is append-only for opens; closing rewrites a single entry in place (load → mutate → rewrite with a temp-file + rename to stay atomic).
- `canon review` itself is read-only and idempotent; running it zero times vs. N times produces the same file contents.
- A finding's `canon_delta_id` MUST resolve to an existing CanonDelta record for `conflict` and `malformed-delta` kinds; for `orphaned-reference` it MAY be nil when the orphan was discovered against a piece whose delta has already been fully rolled back.
