# Contract: Impl-QA Report Format

**Owner**: Impl-QA agent (`.claude/agents/impl-qa.md`)
**Consumers**: human maintainers (primary), pre-commit hooks (secondary), future CI automation (tertiary).

---

## Required structure

```markdown
# Impl-QA Report

**Guide**: <guide path>
**World**: <world path or "scaffolded from §<scenario name>" or "n/a — static-only run">
**Mode**: <default | --behavioral | --behavioral --live>

## Tier 1 — Surface Accuracy

[<status>] <finding>
…

## Tier 2 — Behavioral Accuracy

<either: full Tier-2 block, or the literal line: "Skipped (default mode — pass `--behavioral` to enable).">

## Tier 3 — Undocumented Surface (informational)

[INFO] <finding>
…

## Tier 4 — Backlog (informational)

[INFO] <finding>
…

## Verdict

<PASS | FAIL — <N> Tier-1 failures, <M> Tier-2 failures>

## Root-Cause Candidates

- <bullets, omitted if PASS>
```

Tier 3 and Tier 4 use `[INFO]` — they are informational and never fail the verdict (per FR-IQ-004). Tier 1 and Tier 2 use `[PASS]` / `[FAIL]`.

---

## Mode rules

- **`default`**: Tier 1, Tier 3, Tier 4 are run. Tier 2 block contains the literal line `Skipped (default mode — pass --behavioral to enable).`
- **`--behavioral`**: Tier 1, Tier 2, Tier 3, Tier 4 all run. Tier 2 uses `MOCK_AI=true` for any Eidos LLM calls. The `**World**:` header line MUST name the world.
- **`--behavioral --live`**: Same as `--behavioral` but without `MOCK_AI=true`. The agent MUST add an explicit warning line under the Mode header: `> ⚠️ Live LLM mode — observed costs apply.` This makes the cost-incurring run impossible to mistake for a default run when reviewing the report later.

---

## Finding-line shape

**Tier 1 / Tier 2 PASS**:

```
[PASS] <plain-prose description>
```

**Tier 1 / Tier 2 FAIL**:

```
[FAIL] <one-line summary>
       guide line N: "<quoted text from guide>"
       codebase: <file path or output excerpt>
       attribution: <"guide stale" | "codebase changed" | "unknown — both updated">  (Tier 1/2 only)
       reason: <one-line root-cause hypothesis>
```

The `attribution:` line is mandatory for Tier 1 and Tier 2 failures (FR-IQ-004 — drift attribution required, no silent assumption). When the agent cannot determine attribution from `git log` evidence, it MUST write `unknown — both updated` rather than guessing.

**Tier 3 / Tier 4 INFO**:

```
[INFO] <undocumented-surface item description>  (Tier 3)
[INFO] <aspirational section title> — <commands or behaviors it describes>  (Tier 4)
```

Tier 3 and Tier 4 lines are single-line and do not get continuations.

---

## Tier rules

- **Tier 1 — Surface Accuracy** (static): For every command, flag, subcommand, and file path that the guide names *in non-aspirational sections*, verify it exists in the current codebase. Missing surface is a `[FAIL]`. Aspirational sections are excluded from Tier 1 entirely.
- **Tier 2 — Behavioral Accuracy** (live, opt-in): For each Documented Scenario in non-aspirational sections, run the command sequence against a fresh world and verify the resulting world state matches the scenario's `expected_post_state` claims. Mismatches are `[FAIL]` findings.
- **Tier 3 — Undocumented Surface** (static, informational): For every Thor command + primary user-facing flag, every registered piece form, and every user-facing field of `data/world_config.yml` / `data/settings.yml`, check whether the guide mentions it. Items not mentioned are `[INFO]` lines. Excluded from this check (per FR-IQ-007): SDK, env vars, `strings.yml` keys, internal Thor plumbing, deprecated/hidden flags.
- **Tier 4 — Backlog** (static, informational): Enumerate every aspirational section the guide contains (sections matching the FR-007a marker per `contracts/aspirational-marker.md`). One `[INFO]` line per aspirational section.

---

## Verdict rules

- `PASS` if and only if both Tier 1 and Tier 2 (when run) have zero `[FAIL]` findings.
- `FAIL` MUST be followed by `— <N> Tier-1 failures, <M> Tier-2 failures` with explicit zeros (e.g., `— 0 Tier-1 failures, 1 Tier-2 failure`).
- Tier 3 and Tier 4 counts are NOT included in the Verdict line — they are informational and do not affect pass/fail.
- A separate one-line summary appears AFTER the Verdict reporting Tier 3 / Tier 4 counts: `Tier 3: <N> undocumented items. Tier 4: <M> aspirational sections.`

---

## Header rules

- `**Guide**:` is always present.
- `**World**:` is always present. Value:
  - `default` mode: `n/a — static-only run`
  - `--behavioral` mode with caller-supplied world: the absolute or repo-relative path
  - `--behavioral` mode with agent-scaffolded world: `scaffolded from §"<scenario name>"`
- `**Mode**:` is always present.

---

## Hard rules (binding the agent)

1. The agent MUST cite literal text from the guide (quoted) and concrete codebase evidence (file path, command output excerpt) for every Tier 1/2 FAIL.
2. The agent MUST attempt drift attribution via `git log` and only fall back to `unknown — both updated` when the evidence is genuinely ambiguous.
3. The agent MUST NOT modify any file (guide, codebase, world).
4. The agent MUST set `MOCK_AI=true` for `--behavioral` mode unless the caller passes `--live`.
5. The agent MUST NOT recommend a direction for Tier 3 findings (the choice between "document this" and "remove this from the codebase" is the maintainer's per FR-IQ-003 / FR-IQ-007 / Edge Cases).

---

## PASS example (default mode)

```markdown
# Impl-QA Report

**Guide**: docs/usage-guide.md
**World**: n/a — static-only run
**Mode**: default

## Tier 1 — Surface Accuracy

[PASS] Every command and flag named in the guide exists in the current codebase.

## Tier 2 — Behavioral Accuracy

Skipped (default mode — pass `--behavioral` to enable).

## Tier 3 — Undocumented Surface (informational)

[INFO] `eidos canon impact_review` — Thor command exists; not mentioned in guide.
[INFO] form `comic-script` — registered in `eidos/lib/eidos/forms/`; guide §"Produce your first piece" lists other forms but not this one.

## Tier 4 — Backlog (informational)

(none — v1 guide has no aspirational sections per FR-003)

## Verdict

PASS

Tier 3: 2 undocumented items. Tier 4: 0 aspirational sections.
```

---

## FAIL example (behavioral mode, mock)

```markdown
# Impl-QA Report

**Guide**: docs/usage-guide.md
**World**: scaffolded from §"Create your first world"
**Mode**: --behavioral

## Tier 1 — Surface Accuracy

[PASS] Every command and flag named in the guide exists in the current codebase.

## Tier 2 — Behavioral Accuracy

[FAIL] guide §"Create your first world" promises a populated story bible after `eidos world new`
       guide line 142: "Once `world new` finishes, `data/story_bible/characters.yml` contains your protagonist."
       codebase: `worlds/<scaffolded>/data/story_bible/characters.yml` — file exists but is empty (0 bytes).
       attribution: codebase changed (commit a3f9d12 last week swapped scaffold defaults to literal "unspecified").
       reason: scaffolding stopped seeding example characters; guide hasn't been updated.

## Tier 3 — Undocumented Surface (informational)

(no findings)

## Tier 4 — Backlog (informational)

(no findings)

## Verdict

FAIL — 0 Tier-1 failures, 1 Tier-2 failure.

Tier 3: 0 undocumented items. Tier 4: 0 aspirational sections.

## Root-Cause Candidates

- Recent change to scaffolding defaults; guide §"Create your first world" not updated.
- Possible incomplete migration of feature 015's "no silent fallback" rule into the guide's expected post-state.
```
