#!/bin/bash
# Hardcoded Pattern Detection Script
# Scans codebase for Issue #36 class bugs:
# - Hardcoded "empowerai" references
# - Hardcoded agent patterns (junior-dev-[abc])
# - Absolute user paths (/Users/, /home/)
#
# Usage:
#   bin/test-hardcoded-patterns.sh           # Scan entire codebase
#   bin/test-hardcoded-patterns.sh file.sh   # Scan specific file

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STARFORGE_ROOT="$(dirname "$SCRIPT_DIR")"

# Violation counter
VIOLATIONS_FOUND=0

# Store violations for reporting
declare -a VIOLATION_MESSAGES

# Pattern definitions
PATTERN_EMPOWERAI="empowerai"
PATTERN_AGENT_A="junior-dev-a"
PATTERN_AGENT_B="junior-dev-b"
PATTERN_AGENT_C="junior-dev-c"
PATTERN_USERS_PATH="/Users/"
PATTERN_HOME_PATH="/home/"

# Exclusion patterns (grep -v compatible)
EXCLUDE_DIRS="\\.git/|\\.claude/research/|\\.tmp/|node_modules/"
EXCLUDE_EXTENSIONS="\\.md$"
SYSTEM_PATHS="/tmp/|/var/|/etc/|/usr/|/opt/"

# Report a violation
report_violation() {
    local file="$1"
    local line_num="$2"
    local pattern="$3"
    local context="$4"

    VIOLATIONS_FOUND=$((VIOLATIONS_FOUND + 1))
    local message="  $file:$line_num - Hardcoded '$pattern' detected"
    VIOLATION_MESSAGES+=("$message")
}

# Check file for hardcoded patterns
check_file() {
    local file="$1"

    # Skip if file doesn't exist
    if [ ! -f "$file" ]; then
        return 0
    fi

    # Skip .git file (worktree git directory pointer)
    if [[ "$file" =~ /\.git$ ]] || [[ "$file" == ".git" ]]; then
        return 0
    fi

    # Skip markdown files (documentation)
    if [[ "$file" =~ \.md$ ]]; then
        return 0
    fi

    # Skip files in excluded directories
    if echo "$file" | grep -Eq "$EXCLUDE_DIRS"; then
        return 0
    fi

    # Check for empowerai pattern (skip comments)
    while IFS= read -r line_num; do
        local line_content=$(sed -n "${line_num}p" "$file")
        # Skip if it's a comment line
        if [[ "$line_content" =~ ^[[:space:]]*# ]]; then
            continue
        fi
        report_violation "$file" "$line_num" "$PATTERN_EMPOWERAI" "$line_content"
    done < <(grep -n "$PATTERN_EMPOWERAI" "$file" 2>/dev/null | cut -d: -f1 || true)

    # Check for hardcoded agent patterns (junior-dev-a, junior-dev-b, junior-dev-c)
    # But NOT junior-dev-agent (which is generic)
    while IFS= read -r line_num; do
        local line_content=$(sed -n "${line_num}p" "$file")
        # Skip if it's a comment line or the pattern is in an inline comment (after #)
        if [[ "$line_content" =~ ^[[:space:]]*# ]]; then
            continue
        fi
        # Check if pattern is only in inline comment part (after #)
        local code_part="${line_content%%#*}"
        if ! echo "$code_part" | grep -q "junior-dev-[abc]"; then
            continue
        fi
        # Verify it's actually junior-dev-[abc] and not junior-dev-agent
        if echo "$code_part" | grep -q "junior-dev-[abc]\b" || \
           echo "$code_part" | grep -q "junior-dev-[abc][^a-z]" || \
           echo "$code_part" | grep -q "junior-dev-[abc]$"; then
            local detected_pattern=$(echo "$code_part" | grep -o "junior-dev-[abc]" | head -1)
            report_violation "$file" "$line_num" "$detected_pattern" "$line_content"
        fi
    done < <(grep -n "junior-dev-[abc]" "$file" 2>/dev/null | grep -v "junior-dev-agent" | cut -d: -f1 || true)

    # Check for /Users/ paths (macOS user directories)
    while IFS= read -r line_num; do
        local line_content=$(sed -n "${line_num}p" "$file")
        # Skip if it's a comment line
        if [[ "$line_content" =~ ^[[:space:]]*# ]]; then
            continue
        fi
        report_violation "$file" "$line_num" "/Users/" "$line_content"
    done < <(grep -n "$PATTERN_USERS_PATH" "$file" 2>/dev/null | cut -d: -f1 || true)

    # Check for /home/ paths (Linux user directories)
    while IFS= read -r line_num; do
        local line_content=$(sed -n "${line_num}p" "$file")
        # Skip if it's a comment line
        if [[ "$line_content" =~ ^[[:space:]]*# ]]; then
            continue
        fi
        # Skip if it's a system path like /tmp/, /var/, /etc/
        if ! echo "$line_content" | grep -Eq "$SYSTEM_PATHS"; then
            report_violation "$file" "$line_num" "/home/" "$line_content"
        fi
    done < <(grep -n "$PATTERN_HOME_PATH" "$file" 2>/dev/null | cut -d: -f1 || true)
}

# Scan entire codebase
scan_codebase() {
    local target_dir="${1:-$STARFORGE_ROOT}"

    # Find all files, excluding directories and file patterns
    # Use -path to exclude directories for better performance
    # Exclude tests/ directory and test-*.sh files as they may contain intentional hardcoded patterns
    while IFS= read -r file; do
        # Skip markdown files
        if [[ "$file" =~ \.md$ ]]; then
            continue
        fi

        # Skip test files in bin/
        if [[ "$file" =~ /bin/test-[^/]+\.sh$ ]]; then
            continue
        fi

        # Check the file
        check_file "$file"
    done < <(find "$target_dir" -type f \
        -not -path "*/.git/*" \
        -not -path "*/.claude/research/*" \
        -not -path "*/.tmp/*" \
        -not -path "*/node_modules/*" \
        -not -path "*/tests/*" \
        2>/dev/null || true)
}

# Main execution
main() {
    # If argument provided, scan specific file
    if [ $# -gt 0 ]; then
        local target="$1"

        if [ -f "$target" ]; then
            check_file "$target"
        elif [ -d "$target" ]; then
            scan_codebase "$target"
        else
            echo -e "${RED}Error: $target not found${NC}" >&2
            exit 1
        fi
    else
        # Scan entire codebase
        scan_codebase "$STARFORGE_ROOT"
    fi

    # Report results
    if [ $VIOLATIONS_FOUND -gt 0 ]; then
        echo -e "${RED}✗ Hardcoded pattern violations detected:${NC}" >&2
        echo "" >&2
        for msg in "${VIOLATION_MESSAGES[@]}"; do
            echo -e "${RED}$msg${NC}" >&2
        done
        echo "" >&2
        echo -e "${RED}Found $VIOLATIONS_FOUND violation(s)${NC}" >&2
        echo "" >&2
        echo -e "${YELLOW}Fix these patterns to use dynamic detection:${NC}" >&2
        echo "  - empowerai → Use PROJECT_NAME variable" >&2
        echo "  - junior-dev-[abc] → Use AGENT_ID variable or loops" >&2
        echo "  - /Users/ or /home/ → Use relative paths or PROJECT_ROOT" >&2
        exit 1
    else
        exit 0
    fi
}

# Run main
main "$@"
