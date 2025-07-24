# AI Agent Instructions: Zero-Breakage Refactoring

## Overview
You are an AI agent tasked with refactoring the One Review Man project from a monolithic Jekyll site into modular, reusable components. **CRITICAL**: You must preserve 100% of existing behavior at every step.

## Core Principles

### 🛡️ NEVER BREAK EXISTING FUNCTIONALITY
- **Every change must preserve identical behavior**
- **Always test after each modification**  
- **If anything breaks, rollback immediately**
- **The user must be able to generate chapters throughout the refactoring**

### 🧪 Testing Strategy
- **AI content is non-deterministic** - you cannot compare exact text
- **Use mock AI service** for all testing and validation
- **Compare structure and behavior**, not exact content
- **Test format, file structure, and functionality**

### 📁 File Safety
- **Create Git branch** before each major phase
- **Full backup** before starting: `cp -r . ../backup-$(date +%Y%m%d)`
- **Commit frequently** but only after validation passes

## Phase Execution Instructions

### Phase -1: Decoupling Preparation

**Objective**: Reduce coupling in existing codebase to make extraction easier.

**Step 1: Analyze Current Coupling**
1. Run coupling analysis commands:
   ```bash
   grep -r "YAML.load_file" lib/     # Direct config access
   grep -r "_chapters/" lib/         # Hardcoded paths  
   grep -r "jekyll" lib/             # Jekyll mixed in generation
   ```
2. Document findings in a comment or file
3. Identify which classes need decoupling

**Step 2: Essential Decoupling Tasks**

**Task 1: Dependency Injection**
- Modify classes to accept dependencies as parameters
- Preserve existing defaults to maintain behavior
- Example pattern:
  ```ruby
  def initialize(llm_service: nil, config: nil)
    @llm_service = llm_service || LLMService.new  # Same default
    @config = config || Config.new                # Same default
  end
  ```
- Test after each class modification

**Task 2: Config Abstraction**  
- Create centralized Config class for YAML access
- Replace scattered `YAML.load_file` calls with config object
- Ensure identical data is returned
- Test after each change

**Task 3: Separate Jekyll Output**
- Split content generation from Jekyll formatting
- Create separate classes for generation vs Jekyll output
- Maintain identical file outputs
- Test after each change

**Step 3: Phase -1 Validation**
- Create/run validation script to compare old vs new behavior
- Manual test: generate a chapter and verify it looks correct
- Commit changes only after validation passes

### Phase 0: Simple Test Setup

**Objective**: Create basic safety net with mock AI service.

**Step 1: Mock AI Setup**
1. Create test directory structure: `mkdir -p test/support`
2. Create mock AI responses file with sample chapter content
3. Create MockLLMService class that returns consistent responses
4. Test mock service to ensure it works

**Step 2: Validation Script**
1. Create `bin/validate-refactoring` script
2. Script should:
   - Use mock AI for consistent results
   - Generate content with old and new systems
   - Compare structure (front matter, length, character presence)
   - Report success/failure clearly
3. Test the validation script works

### Phase 1: Extract Core Components

**Objective**: Extract functionality into new BookCore namespace while preserving behavior.

**Step 1: Extract Chapter Generator**
1. Create new `BookCore` namespace to avoid conflicts
2. Move chapter generation logic to `BookCore::ChapterGenerator`
3. Update CLI to use new generator with feature flag
4. Validate with `USE_NEW_CORE=true bin/validate-refactoring`

**Step 2: Extract Configuration**
1. Create `BookCore::Config` class
2. Move all configuration logic to new class
3. Update existing code to use new config
4. Validate behavior remains identical

**Step 3: Extract LLM Service**
1. Create `BookCore::LLMService` with mock/real service switching
2. Abstract AI service behind clean interface
3. Update existing code to use new service
4. Validate with both mock and real AI

### Phase 2: Jekyll Adapter

**Objective**: Separate Jekyll-specific output logic.

**Step 1: Create Jekyll Adapter**
1. Create `BookCore::JekyllAdapter` class
2. Move all Jekyll-specific formatting to adapter
3. Ensure identical file outputs (front matter, content structure)
4. Test that Jekyll site builds identically

**Step 2: Integration**
1. Update CLI to use adapter for all Jekyll output
2. Verify all generated files are identical
3. Test complete site build process

### Phase 3: Content Migration  

**Objective**: Organize into final modular structure.

**Step 1: Package Structure**
1. Create package directories: `packages/book-generator-core/`, etc.
2. Move extracted components to appropriate packages
3. Move book-specific data to `books/one-review-man/`
4. Update require paths

**Step 2: Update References**
1. Update all require statements to use new package structure
2. Test that everything still works from new locations
3. Validate complete functionality

### Phase 4: Polish & Documentation

**Objective**: Clean up and document the new system.

**Step 1: Documentation**
1. Create README files for each package
2. Document the new API
3. Add basic usage examples

**Step 2: Error Handling**
1. Add basic error handling to core components
2. Ensure graceful failure modes
3. Test error scenarios

**Step 3: Final Validation**
1. Run complete validation test
2. Generate a full chapter with new system
3. Verify Jekyll site builds correctly
4. Commit final working state

## Critical Validation Requirements

After **every** change:
1. **Test existing functionality** - ensure it still works
2. **Run validation script** - compare old vs new behavior  
3. **Manual spot-check** - generate content and verify it looks right
4. **Only commit if validation passes**

## Emergency Procedures

**If anything breaks:**
1. **STOP immediately**
2. **Rollback to last working state**: `git checkout HEAD~1`
3. **Analyze what went wrong**
4. **Try a smaller, safer approach**

**If you get stuck:**
1. **Document the issue**
2. **Ask for human guidance**
3. **Don't proceed if unsure**

## Success Criteria

**Phase -1 Complete:**
- [ ] Dependencies are injectable
- [ ] Config is centralized
- [ ] Jekyll output is separated
- [ ] Validation script passes
- [ ] Manual test generates correct chapter

**Phase 0 Complete:**
- [ ] Mock AI service works
- [ ] Validation script functional
- [ ] Can compare old vs new behavior

**Phase 1 Complete:**
- [ ] Core components extracted to BookCore namespace
- [ ] CLI uses new components via feature flag
- [ ] Behavioral equivalence confirmed

**Phase 2 Complete:**
- [ ] Jekyll adapter handles all output
- [ ] Site builds identically
- [ ] All Jekyll functionality preserved

**Phase 3 Complete:**
- [ ] Files organized in packages structure
- [ ] All references updated
- [ ] System works from new structure

**Phase 4 Complete:**
- [ ] Documentation complete
- [ ] Basic error handling added
- [ ] Final validation passes

## Remember

- **Stability over speed** - take time to validate each step
- **Preserve behavior** - identical outputs are required
- **Test frequently** - after every significant change
- **Ask for help** - if anything is unclear or breaks
- **Document issues** - help future debugging

**The goal is a working modular system, not a fast refactoring. Take your time and be careful.**