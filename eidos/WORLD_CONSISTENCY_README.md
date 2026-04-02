# World Consistency System - Planned Feature

**⚠️ STATUS: This is a planned feature that has not been implemented yet.**

This document describes a proposed system for maintaining world-building consistency across chapters using Ruby.

## Problem Solved

Previously chapters created inconsistent world details:
- Chapter 1: "HeroTech Solutions" ✅
- Chapter 3: "CodeFlow Inc." ❌ → **Fixed to "HeroTech Solutions"**

## Proposed Implementation

### Files to be Created/Modified:

1. **`data/world.yml`** - World data storage (following existing character system pattern)
2. **`lib/book_core/world_utils.rb`** - World consistency utilities module
3. **`lib/book_core/book_utils.rb`** - Add `load_world_data()` method
4. **`lib/book_core/chapter_generator.rb`** - Integrate world consistency into prompts
5. **`lib/book_core/world_analyzer.rb`** - Analysis tool for consistency checking
6. **`lib/book_core/prompts/chapter_prompts.txt`** - Update with world placeholders & rules

### Proposed Integration with Ruby System:

The `ChapterGenerator` would automatically include world consistency:

```ruby
# In lib/book_core/chapter_generator.rb
include WorldUtils

def build_chapter_prompt(chapter_num, characters)
  # ... existing code ...
  
  # Build world consistency context
  world_context = build_world_context
  
  placeholders = {
    # ... existing placeholders ...
  }.merge(world_context) # Add world consistency placeholders
end
```

## Proposed Usage (CLI Commands)

### Generate chapters with world consistency:
```bash
book generate chapter  # Would include world consistency when implemented
book generate prompt 4  # Would show prompt with world context
```

### Analyze world consistency (planned):
```bash
book analyze world --summary
book analyze world --chapter content/chapters/003-chapter.md
book analyze world --all
```

### Proposed world data management:
The world data would be stored in `data/world.yml` following the existing pattern:
```yaml
en:
  world:
    company:
      name: HeroTech Solutions
      description: "A small but ambitious startup nestled between..."
    locations:
      # ... etc
```

**Note:** Some books already have `data/world.yml` files created by the `book init` command.

## Ruby Modules Used

### Proposed `WorldUtils` module:
- `build_world_context()` - Would format world data for prompt placeholders
- `analyze_chapter_consistency()` - Would analyze chapters for issues
- `fix_chapter_consistency()` - Would apply fixes

### `BookUtils` module (planned extension):
- `load_world_data(lang = 'en')` - Would load world data with language support

**Current Status:** Basic world data loading may exist, but the full consistency system is not implemented.

## Planned Integration

🚧 **Implementation Required**

Once implemented, the existing workflow would automatically include world consistency:

- `book generate chapter` - Would use world context
- World consistency rules would be enforced via prompt template
- Analysis tools would be available for chapter review

## Example Output

When generating prompts, you'll now see:

```
WORLD CONSISTENCY (CRITICAL):
- Company Name: HeroTech Solutions
- Office Environment: A small but ambitious startup nestled between...
- Established Locations: 
  - HeroTech Solutions Office: Casual tech startup office...
  - Server Room: Room with blinking lights...
- Infrastructure Details:
  - Ancient Legacy Codebase: Pre-Git legacy system...
  - Production Environment: Critical production systems...

WORLD CONSISTENCY RULES (CRITICAL):
- ALWAYS use "HeroTech Solutions" as the company name
- Maintain the established office environment and nearby locations
- Reference previously established infrastructure
...
```

## Planned Benefits

🚧 **Pure Ruby implementation** (would match project language)  
🚧 **Seamless integration** with existing `ChapterGenerator`  
🚧 **No workflow changes** - just better consistency  
🚧 **Follow existing patterns** - use same data structure as characters  
🚧 **CLI analysis tools** - integrated into main CLI  
🚧 **Automatic prompt injection** - no manual steps required  

## Implementation Notes

- Would use pure Ruby implementation following existing patterns
- Would integrate with `BookUtils`, `PromptUtils`, etc.
- Would follow the existing CLI command structure
- Currently, world consistency is handled manually through the existing character and metadata systems
