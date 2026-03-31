# CLI Contract: Canon Branching and Change History

**Feature**: 002-canon-branching-history
**Date**: 2026-03-30

All commands support `--book-dir` (`-b`) flag per Constitution Principle II.

## Canon History Commands

### `book canon history <entity_type> <entity_id>`

Show revision history for a canon entry.

```
Options:
  -b, --book-dir DIR     # Book directory (required)
  --branch NAME          # Branch context (default: "main")
  --limit N              # Show last N revisions (default: all)
  --format FORMAT        # Output format: text (default), json

Output (text):
  Rev #3 | 2026-03-30T14:22:00Z | update
  Reason: Updated backstory after chapter 8
  Changed: backstory, personality_traits
  ---
  Rev #2 | 2026-03-28T10:15:00Z | update
  Reason: Added quirks
  Changed: quirks
  ---
  Rev #1 | 2026-03-25T09:00:00Z | create
  Reason: Initial creation
  Changed: (all fields)

Exit codes: 0 success, 1 entity not found, 2 book-dir invalid
```

### `book canon diff <entity_type> <entity_id> <rev1> <rev2>`

Compare two revisions of a canon entry.

```
Options:
  -b, --book-dir DIR     # Book directory (required)
  --branch NAME          # Branch context (default: "main")
  --format FORMAT        # Output format: text (default), json

Output (text):
  Comparing kenji_yamamoto: Rev #1 → Rev #3

  backstory:
  - "A senior developer who..."
  + "A legendary senior developer who..."

  personality_traits:
  - ["meticulous", "patient"]
  + ["meticulous", "patient", "secretly competitive"]

Exit codes: 0 success, 1 entity/revision not found
```

### `book canon rollback <entity_type> <entity_id> <revision>`

Restore a canon entry to a previous revision.

```
Options:
  -b, --book-dir DIR     # Book directory (required)
  --branch NAME          # Branch context (default: "main")
  --reason TEXT           # Reason for rollback
  --auto                 # Skip confirmation prompt

Output:
  Rolled back character/kenji_yamamoto to revision #2
  New revision: #4 (rollback)
  Running impact analysis... done (3 items affected)
  Use `book canon impact --latest` to view the impact report.

Exit codes: 0 success, 1 entity/revision not found, 3 user cancelled
```

## Impact Analysis Commands

### `book canon impact`

View impact reports.

```
Options:
  -b, --book-dir DIR     # Book directory (required)
  --branch NAME          # Branch context (default: "main")
  --latest               # Show most recent report
  --report-id ID         # Show specific report
  --pending-only         # Show only items with pending review status
  --format FORMAT        # Output format: text (default), json

Output (text):
  Impact Report #2026-03-30-142200
  Trigger: character/kenji_yamamoto Rev #4

  HIGH: content/chapters/008.md
    Lines 45, 72: References old backstory
  MEDIUM: content/chapters/003.md
    Line 12: Mentions personality trait
  LOW: content/chapters/003.ru.md
    Line 12: Translation of affected passage

  Summary: 3 items (1 high, 1 medium, 1 low) | 3 pending review

Exit codes: 0 success, 1 no reports found
```

### `book canon impact review <report_id> <item_index> <status>`

Update review status of an affected item.

```
Arguments:
  report_id    # Report identifier
  item_index   # 1-based index of the affected item
  status       # reviewed, needs_update, deferred

Options:
  -b, --book-dir DIR     # Book directory (required)

Exit codes: 0 success, 1 report/item not found, 2 invalid status
```

## Branch Commands

### `book branch create <name>`

Create a new branch.

```
Options:
  -b, --book-dir DIR     # Book directory (required)
  --from BRANCH          # Parent branch (default: current branch or "main")
  --at-revision SEQ      # Branch from a specific historical revision point
  --description TEXT     # Purpose of this branch

Output:
  Created branch "what-if-kenji-quits" from main at revision #42
  Copied 15 characters, 7 locations, 23 facts, 8 relationships
  Switch to it with: book branch checkout what-if-kenji-quits

Exit codes: 0 success, 1 name already exists, 2 parent branch not found
```

### `book branch list`

List all branches.

```
Options:
  -b, --book-dir DIR     # Book directory (required)
  --all                  # Include archived branches
  --format FORMAT        # text (default), json

Output:
  * main (active)
    what-if-kenji-quits (active) ← main @rev42
    alternate-ending (archived) ← main @rev38

Exit codes: 0 success
```

### `book branch checkout <name>`

Switch active branch context.

```
Options:
  -b, --book-dir DIR     # Book directory (required)

Output:
  Switched to branch "what-if-kenji-quits"

Exit codes: 0 success, 1 branch not found, 2 branch is archived
```

### `book branch compare <branch1> <branch2>`

Compare two branches.

```
Options:
  -b, --book-dir DIR     # Book directory (required)
  --format FORMAT        # text (default), json

Output:
  Comparing "main" ↔ "what-if-kenji-quits"
  Common ancestor: main @rev42

  Only in main (3 changes):
    character/kenji_yamamoto: backstory updated
    location/server_room: status changed
    fact/standup-abolished: created

  Only in what-if-kenji-quits (2 changes):
    character/kenji_yamamoto: role changed to "retired"
    character/kai_nakamura: promoted to lead

  Conflicts (1):
    character/kenji_yamamoto.backstory: modified in both branches

Exit codes: 0 success, 1 branch not found
```

### `book branch merge <source> <target>`

Merge changes from source branch into target.

```
Options:
  -b, --book-dir DIR     # Book directory (required)
  --auto                 # Skip confirmation prompt
  --dry-run              # Show what would be merged without applying

Output (with conflicts):
  Merging "what-if-kenji-quits" → "main"

  Auto-merged: 2 changes
  Conflicts: 1

  Conflict 1: character/kenji_yamamoto.backstory
    OURS (main):   "A legendary senior developer..."
    THEIRS (what-if-kenji-quits): "A retired developer who..."

  Resolve with:
    book branch resolve 1 --keep-ours
    book branch resolve 1 --keep-theirs
    book branch resolve 1 --custom "A legendary but now retired..."

Exit codes: 0 success, 1 branch not found, 3 unresolved conflicts, 4 user cancelled
```

### `book branch archive <name>` / `book branch delete <name>`

Archive or delete a branch.

```
Options:
  -b, --book-dir DIR     # Book directory (required)
  --auto                 # Skip confirmation prompt

Exit codes: 0 success, 1 branch not found, 2 has active children, 3 user cancelled
```

## Changeset Commands

### `book changeset create`

Start a new batch changeset.

```
Options:
  -b, --book-dir DIR     # Book directory (required)
  --branch NAME          # Target branch (default: current)

Exit codes: 0 success, 1 active changeset already exists
```

### `book changeset add <operation> <entity_type> <entity_id> [field=value...]`

Add an operation to the active changeset.

```
Arguments:
  operation    # create, update, delete
  entity_type  # character, location, fact, relationship, plot_thread
  entity_id    # Target entity

Options:
  -b, --book-dir DIR     # Book directory (required)
  --reason TEXT           # Reason for this change

Exit codes: 0 success, 1 no active changeset, 2 entity not found (for update/delete)
```

### `book changeset preview`

Preview aggregate impact of the changeset.

```
Options:
  -b, --book-dir DIR     # Book directory (required)
  --format FORMAT        # text (default), json

Exit codes: 0 success (no conflicts), 1 no active changeset, 3 intra-batch conflicts detected
```

### `book changeset commit` / `book changeset discard`

Commit or discard the active changeset.

```
Options:
  -b, --book-dir DIR     # Book directory (required)
  --auto                 # Skip confirmation prompt
  --reason TEXT           # Overall changeset reason (commit only)

Exit codes: 0 success, 1 no active changeset, 3 unresolved conflicts (commit only)
```
