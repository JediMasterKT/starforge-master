#!/bin/bash
# MCP File Tools - Read File Implementation
# Part of StarForge MCP Integration (Issue #175)
#
# Provides file reading capabilities via MCP protocol

# starforge_read_file - Read file contents and return via MCP
#
# Validates path is absolute, reads file contents, and returns
# properly escaped JSON response.
#
# Args:
#   $1 - Absolute file path to read
#
# Returns:
#   JSON object with either:
#   - {"content": "file contents"} on success
#   - {"error": "error message"} on failure
#
# Examples:
#   starforge_read_file "/path/to/file.txt"
#   # => {"content": "Hello, World!"}
#
#   starforge_read_file "relative/path.txt"
#   # => {"error": "Path must be absolute"}
#
starforge_read_file() {
  local file_path="$1"

  # Validate input
  if [ -z "$file_path" ]; then
    echo '{"error": "Path is required"}'
    return 1
  fi

  # Validate path is absolute (must start with /)
  if [[ ! "$file_path" =~ ^/ ]]; then
    echo '{"error": "Path must be absolute (must start with /)"}'
    return 1
  fi

  # Check if file exists
  if [ ! -f "$file_path" ]; then
    echo "{\"error\": \"File does not exist: $file_path\"}"
    return 1
  fi

  # Check if file is readable
  if [ ! -r "$file_path" ]; then
    echo "{\"error\": \"File is not readable: $file_path\"}"
    return 1
  fi

  # Read file and escape for JSON using jq
  # jq can read file directly with --raw-input --slurp
  # This is faster than cat | jq (one fewer process)
  local content
  if content=$(jq -Rs . "$file_path" 2>/dev/null); then
    # jq -Rs already escapes and quotes the content, so we build JSON around it
    echo "{\"content\": $content}"
    return 0
  else
    echo '{"error": "Failed to read file"}'
    return 1
  fi
}

# Export function for use in other scripts
export -f starforge_read_file
