# One Review Man - AI Generated Programming Comedy

A programming parody of "One-Punch Man" generated chapter by chapter using AI. Built with Jekyll and designed for GitHub Pages with multilingual support (English and Russian).

## Project Overview

This is a humorous programming book that parodies the popular manga/anime "[One-Punch Man](https://en.wikipedia.org/wiki/One-Punch_Man)" in a tech workplace setting. Just as [Saitama](https://en.wikipedia.org/wiki/Saitama_(One-Punch_Man)) can defeat any enemy with one punch, **One Review Man** is a super-programmer who writes perfect code that passes every code review on the first try.

### The Parody Concept

- **One Review Man**: The protagonist, master programmer (parody of Saitama)
  - Writes flawless code that never needs revisions
  - All pull requests are instantly approved and merged
  - Has become bored with his overwhelming programming abilities
  
- **The AI-Enhanced Disciple**: A cyborg-like character with neurointerface (parody of Genos)
  - Connected to AI systems to enhance coding abilities
  - Desperately seeks to learn One Review Man's secrets
  - Still cannot achieve the master's level despite technological augmentation

**All content is created in English first**, then translated to other languages to ensure story consistency and character coherence across all language versions.

## Multilingual Approach

- **Primary Language**: English (where all content is generated)
- **Translations**: Russian (and potentially others)
- **Story Consistency**: Same plot, characters, and relationships across all languages
- **Workflow**: Generate → Translate → Sync

## Project Structure

```
one-review-man/
├── _config.yml              # Jekyll configuration with multilingual support
├── _data/                   # Data files
│   ├── characters.en.yml    # English character database
│   ├── characters.ru.yml    # Russian character translations
│   ├── book_metadata.en.yml # English book settings
│   ├── book_metadata.ru.yml # Russian book settings
│   ├── strings.yml          # UI translations
│   └── generation_log.yml   # Generation tracking
├── _layouts/                # Jekyll layouts
│   ├── chapter.html         # Chapter page layout
│   └── character.html       # Character profile layout
├── _includes/               # Reusable components
│   ├── character_card.html  # Character display card
│   ├── character_mention.html # Inline character links
│   └── chapter_nav.html     # Chapter navigation
├── _chapters/               # Generated chapters
│   ├── 001-chapter-1.md     # English chapters
│   └── 001-chapter-1.ru.md  # Russian translations
├── _characters/             # Character profile pages
│   ├── protagonist.md       # English character pages
│   └── protagonist.ru.md    # Russian character pages
├── scripts/                 # Ruby generation and management scripts
│   ├── generate_chapter.rb  # Chapter generation (English only)
│   ├── manage_characters.rb # Character management (English primary)
│   ├── translate_content.rb # Translation tool
│   ├── book_utils.rb        # Shared utilities
│   └── prompts/             # AI prompt templates
├── index.md                 # English landing page
├── index.ru.md              # Russian landing page
├── chapters.md              # English chapter index
└── characters.md            # English character index
```

## Getting Started

### Prerequisites

- Ruby (for Jekyll and scripts)
- Jekyll (`gem install jekyll bundler`)

### Setup

1. Clone this repository
2. Install dependencies:
   ```bash
   bundle install
   ```

3. Start Jekyll development server:
   ```bash
   bundle exec jekyll serve
   ```

4. Open http://localhost:4000 for English or http://localhost:4000/ru for Russian

## Content Creation Workflow

### 1. Create Content in English

#### Generate a New Chapter
```bash
# Generate next chapter structure and prompt
ruby scripts/generate_chapter.rb next

# Regenerate prompt for existing chapter
ruby scripts/generate_chapter.rb prompt 1
```

#### Create Characters
```bash
# Add new character interactively (English only)
ruby scripts/manage_characters.rb add

# List all characters with translation status
ruby scripts/manage_characters.rb list

# Show character details
ruby scripts/manage_characters.rb show character_slug
```

### 2. Translate to Other Languages

#### Translate Characters
```bash
# Translate specific character
ruby scripts/translate_content.rb character protagonist ru

# Translate all characters at once
ruby scripts/translate_content.rb all-characters ru
```

#### Translate Chapters
```bash
# Translate specific chapter
ruby scripts/translate_content.rb chapter 1 ru
```

#### Check Translation Status
```bash
# See what's translated and what's missing
ruby scripts/translate_content.rb status ru
```

### 3. Sync Metadata Across Languages
```bash
# Sync chapter metadata (character appearances, etc.)
ruby scripts/translate_content.rb sync 1 ru

# Sync character metadata across languages
ruby scripts/manage_characters.rb sync protagonist
```

## Content Guidelines

### Chapter Creation
1. **Generate structure**: `ruby scripts/generate_chapter.rb next`
2. **Get AI prompt**: Copy the generated prompt to your AI (includes One-Punch Man parody context)
3. **Add content**: Edit the chapter file with AI-generated programming comedy content
4. **Update metadata**: Fill in title, summary, new characters
5. **Translate**: Use translation script for other languages

### Character Development
- Create programmer archetypes with distinct coding styles and personalities
- Reference One-Punch Man character dynamics adapted to programming context
- Include consistent programming abilities and quirks across all appearances
- Translate personality while maintaining programming expertise and relationships
- Sync coding skill levels and character relationships across all languages

### Programming Comedy Themes
- Code review scenarios (One Review Man's code is always perfect)
- Debugging disasters and production emergencies
- Framework wars and technology adoption
- Pair programming dynamics and mentorship
- Tech company culture absurdities
- Open source contribution drama
- Legacy code archaeology and technical debt
- Conference presentations and tech talks

## Multilingual Features

### Automatic Language Detection
- URLs: `/` (English) vs `/ru/` (Russian)
- Content filtering by language
- Language switcher on all pages

### Translation Management
- Preserves story structure and relationships
- Maintains character consistency
- Syncs metadata automatically
- Tracks translation status

### Supported Languages
- **English** (en) - Primary
- **Russian** (ru) - Translation
- Easily extensible to other languages

## AI Integration

The project is designed to work with AI generation:

1. **Structured Prompts**: Templates with context about previous chapters and characters
2. **Context Management**: Scripts provide relevant story context
3. **Consistency Tracking**: Generation log prevents repetitive plots
4. **Character Relationships**: Automatically maintained across languages

## Deployment

This project works with GitHub Pages:

1. Push to a GitHub repository
2. Enable GitHub Pages in repository settings
3. Site available at `https://username.github.io/repository-name`
4. Language versions: `https://username.github.io/repository-name/ru/`

## Example Workflow

```bash
# 1. Create your first character (the AI-Enhanced Disciple)
ruby scripts/manage_characters.rb add
# Enter: "Genos-9000", "Cyborg programmer with neurointerface seeking to learn from One Review Man", "persistent, analytical, technology-obsessed"

# 2. Generate first chapter
ruby scripts/generate_chapter.rb next
# Copy prompt (includes One-Punch Man parody context), generate with AI, paste content into chapter file

# 3. Translate character to Russian
ruby scripts/translate_content.rb character genos_9000 ru
# Enter: "Генос-9000", "Программист-киборг с нейроинтерфейсом, стремящийся учиться у One Review Man", etc.

# 4. Translate chapter to Russian
ruby scripts/translate_content.rb chapter 1 ru
# Enter translated title, summary, and content

# 5. Check status
ruby scripts/translate_content.rb status ru
```

## Key Benefits

### ✅ Story Consistency
- Same plot and character development across all languages
- Relationships and timeline remain identical
- No divergent storylines

### ✅ Translation Efficiency
- Translate once, maintain everywhere
- Metadata syncing across languages
- Clear tracking of what needs translation

### ✅ Scalable
- Easy to add new languages
- Automated cross-language linking
- Consistent file naming and structure

### ✅ SEO Friendly
- Clean URLs for each language
- Proper language tags
- Search engine friendly structure

## Contributing

This is a personal humor book project, but suggestions for improvements to the multilingual system are welcome!

## License

This project is available under MIT license.

---

*"One Review Man" - Where AI meets programming parody, one perfect pull request at a time. Now in multiple languages with perfect consistency!* 🤖📚💻⚡
