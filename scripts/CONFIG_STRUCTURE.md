# Configuration Structure

This project uses a unified configuration system that supports both content generation and translation in a DRY way.

## Files

### `_data/characters.yml`
Language-structured character data:
```yaml
---
en:
  characters:
    character_slug:
      name: "Character Name"
      description: "Description..."
      # ... other fields
ru:
  characters:
    character_slug:
      name: "Translated Name"
      description: "Translated description..."
      # ... other fields
```

### `_data/book_metadata.yml`
Language-structured book metadata:
```yaml
---
en:
  book:
    title: "One Review Man"
    # ... other metadata
  generation:
    # ... generation settings
  themes:
    # ... theme data
  status:
    # ... status tracking
ru:
  book:
    title: "Ванревьюмэн"
    # ... translated metadata
  # ... other sections
```

### `_data/strings.yml`
UI/template strings for different languages:
```yaml
---
en:
  site_title: "One Review Man"
  # ... other UI strings
ru:
  site_title: "Ванревьюмэн"
  # ... translated UI strings
```

## Usage

### Generation Scripts (English content)
```ruby
# These work with English by default
characters = load_characters()    # Gets en.characters
book_data = load_book_data()      # Gets en section
save_characters(data)             # Saves to en.characters
save_book_data(data)              # Saves to en section
```

### Translation Scripts (Multi-language)
```ruby
# These work with specific languages
source_chars = load_characters('en')        # Gets en.characters
target_chars = load_characters('ru')        # Gets ru.characters
save_characters(data, 'ru')                 # Saves to ru.characters
save_book_data(data, 'ru')                  # Saves to ru section
```

## Development Tools

### Book Reset Tool (`scripts/reset_book.rb`)
Clean up and reset book content for development/testing:

```bash
# Check current status
ruby scripts/reset_book.rb status

# Reset only characters (interactive)
ruby scripts/reset_book.rb characters

# Reset only chapters (interactive)
ruby scripts/reset_book.rb chapters

# Reset only data files (no prompt)
ruby scripts/reset_book.rb data

# Clean generated site files
ruby scripts/reset_book.rb site

# Full reset (interactive)
ruby scripts/reset_book.rb all

# Full reset (no prompts)
ruby scripts/reset_book.rb all --force

# Force reset characters (no prompt)
ruby scripts/reset_book.rb characters --force
```

## Benefits

1. **DRY**: Single source files, no duplication
2. **Consistent**: Both generation and translation scripts work
3. **Simple**: English generation doesn't need to think about languages
4. **Flexible**: Easy to add new languages
5. **Maintainable**: All configuration in `_data/` directory
6. **Safe Development**: Reset tools for easy cleanup

## Migration

If you have existing simple structure files, they can be automatically migrated:
- The `book_utils.rb` will handle both old and new formats
- Use the sync script pattern to migrate existing character files to the YAML structure 
