---
description: Apply a quick fix or small change with commit discipline. Turbo mode -- no planning ceremony.
argument-hint: "<description of what to fix or change>"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, WebFetch
---

# VBW Fix: $ARGUMENTS

## Context

Working directory: `!`pwd``

Current state:
```
!`cat .planning/STATE.md 2>/dev/null || echo "No state found"`
```

Config:
```
!`cat .planning/config.json 2>/dev/null || echo "No config found"`
```

## Guard

1. **Not initialized:** If .planning/ directory doesn't exist, STOP: "Run /vbw:init first."
2. **Missing description:** If $ARGUMENTS is empty, STOP: "Usage: /vbw:fix \"description of what to fix\""

## Steps

### Step 1: Parse the fix description

The entire $ARGUMENTS string (minus any flags) is the fix description. No phase number needed -- this operates on the codebase directly.

### Step 2: Resolve milestone context

Standard milestone resolution:
- If .planning/ACTIVE exists: read slug, set STATE_PATH to .planning/{slug}/STATE.md
- If .planning/ACTIVE does not exist: set STATE_PATH to .planning/STATE.md

### Step 3: Spawn Dev agent in Turbo mode

Use Task tool spawning protocol:
1. Read `${CLAUDE_PLUGIN_ROOT}/agents/vbw-dev.md`
2. Extract body after frontmatter
3. Spawn via Task tool with:
   - `prompt`: Dev agent body content
   - `description`: "Quick fix task (Turbo mode). Effort level: low. Task: {fix description}. Instructions: Implement this fix directly. Create one atomic commit with format: fix(quick): {brief description}. No SUMMARY.md needed. No PLAN.md needed. Just implement, verify the fix works, and commit. If the fix touches multiple files, still create a single commit. If the fix is ambiguous or requires architectural decisions, STOP and report back instead of guessing."

### Step 4: Verify fix was applied

After Dev agent returns:
1. Check git log for the new commit: `git log --oneline -1`
2. Verify the commit message starts with "fix(quick):"
3. If no commit was made (Dev stopped due to ambiguity), report the issue to the user

### Step 5: Present confirmation

If the fix was committed successfully, display:

```
✓ Fix applied

  {commit hash} {commit message}
  Files: {list of changed files from git diff --name-only HEAD~1}

➜ Next: /vbw:status -- View project status
```

If the Dev stopped without committing, display:

```
⚠ Fix could not be applied automatically

  {reason from Dev agent}

➜ Try: /vbw:debug "{issue}" -- Investigate further
```

## Output Format

Follow @${CLAUDE_PLUGIN_ROOT}/references/vbw-brand.md for all visual formatting:
- ✓ for success confirmation
- ⚠ for inability to apply fix
- ➜ Next Up Block for navigation
- No ANSI color codes
