#!/bin/bash
# StarForge Infrastructure Validation Script
# Run this locally before pushing to catch issues early

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

echo "🔍 StarForge Infrastructure Validation"
echo "========================================"
echo ""

PASSED=0
FAILED=0

check() {
  local test_name="$1"
  shift

  if "$@" &>/dev/null; then
    echo "✅ $test_name"
    ((PASSED++))
  else
    echo "❌ $test_name"
    ((FAILED++))
  fi
}

echo "📁 Directory Structure"
check "templates/ exists" test -d templates
check "templates/agents/ exists" test -d templates/agents
check "templates/bin/ exists" test -d templates/bin
check "templates/lib/ exists" test -d templates/lib
check "templates/scripts/ exists" test -d templates/scripts
echo ""

echo "🤖 Agent Definitions"
for agent in orchestrator senior-engineer junior-engineer qa-engineer tpm-agent; do
  check "${agent}.md exists" test -f "templates/agents/${agent}.md"
done
echo ""

echo "⚙️  Daemon Scripts"
check "starforged exists" test -f templates/bin/starforged
check "starforged executable" test -x templates/bin/starforged
echo ""

echo "📚 Library Files"
for lib in agent-slots discord-notify logger router project-env; do
  check "${lib}.sh exists" test -f "templates/lib/${lib}.sh"
done
echo ""

echo "🔧 Helper Scripts"
for helper in worktree-helpers github-helpers trigger-helpers context-helpers; do
  check "${helper}.sh exists" test -f "templates/scripts/${helper}.sh"
done
echo ""

echo "🔍 Bash Syntax Validation"
SYNTAX_ERRORS=0
while IFS= read -r script; do
  if bash -n "$script" 2>/dev/null; then
    ((PASSED++))
  else
    echo "❌ Syntax error: $script"
    bash -n "$script" || true
    ((FAILED++))
    ((SYNTAX_ERRORS++))
  fi
done < <(find templates -name "*.sh" -type f)

if [ $SYNTAX_ERRORS -eq 0 ]; then
  echo "✅ All shell scripts have valid syntax"
fi
echo ""

echo "🧪 Configuration Parsing Test"
TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

mkdir -p "$TEST_DIR/.claude"/{triggers,logs,daemon}
mkdir -p "$TEST_DIR/templates/lib"

cp templates/bin/starforged "$TEST_DIR/.claude/bin/" 2>/dev/null || {
  mkdir -p "$TEST_DIR/.claude/bin"
  cp templates/bin/starforged "$TEST_DIR/.claude/bin/"
}
cp -r templates/lib/*.sh "$TEST_DIR/.claude/lib/"
cp templates/lib/agent-slots.sh "$TEST_DIR/templates/lib/"

cat > "$TEST_DIR/.env" << 'EOF'
export PARALLEL_DAEMON=true
export MAX_CONCURRENT_AGENTS=4
EOF

cd "$TEST_DIR"
if timeout 5 bash -c "source .env && .claude/bin/starforged 2>&1" | grep -q "Parallel execution enabled"; then
  echo "✅ Daemon configuration parsing works"
  ((PASSED++))
else
  echo "❌ Daemon configuration parsing failed"
  ((FAILED++))
fi
cd "$PROJECT_ROOT"
echo ""

echo "🎰 Agent Slot Management Test"
source templates/lib/agent-slots.sh
export SLOTS_FILE="$TEST_DIR/test-slots.json"
echo '{}' > "$SLOTS_FILE"

mark_agent_busy "test-agent" "12345" "test-ticket"
if is_agent_busy "test-agent"; then
  echo "✅ mark_agent_busy works"
  ((PASSED++))
else
  echo "❌ mark_agent_busy failed"
  ((FAILED++))
fi

PID=$(get_agent_pid "test-agent")
if [ "$PID" = "12345" ]; then
  echo "✅ get_agent_pid works"
  ((PASSED++))
else
  echo "❌ get_agent_pid failed (got: '$PID', expected: '12345')"
  ((FAILED++))
fi

mark_agent_idle "test-agent"
if ! is_agent_busy "test-agent"; then
  echo "✅ mark_agent_idle works"
  ((PASSED++))
else
  echo "❌ mark_agent_idle failed"
  ((FAILED++))
fi
echo ""

echo "========================================"
echo "📊 Results: $PASSED passed, $FAILED failed"
echo "========================================"

if [ $FAILED -eq 0 ]; then
  echo "✅ All validation checks passed!"
  exit 0
else
  echo "❌ Some validation checks failed"
  exit 1
fi
