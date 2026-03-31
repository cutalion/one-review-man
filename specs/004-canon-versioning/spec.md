# Feature Specification: Canon Versioning and Snapshots

**Feature Branch**: `004-canon-versioning`
**Created**: 2026-03-31
**Status**: Draft
**Input**: User description: "Canon versioning and snapshot system for the IP engine"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Create a Canon Snapshot (Priority: P1)

A content creator has finished writing chapter 10 and wants to freeze the current state of the Story Bible before starting chapter 11. They run a CLI command to create a named snapshot that captures all characters, locations, facts, relationships, and plot threads as they exist right now.

**Why this priority**: Without snapshots, there is no IP versioning — all other stories depend on this capability.

**Independent Test**: Can be fully tested by creating a snapshot, modifying the Story Bible, and verifying the snapshot still reflects the original state.

**Acceptance Scenarios**:

1. **Given** a Story Bible with characters, locations, facts, relationships, and plot threads, **When** the user creates a snapshot named "after-chapter-10", **Then** an immutable record is stored that captures the full state of all entities at that moment.
2. **Given** no snapshots exist yet, **When** the user creates the first snapshot, **Then** the system assigns it a monotonically increasing version number alongside the human-readable name.
3. **Given** a snapshot named "after-chapter-10" already exists, **When** the user attempts to create another snapshot with the same name, **Then** the system rejects the request with a clear error message.

---

### User Story 2 - Load Story Bible from a Snapshot (Priority: P1)

A content creator wants to verify what the Story Bible looked like at a previous point in time. They load a snapshot by name and can read all entities as they existed when the snapshot was taken, without modifying the current live state.

**Why this priority**: Reading from a snapshot is the core mechanism that producers will use to pin their input to a specific canon version. Equal priority with US1 because snapshots are useless without the ability to read them.

**Independent Test**: Can be tested by creating a snapshot, modifying entities, then loading the snapshot and verifying the original data is returned.

**Acceptance Scenarios**:

1. **Given** a snapshot "after-chapter-10" was created when character Kenji had 3 mentions, **When** the user loads the Story Bible from that snapshot after adding a 4th mention, **Then** the loaded Story Bible shows Kenji with 3 mentions.
2. **Given** a snapshot exists, **When** the user loads the Story Bible from that snapshot, **Then** the current live Story Bible on disk is NOT modified.
3. **Given** a snapshot name that does not exist, **When** the user attempts to load it, **Then** the system returns a clear error indicating the snapshot was not found.

---

### User Story 3 - List and Inspect Snapshots (Priority: P2)

A content creator wants to see what snapshots exist, when they were created, and optionally compare the current state against a snapshot to understand what changed.

**Why this priority**: Important for usability but not required for the core versioning mechanism to function.

**Independent Test**: Can be tested by creating multiple snapshots and verifying the list output includes all of them with correct metadata.

**Acceptance Scenarios**:

1. **Given** three snapshots exist ("initial", "after-chapter-5", "after-chapter-10"), **When** the user lists snapshots, **Then** all three are shown with their names, version numbers, timestamps, and a summary of entity counts.
2. **Given** a snapshot "after-chapter-5" exists and the Story Bible has changed since, **When** the user inspects that snapshot, **Then** the system shows the entity counts and metadata captured in the snapshot.

---

### User Story 4 - Record Canon Version in Derivatives (Priority: P2)

When a chapter or illustration is generated, the system automatically records which canon snapshot (or current unversioned state) was used as input. This metadata is stored alongside the generated artifact so it can be traced back later.

**Why this priority**: This is the "IP version reference" that producers need, but it builds on snapshots existing first.

**Independent Test**: Can be tested by creating a snapshot, generating a chapter, and verifying the generation log records the snapshot reference.

**Acceptance Scenarios**:

1. **Given** a snapshot "after-chapter-10" is the latest snapshot, **When** the user generates chapter 11 without specifying a snapshot, **Then** the generation metadata records that it was produced from snapshot "after-chapter-10" (auto-selected as latest).
2. **Given** snapshots "after-chapter-5" and "after-chapter-10" exist, **When** the user generates an illustration with an explicit `--snapshot after-chapter-5` flag, **Then** the system uses the Story Bible state from "after-chapter-5" and records that version in the generation metadata.
3. **Given** no snapshots exist, **When** the user generates a chapter, **Then** the generation metadata records "unversioned" or equivalent to indicate no snapshot was pinned.
4. **Given** a chapter was generated from snapshot "after-chapter-10", **When** the user inspects the generation log, **Then** the canon version reference is visible and can be used to reload that exact Story Bible state.

---

### Edge Cases

- What happens when a snapshot is created on a non-main branch? The snapshot captures the branch state and records which branch it was taken from.
- What happens when the Story Bible has no entities (empty project)? An empty snapshot is valid — it captures the empty state.
- What happens if the snapshot storage is corrupted or a file is missing? The system reports a clear error and does not silently return partial data.
- What happens when there are hundreds of snapshots? List command remains responsive; snapshot storage scales with the filesystem (one manifest file per snapshot).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST create immutable snapshots that capture the complete state of all Story Bible entity types (characters, locations, facts, relationships, plot threads) at the time of creation.
- **FR-002**: Each snapshot MUST have a unique human-readable name (provided by user) and an auto-assigned monotonically increasing version number.
- **FR-003**: System MUST store snapshot metadata including: name, version number, timestamp, branch, and entity counts per type.
- **FR-004**: System MUST support loading a read-only view of the Story Bible from any existing snapshot, returning entity data as it existed at snapshot time.
- **FR-005**: System MUST reject duplicate snapshot names with a clear error.
- **FR-006**: System MUST list all snapshots with their metadata, ordered by version number.
- **FR-007**: System MUST record the canon version reference (snapshot name/version or "unversioned") whenever a derivative artifact is produced. By default, the system auto-selects the latest snapshot; users MAY override this with an explicit `--snapshot` flag to pin a specific version.
- **FR-008**: System MUST expose snapshot operations through the CLI (create, list, inspect).
- **FR-009**: Snapshots MUST work correctly on non-main branches, capturing and recording the branch context.
- **FR-010**: System MUST validate snapshot integrity on load — if data is missing or corrupt, report an error rather than returning partial state.

### Key Entities

- **Snapshot**: A named, immutable point-in-time capture of the full Story Bible state. Contains a manifest (metadata + entity references) and the actual entity data.
- **Snapshot Manifest**: Metadata about the snapshot — name, version number, timestamp, branch, entity counts. Acts as the index for the snapshot.
- **Canon Version Reference**: A lightweight pointer (snapshot name + version number) stored in derivative metadata to trace provenance. Can reference a snapshot or indicate "unversioned" state.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Creating a snapshot of a Story Bible with 10+ characters, 9+ locations, and associated facts/relationships/plot threads completes in under 5 seconds.
- **SC-002**: Loading a Story Bible from a snapshot returns data identical to what was present at snapshot creation time — 100% fidelity, verified by round-trip comparison.
- **SC-003**: After 50+ snapshots, list and load operations remain responsive (under 2 seconds).
- **SC-004**: Every generated chapter and illustration includes a traceable canon version reference in its metadata.

## Clarifications

### Session 2026-03-31

- Q: Should derivative generation auto-select the latest snapshot or allow explicit pinning? → A: Auto-select latest by default, but allow explicit `--snapshot` flag to pin a specific version.

## Assumptions

- Snapshots capture the full state by copying entity data, not by replaying revision history. This is simpler and more reliable than reconstructing state from diffs.
- Snapshot storage uses the filesystem (YAML files) consistent with existing project patterns — no external database.
- Snapshots are immutable once created — there is no "update snapshot" operation. To capture new state, create a new snapshot.
- The existing RevisionStore append-only history continues to operate independently. Snapshots are a parallel concept — a "release tag" vs. individual entity change log.
- Binary assets (images, style guides) are out of scope for this feature. The snapshot system captures YAML-serializable entity data only. Binary asset versioning will be addressed in a future feature.
- The generation log (`generation_log.yml`) is the initial location for recording canon version references in derivatives. This may evolve as the Producer Contract pattern matures.
