---
description: Universal AI engineering team. `/team init` to scaffold .ai_team/. `/team <task>` to run the team in sync mode against a free-form task. `/team status` to print state.
---

# /team

You have been invoked as the **lead** of the universal AI engineering team.

**Arguments received:** `$ARGUMENTS`

## Step 1: Parse the subcommand

Look at `$ARGUMENTS`:

| Arg pattern | Subcommand |
|---|---|
| empty / `help` | Print usage (see Step 5) and stop. |
| exactly `init` | Run **init** flow (Step 2). |
| `init <anything else>` | Print "init takes no arguments" and stop. |
| exactly `status` | Run **status** flow (Step 3). |
| `status <anything else>` | Print "status takes no arguments" and stop. |
| exactly `start` / `stop` / `run` | Print "Phase 3 — not yet shipped. See `docs/superpowers/specs/2026-05-01-ai-team-design.md` §8." and stop. |
| matches `^LIN-\d+$` | Print "Phase 2 — Linear integration not yet shipped. Pass the issue body inline as `/team <body>` for now." and stop. |
| starts with `LIN-` but doesn't match `^LIN-\d+$` (e.g., empty or non-numeric) | Print "Pass a Linear issue id, e.g. `/team LIN-123`" and stop. |
| anything else | Treat as a free-form task. Run **task** flow (Step 4). |

## Step 2: `init` flow

1. Refuse if `.ai_team/charter.md` already exists. Print "already initialized" and `cat .ai_team/charter.md | head -20`.
2. Otherwise:
   - Create `.ai_team/`, `.ai_team/log/`, `.ai_team/specs/`.
   - Auto-detect:
     - **Project name:** from `package.json` `name`, or `Cargo.toml` `name`, or git repo root dirname.
     - **Language:** from manifest (lockfile most authoritative).
     - **Test command:** `npm test` / `bundle exec rspec` / `pytest` / `go test ./...` / `cargo test` (whichever fits language).
     - **Lint command:** project-appropriate.
   - Read the templates:
     - `.claude/skills/team-lead/templates/charter.md.tmpl`
     - `.claude/skills/team-lead/templates/state.yml.tmpl`
     - `.claude/skills/team-lead/templates/ai-team-readme.md.tmpl`
   - Substitute `{{PROJECT_NAME}}`, `{{LANG_AUTODETECTED}}`, `{{TEST_CMD_AUTODETECTED}}`, `{{LINT_CMD_AUTODETECTED}}`, `{{GOAL_PLACEHOLDER}}` (literal text "(your first goal — e.g., 'ship feature X by date Y')").
   - Write substituted content to `.ai_team/charter.md`, `.ai_team/state.yml`, `.ai_team/README.md`.
3. Ask the user one question: "What's the team's first goal? I'll write it into `charter.md`. (Type 'skip' to leave the placeholder.)" — incorporate the answer (or skip).
4. Print a short summary of what was created and tell the user to review `.ai_team/charter.md` before invoking `/team <task>`.
5. **Do not run any other agents.** Init is setup-only.

## Step 3: `status` flow

1. If `.ai_team/charter.md` doesn't exist, print "not initialized — run `/team init` first" and stop.
2. Print:
   - First 5 lines of `.ai_team/charter.md` (project name + first goal).
   - `.ai_team/state.yml` (verbatim).
   - Tail (3 most recent) of `.ai_team/log/` filenames + their first 3 lines each.
3. Stop.

## Step 4: `task` flow — become the lead

1. **Load the team-lead skill** by invoking it. The skill teaches you the orchestration playbook (rules, dispatch heuristic, context-loading, state, logging, synthesis).
   - If for any reason the skill cannot be loaded, refuse to proceed with the task. Tell the user.
2. **Verify charter exists.** If `.ai_team/charter.md` is missing, print "run `/team init` first" and stop.
3. **Follow the team-lead skill's playbook** with the task = `$ARGUMENTS`.
4. **Synthesize** results to the user per the skill's synthesis template.
5. **Write the log entry** per the skill's logging spec.

## Step 5: Usage (printed on `/team` or `/team help`)

```
/team init                  Scaffold .ai_team/ in this repo (one-time)
/team <free-form task>      Run the team on the task in sync mode
/team status                Print current state and recent log
/team help                  This message

Phase 3+ (not yet shipped):  /team start | /team stop | /team run
Phase 2 (not yet shipped):   /team LIN-<id>
```

## Hard rule

The `/team` command **never writes code** to files outside `.ai_team/`. Code edits go through `team-engineer` only. (Init writing template files into `.ai_team/` is allowed; init never touches source code.)
