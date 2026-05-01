# AI Team — Universal Multi-Agent Engineering Team

**Date:** 2026-05-01
**Status:** Draft, pending review
**Author:** brainstorming session w/ Alexander Glushkov

---

## 1. Goal

Add a **universal, project-agnostic** multi-agent engineering team to this repo. The team is reusable across projects: drop it in, write a 20-line charter, it operates. It is designed for **autonomous operation** (cron-driven, runs without the user at the terminal), but ships in phases with a sync local-only first cut to prove the roster before turning on autonomy.

## 2. Non-goals

- **Not** Eidos- or storyworld-specific. Existing project agents (`user-qa`, `doc-qa`, `impl-qa`, `rubocop-linter`, `pre-commit-reviewer`) stay where they are; the universal team **delegates** to them when present, but does not depend on them.
- **Not** a replacement for the user driving Claude Code directly. The team is invoked explicitly; bare prompts do not auto-summon it.
- **Not** ChatOps. No Slack, no Discord, no IRC. Linear (already MCP-installed) is the structured channel; Gmail comes later for P0 escalation only.
- **Not** designed to merge to `main` autonomously. Output is PR-only in autonomous mode.

## 3. Architecture overview

Three persistence surfaces, two runtime surfaces:

**Persistence:**
- `.ai_team/` — team-owned project state. Travels with the repo, committed.
  - `charter.md` — user-authored: goals (plural, possibly weighted), non-goals, escalation policy, default authority scope, default cadence.
  - `state.yml` — team-maintained: current focus, last poll cursor, in-flight tasks, escalations needing input.
  - `log/<YYYY-MM-DD>-<slug>.md` — one file per session/tick: dispatches made, outcomes, decisions, links to PRs/Linear issues.
  - `specs/` — analyst-authored mini-specs for non-trivial work, before planner picks them up.
- `.claude/agents/team-*.md` — sub-agent definitions (must live here so Claude Code discovers them).
- `.claude/skills/team-lead/SKILL.md` — orchestration playbook the main session loads.
- `.claude/commands/team.md` — `/team` slash command and subcommands.

**Runtime:**
- **Synchronous (Phase 1–2):** the user's Claude Code session becomes the lead, dispatches sub-agents via Task tool, reports back, exits.
- **Autonomous (Phase 3+):** a `/schedule`-registered cron routine wakes a remote Claude Code agent on cadence; that agent becomes the lead, runs the same dispatch logic, opens PRs / posts Linear comments, sleeps.

Crucially, the lead's logic is the **same skill** in both runtimes. The runtime differs in *trigger* (slash command vs. cron) and *output channel* (terminal vs. Linear+PR), not in dispatch logic.

## 4. Roster — 7 sub-agents

Each agent has a tight role contract: input it accepts, output it produces, when the lead dispatches it. All agents are project-agnostic; they auto-discover language/framework conventions on entry.

### 4.1 `team-analyst`
- **Owns:** "what & why."
- **Input:** fuzzy ask, Linear issue with sparse description, or user prompt.
- **Output:** mini-spec written to `.ai_team/specs/<slug>.md` — problem statement, acceptance criteria, scope/non-scope, open questions.
- **Dispatched when:** task is vague, ambiguous, or lacks acceptance criteria.
- **Authority:** may ask the user clarifying questions in sync mode; in autonomous mode, posts open questions to Linear and sets `Waiting for Input`.

### 4.2 `team-planner`
- **Owns:** "how."
- **Input:** mini-spec from analyst, or a clear ticket with acceptance criteria.
- **Output:** numbered implementation plan with files to touch, test strategy, rollback strategy.
- **Dispatched when:** any task >1 file or >1 logical step.
- **Authority:** read-only.

### 4.3 `team-plan-critic`
- **Owns:** "is this plan right?"
- **Input:** plan from planner.
- **Output:** verdict (approve / request-changes) + list of concerns: missing steps, scope creep, simplification opportunities, hidden assumptions.
- **Dispatched when:** **always after planner, before engineer.** Non-negotiable.
- **Authority:** read-only.

### 4.4 `team-engineer`
- **Owns:** "make it work."
- **Input:** approved plan.
- **Output:** code + tests on a feature branch, commits, summary of what was done.
- **Dispatched when:** plan has been approved by plan-critic.
- **Authority:** writes code on feature branches; never `main`. TDD discipline (test-driven-development skill).

### 4.5 `team-code-critic`
- **Owns:** "is this code right?"
- **Input:** uncommitted or recently-committed changes.
- **Output:** verdict + findings: bugs, logic flaws, style violations, inconsistency with surrounding code.
- **Dispatched when:** after engineer claims done.
- **Authority:** read-only.

### 4.6 `team-qa`
- **Owns:** "does it actually work end-to-end?"
- **Input:** committed changes + acceptance criteria from spec.
- **Output:** test-suite results, linter results, project-specific QA gate results, smoke-test verdict.
- **Dispatched when:** after code-critic passes.
- **Authority:** runs tests, runs linters, invokes project-specific QA agents when they exist.
- **Project-specific delegation:** detects and invokes `rubocop-linter`, `pre-commit-reviewer`, `user-qa`, `doc-qa`, `impl-qa` if `.claude/agents/` contains them; otherwise falls back to generic `<package-manager> test` + linter detection (eslint, mypy, golangci-lint, …).

### 4.7 `team-writer`
- **Owns:** "explain it to humans."
- **Input:** shipped change or doc task from charter.
- **Output:** README/usage-guide updates, PR description, changelog entry, ADR if architectural.
- **Dispatched when:** charter or ticket says docs need updating; or after engineer ships a user-facing change; or when opening a PR.
- **Authority:** writes docs.

## 5. The lead — main session as orchestrator

The lead is **not a sub-agent.** It is the session that runs `/team` (sync) or fires from `/schedule` (autonomous). The `team-lead` skill teaches that session how to orchestrate. Key rules:

- **Lead does not write code.** Period. Any temptation to "just fix it myself" is a violation.
- **Lead reads the charter** on every invocation. Goals can change between ticks.
- **Lead reads `.ai_team/state.yml`** to know what's in flight, what's escalated, what's done since last tick.
- **Lead reads the auto-discovery surfaces** (`CLAUDE.md`, `AGENTS.md`, `README.md`, language manifests, `git log -10`, `.claude/agents/`).
- **Lead picks a dispatch path** based on the task shape:
  - Vague ask → analyst → planner → plan-critic → engineer → code-critic → qa → writer (if user-facing)
  - Clear ticket w/ acceptance criteria → planner → plan-critic → engineer → code-critic → qa → writer (if user-facing)
  - Tiny patch (one-line fix, typo, dep bump) → engineer → code-critic
  - Investigation only → analyst → done (writes findings to `.ai_team/log/`)
- **Lead writes a log entry** at the end of every session/tick to `.ai_team/log/`.
- **Lead synthesizes for the user** — sub-agent outputs are condensed into one report; the user does not read seven sub-agent reports.

## 6. Charter format (`.ai_team/charter.md`)

```markdown
# Team Charter — <project name>

## Goals
1. <weighted or ordered goal>
2. <...>

## Non-goals
- <explicit non-goal>

## Authority
- Default scope: branch-only  # or read-only | broad
- May open PRs: yes
- May merge PRs: no            # or "yes for: docs, dep-bumps"
- May modify CI config: no

## Cadence (autonomous mode)
- Default: hourly during 09:00-19:00 Europe/Moscow on weekdays
- Override per-task in Linear with label `cadence:N` (minutes)

## Escalation
- Channel: Linear (set issue status to `Waiting for Input`)
- P0 channel: <unset until Phase 4>

## Project conventions
- Language: <auto-detected, override here if wrong>
- Test command: <auto-detected, override here if wrong>
- Lint command: <auto-detected, override here if wrong>

## Notes
<anything else the team should know>
```

The lead reads this **every** invocation. Out-of-date charter = out-of-date team behavior.

## 7. Slash command surface (`/team`)

Subcommands:

- `/team init` — scaffold `.ai_team/` (charter template, empty state, log dir, specs dir). Interactive: asks the user a few setup questions and writes a starter charter.
- `/team <free-form task>` — sync mode: lead runs in current session, dispatches the team to work on the task, reports back.
- `/team LIN-<id>` — sync mode: resolve the Linear issue, treat its description as the task.
- `/team start` — register the `/schedule` routine that runs the lead on cron. Phase 3+.
- `/team stop` — disable the schedule.
- `/team run` — fire the autonomous lead **once, locally** — for testing the autonomous code path without waiting for cron.
- `/team status` — print state: current focus, in-flight tasks, escalations, last tick.

## 8. Phasing

| Phase | Ships | Acceptance |
|---|---|---|
| **1** | Roster (7 agents), `team-lead` skill, `/team init`, `/team <task>`, `.ai_team/` scaffold w/ charter+state+log conventions | User runs `/team add a help command to my CLI` in a fresh repo, gets a working PR-ready branch with tests passing |
| **2** | Linear read+comment integration (still sync). `/team LIN-123` works. Final-comment-on-completion. | User runs `/team LIN-123` and the resulting branch + Linear comment matches issue acceptance criteria |
| **3** | `/team start` registers `/schedule` routine. Autonomous lead opens PRs, posts Linear comments, escalates with `Waiting for Input`. PR-only output. | After `/team start`, closing the laptop and re-opening 24h later shows: ≥1 PR opened, ≥1 Linear comment posted, no merges to `main`, no out-of-charter actions |
| **4** | Gmail P0 escalation, charter-driven cadence tuning, multi-task parallelism, `team-housekeeper`, `team-incident-responder` | Polish — defer until Phase 3 has been used in anger |

**Architectural compatibility (must hold across all phases):**

- Lead's dispatch logic is **stateless** — reads charter + state.yml + current task, decides, dispatches. Same logic in both runtimes.
- Sub-agents are **idempotent re-entrant** — partial completions logged so the next tick resumes cleanly.
- The "current task" abstraction accepts three sources: (a) inline prompt, (b) Linear issue ID, (c) "scan for new work" auto-discovery.

## 9. Defaults baked into the charter template

- **Cadence:** hourly during 09:00–19:00 weekdays (Europe/Moscow). The user is expected to override.
- **Authority:** branch-only. May open PRs. May NOT merge. May NOT modify CI config.
- **Escalation:** Linear with `Waiting for Input` status.

These defaults are conservative on purpose: the failure mode of a too-aggressive autonomous team (force-pushing to main, merging its own PRs, modifying CI to bypass checks) is much worse than a too-passive one (sits there waiting for input).

## 10. Project-specific delegation contract

The universal `team-qa` agent must invoke project-specific gates when present. Detection rule (in order):

1. If `.claude/agents/user-qa.md` exists → invoke after engineer for feature work.
2. If `.claude/agents/doc-qa.md` exists and docs touched → invoke.
3. If `.claude/agents/impl-qa.md` exists and CLI surface or scaffolding touched → invoke.
4. If `.claude/agents/rubocop-linter.md` exists and Ruby files touched → invoke.
5. If `.claude/agents/pre-commit-reviewer.md` exists → invoke before commit.
6. Otherwise: generic linter+test detection (eslint, mypy, golangci-lint, rspec, jest, pytest, go test).

The universal team **does not** import or vendor the project-specific agents — it just dispatches them via `Task` when they exist on disk.

## 11. Open questions / risks

- **Q1:** Should the autonomous lead be allowed to *create* Linear issues (e.g., when it discovers a bug while working on something else), or only consume them? Default proposal: yes, with label `ai-team-discovered` so they're visually distinct. Decide before Phase 3.
- **Q2:** State.yml format — YAML vs. JSON. YAML for human-editability; risk is YAML parsing edge cases. Default: YAML.
- **Q3:** Concurrency — can two `/team` sessions run simultaneously in the same repo? Phase 1 says yes (no shared state lock); Phase 3 may need a lock file in `.ai_team/` to prevent two cron ticks colliding.
- **Q4:** How does the lead know which Linear team to query? Charter must specify; discovery via Linear MCP `list_teams` on `init`.
- **Q5:** Cost — autonomous hourly ticks burn API credits even when there's nothing to do. Mitigation: lead's first action on each tick is a 30-second cheap-model triage that decides "anything to do?" before spinning up sub-agents.

## 12. Out of scope (this design)

- Specific implementation of each sub-agent's prompt — that's plan-critic / planner work in the next step (writing-plans skill).
- The `/schedule` routine's exact cron expression generator — Phase 3 detail.
- Multi-language i18n agent — not in roster, not needed for MVP.
- Backend/frontend split — explicitly rejected; one engineer.

---

## Implementation entry point

Phase 1 implementation begins by invoking `superpowers:writing-plans` against this spec, scoped to **Phase 1 only**. Phase 2/3 specs/plans come later, after Phase 1 has been used in anger for at least a week.
