# Contract: Canon-Revision Atomicity

**Owner**: `Eidos::CanonDelta#apply!` + `Eidos::WorldState#advance_revision!`
**Verified by**: `eidos/spec/eidos/canon_delta_atomicity_spec.rb` (NEW)

After feature 018a, every successful canon mutation (a `CanonDelta#apply!` invocation) advances `canon.revision` in `data/world_state.yml` by **exactly 1**. Failure to advance the bible's mutations and failure to advance the counter MUST happen together — never one without the other.

---

## The atomicity invariant

For any single call to `CanonDelta#apply!`, the world is observable in exactly one of two states after the call returns:

1. **Pre-apply** (call raised, all rollback ran): bible files are unchanged from before the call; `canon.revision` is unchanged from before the call.
2. **Post-apply** (call returned successfully): every applicable bible file reflects the delta's mutations; `canon.revision` is exactly 1 higher than before the call.

The world MUST NEVER be observable in a third state where the bible has advanced but the counter hasn't, or where the counter has advanced but the bible hasn't.

---

## Implementation requirement

Inside `CanonDelta#apply!`, the call to `world_state.advance_revision!` MUST be placed:

- **AFTER** all bible-mutating sub-operations succeed (after the `@new_characters.each`, `@new_locations.each`, `@new_facts.each`, `@new_relationships.each`, `@new_events.each`, `@entity_updates.each` loops).
- **BEFORE** the `@applied_at = Time.now.utc` stamp.
- **INSIDE** the existing `begin/rescue StandardError => e` block that wraps the bible mutations.

If `advance_revision!` raises (e.g. disk full, file permission error, corrupt `world_state.yml`), the existing `rollback!(bible, applied_actions)` path runs and the original error is re-raised. The bible is rolled back; the counter was never written.

---

## Code-shape sketch

```ruby
# eidos/lib/eidos/canon_delta.rb (apply! method, post-018a)
def apply!(bible:, audit_log:, canon_version_before:, canon_version_after:,
           piece_id:, world_path: nil, world_state: nil)
  # ... existing setup ...
  world_state ||= Eidos::WorldState.new(world_path: world_path)

  applied_actions = []
  conflict_findings = []
  begin
    # ... existing bible-mutating loops (unchanged) ...

    # NEW: advance the revision counter inside the same rescue scope.
    # If this raises, rollback! runs and the bible mutations are undone.
    new_revision = world_state.advance_revision!

    # canon_version_after gets the new revision threaded back through;
    # callers (PieceProducer) use this for the piece's frontmatter.
    @canon_version_after_resolved = new_revision
  rescue StandardError => e
    rollback!(bible, applied_actions)
    raise e
  end

  @applied_at = Time.now.utc
  # ... existing audit-log writes (unchanged) ...
end
```

---

## Behavior across the three call sites

| Caller | Direction | Effect on `canon.revision` |
|---|---|---|
| `PieceProducer#apply_delta` (called from a successful produce) | apply forward | +1 |
| `Canon#revert_finding` (called from `eidos canon revert --finding=<id>`) | apply inverse | +1 (revert is itself a canon mutation) |
| `Canon#rollback_entity` (called from `eidos canon rollback <type> <id> <rev>`) | apply per-entity rollback | +1 (per-entity rollback is itself a canon mutation) |

In all three cases, `apply!` is the single place that increments. No caller increments separately.

---

## Test methodology

The new spec `eidos/spec/eidos/canon_delta_atomicity_spec.rb` MUST contain at minimum these examples:

```ruby
describe 'CanonDelta#apply! atomicity' do
  it 'advances canon.revision by exactly 1 on a successful apply' do
    # set up a temp world with canon.revision = 7
    # build a CanonDelta with one new_character entry
    # call apply!
    # assert canon.revision == 8 in world_state.yml on disk
    # assert the new_character entry is in the bible
  end

  it 'leaves canon.revision unchanged when apply! raises' do
    # set up a temp world with canon.revision = 7
    # build a CanonDelta whose apply path will raise (e.g. inject a failing storage backend)
    # call apply! and expect it to raise
    # assert canon.revision is still 7 on disk
    # assert no bible mutation was persisted
  end

  it 'leaves canon.revision unchanged when world_state.advance_revision! raises' do
    # set up a temp world with canon.revision = 7
    # build a CanonDelta with one new_character entry
    # inject a WorldState double whose advance_revision! raises
    # call apply! and expect it to raise
    # assert canon.revision is still 7 on disk
    # assert the new_character entry is NOT in the bible (rollback ran)
  end

  it 'advances canon.revision on canon revert (--finding=<id>)' do
    # produce a piece (revision 0 -> 1)
    # call canon revert --finding=<id> against the resulting finding (or the inverse-delta apply path directly)
    # assert canon.revision == 2 (revert is a canon mutation)
  end

  it 'advances canon.revision on canon rollback' do
    # produce a piece (revision 0 -> 1); accept; then rollback the entity
    # assert canon.revision advances on the rollback step
  end
end
```

---

## Concurrency note

This contract does NOT define behavior for two concurrent `apply!` invocations against the same world. If two processes attempt simultaneous applies, the YAML file write may race. Detection or prevention of that race is OUT OF SCOPE for 018a; the project does not have multi-process invariants today and adding file-locking is a separate spec. (A passing test may still race in CI under heavy load — if observed, address with `Mutex` inside `WorldState` instances, or document as known-issue.)

---

## What this contract does NOT cover

- The shape of audit-log findings (unchanged from current `CanonDelta#apply!`).
- The semantics of `parse_drops`, `conflicts`, `orphaned_references` — these continue to surface as `AuditFinding`s with the existing kinds.
- The migration logic for missing `canon.revision` on existing worlds — that's `world-state-migration.md`.
