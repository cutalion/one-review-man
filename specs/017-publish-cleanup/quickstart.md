# Quickstart: Verifying Feature 017

**Feature**: 017-publish-cleanup
**Date**: 2026-04-29
**Purpose**: Manual end-to-end verification that the `publish.rb` fix removes the source-world side effect, the published site still builds with all needed data, and the regression test catches future regressions.

## Prerequisites

- On branch `017-publish-cleanup`.
- `eidos/lib/eidos/cli/publish.rb` modified per the plan: exporter call moved AFTER the data-copy step, with `exporter.export_to(File.join(dest_dir, '_data'))` instead of `exporter.export_for_jekyll!`.
- `eidos/spec/eidos/cli/publish_spec.rb` added per the contract.

---

## Step 1 — Failing test before the fix (Constitution Principle I)

Before applying the publish.rb diff, write the new RSpec file. Run only that file:

```bash
cd /home/cutalion/code/one-review-man/eidos
MOCK_AI=true bundle exec rspec spec/eidos/cli/publish_spec.rb 2>&1 | tail -10
```

**Expected**: at least one test fails — the "leaves the source world byte-identical" test should report new files (`data/world.yml`, `data/story_facts.yml`) appearing in the source after publish.

If the test passes BEFORE the publish.rb fix lands, the test isn't strong enough. Strengthen it before continuing.

---

## Step 2 — Apply the fix and re-run the targeted spec

After applying the publish.rb diff:

```bash
cd /home/cutalion/code/one-review-man/eidos
MOCK_AI=true bundle exec rspec spec/eidos/cli/publish_spec.rb 2>&1 | tail -5
```

**Expected**: 0 failures.

---

## Step 3 — Full RSpec suite

```bash
cd /home/cutalion/code/one-review-man/eidos
MOCK_AI=true bundle exec rspec 2>&1 | tail -3
```

**Expected**: 772+ examples, 0 failures. Coverage held at or above the committed `EIDOS_COVERAGE_FLOOR`. (If coverage drops, investigate before committing.)

---

## Step 4 — Manual end-to-end against `worlds/one-review-man`

```bash
cd /home/cutalion/code/one-review-man

# Clean any prior pollution from the bug
rm -f worlds/one-review-man/data/world.yml \
      worlds/one-review-man/data/story_facts.yml

# Snapshot source world
git status --short worlds/one-review-man/

# Run publish to a sandbox destination (NOT the real ./site)
rm -rf tmp/site-test-017
mkdir -p tmp/site-test-017
eidos/exe/eidos publish jekyll -w worlds/one-review-man --dest tmp/site-test-017

# Snapshot source world again — expect SAME output as before publish
git status --short worlds/one-review-man/
```

**Expected**: the second `git status` output is byte-identical to the first. No new untracked files. (SC-001, SC-004.)

---

## Step 5 — Idempotence

```bash
cd /home/cutalion/code/one-review-man

# Run publish a second and third time
eidos/exe/eidos publish jekyll -w worlds/one-review-man --dest tmp/site-test-017
eidos/exe/eidos publish jekyll -w worlds/one-review-man --dest tmp/site-test-017

git status --short worlds/one-review-man/
```

**Expected**: source world remains clean across 3 successive publish runs. (SC-003.)

---

## Step 6 — Site builds with no unsubstituted placeholders

```bash
cd /home/cutalion/code/one-review-man/tmp/site-test-017
bundle exec jekyll build 2>&1 | tail -3

# Verify zero unsubstituted placeholders in the rendered HTML
grep -rE '\{\{[A-Z_]+\}\}' _site/ | head -5
```

**Expected**: jekyll build completes successfully (modulo CSS deprecation warnings, which are pre-existing). The grep returns zero matches. (SC-002.)

Sanity-check the title is correctly substituted:

```bash
grep -o '<title>[^<]*</title>' _site/index.html
```

**Expected**: `<title>All Chapters - One Review Man</title>` (not literal `{{STORY_TITLE}}`).

---

## Step 7 — Equivalence with the real site (optional but recommended)

Compare the destination produced by feature 017's publish to the existing `site/_site/`:

```bash
cd /home/cutalion/code/one-review-man
diff -rq tmp/site-test-017/_site/ site/_site/ | head -20
```

**Expected**: differences are limited to assets-with-mtimes / build-timestamps / cache files — no semantic differences in chapter, character, or index pages.

---

## Step 8 — `eidos bible export` still works (out-of-scope sanity)

The `bible export` subcommand is the legitimate caller of `export_for_jekyll!`. Verify the fix didn't accidentally regress it:

```bash
cd /home/cutalion/code/one-review-man

# bible export should still write into the source world's data/ directory.
# This is its declared contract — unchanged by feature 017.
eidos/exe/eidos bible export -w worlds/one-review-man

git status --short worlds/one-review-man/
```

**Expected**: `bible export` writes `data/world.yml`, `data/story_facts.yml`, `data/characters.yml` into the source. `git status` reflects those writes. This is correct — `bible export` is allowed to do this; only `publish jekyll` is forbidden from doing it.

Reset before committing: `rm -f worlds/one-review-man/data/world.yml worlds/one-review-man/data/story_facts.yml`.

---

## Acceptance summary

The feature is ready to merge when:

| Check | Source |
|---|---|
| Step 1 fails | regression spec catches the bug pre-fix |
| Step 2 passes | regression spec passes post-fix |
| Step 3 passes | full RSpec green, coverage held |
| Step 4 source clean | manual end-to-end against the real world |
| Step 5 idempotent | source still clean after 3 publish runs |
| Step 6 placeholders 0 | rendered site has no unsubstituted tokens |
| Step 7 site equivalent | destination matches the prior site/_site semantically |
| Step 8 bible export OK | the legitimate caller of export_for_jekyll! still works |

If all eight pass, the feature satisfies SC-001 through SC-005 and is ready to merge.
