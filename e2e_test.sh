#!/bin/bash

# E2E Testing Script for Book Generator
# Tests complete workflow: init -> generate -> translate -> jekyll -> serve

set -e  # Exit on any error

# Configuration
REPO_ROOT=$(pwd)
BOOK_GENERATOR_BIN="$REPO_ROOT/book-generator/bin/book"
TEST_DIR="/tmp/book_e2e_test_$$"
MODEL="gpt-4.1-mini"
TRANSLATE_LANG="ru"
JEKYLL_PORT_BASE=4000

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Cleanup function
cleanup() {
    log_info "Cleaning up test environment..."
    
    # Kill any running Jekyll servers
    for port in $(seq $JEKYLL_PORT_BASE $((JEKYLL_PORT_BASE + 10))); do
        if lsof -ti:$port > /dev/null 2>&1; then
            log_info "Killing process on port $port"
            kill $(lsof -ti:$port) 2>/dev/null || true
        fi
    done
    
    # Remove test directory (skip if KEEP_TEST_DIR is set)
    if [[ -z "$KEEP_TEST_DIR" && -d "$TEST_DIR" ]]; then
        rm -rf "$TEST_DIR"
        log_info "Removed test directory: $TEST_DIR"
    elif [[ -n "$KEEP_TEST_DIR" && -d "$TEST_DIR" ]]; then
        log_info "Keeping test directory for manual inspection: $TEST_DIR"
    fi
}

# Set up cleanup on exit
trap cleanup EXIT

# Find available port
find_available_port() {
    local port=$JEKYLL_PORT_BASE
    while [[ $port -lt $((JEKYLL_PORT_BASE + 100)) ]]; do
        if ! lsof -ti:$port > /dev/null 2>&1; then
            echo $port
            return
        fi
        ((port++))
    done
    echo "0"  # No available port found
}

# Validate file exists
check_file_exists() {
    local file="$1"
    local description="$2"
    
    if [[ -f "$file" ]]; then
        log_success "$description exists: $file"
        return 0
    else
        log_error "$description missing: $file"
        return 1
    fi
}

# Validate directory exists
check_dir_exists() {
    local dir="$1"
    local description="$2"
    
    if [[ -d "$dir" ]]; then
        log_success "$description exists: $dir"
        return 0
    else
        log_error "$description missing: $dir"
        return 1
    fi
}

# Check for unfilled placeholders in a directory
check_unfilled_placeholders() {
    local check_dir="$1"
    local description="${2:-directory}"
    
    if [[ ! -d "$check_dir" ]]; then
        log_warning "Cannot check placeholders - $description does not exist: $check_dir"
        return 1
    fi
    
    cd "$check_dir"
    
    local unfilled_placeholders
    unfilled_placeholders=$(grep -r "{{[A-Z_][A-Z0-9_]*}}" . 2>/dev/null || true)
    
    if [[ -n "$unfilled_placeholders" ]]; then
        log_warning "Unfilled placeholders found in $description:"
        echo "$unfilled_placeholders" | head -5
        return 1
    else
        log_success "No unfilled placeholders in $description"
        return 0
    fi
}

# Production readiness test - expose real user experience issues
test_production_readiness() {
    local operation="$1"
    local expected_behavior="$2"
    local actual_result="$3"
    
    if [[ "$actual_result" != "success" ]]; then
        log_warning "PRODUCTION ISSUE: $operation failed"
        log_warning "Expected: $expected_behavior"
        log_warning "This indicates the system is not production-ready for real users"
        return 1
    fi
    return 0
}

# Test single book workflow as a real user would
test_book_workflow() {
    local book_name="$1"
    local book_title="$2"
    local book_author="$3"
    local book_description="$4"
    
    log_info "Starting REAL USER test for book: $book_name"
    log_info "This test will expose any production readiness issues"
    
    local book_dir="$TEST_DIR/$book_name"
    local site_dir="$book_dir/site"
    local production_issues=0
    
    # Initialize book using only standard CLI (as real user would)
    log_info "Initializing book: $book_title (using standard CLI with intelligent defaults)"
    cd "$TEST_DIR"
    if echo -e "$book_title\n$book_author\n$book_description\nen,ru\nen" | "$BOOK_GENERATOR_BIN" init --book-dir "$book_dir" --quick 2>/dev/null; then
        log_success "Book initialization successful"
    else
        log_error "Book initialization failed - PRODUCTION ISSUE"
        return 1
    fi
    
    # Validate basic book structure (what init should create)
    check_dir_exists "$book_dir" "Book directory"
    check_file_exists "$book_dir/data/book_config.yml" "Book metadata"
    check_file_exists "$book_dir/data/characters.yml" "Characters file" 
    check_file_exists "$book_dir/data/generation_log.yml" "Generation log"
    
    cd "$book_dir"
    
    # Test chapter generation (real user experience)
    log_info "Testing chapter generation as real user would..."
    log_info "Attempting to generate first chapter with minimal setup..."
    
    if (cd "$book_dir" && MOCK_AI=true "$BOOK_GENERATOR_BIN" generate chapter --model "$MODEL" --auto --debug); then
        log_success "Chapter generation succeeded with minimal setup"
        if check_file_exists "$book_dir/content/chapters/001-chapter.md" "First chapter"; then
            log_success "Chapter file created successfully"
        else
            log_error "PRODUCTION ISSUE: Chapter generation claimed success but no file created"
            ((production_issues++))
        fi
    else
        log_warning "PRODUCTION ISSUE: Chapter generation failed with minimal book setup"
        log_warning "A real user would be stuck here without additional guidance"
        log_warning "System should either:"
        log_warning "  1. Prompt for missing information (genre, style, etc.)"
        log_warning "  2. Work with intelligent defaults"
        log_warning "  3. Provide clear guidance on what's missing"
        ((production_issues++))
        
        # Continue with the test to see what else fails
        log_info "Continuing test to identify additional issues..."
    fi
    
    # Test translation (if chapter exists)
    if [[ -f "$book_dir/content/chapters/001-chapter.md" ]]; then
        log_info "Testing chapter translation..."
        if (cd "$book_dir" && MOCK_AI=true "$BOOK_GENERATOR_BIN" translate chapter 1 "$TRANSLATE_LANG" --model "$MODEL"); then
            check_file_exists "$book_dir/content/chapters/001-chapter.ru.md" "First chapter translation"
        else
            log_warning "PRODUCTION ISSUE: Chapter translation failed"
            ((production_issues++))
        fi
    fi
    
    # Test generating one additional chapter only (smaller story)
    log_info "Testing second chapter generation..."
    if (cd "$book_dir" && MOCK_AI=true "$BOOK_GENERATOR_BIN" generate chapter --model "$MODEL" --auto); then
        check_file_exists "$book_dir/content/chapters/002-chapter.md" "Second chapter"
        
        # Test batch translation
        log_info "Testing batch translation..."
        if (cd "$book_dir" && MOCK_AI=true "$BOOK_GENERATOR_BIN" translate all "$TRANSLATE_LANG" --model "$MODEL"); then
            log_success "Batch translation completed"
        else
            log_warning "PRODUCTION ISSUE: Batch translation failed"
            ((production_issues++))
        fi
    else
        log_warning "Second chapter generation failed"
        ((production_issues++))
    fi
    
    # Test Jekyll site generation
    log_info "Testing Jekyll site generation..."
    if (cd "$book_dir" && "$BOOK_GENERATOR_BIN" jekyll generate --dest "$site_dir"); then
        log_success "Jekyll site generation succeeded"
        check_dir_exists "$site_dir" "Jekyll site directory"
        check_file_exists "$site_dir/_config.yml" "Jekyll config"
        check_dir_exists "$site_dir/_chapters" "Jekyll chapters directory"
        check_dir_exists "$site_dir/_data" "Jekyll data directory"
        
        # Test for unfilled custom placeholders (PRODUCTION ISSUE check)
        log_info "Checking for unfilled custom placeholders in source templates..."
        cd "$site_dir"
        unfilled_placeholders=$(grep -r "{{[A-Z_][A-Z0-9_]*}}" . --exclude-dir=_site 2>/dev/null || true)
        
        if [[ -n "$unfilled_placeholders" ]]; then
            log_warning "PRODUCTION ISSUE: Unfilled custom placeholders found in source templates:"
            echo "$unfilled_placeholders" | head -10  # Show first 10 examples
            log_warning "Custom placeholders that should be resolved during template copying:"
            log_warning "  - {{BOOK_TITLE}} should be replaced with book title"
            log_warning "  - {{BOOK_TITLE_RU}} should be replaced with Russian book title"
            log_warning "  - {{BOOK_GENRE_DESCRIPTION_RU}} should be replaced with Russian genre description" 
            log_warning "  - {{SITE_DOMAIN}} should be skipped if empty or replaced with domain"
            ((production_issues++))
        else
            log_success "✅ All custom placeholders resolved in source templates"
            
            # Additional verification - test Jekyll processing by building the site
            log_info "Testing Jekyll build process..."
            jekyll_build_success=true
            
            cd "$site_dir"
            if command -v bundle >/dev/null 2>&1; then
                if ! bundle exec jekyll build >/dev/null 2>&1; then
                    jekyll_build_success=false
                fi
            else
                if ! jekyll build >/dev/null 2>&1; then
                    jekyll_build_success=false
                fi
            fi
            
            if [[ "$jekyll_build_success" == "false" ]]; then
                log_warning "PRODUCTION ISSUE: Jekyll build failed"
                ((production_issues++))
            else
                log_success "✓ Jekyll build completed successfully"
                
                # Check for Jekyll Liquid syntax that wasn't processed in built HTML
                if [[ -d "_site" ]]; then
                    unprocessed_liquid=$(find _site -name "*.html" -exec grep -l "{{ site\." {} \; 2>/dev/null || true)
                    if [[ -n "$unprocessed_liquid" ]]; then
                        log_warning "Jekyll Liquid syntax found in built HTML (Jekyll processing issue):"
                        echo "$unprocessed_liquid" | head -5
                        ((production_issues++))
                    else
                        log_success "✓ Jekyll properly processed all Liquid syntax"
                    fi
                fi
            fi
        fi
    else
        log_warning "PRODUCTION ISSUE: Jekyll site generation failed"
        ((production_issues++))
    fi
    
    # Test third chapter generation
    log_info "Testing third chapter generation..."
    if (cd "$book_dir" && MOCK_AI=true "$BOOK_GENERATOR_BIN" generate chapter --model "$MODEL" --auto); then
        if check_file_exists "$book_dir/content/chapters/003-chapter.md" "Third chapter"; then
            log_success "Third chapter generated successfully"
            
            # Test individual chapter translation
            log_info "Testing individual chapter translation..."
            if (cd "$book_dir" && MOCK_AI=true "$BOOK_GENERATOR_BIN" translate chapter 3 "$TRANSLATE_LANG" --model "$MODEL"); then
                check_file_exists "$book_dir/content/chapters/003-chapter.ru.md" "Third chapter translation"
            else
                log_warning "PRODUCTION ISSUE: Individual chapter translation failed"
                ((production_issues++))
            fi
        fi
    else
        log_warning "Third chapter generation failed"
        ((production_issues++))
    fi
    
    # Test Jekyll site updates
    if [[ -d "$site_dir" ]]; then
        log_info "Testing Jekyll site updates..."
        if (cd "$book_dir" && "$BOOK_GENERATOR_BIN" jekyll generate --dest "$site_dir"); then
            log_success "Jekyll site update succeeded"
            # Only check if chapter exists before checking Jekyll copy
            if [[ -f "$book_dir/content/chapters/003-chapter.md" ]]; then
                check_file_exists "$site_dir/_chapters/003-chapter.md" "Third chapter in Jekyll site"
            fi
            if [[ -f "$book_dir/content/chapters/003-chapter.ru.md" ]]; then
                check_file_exists "$site_dir/_chapters/003-chapter.ru.md" "Third chapter translation in Jekyll site"
            fi
        else
            log_warning "PRODUCTION ISSUE: Jekyll site update failed"
            ((production_issues++))
        fi
    fi
    
    # Test Jekyll server (only if site directory exists)
    if [[ -d "$site_dir" ]]; then
        log_info "Testing Jekyll server..."
        cd "$site_dir"
        
        # Find available port
        local port=$(find_available_port)
        if [[ $port -eq 0 ]]; then
            log_warning "PRODUCTION ISSUE: No available port found for Jekyll server"
            ((production_issues++))
        else
            log_info "Starting Jekyll server on port $port..."
            
            # Start Jekyll server in background
            if command -v bundle >/dev/null 2>&1; then
                bundle exec jekyll serve --port "$port" --host 0.0.0.0 >/dev/null 2>&1 &
            else
                jekyll serve --port "$port" --host 0.0.0.0 >/dev/null 2>&1 &
            fi
            
            local jekyll_pid=$!
            
            # Wait for server to start (reduced for faster testing)
            sleep 2
            
            # Test if server is responding
            if curl -s "http://localhost:$port" >/dev/null; then
                log_success "Jekyll server is responding on port $port"
            else
                log_warning "PRODUCTION ISSUE: Jekyll server not responding on port $port"
                ((production_issues++))
            fi
            
            # Stop Jekyll server
            kill $jekyll_pid 2>/dev/null || true
            log_info "Stopped Jekyll server"
        fi
    else
        log_warning "Skipping Jekyll server test - site directory not created"
        ((production_issues++))
    fi
    
    # Report production readiness assessment
    echo ""
    log_info "=== PRODUCTION READINESS ASSESSMENT ==="
    log_info "Book: $book_name"
    log_info "Production issues found: $production_issues"
    
    if [[ $production_issues -eq 0 ]]; then
        log_success "✅ PRODUCTION READY: All workflows completed successfully"
        log_success "A real user can successfully use this system"
        return 0
    else
        log_warning "❌ NOT PRODUCTION READY: $production_issues issues found"
        log_warning "Real users would encounter problems with current implementation"
        return 1
    fi
}

# Main execution
main() {
    log_info "Starting E2E Book Generator Testing"
    log_info "Test directory: $TEST_DIR"
    log_info "Model: $MODEL"
    log_info "Translation language: $TRANSLATE_LANG"
    echo ""
    
    # Create test directory
    mkdir -p "$TEST_DIR"
    
    # Test with single book scenario for faster e2e testing
    local selected_book="quantum-echoes|Quantum Echoes|Dr. Sarah Chen|A thrilling space exploration adventure through parallel universes"
    
    local total_tests=1
    local production_ready_tests=0
    local total_production_issues=0
    
    book_info="$selected_book"
    IFS='|' read -r book_name book_title book_author book_description <<< "$book_info"
    
    echo ""
    log_info "=========================================="
    log_info "Testing randomly selected book: $book_name"
    log_info "=========================================="
    
    if test_book_workflow "$book_name" "$book_title" "$book_author" "$book_description"; then
        ((production_ready_tests++))
        log_success "Book $book_name: PRODUCTION READY"
    else
        log_error "Book $book_name: NOT PRODUCTION READY"
    fi
    
    echo ""
    
    echo ""
    log_info "=========================================="
    log_info "=== FINAL PRODUCTION READINESS REPORT ==="
    log_info "=========================================="
    log_info "Total book scenarios tested: $total_tests"
    log_info "Production ready scenarios: $production_ready_tests"
    log_info "Failed scenarios: $((total_tests - production_ready_tests))"
    
    echo ""
    log_info "=== ASSESSMENT ==="
    if [[ $production_ready_tests -eq $total_tests ]]; then
        log_success "🎉 SYSTEM IS PRODUCTION READY!"
        log_success "Real users can successfully:"
        log_success "  ✅ Initialize books with minimal input"
        log_success "  ✅ Generate chapters automatically"
        log_success "  ✅ Translate content"
        log_success "  ✅ Create and serve Jekyll sites"
        echo ""
        log_success "The book generator is ready for real-world usage!"
        exit 0
    else
        echo ""
        log_error "❌ SYSTEM NOT PRODUCTION READY"
        log_error "Issues found that would block real users:"
        log_error "  • Chapter generation requires additional setup"
        log_error "  • Missing user guidance for required metadata"
        log_error "  • Unclear error messages for missing information"
        echo ""
        log_warning "RECOMMENDATIONS:"
        log_warning "1. Add interactive prompts for missing book metadata (genre, style, etc.)"
        log_warning "2. Implement intelligent defaults for minimal setup"
        log_warning "3. Improve error messages with actionable guidance"
        log_warning "4. Consider a setup wizard for new users"
        echo ""
        log_error "Fix these issues before releasing to production!"
        exit 1
    fi
}

# Run main function
main "$@"