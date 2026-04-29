# Contract: Chapter-via-PieceProducer Parity

**Owner**: `Eidos::Producers::PieceProducer` (post-018a)
**Verified by**: `eidos/spec/eidos/producers/piece_producer_chapter_spec.rb` (NEW)

After feature 018a, `eidos produce chapter` and `eidos produce piece --form chapter` MUST produce *the same shape* of output as `eidos produce piece --form vignette` (or any other form), modulo form-specific frontmatter fields. This contract defines exactly what "the same shape" means.

---

## Required frontmatter on every produced piece (any form)

```yaml
id: <ULID-style hash, 26 chars>     # uniform across forms; never derived from chapter_number
form: <form-name>                    # 'chapter', 'vignette', 'haiku', etc.
generated_date: <ISO 8601 date>
canon_version: <integer> | <snapshot-label-string>
canon_delta_ref: data/canon_deltas/<id>.yml
```

These five keys are the universal contract. They appear on every form's frontmatter exactly the same way.

**Forbidden values**:
- `canon_version: 'unversioned'` — newly produced pieces post-018a never carry this string. If `WorldState` cannot supply a revision number (e.g. `world_state.yml` is missing), the producer raises before writing the file.

---

## Form-specific frontmatter (in addition to the universal keys)

These vary by form. Chapter has the most; haiku has the least.

| Form | Form-specific keys |
|---|---|
| `chapter` | `title`, `summary`, `chapter_number` (integer); plus Jekyll passthroughs `permalink`, `lang` if needed |
| `vignette`, `short-story` | `title` (if extracted) |
| `haiku` | (none) |
| `comic-script` | (none — panels in body) |
| `portrait`, `illustration` | image-specific (unchanged from today) |
| `social-post` | (none) |

The chapter form's `chapter_number` is the *only* connection between `chapter`'s frontmatter and its on-disk filename. `id` is independent; `chapter_number` is human-meaningful.

---

## On-disk filename derivation

| Form | Filename |
|---|---|
| `chapter` | `content/chapters/<NNN>-chapter.md` where `NNN` is `format('%03d', chapter_number)` |
| every other form | `content/pieces/<form>/<id>.md` |

The chapter filename rule is the single legacy carve-out preserved by 018a (per Q1 clarification — keeps the human-readable on-disk shape users currently have). Every other form uses the uniform `content/pieces/<form>/<id>.md`.

---

## Canon-delta link

Every successful produce (any form) writes a canon-delta file at `data/canon_deltas/<id>.yml` whose `piece_id` matches the piece frontmatter's `id` and whose `applied_at` is timestamped at the moment apply succeeds. Chapter is no exception.

The delta's body schema (the `new_characters`, `new_locations`, `new_facts`, `new_relationships`, `new_events`, `entity_updates`, `parse_drops` sections) is unchanged from current `CanonDelta` for non-chapter forms.

---

## Test methodology

The new spec `eidos/spec/eidos/producers/piece_producer_chapter_spec.rb` MUST contain at minimum these examples:

```ruby
describe 'chapter form via PieceProducer' do
  it 'writes the universal frontmatter keys (id, form, generated_date, canon_version, canon_delta_ref)' do
    # produce chapter under MOCK_AI=true
    # parse the produced file's frontmatter
    # assert each universal key is present and well-typed
  end

  it 'writes the chapter-specific keys (title, summary, chapter_number)' do
    # ...
  end

  it 'derives the on-disk filename from chapter_number, not id' do
    # produce chapter under MOCK_AI=true
    # assert path matches /content\/chapters\/\d{3}-chapter\.md\z/
    # assert frontmatter id is a hash, NOT equal to chapter_number
  end

  it 'writes a canon-delta file at data/canon_deltas/<id>.yml linked back to the piece' do
    # ...
  end

  it 'writes canon_version as an integer (post-018a)' do
    # produce chapter; parse frontmatter; assert canon_version is_a?(Integer)
  end

  it 'writes canon_version as the snapshot label when --snapshot is pinned' do
    # take a snapshot, then produce chapter --snapshot <name>
    # assert frontmatter canon_version == <name>
  end
end

describe 'parity between chapter and other forms' do
  it 'produces a chapter and a vignette with the same set of universal frontmatter keys' do
    # produce both; assert chapter_keys ⊇ vignette_keys + chapter-specific keys
    # assert vignette has zero chapter-specific keys
  end
end
```

---

## Failure modes

When the LLM returns a malformed structured-output envelope (e.g., the response is not valid JSON, OR it is valid JSON but missing one of the required fields `title` / `summary` / `body`), `PieceProducer` MUST surface the failure as a `parse-drop` `AuditFinding` via the existing canon-delta machinery — the same mechanism `CanonDelta#apply!` already uses for malformed delta entries. The producer MUST NOT silently substitute defaults (e.g., empty title, empty summary), and MUST NOT retry indefinitely.

Concretely, on a parse failure during chapter produce:

- The piece file is **NOT** written to disk.
- A canon-delta file is **NOT** written under `data/canon_deltas/`.
- The `canon.revision` counter is **NOT** advanced.
- One `AuditFinding` of `kind: 'parse-drop'` is opened, with the raw LLM response in its evidence field and a `piece_id` referring to the (unwritten) piece's intended id.
- The Thor command exits non-zero with a user-visible message naming the finding id, of the form: `parse-drop finding <id>: chapter generation produced a malformed envelope. Run 'eidos canon review' to inspect.`

This matches the project's banned-patterns rule (no silent fallback) and reuses the existing audit-log surface so the user discovers the failure via `eidos canon review` — the same mechanism every other parse failure already uses. Implementations MUST NOT retry the LLM call automatically; if the user wants a retry, they re-run `produce chapter`.

The `piece_producer_chapter_spec.rb` (T012) MUST contain at least one example covering this path: stub `MockLLMService` to return non-JSON for a chapter produce; assert no piece file is written, no delta file is written, the revision counter is unchanged, and one `parse-drop` `AuditFinding` is opened.

## What this contract does NOT cover

- The contents of the chapter prompt template (which is per-form prompt-engineering, not a shape contract).
- The exact semantics of `--length` for chapter (preserved from current `ChapterGenerator`; reuse the existing `world_config.chapter_length_target` fallback).
- `eidos produce comic --chapter=N` and similar legacy chapter-keyed producers — these are 018b's scope.
- Migration of existing chapter files in `worlds/one-review-man` to this shape — that's 018c.
