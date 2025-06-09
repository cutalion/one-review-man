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
Shared technical metadata with language-specific content:
```yaml
---
# Shared technical metadata (language-independent)
book:
  target_chapters: 50
  current_chapter: 0
generation:
  chapter_length_target: '1500-3000 words'
  complexity_level: 'medium'
  character_consistency: true
status:
  last_generated: null
  generation_count: 0
  characters_created: 0
  active_storylines: []
  chapters_written: 0

# Language-specific content only
localized:
  en:
    title: "One Review Man"
    subtitle: "An AI-Generated Comedy of Errors"
    author: "AI Collective"
    genre: "Humor/Comedy"
    humor_style: "absurdist"
    themes:
      primary: "workplace comedy"
      secondary: ["mistaken identity", "bureaucratic absurdity"]
  ru:
    title: "Ванревьюмэн"
    subtitle: "ИИ-генерируемая Комедия Ошибок"
    # ... other translated content
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
# These work with English by default - returns merged shared + localized data
characters = load_characters()    # Gets en.characters
book_data = load_book_data()      # Gets shared data + en localized content
save_characters(data)             # Saves to en.characters
save_book_data(data)              # Saves shared data + en localized content
```

### Translation Scripts (Multi-language)
```ruby
# These work with specific languages - returns merged shared + localized data
source_chars = load_characters('en')        # Gets en.characters
target_chars = load_characters('ru')        # Gets ru.characters
book_data_en = load_book_data('en')         # Gets shared + en localized
book_data_ru = load_book_data('ru')         # Gets shared + ru localized
save_characters(data, 'ru')                 # Saves to ru.characters
save_book_data(data, 'ru')                  # Saves to ru localized section
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
