# Agent Learnings

Project-specific learnings and patterns for this agent.

---

## Learning 1: Failure to Catch End-to-End Integration Failures

**Date:** 2025-10-22

**What happened:**
QA engineer consistently failed to catch end-to-end integration failures, particularly hardcoded values in code claiming to be "project-agnostic". Issue #36 revealed hardcoded agent detection for exactly 3 agents (junior-dev-a|b|c), which would fail with different agent configurations. This is a systemic issue happening across multiple projects.

**What was learned:**
Current QA testing focused too heavily on happy path scenarios and failed to validate:
- Configuration variations (1, 3, 10 agents)
- Different naming patterns
- Fresh project installations
- Edge cases and boundary conditions
- Claims made in PR descriptions ("project-agnostic", "dynamic", etc.)

**Why it matters:**
- Bugs reaching production that violate core PR objectives
- Loss of user trust in QA approval process
- P0 bugs requiring immediate hotfixes
- Systemic failure pattern affecting multiple projects
- Wastes engineering time fixing issues that should have been caught

**Corrected approach:**
Implement comprehensive E2E testing methodology with mandatory checklists and validation procedures (detailed below).

**Related documentation:**
- Issue #36: Fix Dynamic Agent Detection
- Issue #37: QA Process Improvement
- qa-engineer.md: QA agent definition

---

## Enhanced Testing Checklist

### MANDATORY: Pre-Approval Validation

Before approving ANY PR, complete this checklist:

#### 1. Claim Validation (If PR Claims Special Properties)

When PR claims "project-agnostic", "dynamic", "configurable", "portable", or similar:

```bash
# Search for hardcoded patterns
cd "$REPO_ROOT"

# Check for hardcoded agent names
grep -r "junior-dev-[abc]" templates/ bin/ .claude/ || echo "✓ No hardcoded agent names"

# Check for hardcoded project names
grep -r "empowerai" templates/ bin/ .claude/ || echo "✓ No hardcoded project names"
grep -r "starforge" templates/ bin/ .claude/ || echo "✓ No hardcoded starforge references"

# Check for hardcoded absolute paths
grep -r "/Users/" templates/ bin/ .claude/ || echo "✓ No hardcoded user paths"

# Check for hardcoded agent counts
grep -rE "(junior-dev-[a-c]|three agents|3 agents)" templates/ bin/ || echo "✓ No hardcoded agent counts"
```

**RED FLAGS requiring extra scrutiny:**
- Hardcoded case statements with fixed patterns (e.g., `case` with only a|b|c)
- Hardcoded paths in templates
- Assumptions about number of instances
- Tests that only cover happy path
- Missing edge case tests

#### 2. Configuration Variation Testing

Test with MULTIPLE configurations (minimum, typical, maximum):

- [ ] **Minimum Configuration**: Test with 1 agent
  - Does it work with single agent setup?
  - No errors related to missing agents?

- [ ] **Typical Configuration**: Test with 3 agents
  - Standard happy path works?
  - All 3 agents detected correctly?

- [ ] **Maximum Configuration**: Test with 10 agents
  - Scales beyond typical usage?
  - No hardcoded limits hit?

- [ ] **Custom Naming**: Test with non-standard names
  - Works with `dev-1`, `dev-2` instead of `junior-dev-a`?
  - No assumptions about naming patterns?

- [ ] **Different Project Names**: Test with various project names
  - Works with `my-project`, `test-proj`, `x`?
  - No hardcoded project name dependencies?

#### 3. E2E Testing Scenarios

For claims of portability or project-agnosticism:

- [ ] **Fresh Installation**: Install on brand new project
  ```bash
  # Test in temporary directory
  TEMP_DIR=$(mktemp -d)
  cd "$TEMP_DIR"

  # Run installation
  bash install-cli.sh

  # Verify setup works
  # Verify no assumptions about existing setup
  ```

- [ ] **Different Directory Structures**: Test various layouts
  - `/Users/different-user/projects/test`
  - `/home/user/work/proj`
  - Paths with spaces: `/Users/name/My Projects/test`

- [ ] **Different Configurations**: Test user choices
  - 2 agents vs 5 agents
  - Different worktree naming
  - Different project structure

- [ ] **Edge Cases Matrix**:
  - Minimum configuration (1 agent, minimal setup)
  - Maximum configuration (10 agents, full features)
  - Non-standard configuration (custom names, paths)
  - Missing configuration (partial setup)
  - Invalid configuration (detect and handle gracefully)

#### 4. Acceptance Criteria Deep Validation

Don't just check if tests pass:

- [ ] Each AC explicitly tested (not just implied)
- [ ] Tests cover edge cases, not just happy path
- [ ] Tests validate actual behavior (not just structure)
- [ ] Performance targets met (if specified)
- [ ] Error handling tested (not just success cases)

#### 5. Regression Prevention

Check for patterns seen in past failures:

- [ ] Similar issues in past PRs or other projects?
- [ ] Known failure patterns present?
- [ ] Cross-reference with declined PRs
- [ ] Document new patterns discovered

---

## Configuration Variation Testing Requirements

### Core Principle
**Never assume a specific configuration.** Always test with min/typical/max scenarios.

### Required Test Matrix

| Configuration | Agent Count | Naming Pattern | Project Name | Expected Result |
|--------------|-------------|----------------|--------------|-----------------|
| Minimum | 1 | junior-dev-a | test-proj | ✅ Works |
| Typical | 3 | junior-dev-a/b/c | myproject | ✅ Works |
| Maximum | 10 | junior-dev-a through j | proj | ✅ Works |
| Custom Names | 3 | dev-1/dev-2/dev-3 | custom | ✅ Works |
| Non-standard | 5 | agent-alpha through epsilon | my-proj | ✅ Works |

### Testing Procedure

```bash
# Test with 1 agent
./test-with-config.sh --agents=1 --naming="junior-dev-a"

# Test with 3 agents (typical)
./test-with-config.sh --agents=3 --naming="junior-dev-a,junior-dev-b,junior-dev-c"

# Test with 10 agents (stress test)
./test-with-config.sh --agents=10 --naming="junior-dev-{a..j}"

# Test with custom naming
./test-with-config.sh --agents=3 --naming="dev-1,dev-2,dev-3"
```

**Failure to test variations = automatic PR decline**

---

## Common Failure Patterns to Watch For

### Pattern 1: Hardcoded Agent Names

**Example from Issue #36:**
```bash
# BAD: Hardcoded agent detection
case "$current_dir" in
    *-junior-dev-a) echo "junior-dev-a" ;;
    *-junior-dev-b) echo "junior-dev-b" ;;
    *-junior-dev-c) echo "junior-dev-c" ;;
    *) echo "main" ;;
esac
```

**Detection:**
```bash
grep -rE "junior-dev-[abc]" .
grep -rE "(dev-a|dev-b|dev-c)" .
```

**Why it fails:** Only works with exactly 3 agents named a/b/c

### Pattern 2: Hardcoded Agent Counts

**Example:**
```bash
# BAD: Assumes 3 agents
for agent in a b c; do
    # ...
done
```

**Detection:**
```bash
grep -rE "for.*in.*a b c" .
grep -rE "(three|3) agents" .
```

**Why it fails:** Breaks with 2, 5, or 10 agents

### Pattern 3: Hardcoded Absolute Paths

**Example:**
```bash
# BAD: Hardcoded user path
REPO_ROOT="/Users/krunaaltavkar/starforge-master"
```

**Detection:**
```bash
grep -r "/Users/" .
grep -r "/home/" .
```

**Why it fails:** Only works on original developer's machine

### Pattern 4: Hardcoded Project Names

**Example:**
```bash
# BAD: Hardcoded project name
if [[ "$PWD" =~ "empowerai" ]]; then
    # ...
fi
```

**Detection:**
```bash
grep -r "empowerai" templates/ bin/
grep -r "starforge" templates/ bin/
```

**Why it fails:** Breaks when user names project differently

### Pattern 5: Missing Edge Case Handling

**Example:**
```bash
# BAD: No validation
agent_count=$1
# Assumes agent_count is valid number
```

**Detection:**
- Check for input validation
- Check for error handling
- Check for boundary conditions (0, 1, 100)

**Why it fails:** Crashes with invalid input

---

## E2E Testing Scenarios (Comprehensive)

### Scenario 1: Fresh Project Installation

**Purpose:** Verify zero-assumptions about existing setup

**Procedure:**
```bash
# 1. Create fresh directory
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

# 2. Initialize empty git repo
git init

# 3. Run installation
bash install-cli.sh

# 4. Verify
- All files created correctly
- No errors about missing files
- Works with no prior configuration
```

### Scenario 2: Different Agent Configurations

**Purpose:** Validate dynamic agent handling

**Test Cases:**
- 1 agent (edge case: minimum)
- 2 agents (edge case: not typical)
- 3 agents (typical case)
- 5 agents (above typical)
- 10 agents (stress test: maximum)

### Scenario 3: Custom Naming Patterns

**Purpose:** Ensure no hardcoded name assumptions

**Test Cases:**
```bash
# Standard
junior-dev-a, junior-dev-b, junior-dev-c

# Custom prefix
dev-1, dev-2, dev-3

# Descriptive names
agent-alice, agent-bob, agent-charlie

# Short names
a, b, c

# Alphanumeric
worker-01, worker-02, worker-03
```

### Scenario 4: Different Project Names

**Purpose:** Validate project-agnostic behavior

**Test Cases:**
```bash
# Short name
x

# Standard name
my-project

# With underscores
my_project_name

# With numbers
project-2024

# Complex
enterprise-microservice-platform-v2
```

### Scenario 5: Different Directory Structures

**Purpose:** No hardcoded path assumptions

**Test Cases:**
```bash
# Standard
/Users/name/projects/myproj

# With spaces
/Users/name/My Projects/test

# Deep nesting
/Users/name/work/clients/acme/projects/web/myproj

# Different user
/home/otheruser/code/proj

# Short path
/tmp/p
```

### Scenario 6: Error Handling & Recovery

**Purpose:** Graceful failure handling

**Test Cases:**
- Missing required files
- Invalid configuration values
- Insufficient permissions
- Partial installation (interrupted)
- Corrupted configuration

---

## Regression Prevention Strategy

### 1. Past Failure Documentation

Maintain a log of all failures caught (or missed):

```markdown
### Known Failure: Hardcoded Agent Detection (Issue #36)
- **Pattern:** case statement with a|b|c
- **Detection:** `grep -rE "junior-dev-[abc]"`
- **Prevention:** Always use dynamic worktree detection
```

### 2. Cross-Project Pattern Checking

Before approving PR, check if similar issue exists in:
- Other worktrees
- Other branches
- Related projects
- Past declined PRs

### 3. Automated Pattern Detection

Run before every approval:
```bash
# Check for known bad patterns
./scripts/check-antipatterns.sh

# Checks:
# - Hardcoded names
# - Hardcoded paths
# - Hardcoded counts
# - Missing validation
# - Missing error handling
```

### 4. Learning Accumulation

After each failure:
1. Document pattern in this file
2. Add detection method
3. Update test suite
4. Update checklist

---

## Testing Workflow (Step-by-Step)

### Step 1: Initial Review
- [ ] Read PR description and objectives
- [ ] Read ticket acceptance criteria
- [ ] Identify claims ("project-agnostic", etc.)
- [ ] Note testing scope needed

### Step 2: Static Analysis
- [ ] Run grep for hardcoded patterns
- [ ] Check for antipatterns
- [ ] Review test coverage
- [ ] Verify edge cases tested

### Step 3: Dynamic Testing
- [ ] Test with minimum configuration (1 agent)
- [ ] Test with typical configuration (3 agents)
- [ ] Test with maximum configuration (10 agents)
- [ ] Test with custom naming
- [ ] Test with different project name

### Step 4: E2E Validation
- [ ] Fresh installation test
- [ ] Different directory structures
- [ ] Error scenarios
- [ ] Performance validation (if applicable)

### Step 5: Regression Check
- [ ] Cross-reference past failures
- [ ] Check related code for similar issues
- [ ] Verify known patterns absent

### Step 6: Final Approval
- [ ] All tests passed
- [ ] All checklists completed
- [ ] Claims validated
- [ ] Edge cases covered
- [ ] Documentation updated

**Only approve if ALL steps complete successfully.**

---

## Template for New Learnings

```markdown
## Learning N: [Title]

**Date:** YYYY-MM-DD

**What happened:**
[Description of situation]

**What was learned:**
[Key insight or pattern discovered]

**Why it matters:**
[Impact and importance]

**Corrected approach:**
[How to do it right]

**Related documentation:**
[Links to relevant agent files or protocols]
```
