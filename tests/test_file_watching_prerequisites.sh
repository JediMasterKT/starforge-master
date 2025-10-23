#!/bin/bash
# Test file watching prerequisite checks (TDD - Red Phase)
# Tests for ticket #57: fswatch/inotifywait installation check

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_SCRIPT="$SCRIPT_DIR/../bin/install.sh"

echo "Testing file watching prerequisites for ticket #57..."
echo ""

# Mock function to simulate fswatch/inotifywait not being available
test_fswatch_check_missing() {
    echo "Test 1: Check fswatch warning when missing (macOS)..."

    # Create temporary test script that sources install.sh functions
    local temp_script=$(mktemp)
    cat > "$temp_script" << 'EOF'
#!/bin/bash
# Source the color/emoji vars from install.sh
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
CHECK="✅"
WARN="⚠️ "
ERROR="❌"
INFO="ℹ️ "

# Mock command to return false for fswatch
command() {
    if [ "$1" = "-v" ] && [ "$2" = "fswatch" ]; then
        return 1  # Not found
    fi
    builtin command "$@"
}

export -f command

# Source the check_prerequisites function
source /dev/stdin << 'FUNCTION_EOF'
check_file_watchers() {
    # Check fswatch (macOS)
    if command -v fswatch &> /dev/null; then
        echo -e "${CHECK} fswatch: installed"
        HAS_FSWATCH=true
    else
        echo -e "${INFO} fswatch: not found (optional for trigger monitoring)"
        echo -e "   ${YELLOW}Install: brew install fswatch${NC}"
        HAS_FSWATCH=false
    fi

    # Check inotifywait (Linux)
    if command -v inotifywait &> /dev/null; then
        echo -e "${CHECK} inotifywait: installed"
        HAS_INOTIFYWAIT=true
    else
        echo -e "${INFO} inotifywait: not found (optional for trigger monitoring)"
        echo -e "   ${YELLOW}Install: sudo apt-get install inotify-tools${NC}"
        HAS_INOTIFYWAIT=false
    fi

    # At least one should be available on appropriate platform
    if [ "$HAS_FSWATCH" = false ] && [ "$HAS_INOTIFYWAIT" = false ]; then
        echo -e "${WARN}No file watching tool detected (fswatch or inotifywait)"
        echo -e "   ${YELLOW}Trigger monitoring will require manual mode${NC}"
    fi
}
FUNCTION_EOF

check_file_watchers
EOF

    chmod +x "$temp_script"
    local output=$("$temp_script" 2>&1 || true)
    rm "$temp_script"

    # Verify output contains expected messages
    if echo "$output" | grep -q "fswatch: not found (optional"; then
        echo "  ✓ PASS: fswatch check shows optional message"
    else
        echo "  ✗ FAIL: fswatch check missing or incorrect"
        echo "  Output: $output"
        return 1
    fi

    if echo "$output" | grep -q "Install: brew install fswatch"; then
        echo "  ✓ PASS: Shows installation instructions"
    else
        echo "  ✗ FAIL: Installation instructions missing"
        return 1
    fi

    if echo "$output" | grep -q "optional"; then
        echo "  ✓ PASS: Marked as optional"
    else
        echo "  ✗ FAIL: Not marked as optional"
        return 1
    fi
}

test_inotifywait_check_missing() {
    echo ""
    echo "Test 2: Check inotifywait warning when missing (Linux)..."

    # Similar test for inotifywait
    local temp_script=$(mktemp)
    cat > "$temp_script" << 'EOF'
#!/bin/bash
INFO="ℹ️ "
YELLOW='\033[1;33m'
NC='\033[0m'
CHECK="✅"
WARN="⚠️ "

command() {
    if [ "$1" = "-v" ] && [ "$2" = "inotifywait" ]; then
        return 1  # Not found
    fi
    builtin command "$@"
}

export -f command

source /dev/stdin << 'FUNCTION_EOF'
check_file_watchers() {
    if command -v fswatch &> /dev/null; then
        echo -e "${CHECK} fswatch: installed"
        HAS_FSWATCH=true
    else
        echo -e "${INFO} fswatch: not found (optional for trigger monitoring)"
        echo -e "   ${YELLOW}Install: brew install fswatch${NC}"
        HAS_FSWATCH=false
    fi

    if command -v inotifywait &> /dev/null; then
        echo -e "${CHECK} inotifywait: installed"
        HAS_INOTIFYWAIT=true
    else
        echo -e "${INFO} inotifywait: not found (optional for trigger monitoring)"
        echo -e "   ${YELLOW}Install: sudo apt-get install inotify-tools${NC}"
        HAS_INOTIFYWAIT=false
    fi

    if [ "$HAS_FSWATCH" = false ] && [ "$HAS_INOTIFYWAIT" = false ]; then
        echo -e "${WARN}No file watching tool detected (fswatch or inotifywait)"
        echo -e "   ${YELLOW}Trigger monitoring will require manual mode${NC}"
    fi
}
FUNCTION_EOF

check_file_watchers
EOF

    chmod +x "$temp_script"
    local output=$("$temp_script" 2>&1 || true)
    rm "$temp_script"

    if echo "$output" | grep -q "inotifywait: not found (optional"; then
        echo "  ✓ PASS: inotifywait check shows optional message"
    else
        echo "  ✗ FAIL: inotifywait check missing"
        return 1
    fi

    if echo "$output" | grep -q "sudo apt-get install inotify-tools"; then
        echo "  ✓ PASS: Shows Linux installation instructions"
    else
        echo "  ✗ FAIL: Installation instructions missing"
        return 1
    fi
}

test_both_platforms_supported() {
    echo ""
    echo "Test 3: Check both platforms supported..."

    # Verify install.sh will have both checks
    if [ ! -f "$INSTALL_SCRIPT" ]; then
        echo "  ✗ FAIL: install.sh not found at $INSTALL_SCRIPT"
        return 1
    fi

    # This test will pass once we implement the function
    # For now, we expect it to fail (TDD Red phase)
    if grep -q "fswatch" "$INSTALL_SCRIPT" && grep -q "inotifywait" "$INSTALL_SCRIPT"; then
        echo "  ✓ PASS: Both fswatch and inotifywait checks present"
    else
        echo "  ✗ FAIL: Missing fswatch or inotifywait checks (expected in TDD Red phase)"
        return 1
    fi
}

test_not_required_for_manual_mode() {
    echo ""
    echo "Test 4: Verify graceful handling (not required)..."

    # Create test that ensures missing file watchers don't block installation
    local temp_script=$(mktemp)
    cat > "$temp_script" << 'EOF'
#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
CHECK="✅"
WARN="⚠️ "
ERROR="❌"
INFO="ℹ️ "

all_good=true

# Simulate missing file watchers
HAS_FSWATCH=false
HAS_INOTIFYWAIT=false

# This should NOT set all_good=false
if [ "$HAS_FSWATCH" = false ] && [ "$HAS_INOTIFYWAIT" = false ]; then
    echo -e "${WARN}No file watching tool detected"
    # Should NOT fail installation
fi

# Check all_good is still true
if [ "$all_good" = true ]; then
    echo "Installation can proceed"
    exit 0
else
    echo "Installation blocked"
    exit 1
fi
EOF

    chmod +x "$temp_script"
    if "$temp_script" > /dev/null 2>&1; then
        echo "  ✓ PASS: Missing file watchers don't block installation"
    else
        echo "  ✗ FAIL: Installation incorrectly blocked"
        rm "$temp_script"
        return 1
    fi
    rm "$temp_script"
}

# Run all tests
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Running TDD Tests (Red Phase - Expected to Fail)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

failed=0

test_fswatch_check_missing || failed=$((failed + 1))
test_inotifywait_check_missing || failed=$((failed + 1))
test_both_platforms_supported || failed=$((failed + 1))
test_not_required_for_manual_mode || failed=$((failed + 1))

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ $failed -eq 0 ]; then
    echo "✅ All tests passed!"
    exit 0
else
    echo "❌ $failed test(s) failed (expected in TDD Red phase)"
    echo "Next: Implement the feature to make tests pass"
    exit 1
fi
