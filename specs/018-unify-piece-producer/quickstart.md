# Quickstart: Verifying Feature 018a

**Feature**: 018-unify-piece-producer
**Date**: 2026-04-29
**Purpose**: end-to-end verification mirroring SC-001..SC-007.

## Prerequisites

- On branch `018-unify-piece-producer`.
- Three new failing specs landed (one per user story); test-first discipline observed (Constitution Principle I).
- `Eidos::WorldState`, `PieceProducer` extension, `CanonDelta#apply!` atomicity, and CLI rewrites all implemented.
- `Eidos::ChapterGenerator`, `Eidos::Producers::ChapterProducer`, `eidos produce write` Thor method all deleted.
- Dependent specs migrated.

---

## Step 1 — Failing specs before implementation (Constitution Principle I)

Before any production-code changes, write the three new specs and verify they fail on `main`:

```bash
cd /home/cutalion/code/one-review-man/eidos
git stash   # if any in-progress work
git checkout main -- lib/

# Write the three new specs in spec/eidos/world_state_spec.rb,
# spec/eidos/canon_delta_atomicity_spec.rb,
# spec/eidos/producers/piece_producer_chapter_spec.rb

MOCK_AI=true bundle exec rspec \
  spec/eidos/world_state_spec.rb \
  spec/eidos/canon_delta_atomicity_spec.rb \
  spec/eidos/producers/piece_producer_chapter_spec.rb 2>&1 | tail -10
```

**Expected**: all three spec files have failing examples on `main`. If any spec passes pre-implementation, the test isn't strong enough — strengthen it before continuing.

---

## Step 2 — `WorldState` implementation; revision-counter spec passes

Implement `eidos/lib/eidos/world_state.rb` per `data-model.md` and `contracts/world-state-migration.md`. Re-run:

```bash
MOCK_AI=true bundle exec rspec spec/eidos/world_state_spec.rb 2>&1 | tail -5
```

**Expected**: 0 failures. All `WorldState` invariants (read-existing, migrate-missing, raise-corrupt, atomic-advance) verified.

---

## Step 3 — `CanonDelta#apply!` atomicity

Thread the `world_state:` injectable through `apply!` per `contracts/canon-revision-atomicity.md`. Re-run:

```bash
MOCK_AI=true bundle exec rspec spec/eidos/canon_delta_atomicity_spec.rb 2>&1 | tail -5
```

**Expected**: 0 failures. Atomicity holds across produce, revert, rollback paths.

---

## Step 4 — `PieceProducer` chapter parity

Add the `structured_output: true` flag to `eidos/lib/eidos/forms/chapter.yml`; implement structured-output dispatch in `PieceProducer#produce`; rename `next_chapter_id` to `next_chapter_number`; update `current_canon_version` to read from `WorldState`. Re-run:

```bash
MOCK_AI=true bundle exec rspec spec/eidos/producers/piece_producer_chapter_spec.rb 2>&1 | tail -5
```

**Expected**: 0 failures. Chapter produces parity-shaped output via `PieceProducer`.

---

## Step 5 — CLI rewrites + legacy deletion

- `eidos/lib/eidos/cli/produce.rb`: rewrite the `chapter` Thor action to delegate to `PieceProducer.new(...).produce(form: 'chapter', ...)` with `chapter_number` injection from `next_chapter_number`. Delete the `def write(chapter = nil)` Thor method.
- `eidos/lib/eidos/cli/world.rb`: scaffold writes `canon: { revision: 0 }` into `world_state.yml`.
- `eidos/lib/eidos/cli/helpers.rb`: `render_status_report` adds a `Canon revision: N` line.
- Delete `eidos/lib/eidos/chapter_generator.rb`.
- Delete `eidos/lib/eidos/producers/chapter_producer.rb` (including the `Producer.register(:chapter, ChapterProducer)` line).
- Delete: `spec/chapter_generation_spec.rb`, `spec/eidos/chapter_generator_spec.rb`, `spec/eidos/producers/chapter_producer_spec.rb`, `spec/eidos/producers/chapter_producer_back_compat_spec.rb`.
- Migrate: `spec/integration/chapter_number_regression_spec.rb`, `spec/integration/produce_chapter_prompt_flag_spec.rb` to drive `PieceProducer`.

```bash
MOCK_AI=true bundle exec rspec 2>&1 | tail -3
```

**Expected**: full suite green; ~775 examples (count may shift slightly due to spec deletions and additions); 0 failures; SimpleCov coverage at or above the floor.

---

## Step 6 — Manual end-to-end on a fresh world

```bash
cd /home/cutalion/code/one-review-man

# Scaffold a fresh world
rm -rf tmp/test-018a-world
eidos/exe/eidos world new --quick \
  -w tmp/test-018a-world \
  --title "018a Smoke Test" \
  --author "Test" \
  --premise "Verifying chapter unification and canon revision counter." \
  --languages en

# Confirm world_state.yml has canon.revision: 0
grep -A1 "^canon:" tmp/test-018a-world/data/world_state.yml

# world status shows the revision
eidos/exe/eidos world status -w tmp/test-018a-world | grep -i "canon revision"

# Produce a chapter via the unified path (mock AI)
MOCK_AI=true eidos/exe/eidos produce chapter -w tmp/test-018a-world --auto

# Inspect the chapter file's frontmatter — id is a hash, canon_version is integer
head -20 tmp/test-018a-world/content/chapters/001-chapter.md

# Confirm a canon-delta file was written
ls tmp/test-018a-world/data/canon_deltas/

# Confirm world status now shows revision 1
eidos/exe/eidos world status -w tmp/test-018a-world | grep -i "canon revision"

# Produce a vignette and confirm parity
MOCK_AI=true eidos/exe/eidos produce piece --form vignette \
  --prompt "Test vignette." -w tmp/test-018a-world

# revision now 2
eidos/exe/eidos world status -w tmp/test-018a-world | grep -i "canon revision"

rm -rf tmp/test-018a-world
```

**Expected**:
- `canon.revision: 0` in the scaffold output.
- `Canon revision: 0` in the initial `world status`.
- After `produce chapter`: chapter file has `id` (hash), `form: chapter`, `chapter_number: 1`, `canon_version: 1`, `canon_delta_ref` pointing to a real file. Canon-delta file exists at `data/canon_deltas/<id>.yml`.
- After `produce vignette`: `Canon revision: 2`.

This step is **SC-001, SC-002, SC-003**.

---

## Step 7 — `/impl-qa --behavioral` passes (SC-004)

```bash
# In a Claude Code session with the impl-qa subagent dispatchable:
/impl-qa --behavioral
```

**Expected**: `Verdict: PASS` with **zero Tier-2 failures**. Specifically, the four T025 failures from feature 016's behavioral run are all flipped to PASS:
1. Chapter file frontmatter has `id`, `form`, `canon_delta_ref`. ✓
2. `produce chapter` writes a canon-delta file. ✓
3. `world_state.yml` has `canon.revision`. ✓
4. `world_status` shows the revision. ✓

---

## Step 8 — `worlds/one-review-man` still works (SC-007)

```bash
# Without migrating one-review-man (that's 018c's job), confirm:
eidos/exe/eidos piece show $(ls worlds/one-review-man/content/chapters/ | head -1 | sed 's/-chapter.md//') -w worlds/one-review-man 2>&1 | head -10
eidos/exe/eidos chapter list -w worlds/one-review-man 2>&1 | head -5

# world status against one-review-man — the in-place migration kicks in
eidos/exe/eidos world status -w worlds/one-review-man 2>&1 | tail -10
```

**Expected**:
- `piece show` and `chapter list` both succeed (legacy chapter files remain readable via `Piece#from_file` default-synthesis).
- `world status` emits one `Migrating .../world_state.yml: adding canon.revision = N` log line on first invocation, then reports `Canon revision: N` (where N = count of files in `worlds/one-review-man/data/canon_deltas/`).
- Subsequent invocations of any command against one-review-man do NOT emit the migration log line again (field is now present).

---

## Step 9 — Structural verification (SC-005)

```bash
cd /home/cutalion/code/one-review-man
grep -r "ChapterGenerator" eidos/lib/ ; echo "exit=$?"
grep -rE "def write\b|desc.*write" eidos/lib/eidos/cli/produce.rb ; echo "exit=$?"
grep -r "Producer.register(:chapter" eidos/lib/ ; echo "exit=$?"
```

**Expected**: all three greps return exit code 1 (no matches). Confirms `ChapterGenerator`, `produce write`, and the chapter producer registration are fully retired.

---

## Acceptance summary

The feature is ready to merge when:

| Check | Source |
|---|---|
| Step 1 fails | three new specs catch the gaps pre-implementation |
| Step 2 passes | `WorldState` works |
| Step 3 passes | atomicity holds |
| Step 4 passes | chapter parity holds |
| Step 5 passes | full suite green |
| Step 6 manual | fresh-world end-to-end works |
| Step 7 PASS | impl-qa behavioral verifies all four T025 flip |
| Step 8 works | one-review-man still readable; in-place migration runs once |
| Step 9 zero matches | legacy class + command + registration gone |

PR description includes Step 6 wall-clock (manual produce time), Step 7 verdict, and the rspec count from Step 5.

---

## Note on FR-006a — migration retirement

The in-place migration verified in Step 8 is **temporary scaffolding**. After feature 018c migrates `worlds/one-review-man` explicitly, this code path becomes dead. 018c's task list MUST include "remove `WorldState`'s missing-field migration branch" and tighten the contract to raise on missing field. This 018a contract document (`contracts/world-state-migration.md`) becomes archival history at that point.
