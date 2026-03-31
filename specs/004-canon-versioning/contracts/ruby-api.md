# Ruby API Contract: Snapshot System

**Date**: 2026-04-01
**Branch**: `004-canon-versioning`

## New Class: `BookCore::SnapshotStore`

```ruby
# Manages creation, listing, and loading of canon snapshots.
# Stores snapshots under data/story_bible/snapshots/.
class BookCore::SnapshotStore
  # @param story_bible_path [String] Path to story_bible directory
  def initialize(story_bible_path:)

  # Create a new snapshot from current Story Bible state.
  # @param name [String] Human-readable name (validated)
  # @param branch [String] Branch being captured (default: "main")
  # @return [Hash] Snapshot manifest data
  # @raise [DuplicateSnapshotError] if name already exists
  # @raise [InvalidSnapshotNameError] if name format is invalid
  def create(name:, branch: 'main')

  # List all snapshots ordered by version number.
  # @return [Array<Hash>] Array of manifest data
  def list

  # Get a specific snapshot by name or version number.
  # @param name_or_version [String, Integer] Snapshot name or version
  # @return [Hash, nil] Manifest data or nil if not found
  def get(name_or_version)

  # Get the latest snapshot.
  # @return [Hash, nil] Manifest data or nil if no snapshots exist
  def latest
end
```

## Modified Class: `BookCore::StoryBible`

```ruby
class BookCore::StoryBible
  # Load a read-only Story Bible from a snapshot.
  # Returns a StoryBible instance pointing at snapshot data.
  # Write operations will raise FrozenSnapshotError.
  # @param project_root [String] Project root path
  # @param snapshot_name [String] Snapshot name to load from
  # @param snapshot_store [SnapshotStore] Optional injected store
  # @return [StoryBible] Read-only instance
  # @raise [SnapshotNotFoundError] if snapshot doesn't exist
  # @raise [SnapshotCorruptError] if snapshot data is incomplete
  def self.from_snapshot(project_root:, snapshot_name:, snapshot_store: nil)
end
```

## Modified Class: `BookCore::ChapterGenerator`

```ruby
class BookCore::ChapterGenerator
  # New keyword argument:
  # @param snapshot [String, nil] Snapshot name to pin. If nil,
  #   auto-selects latest snapshot or uses live state.
  def initialize(model_override = nil, snapshot: nil, **kwargs)
end
```

## Canon Version Reference Helper

```ruby
module BookCore
  # Builds canon_version metadata for derivatives.
  module CanonVersionReference
    # @param snapshot_store [SnapshotStore]
    # @param explicit_snapshot [String, nil] User-specified snapshot
    # @return [Hash, String] Canon version hash or "unversioned"
    def self.resolve(snapshot_store:, explicit_snapshot: nil)
  end
end
```
