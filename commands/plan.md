---
description: Plan a phase by spawning the Lead agent for research, decomposition, and self-review.
argument-hint: <phase-number> [--effort=thorough|balanced|fast|turbo]
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, WebFetch
---

# VBW Plan: $ARGUMENTS

## Context

Working directory: `!`pwd``

Current state:
```
!`cat .planning/STATE.md 2>/dev/null || echo "No state found"`
```

Current effort setting:
```
!`cat .planning/config.json 2>/dev/null || echo "No config found"`
```

Phase directory contents:
```
!`ls .planning/phases/ 2>/dev/null || echo "No phases directory"`
```

## Guard

1. **Not initialized:** If .planning/ directory doesn't exist, STOP: "Run /vbw:init first."
2. **No roadmap:** If .planning/ROADMAP.md doesn't exist, STOP: "No roadmap found. Run /vbw:init to create one."
3. **Missing phase number:** If $ARGUMENTS doesn't include a phase number, STOP: "Usage: /vbw:plan <phase-number> [--effort=profile]"
4. **Phase not in roadmap:** If specified phase number doesn't exist in ROADMAP.md, STOP: "Phase {N} not found in roadmap."
5. **Phase already fully planned:** If .planning/phases/{phase-dir}/ contains PLAN.md files AND all have corresponding SUMMARY.md files, warn: "Phase {N} already has completed plans. Run again to re-plan (existing plans will be preserved with .bak extension)."

## Steps

### Step 1: Parse arguments

Extract phase number and optional --effort flag from $ARGUMENTS.
- Phase number: required, integer
- --effort: optional, one of thorough/balanced/fast/turbo
- If --effort not provided, use value from .planning/config.json

### Step 2: Determine execution mode

**Turbo mode** (--effort=turbo or config effort=turbo):
- Do NOT spawn Lead agent. Turbo skips Lead per effort-profiles.md.
- Read the phase requirements from ROADMAP.md directly.
- Create a single lightweight PLAN.md with all tasks in one plan.
- Minimal decomposition: list requirements as tasks, basic verify/done criteria.
- Write directly to .planning/phases/{phase-dir}/{phase}-01-PLAN.md.
- Skip to Step 6 (summary).

**Standard mode** (all other effort levels):
- Continue to Step 3.

### Step 3: Gather phase context

Read these files to build context for the Lead agent:
- .planning/ROADMAP.md (phase goal, requirements, success criteria)
- .planning/REQUIREMENTS.md (full requirement descriptions)
- .planning/STATE.md (decisions, concerns, blockers)
- .planning/PROJECT.md (core value, constraints)
- Any existing CONTEXT.md in the phase directory (from /vbw:discuss)
- Any existing RESEARCH.md in the phase directory (from /vbw:research)
- Prior phase SUMMARY.md files if this phase depends on completed phases

### Step 4: Spawn Lead agent

Spawn the vbw-lead agent as a subagent using Claude Code's Task tool:

1. Read `${CLAUDE_PLUGIN_ROOT}/agents/vbw-lead.md` using the Read tool
2. Extract the body content (everything after the closing `---` of the YAML frontmatter)
3. Use the **Task tool** to spawn the subagent:
   - `prompt`: The extracted body content of vbw-lead.md (this becomes the subagent's system prompt)
   - `description`: A task message containing all gathered phase context:
     - Phase number and name
     - Phase goal and success criteria (from ROADMAP.md)
     - All requirements mapped to this phase (from REQUIREMENTS.md)
     - Current effort profile and what it means for planning depth
     - Existing context (CONTEXT.md, RESEARCH.md if available)
     - Prior phase summaries (if this phase has dependencies)
     - Instruction: produce PLAN.md file(s) in .planning/phases/{phase-dir}/

The Lead agent will:
1. Research the phase requirements
2. Decompose into plans with 3-5 tasks each
3. Self-review plans against success criteria
4. Write PLAN.md files to disk

### Step 5: Validate Lead output

After Lead agent completes, verify:
- At least one PLAN.md file exists in .planning/phases/{phase-dir}/
- Each PLAN.md has valid YAML frontmatter (phase, plan, title, wave, depends_on, must_haves)
- Each PLAN.md has tasks with name, files, action, verify, done
- Wave assignments are consistent (no circular dependencies)

If validation fails, report issues to user.

### Step 6: Update state and present summary

Update .planning/STATE.md:
- Current position: Phase N, Plan 0 of M, Status: Planned
- Log the effort profile used

Present planning summary using vbw-brand.md formatting:
- Double-line box: "Phase {N}: {name} -- Planned"
- Plan list with wave assignments
- Task count per plan
- Effort profile used
- Next Up block: "Run /vbw:build {N} to execute this phase."

## Output Format

Follow @${CLAUDE_PLUGIN_ROOT}/references/vbw-brand.md for all visual formatting:
- Double-line box for phase planning banner
- Checkmark for completed validation checks
- Circle for plans ready to execute
- Arrow for Next Up navigation
- No ANSI color codes
