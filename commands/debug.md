---
description: Investigate a bug using the Debugger agent's scientific method protocol.
argument-hint: "<bug description or error message>"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, WebFetch
---

# VBW Debug: $ARGUMENTS

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

Recent commits:
```
!`git log --oneline -10 2>/dev/null || echo "No git history"`
```

## Guard

1. **Not initialized:** If .planning/ directory doesn't exist, STOP: "Run /vbw:init first."
2. **Missing bug description:** If $ARGUMENTS is empty, STOP: "Usage: /vbw:debug \"description of the bug or error message\""

## Steps

### Step 1: Parse the bug description

The entire $ARGUMENTS string is the bug description / error message.

### Step 2: Determine effort level

Read effort from config.json or --effort flag if present. Map to Debugger effort using `${CLAUDE_PLUGIN_ROOT}/references/effort-profiles.md`:

| Profile  | Debugger Effort |
|----------|-----------------|
| Thorough | high            |
| Balanced | medium          |
| Fast     | medium          |
| Turbo    | low             |

Store as `DEBUGGER_EFFORT`.

### Step 3: Spawn Debugger agent

Use Task tool spawning protocol:
1. Read `${CLAUDE_PLUGIN_ROOT}/agents/vbw-debugger.md`
2. Extract body after frontmatter
3. Spawn via Task tool with:
   - `prompt`: Debugger agent body content
   - `description`: "Bug investigation. Effort level: {DEBUGGER_EFFORT}. Bug report: {bug description}. Working directory: {pwd}. Follow the investigation protocol: reproduce, hypothesize, gather evidence, diagnose, fix, verify, document. Produce an investigation report as your final output. If you apply a fix, commit it with format: fix({scope}): {description}."

### Step 4: Capture investigation results

Read the Debugger agent's text output. It contains the structured investigation report.

### Step 5: Present investigation summary

Display using brand formatting:

```
+------------------------------------------+
|  Bug Investigation Complete              |
+------------------------------------------+

  Issue:      {one-line from report}
  Root Cause: {from report}
  Fix:        {commit hash and message, or "No fix applied -- see report"}

  Files Modified: {list}

  Report: {if Debugger wrote to file, show path}

➜ Next: /vbw:status -- View project status
```

## Output Format

Follow @${CLAUDE_PLUGIN_ROOT}/references/vbw-brand.md for all visual formatting:
- Single-line box for investigation banner
- Metrics Block for issue/root cause/fix details
- ➜ Next Up Block for navigation
- No ANSI color codes
