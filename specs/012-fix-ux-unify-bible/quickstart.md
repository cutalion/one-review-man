# Quickstart: Verifying Feature 012

**Feature**: 012-fix-ux-unify-bible

Use this document to sanity-check the feature end-to-end after implementation. All commands assume you are at the repo root, on branch `012-fix-ux-unify-bible`.

---

## Prerequisites

- Ruby 3.3.5 and Bundler installed.
- API credentials optional — everything below runs under `MOCK_AI=true`.

```bash
cd eidos
bundle install
```

---

## 1. Existing test suite still passes

```bash
cd eidos
MOCK_AI=true bundle exec rspec
```

Expected: all examples green (baseline 544; may grow with new specs in this feature).

---

## 2. Fresh world is clean on disk

```bash
tmp=$(mktemp -d)
ruby eidos/bin/world new --world-dir "$tmp" --quick <<< $'Quickstart Book\nQuickstart Author\nA test book\nen\nen\n'

# Should show the canonical layout only
ls "$tmp/data"
# Expect: characters.yml, generation_log.yml, settings.yml, story_bible/, strings.yml,
#         world.yml (legacy), world_config.yml, world_state.yml, world.yml  ← this last one MUST NOT be there
```

Post-feature acceptance: there is NO `data/world.yml` and NO `data/story_facts.yml` in `$tmp/data`. There IS a populated `data/story_bible/`.

---

## 3. First-run output is clean

```bash
MOCK_AI=true ruby eidos/bin/produce chapter --world-dir "$tmp" 2>&1 | tee /tmp/first_run.log
```

Check the log:

```bash
grep -c "Migrated"              /tmp/first_run.log   # must be 0
grep -c "CHARACTER_NAME"        /tmp/first_run.log   # must be 0
grep -c "CHARACTER_DESCRIPTION" /tmp/first_run.log   # must be 0
grep -c "Not specified"         /tmp/first_run.log   # must be 0
```

All four counts must be `0`. This is SC-001.

---

## 4. Character added via SDK appears in next chapter's prompt

```bash
ruby -Ieidos/lib -reidos -e '
  Eidos.configure { |c| c.worlds_path = "'$tmp'/.." }
  world = Eidos::World.new(File.basename("'$tmp'"))
  world.bible.add_character(id: "jax", name: "Jax Patel", description: "a laid-off dev")
'

MOCK_AI=true ruby eidos/bin/produce chapter --world-dir "$tmp"
grep -l "Jax Patel" tmp/ai_debug/*.txt
```

Expected: at least one debug artifact in `tmp/ai_debug/` contains `Jax Patel`. This is FR-011.

---

## 5. `--content-model` override reaches the generator

```bash
ruby eidos/bin/produce chapter --world-dir "$tmp" --content-model "test-model" --debug 2>&1 | grep "using model"
```

Expected line:
```
Generating Chapter N using model test-model...
```

Not `gpt-4o-mini` or the default. This is FR-008.

---

## 6. `eidos world reset chapters` actually deletes files

```bash
ls "$tmp/content/chapters/"    # note how many files
ruby eidos/bin/world reset chapters --world-dir "$tmp" --force
ls "$tmp/content/chapters/"    # expect empty (or directory gone)
```

Expected: the directory is empty after reset. This is FR-009.

---

## 7. Seed extraction happens (interactive) or is skipped (quick)

Interactive path — confirms FR-015:

```bash
tmp2=$(mktemp -d)
# Provide premise, accept seed prompt
MOCK_AI=true ruby eidos/bin/world new --world-dir "$tmp2" <<< $'Job Hunter\nMe\nA programmer looking for work in a recession\nen\nen\ny\n'

# Should have seeded entries
ruby eidos/bin/bible list --world-dir "$tmp2" | grep "(seed)"
```

Expected: at least one entry tagged `(seed)`. This is US3's acceptance.

`--quick` path — confirms no prompt:

```bash
tmp3=$(mktemp -d)
MOCK_AI=true ruby eidos/bin/world new --world-dir "$tmp3" --quick <<< $'Quick World\nMe\nA test\nen\nen\n'

ruby eidos/bin/bible list --world-dir "$tmp3"   # expect empty or near-empty
```

---

## 8. Legacy files in the repo's one real world are gone

```bash
ls worlds/one-review-man/data/world.yml          2>&1 || echo "missing (correct)"
ls worlds/one-review-man/data/story_facts.yml    2>&1 || echo "missing (correct)"
```

Both should be absent. This is FR-014a.

---

## Exit criteria for merge

- RSpec: 100% pass under `MOCK_AI=true`.
- `grep -r 'world\.yml\|story_facts\.yml' eidos/lib/` returns zero hits for runtime code paths (exporter and `story_bible_migrator.rb` standalone references are exceptions — document them in the PR).
- Manual quickstart steps 2–8 pass on a fresh checkout.
- SC-001 grep checks (step 3) all return `0`.
