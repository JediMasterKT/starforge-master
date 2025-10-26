#!/bin/bash
# MCP File Tools - File Operations Implementation
# Part of StarForge MCP Integration (Issues #175, #177)
#
# Provides file reading and search capabilities via MCP protocol

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

# starforge_search_files - Search for files matching glob pattern
#
# Recursively searches directory for files matching a glob pattern.
# Uses find command for efficient file searching.
#
# Args:
#   $1 - Glob pattern (e.g., "*.py", "*.js", "test_*.sh")
#   $2 - Directory path to search (optional, defaults to current directory)
#
# Returns:
#   JSON object with either:
#   - {"files": ["path1", "path2", ...]} on success
#   - {"error": "error message"} on failure
#
# Examples:
#   starforge_search_files "*.py" "/path/to/project"
#   # => {"files": ["/path/to/project/app.py", "/path/to/project/test.py"]}
#
#   starforge_search_files "*.js"
#   # => {"files": ["./src/index.js", "./src/app.js"]} (searches current dir)
#
#   starforge_search_files "" "/path"
#   # => {"error": "Pattern is required"}
#
starforge_search_files() {
  local pattern="$1"
  local search_path="${2:-.}"  # Default to current directory

  # Validate input
  if [ -z "$pattern" ]; then
    echo '{"error": "Pattern is required"}'
    return 1
  fi

  # Check if directory exists
  if [ ! -d "$search_path" ]; then
    echo "{\"error\": \"Directory does not exist: $search_path\"}"
    return 1
  fi

  # Check if directory is readable
  if [ ! -r "$search_path" ]; then
    echo "{\"error\": \"Directory is not readable: $search_path\"}"
    return 1
  fi

  # Use find to search for files matching pattern
  # -type f: only files (not directories)
  # -name: match pattern
  # Performance optimization: Convert to absolute path in the search_path context
  # to avoid multiple realpath calls
  local abs_search_path
  abs_search_path=$(cd "$search_path" 2>/dev/null && pwd)
  if [ -z "$abs_search_path" ]; then
    abs_search_path="$search_path"
  fi

  # Execute find and pipe directly to jq for efficient JSON array building
  # This avoids intermediate bash array and multiple process spawns
  # -print0 for null-separated output (handles spaces/special chars)
  local json_array
  local find_results

  # Find files and convert to absolute paths, then pipe to jq
  find_results=$(find "$abs_search_path" -type f -name "$pattern" -print 2>/dev/null)

  if [ -z "$find_results" ]; then
    # No matches - empty array
    json_array="[]"
  else
    # Use jq to build JSON array directly from find output
    # This is much faster than looping in bash
    json_array=$(echo "$find_results" | jq -R . | jq -s .)
  fi

  # Return JSON response
  echo "{\"files\": $json_array}"
  return 0
}

# Export functions for use in other scripts
export -f starforge_read_file
export -f starforge_search_files
