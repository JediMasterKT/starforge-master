#!/bin/bash
#
# check-documentation.sh - Automated documentation quality check
#
# Checks for undocumented functions in bash scripts and Python files.
# Used by CI to enforce documentation standards.
#
# Exit codes:
#   0 = All functions documented
#   1 = Undocumented functions found

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"

echo "================================"
echo "Documentation Quality Check"
echo "================================"
echo ""

# Track undocumented functions
UNDOCUMENTED_BASH=0
UNDOCUMENTED_PY=0
UNDOCUMENTED_BASH_FILES=""
UNDOCUMENTED_PY_FILES=""

# 1. Check Bash functions
echo "📝 Checking bash functions..."

# Find all bash functions in templates/ and .claude/ (excluding tests)
while IFS= read -r file; do
  # Skip test files
  if [[ "$file" =~ test- ]] || [[ "$file" =~ /tests/ ]]; then
    continue
  fi

  # Find functions in this file
  grep -n "^function " "$file" 2>/dev/null | while IFS=: read -r line_num func_def; do
    func_name=$(echo "$func_def" | awk '{print $2}' | tr -d '()')

    # Check if function has comment above it (within 3 lines)
    has_comment=false
    for i in 1 2 3; do
      check_line=$((line_num - i))
      if [ $check_line -gt 0 ]; then
        line_content=$(sed -n "${check_line}p" "$file")
        if [[ "$line_content" =~ ^# ]]; then
          has_comment=true
          break
        fi
        # Stop if we hit another function or non-comment/non-empty
        if [[ "$line_content" =~ ^function ]] || [[ -n "$line_content" && ! "$line_content" =~ ^[[:space:]]*$ ]]; then
          break
        fi
      fi
    done

    if [ "$has_comment" = false ]; then
      echo "  ❌ $file:$line_num - function $func_name (no comment)"
      UNDOCUMENTED_BASH=$((UNDOCUMENTED_BASH + 1))
      if [[ ! "$UNDOCUMENTED_BASH_FILES" =~ "$file" ]]; then
        UNDOCUMENTED_BASH_FILES="$UNDOCUMENTED_BASH_FILES\n  - $file"
      fi
    fi
  done
done < <(find templates .claude -name "*.sh" -type f 2>/dev/null)

# 2. Check Python functions (if src/ exists)
if [ -d "src" ]; then
  echo ""
  echo "📝 Checking Python functions..."

  while IFS= read -r file; do
    # Find function definitions
    grep -n "^def " "$file" 2>/dev/null | while IFS=: read -r line_num func_def; do
      func_name=$(echo "$func_def" | awk '{print $2}' | tr -d '(')

      # Check if next non-empty line is a docstring
      next_line=$((line_num + 1))
      next_content=$(sed -n "${next_line}p" "$file" | tr -d '[:space:]')

      if [[ ! "$next_content" =~ ^\"\"\" ]] && [[ ! "$next_content" =~ ^\'\'\' ]]; then
        echo "  ❌ $file:$line_num - def $func_name (no docstring)"
        UNDOCUMENTED_PY=$((UNDOCUMENTED_PY + 1))
        if [[ ! "$UNDOCUMENTED_PY_FILES" =~ "$file" ]]; then
          UNDOCUMENTED_PY_FILES="$UNDOCUMENTED_PY_FILES\n  - $file"
        fi
      fi
    done
  done < <(find src -name "*.py" -type f 2>/dev/null)
fi

# 3. Summary
echo ""
echo "================================"
echo "Summary"
echo "================================"
echo ""

TOTAL=$((UNDOCUMENTED_BASH + UNDOCUMENTED_PY))

if [ $TOTAL -eq 0 ]; then
  echo -e "${GREEN}✅ All functions documented!${NC}"
  echo ""
  exit 0
else
  echo -e "${RED}❌ Found $TOTAL undocumented functions${NC}"
  echo ""
  echo "Breakdown:"
  echo "  - Bash functions: $UNDOCUMENTED_BASH"
  echo "  - Python functions: $UNDOCUMENTED_PY"
  echo ""

  if [ $UNDOCUMENTED_BASH -gt 0 ]; then
    echo -e "${YELLOW}Bash files needing comments:${NC}"
    echo -e "$UNDOCUMENTED_BASH_FILES"
    echo ""
    echo "Example format:"
    echo ""
    echo "  # Description of what this function does"
    echo "  # Args: \$1 = input_file, \$2 = output_file"
    echo "  # Returns: 0 on success, 1 on failure"
    echo "  function process_file() {"
    echo "    ..."
    echo "  }"
    echo ""
  fi

  if [ $UNDOCUMENTED_PY -gt 0 ]; then
    echo -e "${YELLOW}Python files needing docstrings:${NC}"
    echo -e "$UNDOCUMENTED_PY_FILES"
    echo ""
    echo "Example format:"
    echo ""
    echo "  def process_file(input_file, output_file):"
    echo "      \"\"\"Process a file and write to output."
    echo "      "
    echo "      Args:"
    echo "          input_file: Path to input file"
    echo "          output_file: Path to output file"
    echo "      "
    echo "      Returns:"
    echo "          True on success, False on failure"
    echo "      \"\"\""
    echo "      ..."
    echo ""
  fi

  exit 1
fi
