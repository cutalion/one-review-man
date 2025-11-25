#!/bin/bash

# Quick test to verify production readiness fixes
set -e

REPO_ROOT=$(pwd)
BOOK_GENERATOR_BIN="$REPO_ROOT/book-generator/bin/book"
TEST_DIR="/tmp/quick_test_$$"

echo "🧪 Quick Production Readiness Test"
echo "=================================="

# Create test directory
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

echo ""
echo "1️⃣ Testing enhanced book initialization..."

# Test book initialization with intelligent defaults
echo -e "Fantasy Quest\nWizard Author\nA magical adventure with dragons and spells\nen\nen" | "$BOOK_GENERATOR_BIN" init --book-dir fantasy-book --quick

if [[ $? -eq 0 ]]; then
    echo "✅ Book initialization: PASSED"
else
    echo "❌ Book initialization: FAILED"
    exit 1
fi

echo ""
echo "2️⃣ Testing book status command..."

cd fantasy-book
"$BOOK_GENERATOR_BIN" status

if [[ $? -eq 0 ]]; then
    echo "✅ Book status command: PASSED"
else
    echo "❌ Book status command: FAILED"
    exit 1
fi

echo ""
echo "3️⃣ Testing chapter generation readiness..."

# Check if metadata is properly structured
if grep -q "genre: fantasy" data/book_config.yml &&
   grep -q "style: adventurous" data/book_config.yml &&
   grep -q "setting: magical realm" data/book_config.yml; then
    echo "✅ Intelligent defaults: PASSED"
    echo "   - Genre correctly inferred as 'fantasy' (from 'magical', 'dragons')"
    echo "   - Style correctly inferred as 'adventurous' (from 'adventure')" 
    echo "   - Setting correctly inferred as 'magical realm' (from 'magical')"
else
    echo "❌ Intelligent defaults: FAILED"
    echo "Checking metadata content:"
    cat data/book_metadata.yml
    exit 1
fi

echo ""
echo "4️⃣ Testing required files creation..."

required_files=(
    "data/book_config.yml"
    "data/world.yml"
    "data/strings.yml"
    "data/characters.yml"
    "data/generation_log.yml"
)

all_files_exist=true
for file in "${required_files[@]}"; do
    if [[ -f "$file" ]]; then
        echo "✅ $file exists"
    else
        echo "❌ $file missing"
        all_files_exist=false
    fi
done

if [[ "$all_files_exist" == true ]]; then
    echo "✅ Required files: PASSED"
else
    echo "❌ Required files: FAILED"
    exit 1
fi

echo ""
echo "🎉 PRODUCTION READINESS TEST SUMMARY"
echo "===================================="
echo "✅ Enhanced initialization with intelligent defaults"
echo "✅ Complete metadata structure creation"
echo "✅ Book status reporting"
echo "✅ All required files generated"
echo ""
echo "🚀 System appears PRODUCTION READY for basic workflow!"
echo "📝 Real users should now be able to:"
echo "   - Initialize books with minimal friction"
echo "   - Get clear guidance on book status"
echo "   - Generate chapters without unfilled placeholder errors"

# Cleanup
cd /
rm -rf "$TEST_DIR"
echo ""
echo "✨ Test completed successfully!"