#!/bin/bash
# MCP File Tools - Read and Write File Implementation
# Part of StarForge MCP Integration (Issues #175, #176)
#
# Provides file reading and writing capabilities via MCP protocol

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

# starforge_write_file - Write content to file atomically
#
# Validates path is absolute, creates parent directories if needed,
# and writes content atomically using temp file + mv pattern.
#
# Args:
#   $1 - Absolute file path to write
#   $2 - Content to write to file
#
# Returns:
#   JSON object with either:
#   - {"success": true, "path": "/absolute/path"} on success
#   - {"error": "error message"} on failure
#
# Examples:
#   starforge_write_file "/path/to/file.txt" "Hello, World!"
#   # => {"success": true, "path": "/path/to/file.txt"}
#
#   starforge_write_file "relative/path.txt" "content"
#   # => {"error": "Path must be absolute"}
#
starforge_write_file() {
  local file_path="$1"
  local content="$2"

  # Validate input - path is required
  if [ -z "$file_path" ]; then
    echo '{"error": "Path is required"}'
    return 1
  fi

  # Validate path is absolute (must start with /)
  if [[ ! "$file_path" =~ ^/ ]]; then
    echo '{"error": "Path must be absolute (must start with /)"}'
    return 1
  fi

  # Create parent directory if it doesn't exist
  local parent_dir=$(dirname "$file_path")
  if [ ! -d "$parent_dir" ]; then
    if ! mkdir -p "$parent_dir" 2>/dev/null; then
      echo "{\"error\": \"Failed to create parent directory: $parent_dir\"}"
      return 1
    fi
  fi

  # Atomic write: write to temp file first, then move
  # Using $$ (process ID) ensures unique temp file name
  local temp_file="${file_path}.tmp.$$"

  # Write content to temp file
  # Using printf instead of echo to handle special characters correctly
  if ! printf '%s' "$content" > "$temp_file" 2>/dev/null; then
    # Clean up temp file on error
    rm -f "$temp_file" 2>/dev/null
    echo '{"error": "Failed to write to temp file"}'
    return 1
  fi

  # Atomic move: replace original file with temp file
  # mv is atomic on the same filesystem
  if ! mv "$temp_file" "$file_path" 2>/dev/null; then
    # Clean up temp file on error
    rm -f "$temp_file" 2>/dev/null
    echo "{\"error\": \"Failed to move temp file to target: $file_path\"}"
    return 1
  fi

  # Return success with the path that was written
  echo "{\"success\": true, \"path\": \"$file_path\"}"
  return 0
}

# Export functions for use in other scripts
export -f starforge_read_file
export -f starforge_write_file
