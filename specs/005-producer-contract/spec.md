# Feature Specification: Producer Contract Interface

**Feature Branch**: `005-producer-contract`
**Created**: 2026-04-01
**Status**: Draft
**Input**: User description: "Producer Contract interface — Extract a common base interface that all content producers implement. Retrofit the existing ChapterGenerator as the first producer. The interface should accept: IP version reference (canon snapshot), product description/config, and output location. This prepares the architecture for the Instagram comic producer as the second producer."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Define and use the common producer interface (Priority: P1)

As a developer building new content types (books, comics, Instagram images), I want a common producer interface so that all producers follow the same contract: accept an IP version, product configuration, and output location, and produce artifacts consistently.

**Why this priority**: This is the foundation. Without the common interface, there is no shared contract for producers to implement.

**Independent Test**: Can be fully tested by creating a minimal producer that implements the interface and verifying it accepts the three required inputs and produces output at the specified location.

**Acceptance Scenarios**:

1. **Given** a producer interface definition exists, **When** a new producer class implements it, **Then** the producer accepts an IP version reference, product configuration, and output location as inputs.
2. **Given** a producer is invoked with valid inputs, **When** it completes, **Then** it writes artifacts to the specified output location.
3. **Given** a producer is invoked with valid inputs, **When** it completes, **Then** the output artifacts include metadata recording the canon version used.

---

### User Story 2 - Retrofit ChapterGenerator as a producer (Priority: P1)

As a developer, I want the existing ChapterGenerator to conform to the producer contract so that book chapter generation works through the same interface that future producers (Instagram, comics) will use.

**Why this priority**: Equal to P1 because retrofitting the existing generator proves the interface works in practice, not just in theory. The interface is only validated when at least one real producer implements it.

**Independent Test**: Can be tested by invoking the retrofitted ChapterGenerator through the producer interface and verifying it generates a chapter with the correct canon version metadata at the specified output location.

**Acceptance Scenarios**:

1. **Given** the ChapterGenerator implements the producer interface, **When** invoked with a canon snapshot, chapter configuration, and output path, **Then** it generates a chapter at that output path.
2. **Given** the ChapterGenerator is invoked via the producer interface, **When** no explicit snapshot is provided, **Then** it uses the latest available snapshot (or "unversioned" if none exist).
3. **Given** the existing CLI commands for chapter generation, **When** the ChapterGenerator is retrofitted, **Then** existing CLI behavior remains unchanged (backward compatible).

---

### User Story 3 - Configurable output location (Priority: P2)

As a developer, I want to specify where a producer writes its output so that different products can be directed to different directories without hardcoded paths.

**Why this priority**: Output location flexibility is required by the producer contract but is a secondary concern after the interface itself exists.

**Independent Test**: Can be tested by invoking a producer with different output paths and verifying artifacts land in the correct location each time.

**Acceptance Scenarios**:

1. **Given** a producer is invoked with an explicit output location, **When** generation completes, **Then** artifacts are written to that location, not to a default path.
2. **Given** a producer is invoked without an explicit output location, **When** generation completes, **Then** artifacts are written to the producer's default output path.

---

### User Story 4 - Existing CLI wired through producer interface (Priority: P3)

As a user, I want `book generate chapter` to continue working exactly as before, with the producer contract wired internally so the architecture is ready for future producers without changing my workflow.

**Why this priority**: Preserving the existing CLI surface is important for backward compatibility, but it's lower priority than the interface and retrofit themselves.

**Independent Test**: Can be tested by running `book generate chapter` and verifying identical behavior to pre-retrofit, while confirming internally it routes through the producer interface.

**Acceptance Scenarios**:

1. **Given** the ChapterGenerator is retrofitted as a producer, **When** the user runs `book generate chapter`, **Then** it behaves identically to before (same options, same output).
2. **Given** the producer interface exists internally, **When** a future producer is added, **Then** it can be wired to a new CLI command without modifying the existing `generate chapter` path.

*Note: A generic `book produce <name>` CLI command and `--list` discovery deferred to when a second producer is added.*

---

### Edge Cases

- What happens when a producer is invoked with a snapshot that does not exist? The system should raise a clear error before any generation begins.
- What happens when the specified output location does not exist? The system should create the directory structure automatically.
- What happens when a producer is invoked with no snapshots available and no explicit snapshot? It should proceed with "unversioned" canon reference (matching current behavior).
- What happens when a producer's output location already contains files? The producer should overwrite or append as appropriate for its content type, not silently skip.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST define a common producer interface that accepts: (1) IP version reference (snapshot name or nil for latest/unversioned), (2) product configuration as an opaque options hash (each producer defines and validates its own keys), and (3) output location (path where artifacts are written).
- **FR-002**: System MUST provide a base producer class or module that new producers can inherit from or include to implement the contract.
- **FR-003**: The producer interface MUST define a `produce` entry point method that orchestrates generation and returns a result indicating success or failure.
- **FR-004**: Every producer MUST record the canon version reference in the metadata of its output artifacts.
- **FR-005**: The existing ChapterGenerator MUST be retrofitted to implement the producer interface while preserving all current functionality and CLI behavior.
- **FR-006**: Producers MUST accept an explicit output location parameter, falling back to a sensible default when not provided.
- **FR-007**: The CLI MUST support passing an output location to any producer via a `--output` (or equivalent) flag.
- **FR-008**: The system MUST provide a minimal in-code registry so that producers can be registered and looked up by name. CLI listing/discovery is deferred to a future feature.
- **FR-009**: Producers MUST validate their inputs (snapshot existence, configuration completeness, output path writability) before starting generation.
- **FR-010**: The producer interface MUST be designed so that adding a new producer requires only implementing the interface and registering it — no modifications to existing producers or core engine code.

### Key Entities

- **Producer**: A content generator that implements the common interface. Has a name, description, accepted configuration parameters, and a default output location.
- **ProducerResult**: The outcome of a producer invocation. Contains success/failure status, output path, canon version used, and any generated artifact metadata.
- **ProducerRegistry**: A catalog of available producers. Maps producer names to their implementations for CLI discovery and invocation.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The ChapterGenerator works through the producer interface with zero regressions — all existing tests continue to pass.
- **SC-002**: A new producer can be added by implementing only the interface and registering it, with no changes required to existing code — verifiable by adding a minimal test producer.
- **SC-003**: All producer output artifacts include canon version metadata, verifiable by inspecting generated chapter front matter.
- **SC-004**: The existing `book generate chapter` CLI command works identically to before, internally routed through the producer interface.

## Clarifications

### Session 2026-04-01

- Q: How should the new producer CLI coexist with existing `generate chapter`? → A: Keep `book generate chapter` as-is on the surface; wire it to the producer interface internally.
- Q: Should the full registry/discovery CLI be in scope for v1 (one producer)? → A: Minimal in-code registry now; defer CLI `--list` command to the Instagram feature.
- Q: What shape should product configuration take? → A: Opaque options hash; each producer defines and validates its own keys.

## Assumptions

- The canon versioning system (feature 004) is complete and available for producers to reference snapshots.
- The existing ChapterGenerator's constructor signature and CLI options will be adapted, not preserved exactly — backward compatibility means CLI behavior is the same from the user's perspective, but internal APIs may change.
- This feature does not implement the Instagram producer; it only provides the interface and proves it with the chapter producer. Instagram is the next feature.
- Producer registration is in-process (same Ruby runtime), not a plugin system loading external gems.
