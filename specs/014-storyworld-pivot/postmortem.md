# 014-storyworld-pivot — Postmortem

**Date:** 2026-04-18
**Trigger:** User-driven end-to-end smoke test (`scripts/demo_job_hunt.sh` generating `~/worlds/job-hunt`) surfaced six Tier-1 defects in code that passed `bundle exec rspec` (630 examples, 0 failures) and the spec's own success criteria.

## Summary

014 shipped as "done" on the strength of its unit-test suite and CLI help polish. A user-scale audit — scaffold a fresh world from a realistic multi-line premise, generate content with a live LLM, then inspect what landed on disk — found that:

- `data/world_config.yml` was corrupted by multi-line stdin in the quick-setup path.
- `data/strings.yml` carried the same mid-sentence truncation downstream.
- `data/story_bible/` was empty despite canon deltas declaring entities.
- 3 of 4 canon-delta files had all sections empty (LLM emitted string entries; parser silently dropped them).
- `content/chapters/` and `content/characters/` were scaffolded as empty orphan directories.
- `eidos world status` still reports chapter-centric progress for a piece-first world.

Unit tests passed through all of these. The feature's acceptance criteria never required asserting on disk artifacts against user intent.

Follow-up work lands under `specs/015-scaffold-hardening/`.

## Root-cause analysis (per defect)

| # | Defect | Root cause |
|---|---|---|
| 1 | `world new --quick` stdin corruption | Quick-setup loop reads one `\n`-terminated line per prompt. A multi-line premise piped via here-doc splits across subsequent prompts (languages, default_language). |
| 2 | Genre/style/setting/theme silent fallback | `collect_quick_setup_info` runs regex heuristics on the premise; on miss, returns hardcoded defaults (`fiction`, `narrative`, `contemporary setting`, `adventure`) that look like successfully inferred values. |
| 3 | Canon-delta parser silently drops string entries | `parse_new_characters` etc. iterate, `warn` to stderr, `next`. No `parse_error` set, no `canon review` finding. The drop is invisible unless the user watches stderr. |
| 4 | `apply_delta` does not persist to bible | Under investigation (US4). The comic-script delta has `Arthur` + `Arthur's Apartment`, `applied_at` is set, `parse_error` is null — but `data/story_bible/characters/` is empty. |
| 5 | Orphan empty scaffold dirs | `world new` template creates `content/chapters/` and `content/characters/` unconditionally. Book-era assumption that 014 did not remove. |
| 6 | `world status` is chapter-centric | Hardcoded strings assume chapter is the unit; recommend "Run: produce chapter" even when pieces already exist. |

## Process failures (why 014 passed review with these defects)

### 1. Tests asserted on the object graph, not disk artifacts

All 014 specs exercised `PieceProducer`, `FormRegistry`, `Bible`, `AuditLog` with mock LLM responses pre-shaped as well-formed Ruby hashes. No test opened a file under `data/story_bible/` after the run and asserted its contents. Defects 3 and 4 live in the gap between "method called correctly" and "bytes on disk."

### 2. Mock LLM responses were too clean

`spec/support/mock_responses.yml` returns perfect mappings. Real LLMs emit string-entry canon deltas routinely. The silent-drop path was exercised **zero times** by the suite. A fuzz/property test with intentionally malformed deltas would have caught defect 3 immediately.

### 3. Success criteria were engineer-centric, not user-centric

SC-001 through SC-010 measure "CLI completes without error." None measure "the user's stated intent is reflected in world config, bible, and produced pieces." Every SC passed. The feature is still broken.

### 4. "No breaking changes to existing worlds" was read too literally

The spec's intent was backwards-compat for existing world files. I read it as "scaffold the same dirs for new worlds too," preserving `content/chapters/` and `content/characters/` in the template. Defect 5 was in scope but invisible to the spec.

### 5. The quickstart was written, never run, during planning

`quickstart.md` lists commands. I did not actually run them against a realistic multi-line premise until after "implementation done" was declared. Defect 1 would have blown up at plan-phase smoke test.

### 6. Silent fallbacks accepted without pushback

Defects 2, 3, 4 all share a pattern: **a default or short-circuit that looks like real output**. `"fiction"` is a real-looking genre. An empty `new_characters: []` is a real-looking delta. `return unless @bible && @audit_log` is a real-looking method exit. Tests pass, production breaks. This is a design-discipline failure — I accepted code patterns that fail quietly.

## Prevention — mechanical, not aspirational

1. **User-scale integration tests per feature.**
   - New directory: `eidos/spec/integration/user_scale/`.
   - Each test shells `exe/eidos` end-to-end with realistic multi-line stdin.
   - Assertions target **disk artifacts** (file contents, YAML structure, counts under `data/story_bible/`).
   - These are slow; run in CI, not in the fast loop.

2. **`/user-qa` gate (in place).**
   - See `.claude/agents/user-qa.md`, `.claude/commands/user-qa.md`, `CLAUDE.md` → Definition of Done.
   - Every spec-kit feature touching CLI UX, scaffolding, content, prompts, or canon-delta extraction must pass `/user-qa` against a freshly generated world before tasks are marked `[X]`.

3. **Plan-phase quickstart must include at least one multi-line input.**
   - Add to `CLAUDE.md` Definition of Done.
   - Rationale: defect 1 would have surfaced at plan time under this rule.

4. **Ban silent fallbacks in new code.**
   - Code-review checklist item: any method that can return a sentinel (`"fiction"`, `nil`, `[]`, `return unless ...`) must either raise, return a `Result`-like object, or emit a visible log entry that `world status` / `canon review` surfaces. Stderr warnings that the user never sees are not acceptable.

5. **LLM response fuzz tests.**
   - At least one spec per parser / extractor should feed intentionally malformed LLM output (string entries instead of mappings, missing required fields, truncated JSON). Assert the failure surfaces as `parse_error` + a canon finding, not silence.

## Follow-ups (tracked separately)

- **015-scaffold-hardening** — fixes the six defects above. Six user stories, one per defect. Order: US3 → US4 → US1 → US2 → US5 → US6 (surface-then-substrate).
- **Audit other silent-fallback sites** — `collect_quick_setup_info`, `apply_delta`, `parse_*` methods. Any found become US7+.
- **VCR-style recorded LLM fixtures (future, out of scope for 015).**
  - Goal: end-to-end tests that exercise the real prompt-to-bible pipeline without paying for live LLM calls on every run.
  - Shape: first run hits the real LLM and records the response; replay mode deserializes and returns the recorded response for the same prompt hash.
  - Prior art: `vcr` gem for HTTP, but `LLMService` is the abstraction boundary we'd record at — cleaner than HTTP-level taping because our prompt construction is deterministic and hashable.
  - Why not now: scope. 015 uses `MOCK_AI=true` plus live-LLM `/user-qa` runs for validation. Recorded-fixture infrastructure deserves its own spec.
