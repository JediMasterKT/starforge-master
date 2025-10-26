---
name: "qa-engineer"
skill: "webapp-testing"
---

# Webapp-Testing Skill Learnings

This file logs outcomes from using Claude Code's webapp-testing skill during PR reviews. Each entry captures what was tested, what was found, and how the skill's effectiveness improves over time through progressive disclosure.

## Purpose

The webapp-testing skill enables live UI validation during PR reviews:
- **Visual Regression Testing:** Detect layout/styling issues CI cannot catch
- **Accessibility Validation:** Keyboard navigation, ARIA labels, screen reader support
- **User Workflow Testing:** End-to-end flows in real browser
- **Cross-Browser Compatibility:** Test across different browsers (when applicable)

## Progressive Disclosure

The skill improves over time as QA-engineer logs outcomes:
1. **Initial:** Basic screenshot capture and navigation
2. **Learning:** Skill learns project-specific patterns (common components, user flows)
3. **Advanced:** Proactive suggestions based on past issues found
4. **Expert:** Anticipates regressions based on code changes

## Learning Template

Use this template when logging skill outcomes after each PR review:

```markdown
---

## Learning Entry: PR #[NUMBER]

**Date:** YYYY-MM-DD
**PR:** #[NUMBER]
**Ticket:** #[NUMBER]

**Action:** [What you asked the skill to do]
**URL Tested:** [Development server URL]
**Files Changed:** [Number of frontend files modified]

**Result:** [What the skill found]
- Screenshot 1: [Description - e.g., "Homepage rendered correctly"]
- Screenshot 2: [Description - e.g., "Found missing alt text on logo"]
- Accessibility: [Issues found - e.g., "Button missing ARIA label"]
- User Workflow: [Test result - e.g., "Login flow works end-to-end"]

**Learned:** [Patterns identified]
- [Pattern 1 - e.g., "This component always needs keyboard focus indicator"]
- [Pattern 2 - e.g., "Form validation messages must have role=alert"]

**Adaptation:** [How to use skill better next time]
- [Improvement 1 - e.g., "Test mobile viewport for responsive components"]
- [Improvement 2 - e.g., "Check color contrast ratios for new branded colors"]

---
```

## Example Entry

---

## Learning Entry: PR #123

**Date:** 2025-10-26
**PR:** #123
**Ticket:** #45

**Action:** Tested new checkout flow UI changes
**URL Tested:** http://localhost:3000/checkout
**Files Changed:** 5 frontend files (React components)

**Result:** Found 2 accessibility issues
- Screenshot 1: Checkout page renders correctly with new layout
- Screenshot 2: Payment form has proper field labels
- Accessibility Issue 1: "Proceed to Payment" button missing keyboard focus indicator
- Accessibility Issue 2: Error message for invalid card number not announced to screen readers
- User Workflow: Completed checkout flow successfully (happy path)

**Learned:** Checkout flows need extra accessibility attention
- Payment-related buttons must have clear focus indicators (financial transaction = high stakes)
- Error messages in forms must use `role="alert"` and `aria-live="assertive"`
- Credit card input masking should not break screen reader input

**Adaptation:** For future checkout/payment PRs
- Always test keyboard-only navigation (no mouse)
- Verify error messages with screen reader simulation
- Check WCAG 2.1 AA compliance for financial forms

---

## Guidelines for Effective Skill Usage

### When to Use webapp-testing Skill

**Always use for:**
- Frontend code changes (React, Vue, HTML/CSS, JavaScript)
- New UI components or pages
- Layout/styling modifications
- Form submissions and user interactions
- Accessibility-critical features (navigation, forms, modals)

**Skip for:**
- Backend-only PRs (bash scripts, Python, infrastructure)
- Configuration changes (JSON, YAML, .env)
- Documentation updates (markdown files)

### What to Test

**Visual Regression:**
- Layout matches design
- Responsive breakpoints work
- Colors/fonts correct
- Images/icons display properly
- No overlapping elements

**Accessibility:**
- Keyboard navigation (Tab, Enter, Escape, Arrow keys)
- Focus indicators visible
- ARIA labels present and correct
- Screen reader announcements work
- Color contrast meets WCAG 2.1 AA
- Form labels associated with inputs

**User Workflows:**
- Can user complete primary task?
- Error states display correctly
- Loading states show feedback
- Success messages confirm actions

**Cross-Browser (if applicable):**
- Chrome (primary)
- Firefox (if project supports)
- Safari (if Mac available)
- Mobile browsers (if responsive)

### How to Invoke the Skill

The skill is invoked automatically by Claude Code when:
1. QA-engineer is in Gate 3 (Live UI Validation)
2. Frontend files detected in PR
3. Dev server started successfully
4. QA-engineer describes what to test

**Example invocation in PR review:**
```
I need to test the new dashboard UI changes. The dev server is running at http://localhost:3000/dashboard. Please:
1. Capture screenshots of the dashboard page
2. Test keyboard navigation through all interactive elements
3. Verify ARIA labels on the new chart components
4. Test the filter workflow end-to-end
5. Check responsive behavior at mobile breakpoint (375px)
```

The skill will:
- Navigate to the URL
- Execute the test steps
- Capture screenshots
- Report findings
- Suggest improvements

### Logging Best Practices

**Do:**
- ✅ Log EVERY skill invocation (builds knowledge base)
- ✅ Be specific about what was tested
- ✅ Include both successes and failures
- ✅ Document patterns you notice
- ✅ Note false positives (skill flagged non-issue)
- ✅ Record skill's effectiveness (saved time, caught bugs)

**Don't:**
- ❌ Skip logging "uneventful" tests (no issues found)
- ❌ Copy/paste generic entries (be specific)
- ❌ Forget to update adaptation section
- ❌ Log without reading skill output carefully

### Measuring Skill Effectiveness

Track these metrics in learnings:
- **Bugs caught:** Visual regressions found by skill
- **Accessibility issues:** WCAG violations detected
- **False positives:** Skill flagged non-issues (improve prompts)
- **Time saved:** Estimated manual testing time avoided
- **Coverage:** % of UI changes tested with skill

**Goal:** Skill becomes more effective over time as QA-engineer learns to:
1. Prompt skill more precisely
2. Focus on high-risk areas
3. Interpret skill output faster
4. Build project-specific testing patterns

---

## Skill Learnings Log

Entries below are auto-generated during PR reviews. Each entry follows the template above.

---
