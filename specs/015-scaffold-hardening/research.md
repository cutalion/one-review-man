# Research — 015 Scaffold Hardening

**Date**: 2026-04-18
**Status**: All NEEDS-CLARIFICATION resolved.

This document records the material decisions taken during Phase 0 planning. Implementation-level choices (variable naming, exact method signatures) are deferred to `/speckit.tasks`.

---

## R1 — Canon-delta parse-error shape

**Context**: US1 / FR-001..FR-003. Today `Eidos::CanonDelta.normalize_section` (`eidos/lib/eidos/canon_delta.rb:73`) drops non-mapping entries with a stderr `warn` and `next nil`. `parse_error` is currently a single string ("YAML parse error: ..." or "delta document must be a YAML mapping") used for document-level failures only — it is null for entry-level drops.

The spec's Assumptions state the change is a "population change, not a schema change": `parse_error` already exists and is nullable; we extend its population, not its name.

### Decision

`parse_error` becomes a **structured record** when any drop or document-level issue is present, null otherwise. Shape:

```yaml
parse_error:
  summary: "2 non-mapping entries dropped across new_characters, new_facts"
  drops:
    - section: new_characters
      value: "Arthur is a poet"
      reason: "expected mapping, got String"
    - section: new_facts
      value: "the world is grim"
      reason: "expected mapping, got String"
```

For document-level failures (missing sentinel, bad YAML), the record carries only `summary` and no `drops` — preserving information parity with today's string-valued `parse_error`.

On read (`CanonDelta.from_hash`), accept either a string (legacy) or a hash (new). String-valued `parse_error` is converted in-memory to `{ summary: <string>, drops: [] }` so downstream code sees one shape.

### Rationale

- **Single field, richer value.** No YAML schema migration; no new top-level field.
- **`eidos canon review` gets structured data.** FR-002 requires one user-visible finding per dropped entry. A structured `drops:` array is directly iterable by the review command.
- **Backwards-compat on read.** Existing worlds keep parsing — the deserializer degrades gracefully.
- **Cheap to write.** Populating a hash is as cheap as populating a string; no performance impact.

### Alternatives considered

- **New top-level `drops:` field on the delta document.** Rejected: the spec explicitly frames this as a population change, and adding a field is an unnecessary schema expansion when `parse_error` already signals "parser had problems with this delta."
- **Keep stderr warnings as authoritative, mirror them to the audit log.** Rejected: users do not read stderr. The spec's FR-023 bans stderr-only signaling. Mirroring doubles the surface with no benefit — better to not emit stderr at all once the record + finding exists.
- **Abort delta parse on first drop, return document-level error.** Rejected: the LLM routinely emits partial-valid deltas (Arthur as a well-formed mapping alongside "Marcus" as a bare string). Losing Arthur to save a clean failure surface would be worse than today's behavior.

---

## R2 — Canon-delta drop surfacing in `canon review`

**Context**: FR-002. Review must report one finding per dropped entry, with piece id, delta id, category, dropped value.

### Decision

Reuse the existing `AuditFinding` / `AuditLog` mechanism. Introduce one new finding kind: `'parse-drop'` (alongside the existing `'malformed-delta'` and `'conflict'` kinds). Opened automatically by `CanonDelta#apply!` when `parse_error` contains a non-empty `drops:` array, one finding per drop. The existing `open_malformed_finding` method is the blueprint.

### Rationale

- **Zero infrastructure.** AuditLog already persists findings under `data/audit_findings.yml`; `canon review` already enumerates them. Adding a finding kind is a one-line change per call site.
- **Consistent with existing "conflict" findings.** Users already learn to read findings as "something the parser/applier noticed but did not fail on."
- **Separates "whole delta unusable" (malformed-delta) from "some entries dropped" (parse-drop).** Different severities; the review output can color or sort them separately if we want to.

### Alternatives considered

- **Fold into the existing `'malformed-delta'` kind.** Rejected: that kind currently means "delta entirely unusable, no entities applied." Drops should not pollute that signal; a delta with 1 drop and 5 successes is not malformed.
- **New `CanonIssue` class separate from `AuditFinding`.** Rejected: duplicates infrastructure. `AuditFinding` is already the project's "thing the user should look at" record.

---

## R3 — `apply_delta` persistence: root cause hypothesis for US2

**Context**: FR-004..FR-006. Postmortem observed: delta declared Arthur + Arthur's Apartment with `applied_at` set and `parse_error` null, yet `data/story_bible/characters/` stayed empty.

Reading `CanonDelta#apply_character` (`canon_delta.rb:235`): `return nil unless id`. If the LLM emits `{ "name": "Arthur", "description": "A programmer" }` with no `id` key, this early-returns with zero filesystem writes, zero findings, zero warnings.

`CanonDelta.normalize_section` (line 82-84) only slugifies `id` if `id` is already present — it does not derive an id from `name`.

### Decision

Two complementary fixes, both necessary:

1. **Derive `id` from `name` when missing** in `normalize_section`. Use the existing `Eidos::ValidationUtils.slugify(entry['name'])`. If neither `id` nor `name` is present on a would-be-mapping entry, record the entry in `parse_error.drops` with reason `"missing both id and name"` — do not silently skip.
2. **Replace `return nil unless id` with an assertion path** in `apply_character` / `apply_location` / `apply_update`. At this point, `id` should always be populated (R2 guarantees normalization set it or dropped the entry). A missing id here is a programmer error — raise, do not silently no-op.

The second fix is a defense-in-depth against the first regressing. It also satisfies FR-022 (no silent sentinel exits).

### Rationale

- **Derivation is the right default.** The LLM usually emits `name`; requiring `id` on every entry would either force a prompt-engineering change (brittle) or keep dropping valid entries.
- **Raise in engine code is safer than `return nil`.** Engine code has DI guarantees; callers pass known-good values. A raised exception surfaces immediately in tests and in the CLI error channel — exactly the user-visible signal FR-022 demands.
- **No bible-wiring change needed, probably.** The simplest hypothesis — missing id, silent early-return — fully explains the observed behavior. If after implementing fixes (1) and (2) the demo still produces an empty bible, US2 implementation revisits the injection site. But we do not pre-emptively refactor the wiring.

### Alternatives considered

- **Refactor bible persistence into a `BiblePersister` class injected separately.** Rejected as premature. The existing `StoryBible#save_character` already writes to disk when backed by `:yaml_file` storage. Changing the wiring before confirming the wiring is broken is YAGNI.
- **Make `id` a required field in canon-delta YAML, reject deltas without it.** Rejected: too strict for the LLM's actual behavior, would cascade into prompt changes.

---

## R4 — Non-interactive `world new --quick` surface (US3)

**Context**: FR-007..FR-010. Today `Eidos::CLI::World#new` invokes an interactive `collect_quick_setup_info` that reads `tty-prompt` line-by-line from stdin. A here-doc multi-line premise spills into the next prompt.

### Decision

Add explicit Thor options on `eidos world new --quick`:

- `--title STRING` (required when non-interactive)
- `--author STRING` (required when non-interactive)
- `--premise STRING` (required when non-interactive; may be multi-line)
- `--languages STRING` (comma-separated list of ISO codes, e.g. `en,ru`; optional, defaults to `en`)
- `--default-language STRING` (must be a member of `--languages`; optional, defaults to first of `--languages`)
- `--genre STRING` (optional; see R5)
- `--style STRING` (optional; see R5)
- `--setting STRING` (optional; see R5)
- `--theme STRING` (optional; see R5)

Detection rule: if `$stdin.tty?` is true and no flags were passed, fall through to today's interactive `tty-prompt` flow. If any flag was passed OR stdin is not a TTY, require all four mandatory flags (`title`, `author`, `premise`, `languages`-default-ok) — otherwise exit non-zero with a message naming the missing values.

### Rationale

- **Simplest, most testable.** Thor already parses flags; no parser changes required. Integration specs can shell `exe/eidos world new --quick --title ... --premise "..."` and assert on disk.
- **Scripts and CI friendly.** `scripts/demo_job_hunt.sh` becomes flag-driven instead of here-doc-fed; multi-line values survive shell quoting.
- **Interactive TTY untouched.** FR-009 preserved — real users at a terminal see the same prompts as today.
- **No stdin line-reader involvement.** FR-008 preserved by construction — Thor does not split flag values on newlines.

### Alternatives considered

- **Read entire stdin as a single YAML/JSON blob.** Rejected: adds a second input format to document; flags are already familiar and idiomatic for CLIs.
- **Add a `--config FILE` flag pointing to a YAML.** Considered; deferred. Flag surface is sufficient for the spec's success criteria. A file-based path is welcome later work but not needed here.
- **Keep stdin, escape newlines as `\n`.** Rejected: hostile to humans and to shell here-docs, which is exactly the case the demo script hit.

---

## R5 — World metadata inference (US4)

**Context**: FR-011..FR-013. Today `collect_quick_setup_info` runs regex heuristics on the premise and returns `"fiction"` / `"narrative"` / `"contemporary setting"` / `"adventure"` on every regex miss. These are plausible-looking lies.

### Decision

Two-path approach:

1. **Explicit flags win** (FR-013). If the user passes `--genre`, `--style`, `--setting`, or `--theme` (see R4), those values are used verbatim. No inference overlay.
2. **Absent explicit values, skip inference and write an explicit sentinel** `"unspecified"` for each empty field. Surface unfilled fields via `eidos world status` as an action-item line ("World metadata needs attention: genre, style, setting, theme — re-run `world new --quick --genre ... --style ...` or edit `data/world_config.yml`").

**We do NOT run an LLM inference call in this feature.** The spec leaves this open ("either one-shot LLM inference OR refuse to scaffold without explicit values"); we pick the simpler, zero-LLM-dependency path for now.

### Rationale

- **Honesty by construction.** The output either reflects the user's explicit intent or says "I don't know." No category of "I guessed, and my guess looks real." FR-011 met literally.
- **Visibility via `world status`.** FR-012 is a natural read-path change; the status command already exists and is the right channel for "things you should look at."
- **Zero new LLM cost / latency for world creation.** Creating a world stays offline-capable, matches Principle I's spirit.
- **LLM inference remains welcome future work.** When/if a concrete need arises (batch-creating worlds from a premise corpus, say), a dedicated `eidos world infer-metadata` subcommand can be added behind the existing `Eidos::LLMService` abstraction, per Principle VI. Not in scope here.
- **Regex heuristics are deleted outright.** A silent fallback with a long enough tenure is not load-bearing; removing it is the point.

### Alternatives considered

- **LLM one-shot inference at scaffold time.** Deferred. Adds a network-dependent step to `world new`, coupling a deterministic local operation to a remote service. Worth doing, not worth doing here.
- **Block scaffolding without explicit metadata.** Rejected as too strict. A user trying out the tool should still get a world; an explicit "unspecified" state is the kinder compromise.
- **Keep regex heuristics but mark results as low-confidence.** Rejected: still a silent fallback in practice. Users see "genre: fiction" and accept it; the confidence tag is noise.

---

## R6 — Lazy form-directory scaffolding (US5)

**Context**: FR-014..FR-016. Today `world new` (or its underlying template) creates `content/chapters/` and `content/characters/` unconditionally.

### Decision

Stop creating content-form directories at scaffold time. Piece-producing code paths (`PieceProducer`, `ChapterGenerator`) already write their output to `content/pieces/<form>/<id>.md` (or `content/chapters/<n>.md` for chapters); make those code paths ensure their parent directory exists at write time via `FileUtils.mkdir_p`. This is likely already true — the change is mostly deletion.

For existing worlds (`worlds/one-review-man`), the extant `content/chapters/` stays on disk; no migration, no cleanup. This honors the backwards-compat constraint and FR-016.

### Rationale

- **Deletion > addition.** Removing the eager `mkdir` in the scaffold template is smaller and safer than adding conditional logic.
- **Lazy mkdir is idiomatic Ruby.** `FileUtils.mkdir_p` is idempotent and cheap.
- **Explicit backwards-compat path.** Existing worlds untouched. New worlds get cleaner `content/` trees.

### Alternatives considered

- **Derive scaffolded dirs from declared forms in `data/forms/`.** Rejected as premature — worlds rarely declare forms at creation time, and a "no empty dirs at all until produced" rule is simpler and matches the spec's SC-005.

---

## R7 — Piece-first `world status` (US6)

**Context**: FR-017..FR-018. Today status hardcodes "chapters written" and suggests "produce chapter."

### Decision

`eidos world status` enumerates pieces by walking `content/pieces/<form>/*.md` and `content/chapters/*.md`, groups by form, reports:

```
Pieces by form:
  chapter:    3
  vignette:   2
  haiku:      1
Total: 6
```

When a world has zero pieces across all forms, the suggestion is generic:

```
No pieces yet. Try:
  eidos produce piece --form <form> --prompt "..."
  (see `eidos produce --help` for available forms)
```

When the world has declared an intent that is specifically chapter-based (future work — a `world_config.primary_form` key), the suggestion can narrow to "produce chapter" again. For now, chapters are one valid row in the counts table, not the universal unit.

World-metadata unfilled fields (R5) appear in the status output as action items, per FR-012.

### Rationale

- **Descriptive, not prescriptive.** Output reflects what is on disk, not what the system thinks the world "should" be.
- **Chapters remain a first-class form.** `worlds/one-review-man` users see chapter counts exactly as before.
- **Additive change.** No removal of existing status fields; replacement only within the "progress / next step" block.

### Alternatives considered

- **Fully rip out the "next step" suggestion.** Rejected: new users benefit from a hint. A generic hint beats no hint and a wrong hint.

---

## R8 — User-scale integration harness shape

**Context**: FR-019..FR-021, SC-008. New directory `eidos/spec/integration/user_scale/` that shells `exe/eidos` end-to-end and asserts on disk artifacts.

### Decision

RSpec-based, but isolated from the default suite:

- **Location**: `eidos/spec/integration/user_scale/`.
- **Invocation**: `MOCK_AI=true bundle exec rspec spec/integration/user_scale/`. Default `rspec` run does NOT descend into this directory. Achieved by extending the existing `.rspec` exclusion or by setting `--default-path spec` and having integration files require their own helper that is not auto-loaded by the default spec suite.
- **Mechanism**: Each spec creates a temp dir under `Dir.mktmpdir`, runs `exe/eidos world new --quick --title ... --premise "multi\nline\npremise" --author ... --languages en` via `Open3.capture3`, then reads files off disk with `YAML.load_file` / `File.read` and asserts. No direct class instantiation. No `Eidos::CLI::*.new.invoke(...)`.
- **LLM**: `MOCK_AI=true` by default. The test suite cannot require live-LLM calls to pass. SC-007 (live-LLM `/user-qa` PASS) is validated by the human-in-the-loop QA gate already in place (`.claude/commands/user-qa.md`), not by this automated suite.
- **Coverage floor**: integration specs contribute to the SimpleCov totals when run; they must not cause a drop in the committed floor.

Initial specs (Phase 2 will expand):

- `demo_job_hunt_spec.rb` — scaffold a world from a multi-line premise, produce one piece, assert `world_config.yml` fields, `data/story_bible/characters/*.yml` presence, canon-delta `parse_error` null for the clean case.
- `canon_delta_fuzz_spec.rb` — for each of bare-string, missing-required-key, truncated-JSON inputs, assert `parse_error.drops` populated AND `eidos canon review` output contains a matching finding.
- `produce_two_forms_spec.rb` — produce one vignette and one haiku, assert both `content/pieces/vignette/*.md` and `content/pieces/haiku/*.md` exist, and `world status` lists both.

### Rationale

- **Shells the CLI → mirrors user reality.** Unit tests mock too much (see postmortem §3.2). Shelling exercises flag parsing, stdin handling, exit codes, and file I/O exactly as a user would.
- **Temp-dir isolation → no test pollution.** Each scenario gets a fresh world; no shared state with `worlds/one-review-man`.
- **`MOCK_AI=true` default → fast CI.** Live-LLM runs are reserved for `/user-qa`; deterministic CI stays under the existing mock contract (Principle I).
- **Separate directory → opt-in cost.** `FR-020` explicitly says integration suite must be separately runnable; this structure delivers it.

### Alternatives considered

- **Aruba gem for CLI testing.** Rejected — `FR` calls out "no new runtime gems if avoidable"; Aruba is a dev-dependency but new. `Open3` + `Dir.mktmpdir` from stdlib suffices.
- **Single-process invocation (instantiate `Eidos::CLI::Main` directly).** Rejected — defeats the purpose. We need stdin/stdout/argv behavior the real user gets, which means an actual process.
- **VCR-style recorded LLM fixtures.** Deferred (project memory `project_vcr_llm_fixtures.md`). Out of scope per spec §Out of Scope.

---

## R9 — Silent-fallback documentation location (FR-022, FR-023, SC-009)

### Decision

A new section in `CLAUDE.md` titled **"Banned patterns: silent fallbacks"**, placed under the existing "Development Conventions" area, adjacent to the "Definition of Done" section added during the 014 postmortem. Content covers:

1. The pattern (return a sentinel that looks like real data).
2. Examples of real offenders from the 014 postmortem (`"fiction"`, `return unless @bible`, `next nil` after stderr warn).
3. The three acceptable alternatives (raise, return a result object, emit a user-visible message via `canon review` / `world status` / CLI error channel).
4. The reason stderr is not a user-visible channel.

CLAUDE.md is already loaded into every Claude Code session, so contributors (and the model itself) see the rule before writing code. This directly satisfies SC-009's "location future contributors will discover before writing code."

### Rationale

- **CLAUDE.md is the canonical agent-instructions file for this project.** Already referenced by Definition of Done; adding the ban beside it keeps related prevention rules together.
- **No new document created.** Keeps the contributor surface small.

### Alternatives considered

- **New dedicated doc (`docs/conventions/silent-fallbacks.md`).** Rejected: one more place to go stale; one less place an LLM will read.
- **Enforce via RuboCop custom cop.** Rejected for this feature (spec says "social enforcement only"). Welcome future work, but not blocking.

---

## Summary of decisions

| ID | Topic | Decision |
|----|-------|----------|
| R1 | `parse_error` shape | Structured hash `{summary:, drops: [...]}`; string-valued legacy tolerated on read. |
| R2 | Drop surfacing | New `AuditFinding` kind `'parse-drop'`, one per dropped entry. |
| R3 | `apply_delta` persistence | Derive id from name in `normalize_section`; raise on missing id in engine apply-path instead of `return nil`. |
| R4 | `world new --quick` surface | Thor flags `--title --author --premise --languages --default-language` (plus metadata flags from R5). Interactive TTY flow preserved. Missing required flags → clear error. |
| R5 | Metadata inference | Delete regex heuristics. Explicit flags win. Absent flags → sentinel `"unspecified"`, surfaced by `world status`. No LLM call at scaffold time. |
| R6 | Form-dir scaffolding | Lazy — `mkdir_p` at write time. Scaffold template no longer creates `content/chapters/` etc. Existing worlds unaffected. |
| R7 | `world status` | Enumerates pieces per form from disk. Generic "produce" hint when empty. Chapters are one row, not the unit. |
| R8 | Integration harness | New `eidos/spec/integration/user_scale/`; shells `exe/eidos` via `Open3`; `MOCK_AI=true` default; separate runnable suite. |
| R9 | Silent-fallback ban | New CLAUDE.md section beside Definition of Done. No new docs. Social enforcement. |

All NEEDS-CLARIFICATION resolved. Ready for Phase 1.
