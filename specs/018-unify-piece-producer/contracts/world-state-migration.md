# Contract: `WorldState` In-Place Migration of Existing Worlds

**Owner**: `Eidos::WorldState#current_revision` (the migration path)
**Verified by**: `eidos/spec/eidos/world_state_spec.rb` (NEW)
**Retirement timeline**: see FR-006a — this entire migration path MUST be removed in/after feature 018c

---

## Why this exists

Worlds created before feature 018a do not have a `canon` mapping in `data/world_state.yml`. The first time post-018a code touches such a world (typically via a `produce` or a `world status`), `WorldState#current_revision` must do *something* sensible. Per FR-006, that something is an **in-place migration**: compute the value retroactively from on-disk evidence, write it, log a single user-visible line, and proceed.

This is temporary scaffolding. The project carries exactly one long-running legacy world (`worlds/one-review-man`). Once 018c migrates that world explicitly, this code is dead and gets deleted (FR-006a).

---

## When the migration triggers

`WorldState#current_revision` is called for the first time on a world. Inspecting `data/world_state.yml`:

| Observed state | Action |
|---|---|
| `canon.revision` is present (any non-negative integer) | Return it. No migration. (Common case for post-018a worlds.) |
| `canon` mapping is missing entirely, OR `canon` is present but `canon.revision` is missing | **Run the migration** (see below) |
| `world_state.yml` itself is missing | **Raise `Eidos::WorldState::CorruptWorldError`** with a message naming the missing path. Do NOT migrate. (A world without `world_state.yml` is corrupt; silently creating one would mask the corruption.) |
| `canon.revision` is present but is not a non-negative integer (e.g. a string, a float, negative) | **Raise `Eidos::WorldState::CorruptWorldError`** with a message naming the bad value. Do NOT silently coerce. |

---

## The migration steps

Given a world whose `world_state.yml` exists but lacks `canon.revision`:

1. **Compute the retroactive revision**. Count the YAML files in `data/canon_deltas/`:
   - If `data/canon_deltas/` exists: revision = `Dir.glob(File.join(world_path, 'data', 'canon_deltas', '*.yml')).count`. Each delta represents one historical apply. Zero is a valid result for a world that has been scaffolded but never produced a piece.
   - If `data/canon_deltas/` does NOT exist: **raise `Eidos::WorldState::CorruptWorldError`** with the message `"Cannot migrate <world>/data/world_state.yml: data/canon_deltas/ directory is absent. Investigate before proceeding."` Do NOT silently default to 0 — directory absence implies world corruption (the directory should have been created at scaffold time even when empty), and treating it as "0 deltas" is exactly the banned-pattern silent fallback.

2. **Write the result back to `world_state.yml`**. Add the `canon: { revision: <N> }` mapping (top-level). Do not touch other keys. Use atomic write (write to tmp file + rename) to avoid corrupting the file on partial-write failure.

3. **Emit a single user-visible log line** of exactly this shape:
   ```
   Migrating <abs path to world_state.yml>: adding canon.revision = <N>
   ```
   Use the project's existing `say` helper (Thor's color-aware output) when called from a CLI context, or `warn` (or equivalent stderr write) when called from a non-CLI context. The line is informational, not an error — but it MUST appear so a user can see the migration happened.

4. **Return `<N>` to the caller** as the current revision.

5. The next call to `current_revision` against the same world reads from `world_state.yml` directly (no migration; the field is now present).

---

## What the migration MUST NOT do

- **MUST NOT silently default to 0** when the file is missing or the directory is absent. Both cases are corrupt-world signals; raising is the only correct behavior.
- **MUST NOT prompt the user interactively**. The migration is for human-and-CI use; interactive prompts break automation.
- **MUST NOT mutate any other field of `world_state.yml`** beyond adding the `canon` mapping. If `world_state.yml` has unrecognized keys, leave them.
- **MUST NOT log if the field was already present** — only log on actual migration. Otherwise every `world status` call would spam.

---

## Test methodology

The new spec `eidos/spec/eidos/world_state_spec.rb` MUST contain at minimum these examples:

```ruby
describe 'Eidos::WorldState' do
  describe '#current_revision (already-present field)' do
    it 'reads canon.revision from world_state.yml when present' do
      # write world_state.yml with canon: { revision: 42 }
      # assert WorldState.new(world_path:).current_revision == 42
      # assert no migration log line was emitted
    end
  end

  describe '#current_revision (in-place migration)' do
    it 'migrates and returns count(canon_deltas/*.yml) when canon.revision is missing' do
      # write world_state.yml WITHOUT canon mapping
      # populate data/canon_deltas/ with 5 dummy yml files
      # call current_revision
      # assert returns 5
      # assert the file now has canon: { revision: 5 }
      # assert one migration log line was emitted (capture stdout/stderr)
    end

    it 'returns 0 (and migrates) when data/canon_deltas/ exists but is empty' do
      # write world_state.yml WITHOUT canon mapping
      # mkdir data/canon_deltas/ but leave it empty
      # call current_revision
      # assert returns 0
      # assert canon: { revision: 0 } now in file
    end

    it 'raises CorruptWorldError when data/canon_deltas/ does not exist' do
      # write world_state.yml WITHOUT canon mapping
      # do NOT create data/canon_deltas/
      # expect WorldState.new(world_path:).current_revision to raise CorruptWorldError
      # assert error message names the missing path
      # assert world_state.yml was NOT modified (atomic — migration aborted)
    end
  end

  describe '#current_revision (corrupt-world signals)' do
    it 'raises CorruptWorldError when world_state.yml is missing' do
      # do not create world_state.yml
      # expect raises CorruptWorldError
    end

    it 'raises CorruptWorldError when canon.revision is a non-integer' do
      # write canon: { revision: "seventeen" }
      # expect raises CorruptWorldError
    end

    it 'raises CorruptWorldError when canon.revision is negative' do
      # write canon: { revision: -1 }
      # expect raises CorruptWorldError
    end
  end

  describe '#advance_revision!' do
    it 'increments by exactly 1 and returns the new value' do
      # write canon: { revision: 7 }
      # assert advance_revision! returns 8
      # assert file now has canon: { revision: 8 }
    end

    it 'is atomic — partial-write failure leaves the previous value' do
      # write canon: { revision: 7 }
      # stub File.rename (or equivalent atomic-write step) to raise
      # expect advance_revision! to raise
      # assert file still has canon: { revision: 7 }
    end
  end
end
```

---

## Retirement (per FR-006a)

The migration code in `WorldState#current_revision` is in scope for deletion as a final step of feature 018c (or as a small follow-up cleanup feature immediately after 018c lands). Once `worlds/one-review-man` has been migrated explicitly by 018c — and given the project carries no other long-running legacy world — there is no future caller for the migration branch.

Concrete deletion plan:
- Remove the "if `canon.revision` is missing → migrate" branch from `WorldState#current_revision`.
- Replace with: `raise CorruptWorldError` if missing (because post-018c, every world has the field).
- Delete the migration-specific tests in `world_state_spec.rb`.
- Tag the corresponding section of CLAUDE.md (if any) as resolved.

This contract document itself can be archived (move to `specs/018-unify-piece-producer/legacy-world-state-migration.md` with a note) once the code is gone, as a record of why the migration existed.
