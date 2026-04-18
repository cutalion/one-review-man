# Quickstart — 015 Scaffold Hardening

How to validate this feature locally, end-to-end, against a freshly generated world. Follow this before marking any task `[X]` per CLAUDE.md Definition of Done.

---

## Prerequisites

- Working copy on branch `015-scaffold-hardening`.
- Ruby 3.3.5, bundle installed: `cd eidos && bundle install`.
- For live-LLM validation (SC-007 only): `OPENAI_API_KEY` in `~/.config/eidos/.env` or exported.

---

## 1 — Run the unit suite

```bash
cd eidos
MOCK_AI=true bundle exec rspec
```

Expected: 0 failures. Coverage at or above `EIDOS_COVERAGE_FLOOR`. Prompt-assertion harness silent (no unfilled/unused placeholder errors).

---

## 2 — Run the user-scale integration suite (new in 015)

```bash
cd eidos
MOCK_AI=true bundle exec rspec spec/integration/user_scale/
```

This suite shells `exe/eidos` end-to-end and asserts on disk artifacts. It is NOT included in the default `rspec` run — invoke it explicitly.

Expected: 0 failures. Each scenario creates and cleans up its own `Dir.mktmpdir` world — no state leaked to `worlds/`.

---

## 3 — Verify each user story individually

### US3 — Non-interactive `world new --quick` accepts multi-line premise

```bash
rm -rf /tmp/qa-us3
eidos/exe/eidos world new --quick \
  -w /tmp/qa-us3 \
  --title "Test World" \
  --author "QA" \
  --premise "A multi-line premise.
Second line with a comma, quotes, and — punctuation.
Third line." \
  --languages en,ru \
  --default-language en
```

Check:

```bash
cat /tmp/qa-us3/data/world_config.yml
```

Expected: `subtitle` and `description` contain all three lines verbatim. `languages: [en, ru]`. `default_language: en`. No prose fragments in `languages`.

### US3 — Missing required flag surfaces a clear error

```bash
eidos/exe/eidos world new --quick -w /tmp/qa-us3-missing --title "X"
```

Expected: non-zero exit; stderr names `--author` and `--premise` as missing; no world created.

### US4 — Absent metadata produces visible sentinel, not a lie

Using the world from US3:

```bash
grep -E '^(genre|style|setting|theme):' /tmp/qa-us3/data/world_config.yml
```

Expected: all four are `unspecified` (since we didn't pass `--genre` etc).

```bash
eidos/exe/eidos world status -w /tmp/qa-us3
```

Expected: status output includes an "Unspecified fields need your attention" line listing `genre`, `style`, `setting`, `theme`.

### US4 — Explicit flags win

```bash
rm -rf /tmp/qa-us4
eidos/exe/eidos world new --quick -w /tmp/qa-us4 \
  --title "T" --author "A" --premise "p" \
  --genre comedy --style deadpan --setting "office" --theme "AI revolution"
grep -E '^(genre|style|setting|theme):' /tmp/qa-us4/data/world_config.yml
```

Expected: values are literally `comedy`, `deadpan`, `office`, `AI revolution`. No inference overlay.

### US1 — Canon-delta bare-string drops are visible

Using `MOCK_AI=true` with a mock tuned to return a delta whose `new_characters` is `["Arthur is a programmer"]`:

```bash
MOCK_AI=true MOCK_RESPONSE=canon_delta_bare_string \
  eidos/exe/eidos produce piece --form vignette --prompt "any" -w /tmp/qa-us3
```

Check:

```bash
ls /tmp/qa-us3/data/canon_deltas/
cat /tmp/qa-us3/data/canon_deltas/*.yml | head -40
```

Expected: `parse_error` is a hash with `summary:` and a non-empty `drops:` array. Each drop has `section`, `value`, `reason`.

```bash
eidos/exe/eidos canon review -w /tmp/qa-us3
```

Expected: output includes a `[parse-drop]` finding naming the piece, delta, section, dropped value.

### US2 — Well-formed delta persists to bible

With a mock that returns a well-formed canon-delta declaring a named character (Arthur, description "A programmer"):

```bash
rm -rf /tmp/qa-us2 && eidos/exe/eidos world new --quick -w /tmp/qa-us2 \
  --title T --author A --premise p
MOCK_AI=true MOCK_RESPONSE=canon_delta_arthur \
  eidos/exe/eidos produce piece --form vignette --prompt "any" -w /tmp/qa-us2
```

Check:

```bash
ls /tmp/qa-us2/data/story_bible/characters/
cat /tmp/qa-us2/data/story_bible/characters/arthur.yml
```

Expected: file exists on disk. `description` field matches `"A programmer"`.

### US5 — No orphan scaffold directories

```bash
rm -rf /tmp/qa-us5 && eidos/exe/eidos world new --quick -w /tmp/qa-us5 \
  --title T --author A --premise p
find /tmp/qa-us5/content -type d
```

Expected: only `/tmp/qa-us5/content` itself. No `content/chapters`, no `content/characters`.

Then produce a piece:

```bash
MOCK_AI=true eidos/exe/eidos produce piece --form haiku --prompt "x" -w /tmp/qa-us5
find /tmp/qa-us5/content -type d
```

Expected: now `/tmp/qa-us5/content/pieces/haiku/` exists, because it was created on demand.

### US5 — Backwards compat: `worlds/one-review-man` untouched

```bash
ls worlds/one-review-man/content/
```

Expected: pre-existing directories (including `chapters/`, `characters/`) still present. This feature does not delete anything from existing worlds.

### US6 — `world status` is piece-first

With the US5 world that now contains one haiku:

```bash
eidos/exe/eidos world status -w /tmp/qa-us5
```

Expected:
- Output lists a `[Pieces by form]` block with `haiku: 1`.
- Output does NOT contain `Run: produce chapter` as the suggestion.
- For an empty world, suggestion is generic (`produce piece --form <form>`), not chapter-specific.

---

## 4 — Run the demo script end-to-end

```bash
rm -rf ~/worlds/job-hunt
scripts/demo_job_hunt.sh
```

Expected: script succeeds. Check:

```bash
cat ~/worlds/job-hunt/data/world_config.yml
ls ~/worlds/job-hunt/data/story_bible/characters/
ls ~/worlds/job-hunt/content/
eidos/exe/eidos world status -w ~/worlds/job-hunt
eidos/exe/eidos canon review -w ~/worlds/job-hunt
```

Expected:

- `world_config.yml` `subtitle`/`description` contain the full demo premise verbatim.
- `languages` is `[en]` (or whatever demo passes) — no prose fragments.
- `genre`/`style`/`setting`/`theme` are either user-supplied values or `unspecified`, never the old `fiction`/`narrative`/`contemporary setting`/`adventure` defaults.
- `data/story_bible/characters/arthur.yml` exists when the demo produced a piece that introduced Arthur.
- `content/chapters/` does NOT exist (this is a piece-first demo).
- `world status` lists piece counts by form; does not recommend `produce chapter`.
- `canon review` shows parse-drop findings if any deltas had drops; otherwise clean.

---

## 5 — Run `/user-qa` against the demo world (SC-007, blocking for done-state)

```bash
# In the Claude Code session:
/user-qa scripts/demo_job_hunt.sh "A 40-year-old programmer with 20+ years of experience quits his stable job, convinced that landing a new one will be quick. Instead he wakes up in the middle of the AI revolution: recruiters have been replaced by spam funnels, take-home coding tests are graded by hallucinating LLMs, every job post demands 7 years of a framework that's 3 years old, and his carefully crafted resume gets rewritten by an AI that adds blockchain to his skill list. Deadpan, dry, quietly miserable tone — observational humor, not slapstick. Main character: Arthur."
```

Use **live LLM** mode. Per CLAUDE.md Definition of Done, SC-007 requires a live-LLM PASS.

Expected verdict: **PASS** across all three tiers (structural, intent consistency, UX smoke).

If any Tier-1 failure: the feature is not done. Do not mark tasks `[X]`. Fix the root cause; do not weaken the QA check.

---

## 6 — Verify the silent-fallback ban is discoverable (SC-009)

```bash
grep -A 5 "silent fallback" CLAUDE.md
```

Expected: a section titled something like "Banned patterns: silent fallbacks" with at least the three acceptable alternatives (raise / Result / user-visible channel) enumerated.

---

## Troubleshooting

- **`world new --quick` hangs waiting for input**: means the non-interactive path didn't detect non-TTY correctly, or flags were not recognized. Check `exe/eidos world new --help` shows the new flags.
- **Bible remains empty after produce**: indicates US2 regression. Re-read `apply_character` (`canon_delta.rb:235`) — `return nil unless id` or a memory-backed bible are the two likely causes. Do NOT paper over with a test that asserts only `applied_at`.
- **Integration suite runs in default `rspec`**: confirm `.rspec` excludes `spec/integration/user_scale/` from auto-discovery.
- **`/user-qa` report says "agent type 'user-qa' not found"**: subagent registration loads at session start. Restart the Claude Code session.

---

## Summary

| Step | What it validates | Required to mark done? |
|------|---|---|
| 1 — unit suite | Regression safety net | yes |
| 2 — integration suite | User-scale disk-artifact assertions | yes |
| 3 — per-US manual walkthrough | Individual story independence | nice to have |
| 4 — demo script | End-to-end smoke | yes |
| 5 — `/user-qa` live | Definition of Done | **yes (blocking)** |
| 6 — CLAUDE.md grep | SC-009 | yes |

All six must pass before 015 is shipped.
