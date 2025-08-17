# One Review Man — AI‑generated programming comedy

A programming parody of “One‑Punch Man”, generated chapter‑by‑chapter with AI. Content is authored in English and translated to other languages (currently Russian). The project has been refactored into a modular, reusable monorepo with a dedicated generator CLI and a separate Jekyll site adapter.

## Project structure (monorepo)

```
one-review-man/
├── book-generator/          # 📚 Core library + CLI (bin/book)
│   ├── lib/book_core/       # Core generation/translation engine
│   └── bin/book             # CLI entrypoint (Thor)
├── book-generator/templates/
│   └── jekyll/              # Jekyll site template (layouts, includes, assets)
├── books/                   # 📖 Book content and per-book config
│   └── one-review-man/
│       ├── data/            # Book metadata, characters, logs
│       ├── content/
│       │   ├── chapters/    # English chapters + translations (*.ru.md)
│       │   └── characters/  # English character pages + translations
│       └── scripts/llm_config.yml  # Per-book LLM config
└── README.md
```

- No root‑level runtime “bin”. All commands go through `book-generator/bin/book`.
- Each book folder is self‑contained. You can create more books under `books/` and use the same generator.

## CLI (new canonical flow)

All commands accept `--book-dir` (or `-b`) to work from any current directory.

```bash
# Initialize a new (empty) book folder
book-generator/bin/book init here --path books/one-review-man

# Generate the next English chapter (set a model if needed)
book-generator/bin/book generate chapter \
  --model gpt-5 \
  --book-dir books/one-review-man

# Inspect the exact prompt used for the next (or specific) chapter
book-generator/bin/book generate prompt --book-dir books/one-review-man
book-generator/bin/book generate prompt 7 --book-dir books/one-review-man

# Translate everything to Russian
book-generator/bin/book translate all ru --book-dir books/one-review-man

# Prepare a Jekyll site with the current book content
book-generator/bin/book jekyll generate \
  --book-dir books/one-review-man \
  --dest books/one-review-man/site

# Build/serve the site (run inside the generated site directory)
cd books/one-review-man/site
bundle install
bundle exec jekyll serve
```

Tips:
- Use `MOCK_AI=true` for deterministic, offline runs (no API calls).
- Use `--debug` (or `DEBUG_AI=1`) to write request/response artifacts to `BOOK_DIR/tmp/ai_debug/`.

## LLM configuration

Per‑book config lives at `BOOK_DIR/scripts/llm_config.yml`. Example keys:

```yaml
provider: openai
model: gpt-4o-mini
temperature: 0.7
openai_base_url: "https://api.openai.com/v1" # optional
openai_api_key: "env-or-placeholder"         # typically use ENV OPENAI_API_KEY
default_options:
  max_tokens: 12000
task_options:
  generation:
    max_tokens: 8000
  translation:
    max_tokens: 12000
```

Model compatibility helpers:
- `gpt-5*`/`o3*` use `max_completion_tokens` instead of `max_tokens` and may ignore `temperature`.
- The generator handles these automatically and retries on specific API errors.

## Content workflow

1) Generate English chapter
- Uses `book-generator/lib/book_core/chapter_generator.rb` with rich prompts from `book-generator/lib/book_core/prompts/`.
- Writes to `BOOK_DIR/content/chapters/NNN-chapter.md` and updates `data/book_metadata.yml`.
- If new characters appear, profiles are generated and saved to `data/characters.yml` and `content/characters/`.

2) Translate
- Translates chapters and characters (e.g., to Russian) and writes `.ru.md` files alongside English ones.
- Glossary is auto‑built from existing character translations for name consistency.

3) Build site
- `book jekyll generate` copies the book content and template into a site folder.
- Build locally with Bundler/Jekyll and deploy (including GitHub Pages).

## Debugging

- Show the effective prompt without calling the API:
  - `book-generator/bin/book generate prompt [NUMBER] --book-dir BOOK_DIR`
- Enable debug artifacts for real API calls:
  - `--debug` flag (or `DEBUG_AI=1` env)
  - Files: `tmp/ai_debug/request_parameters.json`, `response_raw.json`, `chapter_generation_raw*.json`
- Offline mode:
  - `MOCK_AI=true` disables API calls and produces deterministic content for tests.

## Development

Core library:
```bash
cd book-generator
bundle exec rspec
```

## License

MIT

— “One Review Man”: where AI meets programming parody, one perfect pull request at a time. 🤖📚💻⚡
