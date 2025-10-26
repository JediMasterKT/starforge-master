#!/bin/bash
# Integration test for starforge_grep_content MCP tool
# Tests for issue #178 - Grep Content Tool (B4)
#
# Integration tests verify the feature works with real dependencies
# and meets real-world usage requirements.

# Note: Not using 'set -e' because error tests intentionally trigger failures
# and we need to test error handling properly

# Setup: Create test environment
TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

echo "Integration test: starforge_grep_content"
echo "========================================="
echo ""

# Create realistic project structure (simulating a Python project)
mkdir -p "$TEST_DIR/project/src/api"
mkdir -p "$TEST_DIR/project/src/models"
mkdir -p "$TEST_DIR/project/src/utils"
mkdir -p "$TEST_DIR/project/tests/unit"
mkdir -p "$TEST_DIR/project/tests/integration"
mkdir -p "$TEST_DIR/project/docs"

# Create Python source files
cat > "$TEST_DIR/project/src/api/routes.py" << 'EOF'
from flask import Blueprint, request
from models.user import User

api = Blueprint('api', __name__)

@api.route('/users', methods=['GET'])
def get_users():
    """Retrieve all users."""
    users = User.query.all()
    return {'users': [u.to_dict() for u in users]}

@api.route('/users/<id>', methods=['GET'])
def get_user(id):
    """Retrieve user by ID."""
    user = User.query.get_or_404(id)
    return user.to_dict()

# TODO: Add error handling for database errors
EOF

cat > "$TEST_DIR/project/src/models/user.py" << 'EOF'
from database import db

class User(db.Model):
    """User model for authentication."""
    __tablename__ = 'users'

    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(80), unique=True, nullable=False)
    email = db.Column(db.String(120), unique=True, nullable=False)

    def to_dict(self):
        """Convert user to dictionary."""
        return {
            'id': self.id,
            'username': self.username,
            'email': self.email
        }
EOF

cat > "$TEST_DIR/project/src/utils/validators.py" << 'EOF'
import re

def validate_email(email):
    """Validate email format."""
    pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    return re.match(pattern, email) is not None

def validate_username(username):
    """Validate username format."""
    if len(username) < 3:
        raise ValueError("Username too short")
    return True
EOF

# Create test files
cat > "$TEST_DIR/project/tests/unit/test_validators.py" << 'EOF'
import pytest
from utils.validators import validate_email, validate_username

def test_validate_email():
    """Test email validation."""
    assert validate_email("user@example.com") == True
    assert validate_email("invalid") == False

def test_validate_username():
    """Test username validation."""
    assert validate_username("john") == True
    with pytest.raises(ValueError):
        validate_username("ab")
EOF

# Create documentation
cat > "$TEST_DIR/project/docs/API.md" << 'EOF'
# API Documentation

## User Endpoints

### GET /users
Retrieve all users from the database.

### GET /users/<id>
Retrieve a specific user by ID.

## Error Handling
TODO: Document error responses
EOF

# Create config file
cat > "$TEST_DIR/project/config.py" << 'EOF'
DATABASE_URL = "postgresql://localhost/mydb"
DEBUG = True
SECRET_KEY = "change-me-in-production"
EOF

# Load implementation
source templates/lib/mcp-tools-file.sh

echo "Test 1: Search for TODO comments across entire codebase"
echo "--------------------------------------------------------"
result=$(starforge_grep_content "TODO" "$TEST_DIR/project")
count=$(echo "$result" | jq -r '.matches | length')
echo "Found $count TODO comments"

# Verify we found TODOs in multiple files
if [ "$count" -ge 2 ]; then
  echo "✅ PASS: Found TODO comments in multiple files"
else
  echo "❌ FAIL: Expected at least 2 TODO comments, got $count"
  exit 1
fi

# Verify matches include file paths
first_file=$(echo "$result" | jq -r '.matches[0].file')
if [[ "$first_file" =~ $TEST_DIR ]]; then
  echo "✅ PASS: Match includes full file path"
else
  echo "❌ FAIL: File path missing or incorrect: $first_file"
  exit 1
fi
echo ""

echo "Test 2: Search for function definitions in Python files only"
echo "--------------------------------------------------------------"
result=$(starforge_grep_content "^def " "$TEST_DIR/project" "py" false)
count=$(echo "$result" | jq -r '.matches | length')
echo "Found $count function definitions in Python files"

if [ "$count" -ge 5 ]; then
  echo "✅ PASS: Found expected Python functions"
else
  echo "❌ FAIL: Expected at least 5 functions, got $count"
  exit 1
fi

# Verify all matches are from .py files
non_py_count=$(echo "$result" | jq -r '.matches[].file' | grep -v '\.py$' | wc -l)
if [ "$non_py_count" -eq 0 ]; then
  echo "✅ PASS: All matches are from Python files"
else
  echo "❌ FAIL: Found $non_py_count matches from non-Python files"
  exit 1
fi
echo ""

echo "Test 3: Case-insensitive search for error handling"
echo "---------------------------------------------------"
result=$(starforge_grep_content "error" "$TEST_DIR/project" "" true)
count=$(echo "$result" | jq -r '.matches | length')
echo "Found $count matches for 'error' (case-insensitive)"

# Should find both "error" and "Error"
content_lower=$(echo "$result" | jq -r '.matches[].content' | grep -i "error" | wc -l)
if [ "$content_lower" -ge 2 ]; then
  echo "✅ PASS: Case-insensitive search working"
else
  echo "❌ FAIL: Expected multiple error mentions"
  exit 1
fi
echo ""

echo "Test 4: Complex regex pattern for email validation"
echo "---------------------------------------------------"
pattern='[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'
result=$(starforge_grep_content "$pattern" "$TEST_DIR/project")
count=$(echo "$result" | jq -r '.matches | length')
echo "Found $count email patterns"

if [ "$count" -ge 1 ]; then
  echo "✅ PASS: Complex regex patterns work"
else
  echo "❌ FAIL: Regex pattern not matching emails"
  exit 1
fi
echo ""

echo "Test 5: Search with no matches returns empty array"
echo "---------------------------------------------------"
result=$(starforge_grep_content "NONEXISTENT_PATTERN_XYZ123" "$TEST_DIR/project")
count=$(echo "$result" | jq -r '.matches | length')

if [ "$count" -eq 0 ]; then
  echo "✅ PASS: No matches returns empty array"
else
  echo "❌ FAIL: Expected 0 matches, got $count"
  exit 1
fi

# Verify it's still valid JSON with matches field
has_matches=$(echo "$result" | jq 'has("matches")')
if [ "$has_matches" = "true" ]; then
  echo "✅ PASS: Result has proper JSON structure"
else
  echo "❌ FAIL: Result missing matches field"
  exit 1
fi
echo ""

echo "Test 6: Performance test with large codebase"
echo "---------------------------------------------"
# Create a larger codebase (500 files)
perf_dir="$TEST_DIR/large_project"
mkdir -p "$perf_dir/src"

for i in {1..500}; do
  cat > "$perf_dir/src/module_$i.py" << EOF
def function_$i():
    """Function number $i."""
    return $i

class Class$i:
    """Class number $i."""
    def method_$i(self):
        return $i
EOF
done

# Add target pattern to some files
echo "SEARCH_TARGET = 'found_me'" >> "$perf_dir/src/module_100.py"
echo "# SEARCH_TARGET in comment" >> "$perf_dir/src/module_200.py"
echo "SEARCH_TARGET = 'another one'" >> "$perf_dir/src/module_300.py"

# Measure search time
start=$(date +%s%3N)
result=$(starforge_grep_content "SEARCH_TARGET" "$perf_dir")
end=$(date +%s%3N)
duration=$((end - start))

echo "Searched 500 files in ${duration}ms"

if [ $duration -lt 1000 ]; then
  echo "✅ PASS: Performance target met (<1000ms)"
else
  echo "❌ FAIL: Too slow: ${duration}ms (target: <1000ms)"
  exit 1
fi

# Verify we found all 3 targets
count=$(echo "$result" | jq -r '.matches | length')
if [ "$count" -eq 3 ]; then
  echo "✅ PASS: Found all target patterns"
else
  echo "❌ FAIL: Expected 3 matches, got $count"
  exit 1
fi
echo ""

echo "Test 7: Error handling for invalid directory"
echo "---------------------------------------------"
result=$(starforge_grep_content "test" "$TEST_DIR/nonexistent_dir")
has_error=$(echo "$result" | jq 'has("error")')

if [ "$has_error" = "true" ]; then
  echo "✅ PASS: Returns error for invalid directory"
else
  echo "❌ FAIL: Should return error for invalid directory"
  exit 1
fi

error_msg=$(echo "$result" | jq -r '.error')
if [[ "$error_msg" == *"not found"* ]] || [[ "$error_msg" == *"does not exist"* ]]; then
  echo "✅ PASS: Error message is descriptive"
else
  echo "❌ FAIL: Error message not descriptive: $error_msg"
  exit 1
fi
echo ""

echo "Test 8: Match includes line numbers"
echo "------------------------------------"
result=$(starforge_grep_content "def get_users" "$TEST_DIR/project")
line_num=$(echo "$result" | jq -r '.matches[0].line_number')

if [ "$line_num" -gt 0 ] 2>/dev/null; then
  echo "✅ PASS: Line number included (line $line_num)"
else
  echo "❌ FAIL: Line number missing or invalid: $line_num"
  exit 1
fi
echo ""

echo "========================================="
echo "✅ ALL INTEGRATION TESTS PASSED"
echo "========================================="
echo ""
echo "Summary:"
echo "- Searched across multiple file types"
echo "- Case-insensitive search verified"
echo "- File type filtering working"
echo "- Regex patterns supported"
echo "- Performance targets met (<1s for 500 files)"
echo "- Error handling validated"
echo "- JSON structure correct"
