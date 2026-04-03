# Quickstart: Storage Abstraction Layer

## Overview

This feature introduces three storage contracts and a factory that lets the system swap between storage backends (YAML files, in-memory, future databases) without changing application logic.

## Key Concepts

1. **Three contracts**: `EntityStorage`, `RevisionStorage`, `SnapshotStorage` — each independently swappable.
2. **Two initial backends**: `YamlFile` (extracts current behavior) and `Memory` (for tests).
3. **StorageFactory**: Reads `data/settings.yml` and returns configured adapter instances.
4. **StoryBible** delegates to `EntityStorage` adapter instead of doing filesystem I/O directly.
5. **RevisionStore** and **SnapshotStore** become interfaces; their current implementations become the `YamlFile` backends.

## Configuration

In `data/settings.yml`:

```yaml
storage:
  backend: yaml_file  # or: memory
```

Default is `yaml_file` if omitted (backward compatible).

## For Test Authors

Tests can use the memory backend for speed and isolation:

```ruby
# In spec_helper or individual specs
entity_store = Eidos::Storage::Memory::EntityStorage.new
revision_store = Eidos::Storage::Memory::RevisionStorage.new
snapshot_store = Eidos::Storage::Memory::SnapshotStorage.new

bible = Eidos::StoryBible.new(entity_storage: entity_store, revision_storage: revision_store)
```

## For Backend Implementors

To add a new storage backend:

1. Implement the three contracts (see `contracts/` directory).
2. Register the backend name in `StorageFactory`.
3. Add the backend name to `data/settings.yml` as a valid option.

No changes to StoryBible, CLI commands, or any other application code required.

## File Layout

```
eidos/lib/eidos/storage/
├── entity_storage.rb          # Base module / contract definition
├── revision_storage.rb        # Base module / contract definition
├── snapshot_storage.rb        # Base module / contract definition
├── factory.rb                 # StorageFactory — reads config, returns adapters
├── yaml_file/
│   ├── entity_storage.rb      # Current StoryBible filesystem logic extracted
│   ├── revision_storage.rb    # Current RevisionStore logic extracted
│   └── snapshot_storage.rb    # Current SnapshotStore logic extracted
└── memory/
    ├── entity_storage.rb      # Hash-based in-memory implementation
    ├── revision_storage.rb    # Array-based in-memory implementation
    └── snapshot_storage.rb    # Hash-based in-memory implementation
```
