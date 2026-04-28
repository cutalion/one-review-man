# Canon Delta Contract

**Feature**: 014-storyworld-pivot

Defines the structure of the canon-delta record emitted by every producer and the shape of the LLM-facing tail block. See `form-definition.md` for how templates request it from the model.

## LLM-facing format (what the model emits)

```text
<piece content here — prose, haiku, script, image prompt, whatever the form requires>

---CANON-DELTA---
new_characters:
  - id: kev-bot
    name: Kev-Bot
    role: senior-architect
    description: "Self-described 'lifestyle not a bot'; lead architect at Synthetix Agnostics."
new_locations: []
new_facts:
  - subject: synthetix-agnostics
    kind: pivot-history
    value: "Pivoted from 'Blockchain for Bees' to 'LLMs for Sentimental Toasters.'"
new_events:
  - when: "during-interview"
    who: ["arthur-pringle", "brenda-20"]
    what: "Pre-Interview Vibe Check with Desperation Coefficient measurement"
    where: "virtual-waiting-room"
new_relationships: []
entity_updates:
  - entity_kind: character
    entity_id: brenda-20
    attribute: role
    old_value: "AI recruiter assistant"
    new_value: "Automated HR department (Lambda function)"
```

## Parsing rules

1. Split on the first line matching exactly `---CANON-DELTA---` (leading/trailing whitespace allowed; no code fences around it).
2. Parse the text after the sentinel as a YAML document.
3. Expect a mapping with the six top-level keys: `new_characters`, `new_locations`, `new_facts`, `new_events`, `new_relationships`, `entity_updates`. Missing keys default to empty lists.
4. Unknown top-level keys are ignored (warning logged to debug).
5. Each entry in each list must itself be a mapping. Non-mapping entries are dropped with a debug warning.
6. On any failure — missing sentinel, YAML parse error, non-mapping document — return an empty CanonDelta with `parse_error` set to a short human-readable reason. This opens a `:malformed-delta` AuditFinding (FR-022) but does not lose the piece content (SC-010).

## Persisted format

`worlds/<name>/data/canon_deltas/<delta-id>.yml`:

```yaml
id: 01ABCDEF...              # ULID
piece_id: 002                # chapter number for chapter form, ULID for others
created_at: 2026-04-18T10:32:17Z
applied_at: 2026-04-18T10:32:19Z
reverted_at: null
parse_error: null
new_characters:
  - id: kev-bot
    name: Kev-Bot
    # ... (same as LLM output, but id passed through ValidationUtils.slugify)
new_locations: []
new_facts: [...]
new_events: [...]
new_relationships: []
entity_updates: [...]
```

## Id normalization

All ids in `new_*` sections and `entity_updates[].entity_id` MUST be passed through `Eidos::ValidationUtils.slugify` before the delta is applied or persisted. This keeps kebab-case consistent across the bible (matches the feature-013 slug-normalization convention).

## Apply semantics

`CanonDelta#apply!(bible:, canon:, audit_log:)`:

1. Validate: if `parse_error` is set, skip apply and open `:malformed-delta` finding. Return.
2. Atomic batch: open a new revision via existing `RevisionStore`.
3. For each `new_characters` entry: if a character with that slug already exists with different attributes, open `:conflict` finding AND apply the update (optimistic, FR-020). Otherwise, insert.
4. Same pattern for `new_locations`, `new_facts`, `new_events`, `new_relationships`.
5. For each `entity_updates` entry: if `old_value` does not match current canon, open `:conflict` finding AND apply (optimistic). Otherwise, apply silently.
6. Commit the revision. Set `applied_at`. Bump canon version on the owning Piece record.

If any step raises (e.g. storage write failure), the whole revision is rolled back — no partial state (FR-019). The piece file is still written; the delta is persisted with `applied_at: null` and `parse_error: "apply failed: <reason>"`.

## Revert semantics

`CanonDelta#revert!(bible:, canon:, audit_log:, finding:)`:

1. Write a reverse revision that undoes each entry (delete what was inserted; restore `old_value` for updates).
2. Set `reverted_at` on the delta.
3. Flip the owning Piece's `canon_status: reverted`; DO NOT touch the piece file.
4. Scan later pieces whose deltas reference any entity now rolled back. For each match, open an `:orphaned-reference` finding. This is how the revert-supersession edge case is surfaced.
5. Close the originating `finding` with `resolution: revert`, `resolved_at: Time.now`.
