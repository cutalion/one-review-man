# Specification Quality Checklist: Project Pitch + Usage Guide + Doc-QA & Impl-QA Agents

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-04-28
**Feature**: [Link to spec.md](../spec.md)

## Content Quality

- [x] No implementation details (languages, frameworks, APIs)
- [x] Focused on user value and business needs
- [x] Written for non-technical stakeholders
- [x] All mandatory sections completed

## Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers remain
- [x] Requirements are testable and unambiguous
- [x] Success criteria are measurable
- [x] Success criteria are technology-agnostic (no implementation details)
- [x] All acceptance scenarios are defined
- [x] Edge cases are identified
- [x] Scope is clearly bounded
- [x] Dependencies and assumptions identified

## Feature Readiness

- [x] All functional requirements have clear acceptance criteria
- [x] User scenarios cover primary flows
- [x] Feature meets measurable outcomes defined in Success Criteria
- [x] No implementation details leak into specification

## Notes

- The spec deliberately names four artifact paths (`docs/pitch.md`, `docs/usage-guide.md`, `.claude/agents/doc-qa.md`, `.claude/agents/impl-qa.md`). These are not implementation choices — they are user-visible locations the agents, the README, and the maintainer's mental model all need to point to, so they belong in the spec.
- The spec references the existing `user-qa` agent shape (`.claude/agents/user-qa.md`) as a structural template for both new agents. The reference is to an existing user-facing artifact, not to internal Ruby symbols.
- The two-agent split (doc-qa: pitch ↔ guide; impl-qa: guide ↔ code) is intentional and is the architectural commitment that distinguishes this spec from a single combined verifier. FR-DQ-003 explicitly forbids hardcoded feature names in the doc-qa agent so the vision check stays a *property of comparing two documents*, not a curated allowlist.
- FR-021 names `CLAUDE.md` updates. `CLAUDE.md` is a contributor-facing file; the spec calls for editing it because that is where the project's Definition of Done lives. This is a process artifact, not an implementation detail of the guide.
- SC-005 sets a documentation-coverage floor of 80% rather than 100% deliberately: a fraction of the user-facing surface (deprecated flags, hidden debug aids) is intentionally left out of an end-user guide. A coverage shortfall is now a dual-direction signal: it means *either* the guide is incomplete *or* the codebase has surface to remove. The maintainer makes that call per-item.
- Items marked incomplete require spec updates before `/speckit.clarify` or `/speckit.plan`.
