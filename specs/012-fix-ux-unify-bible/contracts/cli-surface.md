# Contract: CLI Surface Changes

**Feature**: 012-fix-ux-unify-bible

Eidos' external contract is the `eidos` CLI. This document enumerates every user-visible change to that contract.

---

## `eidos world new` (interactive mode)

### Added flag

- `--no-seed` — skip the premise-to-bible seed extraction step without prompting. No-op in `--quick` mode (already skipped). Default: off.

### Behavior changes

1. **Defaults aligned with options.** Every prompt that offers a default AND a list of options now offers a default that appears in the list. Currently-misaligned examples (`genre: "fiction"`, `style: "narrative"`) are changed so the default matches an option.
2. **Single language prompt.** The user is asked for language exactly once per `world new` run. The second prompt (translation target language) is removed; if the user wants translations, they use `eidos translate` later.
3. **Premise-to-bible seed step (new).** After capturing the premise in interactive mode, the wizard prints:
   ```
   Seed the Story Bible from your premise? [Y/n]
   ```
   - Default Yes (Enter accepts).
   - On Yes: call `Eidos::SeedExtractor#extract(premise:)`, persist any returned entries to the Story Bible with `origin: "seed"`. Show `"Seeded N characters, M locations, K facts."` or on failure `"Seed extraction skipped: <reason>. Continuing."`.
   - On No / `--no-seed` / `--quick`: skip silently.
4. **No `data/world.yml` written.** Fresh worlds no longer receive a `data/world.yml` file. Their canonical lore lives in `data/story_bible/` from the first keystroke.

### Unchanged

- Non-interactive flags (`--world-dir`, `--quick`, all stdin-driven prompts).
- `settings.yml` structure (provider/model defaults already landed in `4c77bd2`).
- Exit codes.

---

## `eidos produce chapter`

### Behavior changes

1. **No "Migrated world.yml to story_facts.yml" output.** The auto-migration code path in `ChapterGenerator` is removed. On worlds without legacy files, nothing changes visibly. On worlds that still have stray legacy files (from an old checkout), the files are ignored.
2. **No `CHARACTER_NAME` / `CHARACTER_DESCRIPTION` literal leaks.** When the bible has no characters, the character section of the prompt is omitted, not interpolated with placeholder tokens.
3. **No "Difficulty: Not specified" in chapter metadata.** Fields with no value are omitted rather than rendered as "Not specified".
4. **Substantive chapter title.** The LLM is asked to include a `title` field in its structured output; the chapter's title reflects the chapter's content (fallback to `"Chapter #{N}"` only on LLM failure).
5. **Reads from Story Bible.** Internal implementation detail, but observable via `tmp/ai_debug/` artifacts: characters/locations/facts in the prompt come from `data/story_bible/`, not from `data/world.yml` / `data/story_facts.yml`.

### Unchanged

- CLI flags, arguments, exit codes, and chapter file layout (`content/chapters/`).

---

## `eidos world reset chapters`

### Behavior changes

Already fixed on `main` in an earlier commit in this session: globs `content/chapters/*.md` (previously `_chapters/*.md`). This feature adds a regression spec so it doesn't revert.

### Unchanged

- CLI flag surface.

---

## `eidos bible list`

### Behavior additions

- Seeded entries show an `(seed)` marker in the output so the user can recognize premise-derived candidates and choose to edit, keep, or remove them.

### Unchanged

- Command name, flags, sort order.

---

## Not changed

- `eidos probe` — untouched by this feature.
- `eidos translate` — untouched.
- `eidos publish` — untouched (still uses `StoryBibleExporter` to produce Jekyll `_data/world.yml` etc.).
- `eidos chapter` / `eidos character` SDK-based subcommands — untouched (they already read through the SDK).

---

## Contract tests

Each CLI behavior above is validated by an RSpec example in `spec/eidos/cli/*_spec.rb` or the first-run integration spec. The integration spec asserts the substrings in **SC-001** are absent from stdout:

- No occurrence of `"Migrated"`
- No occurrence of `"CHARACTER_NAME"`
- No occurrence of `"CHARACTER_DESCRIPTION"`
- No occurrence of `"Not specified"`
