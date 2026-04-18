---
description: Validate a generated Eidos world against the user's stated intent and structural health invariants. Acts as an end-user would — drives `eidos`, inspects the filesystem, and flags drift between what was asked for and what was produced.
---

## User Input

```text
$ARGUMENTS
```

The argument is one of:

1. An **existing world path** + an intent statement, e.g.
   `-w ~/worlds/job-hunt "unlucky 40yo programmer Arthur hunting jobs during AI revolution, deadpan comedy"`
2. A **script path** + intent, e.g.
   `scripts/demo_job_hunt.sh "…intent…"` (FORCE=1 implied if the world already exists)
3. A **spec reference** + world path, e.g.
   `specs/014-storyworld-pivot/quickstart.md -w ~/worlds/014-smoke`

If the argument is empty or ambiguous, ask the user once for:
- intent (one sentence)
- world path (or script to generate one)
- mock vs live LLM (live is the default — it exercises the real plumbing)

## Outline

1. **Parse the argument** into `{intent, world_path, generator?, mode}`.
2. **If a generator script is provided**, run it (with `FORCE=1` if the target exists and the user confirmed). Capture stdout + stderr.
3. **Dispatch the user-qa subagent** via the Task tool. Pass the full context in its prompt:
   - The intent verbatim.
   - The world path.
   - The mode (mock / live).
   - Any stderr warnings already captured during generation (these are pre-populated Tier-1 signal).
   - The Tier-1 / Tier-2 / Tier-3 check list from `.claude/agents/user-qa.md` (the agent already knows it — don't restate; just ask for the report).
4. **Wait for the subagent's report.** Relay it to the user verbatim — do not summarize away the file paths or evidence. The whole point is concrete citations.
5. **If the report is FAIL**, do NOT start fixing things. Ask the user which failure to address first, or whether to open issues. The QA agent's output is a diagnosis, not a work order.
6. **If PASS**, note it and offer to mark the associated spec-kit task(s) complete.

## Rules

- Never claim a feature is done on the strength of green unit tests alone if this command hasn't passed against a freshly generated world.
- When running against scaffolding changes, always generate a NEW world — auditing a pre-existing one masks scaffold regressions.
- When running against content-generation or canon-extraction changes, prefer **live LLM**. Mock responses don't exercise the prompt-to-bible plumbing that this command most often catches bugs in.
- The report must cite exact file paths and, where useful, line numbers and excerpts. If the subagent returns a vague report, push it back for specifics.
