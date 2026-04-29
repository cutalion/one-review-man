---
description: Verify the project's usage guide is consistent with the project's pitch. Compares two Markdown documents (a pitch and a guide) by reading-comprehension; carries no hardcoded knowledge of specific features. Reports vision-alignment, internal-consistency, and pitch-self-consistency findings.
---

## User Input

```text
$ARGUMENTS
```

Arguments are optional. Supported forms:

1. **No arguments** — defaults to `docs/pitch.md` and `docs/usage-guide.md`.
2. **Two paths** — `<pitch path> <guide path>`, e.g. `docs/pitch.md docs/usage-guide.md`.
3. **Single guide path** — `--guide <path>` (uses the default pitch path).
4. **Single pitch path** — `--pitch <path>` (uses the default guide path).

If a referenced path does not exist, ask the user once for the correct path. Do not invent contents.

## Outline

1. **Parse the argument** into `{pitch_path, guide_path}`. Default both to `docs/pitch.md` and `docs/usage-guide.md` if not supplied.
2. **Verify both files exist.** If either is missing, stop and ask the user.
3. **Dispatch the doc-qa subagent** via the Task tool. Pass:
   - The pitch path.
   - The guide path.
   - The contract reference at `specs/016-usage-guide/contracts/doc-qa-report.md` so the subagent matches the report format exactly.
4. **Wait for the subagent's report.** Relay it to the user verbatim — do not summarize away the line numbers or quoted text.
5. **If the report is FAIL**, do NOT start fixing things. Ask the user which failure to address first, or whether the pitch or the guide is the side to update for each finding. The agent's output is a diagnosis, not a work order.
6. **If PASS**, note it. The user may also want to run `/impl-qa` to verify the guide against the implementation.

## Rules

- Doc-qa verifies *document-to-document* consistency only. It does not check whether the codebase matches the guide — that is impl-qa's job. Never let the maintainer conflate the two reports.
- Doc-qa carries no hardcoded knowledge of specific features. If a finding seems to require knowing that "X is deprecated" or "Y is the new way," push back for the literal pitch passage that establishes the framing.
- The report must cite exact line numbers and quoted text from each document. If the subagent returns a vague finding, push it back for specifics.
- A `FAIL` Verdict is blocking for any change that touches `docs/pitch.md` or `docs/usage-guide.md`, per the project Definition of Done.
