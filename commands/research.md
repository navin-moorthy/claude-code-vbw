---
description: Run standalone research by spawning Scout agent(s) for web searches and documentation lookups.
argument-hint: <research-topic> [--parallel]
allowed-tools: Read, Write, Bash, Glob, Grep, WebFetch
---

# VBW Research: $ARGUMENTS

## Context

Working directory: `!`pwd``

Current project:
```
!`head -20 .planning/PROJECT.md 2>/dev/null || echo "No project found"`
```

## Guard

1. **No topic:** If $ARGUMENTS is empty, STOP: "Usage: /vbw:research <topic> [--parallel]. Describe what you need researched."

## Steps

### Step 1: Parse arguments

Extract research topic and optional --parallel flag.
- Topic: required, free text description of what to research
- --parallel: optional, if present, spawn multiple Scout agents on sub-topics

### Step 2: Determine research scope

Analyze the topic to determine:
- Is this a single focused question (one Scout) or multi-faceted (parallel Scouts)?
- If --parallel flag: decompose topic into 2-4 sub-topics for parallel research.
- If no flag: single Scout agent handles the full topic.

### Step 3: Spawn Scout agent(s)

Spawn vbw-scout agent(s) as subagent(s) using Claude Code's Task tool:

1. Read `${CLAUDE_PLUGIN_ROOT}/agents/vbw-scout.md` using the Read tool
2. Extract the body content (everything after the closing `---` of the YAML frontmatter)
3. For single research: Use the **Task tool** once:
   - `prompt`: The extracted body content of vbw-scout.md (this becomes the subagent's system prompt)
   - `description`: The full research topic plus project context (tech stack, constraints) if relevant

4. For parallel research (--parallel or multi-faceted topic):
   - Decompose into 2-4 sub-topics
   - Use the **Task tool** once per sub-topic (up to 4 per AGNT-01)
   - Each Task call uses the same vbw-scout.md prompt but different sub-topic descriptions
   - Each Scout returns structured findings independently

### Step 4: Synthesize findings

If single Scout: present findings directly.
If parallel Scouts: synthesize findings into a coherent summary:
- Merge overlapping findings
- Note contradictions between sources
- Rank by confidence and relevance

### Step 5: Optionally persist

Ask user: "Save these findings? (y/n)"
- If yes: Write to .planning/phases/{current-phase-dir}/RESEARCH.md (or .planning/RESEARCH.md if no active phase)
- If no: findings displayed only, not persisted.

## Output Format

Follow @${CLAUDE_PLUGIN_ROOT}/references/vbw-brand.md:
- Single-line box for each research finding section
- Sources listed with arrow prefix
- Confidence levels: high checkmark, medium circle, low warning
- No ANSI color codes
