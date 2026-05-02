# One Review Man — AI‑generated programming comedy IP

A programming parody of *One‑Punch Man*, generated chapter‑by‑chapter with AI. Content is authored in English and translated to other languages (currently Russian).

This repository is a **monorepo** for the project:

- The **Eidos** gem: a Ruby engine + CLI for building and managing IP worlds ("storyworlds"). Eidos handles world management, canonical lore (Story Bible), canon versioning, content production, translation, and publishing.
- The **One Review Man** storyworld: the actual content (chapters, characters, comics) produced by Eidos.
- The generated **Jekyll site**: the public reading surface, built from the storyworld content.

Eidos is reusable — you can install it as a gem (`gem install eidos`) and use it for any storyworld, not just this one.

## Start here

- **[Pitch](docs/pitch.md)** — what Eidos is, who it's for, and what it isn't. Read first.
- **[Usage Guide](docs/usage-guide.md)** — every workflow end-to-end, organized by what you want to do.

## Project structure

```
one-review-man/
├── eidos/                     # 💎 Eidos gem (engine + CLI + SDK)
│   ├── lib/eidos/             # Engine + SDK (Eidos:: namespace)
│   ├── lib/eidos/cli/         # Thor-based CLI classes
│   ├── exe/eidos              # Unified `eidos` binary (installed by the gem)
│   ├── bin/{world,bible,canon,produce,translate,publish}
│   │                          # Domain-specific dev binaries (same commands,
│   │                          # split for convenience during development)
│   ├── templates/jekyll/      # Jekyll site template
│   └── spec/                  # RSpec tests
├── worlds/one-review-man/     # 🌍 The storyworld content
│   ├── content/               # Chapters, characters, comics (+ translations)
│   └── data/                  # world_config.yml, story_bible, settings.yml
└── site/                      # 📖 Generated Jekyll site
```

## Quick start (monorepo dev mode)

```bash
# Install Eidos dependencies
cd eidos
bundle install

# Generate the next chapter of One Review Man
MOCK_AI=true bin/produce chapter -w ../worlds/one-review-man --auto

# Or use the unified CLI
exe/eidos chapter list -w ../worlds/one-review-man
exe/eidos character show kenji_yamamoto -w ../worlds/one-review-man

# Run the full test suite (544 examples)
MOCK_AI=true bundle exec rspec
```

## Using Eidos as a gem (for your own storyworld)

```bash
gem install eidos
eidos --version    # eidos 0.2.0
eidos world new -w /path/to/my-world
```

From Ruby:

```ruby
require 'eidos'

Eidos.configure { |c| c.worlds_path = '/path/to/worlds' }

world = Eidos::World.new('my-world')
puts world.status[:title]
puts world.chapters.count
world.bible.characters.each { |c| puts "#{c.id}: #{c.name}" }
```

See `eidos/README.md` for the full SDK and CLI reference.

## CLI overview

All commands accept `-w` / `--world-dir` to point at a storyworld directory.

```bash
eidos world   ...   # Create, inspect, manage worlds
eidos bible   ...   # Manage the Story Bible (characters, locations, facts)
eidos canon   ...   # Canon versioning (snapshots, branches)
eidos produce ...   # Generate chapters, comics, illustrations
eidos translate ... # Translate content to other languages
eidos publish ...   # Build the Jekyll site
eidos chapter ...   # SDK-based chapter browsing (list, show)
eidos character ... # SDK-based character browsing (list, show, update)
eidos probe MODEL   # Cheap smoke-test for a provider/model (auth, reachability, latency)
eidos version       # Show the installed Eidos version
```

The `bin/<subcommand>` scripts inside `eidos/bin/` are equivalent to `eidos <subcommand>` and exist for monorepo dev convenience.

## Content workflow

1. **Generate** — `eidos produce chapter` writes `worlds/one-review-man/content/chapters/NNN-chapter.md` and updates the Story Bible with any new characters/locations.
2. **Translate** — `eidos translate all ru` writes `.ru.md` siblings, using a glossary built from existing character translations.
3. **Publish** — `eidos publish jekyll --dest site` assembles content into the Jekyll template. `cd site && bundle exec jekyll serve` runs it at http://localhost:4000.

## Development modes

- `MOCK_AI=true` — deterministic offline responses from `eidos/spec/support/mock_responses.yml`. Use for tests and local iteration without API calls.
- `DEBUG_AI=1` or `--debug` — write request/response artifacts to `tmp/ai_debug/`.

## LLM configuration

Per‑world config lives at `worlds/<name>/data/settings.yml`:

```yaml
llm:
  provider: openai
  model: gpt-4o-mini
  temperature: 0.7
  timeout: 240
  default_options:
    max_tokens: 12000
  task_options:
    generation:
      max_tokens: 8000
    translation:
      max_tokens: 12000
```

Provide `OPENAI_API_KEY` via the environment. `gpt-5*` / `o3*` model quirks (`max_completion_tokens`, temperature) are handled automatically.

## Universal AI engineering team (Phase 1)

This repo ships a project-agnostic multi-agent engineering team in `.claude/agents/team-*`, `.claude/skills/team-lead/`, and `.claude/commands/team.md`. To use it in any project:

1. `/team init` — scaffolds `.ai_team/charter.md` (per-repo state: goals, non-goals, authority, conventions).
2. `/team <task>` — runs the team in sync mode against a free-form task; produces a feature branch, tests, and a session log under `.ai_team/log/`.
3. `/team status` — prints current state and recent log entries.

The team has 7 specialist roles (analyst, planner, plan-critic, engineer, code-critic, qa, writer) coordinated by a lead orchestrator. See `docs/superpowers/specs/2026-05-01-ai-team-design.md` for the design and roadmap. Phases 2-4 add Linear integration, cron-driven autonomous mode, and escalation polish.

## Docker

```bash
docker compose build
docker compose up -d
```

## License

MIT.

— *One Review Man*: where AI meets programming parody, one perfect pull request at a time. 🤖📚💻⚡
