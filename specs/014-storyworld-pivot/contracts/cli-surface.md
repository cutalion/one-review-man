# CLI Surface Contract

**Feature**: 014-storyworld-pivot

All commands are dispatched by the unified `eidos` Thor router (`eidos/exe/eidos`) and are equivalently invokable via the legacy domain binaries under `eidos/bin/`. Every command accepts `--world-dir` / `-w` per Principle II.

---

## NEW: `eidos produce piece`

```text
eidos produce piece --form <name> --prompt "<text>"
                    [--world-dir PATH] [--length N] [--dry-run]
                    [--debug] [--auto]
```

| Flag | Required | Default | Notes |
|---|---|---|---|
| `--form` | yes | — | Must resolve against the world's FormRegistry. Error on unknown form lists available forms (FR-014). |
| `--prompt` | yes | — | Free-form user prompt passed into the form's template. |
| `--length` | no | form's `default_length` | Target length; unit is form-declared. Supersedes world's `chapter_length_target` for non-chapter forms (FR-004). |
| `--dry-run` | no | false | Show piece + canon delta in terminal; write nothing (FR-018 mode b). |
| `--world-dir` / `-w` | no | cwd-walk | Standard world resolution. |
| `--auto` | no | false | Non-interactive; no confirmation prompts. |
| `--debug` | no | false | Verbose LLM logging to `tmp/ai_debug/`. |

**Exit codes**:
- `0` — piece generated and written (or shown, in dry-run).
- `1` — unknown form; error listing available forms.
- `2` — LLM call failed; piece not written; no audit finding (failure is before delta parse).
- `3` — form template missing; registry warning + exit.

**Stdout**: summary line with form, piece id, path, measured length, canon version, delta summary (count per section), and if any audit finding was opened, its id and kind.

---

## NEW: `eidos produce <form>` (short form)

```text
eidos produce haiku --prompt "..." [--world-dir PATH] [--length N] [--dry-run]
```

Short dispatch: when the first argument after `produce` matches a registered form name in the active world's FormRegistry (and is not a reserved subcommand like `chapter`, `piece`, `comic`), the CLI delegates to `produce piece --form <name>`. Reserved subcommands always win over custom forms to avoid hijacking existing paths.

The existing `eidos produce chapter` path is a reserved subcommand and retains its current flags and output shape (FR-002).

---

## UPDATED: `eidos produce chapter` (no change to user contract)

All existing flags and behavior preserved (FR-002, SC-002). Internally delegates to `PieceProducer` with form=`chapter`, but the user-visible contract — flags, output path (`worlds/<name>/content/chapters/NNN-chapter.md`), frontmatter keys — is unchanged.

---

## NEW: `eidos canon review`

```text
eidos canon review [--world-dir PATH] [--status open|closed|all]
                   [--kind conflict|malformed-delta|orphaned-reference]
                   [--piece PIECE_ID] [--format text|json]
```

Read-only. Lists audit findings. No flags → defaults to `--status open --format text`.

**Stdout (text format)**: one block per finding with id, kind, status, piece id, canon version before/after, one-paragraph explanation, severity, and — for `open` findings — a footer listing the remediation commands.

**Stdout (json format)**: JSON array of finding records suitable for piping.

**Exit codes**:
- `0` — success regardless of whether findings exist. A clean review prints `0 findings` and exits 0.
- `1` — cannot read audit log (corrupt or permission).

---

## NEW: `eidos canon revert`

```text
eidos canon revert --finding FINDING_ID [--world-dir PATH]
                   [--also-regenerate] [--dry-run]
```

Rolls back the CanonDelta associated with the finding:
- Writes a reverse revision through the existing `RevisionStore`.
- Flips the originating piece's record `canon_status: reverted`.
- Leaves the piece file on disk unchanged (Q2 decision).
- Closes the finding with `resolution: revert`.
- If `--also-regenerate`, immediately kicks off a new `produce piece --form <same-form>` invocation with a flag indicating it's a replacement (new piece id, no relationship stored to the reverted one in MVP).
- Emits `:orphaned-reference` findings if any subsequent pieces referenced entities now rolled back.

**Exit codes**:
- `0` — revert applied (or previewed in `--dry-run`).
- `1` — finding not found or already closed.
- `2` — revert blocked by canon invariant (future: none in MVP).

---

## NEW: `eidos canon accept` / `eidos canon patch`

```text
eidos canon accept --finding FINDING_ID [--world-dir PATH] [--note TEXT]
eidos canon patch  --finding FINDING_ID [--world-dir PATH]
```

- `accept`: closes the finding with `resolution: accept`. No canon mutation.
- `patch`: opens the referenced entity (character/location/fact/relationship) in the user's `$EDITOR` (YAML source) and writes through the existing `Eidos::Storage` interface. On successful save, closes the finding with `resolution: patch-canon`.

**Exit codes**: `0` on success, `1` on finding lookup failure, `2` on editor/save failure.

---

## NEW: `eidos piece list` / `eidos piece show`

SDK-based commands following the pattern of `eidos chapter list` / `eidos character show`.

```text
eidos piece list [--world-dir PATH] [--form FORM] [--status applied|reverted|all]
eidos piece show PIECE_ID [--world-dir PATH]
```

Both are read-only. `list` prints a table (id, form, length, generated_date, canon_status, canon_version). `show` prints frontmatter + content (or asset path + prompt for image forms).

---

## UPDATED: `eidos world` docs / help text

`eidos world` help strings and any emitted user-facing text that frames content as "chapters of a book" are updated to piece terminology (FR-005). No flag changes. No command-name changes.

---

## CLI invariant tests (plan gate)

The following must be covered by RSpec with `MOCK_AI=true`:

1. `produce chapter` on an existing world produces byte-identical output shape to pre-feature (SC-002).
2. `produce haiku --length 3` produces a piece whose measured length is within tolerance of 3 lines and is NOT padded up to the chapter length (SC-001).
3. `produce <unknown-form>` lists the available forms in stderr and exits 1 (FR-014).
4. `produce piece --form haiku --dry-run` writes zero files and prints the delta tail (FR-018 dry-run).
5. A world with a custom `haiku.yml` in `data/forms/` that collides with a built-in emits the override notice (FR-013).
6. `canon review` on a clean world returns zero findings and exits 0.
7. Producing a piece whose delta collides with existing canon opens exactly one `:conflict` finding and subsequent `canon review` surfaces it.
8. `canon revert --finding <id>` flips the piece record to `canon_status: reverted`, leaves the file on disk, and closes the finding with `resolution: revert`.
9. `canon revert` on a delta whose entities are referenced by a later piece opens an `:orphaned-reference` finding for that downstream piece.
10. A malformed LLM delta response results in an `:empty` CanonDelta with `parse_error` set AND a `:malformed-delta` finding AND preserved piece content on disk (SC-010).
