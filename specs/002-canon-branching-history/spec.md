# Feature Specification: Canon Branching and Change History

**Feature Branch**: `002-canon-branching-history`
**Created**: 2026-03-30
**Status**: Draft
**Input**: User description: "creator may want to change the character, fact, event, etc when world is already built to some degree and the system should update and/or branch the rest of the world to make it consistent with a changed detail. It should support branching and change history tracking."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Track Change History for Canon Entries (Priority: P1)

A creator modifies a canon entry (character trait, world fact, event detail) in an established world. The system records what changed, when, and why. The creator can view the full revision history of any canon entry and compare any two versions side by side.

**Why this priority**: Change history is the foundation for both understanding what happened and for branching. Without it, neither rollback nor branching is possible.

**Independent Test**: Create a world with a character, modify that character's backstory three times, then view the revision history and confirm all three versions are recorded with timestamps and diffs.

**Acceptance Scenarios**:

1. **Given** a world with an existing canon entry, **When** the creator updates the entry, **Then** the system stores the previous version and records the change with a timestamp and optional change reason.
2. **Given** a canon entry with multiple revisions, **When** the creator requests revision history, **Then** the system displays all versions in chronological order with diffs between consecutive versions.
3. **Given** a canon entry with multiple revisions, **When** the creator selects two specific versions, **Then** the system shows a side-by-side comparison highlighting the differences.
4. **Given** a canon entry with revisions, **When** the creator requests a rollback to a previous version, **Then** the system restores that version as the current state and records the rollback as a new revision.

---

### User Story 2 - Propagate Canon Changes to Dependent Content (Priority: P2)

When a creator changes a canon entry, the system automatically identifies all content (chapters, translations, media references) that depends on the changed entry and flags them for consistency review. This analysis runs in the background without blocking the creator's work. The creator can see an impact report showing exactly what is affected and why at any time, and can choose to accept, update, or defer each affected piece at their own pace.

**Why this priority**: Change propagation is the core value — without it, changes create silent inconsistencies across the world. It depends on change tracking (US1).

**Independent Test**: Create a world with a character referenced in three chapters, change the character's name, and verify the system produces an impact report listing all three chapters with the specific passages that reference the old name.

**Acceptance Scenarios**:

1. **Given** a canon entry referenced by multiple content pieces, **When** the creator modifies the entry, **Then** the system produces an impact report listing every affected content piece, the specific references within each, and the nature of the inconsistency.
2. **Given** an impact report with affected content, **When** the creator marks a content piece as "reviewed and accepted," **Then** the system records the acknowledgment and clears the consistency flag for that piece.
3. **Given** an impact report, **When** the creator chooses to defer review of a content piece, **Then** the system keeps the flag active and includes the deferred item in future consistency reports.
4. **Given** a canon change that affects translations, **When** the impact report is generated, **Then** translated content referencing the changed entry is also flagged, with glossary implications noted.

---

### User Story 3 - Branch a World to Explore Alternate Versions (Priority: P3)

A creator branches a world at its current state (or from a specific historical point) to explore "what if" scenarios. The branch is a full copy of the world's canon and content that can be modified independently. Branches can themselves be branched, forming a tree structure for deep exploratory forking. The creator can compare branches side by side to see how they diverge, and optionally merge changes from one branch back into another.

**Why this priority**: Branching enables creative exploration without risk to the main canon. It builds on change history (US1) and benefits from propagation (US2) but is independently valuable.

**Independent Test**: Create a world with established canon, branch it, modify a character in the branch, then compare the two branches and verify the system shows exactly what diverges.

**Acceptance Scenarios**:

1. **Given** a world with established canon, **When** the creator creates a branch with a name, **Then** the system creates an independent copy of the world's current state that can be modified without affecting the original.
2. **Given** a world with change history, **When** the creator branches from a specific historical point, **Then** the branch starts from that point's state, not the current state.
3. **Given** two branches of the same world, **When** the creator requests a comparison, **Then** the system shows which canon entries differ, which content pieces diverge, and which are identical.
4. **Given** a branch with changes the creator wants to adopt, **When** the creator merges selected changes back into the main branch, **Then** the system applies those changes, runs consistency checks on the result, and reports any conflicts that require manual resolution.

---

### User Story 4 - Batch Canon Changes with Consistency Preview (Priority: P4)

A creator plans multiple related canon changes (e.g., renaming a faction and updating all its members' affiliations) and wants to preview the combined impact before committing. The system groups these changes into a changeset, shows the aggregate impact report, and applies them atomically — either all succeed or none do.

**Why this priority**: Batch changes prevent the "death by a thousand cuts" problem where individual changes each trigger separate review cycles. It enhances US2's propagation with transactional safety.

**Independent Test**: Queue three related canon changes (rename a location, update two characters who live there), preview the combined impact report, then commit all at once and verify the world is consistent.

**Acceptance Scenarios**:

1. **Given** a world, **When** the creator queues multiple canon changes without committing, **Then** the system stores them as a pending changeset.
2. **Given** a pending changeset, **When** the creator requests a preview, **Then** the system shows the aggregate impact across all changes, including cascading effects where one change affects another.
3. **Given** a previewed changeset, **When** the creator commits, **Then** all changes are applied atomically and a single combined entry appears in the change history.
4. **Given** a pending changeset, **When** the creator discards it, **Then** no changes are applied and the world remains in its prior state.

---

### Edge Cases

- What happens when a branch diverges so far that merge becomes impractical? The system MUST report all conflicts and allow the creator to resolve them one by one, or abandon the merge without side effects.
- What happens when a rollback undoes a change that other content has already been updated to reflect? The system MUST run a full consistency check after rollback and flag newly introduced inconsistencies.
- What happens when two changes in a batch conflict with each other (e.g., deleting a character and simultaneously adding content referencing that character)? The system MUST detect intra-batch conflicts during preview and prevent commit until resolved.
- What happens when the creator tries to branch from a historical point that predates the existence of certain canon entries? The branch MUST accurately reflect the world state at that point — entries that did not yet exist MUST NOT appear in the branch.
- How does the system handle very large worlds (thousands of canon entries) when computing impact reports? The system MUST complete impact analysis within a reasonable time and allow the creator to scope the analysis to specific canon categories if needed.

## Clarifications

### Session 2026-03-30

- Q: When does impact analysis run — automatically blocking, automatically non-blocking, or manual trigger? → A: Automatic but non-blocking — analysis runs on every change, results available when creator is ready.
- Q: Can branches be created from other branches (nested), or only from the main world? → A: Tree structure — any branch can be branched further, forming a hierarchy.
- Q: At what granularity are merge conflicts detected — entry-level, field-level, or semantic? → A: Field-level — only conflicting if both branches changed the same field of the same entry.
- Q: What happens to branches after they serve their purpose? → A: Branches can be archived (read-only, recoverable) or permanently deleted.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST record a new revision for every modification to a canon entry, storing the previous state, timestamp, and an optional creator-provided change reason.
- **FR-002**: The system MUST allow creators to view the complete revision history of any canon entry, ordered chronologically.
- **FR-003**: The system MUST support side-by-side comparison of any two revisions of a canon entry, highlighting differences.
- **FR-004**: The system MUST allow rollback of a canon entry to any previous revision, recording the rollback itself as a new revision.
- **FR-005**: The system MUST automatically compute an impact report in the background when a canon entry changes, identifying all dependent content pieces (chapters, translations, media references) and the specific references within each. This analysis MUST NOT block the creator from continuing to make changes.
- **FR-006**: The system MUST allow creators to mark affected content as "reviewed," "needs update," or "deferred" in response to an impact report.
- **FR-007**: The system MUST support creating named branches of a world from its current state or from a specific historical point. Branches MUST be nestable — a branch can be created from any other branch, forming a tree structure.
- **FR-008**: The system MUST ensure branches are fully independent — changes in one branch MUST NOT affect another.
- **FR-008a**: The system MUST allow branches to be archived (made read-only and hidden from default views, but recoverable) or permanently deleted.
- **FR-009**: The system MUST support comparing two branches to show canon and content differences.
- **FR-010**: The system MUST support merging selected changes from one branch into another, with field-level conflict detection (a conflict exists only when both branches modify the same field of the same canon entry) and manual resolution workflow.
- **FR-011**: The system MUST support grouping multiple canon changes into a changeset that can be previewed and committed atomically.
- **FR-012**: The system MUST detect conflicts within a changeset during preview (e.g., contradictory changes) and prevent commit until conflicts are resolved.
- **FR-013**: The system MUST propagate impact analysis to translations when a canon change affects glossary terms or translated content.
- **FR-014**: Impact reports MUST include severity levels (e.g., direct contradiction vs. potentially affected) to help creators prioritize review.

### Key Entities

- **Revision**: A versioned snapshot of a canon entry at a point in time. Contains the entry state, timestamp, change reason, and a reference to the previous revision.
- **Impact Report**: The result of analyzing a canon change against all dependent content. Lists affected content pieces, specific references, severity, and review status.
- **Branch**: A named, independent copy of a world's canon and content state. Has a parent branch (which may itself be a branch, forming a tree), a creation point (timestamp or revision reference), its own independent revision history, and a lifecycle status (active, archived, or deleted).
- **Changeset**: A group of pending canon changes that can be previewed and applied atomically. Has a status (draft, previewed, committed, discarded).
- **Conflict**: A field-level inconsistency detected during merge or batch preview — two branches modified the same field of the same canon entry. References the conflicting field, both values, and requires creator resolution before proceeding.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Creators can view the full revision history of any canon entry and compare any two versions in under 5 seconds for a world with 500+ revisions.
- **SC-002**: Impact reports for a single canon change are generated within 30 seconds for a world with 200+ canon entries and 50+ content pieces.
- **SC-003**: 100% of direct dependencies (content explicitly referencing a changed entry) are identified in impact reports — no silent inconsistencies.
- **SC-004**: Branching a world with 200+ canon entries and 50+ content pieces completes in under 1 minute.
- **SC-005**: Creators can resolve a merge with up to 20 conflicts in a single session without data loss or corruption.
- **SC-006**: Batch changesets with up to 50 changes can be previewed within 2 minutes and committed atomically with zero partial-apply failures.

## Assumptions

- This feature builds on the world and canon model defined in the IP World Consistency Engine (spec 001). Canon entries, content pieces, and consistency validation already exist.
- Branching creates a logical copy, not necessarily a physical duplication of all data — the system may optimize storage internally as long as the creator experiences full independence.
- Merge conflicts are resolved manually by the creator; the system does not auto-resolve semantic conflicts (it detects and presents them).
- Change history is append-only — revisions are never deleted, only superseded. This ensures a complete audit trail.
- The primary user is the world creator or a small team; concurrent editing of the same branch by multiple users is not a requirement for this feature.
- "Branching" in this context refers to world-content branching (creative versioning), not source-code branching, though the concepts are analogous.
