# Quickstart: Canon Versioning and Snapshots

## Prerequisites

- Ruby 3.3.5 with Bundler
- Book project initialized (`book-generator/bin/book init`)
- At least one chapter generated (for meaningful snapshot content)

## Create Your First Snapshot

```bash
# From repo root
book-generator/bin/book snapshot create initial -b books/one-review-man
```

Output:
```
Created snapshot "initial" (version 1)
  Characters: 11
  Locations: 9
  Facts: 5 categories
  Relationships: 8
  Plot threads: 4
```

## Generate a Chapter Pinned to a Snapshot

```bash
# Auto-selects latest snapshot
book-generator/bin/book generate chapter -b books/one-review-man

# Or pin to a specific snapshot
book-generator/bin/book generate chapter --snapshot initial -b books/one-review-man
```

The generated chapter's front matter will include:
```yaml
canon_version:
  snapshot: "initial"
  version: 1
  branch: "main"
```

## List and Inspect Snapshots

```bash
# List all
book-generator/bin/book snapshot list -b books/one-review-man

# Show details for one
book-generator/bin/book snapshot show initial -b books/one-review-man
```

## Load Story Bible from a Snapshot (Ruby API)

```ruby
store = BookCore::SnapshotStore.new(
  story_bible_path: "books/one-review-man/data/story_bible"
)

bible = BookCore::StoryBible.from_snapshot(
  project_root: "books/one-review-man",
  snapshot_name: "initial",
  snapshot_store: store
)

# Read-only access to the snapshot state
bible.characters  # => characters as of snapshot "initial"
bible.facts       # => facts as of snapshot "initial"
```

## Verify Round-Trip Fidelity

```bash
cd book-generator
MOCK_AI=true bundle exec rspec spec/book_core/snapshot_store_spec.rb
```
