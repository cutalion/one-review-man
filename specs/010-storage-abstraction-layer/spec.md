# Feature Specification: Storage Abstraction Layer

**Feature Branch**: `010-storage-abstraction-layer`  
**Created**: 2026-04-02  
**Status**: Draft  
**Input**: User description: "Introduce a storage abstraction layer so that Eidos world data can be backed by different storage engines"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Switching Storage Backend for Development vs Production (Priority: P1)

As a developer configuring a world project, I want to select which storage backend the system uses (e.g., file-based for local development, database-backed for production) so that I can optimize for my environment without changing any application logic.

**Why this priority**: This is the foundational capability — without the ability to swap backends, none of the other stories are possible. It delivers the core architectural value of decoupling storage from business logic.

**Independent Test**: Can be fully tested by configuring a world project with two different storage backends and verifying that all entity operations (create, read, update, delete, search) produce identical results regardless of which backend is active.

**Acceptance Scenarios**:

1. **Given** a world project with a file-based storage configuration, **When** I perform any entity operation (read/write characters, facts, etc.), **Then** the system behaves identically to the current behavior.
2. **Given** a world project reconfigured to use a different storage backend, **When** I perform the same entity operations, **Then** the results are identical to the file-based backend.
3. **Given** an invalid or unsupported storage backend is configured, **When** the system starts, **Then** a clear error message identifies the problem and lists available backends.

---

### User Story 2 - Fast Isolated Testing with In-Memory Storage (Priority: P2)

As a developer running tests, I want to use an in-memory storage backend so that tests run faster, require no filesystem setup/cleanup, and are fully isolated from each other.

**Why this priority**: Testing speed and isolation are the most immediate practical benefit. The existing 388 tests use real temp directories; an in-memory backend would eliminate filesystem overhead and make tests truly independent.

**Independent Test**: Can be fully tested by running the entire existing test suite against the in-memory backend and confirming all tests pass with identical behavior, while measuring execution time improvement.

**Acceptance Scenarios**:

1. **Given** the test suite is configured to use in-memory storage, **When** all existing tests are run, **Then** every test passes with the same outcomes as the file-based backend.
2. **Given** two tests running in parallel with in-memory storage, **When** one test writes data, **Then** the other test's storage is unaffected (full isolation).
3. **Given** in-memory storage is active, **When** the test process ends, **Then** no persistent artifacts remain on disk.

---

### User Story 3 - Preserving All Existing Functionality (Priority: P1)

As a content creator using the CLI tools (bible, canon, produce), I want the storage abstraction to be invisible to me so that all my existing workflows continue to work exactly as before.

**Why this priority**: Backward compatibility is non-negotiable. The abstraction layer must not break or alter any user-facing behavior. This is co-equal with Story 1 because both must be true simultaneously.

**Independent Test**: Can be fully tested by running all existing CLI commands and automated tests against the file-based backend (extracted into the new adapter) and verifying zero behavioral changes.

**Acceptance Scenarios**:

1. **Given** the system is upgraded with the storage abstraction, **When** I run any bible command (list, show, search, context, export), **Then** the output is identical to the pre-abstraction version.
2. **Given** the system is upgraded with the storage abstraction, **When** I run any canon command (update, history, diff, rollback, snapshot, branch), **Then** the behavior is identical to the pre-abstraction version.
3. **Given** the system is upgraded with the storage abstraction, **When** I generate content (chapters, comics, illustrations), **Then** all generation workflows complete successfully with no changes in behavior.

---

### User Story 4 - Adding a New Storage Backend Without Modifying Core Logic (Priority: P3)

As a developer extending the system, I want a well-defined storage contract so that I can implement new backends (database, graph database, composite with search) without modifying any existing application code.

**Why this priority**: This is the long-term extensibility payoff. It validates that the abstraction is clean enough for third-party or future backends. Lower priority because it's a quality attribute of the design, not an immediate user need.

**Independent Test**: Can be fully tested by implementing a minimal "null" or "echo" storage backend using only the documented contract and verifying it integrates without any changes to application code.

**Acceptance Scenarios**:

1. **Given** the documented storage contract, **When** a developer implements a new backend that satisfies the contract, **Then** it plugs into the system with zero modifications to core logic.
2. **Given** a new backend is registered, **When** it is selected via configuration, **Then** the system uses it for all storage operations.
3. **Given** a new backend does not implement all required operations, **When** the system attempts to use it, **Then** a clear error identifies which operations are missing.

---

### Edge Cases

- When a storage backend becomes unavailable mid-operation, exceptions propagate as-is — the CLI shows the error and exits. No retry or fallback logic is included in the initial version.
- How does the system behave when migrating data between two different storage backends?
- Storage format consistency is enforced by shared conformance tests — any backend that returns data in a different format will fail the contract test suite before it can be used.
- Snapshot/restore across different backends is supported naturally since snapshots return data (not paths); any backend can consume the data format.
- Concurrent process access is out of scope for the initial version (single-process CLI usage pattern per Assumptions). No locking or coordination is provided.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide three separate storage contracts: one for entity management (including search), one for revision history, and one for snapshot operations. Each contract can be implemented and swapped independently.
- **FR-002**: System MUST include a file-based storage backend that preserves the exact current behavior (reading/writing entities as individual files, storing revisions as numbered files, managing snapshots as directory copies).
- **FR-003**: System MUST include an in-memory storage backend suitable for automated testing, supporting all operations defined in the contract.
- **FR-004**: System MUST allow the storage backend to be selected via project configuration, with the file-based backend as the default.
- **FR-005**: System MUST support all current entity types through the storage contract: characters, locations, facts (organized by category), relationships, and plot threads.
- **FR-006**: System MUST support revision history operations through the storage contract: recording revisions, querying history, retrieving specific revisions, and getting the latest revision, including branch-scoped revisions.
- **FR-007**: System MUST support snapshot operations through the storage contract: creating snapshots from current state, listing snapshots, and retrieving snapshots by name or version. Snapshots return entity data directly (not filesystem paths), keeping the contract storage-agnostic.
- **FR-008**: System MUST support keyword search on facts through the storage contract, with case-insensitive matching across fact names, descriptions, and rules.
- **FR-009**: System MUST validate that a configured storage backend implements all required operations before accepting it, and report clear errors for missing operations.
- **FR-010**: System MUST maintain cache invalidation behavior — when entities are modified, subsequent reads reflect the changes regardless of backend.
- **FR-011**: All existing tests (388 examples) MUST pass without modification when using the file-based storage backend extracted into the new adapter.

### Key Entities

- **Entity Storage Contract**: The set of operations for entity CRUD and search. Covers characters, locations, facts, relationships, and plot threads.
- **Revision Storage Contract**: The set of operations for append-only revision history. Covers recording, querying, and retrieving revisions with branch support.
- **Snapshot Storage Contract**: The set of operations for point-in-time snapshots. Covers creating, listing, and retrieving snapshots. Returns entity data directly (not filesystem paths) to remain storage-agnostic.
- **Storage Backend**: A concrete implementation of the storage contract. Each backend encapsulates how and where data is persisted (files, memory, database, etc.).
- **Entity**: A typed data record managed by the story bible — characters, locations, facts, relationships, or plot threads. Each has an identifier and structured data.
- **Revision**: An immutable record of a change to an entity, including sequence number, timestamp, operation type, and a snapshot of the entity state at that point.
- **Snapshot**: A point-in-time copy of the entire story bible state, used for versioning and read-only historical access.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of existing automated tests pass against the file-based storage backend after extraction into the new adapter (zero regressions).
- **SC-002**: 100% of existing automated tests pass against the in-memory storage backend (proving contract equivalence).
- **SC-003**: All existing CLI commands produce identical output before and after the abstraction is introduced.
- **SC-004**: A new storage backend can be created and integrated by implementing only the documented contract — zero lines of core application code need modification.
- **SC-005**: Test suite execution time with the in-memory backend is at least 30% faster than with the file-based backend.
- **SC-006**: Switching between storage backends requires changing only configuration — no code changes, no redeployment of application logic.

## Clarifications

### Session 2026-04-02

- Q: Should the storage abstraction be a single unified contract or three separate contracts? → A: Three separate contracts (entity storage, revision storage, snapshot storage), each independently swappable.
- Q: How should the system handle storage failures mid-operation? → A: Let exceptions propagate as-is; CLI shows the error and exits. No retry or fallback.
- Q: Should snapshots return filesystem paths or data? → A: Data-based; snapshot contract returns entity data directly, keeping it storage-agnostic.

## Assumptions

- The primary users of the storage abstraction are developers (configuring backends) and automated tests (using in-memory storage); end users interact with the CLI tools and are unaffected.
- Data migration between backends is out of scope for the initial version; each backend starts fresh or is populated independently.
- Concurrent write access to a single storage backend instance is not required in the initial version (single-process CLI usage pattern).
- The file-based backend will remain the default and recommended backend for local development and single-user workflows.
- Future backends (database, graph, RAG-enabled) will be implemented as separate follow-up features, each conforming to the contract defined here.
- The storage contract is designed to be additive — future versions may add optional operations (e.g., advanced search) without breaking existing backends that don't implement them.
