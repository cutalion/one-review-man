# Research: Canon Branching and Change History

**Feature**: 002-canon-branching-history
**Date**: 2026-03-30

## R1: Revision Storage Strategy (YAML-based append-only history)

**Decision**: Store revisions as numbered YAML files per entity in a `revisions/` directory tree mirroring the `story_bible/` structure. Each revision file contains the full entity snapshot, timestamp, change reason, and parent revision reference.

**Rationale**: Full snapshots are simpler to implement and reason about than diffs. YAML files are human-readable and align with the existing storage pattern. At the expected scale (hundreds of revisions, not millions), the storage overhead of full snapshots is negligible. Diffing is computed on-the-fly from two snapshots rather than stored.

**Alternatives considered**:
- **Delta/diff storage**: Lower disk usage but complex reconstruction logic, harder to inspect manually, and unnecessary at this scale.
- **Single-file append log**: Simpler but harder to query individual entity histories; YAML arrays become unwieldy at scale.
- **SQLite**: Better query performance but introduces a new dependency, breaks the YAML-everywhere convention, and adds complexity for a single-user tool.

## R2: Branch Storage Strategy (copy-on-branch with shared base)

**Decision**: When a branch is created, copy the entire `story_bible/` directory tree into `story_bible/branches/{branch-name}/`. The branch operates on its own copy. A `_index.yml` file at `story_bible/branches/` tracks the branch tree (parent, creation point, status).

**Rationale**: Full copy is simple to implement and guarantees branch independence (Constitution Principle IV — content integrity). At the expected scale (dozens of YAML files per world), copying is fast and disk usage is trivial. The `_index.yml` index enables branch tree traversal for comparison and merge operations.

**Alternatives considered**:
- **Copy-on-write / symlinks**: More space-efficient but significantly more complex, platform-dependent (symlinks on Windows), and fragile when files are edited in-place.
- **Git-backed branching**: Elegant but couples the content model to git, makes the tool harder to use outside a git repo, and conflates source-code versioning with creative versioning.
- **Virtual overlay (in-memory diff from base)**: Efficient but complex to persist, harder to debug, and breaks the "files are the source of truth" principle.

## R3: Impact Analysis Approach (reference index + content scanning)

**Decision**: Maintain a reference index (`story_bible/references.yml`) that maps each canon entry to the content pieces that reference it (chapter files, translations). When a canon entry changes, look up its dependents in the index and scan those files for specific passages referencing the changed fields. The index is rebuilt on demand and cached.

**Rationale**: A pre-built index makes impact lookups fast (O(1) per entry) rather than requiring a full scan of all content on every change. The index can be rebuilt from scratch at any time by scanning content files, so it's a cache — not a source of truth. Content scanning for specific passages provides the detailed impact report the spec requires.

**Alternatives considered**:
- **Full content scan on every change**: Simple but slow at scale (50+ content files x 10k words each). Acceptable as a fallback but not as the primary path.
- **Embedded references in content files (front matter)**: Reliable but requires content files to explicitly declare their canon dependencies, adding authoring burden.
- **LLM-based semantic analysis**: Could detect subtle inconsistencies but is non-deterministic, expensive, slow, and violates the offline/MOCK_AI testing constraint. Could be added as an optional enhancement later.

## R4: Field-Level Diff and Conflict Detection

**Decision**: Compare YAML entity snapshots field-by-field using deep hash comparison. A conflict exists only when both branches modify the same leaf field of the same entity relative to their common ancestor. Non-conflicting changes from both branches are auto-merged; conflicts require manual resolution.

**Rationale**: Field-level granularity (per the clarification) avoids false conflicts when two branches modify unrelated aspects of the same entity. Deep hash comparison handles nested structures (e.g., `physical_appearance.hair`). Using the common ancestor as the base (three-way merge) correctly identifies which branch introduced each change.

**Alternatives considered**:
- **Text-based diff (treat YAML as text)**: Simpler but produces noisy diffs for YAML (key ordering, whitespace) and can't distinguish semantic vs. formatting changes.
- **Entry-level diff**: Simpler but generates excessive false conflicts (any change to the same entity = conflict), which was explicitly rejected in clarification.

## R5: Changeset Atomicity Strategy

**Decision**: A changeset is a YAML file listing pending operations (create, update, delete for canon entries). Preview computes the aggregate impact by applying all operations to an in-memory copy of the current state and running impact analysis on the result. Commit applies all operations sequentially, writing a single combined revision entry. If any operation fails, roll back all previously applied operations in reverse order.

**Rationale**: In-memory preview avoids polluting the actual data during "what if" exploration. Sequential apply with rollback-on-failure provides atomicity without requiring transaction support in the filesystem. The single combined revision entry keeps history clean.

**Alternatives considered**:
- **Filesystem transactions (temp directory + rename)**: More robust atomicity but complex; rename-based atomicity doesn't work across directories on all filesystems.
- **Write-ahead log**: Enterprise-grade durability but overkill for a single-user YAML-based tool.

## R6: Background Impact Analysis

**Decision**: "Background" in this single-process CLI context means: after a canon change is written, the impact analysis runs as a follow-up step within the same command invocation but does not block the command's primary output. Results are written to a `story_bible/impact_reports/` directory as YAML files. The creator can view them via a separate CLI command (`book canon impact`).

**Rationale**: True background processing (threads, job queues) adds complexity inappropriate for a CLI tool. The spec's "non-blocking" requirement is satisfied by ensuring the creator doesn't need to act on impact results immediately — they're computed and stored, available on demand.

**Alternatives considered**:
- **Async threads**: Adds concurrency complexity, potential race conditions on YAML files, and debugging difficulty — all for marginal benefit in a CLI tool.
- **Lazy/on-demand only**: Simpler but means impact data isn't ready when the creator wants it; they'd have to explicitly request and wait each time.
