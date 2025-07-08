# Book CLI Tool Implementation Plan

## 🎯 Goals
Create a unified `book` CLI tool that consolidates all existing Ruby scripts into a single, user-friendly command-line interface with consistent help, error handling, and extensibility.

## ✅ Implementation Progress & Roadmap

### 🟢 **COMPLETED** (TDD Implementation)
- ✅ Basic CLI structure with Thor framework
- ✅ Version command (`book --version`)
- ✅ Help system (global, command, and subcommand levels)
- ✅ Chapter generation **FOUNDATION ONLY** (`book generate chapter`)
  - ✅ Directory validation (ensures book project structure)
  - ✅ Basic file creation (stub content only)
  - ✅ Error handling for existing chapters
  - ✅ Support for `--auto` and `--model` options
  - ❌ **MISSING**: Actual LLM integration and content generation
  - ❌ **MISSING**: Proper file naming (should be 001-chapter.md, not 01-chapter-1.md)
  - ❌ **MISSING**: Character selection and creation
  - ❌ **MISSING**: Prompt template system
  - ❌ **MISSING**: World consistency integration
- ✅ Comprehensive test suite with RSpec
- ✅ Executable entry point (`bin/book`)
- 🚨 **CRITICAL**: Test suite runs in actual project directory (UNSAFE)

### 🟡 **IN PROGRESS** (Next TDD Iterations)
- 🔄 Fix test safety issues (use isolated test directories)
- 🔄 Implement actual chapter generation with LLM integration

### 🔴 **TODO** (Prioritized by TDD phases)

#### **Phase 1: Fix Critical Issues & Complete Generate Command** 
- 🚨 **URGENT**: Fix test safety (tests shouldn't touch real project files)
- ❌ Fix chapter file naming pattern (`001-chapter.md` not `01-chapter-1.md`)
- ❌ Real LLM integration for chapter generation (migrate from `generate_chapter.rb`)
- ❌ Prompt template system and loading
- ❌ Character selection and creation system
- ❌ World consistency integration
- ❌ Structured chapter data generation
- ❌ Chapter improvement functionality
- ❌ Chapter regeneration functionality

#### **Phase 2: Configuration System**
- ❌ Config command (`book config`)
- ❌ Configuration file handling (`~/.book_config.yml`)
- ❌ Environment variable support
- ❌ Project-specific config override

#### **Phase 3: Translation Commands**
- ❌ Translate command foundation (`book translate`)
- ❌ Language detection and management
- ❌ Translation status tracking
- ❌ Metadata synchronization

#### **Phase 4: Advanced Features**
- ❌ Improve command (`book improve`)
- ❌ World consistency tools (`book world`)
- ❌ Reset functionality (`book reset`)

#### **Phase 5: Polish & UX**
- ❌ Progress indicators
- ❌ Colored output
- ❌ Enhanced error messages
- ❌ Verbose/quiet modes

## 📋 Current Script Analysis

**Existing Scripts to Migrate:**
- `generate_chapter.rb` (803 lines) - Chapter generation with AI
- `translate_content.rb` (768 lines) - Translation management  
- `reset_book.rb` (376 lines) - Book reset utilities
- `analyze_world_consistency.rb` (219 lines) - World consistency analysis

**Utility Libraries:**
- `book_utils.rb` (440 lines) - Shared utilities
- `llm_service.rb` (899 lines) - OpenAI integration
- `world_utils.rb` (222 lines) - World consistency utilities
- `prompt_utils.rb` (93 lines) - Prompt management

## 🏗️ Architecture Design

### 1. Command Structure ✅ **IMPLEMENTED**
```bash
book <command> <subcommand> [options] [arguments]

# Primary Commands:
book generate chapter [options]        # ✅ DONE
book improve chapter <number> <aspect> # ❌ TODO
book translate [language] [options]    # ❌ TODO
book reset [options]                   # ❌ TODO
book world analyze [options]           # ❌ TODO
book config [key] [value]              # ❌ TODO
book help [command]                    # ✅ DONE
```

### 2. File Structure (Current vs Planned)
```
bin/
  book                           # ✅ Main executable entry point

lib/
  book/                          # ✅ CURRENT STRUCTURE
    cli.rb                       # ✅ Main CLI router and argument parser
    cli/
      version.rb                 # ✅ Version management
    utils/                       # ❌ TODO: Move utility files here

  book_cli/                      # ❌ PLANNED STRUCTURE (for migration)
    commands/
      base_command.rb            # ❌ Base class for all commands
      generate_command.rb        # ❌ Chapter generation (from generate_chapter.rb)
      improve_command.rb         # ❌ Content improvement
      translate_command.rb       # ❌ Translation (from translate_content.rb)
      reset_command.rb          # ❌ Reset operations (from reset_book.rb)
      world_command.rb          # ❌ World consistency (from analyze_world_consistency.rb)
      config_command.rb         # ❌ Configuration management
    utils/
      book_utils.rb             # ❌ Moved from scripts/
      llm_service.rb            # ❌ Moved from scripts/
      world_utils.rb            # ❌ Moved from scripts/
      prompt_utils.rb           # ❌ Moved from scripts/
```

### 3. CLI Framework Choice ✅ **COMPLETED**
**✅ Thor Implementation** - Successfully chosen for:
- ✅ Excellent subcommand support (Git-like interface)
- ✅ Automatic help generation
- ✅ Built-in option parsing with type validation
- ✅ Error handling and user-friendly output
- ✅ Ruby standard for CLI tools

## 🔧 Implementation Phases & TDD Progress

### Phase 1: Foundation Setup ✅ **COMPLETED**
1. **✅ Create basic CLI structure**
   - ✅ `bin/book` executable entry point
   - ✅ `lib/book/cli.rb` main router
   - ✅ `lib/book/cli/version.rb` version management
   - ✅ Basic Thor integration

2. **❌ Migrate utility libraries** - NEXT PRIORITY
   - ❌ Move utility files to `lib/book/utils/`
   - ❌ Update require paths
   - ❌ Ensure no breaking changes

### Phase 2: Command Migration 🔄 **IN PROGRESS**
1. **🔄 Generate Command** (`book generate`) - PARTIAL
   ```bash
   book generate chapter [number]           # ✅ Basic file creation
   book generate chapter --auto             # ✅ Auto-numbering
   book generate chapter --model gpt-4o     # ✅ Model option parsing
   book generate prompt [number]            # ❌ Stub only - needs implementation
   ```

2. **❌ Translate Command** (`book translate`) - TODO
   ```bash
   book translate chapter <number> <lang>   # ❌ Translate specific chapter
   book translate all-chapters <lang>       # ❌ Translate all chapters
   book translate status <lang>             # ❌ Show translation status
   book translate sync <number> <lang>      # ❌ Sync metadata
   ```

3. **❌ Reset Command** (`book reset`) - TODO
   ```bash
   book reset --confirm                     # ❌ Reset entire book
   book reset chapter <number>              # ❌ Reset specific chapter
   book reset metadata                      # ❌ Reset only metadata
   ```

### Phase 3: Enhanced Commands ❌ **TODO**
1. **❌ Improve Command** (`book improve`)
2. **❌ World Command** (`book world`)
3. **❌ Config Command** (`book config`)

### Phase 4: Polish & Enhancement ❌ **TODO**
1. **❌ Enhanced Help System** (basic version ✅ done)
2. **❌ Configuration Management**
3. **❌ Progress Indicators & Output**

## 🎯 Next TDD Iteration Priorities

### **Immediate Next Steps** (Choose One):

#### 🥇 **Option A: Complete Generate Command**
```ruby
# Write tests for:
# 1. Prompt loading and display
# 2. AI integration for actual content generation
# 3. Context awareness (previous chapters, characters)

# Test cases to write:
it 'loads and displays chapter generation prompt'
it 'generates actual content with AI'
it 'includes context from previous chapters'
it 'respects character consistency'
```

#### 🥈 **Option B: Config Management Foundation**
```ruby
# Write tests for:
# 1. Config file creation and reading
# 2. Setting and getting config values
# 3. Environment variable support

# Test cases to write:
it 'creates default config file'
it 'sets and gets configuration values'
it 'supports environment variable overrides'
```

#### 🥉 **Option C: Utility Migration**
```ruby
# Write tests for:
# 1. Moving existing utility files
# 2. Updating require paths
# 3. Maintaining backward compatibility

# Test cases to write:
it 'loads book utilities correctly'
it 'maintains LLM service functionality'
it 'preserves existing script compatibility'
```

## 🧪 Testing Status

### ✅ **Existing Test Coverage**
- ✅ CLI version functionality (`spec/cli_spec.rb`)
- ✅ Help system comprehensive testing (`spec/help_system_spec.rb`)
- ✅ Chapter generation with edge cases (`spec/chapter_generation_spec.rb`)
- ✅ Generate command options (`spec/generate_command_spec.rb`)

### 📊 **Test Statistics**
- **Total Tests**: 17 examples
- **Passing**: 17 ✅
- **Failing**: 0 ❌
- **Coverage**: Foundation features fully tested

### 🎯 **Test Gaps to Address**
- ❌ AI integration testing (mocked LLM responses)
- ❌ Configuration management tests
- ❌ File system utility tests
- ❌ Integration tests with existing scripts

## 🎨 Command Examples

### Chapter Generation ✅ **WORKING**
```bash
# ✅ Generate next chapter with default settings
book generate chapter

# ✅ Generate specific chapter with custom model
book generate chapter 5 --model gpt-4o --auto

# ❌ Show prompt that would be used (stub only)
book generate prompt 3
```

### Translation Workflow ❌ **TODO**
```bash
# ❌ Translate chapter 2 to Russian
book translate chapter 2 ru

# ❌ Check what needs translation
book translate status ru

# ❌ Translate everything at once
book translate all-chapters ru
```

### Content Improvement ❌ **TODO**
```bash
# ❌ Make chapter 1 funnier
book improve chapter 1 humor

# ❌ Improve clarity of chapter 3
book improve chapter 3 clarity

# ❌ Ensure consistency in chapter 2
book improve chapter 2 consistency
```

### World Consistency ❌ **TODO**
```bash
# ❌ Analyze world consistency
book world analyze

# ❌ Quick consistency check
book world check --chapter 2

# ❌ Generate detailed report
book world report --output consistency_report.txt
```

## 🔨 Technical Implementation Details

### 1. Base Command Pattern ✅ **IMPLEMENTED**
```ruby
# Current working implementation in lib/book/cli.rb
class Generate < Thor
  # ✅ Working with proper option parsing
  # ✅ Error handling and validation
  # ✅ File creation and directory management
end
```

### 2. Error Handling Strategy ✅ **IMPLEMENTED**
- ✅ Consistent error messages across all commands
- ✅ Helpful suggestions for common mistakes (directory validation)
- ✅ Graceful degradation for missing dependencies

### 3. Configuration Hierarchy ❌ **TODO**
1. Command-line options (highest priority) - ✅ Working
2. Project config file (`.book_config.yml`) - ❌ TODO
3. User config file (`~/.book_config.yml`) - ❌ TODO
4. Environment variables - ❌ TODO
5. Default values (lowest priority) - ✅ Working

### 4. Testing Strategy ✅ **IMPLEMENTED**
- ✅ Unit tests for each command class
- ✅ Integration tests for CLI interface
- ❌ Mock LLM responses for consistent testing - TODO

## 🚀 Migration Strategy

### 1. Backward Compatibility ❌ **TODO**
- ❌ Keep existing scripts working during transition
- ❌ Add deprecation warnings to old scripts
- ❌ Provide migration guide for users

### 2. Gradual Rollout 🔄 **IN PROGRESS**
- ✅ Start with most-used commands (`generate` foundation)
- 🔄 Add remaining commands incrementally
- ❌ Remove old scripts only after full CLI is tested

### 3. Documentation Updates ❌ **TODO**
- ❌ Update all README files with new CLI usage
- ❌ Create comprehensive CLI help system
- ❌ Provide migration examples

## 📚 CLI Help System Design ✅ **IMPLEMENTED**

**✅ Requirement Met: Every command and subcommand has comprehensive help available via both `help` subcommand and `--help` flag.**

### Hierarchical Help Structure ✅ **WORKING**
```bash
# ✅ Global help
book help
book --help

# ✅ Command help  
book generate help
book generate --help

# ✅ Subcommand help
book generate chapter --help
```

### ✅ Implementation Status
- ✅ Consistent format across all help messages
- ✅ Progressive disclosure (detailed help at each level)
- ✅ Dual access (both `help` and `--help` work)
- ✅ Context-aware help with examples
- ✅ Proper Thor integration

## 🎯 Success Criteria

### 1. User Experience
- ✅ Single command entry point (`book`)
- ✅ Consistent interface across all operations (Thor-based)
- ✅ Helpful error messages and suggestions (directory validation)

### 2. Maintainability
- ✅ Clean separation of concerns (Thor subcommands)
- ✅ Easy to add new commands (Thor pattern established)
- ✅ Comprehensive test coverage (17 tests passing)

### 3. Backward Compatibility
- ❌ All existing functionality preserved - TODO
- ❌ Smooth migration path from old scripts - TODO

### 4. Documentation
- ✅ Built-in help system (comprehensive Thor help)
- ❌ Updated README and guides - TODO
- ❌ Clear migration instructions - TODO

---

## 🔄 **CRITICAL TDD FINDINGS & NEXT STEPS**

### 🚨 **Issues Found & Fixed**
1. **✅ FIXED**: Test safety issue - tests now run in isolated temp directories
2. **✅ IDENTIFIED**: Wrong file naming pattern (`01-chapter-1.md` vs `001-chapter.md`)
3. **✅ IDENTIFIED**: Missing LLM integration (just stub content)
4. **✅ DOCUMENTED**: 5 major missing features in test suite

### 🎯 **Accurate Current Status**
- **CLI Foundation**: ✅ Solid and working
- **Chapter Generation**: ❌ **STUB ONLY** - needs complete rewrite
- **Test Suite**: ✅ Safe and comprehensive (12 tests, 0 failures, 5 pending)

### 🚀 **RECOMMENDED NEXT TDD SESSION**

**Priority: Complete Real Chapter Generation**

1. **Fix File Naming Pattern** (Quick Win)
   ```ruby
   # Change from: 01-chapter-1.md  
   # To: 001-chapter.md (match existing script)
   ```

2. **Migrate LLM Integration** (Core Feature)
   ```ruby
   # Write tests for:
   it 'integrates with LLMService for content generation'
   it 'loads and uses prompt templates'
   it 'generates structured chapter data'
   
   # Then implement by extracting from generate_chapter.rb:
   # - LLMService integration
   # - Prompt template system  
   # - Character selection logic
   ```

3. **Add Character & World Integration** (Advanced)
   ```ruby
   # Extract and adapt from generate_chapter.rb:
   # - Character selection for chapters
   # - World consistency integration
   # - New character creation
   ```

This approach will transform our stub into a real, working chapter generator while maintaining the TDD methodology that caught these critical issues. 
