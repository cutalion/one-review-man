# Project Refactoring Plan: Splitting One Review Man into Independent Components

## Overview

This document outlines a comprehensive step-by-step plan to refactor the One Review Man project into three independent, reusable components:

1. **Book Generation Library** - Core content generation engine
2. **Static Site Generator Adapters** - Pluggable site generators (Jekyll, Hugo, etc.)
3. **Book Content & Configuration** - Specific book data and settings

## ⚠️ Zero-Breakage Methodology

**CRITICAL PRINCIPLE (historical)**: Earlier phases preserved 100% of existing behavior at every step. We have now fully migrated to the new core and CLI; legacy validation is no longer required.

### 🛡️ Safety Framework

#### 1. **Strangler Fig Pattern**
Build new system alongside old, gradually migrating:
```
Current:     [Jekyll Site] ← [Ruby CLI] ← [Content]
Transition:  [Jekyll Site] ← [New Core] ← [Content]
                             ↑ [Old CLI] (proxy mode)
Final:       [Any Generator] ← [New Core] ← [Content]
```

#### 2. **Simple but Safe Testing**
⚠️ **CRITICAL**: AI content is non-deterministic - need deterministic testing approach!

```bash
# Simple Pet Project Safety Net
git checkout -b refactoring-backup
cp -r . ../one-review-man-backup-$(date +%Y%m%d)

# Mock AI responses for consistent testing
cat > test/ai_responses.yml << EOF
chapter_1: "Alex looked at the pull request with his usual skepticism..."
chapter_2: "The code review session began as Sarah opened the editor..."
EOF

# (Historical) legacy validation script used old vs new comparison
```

**Why We Need Mock AI**:
```ruby
# ❌ THIS WILL ALWAYS FAIL
expected = "Alex reviewed the code with sarcasm..."
actual = generate_chapter(1)  # Different AI output every time!
assert_equal expected, actual  # GUARANTEED FAILURE
```

**Simple Solution**:
```ruby
# ✅ Mock AI for consistent testing
class MockLLMService
  def generate_text(prompt:, context: {})
    responses = YAML.load_file('test/ai_responses.yml')
    chapter_num = extract_chapter_number(prompt)
    responses["chapter_#{chapter_num}"] || "Mock chapter content"
  end
end

# Test structure and behavior, not exact content
def validate_chapter(chapter_content)
  chapter_content.match?(/^---\nlayout: chapter/) &&
  chapter_content.length > 500 &&
  chapter_content.include?("Alex" || "Sarah" || "Mike")
end
```

#### 3. **Extract-and-Wrap Pattern**
Never rewrite - extract behind identical interfaces:
```ruby
# Legacy flag removed; new core is default
```

#### 4. **Simple Validation Testing**
For final validation only (not every change):

```bash
#!/bin/bash
# (Deprecated) bin/validate-refactoring - legacy validation script no longer used

set -e

echo "🔍 Validating refactoring with mock AI..."

echo "Legacy validation removed. Use MOCK_AI=true with book-generator/bin/book and build the site for checks."
```

#### 5. **Simple Rollback Strategy**
- Git branch for each major step
- Full backup before starting: `cp -r . ../backup-$(date +%Y%m%d)`
- Keep old code paths until manually verified
- Simple rollback: `git checkout main && rm -rf new_code`

#### 6. **Essential Validation Gates**
Every major step must pass:
- [ ] Existing tests pass **with mocked AI** 
- [ ] (Deprecated) Behavioral equivalence via legacy validation
- [ ] Manual spot-check of generated content looks correct
- [ ] Site builds successfully with Jekyll
- [ ] No new dependencies without good reason
- [ ] **Git commit only after validation passes**

## Current State Analysis

### Project Structure
The project currently combines:
- Jekyll-based static site generation
- Ruby CLI tool for content generation
- AI-powered chapter creation via OpenAI
- Multilingual support (English/Russian)
- Character and world consistency management

### Key Dependencies
- Jekyll 4.4.1 for site generation
- Ruby with Thor CLI framework
- OpenAI API integration
- Jekyll Polyglot for multilingualization

## Target Architecture

```
one-review-man-ecosystem/
├── packages/
│   ├── book-generator-core/          # 📚 Core library
│   ├── book-generator-jekyll/        # 🏗️ Jekyll adapter
│   ├── book-generator-hugo/          # 🏗️ Hugo adapter (future)
│   └── book-generator-pdf/           # 📄 PDF generator (future)
└── books/
    ├── one-review-man/               # 📖 Current book
    ├── another-adventure/            # 📖 Future book
    └── shared-templates/             # 🎨 Reusable templates
```

## Phase 1: Extract Core Book Generation Library

### Step 1.1: Create Core Library Package

**Goal**: Extract all book generation logic into a standalone Ruby gem.

**Actions**:
1. Create new directory structure:
   ```
   packages/book-generator-core/
   ├── lib/
   │   └── book_generator/
   │       ├── core/
   │       │   ├── generator.rb          # Main generation engine
   │       │   ├── chapter.rb            # Chapter model
   │       │   ├── character.rb          # Character model
   │       │   ├── world.rb              # World consistency
   │       │   └── book.rb               # Book model
   │       ├── services/
   │       │   ├── llm_service.rb        # AI integration (abstract)
   │       │   ├── openai_service.rb     # OpenAI implementation
   │       │   └── translator.rb         # Translation service
   │       ├── utils/
   │       │   ├── file_utils.rb         # File operations
   │       │   ├── prompt_utils.rb       # Prompt management
   │       │   └── config_utils.rb       # Configuration
   │       └── version.rb
   ├── templates/                        # Default prompt templates
   ├── spec/                            # Comprehensive tests
   ├── book-generator-core.gemspec
   ├── Gemfile
   └── README.md
   ```

2. **Extract Core Classes**:
   - Move `lib/book/chapter_generator.rb` → `lib/book_generator/core/generator.rb`
   - Move `lib/book/utils/llm_service.rb` → `lib/book_generator/services/llm_service.rb`
   - Move `lib/book/utils/world_utils.rb` → `lib/book_generator/core/world.rb`
   - Move `lib/book/prompts/` → `templates/prompts/`

3. **Create Abstract Interfaces**:
   ```ruby
   # lib/book_generator/core/generator.rb
   module BookGenerator
     class Generator
       def initialize(config:, llm_service:, output_adapter:)
         @config = config
         @llm_service = llm_service
         @output_adapter = output_adapter
       end

       def generate_chapter(chapter_number)
         # Core generation logic, adapter-agnostic
       end
     end
   end
   ```

### Step 1.2: Configuration System

**Goal**: Create flexible, hierarchical configuration system.

**Actions**:
1. **Create Configuration Schema**:
   ```ruby
   # lib/book_generator/core/config.rb
   class Config
     attr_reader :book_metadata, :world_settings, :character_database, 
                 :generation_settings, :output_settings
     
     def self.load_from_directory(path)
       # Load from YAML files or Ruby DSL
     end
   end
   ```

2. **Support Multiple Config Formats**:
   - YAML files (current format)
   - Ruby DSL for programmatic configuration
   - JSON for external tools integration

### Step 1.3: Plugin Architecture for LLM Services

**Goal**: Make AI providers swappable (OpenAI, Anthropic, local models).

**Actions**:
1. **Abstract LLM Interface**:
   ```ruby
   # lib/book_generator/services/base_llm_service.rb
   class BaseLLMService
     def generate_text(prompt:, context: {})
       raise NotImplementedError
     end
     
     def translate_text(text:, target_language:)
       raise NotImplementedError
     end
   end
   ```

2. **Provider Implementations**:
   - `OpenAIService` (existing)
   - `AnthropicService` (future)
   - `LocalLLMService` (for offline generation)

## Phase 2: Create Site Generator Adapters

### Step 2.1: Abstract Output Adapter Interface

**Goal**: Make site generators pluggable and interchangeable.

**Actions**:
1. **Create Base Adapter**:
   ```ruby
   # lib/book_generator/adapters/base_adapter.rb
   class BaseAdapter
     def initialize(config)
       @config = config
     end
     
     def setup_project(path)
       # Initialize site structure
     end
     
     def write_chapter(chapter)
       # Output chapter in site format
     end
     
     def write_character(character)
       # Output character page
     end
     
     def build_site
       # Trigger site build process
     end
   end
   ```

### Step 2.2: Jekyll Adapter Package

**Goal**: Extract Jekyll-specific logic into separate adapter.

**Actions**:
1. **Create Jekyll Adapter Package**:
   ```
   packages/book-generator-jekyll/
   ├── lib/
   │   └── book_generator/
   │       └── adapters/
   │           ├── jekyll_adapter.rb     # Main adapter
   │           ├── layout_generator.rb   # Generate _layouts/
   │           ├── include_generator.rb  # Generate _includes/
   │           └── config_generator.rb   # Generate _config.yml
   ├── templates/
   │   ├── layouts/                     # Default Jekyll layouts
   │   ├── includes/                    # Default Jekyll includes
   │   └── assets/                      # Default CSS/JS
   ├── spec/
   ├── book-generator-jekyll.gemspec
   └── README.md
   ```

2. **Implement Jekyll-Specific Logic**:
   - Move `_layouts/`, `_includes/` to templates
   - Create logic to generate `_config.yml` from core config
   - Handle Jekyll collections and front matter

### Step 2.3: Future Adapters Framework

**Goal**: Prepare for additional site generators.

**Planned Adapters**:
- **Hugo Adapter**: For faster builds and different templating
- **Next.js Adapter**: For modern React-based sites
- **PDF Adapter**: For generating print-ready books
- **EPUB Adapter**: For e-book distribution

## Phase 3: Separate Book Content and Configuration

### Step 3.1: Book Project Template

**Goal**: Create reusable template for new book projects.

**Actions**:
1. **Template Structure**:
   ```
   books/book-template/
   ├── book.yml                    # Main book configuration
   ├── characters/
   │   ├── characters.yml          # Character database
   │   └── relationships.yml       # Character relationships
   ├── world/
   │   ├── world.yml              # World consistency data
   │   ├── locations.yml          # Locations database
   │   └── timeline.yml           # Story timeline
   ├── prompts/
   │   ├── chapter_template.md    # Custom chapter prompts
   │   ├── character_template.md  # Custom character prompts
   │   └── translation_template.md # Custom translation prompts
   ├── content/
   │   ├── chapters/              # Generated chapters
   │   └── characters/            # Generated character pages
   ├── assets/
   │   ├── images/               # Book-specific images
   │   └── styles/               # Custom CSS
   └── Bookfile                  # Book generation script
   ```

### Step 3.2: Book Configuration DSL

**Goal**: Create user-friendly configuration format.

**Actions**:
1. **Book DSL Example**:
   ```ruby
   # books/one-review-man/Bookfile
   book "One Review Man" do
     version "1.0.0"
     author "AI Generated"
     description "Programming humor through code reviews"
     
     languages [:en, :ru]
     default_language :en
     
     llm_service :openai do
       model "gpt-4"
       temperature 0.7
     end
     
     output_adapter :jekyll do  
       theme "minima"
       url "https://one-review-man.github.io"
       plugins ["jekyll-feed", "jekyll-polyglot"]
     end
     
     world do
       company "TechCorp Solutions"
       setting "Modern software development company"
       tone "Humorous, satirical"
     end
     
     character "Alex" do
       role "Senior Developer"
       personality "Perfectionist, sarcastic"
       skills ["Code review", "Architecture"]
     end
   end
   ```

### Step 3.3: Migration Script

**Goal**: Migrate current One Review Man to new structure.

**Actions**:
1. **Create Migration Tool**:
   ```bash
   # Create migration command
   book-generator migrate ./one-review-man --to ./books/one-review-man
   ```

2. **Migration Steps**:
   - Extract `_data/` to book configuration files
   - Move `_chapters/` to `content/chapters/`
   - Move `_characters/` to `content/characters/`
   - Convert Jekyll `_config.yml` to book configuration
   - Create `Bookfile` from existing settings

## 🚀 Zero-Breakage Implementation Roadmap

### Phase -1: Decoupling Preparation

**🎯 Goal**: Reduce coupling within existing system to make extraction easier

#### Step 1: Analyze Current Coupling

- [x] **Run coupling analysis**:
```bash
# Find the obvious coupling points
grep -r "YAML.load_file" lib/     # Direct config access
grep -r "_chapters/" lib/         # Hardcoded paths
grep -r "jekyll" lib/             # Jekyll mixed in generation
```
- [x] **Document findings** - list files that need decoupling (see commit _Phase-1-Coupling-Report_)

#### Step 2: Essential Decoupling Tasks

**Task 1: Dependency Injection**
- [x] `ChapterGenerator` now supports injected `llm_service`, `book_data`, `characters`, and `generation_log` while retaining backward-compatible API.
- [x] `Translator` updated. `Reset` now accepts injectable IO stream; non-blocking spec added.

**Task 2: Config Abstraction**
- [x] **Create Config class** (`lib/book/config.rb`) centralises YAML loading; returns empty hash when file missing.
- [x] BookUtils now delegates `load_yaml_file` to `Book::Config`; `LLMService` uses it for its own config loading.
- [x] RSpec `config_spec.rb` verifies empty-hash fallback and parsing behaviour. Existing specs run using the new helper.

**Task 3: Separate Jekyll Output**
- [x] **Split generation from formatting** (initial adapter in place):
  - Introduced `Book::JekyllWriter` (Phase-1 extraction helper) – centralises file writes behind `write_file`/`write_character_page`.
  - `ChapterGenerator` now receives an `output_adapter` dependency (defaulting to `JekyllWriter`) and delegates chapter file creation to it.
  - Behaviour remains identical; this merely decouples IO from generation logic.
  - All update operations (`update_chapter_content`, `update_chapter_with_structured_content`) now rely on adapter helpers (`update_body`, `update_front_matter_and_body`).
- [x] **Test after change** - minimal RSpec added (`spec/dependency_injection_spec.rb`) with `MockLLMService` confirms injected service is used by `ChapterGenerator` and `Translator`.

**Task 4: Prompt Abstraction (NEW)**
- [x] Create `PromptProvider` with layered look-up (`./prompts` → core templates)
- [x] Inject `prompt_provider:` into generators; default to new provider
- [x] Remove hard-coded template file paths; generators use provider
- [x] Unit tests for provider & updated generators; specs inject mock provider
- [x] Validation script MUST rely on injected provider (no monkey-patching)

Phase-1 success criteria add-on: “Prompt access centralised & injectable; validation script uses injection, not monkey-patch.”

#### Step 3: Phase -1 Validation
- [x] **Run validation script** - `bin/validate-refactoring` (create if needed)
- [x] **Manual test** - generate a chapter and verify it looks correct
- [ ] **Commit changes** - only after validation passes

#### **Phase -1 Success Criteria**
Before moving to Phase 0, ensure:
- [x] **Zero behavior change** - all outputs identical
- [x] **Clean interfaces** - no direct file system access in core logic
- [x] **Dependency injection** - all hard dependencies parameterized
- [x] **Separated concerns** - generation logic independent of Jekyll
- [x] **Configuration abstraction** - centralized config access
- [x] **Reduced coupling** - classes can be instantiated independently

#### **Benefits of Phase -1**
1. **Easier Extraction**: Loosely coupled code extracts cleanly
2. **Safer Testing**: Independent components can be tested in isolation  
3. **Cleaner Interfaces**: Well-defined boundaries make wrapping simpler
4. **Reduced Risk**: Smaller changes with immediate validation
5. **Better Understanding**: Forces us to understand current dependencies

**🔑 Key Principle**: Phase -1 changes are **internal refactoring only**. The CLI interface, file outputs, and user experience remain 100% identical.

### Phase 0: Simple Test Setup

**🎯 Goal**: Create basic safety net with minimal overhead

#### Step 1: Mock AI Setup

- [x] **Create test directory structure**:
```bash
mkdir -p test/support
```
- [x] **Create mock AI responses**:
```bash
cat > test/support/mock_responses.yml << EOF
chapter_1: "Alex looked at the pull request with his usual skepticism..."
chapter_2: "The code review session began with Sarah's presentation..."
EOF
```
- [x] **Create mock LLM service**:
```ruby
# lib/test_support/mock_llm_service.rb
class MockLLMService  
  def generate_text(prompt:, context: {})
    responses = YAML.load_file('test/support/mock_responses.yml')
    chapter_num = prompt.match(/chapter (\d+)/i)&.captures&.first || "1"
    responses["chapter_#{chapter_num}"] || "Mock chapter content for testing"
  end
end
```
- [x] **Test mock service** - ensure it returns consistent responses

#### Step 2: Validation Script

- [x] **Create validation script** `bin/validate-refactoring`:
```bash
#!/bin/bash
# bin/validate-refactoring - Essential validation only

export MOCK_AI=true

echo "Testing with old system..."
LEGACY_MODE=true bin/book generate 1
old_chapter=$(cat _chapters/001-chapter.md)

echo "Testing with new system..."  
LEGACY_MODE=false bin/book generate 1
new_chapter=$(cat _chapters/001-chapter.md)

# Compare structure (not exact content)
if [[ "$old_chapter" =~ ^---.*layout:\ chapter ]] && [[ "$new_chapter" =~ ^---.*layout:\ chapter ]]; then
  echo "✅ Both have Jekyll front matter"
else
  echo "❌ Front matter differs"
  exit 1
fi

if [[ ${#old_chapter} -gt 500 ]] && [[ ${#new_chapter} -gt 500 ]]; then
  echo "✅ Both have substantial content"
else
  echo "❌ Content length differs significantly"  
  exit 1
fi

echo "🎉 Basic validation passed"
```
- [x] **Make script executable** - `chmod +x bin/validate-refactoring`
- [x] **Test validation script** - ensure it works correctly

#### Step 3: Phase 0 Validation
- [x] **Run validation script** - should pass with mock AI
- [x] **Manual test** - generate chapter with mock AI and verify structure
- [ ] **Commit changes** - only after validation passes

### Phase 1: Extract Core Components

**🎯 Goal**: Extract one component at a time, validate after each

#### Step 1: Extract Chapter Generator

- [x] **Create new namespace** to avoid conflicts:
```ruby
module BookCore
  class ChapterGenerator
    def generate(num)
      # Move existing logic here, identical behavior
    end
  end
end
```
- [x] **Update CLI** to use new generator with feature flag:
```ruby
ENV['USE_NEW_CORE'] == 'true' ? BookCore::ChapterGenerator : Book::ChapterGenerator
```
- [x] **Test extraction** - `USE_NEW_CORE=true bin/validate-refactoring`
- [ ] **Commit changes** - only after validation passes

#### Step 2: Extract Configuration
```ruby
module BookCore
  class Config < Book::Config; end
end
```
- [x] Create wrapper in new namespace
- [x] Update existing code to use new config (Translator, BookUtils, specs)
- [x] Validate behaviour (all specs pass)

#### Step 3: Extract LLM Service
```ruby
module BookCore
  class LLMService < ::LLMService; end
end
```
- [x] Create wrapper class
- [x] Update injection points (Translator, BookUtils)
- [ ] Validate with mocked & real AI

**Final validation**: All components extracted and working with new core

### Phase 2: Jekyll Adapter

**🎯 Goal**: Separate Jekyll output logic

#### Step 1: Create Simple Jekyll Adapter
**Status: completed (thin wrapper BookCore::JekyllAdapter; new core is the default and only path).**
```ruby
# Simple Jekyll output handler
module BookCore
  class JekyllAdapter
    def write_chapter(number, content, metadata = {})
      front_matter = {
        'layout' => 'chapter',
        'title' => "Chapter #{number}",
        **metadata
      }.to_yaml
      
      jekyll_content = "#{front_matter}---\n#{content}"
      filename = "_chapters/#{format('%03d', number)}-chapter.md"
      File.write(filename, jekyll_content)
    end
    
    def write_character(character_data)
      # Similar Jekyll output for characters
    end
  end
end
```

#### Step 2: Integration  
**Status: completed – CLI flow (via BookCore::ChapterGenerator) now calls the fully-featured JekyllAdapter which sets up project directories and handles all writes.**
```ruby
# Update CLI to use adapter
class CLI
  def generate(chapter_num)
    content = BookCore::ChapterGenerator.new.generate(chapter_num)
    BookCore::JekyllAdapter.new.write_chapter(chapter_num, content)
  end
end
```

**Validation**: Site builds identically (validated via `bin/validate-refactoring` and full RSpec suite).

### Phase 3: Content Migration  
**Status: ✅ Completed – core code, Jekyll adapter, and book data are now in their respective package folders. Compatibility symlinks keep legacy paths working; specs and validation remain green.**

```bash
# Directories now exist in the repo
packages/book-generator-core/lib/book_generator
packages/book-generator-jekyll/lib/book_generator
books/one-review-man
```

# The actual file moves will happen after path refactor (see next step).

#### Step 2: Update References  
**Status: completed – CLI and specs now load `book_core/*` from `packages/book-generator-core` and `book_generator/jekyll_adapter` wrapper.**

All tests and validation script pass after the update.

```ruby
# main CLI (lib/book/cli.rb)
core_lib = File.expand_path('../../../packages/book-generator-core/lib', __dir__)
$LOAD_PATH.unshift(core_lib) unless $LOAD_PATH.include?(core_lib)
require 'book_core/chapter_generator'

# Jekyll adapter wrapper
require 'book_generator/jekyll_adapter'
```

**Validation**: Everything works – specs green & validation passed.

---

### Phase 4: Polish & Documentation (NEXT)

1. **Package README & Docs**  
   – `packages/book-generator-core/README.md` (API, dependency injection).  
   – `packages/book-generator-jekyll/README.md` (site template, build script).  
   – Root `README.md` explaining monorepo layout.

2. **Gem Scaffolding**  
   – Add `book-generator-core.gemspec`, `book-generator-jekyll.gemspec`.  
   – Move package-specific deps from root Gemfile into gemspecs.  
   – Provide `rake build` tasks.

3. **Site Template Finalisation**  
   – Move `_layouts/`, `_includes/`, `_sass/`, `assets/` into `packages/book-generator-jekyll/site_template/`.  
   – Keep symlinks to `books/one-review-man/content/...`.

4. **Cleanup & Deprecation**  
   – Remove root-level Jekyll folders once template path is in use.  
   – Drop legacy load-path shims after public release.

5. **CI / Release**  
   – Ensure each gem’s specs run in isolation.  
   – Maintain monorepo integration suite.  
   – Tag v1.0 for both gems; publish to RubyGems.

#### Phase 4 Detailed Repository Shuffle (zero-breakage)

| Phase | Goal | Concrete actions |
|-------|------|------------------|
| A – Skeleton | Prepare directories | 1) `mkdir book-generator jekyll-site`  2) Move `packages/book-generator-core/*` → `book-generator/`  3) Move `packages/book-generator-jekyll/*` → `jekyll-site/`  4) Copy root Jekyll assets (`_layouts`, `_includes`, `_sass`, `assets`, `_config.yml`) into `jekyll-site/site_template/` |
| B – Specs | Relocate tests | 5) Move generator specs into `book-generator/spec/`  6) Move adapter specs into `jekyll-site/spec/`  7) Add `$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))` in each package’s `spec_helper.rb` |
| C – Gemspecs | Stub gem metadata | 8) Create `book-generator/book-generator.gemspec`  9) Create `jekyll-site/jekyll-site.gemspec`  10) Point root `Gemfile` to both gems via `path:` |
| D – Symlinks | Link book data into template | 11) Inside `jekyll-site/site_template/` add symlinks to `books/one-review-man` for `_chapters`, `_characters`, `_data` |
| E – Safety net | Verify nothing broke | 12) `bundle exec rspec` (all)  13) `bin/validate-refactoring`  14) Manual `jekyll-site/site_template/build_site.sh` |
| F – Cleanup | Remove old paths | 15) Delete `packages/**` legacy dirs & root Jekyll folders  16) Remove temporary symlinks from repo root when confirmed unused |

All phases must keep tests & validation green before proceeding to the next.

---
