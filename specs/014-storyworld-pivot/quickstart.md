# Quickstart: IP-Generator Pivot

**Feature**: 014-storyworld-pivot
**Audience**: Developer picking up this feature or first user trying the new pieces/forms/review flow.

This quickstart walks the three user stories end-to-end in the order they ship. Every command is runnable from the repo root with `MOCK_AI=true` for offline verification; drop the prefix to hit live models.

## Prerequisites

```bash
cd eidos
bundle install
cd ..
```

Confirm the test suite is green at the current coverage floor before you start:

```bash
MOCK_AI=true bundle exec --gemfile=eidos/Gemfile rspec eidos/spec
```

## Story 1 — P1: produce a non-chapter piece without book-era defaults

**Goal**: generate a 400-word vignette on `worlds/one-review-man`, confirm the chapter path still works byte-identically.

```bash
# 1. New piece in a non-chapter form.
MOCK_AI=true eidos/exe/eidos produce piece \
  --form vignette --prompt "Arthur's coffee machine files a grievance." \
  --length 400 -w worlds/one-review-man

# Expect:
#   - File at worlds/one-review-man/content/pieces/vignette/01H....md
#   - Frontmatter: form=vignette, category=text, canon_status=applied, canon_delta_ref=01H...
#   - Measured length ≈ 400 words (not padded up to chapter range)
#   - canon_delta_ref resolves to worlds/one-review-man/data/canon_deltas/01H....yml

# 2. Chapter path still produces byte-identical shape.
MOCK_AI=true eidos/exe/eidos produce chapter -w worlds/one-review-man --auto

# Expect:
#   - File at worlds/one-review-man/content/chapters/NNN-chapter.md
#   - Frontmatter keys match pre-feature shape exactly (chapter_number, word_count,
#     permalink, status, lang, canon_version, new_characters — all present, all in
#     the same order they were before the feature).

# 3. Docs drift check.
grep -rni "chapters of the book" CLAUDE.md eidos/lib/eidos/prompts/PLACEHOLDERS_REFERENCE.md
# Expect: no matches. Piece terminology should have replaced book-centric framing
# in user-facing docs.
```

Verification targets: SC-001, SC-002, SC-003.

## Story 2 — P2: add a custom form to a single world

**Goal**: drop a haiku form into `worlds/one-review-man`, invoke it without restarting anything.

```bash
# 1. Create a world-local haiku form.
mkdir -p worlds/one-review-man/data/forms
cat > worlds/one-review-man/data/forms/haiku.yml <<'YAML'
name: haiku
category: text
default_length: 3
default_shape: "3 lines, 5-7-5 syllables"
prompt_template_path: ./haiku.prompt.txt
canon_context:
  - all_characters
YAML
cat > worlds/one-review-man/data/forms/haiku.prompt.txt <<'TXT'
You are writing a haiku set in this world's canon.

Canon context:
{CANON_CONTEXT}

Prompt from user: {USER_PROMPT}
Shape: {LENGTH_TARGET}

Return only the haiku. Then emit the canonical changes it introduces after:

---CANON-DELTA---
new_characters: []
new_locations: []
new_facts: []
new_events: []
new_relationships: []
entity_updates: []
TXT

# 2. Invoke it via the short form (works because 'haiku' is unique in this world).
MOCK_AI=true eidos/exe/eidos produce haiku \
  --prompt "Arthur at 3am debugging a ghost null pointer." \
  -w worlds/one-review-man

# Expect:
#   - File under worlds/one-review-man/content/pieces/haiku/01H....md
#   - Measured length ≈ 3 lines (NOT pulled into chapter length range)
#   - A canon_delta_ref present even if empty

# 3. List available forms for the world.
MOCK_AI=true eidos/exe/eidos produce piece --help
# Expect: haiku appears alongside built-in chapter, vignette, short-story, etc.

# 4. Error path: unknown form lists availability.
MOCK_AI=true eidos/exe/eidos produce nonesuch --prompt "x" -w worlds/one-review-man
# Expect exit 1, and stderr listing the forms actually available for this world.
```

Verification targets: SC-004, SC-005, SC-006.

## Story 3 — P3: optimistic canon feedback + `canon review` audit

**Goal**: produce a piece that introduces a conflict with existing canon, see the finding, revert non-destructively.

```bash
# Setup: produce a piece that collides with an existing character attribute.
# In mock mode, use a fixture that deliberately triggers a :conflict finding
# against an existing character in one-review-man.
MOCK_AI=true eidos/exe/eidos produce piece \
  --form social-post \
  --prompt "A post from 'brenda-20' with a new conflicting role." \
  -w worlds/one-review-man

# 1. The piece was written AND canon was updated AND a finding opened.
MOCK_AI=true eidos/exe/eidos canon review -w worlds/one-review-man

# Expect:
#   1 open finding [conflict] referencing that piece, with remediation commands printed.

# 2. Revert the piece. The file on disk stays; canon_status flips to reverted.
FINDING=$(MOCK_AI=true eidos/exe/eidos canon review --format json -w worlds/one-review-man \
  | ruby -rjson -e 'puts JSON.parse(STDIN.read).first["id"]')

MOCK_AI=true eidos/exe/eidos canon revert --finding "$FINDING" -w worlds/one-review-man

# Expect:
#   - Piece file still present on disk.
#   - Piece frontmatter: canon_status: reverted
#   - Bible no longer reflects the conflicting attribute change.
#   - Finding closed with resolution: revert.

# 3. Second review shows the finding closed, zero remaining opens.
MOCK_AI=true eidos/exe/eidos canon review -w worlds/one-review-man
# Expect: "0 open findings"; closed finding visible under --status closed or --status all.

# 4. Dry-run preview on any form: no canon change, no file on disk.
MOCK_AI=true eidos/exe/eidos produce haiku --dry-run \
  --prompt "Preview only" -w worlds/one-review-man
# Expect:
#   - Piece text and proposed canon-delta block printed to stdout.
#   - No new file under content/pieces/haiku/.
#   - No new entry in data/canon_deltas/ or data/audit_log/findings.yml.
```

Verification targets: SC-007, SC-008, SC-009, SC-010, SC-013.

## Smoke test the whole feature

```bash
cd eidos
MOCK_AI=true bundle exec rspec
cd ..
```

Expect:
- All new specs pass (`piece_producer_spec.rb`, `form_registry_spec.rb`, `canon_delta_spec.rb`, `audit_log_spec.rb`, `audit_finding_spec.rb`, `canon_review_spec.rb`, `produce_spec.rb`, `piece_cli_spec.rb`, `chapter_producer_back_compat_spec.rb`).
- Existing specs still pass.
- SimpleCov coverage stays ≥ 47.15% (the current committed floor in `eidos/spec/support/coverage_setup.rb`). If coverage rises, bump `EIDOS_COVERAGE_FLOOR` in the same PR; never lower it.
- No prompt-assertion failures from the `MockLLMService` harness (every new template has all declared placeholders filled, no unused ones).

## What *not* to do during implementation

- Don't touch `worlds/one-review-man/content/chapters/` during dev; byte-identical shape is a contract (SC-002).
- Don't add a "deferred / pending approval" mode; the optimistic model is the spec (Q1 clarification).
- Don't delete a piece file on revert; `canon_status: reverted` is the non-destructive contract (Q2 clarification).
- Don't add LLM-assisted detections to `canon review` in MVP; stick to explicit findings only (Q3 clarification, and see Future Work in spec.md).
- Don't build a new versioning primitive; reuse `RevisionStore` / `SnapshotStore` / `BranchManager` (Decision 5 in research.md).
- Don't lower `EIDOS_COVERAGE_FLOOR` to unblock a red run; investigate the drop first (Decision 6 in research.md).

## What to do first

Recommended MVP-first slice: land Story 1 alone (terminology pivot + length unshackle + chapter byte-identical back-compat) as a shippable increment. It unlocks the rest without committing to the form registry or the review flow.
