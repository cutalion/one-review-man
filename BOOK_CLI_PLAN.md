# Book CLI Tool Implementation Plan

## 🎯 Goals
Create a unified `book` CLI tool that consolidates all existing Ruby scripts into a single, user-friendly command-line interface with consistent help, error handling, and extensibility.

## 📋 Current Script Analysis

**Existing Scripts:**
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

### 1. Command Structure
```bash
book <command> <subcommand> [options] [arguments]

# Primary Commands:
book generate chapter [options]
book improve chapter <number> <aspect>
book translate [language] [options]
book reset [options]
book world analyze [options]
book config [key] [value]
book help [command]
```

### 2. File Structure
```
bin/
  book                           # Main executable entry point

lib/
  book_cli/
    cli.rb                       # Main CLI router and argument parser
    version.rb                   # Version management
    config.rb                    # Configuration management
    commands/
      base_command.rb            # Base class for all commands
      generate_command.rb        # Chapter generation (from generate_chapter.rb)
      improve_command.rb         # Content improvement
      translate_command.rb       # Translation (from translate_content.rb)
      reset_command.rb          # Reset operations (from reset_book.rb)
      world_command.rb          # World consistency (from analyze_world_consistency.rb)
      config_command.rb         # Configuration management
    utils/
      book_utils.rb             # Moved from scripts/
      llm_service.rb            # Moved from scripts/
      world_utils.rb            # Moved from scripts/
      prompt_utils.rb           # Moved from scripts/
```

### 3. CLI Framework Choice
**Recommendation: Thor** for the following reasons:
- Excellent subcommand support (Git-like interface)
- Automatic help generation
- Built-in option parsing with type validation
- Error handling and user-friendly output
- Ruby standard for CLI tools

## 🔧 Implementation Phases

### Phase 1: Foundation Setup
1. **Create basic CLI structure**
   - `bin/book` executable entry point
   - `lib/book_cli/cli.rb` main router
   - `lib/book_cli/version.rb` version management
   - Basic Thor integration

2. **Migrate utility libraries**
   - Move utility files to `lib/book_cli/utils/`
   - Update require paths
   - Ensure no breaking changes

### Phase 2: Command Migration
1. **Generate Command** (`book generate`)
   ```bash
   book generate chapter [number]           # Generate specific chapter
   book generate chapter --auto             # Auto-generate next chapter
   book generate chapter --model gpt-4o     # Use specific model
   book generate prompt [number]            # Show generation prompt
   ```

2. **Translate Command** (`book translate`)
   ```bash
   book translate chapter <number> <lang>   # Translate specific chapter
   book translate all-chapters <lang>       # Translate all chapters
   book translate status <lang>             # Show translation status
   book translate sync <number> <lang>      # Sync metadata
   ```

3. **Reset Command** (`book reset`)
   ```bash
   book reset --confirm                     # Reset entire book
   book reset chapter <number>              # Reset specific chapter
   book reset metadata                      # Reset only metadata
   ```

### Phase 3: Enhanced Commands
1. **Improve Command** (`book improve`)
   ```bash
   book improve chapter <number> humor      # Make chapter funnier
   book improve chapter <number> clarity    # Improve readability
   book improve chapter <number> consistency # Ensure consistency
   ```

2. **World Command** (`book world`)
   ```bash
   book world analyze                       # Analyze consistency
   book world check                         # Quick consistency check
   book world report                        # Generate detailed report
   ```

3. **Config Command** (`book config`)
   ```bash
   book config list                         # Show all configuration
   book config get <key>                    # Get specific config value
   book config set <key> <value>            # Set configuration value
   book config reset                        # Reset to defaults
   ```

### Phase 4: Polish & Enhancement
1. **Enhanced Help System**
   - Command-specific help with examples
   - Global help with command overview
   - Error messages with suggestions

2. **Configuration Management**
   - Unified config file (`~/.book_config.yml`)
   - Environment variable support
   - Project-specific config override

3. **Progress Indicators & Output**
   - Progress bars for long operations
   - Colored output for status/errors
   - Verbose/quiet modes

## 🎨 Command Examples

### Chapter Generation
```bash
# Generate next chapter with default settings
book generate chapter

# Generate specific chapter with custom model
book generate chapter 5 --model gpt-4o --auto

# Show prompt that would be used
book generate prompt 3
```

### Translation Workflow
```bash
# Translate chapter 2 to Russian
book translate chapter 2 ru

# Check what needs translation
book translate status ru

# Translate everything at once
book translate all-chapters ru
```

### Content Improvement
```bash
# Make chapter 1 funnier
book improve chapter 1 humor

# Improve clarity of chapter 3
book improve chapter 3 clarity

# Ensure consistency in chapter 2
book improve chapter 2 consistency
```

### World Consistency
```bash
# Analyze world consistency
book world analyze

# Quick consistency check
book world check --chapter 2

# Generate detailed report
book world report --output consistency_report.txt
```

## 🔨 Technical Implementation Details

### 1. Base Command Pattern
```ruby
class BaseCommand < Thor
  def self.shared_options
    option :verbose, type: :boolean, desc: "Verbose output"
    option :config, type: :string, desc: "Config file path"
  end
end
```

### 2. Error Handling Strategy
- Consistent error messages across all commands
- Helpful suggestions for common mistakes
- Graceful degradation for missing dependencies

### 3. Configuration Hierarchy
1. Command-line options (highest priority)
2. Project config file (`.book_config.yml`)
3. User config file (`~/.book_config.yml`)
4. Environment variables
5. Default values (lowest priority)

### 4. Testing Strategy
- Unit tests for each command class
- Integration tests for CLI interface
- Mock LLM responses for consistent testing

## 🚀 Migration Strategy

### 1. Backward Compatibility
- Keep existing scripts working during transition
- Add deprecation warnings to old scripts
- Provide migration guide for users

### 2. Gradual Rollout
- Start with most-used commands (`generate`, `translate`)
- Add remaining commands incrementally
- Remove old scripts only after full CLI is tested

### 3. Documentation Updates
- Update all README files with new CLI usage
- Create comprehensive CLI help system
- Provide migration examples

## 📚 CLI Help System Design

**Requirement: Every command and subcommand must have comprehensive help available via both `help` subcommand and `--help` flag.**

### Hierarchical Help Structure
```bash
# Global help
book help
book --help

# Command help  
book generate help
book generate --help

# Subcommand help
book generate chapter help
book generate chapter --help

# All commands support both patterns
book translate help
book translate chapter help
book world analyze help
```

### Global Help
```bash
$ book help
Usage: book <command> [options]

Commands:
  book generate     # Generate content (chapters, prompts)
  book translate    # Manage translations
  book improve      # Improve existing content
  book world        # World consistency tools
  book reset        # Reset book data
  book config       # Configuration management

Global Options:
  --verbose         # Enable verbose output
  --config FILE     # Use custom config file
  --version         # Show version
  --help            # Show this help

Use 'book <command> help' for more information on a specific command.

Examples:
  book generate help           # Show generate command help
  book translate chapter help # Show chapter translation help
```

### Command-Level Help
```bash
$ book generate help
Usage: book generate <subcommand> [options]

Generate content for the book using AI.

Subcommands:
  chapter [NUMBER]    # Generate a specific chapter or next chapter
  prompt [NUMBER]     # Show the prompt that would be used for generation

Options:
  --auto              # Generate without interactive prompts
  --model NAME        # Use specific LLM model (gpt-4o, gpt-4o-mini)
  --output FILE       # Save generated content to specific file
  --verbose           # Show detailed generation process
  --help              # Show this help

Global Options:
  --config FILE       # Use custom config file

Examples:
  book generate chapter           # Generate next chapter interactively
  book generate chapter 5        # Generate chapter 5
  book generate chapter --auto   # Generate next chapter automatically
  book generate prompt 3         # Show prompt for chapter 3

Use 'book generate <subcommand> help' for detailed subcommand help.
```

### Subcommand-Level Help
```bash
$ book generate chapter help
Usage: book generate chapter [NUMBER] [options]

Generate a book chapter using AI. If no NUMBER is provided, generates the next chapter
in sequence. The generation process includes context from previous chapters and
existing characters to maintain story consistency.

Arguments:
  NUMBER              Chapter number to generate (optional, defaults to next)

Options:
  --auto              Generate automatically without interactive prompts
  --model NAME        LLM model to use (gpt-4o, gpt-4o-mini, gpt-4-turbo)
  --output FILE       Save generated content to specific file
  --regenerate        Regenerate existing chapter (overwrites existing content)
  --prompt-only       Show generation prompt without actually generating
  --temperature NUM   Creativity level (0.0-1.0, default from config)
  --max-tokens NUM    Maximum tokens to generate
  --verbose           Show detailed generation process and API calls
  --help              Show this help

Global Options:
  --config FILE       Use custom config file

Examples:
  book generate chapter                    # Generate next chapter interactively
  book generate chapter 5                 # Generate chapter 5
  book generate chapter --auto            # Generate next chapter automatically  
  book generate chapter 3 --regenerate    # Regenerate existing chapter 3
  book generate chapter --model gpt-4o    # Use specific model
  book generate chapter --prompt-only     # Just show the prompt

Configuration:
  The chapter generation uses settings from your LLM config file. You can override
  model, temperature, and token limits with command-line options.

  See 'book config help' for configuration management.
```

### Additional Help Examples
```bash
$ book translate help
Usage: book translate <subcommand> [options]

Manage translations of book content to different languages.

Subcommands:
  chapter <NUM> <LANG>     # Translate specific chapter
  all-chapters <LANG>      # Translate all chapters  
  status <LANG>            # Show translation status
  sync <NUM> <LANG>        # Sync metadata between languages

$ book translate chapter help  
Usage: book translate chapter <NUMBER> <LANGUAGE> [options]

Translate a specific chapter to the target language. The translation preserves
story structure, character relationships, and programming humor while adapting
cultural references appropriately.

$ book world analyze help
Usage: book world analyze [options]

Analyze the consistency of the book's world, characters, and plot elements.
Generates a detailed report of potential inconsistencies and suggestions.

$ book reset help
Usage: book reset [options]

Reset book data with various scopes. Use with caution as this can delete content.

Subcommands:
  book reset --confirm           # Reset entire book (requires confirmation)
  book reset chapter <NUMBER>    # Reset specific chapter
  book reset metadata           # Reset only metadata, keep content
```

### Help System Implementation Notes

1. **Consistent Format**: All help messages follow the same structure:
   - Usage line
   - Description
   - Arguments (if any)
   - Options (command-specific)
   - Global options
   - Examples
   - Additional notes/warnings

2. **Progressive Disclosure**: Help gets more detailed as you drill down:
   - Global help: Overview of all commands
   - Command help: Overview of subcommands and common options
   - Subcommand help: Detailed usage, all options, examples

3. **Dual Access**: Both `help` subcommand and `--help` flag work at every level

4. **Context-Aware**: Help mentions related commands and configuration

5. **Examples Required**: Every help message includes practical examples

## 🎯 Success Criteria

1. **User Experience**
   - Single command entry point
   - Consistent interface across all operations
   - Helpful error messages and suggestions

2. **Maintainability**
   - Clean separation of concerns
   - Easy to add new commands
   - Comprehensive test coverage

3. **Backward Compatibility**
   - All existing functionality preserved
   - Smooth migration path from old scripts

4. **Documentation**
   - Built-in help system
   - Updated README and guides
   - Clear migration instructions

This plan provides a solid foundation for building a professional, user-friendly CLI tool that consolidates all your book management functionality into a single, cohesive interface. 
