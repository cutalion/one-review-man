# Library API Contract: Canon Branching and Change History

**Feature**: 002-canon-branching-history
**Date**: 2026-03-30

All classes accept dependencies via constructor injection (Constitution Principle III).

## BookCore::RevisionStore

Manages append-only revision history for canon entries.

```ruby
# Initialize with a base path for revision storage
store = RevisionStore.new(revisions_path:)

# Record a new revision (returns Revision)
store.record(entity_type:, entity_id:, snapshot:, operation:,
             branch: "main", change_reason: nil, changeset_id: nil)

# Get all revisions for an entity (returns Array<Revision>)
store.history(entity_type:, entity_id:, branch: "main")

# Get a specific revision (returns Revision or nil)
store.get(entity_type:, entity_id:, sequence:, branch: "main")

# Get the latest revision (returns Revision or nil)
store.latest(entity_type:, entity_id:, branch: "main")
```

## BookCore::DiffEngine

Computes field-level diffs and detects conflicts between entity snapshots.

```ruby
engine = DiffEngine.new

# Compare two snapshots (returns Hash of field_path => {old:, new:})
engine.diff(snapshot_a, snapshot_b)

# Three-way merge conflict detection (returns Array<Conflict>)
engine.find_conflicts(base:, ours:, theirs:)

# Auto-merge non-conflicting changes (returns {merged:, conflicts:})
engine.three_way_merge(base:, ours:, theirs:)
```

## BookCore::ImpactAnalyzer

Identifies content affected by canon changes.

```ruby
analyzer = ImpactAnalyzer.new(
  content_path:,        # Path to content/ directory
  reference_index_path:, # Path to references.yml
  revision_store:        # Injected RevisionStore
)

# Analyze impact of a canon change (returns ImpactReport)
analyzer.analyze(entity_type:, entity_id:, revision:, branch: "main")

# Rebuild reference index from content files
analyzer.rebuild_index!

# Update review status on a report item
analyzer.update_review_status(report_id:, item_index:, status:)
```

## BookCore::BranchManager

Creates, compares, merges, and manages branch lifecycle.

```ruby
manager = BranchManager.new(
  story_bible_path:,  # Path to data/story_bible/
  revision_store:,    # Injected RevisionStore
  diff_engine:        # Injected DiffEngine
)

# Create a branch (returns Branch)
manager.create(name:, from_branch: "main", at_revision: nil,
               description: nil)

# List branches (returns Array<Branch>)
manager.list(include_archived: false)

# Get current branch name (returns String)
manager.current_branch

# Switch branch context (returns Branch)
manager.checkout(name)

# Compare two branches (returns {only_in_a:, only_in_b:, conflicts:, identical:})
manager.compare(branch_a, branch_b)

# Merge source into target (returns {auto_merged:, conflicts:})
manager.merge(source:, target:, resolutions: {})

# Archive a branch
manager.archive(name)

# Unarchive a branch
manager.unarchive(name)

# Delete a branch permanently
manager.delete(name)
```

## BookCore::ChangesetManager

Groups multiple canon changes for atomic preview and commit.

```ruby
manager = ChangesetManager.new(
  changesets_path:,    # Path to data/changesets/
  story_bible:,        # Injected StoryBible (branch-aware)
  revision_store:,     # Injected RevisionStore
  impact_analyzer:     # Injected ImpactAnalyzer
)

# Create a new changeset (returns Changeset)
manager.create(branch: "main")

# Get active changeset for a branch (returns Changeset or nil)
manager.active(branch: "main")

# Add an operation to the active changeset
manager.add_operation(changeset_id:, operation:, entity_type:,
                      entity_id:, changes: {}, change_reason: nil)

# Preview aggregate impact (returns {report:, conflicts:})
manager.preview(changeset_id:)

# Commit atomically (returns Array<Revision>)
# Raises ChangesetConflictError if unresolved conflicts
manager.commit(changeset_id:, reason: nil)

# Discard without applying
manager.discard(changeset_id:)
```

## Value Objects (BookCore::Models)

```ruby
# All are plain Ruby objects with read-only attributes

Revision = Struct(sequence, entity_type, entity_id, snapshot,
                  timestamp, change_reason, parent_seq,
                  operation, branch, changeset_id)

Branch = Struct(name, display_name, parent_branch, created_at,
                created_from, status, archived_at, description)

ImpactReport = Struct(id, trigger, created_at, branch,
                      affected_items, summary)

AffectedItem = Struct(content_type, content_path, references,
                      severity, review_status, reviewed_at)

Changeset = Struct(id, branch, created_at, status, operations,
                   preview_report, committed_at)

ChangeOperation = Struct(operation, entity_type, entity_id,
                         changes, change_reason)

Conflict = Struct(entity_type, entity_id, field_path,
                  base_value, ours_value, theirs_value,
                  resolution, custom_value)
```

## StoryBible Extensions

The existing `BookCore::StoryBible` class is extended to be branch-aware:

```ruby
# Existing methods gain an optional branch: parameter
bible = StoryBible.new(data_path:, revision_store:, branch_manager:)

# All read/write operations respect the current branch
bible.get_character("kenji_yamamoto")         # reads from current branch
bible.update_character("kenji_yamamoto", backstory: "...")  # writes + records revision

# Branch context
bible.current_branch    # => "main"
bible.on_branch("what-if") { ... }  # temporarily switch context
```
