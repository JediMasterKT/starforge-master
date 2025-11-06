#!/bin/bash
#
# Integration Test: send_agent_complete_notification() receives PR context
#
# Tests that daemon passes PR context (pr_number, pr_title, pr_url)
# to send_agent_complete_notification()
#
# Related: Issue #315

set -e

DAEMON_RUNNER="templates/bin/daemon-runner.sh"

echo "Integration Test: Complete Notification PR Context"
echo "==================================================="

# Test 1: Verify sequential mode (line ~368) passes PR context
echo -n "Test 1: Sequential mode passes pr_number, message parameters... "

# Find the line in invoke_agent function (sequential mode)
SEQUENTIAL_LINE=$(grep -n 'send_agent_complete_notification.*"\$to_agent".*"\$duration_min"' "$DAEMON_RUNNER" | head -1 | cut -d: -f2)

if echo "$SEQUENTIAL_LINE" | grep -q '\$pr'; then
  echo "✅ PASS"
else
  echo "❌ FAIL"
  echo "Sequential mode call site does not pass PR context"
  echo "Actual line: $SEQUENTIAL_LINE"
  exit 1
fi

# Test 2: Verify parallel mode (line ~658) passes PR context
echo -n "Test 2: Parallel mode passes pr_number, message parameters... "

# Find the line in parallel function
PARALLEL_LINE=$(grep -n 'send_agent_complete_notification.*"\$agent".*"0".*"0"' "$DAEMON_RUNNER" | head -1 | cut -d: -f2)

if echo "$PARALLEL_LINE" | grep -q '\$pr'; then
  echo "✅ PASS"
else
  echo "❌ FAIL"
  echo "Parallel mode call site does not pass PR context"
  echo "Actual line: $PARALLEL_LINE"
  exit 1
fi

# Test 3: Verify both call sites use consistent parameter order
echo -n "Test 3: Both call sites use consistent parameter order... "

# Extract parameter order from sequential
SEQ_PARAMS=$(echo "$SEQUENTIAL_LINE" | sed 's/.*send_agent_complete_notification //; s/ &.*//; s/ >//')

# Extract parameter order from parallel
PAR_PARAMS=$(echo "$PARALLEL_LINE" | sed 's/.*send_agent_complete_notification //; s/ &.*//; s/ >//')

# Both should have same relative order of new params (after existing params)
if [ -n "$SEQ_PARAMS" ] && [ -n "$PAR_PARAMS" ]; then
  echo "✅ PASS"
  echo "   Sequential: $SEQ_PARAMS"
  echo "   Parallel:   $PAR_PARAMS"
else
  echo "❌ FAIL"
  echo "   Sequential: $SEQ_PARAMS"
  echo "   Parallel:   $PAR_PARAMS"
  exit 1
fi

# Test 4: Verify function signature updated in discord-notify.sh
echo -n "Test 4: Verify function accepts PR context parameters... "

NOTIFY_FILE="templates/lib/discord-notify.sh"
FUNCTION_DEF=$(grep -A 10 '^send_agent_complete_notification()' "$NOTIFY_FILE")

if echo "$FUNCTION_DEF" | grep -q 'local pr=' && \
   echo "$FUNCTION_DEF" | grep -q 'local message='; then
  echo "✅ PASS"
else
  echo "❌ FAIL"
  echo "Function signature does not include pr and message parameters"
  echo "Function definition:"
  echo "$FUNCTION_DEF"
  exit 1
fi

# Test 5: Verify notification includes PR context in description
echo -n "Test 5: Verify notification includes PR link when present... "

# Check that notification description uses PR context
if grep -A 20 '^send_agent_complete_notification()' "$NOTIFY_FILE" | \
   grep -q 'if.*\$pr'; then
  echo "✅ PASS"
else
  echo "❌ FAIL"
  echo "Notification does not conditionally include PR link"
  exit 1
fi

# Test 6: Verify parallel mode extracts PR from context
echo -n "Test 6: Verify parallel mode extracts PR from trigger context... "

# Check parallel mode extracts pr variable
if grep -B 20 "send_agent_complete_notification.*\"\$agent\".*\"0\".*\"0\"" "$DAEMON_RUNNER" | \
   grep -q 'local pr='; then
  echo "✅ PASS"
else
  echo "❌ FAIL"
  echo "Parallel mode does not extract pr variable from trigger context"
  exit 1
fi

echo ""
echo "Results: 6 passed, 0 failed"
echo "✅ ALL TESTS PASSED"
