---
name: skills
description: Browse and install community skills from skills.sh based on your project's tech stack.
argument-hint: [--search <query>] [--list] [--refresh]
allowed-tools: Read, Bash, Glob, Grep, WebFetch
---

# VBW Skills $ARGUMENTS

## Context

Working directory: `!`pwd``

Stack detection:
```
!`bash ${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.sh "$(pwd)" 2>/dev/null || echo '{"error":"detect-stack.sh failed"}'`
```

## Guard

1. **Script failure:** If the Context output contains `"error"`, STOP: "Stack detection failed. Make sure jq is installed and try again."

## Steps

### Step 1: Parse arguments

- **No arguments**: Run full flow (detect stack, show installed, suggest new, offer install).
- **--search \<query\>**: Skip curated suggestions, search skills.sh registry directly for \<query\>.
- **--list**: List installed skills only, no suggestions.
- **--refresh**: Force re-run of stack detection (ignore any cached results).

### Step 2: Display current state

From the Context JSON:

**Installed skills** — combine `installed.global[]` and `installed.project[]`:
```
┌─ Installed Skills ─────────────────────────┐
│ ✓ skill-name (global)                      │
│ ✓ skill-name (project)                     │
│ (or "None detected" if both arrays empty)  │
└────────────────────────────────────────────┘
```

**Detected stack** — from `detected_stack[]`:
```
  Stack: react, typescript, tailwind, vitest
```

If `--list` was passed, display installed skills and STOP here.

### Step 3: Curated suggestions

From `suggestions[]` in the Context JSON. These are skills recommended for the detected stack but not yet installed.

If `suggestions[]` is non-empty, display:
```
┌─ Suggested Skills (curated) ──────────────┐
│ ○ react-skill — recommended for react      │
│ ○ typescript-skill — recommended for ts     │
│ ○ tailwind-skill — recommended for tailwind │
└────────────────────────────────────────────┘
```

If `suggestions[]` is empty and `detected_stack[]` is non-empty:
```
  ✓ All recommended skills for your stack are already installed.
```

If `detected_stack[]` is empty AND `suggestions[]` is empty:
- If `find_skills_available` is `true`, suggest example searches:
```
  ○ No stack detected. Try searching:
    /vbw:skills --search react
    /vbw:skills --search testing
    /vbw:skills --search docker
```
- If `find_skills_available` is `false`:
```
  ○ No tech stack detected. Use --search <query> to find skills manually.
```

### Step 4: Dynamic registry search

**4a. Ensure find-skills is available**

If `find_skills_available` is `false`, ask the user via AskUserQuestion:

```
○ Skills.sh Registry

The Skills.sh registry has ~2000 community skills but requires the
find-skills meta-skill for searching. Install it now?
```
Options: "Install (Recommended)" / "Skip"

- If approved: run `npx skills add vercel-labs/skills --skill find-skills -g -y`, then continue to 4b.
- If declined: display `○ Skipped. Use --search <query> with npx skills CLI directly.` and skip to Step 5.

**4b. Determine what to search**

This step runs when:
- **--search \<query\>** was passed: search the registry for \<query\>.
- **No --search** but `detected_stack[]` is non-empty AND there are stack items with no curated mapping: automatically search the registry for each unmapped stack item. No need for the user to pass --search.
- **No --search** and all stack items have curated mappings: skip this step.

**To search the registry**, run:
```bash
npx skills find "<query>"
```

Parse the output and display results with `(registry)` attribution:
```
┌─ Registry Results ────────────────────────┐
│ ○ skill-name — description (registry)      │
│ ○ skill-name — description (registry)      │
└────────────────────────────────────────────┘
```

If `--search` was passed but `npx skills` is not available, display:
```
  ⚠ skills CLI not found. Install it with: npm install -g skills
```

### Step 5: Offer installation

Combine curated suggestions and registry results into a single list, deduplicated. Rank by relevance: curated matches first, then registry matches sorted by closest stack alignment.

Ask the user using AskUserQuestion with multiSelect:

```
Which skills would you like to install?
```

Options (max 4 due to tool limit): show each skill with its description, e.g. "skill-name — short description". Include "Skip" as the last option.

If there are more than 4 combined suggestions, show the top 4 most relevant and append:
```
  ➜ Run /vbw:skills --search <query> for more results.
```

### Step 6: Install selected skills

For each skill the user selected, run:
```bash
npx skills add <skill-name> -g -y
```

Display result for each:
```
  ✓ react-skill installed (global)
  ✗ unknown-skill — not found in registry
```

After installation, display:
```
➜ Skills take effect immediately — no restart needed.
  Run /vbw:skills --list to see all installed skills.
```

## Output Format

Follow @${CLAUDE_PLUGIN_ROOT}/references/vbw-brand-essentials.md:
- Single-line box for skill sections
- ✓ installed, ○ suggested/pending, ✗ failed, ⚠ warning
- No ANSI color codes
