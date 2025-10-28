#!/bin/bash
#
# Integration Test: send_agent_start_notification() receives context
#
# Tests that daemon-runner.sh passes extracted context variables
# (message, pr, description) to send_agent_start_notification()
#
# Related: Issue #312

set -e

DAEMON_RUNNER="templates/bin/daemon-runner.sh"

echo "Integration Test: Notification Context Passing"
echo "=============================================="

# Test 1: Verify daemon-runner.sh line ~273 has new signature (sequential mode)
echo -n "Test 1: Sequential mode (line ~273) passes context parameters... "

# Find the line in invoke_agent function (sequential mode)
SEQUENTIAL_LINE=$(grep -n 'send_agent_start_notification.*"\$to_agent".*"\$action".*"\$from_agent".*"\$ticket"' "$DAEMON_RUNNER" | head -1 | cut -d: -f2)

if echo "$SEQUENTIAL_LINE" | grep -q '\$message.*\$pr.*\$description'; then
  echo "✅ PASS"
else
  echo "❌ FAIL"
  echo "Sequential mode call site does not pass \$message, \$pr, \$description"
  echo "Actual line: $SEQUENTIAL_LINE"
  exit 1
fi

# Test 2: Verify daemon-runner.sh line ~450 has new signature (parallel mode)
echo -n "Test 2: Parallel mode (line ~450) passes context parameters... "

# Find the line in invoke_agent_parallel function
PARALLEL_LINE=$(grep -n 'send_agent_start_notification.*"\$to_agent".*"\$action".*"\$from_agent".*"\$ticket"' "$DAEMON_RUNNER" | tail -1 | cut -d: -f2)

if echo "$PARALLEL_LINE" | grep -q '\$message.*\$pr.*\$description'; then
  echo "✅ PASS"
else
  echo "❌ FAIL"
  echo "Parallel mode call site does not pass \$message, \$pr, \$description"
  echo "Actual line: $PARALLEL_LINE"
  exit 1
fi

# Test 3: Verify both call sites use same parameter order
echo -n "Test 3: Both call sites use consistent parameter order... "

# Extract parameter order from sequential
SEQ_PARAMS=$(echo "$SEQUENTIAL_LINE" | sed 's/.*send_agent_start_notification //; s/ &.*//; s/ >//')

# Extract parameter order from parallel
PAR_PARAMS=$(echo "$PARALLEL_LINE" | sed 's/.*send_agent_start_notification //; s/ &.*//; s/ >//')

if [ "$SEQ_PARAMS" = "$PAR_PARAMS" ]; then
  echo "✅ PASS"
  echo "   Parameter order: $SEQ_PARAMS"
else
  echo "❌ FAIL"
  echo "   Sequential: $SEQ_PARAMS"
  echo "   Parallel:   $PAR_PARAMS"
  exit 1
fi

# Test 4: Verify all 7 parameters are passed (not just 4)
echo -n "Test 4: Verify 7 parameters passed (to_agent, action, from_agent, ticket, message, pr, description)... "

PARAM_COUNT=$(echo "$SEQ_PARAMS" | grep -o '\$' | wc -l)

if [ "$PARAM_COUNT" -ge 7 ]; then
  echo "✅ PASS ($PARAM_COUNT parameters)"
else
  echo "❌ FAIL"
  echo "Expected at least 7 parameters, found: $PARAM_COUNT"
  echo "Parameters: $SEQ_PARAMS"
  exit 1
fi

# Test 5: Verify parameter names match extracted variables from line ~252-259
echo -n "Test 5: Verify parameter names match extracted variables... "

# Check that message, pr, description variables are extracted
if grep -q 'local message=' "$DAEMON_RUNNER" && \
   grep -q 'local pr=' "$DAEMON_RUNNER" && \
   grep -q 'local description=' "$DAEMON_RUNNER"; then
  echo "✅ PASS"
else
  echo "❌ FAIL"
  echo "Variables message, pr, or description not found in daemon-runner.sh"
  exit 1
fi

# Test 6: Verify variables are extracted from context (issue #311 prerequisite)
echo -n "Test 6: Verify context extraction exists (prerequisite from #311)... "

if grep -q 'local context_json=' "$DAEMON_RUNNER" && \
   grep -q '\.context\.pr' "$DAEMON_RUNNER" && \
   grep -q '\.context\.description' "$DAEMON_RUNNER"; then
  echo "✅ PASS"
else
  echo "❌ FAIL"
  echo "Context extraction from #311 not found in daemon-runner.sh"
  exit 1
fi

echo ""
echo "Results: 6 passed, 0 failed"
echo "✅ ALL TESTS PASSED"
