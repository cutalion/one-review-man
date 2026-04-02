#!/bin/bash

# Quick test to verify production readiness fixes
set -e

EIDOS_DIR="/home/cutalion/code/one-review-man/eidos"
WORLD_BIN="$EIDOS_DIR/bin/world"
TEST_DIR="/tmp/quick_test_$$"

echo "Quick Production Readiness Test"
echo "=================================="

# Create test directory
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

echo ""
echo "1. Testing world initialization..."

# Test world initialization with intelligent defaults
echo -e "Fantasy Quest\nWizard Author\nA magical adventure with dragons and spells\nen\nen" | ruby "$WORLD_BIN" new --world-dir fantasy-world --quick

if [[ $? -eq 0 ]]; then
    echo "World initialization: PASSED"
else
    echo "World initialization: FAILED"
    exit 1
fi

echo ""
echo "2. Testing world status command..."

cd fantasy-world
ruby "$WORLD_BIN" status

if [[ $? -eq 0 ]]; then
    echo "World status command: PASSED"
else
    echo "World status command: FAILED"
    exit 1
fi

echo ""
echo "3. Testing chapter generation readiness..."

# Check if metadata is properly structured
if grep -q "genre: fantasy" data/world_config.yml &&
   grep -q "humor_style: adventurous" data/world_config.yml &&
   grep -q "setting: magical realm" data/world_config.yml; then
    echo "Intelligent defaults: PASSED"
    echo "   - Genre correctly inferred as 'fantasy' (from 'magical', 'dragons')"
    echo "   - Style correctly inferred as 'adventurous' (from 'adventure')"
    echo "   - Setting correctly inferred as 'magical realm' (from 'magical')"
else
    echo "Intelligent defaults: FAILED"
    echo "Checking metadata content:"
    cat data/world_config.yml
    exit 1
fi

echo ""
echo "4. Testing required files creation..."

required_files=(
    "data/world_config.yml"
    "data/world_state.yml"
    "data/world.yml"
    "data/strings.yml"
    "data/characters.yml"
    "data/generation_log.yml"
)

all_files_exist=true
for file in "${required_files[@]}"; do
    if [[ -f "$file" ]]; then
        echo "$file exists"
    else
        echo "$file missing"
        all_files_exist=false
    fi
done

if [[ "$all_files_exist" == true ]]; then
    echo "Required files: PASSED"
else
    echo "Required files: FAILED"
    exit 1
fi

echo ""
echo "PRODUCTION READINESS TEST SUMMARY"
echo "===================================="
echo "Enhanced initialization with intelligent defaults"
echo "Complete metadata structure creation"
echo "World status reporting"
echo "All required files generated"
echo ""
echo "System appears PRODUCTION READY for basic workflow!"

# Cleanup
cd /
rm -rf "$TEST_DIR"
echo ""
echo "Test completed successfully!"
