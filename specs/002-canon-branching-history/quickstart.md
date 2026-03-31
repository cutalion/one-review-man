# Quickstart: Canon Branching and Change History

**Feature**: 002-canon-branching-history

## Prerequisites

- Ruby 3.3.5 installed
- `bundle install` in `book-generator/`
- An existing book directory (e.g., `books/one-review-man`)

## 1. Track Canon Changes

Every canon modification now creates a revision automatically.

```bash
# Update a character (revision is recorded)
book-generator/bin/book canon update character kenji_yamamoto \
  backstory="A legendary senior developer who reviews code with one glance" \
  --reason "Post chapter 8 character development" \
  -b books/one-review-man

# View revision history
book-generator/bin/book canon history character kenji_yamamoto \
  -b books/one-review-man

# Compare two revisions
book-generator/bin/book canon diff character kenji_yamamoto 1 3 \
  -b books/one-review-man

# Rollback to a previous revision
book-generator/bin/book canon rollback character kenji_yamamoto 2 \
  --reason "Chapter 8 rewrite cancelled" \
  -b books/one-review-man
```

## 2. View Impact Reports

Impact analysis runs automatically after every canon change.

```bash
# See the latest impact report
book-generator/bin/book canon impact --latest \
  -b books/one-review-man

# See only items pending review
book-generator/bin/book canon impact --pending-only \
  -b books/one-review-man

# Mark an item as reviewed
book-generator/bin/book canon impact review 2026-03-30-142200 1 reviewed \
  -b books/one-review-man
```

## 3. Branch a World

```bash
# Create a branch to explore an alternate storyline
book-generator/bin/book branch create what-if-kenji-quits \
  --description "Explore what happens if Kenji leaves HeroTech" \
  -b books/one-review-man

# Switch to the branch
book-generator/bin/book branch checkout what-if-kenji-quits \
  -b books/one-review-man

# Make changes on the branch (revisions tracked per branch)
book-generator/bin/book canon update character kenji_yamamoto \
  role="retired" --reason "Kenji quits in this timeline" \
  -b books/one-review-man

# Compare branches
book-generator/bin/book branch compare main what-if-kenji-quits \
  -b books/one-review-man

# Switch back
book-generator/bin/book branch checkout main \
  -b books/one-review-man
```

## 4. Merge Branches

```bash
# Merge changes from a branch back to main
book-generator/bin/book branch merge what-if-kenji-quits main \
  -b books/one-review-man

# If conflicts exist, resolve them
book-generator/bin/book branch resolve 1 --keep-theirs \
  -b books/one-review-man

# Archive the branch when done
book-generator/bin/book branch archive what-if-kenji-quits \
  -b books/one-review-man
```

## 5. Batch Changes with Changesets

```bash
# Start a changeset for related changes
book-generator/bin/book changeset create \
  -b books/one-review-man

# Queue multiple operations
book-generator/bin/book changeset add update character kenji_yamamoto \
  backstory="Now leads the architecture team" \
  --reason "Promotion arc" \
  -b books/one-review-man

book-generator/bin/book changeset add update character kai_nakamura \
  role="Senior Developer" \
  --reason "Takes over Kenji's old role" \
  -b books/one-review-man

# Preview the combined impact
book-generator/bin/book changeset preview \
  -b books/one-review-man

# Commit all changes atomically
book-generator/bin/book changeset commit \
  --reason "Chapter 11 character promotions" \
  -b books/one-review-man
```

## Verification

```bash
# Run tests
cd book-generator
MOCK_AI=true bundle exec rspec spec/revision_store_spec.rb \
  spec/impact_analyzer_spec.rb spec/branch_manager_spec.rb \
  spec/changeset_manager_spec.rb spec/diff_engine_spec.rb
```
