# Eidos SDK & Installable CLI — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Eidos an installable Ruby gem with a unified `eidos` CLI and a public OOP SDK usable from Rails apps.

**Architecture:** Three layers — Engine (existing internals) wrapped by SDK (domain objects like `Eidos::World`, `Eidos::Chapter`, `Eidos::Character`) consumed by CLI (thin Thor commands). SDK is storage-agnostic with immediate persistence. CLI is a single `eidos` binary with flat entity-first subcommands.

**Tech Stack:** Ruby 3.3+, Thor 1.3, ruby-openai 7.3, RSpec

**Spec:** `docs/superpowers/specs/2026-04-16-eidos-sdk-and-installable-cli-design.md`

---

## Phase 1: Plumbing (installable gem, no behavior change)

### Task 1: Unify version to `Eidos::VERSION`

**Files:**
- Create: `eidos/lib/eidos/version.rb`
- Modify: `eidos/eidos.gemspec`
- Modify: `eidos/lib/eidos.rb`
- Delete content from: `eidos/lib/eidos/cli/version.rb` (keep file, delegate)

- [ ] **Step 1: Write the test for Eidos::VERSION**

```ruby
# eidos/spec/eidos/version_spec.rb
# frozen_string_literal: true

require 'eidos/version'

RSpec.describe 'Eidos::VERSION' do
  it 'is a string in semver format' do
    expect(Eidos::VERSION).to match(/\A\d+\.\d+\.\d+\z/)
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd eidos && bundle exec rspec spec/eidos/version_spec.rb -v`
Expected: FAIL — `Eidos::VERSION` is not defined (only `Eidos::CLI::VERSION` exists)

- [ ] **Step 3: Create `lib/eidos/version.rb`**

```ruby
# eidos/lib/eidos/version.rb
# frozen_string_literal: true

module Eidos
  VERSION = '0.2.0'
end
```

- [ ] **Step 4: Update `lib/eidos.rb` to require version**

```ruby
# eidos/lib/eidos.rb
# frozen_string_literal: true

require_relative 'eidos/version'

# Eidos - IP World Engine
# Main entry point for the Eidos gem
module Eidos
end
```

- [ ] **Step 5: Update `lib/eidos/cli/version.rb` to delegate**

```ruby
# eidos/lib/eidos/cli/version.rb
# frozen_string_literal: true

require_relative '../version'

module Eidos
  module CLI
    VERSION = Eidos::VERSION
  end
end
```

- [ ] **Step 6: Update gemspec to use `Eidos::VERSION`**

In `eidos/eidos.gemspec`, replace the hardcoded version:

```ruby
# eidos/eidos.gemspec
# frozen_string_literal: true

require_relative 'lib/eidos/version'

Gem::Specification.new do |spec|
  spec.name          = 'eidos'
  spec.version       = Eidos::VERSION
  # ... rest unchanged
end
```

- [ ] **Step 7: Run all tests**

Run: `cd eidos && bundle exec rspec`
Expected: All 508+ tests pass, including the new version spec.

- [ ] **Step 8: Commit**

```bash
cd eidos
git add lib/eidos/version.rb spec/eidos/version_spec.rb lib/eidos.rb lib/eidos/cli/version.rb eidos.gemspec
git commit -m "feat: unify version to Eidos::VERSION (0.2.0)"
```

---

### Task 2: Create `exe/eidos` unified entry point

**Files:**
- Create: `eidos/exe/eidos`
- Modify: `eidos/eidos.gemspec`

- [ ] **Step 1: Create `exe/eidos` that routes to existing CLI classes**

```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true

lib_dir = File.expand_path('../lib', __dir__)
$LOAD_PATH.unshift(lib_dir) unless $LOAD_PATH.include?(lib_dir)

require 'thor'
require 'eidos/cli/world'
require 'eidos/cli/bible'
require 'eidos/cli/canon'
require 'eidos/cli/produce'
require 'eidos/cli/translate'
require 'eidos/cli/publish'
require 'eidos/version'

module Eidos
  module CLI
    # Top-level CLI router. Delegates to existing subcommand classes.
    class Main < Thor
      desc 'world SUBCOMMAND ...ARGS', 'Manage worlds'
      subcommand 'world', Eidos::CLI::World

      desc 'bible SUBCOMMAND ...ARGS', 'Manage the Story Bible'
      subcommand 'bible', Eidos::CLI::Bible

      desc 'canon SUBCOMMAND ...ARGS', 'Manage canon versioning'
      subcommand 'canon', Eidos::CLI::Canon

      desc 'produce SUBCOMMAND ...ARGS', 'Generate content'
      subcommand 'produce', Eidos::CLI::Produce

      desc 'translate SUBCOMMAND ...ARGS', 'Translate content'
      subcommand 'translate', Eidos::CLI::Translate

      desc 'publish SUBCOMMAND ...ARGS', 'Publish content'
      subcommand 'publish', Eidos::CLI::Publish

      desc 'version', 'Show version'
      def version
        puts "eidos #{Eidos::VERSION}"
      end

      map %w[--version -v] => :version
    end
  end
end

Eidos::CLI::Main.start(ARGV)
```

- [ ] **Step 2: Make it executable**

Run: `chmod +x eidos/exe/eidos`

- [ ] **Step 3: Test it manually**

Run: `cd eidos && exe/eidos version`
Expected: `eidos 0.2.0`

Run: `cd eidos && exe/eidos world status -w ../worlds/one-review-man`
Expected: World status report (same as `bin/world status`)

- [ ] **Step 4: Update gemspec to use `exe/` as bindir**

In `eidos/eidos.gemspec`, change the bindir and executables:

Replace:
```ruby
  spec.files = Dir.glob(%w[
                          lib/**/*.rb
                          templates/**/*
                          bin/*
                          LICENSE.txt
                          README.md
                        ], File::FNM_DOTMATCH).reject { |f| File.directory?(f) }

  spec.bindir        = 'bin'
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
```

With:
```ruby
  spec.files = Dir.glob(%w[
                          lib/**/*.rb
                          templates/**/*
                          exe/*
                          LICENSE.txt
                          README.md
                        ], File::FNM_DOTMATCH).reject { |f| File.directory?(f) }

  spec.bindir        = 'exe'
  spec.executables   = ['eidos']
```

- [ ] **Step 5: Verify gem builds**

Run: `cd eidos && gem build eidos.gemspec`
Expected: `Successfully built RubyGem` with `eidos-0.2.0.gem` created. Verify it lists `exe/eidos` as executable.

Run: `rm eidos-0.2.0.gem` (cleanup)

- [ ] **Step 6: Run all tests**

Run: `cd eidos && bundle exec rspec`
Expected: All tests pass (bin/ scripts still work, exe/eidos is additive).

- [ ] **Step 7: Commit**

```bash
cd eidos
git add exe/eidos eidos.gemspec
git commit -m "feat: add unified exe/eidos CLI entry point"
```

---

### Task 3: Add `Eidos::Configuration` (global configure block)

**Files:**
- Create: `eidos/lib/eidos/config.rb` — note: `configuration.rb` already exists and is the per-project config loader. This new file is the global SDK config.
- Modify: `eidos/lib/eidos.rb`
- Test: `eidos/spec/eidos/config_spec.rb` — note: `config_spec.rb` already exists but tests the old `Eidos::Config` module. We need to check what's there first.

Actually, let me check what `eidos/lib/eidos/config.rb` currently contains.

**Files:**
- Modify: `eidos/lib/eidos/config.rb` (currently exists — will be repurposed or extended)
- Modify: `eidos/lib/eidos.rb`
- Create: `eidos/spec/eidos/sdk_configuration_spec.rb`

- [ ] **Step 1: Read the existing `config.rb` to understand current usage**

Run: `cat eidos/lib/eidos/config.rb`

This step is for the implementor — read the file and understand what `Eidos::Config` currently does before modifying.

- [ ] **Step 2: Write the test**

```ruby
# eidos/spec/eidos/sdk_configuration_spec.rb
# frozen_string_literal: true

require 'eidos'

RSpec.describe Eidos do
  after { Eidos.reset_configuration! }

  describe '.configure' do
    it 'yields a configuration object' do
      Eidos.configure do |c|
        c.worlds_path = '/tmp/my-worlds'
      end

      expect(Eidos.configuration.worlds_path).to eq('/tmp/my-worlds')
    end

    it 'has a default worlds_path of ./worlds' do
      expect(Eidos.configuration.worlds_path).to eq('./worlds')
    end

    it 'has a default storage_backend of :yaml_file' do
      expect(Eidos.configuration.storage_backend).to eq(:yaml_file)
    end
  end

  describe '.reset_configuration!' do
    it 'restores defaults' do
      Eidos.configure { |c| c.worlds_path = '/custom' }
      Eidos.reset_configuration!
      expect(Eidos.configuration.worlds_path).to eq('./worlds')
    end
  end
end
```

- [ ] **Step 3: Run test to verify it fails**

Run: `cd eidos && bundle exec rspec spec/eidos/sdk_configuration_spec.rb -v`
Expected: FAIL — `Eidos.configure` is not defined.

- [ ] **Step 4: Create `Eidos::SdkConfiguration` and wire up `Eidos.configure`**

```ruby
# eidos/lib/eidos/sdk_configuration.rb
# frozen_string_literal: true

module Eidos
  # Global SDK configuration. Set via Eidos.configure block.
  # This is separate from Eidos::Configuration which handles per-project settings merging.
  class SdkConfiguration
    attr_accessor :worlds_path, :storage_backend

    def initialize
      reset!
    end

    def reset!
      @worlds_path = './worlds'
      @storage_backend = :yaml_file
    end
  end
end
```

- [ ] **Step 5: Update `lib/eidos.rb` to wire up `.configure`**

```ruby
# eidos/lib/eidos.rb
# frozen_string_literal: true

require_relative 'eidos/version'
require_relative 'eidos/sdk_configuration'

# Eidos - IP World Engine
# Main entry point for the Eidos gem
module Eidos
  class << self
    def configuration
      @configuration ||= SdkConfiguration.new
    end

    def configure
      yield(configuration)
    end

    def reset_configuration!
      @configuration = SdkConfiguration.new
    end
  end
end
```

- [ ] **Step 6: Run the new test**

Run: `cd eidos && bundle exec rspec spec/eidos/sdk_configuration_spec.rb -v`
Expected: All pass.

- [ ] **Step 7: Run all tests**

Run: `cd eidos && bundle exec rspec`
Expected: All 508+ tests pass. The new module-level methods are additive and don't break anything.

- [ ] **Step 8: Commit**

```bash
cd eidos
git add lib/eidos/sdk_configuration.rb lib/eidos.rb spec/eidos/sdk_configuration_spec.rb
git commit -m "feat: add Eidos.configure for global SDK configuration"
```

---

## Phase 2: Domain Objects (SDK facade)

### Task 4: `Eidos::World` — root SDK object

**Files:**
- Create: `eidos/lib/eidos/world.rb`
- Create: `eidos/spec/eidos/world_spec.rb`
- Modify: `eidos/lib/eidos.rb` (add require)

- [ ] **Step 1: Write the test**

```ruby
# eidos/spec/eidos/world_spec.rb
# frozen_string_literal: true

require 'eidos'
require 'eidos/world'
require 'tmpdir'
require 'fileutils'
require 'yaml'

RSpec.describe Eidos::World do
  around do |example|
    Dir.mktmpdir do |tmpdir|
      @worlds_path = tmpdir
      @world_dir = File.join(tmpdir, 'test-world')
      setup_test_world(@world_dir)
      Eidos.configure { |c| c.worlds_path = tmpdir }
      example.run
      Eidos.reset_configuration!
    end
  end

  def setup_test_world(dir)
    FileUtils.mkdir_p(File.join(dir, 'data'))
    FileUtils.mkdir_p(File.join(dir, 'content', 'chapters'))

    File.write(File.join(dir, 'data', 'world_config.yml'), {
      'localized' => {
        'en' => {
          'title' => 'Test World',
          'author' => 'Test Author',
          'genre' => 'comedy'
        }
      }
    }.to_yaml)

    File.write(File.join(dir, 'data', 'world_state.yml'), {
      'world' => { 'current_chapter' => 3 }
    }.to_yaml)

    # Create two chapter files
    [1, 2, 3].each do |n|
      File.write(
        File.join(dir, 'content', 'chapters', format('%03d-chapter.md', n)),
        "---\ntitle: Chapter #{n}\nchapter_number: #{n}\n---\nContent of chapter #{n}."
      )
    end
  end

  describe '.new with name' do
    it 'finds a world by name in worlds_path' do
      world = Eidos::World.new('test-world')
      expect(world.name).to eq('test-world')
    end

    it 'raises if world not found' do
      expect { Eidos::World.new('nonexistent') }.to raise_error(Eidos::WorldNotFoundError)
    end
  end

  describe '.new with explicit path' do
    it 'accepts a full path' do
      world = Eidos::World.new(@world_dir)
      expect(world.name).to eq('test-world')
    end
  end

  describe '#status' do
    it 'returns a hash with world stats' do
      world = Eidos::World.new('test-world')
      status = world.status
      expect(status[:title]).to eq('Test World')
      expect(status[:author]).to eq('Test Author')
      expect(status[:chapters]).to eq(3)
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd eidos && bundle exec rspec spec/eidos/world_spec.rb -v`
Expected: FAIL — `Eidos::World` is not defined.

- [ ] **Step 3: Implement `Eidos::World`**

```ruby
# eidos/lib/eidos/world.rb
# frozen_string_literal: true

require_relative 'world_config'

module Eidos
  class WorldNotFoundError < StandardError; end

  # Root SDK object. Entry point for all world operations.
  # Wraps the existing engine classes behind a clean public API.
  class World
    attr_reader :path, :name

    def initialize(name_or_path = nil)
      @path = resolve_path(name_or_path)
      @name = File.basename(@path)
      @world_config = WorldConfig.load_from_project(@path)
    end

    def status
      chapters_dir = File.join(@path, 'content', 'chapters')
      chapter_count = if Dir.exist?(chapters_dir)
                        Dir.glob(File.join(chapters_dir, '???-chapter.md')).length
                      else
                        0
                      end

      {
        title: @world_config.title,
        author: @world_config.author,
        genre: @world_config.genre,
        chapters: chapter_count,
        current_chapter: @world_config.current_chapter
      }
    end

    private

    def resolve_path(name_or_path)
      return detect_from_cwd if name_or_path.nil?

      # Explicit full path
      expanded = File.expand_path(name_or_path)
      return expanded if world_dir?(expanded)

      # Treat as a name — search worlds_path, then ~/.eidos/worlds/
      search_paths = [
        File.expand_path(File.join(Eidos.configuration.worlds_path, name_or_path)),
        File.expand_path(File.join('~/.eidos/worlds', name_or_path))
      ]

      found = search_paths.find { |p| world_dir?(p) }
      return found if found

      raise WorldNotFoundError, "World '#{name_or_path}' not found. Searched: #{search_paths.join(', ')}"
    end

    def detect_from_cwd
      dir = Dir.pwd
      return dir if world_dir?(dir)

      raise WorldNotFoundError,
            'Not in a world directory (missing data/world_config.yml). Pass a world name or path.'
    end

    def world_dir?(dir)
      return false unless Dir.exist?(dir)

      %w[world_config.yml world_metadata.yml].any? do |marker|
        File.exist?(File.join(dir, 'data', marker))
      end
    end
  end
end
```

- [ ] **Step 4: Add require to `lib/eidos.rb`**

Add after the existing requires in `lib/eidos.rb`:

```ruby
require_relative 'eidos/world'
```

- [ ] **Step 5: Run the new test**

Run: `cd eidos && bundle exec rspec spec/eidos/world_spec.rb -v`
Expected: All pass.

- [ ] **Step 6: Run all tests**

Run: `cd eidos && bundle exec rspec`
Expected: All tests pass.

- [ ] **Step 7: Commit**

```bash
cd eidos
git add lib/eidos/world.rb spec/eidos/world_spec.rb lib/eidos.rb
git commit -m "feat: add Eidos::World root SDK object"
```

---

### Task 5: `Eidos::Chapter` and `Eidos::ChapterCollection`

**Files:**
- Create: `eidos/lib/eidos/chapter.rb`
- Create: `eidos/lib/eidos/chapter_collection.rb`
- Create: `eidos/spec/eidos/chapter_spec.rb`
- Create: `eidos/spec/eidos/chapter_collection_spec.rb`
- Modify: `eidos/lib/eidos/world.rb` (add `#chapters`)

- [ ] **Step 1: Write the test for Chapter**

```ruby
# eidos/spec/eidos/chapter_spec.rb
# frozen_string_literal: true

require 'eidos/chapter'

RSpec.describe Eidos::Chapter do
  let(:chapter) do
    Eidos::Chapter.new(
      chapter_number: 1,
      title: 'The Code Review',
      content: "---\ntitle: The Code Review\n---\nOnce upon a time in a codebase far away.",
      summary: 'A hero appears',
      characters: %w[kenji kai],
      path: '/tmp/001-chapter.md'
    )
  end

  it 'exposes attributes' do
    expect(chapter.chapter_number).to eq(1)
    expect(chapter.title).to eq('The Code Review')
    expect(chapter.summary).to eq('A hero appears')
    expect(chapter.characters).to eq(%w[kenji kai])
  end

  it 'returns content body' do
    expect(chapter.content).to include('Once upon a time')
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd eidos && bundle exec rspec spec/eidos/chapter_spec.rb -v`
Expected: FAIL — `Eidos::Chapter` not defined.

- [ ] **Step 3: Implement `Eidos::Chapter`**

```ruby
# eidos/lib/eidos/chapter.rb
# frozen_string_literal: true

module Eidos
  # Represents a single chapter in a world.
  # Read from markdown files with YAML front matter.
  class Chapter
    attr_reader :chapter_number, :title, :content, :summary, :characters, :path

    def initialize(chapter_number:, title:, content:, summary: nil, characters: [], path: nil)
      @chapter_number = chapter_number
      @title = title
      @content = content
      @summary = summary
      @characters = characters
      @path = path
    end

    # Parse a chapter from a markdown file with YAML front matter.
    def self.from_file(file_path)
      raw = File.read(file_path)
      front_matter, body = parse_front_matter(raw)

      new(
        chapter_number: front_matter['chapter_number'] || extract_number_from_path(file_path),
        title: front_matter['title'] || 'Untitled',
        content: body,
        summary: front_matter['summary'],
        characters: front_matter['characters'] || [],
        path: file_path
      )
    end

    def self.parse_front_matter(raw)
      if raw.start_with?("---\n")
        parts = raw.split("---\n", 3)
        if parts.length >= 3
          front_matter = YAML.safe_load(parts[1]) || {}
          body = parts[2].strip
          return [front_matter, body]
        end
      end
      [{}, raw.strip]
    end

    def self.extract_number_from_path(path)
      basename = File.basename(path)
      match = basename.match(/^(\d{3})-chapter/)
      match ? match[1].to_i : 0
    end

    def translations
      @translations ||= {}
    end
  end
end
```

- [ ] **Step 4: Run the chapter test**

Run: `cd eidos && bundle exec rspec spec/eidos/chapter_spec.rb -v`
Expected: All pass.

- [ ] **Step 5: Write the test for ChapterCollection**

```ruby
# eidos/spec/eidos/chapter_collection_spec.rb
# frozen_string_literal: true

require 'eidos/chapter_collection'
require 'tmpdir'
require 'fileutils'

RSpec.describe Eidos::ChapterCollection do
  around do |example|
    Dir.mktmpdir do |tmpdir|
      @chapters_dir = File.join(tmpdir, 'content', 'chapters')
      FileUtils.mkdir_p(@chapters_dir)

      # Create 3 chapters
      [1, 2, 3].each do |n|
        File.write(
          File.join(@chapters_dir, format('%03d-chapter.md', n)),
          "---\ntitle: Chapter #{n}\nchapter_number: #{n}\nsummary: Summary #{n}\n---\nContent #{n}."
        )
      end

      # Create a Russian translation (should be excluded)
      File.write(
        File.join(@chapters_dir, '001-chapter.ru.md'),
        "---\ntitle: Glava 1\n---\nRussian content."
      )

      @collection = Eidos::ChapterCollection.new(world_path: tmpdir)
      example.run
    end
  end

  it 'is enumerable' do
    expect(@collection).to respond_to(:each)
    expect(@collection.count).to eq(3)
  end

  it 'returns chapters by index (1-based chapter number)' do
    chapter = @collection[2]
    expect(chapter).to be_a(Eidos::Chapter)
    expect(chapter.title).to eq('Chapter 2')
  end

  it 'returns nil for missing chapter' do
    expect(@collection[99]).to be_nil
  end

  it 'returns the last chapter' do
    expect(@collection.last.chapter_number).to eq(3)
  end

  it 'excludes translation files' do
    titles = @collection.map(&:title)
    expect(titles).not_to include('Glava 1')
  end
end
```

- [ ] **Step 6: Run test to verify it fails**

Run: `cd eidos && bundle exec rspec spec/eidos/chapter_collection_spec.rb -v`
Expected: FAIL — `Eidos::ChapterCollection` not defined.

- [ ] **Step 7: Implement `Eidos::ChapterCollection`**

```ruby
# eidos/lib/eidos/chapter_collection.rb
# frozen_string_literal: true

require_relative 'chapter'

module Eidos
  # Collection of chapters in a world. Enumerable, indexable by chapter number.
  class ChapterCollection
    include Enumerable

    def initialize(world_path:)
      @chapters_dir = File.join(world_path, 'content', 'chapters')
    end

    def each(&block)
      load_all.each(&block)
    end

    # Access by chapter number (1-based)
    def [](chapter_number)
      path = chapter_path(chapter_number)
      return nil unless File.exist?(path)

      Chapter.from_file(path)
    end

    def last
      files = english_chapter_files
      return nil if files.empty?

      Chapter.from_file(files.last)
    end

    private

    def load_all
      english_chapter_files.map { |f| Chapter.from_file(f) }
    end

    def english_chapter_files
      return [] unless Dir.exist?(@chapters_dir)

      Dir.glob(File.join(@chapters_dir, '???-chapter.md')).sort
    end

    def chapter_path(number)
      File.join(@chapters_dir, format('%03d-chapter.md', number))
    end
  end
end
```

- [ ] **Step 8: Run the collection test**

Run: `cd eidos && bundle exec rspec spec/eidos/chapter_collection_spec.rb -v`
Expected: All pass.

- [ ] **Step 9: Wire `world.chapters` into `Eidos::World`**

Add to `eidos/lib/eidos/world.rb`, inside the `World` class, in the public section (before `private`):

```ruby
    def chapters
      @chapters ||= ChapterCollection.new(world_path: @path)
    end
```

And add at the top of the file, after `require_relative 'world_config'`:

```ruby
require_relative 'chapter_collection'
```

- [ ] **Step 10: Add integration test to world_spec.rb**

Append to `eidos/spec/eidos/world_spec.rb`, inside the main `describe` block:

```ruby
  describe '#chapters' do
    it 'returns a ChapterCollection' do
      world = Eidos::World.new('test-world')
      expect(world.chapters).to be_a(Eidos::ChapterCollection)
      expect(world.chapters.count).to eq(3)
    end

    it 'accesses chapters by number' do
      world = Eidos::World.new('test-world')
      chapter = world.chapters[1]
      expect(chapter.title).to eq('Chapter 1')
    end
  end
```

- [ ] **Step 11: Run all tests**

Run: `cd eidos && bundle exec rspec`
Expected: All tests pass.

- [ ] **Step 12: Commit**

```bash
cd eidos
git add lib/eidos/chapter.rb lib/eidos/chapter_collection.rb lib/eidos/world.rb \
        spec/eidos/chapter_spec.rb spec/eidos/chapter_collection_spec.rb spec/eidos/world_spec.rb
git commit -m "feat: add Eidos::Chapter and Eidos::ChapterCollection"
```

---

### Task 6: `Eidos::Character`, `Eidos::CharacterCollection`, and `Eidos::Bible`

**Files:**
- Create: `eidos/lib/eidos/character.rb`
- Create: `eidos/lib/eidos/character_collection.rb`
- Create: `eidos/lib/eidos/bible.rb`
- Create: `eidos/spec/eidos/character_sdk_spec.rb`
- Create: `eidos/spec/eidos/bible_sdk_spec.rb`
- Modify: `eidos/lib/eidos/world.rb` (add `#bible`)

- [ ] **Step 1: Write the Character test**

```ruby
# eidos/spec/eidos/character_sdk_spec.rb
# frozen_string_literal: true

require 'eidos/character'

RSpec.describe Eidos::Character do
  let(:data) do
    {
      'id' => 'kenji_yamamoto',
      'name' => 'Kenji Yamamoto',
      'role' => 'senior dev',
      'traits' => ['perfectionist', 'humble']
    }
  end

  let(:character) { Eidos::Character.new(data: data) }

  it 'exposes id and name' do
    expect(character.id).to eq('kenji_yamamoto')
    expect(character.name).to eq('Kenji Yamamoto')
  end

  it 'exposes arbitrary attributes via []' do
    expect(character['role']).to eq('senior dev')
    expect(character['traits']).to eq(['perfectionist', 'humble'])
  end

  it 'exposes attributes via method_missing' do
    expect(character.role).to eq('senior dev')
  end

  it 'responds_to? for existing attributes' do
    expect(character.respond_to?(:role)).to be true
    expect(character.respond_to?(:nonexistent)).to be false
  end

  it 'returns data as a hash via to_h' do
    expect(character.to_h).to eq(data)
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd eidos && bundle exec rspec spec/eidos/character_sdk_spec.rb -v`
Expected: FAIL — `Eidos::Character` not defined.

- [ ] **Step 3: Implement `Eidos::Character`**

```ruby
# eidos/lib/eidos/character.rb
# frozen_string_literal: true

module Eidos
  # SDK domain object for a character in the Story Bible.
  # Wraps a data hash with attribute accessors and persistence methods.
  class Character
    attr_reader :id, :data

    def initialize(data:, bible: nil)
      @data = data
      @id = data['id']
      @bible = bible
    end

    def name
      @data['name']
    end

    def [](key)
      @data[key.to_s]
    end

    def to_h
      @data.dup
    end

    def update(changes, reason: nil)
      changes.each { |k, v| @data[k.to_s] = v }
      @bible&.save_character(@id, @data, change_reason: reason)
      self
    end

    def history
      @bible&.character_history(@id) || []
    end

    def rollback(revision_number)
      @bible&.rollback_character(@id, revision_number)
    end

    def respond_to_missing?(method_name, include_private = false)
      @data.key?(method_name.to_s) || super
    end

    def method_missing(method_name, *args)
      key = method_name.to_s
      return @data[key] if args.empty? && @data.key?(key)

      super
    end
  end
end
```

- [ ] **Step 4: Run the character test**

Run: `cd eidos && bundle exec rspec spec/eidos/character_sdk_spec.rb -v`
Expected: All pass.

- [ ] **Step 5: Implement `Eidos::CharacterCollection`**

```ruby
# eidos/lib/eidos/character_collection.rb
# frozen_string_literal: true

require_relative 'character'

module Eidos
  # Collection of characters. Enumerable, indexable by id.
  class CharacterCollection
    include Enumerable

    def initialize(bible:)
      @bible = bible
    end

    def each(&block)
      load_all.each(&block)
    end

    def [](character_id)
      data = @bible.engine_bible.get_character(character_id)
      return nil unless data

      Character.new(data: data.merge('id' => character_id), bible: @bible)
    end

    private

    def load_all
      @bible.engine_bible.list_characters.map do |char_data|
        Character.new(data: char_data, bible: @bible)
      end
    end
  end
end
```

- [ ] **Step 6: Write the Bible test**

```ruby
# eidos/spec/eidos/bible_sdk_spec.rb
# frozen_string_literal: true

require 'eidos/bible'
require 'tmpdir'
require 'fileutils'
require 'yaml'

RSpec.describe Eidos::Bible do
  around do |example|
    Dir.mktmpdir do |tmpdir|
      @world_path = tmpdir
      setup_story_bible(tmpdir)
      example.run
    end
  end

  def setup_story_bible(dir)
    bible_dir = File.join(dir, 'data', 'story_bible')
    chars_dir = File.join(bible_dir, 'characters')
    locs_dir = File.join(bible_dir, 'locations')
    FileUtils.mkdir_p(chars_dir)
    FileUtils.mkdir_p(locs_dir)

    File.write(File.join(chars_dir, 'kenji_yamamoto.yml'), {
      'name' => 'Kenji Yamamoto',
      'role' => 'senior dev'
    }.to_yaml)

    File.write(File.join(chars_dir, 'kai_nakamura.yml'), {
      'name' => 'Kai Nakamura',
      'role' => 'junior dev'
    }.to_yaml)

    File.write(File.join(locs_dir, 'server_room.yml'), {
      'name' => 'Server Room',
      'description' => 'A cold, dark place'
    }.to_yaml)

    File.write(File.join(bible_dir, 'facts.yml'), { 'events' => {} }.to_yaml)
    File.write(File.join(bible_dir, 'relationships.yml'), { 'relationships' => [] }.to_yaml)
    File.write(File.join(bible_dir, 'plot_threads.yml'), { 'plot_threads' => [] }.to_yaml)
  end

  describe '#characters' do
    it 'returns a CharacterCollection' do
      bible = Eidos::Bible.new(world_path: @world_path)
      expect(bible.characters).to be_a(Eidos::CharacterCollection)
    end

    it 'accesses characters by id' do
      bible = Eidos::Bible.new(world_path: @world_path)
      kenji = bible.characters['kenji_yamamoto']
      expect(kenji).to be_a(Eidos::Character)
      expect(kenji.name).to eq('Kenji Yamamoto')
    end

    it 'enumerates characters' do
      bible = Eidos::Bible.new(world_path: @world_path)
      names = bible.characters.map(&:name)
      expect(names).to contain_exactly('Kenji Yamamoto', 'Kai Nakamura')
    end
  end

  describe '#search' do
    it 'searches facts by keyword' do
      bible = Eidos::Bible.new(world_path: @world_path)
      results = bible.search('server')
      # May be empty with minimal fixture — that's ok, just verify it doesn't crash
      expect(results).to be_an(Array)
    end
  end
end
```

- [ ] **Step 7: Run test to verify it fails**

Run: `cd eidos && bundle exec rspec spec/eidos/bible_sdk_spec.rb -v`
Expected: FAIL — `Eidos::Bible` not defined (or wrong `Bible` loaded).

- [ ] **Step 8: Implement `Eidos::Bible`**

```ruby
# eidos/lib/eidos/bible.rb
# frozen_string_literal: true

require_relative 'character_collection'
require_relative 'story_bible'

module Eidos
  # SDK facade for the Story Bible.
  # Wraps the engine's StoryBible with a clean OOP interface.
  class Bible
    attr_reader :engine_bible

    def initialize(world_path:)
      @world_path = world_path
      @engine_bible = StoryBible.new(project_root: world_path)
    end

    def characters
      @characters ||= CharacterCollection.new(bible: self)
    end

    def locations
      @engine_bible.locations
    end

    def facts
      @engine_bible.facts
    end

    def relationships
      @engine_bible.relationships
    end

    def plot_threads
      @engine_bible.plot_threads
    end

    def search(query)
      @engine_bible.search_facts(query)
    end

    def chapter_context(chapter_number)
      @engine_bible.chapter_context(chapter_number)
    end

    # Internal: used by Character#update
    def save_character(id, data, change_reason: nil)
      @engine_bible.save_character(id, data, change_reason: change_reason)
    end

    # Internal: used by Character#history
    def character_history(id)
      return [] unless @engine_bible.respond_to?(:revision_store) && @engine_bible.send(:revision_store)

      # Delegate to revision store if available
      []
    end

    # Internal: used by Character#rollback
    def rollback_character(id, revision_number)
      # Will be implemented when Canon is wired up
    end
  end
end
```

- [ ] **Step 9: Wire `world.bible` into `Eidos::World`**

Add to `eidos/lib/eidos/world.rb`, in the public section:

```ruby
    def bible
      @bible ||= Bible.new(world_path: @path)
    end
```

And add at the top, after existing requires:

```ruby
require_relative 'bible'
```

- [ ] **Step 10: Run all new tests**

Run: `cd eidos && bundle exec rspec spec/eidos/character_sdk_spec.rb spec/eidos/bible_sdk_spec.rb -v`
Expected: All pass.

- [ ] **Step 11: Run all tests**

Run: `cd eidos && bundle exec rspec`
Expected: All tests pass.

- [ ] **Step 12: Commit**

```bash
cd eidos
git add lib/eidos/character.rb lib/eidos/character_collection.rb lib/eidos/bible.rb \
        lib/eidos/world.rb \
        spec/eidos/character_sdk_spec.rb spec/eidos/bible_sdk_spec.rb
git commit -m "feat: add Eidos::Bible, Eidos::Character, Eidos::CharacterCollection"
```

---

### Task 7: `Eidos::Location` and `Eidos::LocationCollection`

**Files:**
- Create: `eidos/lib/eidos/location.rb`
- Create: `eidos/lib/eidos/location_collection.rb`
- Create: `eidos/spec/eidos/location_sdk_spec.rb`
- Modify: `eidos/lib/eidos/bible.rb` (wire up `#locations` to return collection)

- [ ] **Step 1: Write the test**

```ruby
# eidos/spec/eidos/location_sdk_spec.rb
# frozen_string_literal: true

require 'eidos/location'
require 'eidos/location_collection'
require 'eidos/bible'
require 'tmpdir'
require 'fileutils'
require 'yaml'

RSpec.describe Eidos::Location do
  let(:data) { { 'id' => 'server_room', 'name' => 'Server Room', 'description' => 'Cold and dark' } }
  let(:location) { Eidos::Location.new(data: data) }

  it 'exposes id, name, description' do
    expect(location.id).to eq('server_room')
    expect(location.name).to eq('Server Room')
    expect(location['description']).to eq('Cold and dark')
  end
end

RSpec.describe Eidos::LocationCollection do
  around do |example|
    Dir.mktmpdir do |tmpdir|
      @world_path = tmpdir
      locs_dir = File.join(tmpdir, 'data', 'story_bible', 'locations')
      FileUtils.mkdir_p(locs_dir)
      # Also need the other bible files so StoryBible doesn't error
      bible_dir = File.join(tmpdir, 'data', 'story_bible')
      FileUtils.mkdir_p(File.join(bible_dir, 'characters'))
      File.write(File.join(bible_dir, 'facts.yml'), { 'events' => {} }.to_yaml)
      File.write(File.join(bible_dir, 'relationships.yml'), { 'relationships' => [] }.to_yaml)
      File.write(File.join(bible_dir, 'plot_threads.yml'), { 'plot_threads' => [] }.to_yaml)

      File.write(File.join(locs_dir, 'server_room.yml'), {
        'name' => 'Server Room', 'description' => 'Cold'
      }.to_yaml)
      File.write(File.join(locs_dir, 'office.yml'), {
        'name' => 'Office', 'description' => 'Open plan'
      }.to_yaml)

      example.run
    end
  end

  it 'enumerates locations' do
    bible = Eidos::Bible.new(world_path: @world_path)
    names = bible.locations.map(&:name)
    expect(names).to contain_exactly('Server Room', 'Office')
  end

  it 'accesses by id' do
    bible = Eidos::Bible.new(world_path: @world_path)
    loc = bible.locations['server_room']
    expect(loc.name).to eq('Server Room')
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd eidos && bundle exec rspec spec/eidos/location_sdk_spec.rb -v`
Expected: FAIL — `Eidos::Location` not defined.

- [ ] **Step 3: Implement Location and LocationCollection**

```ruby
# eidos/lib/eidos/location.rb
# frozen_string_literal: true

module Eidos
  # SDK domain object for a location in the Story Bible.
  class Location
    attr_reader :id, :data

    def initialize(data:, bible: nil)
      @data = data
      @id = data['id']
      @bible = bible
    end

    def name
      @data['name']
    end

    def [](key)
      @data[key.to_s]
    end

    def to_h
      @data.dup
    end

    def update(changes, reason: nil)
      changes.each { |k, v| @data[k.to_s] = v }
      @bible&.save_location(@id, @data, change_reason: reason)
      self
    end

    def respond_to_missing?(method_name, include_private = false)
      @data.key?(method_name.to_s) || super
    end

    def method_missing(method_name, *args)
      key = method_name.to_s
      return @data[key] if args.empty? && @data.key?(key)

      super
    end
  end
end
```

```ruby
# eidos/lib/eidos/location_collection.rb
# frozen_string_literal: true

require_relative 'location'

module Eidos
  # Collection of locations. Enumerable, indexable by id.
  class LocationCollection
    include Enumerable

    def initialize(bible:)
      @bible = bible
    end

    def each(&block)
      load_all.each(&block)
    end

    def [](location_id)
      locs = @bible.engine_bible.locations
      data = locs[location_id]
      return nil unless data

      Location.new(data: data.merge('id' => location_id), bible: @bible)
    end

    private

    def load_all
      @bible.engine_bible.locations.map do |id, data|
        Location.new(data: data.merge('id' => id), bible: @bible)
      end
    end
  end
end
```

- [ ] **Step 4: Update `Bible#locations` to return `LocationCollection`**

In `eidos/lib/eidos/bible.rb`, add require at top:

```ruby
require_relative 'location_collection'
```

Replace the `locations` method:

```ruby
    def locations
      @locations ||= LocationCollection.new(bible: self)
    end
```

Add a helper for Location persistence:

```ruby
    def save_location(id, data, change_reason: nil)
      @engine_bible.save_location(id, data, change_reason: change_reason)
    end
```

- [ ] **Step 5: Run all new tests**

Run: `cd eidos && bundle exec rspec spec/eidos/location_sdk_spec.rb -v`
Expected: All pass.

- [ ] **Step 6: Run all tests**

Run: `cd eidos && bundle exec rspec`
Expected: All tests pass.

- [ ] **Step 7: Commit**

```bash
cd eidos
git add lib/eidos/location.rb lib/eidos/location_collection.rb lib/eidos/bible.rb \
        spec/eidos/location_sdk_spec.rb
git commit -m "feat: add Eidos::Location and Eidos::LocationCollection"
```

---

### Task 8: `Eidos::Canon` (snapshots and branches)

**Files:**
- Create: `eidos/lib/eidos/canon.rb`
- Create: `eidos/spec/eidos/canon_sdk_spec.rb`
- Modify: `eidos/lib/eidos/world.rb` (add `#canon`)

- [ ] **Step 1: Write the test**

```ruby
# eidos/spec/eidos/canon_sdk_spec.rb
# frozen_string_literal: true

require 'eidos/canon'
require 'tmpdir'
require 'fileutils'
require 'yaml'

RSpec.describe Eidos::Canon do
  around do |example|
    Dir.mktmpdir do |tmpdir|
      @world_path = tmpdir
      bible_dir = File.join(tmpdir, 'data', 'story_bible')
      FileUtils.mkdir_p(File.join(bible_dir, 'characters'))
      FileUtils.mkdir_p(File.join(bible_dir, 'locations'))
      FileUtils.mkdir_p(File.join(bible_dir, 'revisions'))
      FileUtils.mkdir_p(File.join(bible_dir, 'snapshots'))
      FileUtils.mkdir_p(File.join(tmpdir, 'data', 'changesets'))
      File.write(File.join(bible_dir, 'facts.yml'), { 'events' => {} }.to_yaml)
      File.write(File.join(bible_dir, 'relationships.yml'), { 'relationships' => [] }.to_yaml)
      File.write(File.join(bible_dir, 'plot_threads.yml'), { 'plot_threads' => [] }.to_yaml)

      example.run
    end
  end

  it 'exposes snapshots' do
    canon = Eidos::Canon.new(world_path: @world_path)
    expect(canon.snapshots).to be_an(Array)
  end

  it 'exposes branches' do
    canon = Eidos::Canon.new(world_path: @world_path)
    expect(canon.branches).to be_an(Array)
  end

  it 'reports current branch' do
    canon = Eidos::Canon.new(world_path: @world_path)
    expect(canon.current_branch).to eq('main')
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd eidos && bundle exec rspec spec/eidos/canon_sdk_spec.rb -v`
Expected: FAIL — `Eidos::Canon` not defined (the existing `CLI::Canon` is different).

- [ ] **Step 3: Implement `Eidos::Canon`**

```ruby
# eidos/lib/eidos/canon.rb
# frozen_string_literal: true

require_relative 'revision_store'
require_relative 'snapshot_store'
require_relative 'story_bible'
require_relative 'diff_engine'
require_relative 'branch_manager'

module Eidos
  # SDK facade for canon versioning: revisions, snapshots, branches.
  class Canon
    def initialize(world_path:)
      @world_path = world_path
      @bible_path = File.join(world_path, 'data', 'story_bible')
      @revisions_path = File.join(@bible_path, 'revisions')
    end

    def history(entity_type, entity_id, branch: 'main')
      revision_store.history(entity_type: entity_type, entity_id: entity_id, branch: branch)
    end

    def diff(entity_type, entity_id, rev1, rev2, branch: 'main')
      r1 = revision_store.get(entity_type: entity_type, entity_id: entity_id, sequence: rev1, branch: branch)
      r2 = revision_store.get(entity_type: entity_type, entity_id: entity_id, sequence: rev2, branch: branch)
      return nil unless r1 && r2

      diff_engine.diff(r1.snapshot, r2.snapshot)
    end

    def snapshots
      snapshot_store.list
    end

    def create_snapshot(name)
      snapshot_store.create(name: name)
    end

    def branches
      branch_manager.list
    end

    def current_branch
      branch_manager.current_branch
    end

    def create_branch(name, from: 'main', description: nil)
      branch_manager.create(name: name, from_branch: from, description: description)
    end

    def compare_branches(branch_a, branch_b)
      branch_manager.compare(branch_a, branch_b)
    end

    def merge_branch(source, into:)
      branch_manager.merge(source: source, target: into)
    end

    private

    def revision_store
      @revision_store ||= RevisionStore.new(revisions_path: @revisions_path)
    end

    def snapshot_store
      @snapshot_store ||= SnapshotStore.new(story_bible_path: @bible_path)
    end

    def diff_engine
      @diff_engine ||= DiffEngine.new
    end

    def branch_manager
      @branch_manager ||= BranchManager.new(
        story_bible_path: @bible_path,
        revision_store: revision_store,
        diff_engine: diff_engine
      )
    end
  end
end
```

- [ ] **Step 4: Wire `world.canon` into `Eidos::World`**

Add to `eidos/lib/eidos/world.rb`, in the public section:

```ruby
    def canon
      @canon ||= Canon.new(world_path: @path)
    end
```

And add at the top:

```ruby
require_relative 'canon'
```

- [ ] **Step 5: Run all new tests**

Run: `cd eidos && bundle exec rspec spec/eidos/canon_sdk_spec.rb -v`
Expected: All pass.

- [ ] **Step 6: Run all tests**

Run: `cd eidos && bundle exec rspec`
Expected: All tests pass.

- [ ] **Step 7: Commit**

```bash
cd eidos
git add lib/eidos/canon.rb lib/eidos/world.rb spec/eidos/canon_sdk_spec.rb
git commit -m "feat: add Eidos::Canon SDK facade for versioning"
```

---

### Task 9: End-to-end SDK integration test

**Files:**
- Create: `eidos/spec/eidos/sdk_integration_spec.rb`

- [ ] **Step 1: Write the integration test**

```ruby
# eidos/spec/eidos/sdk_integration_spec.rb
# frozen_string_literal: true

require 'eidos'
require 'tmpdir'
require 'fileutils'
require 'yaml'

RSpec.describe 'SDK Integration' do
  around do |example|
    Dir.mktmpdir do |tmpdir|
      @worlds_path = tmpdir
      @world_dir = File.join(tmpdir, 'my-world')
      setup_full_world(@world_dir)
      Eidos.configure { |c| c.worlds_path = tmpdir }
      example.run
      Eidos.reset_configuration!
    end
  end

  def setup_full_world(dir)
    FileUtils.mkdir_p(File.join(dir, 'data', 'story_bible', 'characters'))
    FileUtils.mkdir_p(File.join(dir, 'data', 'story_bible', 'locations'))
    FileUtils.mkdir_p(File.join(dir, 'data', 'story_bible', 'revisions'))
    FileUtils.mkdir_p(File.join(dir, 'data', 'story_bible', 'snapshots'))
    FileUtils.mkdir_p(File.join(dir, 'data', 'changesets'))
    FileUtils.mkdir_p(File.join(dir, 'content', 'chapters'))

    File.write(File.join(dir, 'data', 'world_config.yml'), {
      'localized' => { 'en' => { 'title' => 'My World', 'author' => 'Me', 'genre' => 'comedy' } }
    }.to_yaml)

    File.write(File.join(dir, 'data', 'world_state.yml'), {
      'world' => { 'current_chapter' => 2 }
    }.to_yaml)

    File.write(File.join(dir, 'content', 'chapters', '001-chapter.md'),
               "---\ntitle: First Chapter\nchapter_number: 1\n---\nHello world.")

    File.write(File.join(dir, 'content', 'chapters', '002-chapter.md'),
               "---\ntitle: Second Chapter\nchapter_number: 2\n---\nMore content.")

    File.write(File.join(dir, 'data', 'story_bible', 'characters', 'hero.yml'), {
      'name' => 'The Hero', 'role' => 'protagonist'
    }.to_yaml)

    File.write(File.join(dir, 'data', 'story_bible', 'locations', 'office.yml'), {
      'name' => 'The Office', 'description' => 'Where it all happens'
    }.to_yaml)

    File.write(File.join(dir, 'data', 'story_bible', 'facts.yml'), {}.to_yaml)
    File.write(File.join(dir, 'data', 'story_bible', 'relationships.yml'), { 'relationships' => [] }.to_yaml)
    File.write(File.join(dir, 'data', 'story_bible', 'plot_threads.yml'), { 'plot_threads' => [] }.to_yaml)
  end

  it 'provides the full SDK workflow' do
    # Find world by name
    world = Eidos::World.new('my-world')
    expect(world.name).to eq('my-world')

    # Status
    status = world.status
    expect(status[:title]).to eq('My World')
    expect(status[:chapters]).to eq(2)

    # Chapters
    expect(world.chapters.count).to eq(2)
    expect(world.chapters[1].title).to eq('First Chapter')
    expect(world.chapters.last.title).to eq('Second Chapter')

    # Bible - characters
    expect(world.bible.characters.count).to eq(1)
    hero = world.bible.characters['hero']
    expect(hero.name).to eq('The Hero')
    expect(hero.role).to eq('protagonist')

    # Bible - locations
    office = world.bible.locations['office']
    expect(office.name).to eq('The Office')

    # Canon
    expect(world.canon.current_branch).to eq('main')
    expect(world.canon.snapshots).to be_an(Array)
  end
end
```

- [ ] **Step 2: Run the integration test**

Run: `cd eidos && bundle exec rspec spec/eidos/sdk_integration_spec.rb -v`
Expected: All pass.

- [ ] **Step 3: Run all tests**

Run: `cd eidos && bundle exec rspec`
Expected: All tests pass.

- [ ] **Step 4: Commit**

```bash
cd eidos
git add spec/eidos/sdk_integration_spec.rb
git commit -m "test: add SDK end-to-end integration test"
```

---

## Phase 3: Rewrite CLI on top of SDK

### Task 10: CLI infrastructure — `Eidos::CLI::Main` and shared helpers

**Files:**
- Create: `eidos/lib/eidos/cli/main.rb`
- Create: `eidos/lib/eidos/cli/sdk_helpers.rb`
- Modify: `eidos/exe/eidos`

- [ ] **Step 1: Create SDK helpers for CLI commands**

```ruby
# eidos/lib/eidos/cli/sdk_helpers.rb
# frozen_string_literal: true

require 'eidos'

module Eidos
  module CLI
    # Helpers for CLI commands that use the SDK
    module SdkHelpers
      private

      def resolve_world(options)
        world_name = options['world-dir'] || options[:world] || options['w']
        if world_name
          Eidos::World.new(world_name)
        else
          Eidos::World.new
        end
      rescue Eidos::WorldNotFoundError => e
        say e.message, :red
        exit 1
      end
    end
  end
end
```

- [ ] **Step 2: Create `Eidos::CLI::Main` as standalone class**

```ruby
# eidos/lib/eidos/cli/main.rb
# frozen_string_literal: true

require 'thor'
require 'eidos/version'

module Eidos
  module CLI
    # Top-level CLI router for the unified `eidos` command.
    # Delegates to subcommand classes.
    class Main < Thor
      def self.exit_on_failure?
        true
      end

      desc 'version', 'Show version'
      def version
        puts "eidos #{Eidos::VERSION}"
      end

      map %w[--version -v] => :version
    end
  end
end

# Load and register subcommands.
# During transition, these are the existing CLI classes.
# They will be replaced one by one with SDK-based versions.
require 'eidos/cli/world'
require 'eidos/cli/bible'
require 'eidos/cli/canon'
require 'eidos/cli/produce'
require 'eidos/cli/translate'
require 'eidos/cli/publish'

module Eidos
  module CLI
    class Main
      desc 'world SUBCOMMAND ...ARGS', 'Manage worlds'
      subcommand 'world', Eidos::CLI::World

      desc 'bible SUBCOMMAND ...ARGS', 'Manage the Story Bible'
      subcommand 'bible', Eidos::CLI::Bible

      desc 'canon SUBCOMMAND ...ARGS', 'Manage canon versioning'
      subcommand 'canon', Eidos::CLI::Canon

      desc 'produce SUBCOMMAND ...ARGS', 'Generate content'
      subcommand 'produce', Eidos::CLI::Produce

      desc 'translate SUBCOMMAND ...ARGS', 'Translate content'
      subcommand 'translate', Eidos::CLI::Translate

      desc 'publish SUBCOMMAND ...ARGS', 'Publish content'
      subcommand 'publish', Eidos::CLI::Publish
    end
  end
end
```

- [ ] **Step 3: Simplify `exe/eidos` to use Main**

```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true

lib_dir = File.expand_path('../lib', __dir__)
$LOAD_PATH.unshift(lib_dir) unless $LOAD_PATH.include?(lib_dir)

require 'eidos/cli/main'

Eidos::CLI::Main.start(ARGV)
```

- [ ] **Step 4: Test manually**

Run: `cd eidos && exe/eidos version`
Expected: `eidos 0.2.0`

Run: `cd eidos && exe/eidos world status -w ../worlds/one-review-man`
Expected: World status report.

Run: `cd eidos && exe/eidos bible list characters -w ../worlds/one-review-man`
Expected: Character list.

- [ ] **Step 5: Run all tests**

Run: `cd eidos && bundle exec rspec`
Expected: All tests pass.

- [ ] **Step 6: Commit**

```bash
cd eidos
git add lib/eidos/cli/main.rb lib/eidos/cli/sdk_helpers.rb exe/eidos
git commit -m "feat: add CLI::Main router and SDK helpers"
```

---

### Task 11: New `eidos chapter` CLI command (SDK-based)

This demonstrates the new pattern. One new subcommand using the SDK. The old `produce` still works in parallel.

**Files:**
- Create: `eidos/lib/eidos/cli/chapter_cli.rb`
- Modify: `eidos/lib/eidos/cli/main.rb` (register new subcommand)

- [ ] **Step 1: Create the chapter CLI**

```ruby
# eidos/lib/eidos/cli/chapter_cli.rb
# frozen_string_literal: true

require 'thor'
require 'eidos/cli/sdk_helpers'

module Eidos
  module CLI
    # SDK-based CLI for chapter operations.
    class ChapterCli < Thor
      include SdkHelpers

      class_option 'world-dir', aliases: ['-w'], type: :string,
                                desc: 'Path to the world directory'

      desc 'list', 'List all chapters'
      def list
        world = resolve_world(options)
        chapters = world.chapters.to_a

        if chapters.empty?
          say 'No chapters generated yet.', :yellow
          return
        end

        say "Chapters (#{chapters.length}):", :cyan
        chapters.each do |ch|
          say format('  %03d: %s', ch.chapter_number, ch.title), :green
        end
      end

      desc 'show NUMBER', 'Show chapter details'
      def show(number)
        world = resolve_world(options)
        chapter = world.chapters[number.to_i]

        unless chapter
          say "Chapter #{number} not found.", :red
          exit 1
        end

        say "Chapter #{chapter.chapter_number}: #{chapter.title}", :cyan
        say "Summary: #{chapter.summary}" if chapter.summary
        say "Characters: #{chapter.characters.join(', ')}" if chapter.characters.any?
        say "Words: #{chapter.content.split.length}"
      end
    end
  end
end
```

- [ ] **Step 2: Register in Main**

Add to `eidos/lib/eidos/cli/main.rb`, in the second `Main` reopening, alongside the other subcommands:

```ruby
      # New SDK-based subcommands
      desc 'chapter SUBCOMMAND ...ARGS', 'Chapter operations'
      subcommand 'chapter', Eidos::CLI::ChapterCli
```

And add the require before the subcommand registrations:

```ruby
require 'eidos/cli/chapter_cli'
```

- [ ] **Step 3: Test manually**

Run: `cd eidos && exe/eidos chapter list -w ../worlds/one-review-man`
Expected: Lists all 11 chapters with numbers and titles.

Run: `cd eidos && exe/eidos chapter show 1 -w ../worlds/one-review-man`
Expected: Shows chapter 1 details.

- [ ] **Step 4: Run all tests**

Run: `cd eidos && bundle exec rspec`
Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
cd eidos
git add lib/eidos/cli/chapter_cli.rb lib/eidos/cli/main.rb
git commit -m "feat: add 'eidos chapter' CLI subcommand (SDK-based)"
```

---

### Task 12: New `eidos character` CLI command (SDK-based)

**Files:**
- Create: `eidos/lib/eidos/cli/character_cli.rb`
- Modify: `eidos/lib/eidos/cli/main.rb` (register)

- [ ] **Step 1: Create the character CLI**

```ruby
# eidos/lib/eidos/cli/character_cli.rb
# frozen_string_literal: true

require 'thor'
require 'eidos/cli/sdk_helpers'

module Eidos
  module CLI
    # SDK-based CLI for character operations.
    class CharacterCli < Thor
      include SdkHelpers

      class_option 'world-dir', aliases: ['-w'], type: :string,
                                desc: 'Path to the world directory'

      desc 'list', 'List all characters'
      def list
        world = resolve_world(options)
        chars = world.bible.characters.to_a

        if chars.empty?
          say 'No characters found.', :yellow
          return
        end

        say "Characters (#{chars.length}):", :cyan
        chars.each { |c| say "  #{c.id}: #{c.name}", :green }
      end

      desc 'show ID', 'Show character details'
      def show(id)
        world = resolve_world(options)
        character = world.bible.characters[id]

        unless character
          say "Character '#{id}' not found.", :red
          exit 1
        end

        say "Character: #{character.name}", :cyan
        character.to_h.each do |key, value|
          next if key == 'id'

          say "  #{key}: #{value}"
        end
      end

      desc 'update ID [FIELD=VALUE...]', 'Update a character'
      method_option :reason, type: :string, desc: 'Reason for the change'
      def update(id, *field_values)
        world = resolve_world(options)
        character = world.bible.characters[id]

        unless character
          say "Character '#{id}' not found.", :red
          exit 1
        end

        changes = {}
        field_values.each do |fv|
          key, value = fv.split('=', 2)
          changes[key] = value if key && value
        end

        character.update(changes, reason: options[:reason])
        say "Updated #{id}", :green
      end
    end
  end
end
```

- [ ] **Step 2: Register in Main**

Add to `eidos/lib/eidos/cli/main.rb`:

```ruby
require 'eidos/cli/character_cli'
```

And in the subcommand registrations:

```ruby
      desc 'character SUBCOMMAND ...ARGS', 'Character operations'
      subcommand 'character', Eidos::CLI::CharacterCli
```

- [ ] **Step 3: Test manually**

Run: `cd eidos && exe/eidos character list -w ../worlds/one-review-man`
Expected: Lists all 10 characters.

Run: `cd eidos && exe/eidos character show kenji_yamamoto -w ../worlds/one-review-man`
Expected: Shows Kenji's details.

- [ ] **Step 4: Run all tests**

Run: `cd eidos && bundle exec rspec`
Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
cd eidos
git add lib/eidos/cli/character_cli.rb lib/eidos/cli/main.rb
git commit -m "feat: add 'eidos character' CLI subcommand (SDK-based)"
```

---

### Task 13: Verify gem builds and installs cleanly

**Files:** No new files. Verification only.

- [ ] **Step 1: Build the gem**

Run: `cd eidos && gem build eidos.gemspec`
Expected: `Successfully built RubyGem` with `eidos-0.2.0.gem`.

- [ ] **Step 2: Install locally**

Run: `cd eidos && gem install --local eidos-0.2.0.gem`
Expected: `Successfully installed eidos-0.2.0`. The `eidos` command is now available globally.

- [ ] **Step 3: Test the installed gem**

Run: `eidos version`
Expected: `eidos 0.2.0`

Run: `eidos chapter list -w /full/path/to/worlds/one-review-man`
Expected: Lists chapters.

Run: `eidos character list -w /full/path/to/worlds/one-review-man`
Expected: Lists characters.

- [ ] **Step 4: Test SDK from irb**

Run:
```bash
irb -r eidos -e "
  Eidos.configure { |c| c.worlds_path = '/full/path/to/worlds' }
  w = Eidos::World.new('one-review-man')
  puts w.status.inspect
  puts w.chapters.count
  puts w.bible.characters.map(&:name).inspect
"
```
Expected: Prints world status, chapter count, character names.

- [ ] **Step 5: Clean up**

Run: `cd eidos && rm eidos-0.2.0.gem && gem uninstall eidos`

- [ ] **Step 6: Commit any fixes needed**

If any issues were found and fixed, commit them now.

---

## Summary

After all 13 tasks, you have:

- **Installable gem:** `gem install eidos` with a single `eidos` command
- **SDK:** `Eidos::World.new("my-world")` with `.chapters`, `.bible.characters`, `.bible.locations`, `.canon`
- **OOP domain objects:** `Chapter`, `Character`, `Location`, `Bible`, `Canon` with behavior
- **New CLI commands:** `eidos chapter list/show`, `eidos character list/show/update`
- **Old CLI preserved:** `eidos world/bible/canon/produce/translate/publish` still work
- **508+ tests passing** plus new SDK tests

Phase 4 (engine cleanup, move to `engine/` namespace) is left for a follow-up plan. The old CLI commands (`produce`, `bible`, `canon`, `translate`, `publish`) will be rewritten to use SDK in follow-up tasks as well — one at a time, same pattern as Tasks 11-12.
