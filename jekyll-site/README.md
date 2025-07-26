# Book Generator Jekyll

A Jekyll-based static site generator adapter for the book-generator library. This package provides templates, layouts, and build scripts for creating beautiful book websites using Jekyll.

## Features

- **Beautiful Templates**: Pre-designed Jekyll layouts for books
- **Responsive Design**: Mobile-friendly book reading experience
- **Multi-language Support**: Built-in support for multiple languages via Jekyll Polyglot
- **Character Pages**: Automatic character profile generation
- **Chapter Navigation**: Seamless navigation between chapters
- **SEO Optimized**: Meta tags and structured data for better search visibility

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'book-generator-jekyll'
```

And then execute:

```bash
bundle install
```

## Quick Start

### 1. Initialize a New Book Site

```ruby
require 'book_generator/jekyll_adapter'

adapter = BookGenerator::JekyllAdapter.new
adapter.setup_project('./my-book-site')
```

### 2. Generate Content

```ruby
# Generate a chapter
adapter.write_chapter(1, chapter_content, {
  title: "Chapter 1: The Beginning",
  author: "AI Generated",
  date: Date.today
})

# Generate a character page
adapter.write_character({
  name: "Alex",
  role: "Senior Developer",
  personality: "Perfectionist, sarcastic",
  skills: ["Code review", "Architecture"]
})
```

### 3. Build the Site

```bash
cd my-book-site
bundle exec jekyll serve
```

Your book will be available at `http://localhost:4000`

## Site Structure

The Jekyll adapter creates the following structure:

```
my-book-site/
├── _chapters/           # Generated chapters
├── _characters/         # Generated character pages
├── _data/              # Book metadata and configuration
├── _layouts/           # Jekyll layouts
│   ├── default.html    # Base layout
│   ├── chapter.html    # Chapter layout
│   └── character.html  # Character profile layout
├── _includes/          # Reusable components
│   ├── chapter_nav.html
│   ├── character_card.html
│   └── character_mention.html
├── _sass/              # Stylesheets
├── assets/             # Images, CSS, JS
├── _config.yml         # Jekyll configuration
└── index.md           # Homepage
```

## Customization

### Layouts

Customize the appearance by editing the layout files:

- `_layouts/default.html` - Base template for all pages
- `_layouts/chapter.html` - Template for chapter pages
- `_layouts/character.html` - Template for character profiles

### Styling

Modify the styles in `_sass/` directory:

- `_variables.scss` - Color scheme and typography
- `main.scss` - Main stylesheet

### Configuration

Edit `_config.yml` to customize:

```yaml
title: Your Book Title
author: Your Name
description: Book description
url: "https://your-book-site.com"

# Multi-language support
languages: ["en", "ru"]
default_lang: "en"
exclude_from_localization: ["assets"]

# Jekyll Polyglot configuration
polyglot:
  default_lang: en
  langs: [en, ru]
  fallback_lang: en
```

## Integration with Book Generator Core

This package is designed to work seamlessly with the `book-generator` core library:

```ruby
require 'book_core/chapter_generator'
require 'book_generator/jekyll_adapter'

# Initialize core generator
generator = BookCore::ChapterGenerator.new(
  llm_service: llm_service,
  output_adapter: BookGenerator::JekyllAdapter.new
)

# Generate and output content
generator.generate_chapter(1)
```

## Multi-language Support

The adapter includes built-in support for multiple languages:

```ruby
# Generate content in different languages
adapter.write_chapter(1, en_content, { lang: 'en' })
adapter.write_chapter(1, ru_content, { lang: 'ru' })

# Character pages in multiple languages
adapter.write_character(en_character_data, { lang: 'en' })
adapter.write_character(ru_character_data, { lang: 'ru' })
```

## Deployment

### GitHub Pages

1. Push your site to a GitHub repository
2. Enable GitHub Pages in repository settings
3. Your book will be available at `https://username.github.io/repository-name`

### Netlify

1. Connect your repository to Netlify
2. Set build command: `bundle exec jekyll build`
3. Set publish directory: `_site`

### Custom Server

```bash
# Build the static site
bundle exec jekyll build

# Upload the _site directory to your web server
rsync -av _site/ user@server:/path/to/web/root/
```

## Development

### Local Development

```bash
bundle exec jekyll serve --livereload
```

### Testing

```bash
bundle exec rspec
```

## Themes and Templates

The adapter includes several built-in themes:

- **Default**: Clean, readable design
- **Academic**: Formal styling for academic works
- **Creative**: Artistic design for creative writing

Switch themes by modifying the `theme` setting in `_config.yml`.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## License

The gem is available as open source under the terms of the MIT License.
