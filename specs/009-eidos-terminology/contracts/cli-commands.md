# CLI Commands Contract: Eidos

**Feature**: 009-eidos-terminology
**Date**: 2026-04-01

## Shared Options

All binaries accept:
- `--world-dir PATH` / `-w PATH` — path to the world directory (defaults to current directory)

## bin/world

World lifecycle management.

```
world new -w PATH              # Scaffold a new world
world init -w PATH [--quick]   # Initialize world (interactive, or quick with defaults)
world status [-w PATH]         # Show world configuration and status
world migrate [-w PATH]        # Migrate from books/ to worlds/ format
world reset SCOPE [-w PATH]    # Reset generated content (SCOPE: all|chapters|characters|data|site|status)
world version                  # Show Eidos version
```

## bin/bible

Story Bible management.

```
bible list TYPE [-w PATH]                  # List entities (characters, locations)
bible show ENTITY_PATH [-w PATH]           # Show entity details
bible search QUERY [-w PATH]               # Search facts
bible context CHAPTER [-w PATH]            # Show context for a chapter number
bible migrate [-w PATH]                    # Migrate data to Story Bible format
bible export [-w PATH]                     # Export Story Bible to Jekyll format
```

## bin/canon

Canon versioning, branching, and batch changes.

```
# History & diffing
canon show [-w PATH]                                          # Show world configuration
canon history ENTITY_TYPE ENTITY_ID [-w PATH]                 # Show revision history
canon diff ENTITY_TYPE ENTITY_ID REV1 REV2 [-w PATH]         # Compare revisions
canon rollback ENTITY_TYPE ENTITY_ID REVISION [-w PATH]       # Rollback to revision
canon update ENTITY_TYPE ENTITY_ID [FIELD=VALUE...] [-w PATH] # Update entity

# Impact analysis
canon impact [-w PATH]                                        # View impact reports
canon impact_review REPORT_ID ITEM_INDEX STATUS [-w PATH]     # Review impact item

# Snapshots
canon snapshot create NAME [-w PATH]       # Create snapshot
canon snapshot list [-w PATH]              # List snapshots
canon snapshot show NAME [-w PATH]         # Show snapshot details

# Branches
canon branch create NAME [-w PATH]         # Create branch
canon branch list [-w PATH]                # List branches
canon branch checkout NAME [-w PATH]       # Switch branch
canon branch compare B1 B2 [-w PATH]       # Compare branches
canon branch merge SOURCE TARGET [-w PATH] # Merge branches
canon branch archive NAME [-w PATH]        # Archive branch
canon branch delete NAME [-w PATH]         # Delete branch

# Changesets
canon changeset create [-w PATH]                                        # Start changeset
canon changeset add OPERATION ENTITY_TYPE ENTITY_ID [FIELD=VALUE...] [-w PATH] # Add operation
canon changeset preview [-w PATH]                                       # Preview impact
canon changeset commit [-w PATH]                                        # Commit changeset
canon changeset discard [-w PATH]                                       # Discard changeset
```

## bin/produce

Content production (all content creation commands).

```
produce chapter [NUMBER] [-w PATH] [--model MODEL] [--auto] [--debug]  # Generate chapter
produce comic [-w PATH] [--model MODEL] [--debug]                       # Generate comic panels
produce illustration [CHAPTER] [-w PATH] [--debug]                      # Generate illustration
produce prompt [CHAPTER] [-w PATH]                                      # Show generation prompt (dry run)
produce write [CHAPTER] [-w PATH] [--model MODEL] [--debug]             # Agent-based chapter writing (WriterAgent)
```

## bin/translate

Content translation.

```
translate chapter NUMBER LANG [-w PATH]    # Translate a chapter
translate character SLUG LANG [-w PATH]    # Translate a character
translate all LANG [-w PATH]               # Translate all content
```

## bin/publish

Publishing to distribution targets.

```
publish jekyll [-w PATH] [--dest DEST]     # Generate Jekyll site
```

## Migration from Old CLI

| Old Command | New Command |
|-------------|-------------|
| `book generate chapter` | `produce chapter` |
| `book generate comic` | `produce comic` |
| `book generate illustration` | `produce illustration` |
| `book generate prompt` | `produce prompt` |
| `book translate chapter 1 ru` | `translate chapter 1 ru` |
| `book translate all ru` | `translate all ru` |
| `book init` | `world init` |
| `book jekyll generate` | `publish jekyll` |
| `book bible list characters` | `bible list characters` |
| `book bible write` | `produce write` |
| `book canon show` | `canon show` |
| `book snapshot create v1` | `canon snapshot create v1` |
| `book branch create alt` | `canon branch create alt` |
| `book changeset create` | `canon changeset create` |
| `book agent generate` | `produce write` |
| `book reset all` | `world reset all` |
| `book status` | `world status` |
| `book migrate` | `world migrate` |
