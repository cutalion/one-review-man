# Contract: SDK / Engine Surface Changes

**Feature**: 012-fix-ux-unify-bible

---

## `Eidos::StoryBible`

### Public API — unchanged

All existing methods keep their signatures: `#characters`, `#locations`, `#facts`, `#relationships`, `#plot_threads`, `#search`, plus the add/update helpers. No rename, no deprecation, no breaking change.

### Internal additions (not exposed as public API)

- A helper to return character/location/fact data in the shape `ChapterGenerator` wants (so `ChapterGenerator` doesn't re-parse the YAML itself). Placement: either a small adapter on `StoryBible` or a utility method in `ChapterGenerator`. Final placement is a code-review decision; both satisfy the constitution.

---

## `Eidos::ChapterGenerator`

### Constructor — unchanged

Still accepts its injectable collaborators (`LLMService`, `OutputAdapter`, `PromptProvider`, optional `StoryBible`).

### Behavior changes

- **No longer calls** `migrate_world_data_to_story_facts`. The method may remain temporarily as a no-op (for any caller we haven't audited) or be deleted outright; `tasks.md` will decide.
- **No longer reads** `data/world.yml` or `data/story_facts.yml` for character/location/fact data. All lore reads go through `@story_bible`.
- **Always instantiates (or accepts) a `StoryBible`.** If one isn't passed, it's loaded from the world on init.
- **Asks the LLM for a chapter title** as part of the structured response.

### API stability

- `ChapterGenerator#generate` returns the same result shape. Existing callers don't need changes.

---

## `Eidos::SeedExtractor` (NEW)

```ruby
class Eidos::SeedExtractor
  # @param llm_service [Eidos::LLMService]
  # @param story_bible [Eidos::StoryBible]
  def initialize(llm_service:, story_bible:); end

  # Never raises. On failure returns SeedResult with empty arrays + a warning.
  #
  # @param premise [String] the user's world description
  # @return [Eidos::SeedResult]
  def extract(premise:); end
end

# Value object
SeedResult = Struct.new(:characters, :locations, :facts, :warnings, keyword_init: true)
```

Contract guarantees:

- `#extract` never raises. All failures collapse to an empty `SeedResult` with one warning.
- `#extract` does **not** persist anything. The caller (typically `cli/world.rb`) is responsible for writing accepted entries into the Story Bible via its public methods.
- Output is capped: ≤3 characters, ≤2 locations, ≤3 facts, regardless of what the LLM returns.
- Each returned entry is shaped like a normal Character/Location/Fact hash, plus the `origin: "seed"` and `origin_note: "derived from premise"` keys.

### Test doubles

Under `MOCK_AI=true`, `mock_responses.yml` gains a `seed_extractor_default` entry returning a small canned set of characters/locations/facts so unit tests are deterministic.

---

## `Eidos::World`

No public API change. `world.bible` is now, truly, the only lore store. Previously some read paths silently went through legacy files; after this feature, they all route through `world.bible`.

---

## Deprecations / removals

- **`Eidos::StoryBibleMigrator`** — kept in the code base but removed from all runtime call sites. It remains available for one-off scripting via `bin/` if needed; not wired into any CLI command in this feature. A follow-up feature may delete it outright.
- **`Eidos::Utils.load_world_data` / similar `world.yml` loaders** — removed entirely. Any remaining callers are rewritten to go through `StoryBible`.

---

## Contract tests

- `spec/eidos/story_bible_spec.rb` — no regressions.
- `spec/eidos/seed_extractor_spec.rb` — new: success path (mocked LLM returns well-shaped JSON), malformed-JSON path (warnings populated, no raise), timeout path, cap enforcement.
- `spec/eidos/chapter_generator_spec.rb` — add: reads characters from the injected `StoryBible`, not from `data/world.yml`; emits no "Migrated" output on a fresh tmp world.
- `spec/eidos/integration/first_run_spec.rb` — end-to-end using `Open3.capture3`, asserts no forbidden substrings from SC-001.
