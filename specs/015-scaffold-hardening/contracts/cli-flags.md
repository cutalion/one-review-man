# CLI Contract — 015 Scaffold Hardening

The contracts below describe the **user-facing command-line surface** changes in this feature. They are the boundary the integration test suite asserts against. Method-level Ruby signatures are implementation detail and not specified here.

---

## `eidos world new --quick` — new flag surface (US3, US4)

### Flags

| Flag | Arg type | Required (non-interactive) | Default | Description |
|------|---------|:---:|---------|-------------|
| `--title` | String | yes | — | World title |
| `--author` | String | yes | — | Author name |
| `--premise` | String | yes | — | Multi-line premise; newlines preserved verbatim |
| `--languages` | String (CSV) | no | `en` | Comma-separated ISO language codes (e.g., `en,ru`) |
| `--default-language` | String | no | first of `--languages` | Must be a member of `--languages` |
| `--genre` | String | no | `unspecified` | Explicit genre; used verbatim when provided |
| `--style` | String | no | `unspecified` | Explicit narrative style |
| `--setting` | String | no | `unspecified` | Explicit setting descriptor |
| `--theme` | String | no | `unspecified` | Explicit theme descriptor |
| `-w`, `--world-dir` | Path | no | cwd | Target directory (existing behavior) |
| `--force` | Bool | no | false | Overwrite existing world (existing behavior) |

### Behavior

**Interactive TTY + no flags** (existing behavior preserved):
- If `$stdin.tty? == true` AND zero quick-setup flags provided → fall through to the existing `tty-prompt` interactive flow. No change.

**Non-interactive OR any flag provided**:
- Thor parses flags. No stdin is read.
- Missing required flag → exit non-zero with a message naming each missing flag. Example:
  ```
  Error: --quick requires all of: --title, --author, --premise
  Missing: --author, --premise
  ```
- Invalid `--languages` (empty, non-ISO) → exit non-zero with a naming message.
- `--default-language` not in `--languages` → exit non-zero with a naming message.
- All inputs valid → world is scaffolded at `--world-dir` (or cwd); success exit code 0.

### Output (success)

Produces `data/world_config.yml` containing:

```yaml
title: <value of --title>
author: <value of --author>
subtitle: <value of --premise, newlines preserved>
description: <value of --premise, newlines preserved>   # same value; consolidation optional
languages: [<each code from --languages, trimmed>]
default_language: <value of --default-language or first of languages>
genre: <value of --genre or "unspecified">
style: <value of --style or "unspecified">
setting: <value of --setting or "unspecified">
theme: <value of --theme or "unspecified">
# ... existing unchanged fields (chapter_length_target, llm:, etc.)
```

### Output (failure — missing required flag)

- Exit code: non-zero.
- stderr: one line naming the missing flags.
- stdout: empty.
- Filesystem: no world directory created. No partial state left behind.

---

## `eidos canon review` — new finding kind (US1)

### Behavior

Scans `data/audit_findings.yml` (unchanged mechanism). Now recognizes `kind: 'parse-drop'` in addition to the existing `malformed-delta`, `conflict`, `orphaned-reference`.

### Output format

One block per finding. `parse-drop` findings render with at least:

```
[parse-drop]  delta <delta-id>  piece <piece-id or "—">
  Section: new_characters
  Dropped:  "Arthur is a programmer"
  Reason:   expected mapping, got String
```

The exact formatting is not part of the contract — the contract is: for every element of every delta's `parse_error.drops`, there is exactly one finding visible in `canon review` output, and the finding contains the delta id, piece id, section name, dropped value, and reason.

### Exit code

Unchanged. `canon review` exits 0 when invoked successfully, regardless of finding count. Findings are informational; users resolve them via existing flows.

---

## `eidos world status` — piece-first progress (US6, US4 surfacing)

### Behavior (new shape)

Enumerates `content/pieces/<form>/*.md` and `content/chapters/*.md`. Groups by form. Reports counts.

### Output structure

```
World: <title>
Author: <author>

[Metadata]
  genre: <value>
  style: <value>
  setting: <value>
  theme: <value>

[Pieces by form]
  chapter:    <count>
  vignette:   <count>
  haiku:      <count>
  …
  Total: <sum>

[Next step]
  <contextual hint — see below>
```

### Next-step hint rules

- Zero pieces across all forms: generic hint, e.g.
  ```
  No pieces yet. Run:
    eidos produce piece --form <form> --prompt "…"
  See `eidos produce --help` for available forms.
  ```
- One or more pieces exist: no "next step" block required (optional — may suggest canon review or new piece).
- Never "Run: produce chapter" as the universal suggestion. Chapter appears in the counts table like any other form.

### Metadata action items (ties in with US4)

When any of `genre`, `style`, `setting`, `theme` equals the sentinel `"unspecified"`, the `[Metadata]` block includes a trailing action-item line:

```
[Metadata]
  genre: unspecified
  style: contemporary
  setting: unspecified
  theme: unspecified
  ⚠️  Unspecified fields need your attention: genre, setting, theme.
      Edit data/world_config.yml or re-run `world new --quick --genre … --setting … --theme …`.
```

### Exit code

Unchanged. 0 on success.

---

## Scaffold directory layout (US5)

### Contract for a freshly created world

After `eidos world new --quick ...` completes successfully, the target directory contains:

```
<world>/
├── data/
│   ├── world_config.yml
│   ├── strings.yml
│   ├── forms/                     (may be empty or contain built-in form refs)
│   ├── story_bible/
│   │   └── (empty — populated on first canon-delta apply)
│   ├── canon_deltas/
│   │   └── (empty)
│   └── audit_findings.yml         (empty array or absent)
└── content/
    └── (empty — no subdirectories)
```

**What is NOT present**:
- `content/chapters/` (created on first `produce chapter` / `produce piece --form chapter`)
- `content/characters/` (created on first `produce piece --form character-bio` or similar)
- `content/pieces/<form>/` (created on first produce of that form)

### Contract for an existing pre-015 world

Unchanged. `worlds/one-review-man` and any other pre-existing world keeps its current `content/chapters/` and `content/characters/` directories. No migration, no cleanup.

---

## Validation scenarios (what the integration suite asserts)

Each row is one scenario the integration suite covers. These match the success criteria in `spec.md`.

| Scenario | Shelled command | On-disk assertion |
|---|---|---|
| Multi-line premise preserved | `world new --quick --title X --author Y --premise "line1\nline2\nline3" --languages en` | `world_config.yml` `subtitle` contains exact three lines; `languages: [en]`; `default_language: en` |
| Explicit metadata wins | same + `--genre comedy --style deadpan` | `world_config.yml` `genre: comedy`, `style: deadpan` |
| Absent metadata surfaces as unspecified | bare required flags only | `world_config.yml` `genre: unspecified` …; `world status` output includes "⚠️ Unspecified fields" |
| No empty content dirs | bare required flags only | `content/` exists; no subdirectories exist |
| Canon-delta bare-string drop | produce a piece with forced-malformed LLM mock | `data/canon_deltas/*.yml` `parse_error.drops` non-empty; `canon review` stdout contains "parse-drop" finding |
| Canon-delta applies to bible | produce a piece with well-formed mock declaring a named character | `data/story_bible/characters/<id>.yml` exists on disk with matching description |
| World status piece-first | produce 2 vignettes and 1 haiku | `world status` stdout contains "vignette: 2" and "haiku: 1"; does NOT contain "Run: produce chapter" |

---

## What this contract does NOT change

- `exe/eidos world new` (without `--quick`) — unchanged, non-interactive full flow via config file (if present).
- `eidos world status` for existing worlds — piece counts are derived from disk; a chapter-only world still shows `chapter: N` alongside whatever else exists.
- `eidos canon review`'s existing finding kinds — `malformed-delta`, `conflict`, `orphaned-reference` keep their shape and output format.
- `exe/eidos produce` flags — no flag changes.
- `eidos chapter`, `eidos character`, `eidos piece`, `eidos bible`, `eidos canon` subcommands outside of `canon review` — unchanged.
