# Specification Quality Checklist — 015-scaffold-hardening

**Spec**: `specs/015-scaffold-hardening/spec.md`
**Reviewed**: 2026-04-18

## Content Quality

- [X] **No implementation details** — Spec describes WHAT and WHY, not HOW. No code, class names, framework names, library calls. Evidence: FR-001..FR-024 use user-facing concepts (parse_error field, canon-delta sections, status output); no mention of Ruby classes, gems, or method signatures except as user-visible artifact names (e.g. `data/world_config.yml` which IS the user-visible artifact).
- [X] **Focused on user value** — Every user story has "Why this priority" that ties the fix to a user-observable harm (silent data loss, broken automation, cosmetic chapter-era language leak). Not organized around internal modules.
- [X] **Written for non-technical stakeholders** — A PM or a storyworld author could read US1-US6 and understand the defect and the intended repair without knowing Ruby. Technical terms used (YAML, stderr, sentinel) are either named user-visible artifacts or defined in context.
- [X] **All mandatory sections present** — User Scenarios & Testing, Requirements, Success Criteria, plus Assumptions, Dependencies, Out of Scope, Key Entities, Edge Cases.

## Requirement Completeness

- [X] **No [NEEDS CLARIFICATION] markers** — None in the spec. Ambiguities were resolved during drafting (e.g. choice of sentinel value explicitly left as implementation-choice in Assumptions).
- [X] **Requirements are testable and unambiguous** — Every FR names the observable condition (file exists, output contains, exits with error). FR-001 "MUST be recorded on the delta's `parse_error` field with category, raw dropped value, and reason" is directly verifiable by reading the YAML.
- [X] **Success criteria are measurable** — SC-001 through SC-009 cite exact file paths, exact command outputs, or count-based thresholds (e.g. SC-005 "no empty directories", SC-008 "at least two distinct non-chapter forms").
- [X] **Success criteria are technology-agnostic** — No mention of RSpec, Ruby, specific test frameworks, specific CI. SC-008 refers to "user-scale integration suite ... invoked by a single documented command" — does not prescribe the command or the framework.
- [X] **All acceptance scenarios are defined** — Every US has 3-4 Given/When/Then scenarios covering happy path, error path, and backwards-compat where applicable.
- [X] **Edge cases are identified** — Dedicated Edge Cases section covering mixed valid/invalid canon-delta entries, delta-vs-existing-entity conflicts, interactive fallthrough, premise with no clear genre, backwards compat for existing worlds, LLM truncation.
- [X] **Scope is clearly bounded** — Dedicated "Out of Scope" section naming VCR fixtures, linting, Jekyll, arc redesign, multi-user, migration of existing worlds.
- [X] **Dependencies and assumptions identified** — Both sections present. Assumptions call out the unspecified-sentinel choice as implementation-flexibility, live-LLM meaning, CLI backwards compat, social-enforcement of the silent-fallback ban.

## Feature Readiness

- [X] **All functional requirements map to user stories** — FR-001..FR-006 → US1/US2; FR-007..FR-010 → US3; FR-011..FR-013 → US4; FR-014..FR-016 → US5; FR-017..FR-018 → US6; FR-019..FR-024 → cross-cutting (harness, silent-fallback ban, fuzz coverage). Every FR traceable.
- [X] **User stories are independently testable** — Each US has an "Independent Test" section asserting the story's acceptance criterion is measurable without the other stories being complete. US1 testable with a hand-crafted malformed delta; US2 testable with a hand-crafted well-formed delta; US3 testable by piping a here-doc at a fresh CLI; etc.
- [X] **Priorities are assigned and justified** — P1: US1, US2, US3 (data loss + blocker-for-QA). P2: US4, US5 (silent-fallback anti-pattern surfaces, but cosmetic-to-prompt-drift rather than data loss). P3: US6 (pure UX). Rationale in each story's "Why this priority."
- [X] **Success criteria correspond to acceptance scenarios** — SC-001 ↔ US3.1/US3.2; SC-002 ↔ US4.1/US4.2; SC-003 ↔ US2.1/US2.2; SC-004 ↔ US1.1/US1.2; SC-005 ↔ US5.1; SC-006 ↔ US6.1/US6.2; SC-007 ↔ overall QA verdict; SC-008 ↔ FR-019..FR-021; SC-009 ↔ FR-022.
- [X] **Backwards-compat constraint surfaced** — Assumptions + US5.3 + Edge Cases + FR-016 all reinforce that existing worlds keep working.
- [X] **Non-goals explicit** — "Out of Scope" section enumerates six excluded areas with rationale or pointer (VCR → project memory).

## Validation Result

**Status**: PASS — spec is ready for `/speckit.clarify` or `/speckit.plan`.

No outstanding ambiguities worth formal clarification. The one area where implementation has discretion — exact sentinel value for unspecified metadata — is explicitly called out in Assumptions as intentional flexibility for the plan phase, not as an unresolved decision.

**Recommended next step**: `/speckit.plan` (clarify not needed — the spec resolved its own ambiguities during drafting via the postmortem's concrete defect inventory).
