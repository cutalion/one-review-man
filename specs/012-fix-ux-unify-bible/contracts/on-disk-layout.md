# Contract: On-Disk Layout Before/After

**Feature**: 012-fix-ux-unify-bible

This is the visible change on a user's filesystem.

---

## Before this feature (current state on `main`)

A world's data directory can be in any of three shapes:

**Shape A — legacy only** (older worlds):
```
worlds/<name>/data/
├── world.yml           # characters (some), locations, culture, infrastructure
├── story_facts.yml     # facts, additional locations
├── characters.yml      # characters (also)
├── settings.yml
├── world_config.yml
├── world_state.yml
├── generation_log.yml
└── strings.yml
```

**Shape B — SDK-first** (worlds created via `eidos bible add-character` etc.):
```
worlds/<name>/data/
├── story_bible/
│   ├── characters.yml
│   ├── locations.yml
│   ├── facts.yml
│   ├── relationships.yml
│   └── plot_threads.yml
├── settings.yml
├── world_config.yml
├── world_state.yml
├── generation_log.yml
└── strings.yml
```

**Shape C — dual-state** (the one real case: `worlds/one-review-man/`):
Both Shape A and Shape B present simultaneously. `ChapterGenerator` reads from A; SDK/CLI reads from B.

---

## After this feature

Exactly one shape: **Shape B**.

```
worlds/<name>/data/
├── story_bible/
│   ├── characters.yml
│   ├── locations.yml
│   ├── facts.yml
│   ├── relationships.yml
│   └── plot_threads.yml
├── settings.yml
├── world_config.yml
├── world_state.yml
├── generation_log.yml
└── strings.yml
```

No `data/world.yml`. No `data/story_facts.yml`. No `data/characters.yml` at the top level (that legacy single-file flavor is also dropped — characters live in `data/story_bible/characters.yml`).

### Transition for each prior shape

| Prior shape | Transition |
|---|---|
| A (legacy only) | **Not supported at runtime.** Eidos ignores stray `world.yml` / `story_facts.yml`. The user is responsible for manual migration if they had such a world. In practice no such world exists in this repo. |
| B (SDK-first) | No change. Works as-is on day one after this feature. |
| C (dual-state — one-review-man) | **Manually cleaned up in this PR.** After verification that `data/story_bible/` has the canonical data, `data/world.yml` and `data/story_facts.yml` are deleted and committed. |

---

## Jekyll site layout (unchanged)

`StoryBibleExporter` continues to write `world.yml` and `story_facts.yml` into the Jekyll site's `_data/` directory. That's the Jekyll contract, not the canonical world store. This feature does not touch it.

```
site/
└── _data/
    ├── world.yml           # produced by exporter; consumed by Jekyll templates
    └── story_facts.yml     # produced by exporter
```

---

## Debug artifacts (unchanged)

```
tmp/ai_debug/
├── last_prompt.txt
├── last_response.txt
└── ...
```

Integration tests inspect these to verify that seeded / added characters reach the LLM prompt (FR-011, FR-012).

---

## Contract tests

- Fresh `world new --quick` in a temp dir must produce no `data/world.yml` and no `data/story_facts.yml` in the created directory.
- `cli_spec.rb` (existing) already asserts which files are produced; update to remove any mention of `data/world.yml` and add an assertion that `data/story_bible/` exists.
