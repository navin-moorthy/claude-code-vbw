---
description: Display project progress dashboard with phase status, velocity metrics, and next action.
argument-hint: [--verbose] [--metrics]
allowed-tools: Read, Glob, Grep, Bash
---

# VBW Status $ARGUMENTS

## Context

Working directory: `!`pwd``

Current state:
```
!`cat .planning/STATE.md 2>/dev/null || echo "No state found"`
```

Roadmap:
```
!`cat .planning/ROADMAP.md 2>/dev/null || echo "No roadmap found"`
```

Config:
```
!`cat .planning/config.json 2>/dev/null || echo "No config found"`
```

Phase directories:
```
!`ls .planning/phases/ 2>/dev/null || echo "No phases directory"`
```

Active milestone:
```
!`cat .planning/ACTIVE 2>/dev/null || echo "No active milestone (single-milestone mode)"`
```

Milestone directories:
```
!`ls -d .planning/*/ROADMAP.md 2>/dev/null || echo "No milestone directories"`
```

## Guard

1. **Not initialized:** If .planning/ directory doesn't exist, STOP: "Run /vbw:init first."
2. **No roadmap:** If .planning/ROADMAP.md doesn't exist, STOP: "No roadmap found. Run /vbw:init to create one."

## Steps

### Step 1: Parse arguments

Extract optional flags from $ARGUMENTS:

- **--verbose** (optional): Show per-plan detail within each phase, including individual plan status, title, and duration if complete.
- **--metrics** (optional): Show detailed token consumption breakdown per agent type and compaction event history. This is the observability view.

If no arguments are provided, display the standard dashboard view.

### Step 2: Read project data

Gather data from multiple sources:

**From STATE.md:**
- Project name (from Project Reference section)
- Current phase number and name
- Overall progress percentage
- Velocity metrics: total plans completed, average duration, total execution time, per-phase breakdown

**From ROADMAP.md:**
- All phases with their names
- Phase status markers (checked `[x]` = complete, unchecked `[ ]` = incomplete)
- Plan counts per phase (from the Plans subsections)
- Success criteria for each phase

**From config.json:**
- Current effort profile (mode field)

**From .planning/phases/ directories:**
- For each phase directory, use Glob to find `*-PLAN.md` and `*-SUMMARY.md` files
- Count PLAN.md files (total plans per phase)
- Count SUMMARY.md files (completed plans per phase)
- This gives real-time completion data independent of STATE.md

**From SUMMARY.md frontmatter (for --metrics mode):**
- For each completed plan, read SUMMARY.md frontmatter to extract:
  - `tokens_consumed`: total tokens for this plan's execution
  - `compaction_count`: number of compaction events during execution
  - `duration`: execution time
  - `phase`: which phase this plan belongs to
- Accumulate per-phase totals and per-agent-type estimates:
  - Dev tokens: sum of tokens_consumed from all SUMMARY.md files
  - QA tokens: estimated from VERIFICATION.md existence (if QA ran, estimate tokens based on tier: Quick ~5K, Standard ~15K, Deep ~30K)
  - Lead tokens: estimated from plan count (each plan creation ~20K tokens)

**From .planning/ACTIVE and milestone directories:**
- Check if .planning/ACTIVE exists (multi-milestone mode)
- If ACTIVE exists: scan for all milestone directories (.planning/*/ROADMAP.md, excluding milestones/)
- For each milestone directory: read its STATE.md for position and progress
- Identify the active milestone (from ACTIVE file)

### Step 2.5: Resolve milestone context

If `.planning/ACTIVE` exists (multi-milestone mode):
- Set ACTIVE_SLUG to the content of `.planning/ACTIVE`
- Set ROADMAP_PATH to `.planning/{ACTIVE_SLUG}/ROADMAP.md`
- Set PHASES_DIR to `.planning/{ACTIVE_SLUG}/phases/`
- Gather milestone list: all directories under `.planning/` that contain `ROADMAP.md` (excluding `.planning/milestones/` which is the archive)

If `.planning/ACTIVE` does NOT exist (single-milestone mode):
- Set ROADMAP_PATH to `.planning/ROADMAP.md`
- Set PHASES_DIR to `.planning/phases/`
- No milestone list needed

Use the resolved ROADMAP_PATH and PHASES_DIR for all subsequent steps (Step 3 onward). This makes the existing logic milestone-aware without changing its structure.

### Step 3: Compute phase progress

For each phase found in the roadmap:

1. Locate the corresponding phase directory in `.planning/phases/` (e.g., Phase 3 maps to `03-*` directory)
2. Count total PLAN.md files in that directory
3. Count SUMMARY.md files (completed plans)
4. Calculate percentage: `(completed / total) * 100`, rounded to nearest integer
5. Determine display status:
   - **Complete**: All PLAN.md files have corresponding SUMMARY.md files (percentage = 100%)
   - **In Progress**: At least one SUMMARY.md exists but not all (percentage between 1-99%)
   - **Planned**: PLAN.md files exist but no SUMMARY.md files yet (percentage = 0%, but plans exist)
   - **Not Started**: No PLAN.md files exist in the directory (or directory doesn't exist)

Map status to symbols:
- Complete = ✓ (checkmark)
- In Progress = ◆ (diamond)
- Planned = ○ (circle, plans exist but none executed)
- Not Started = ○ (circle)

### Step 4: Compute velocity metrics

From STATE.md Performance Metrics section, extract:

- **Total plans completed:** Count of all SUMMARY.md files across all phases
- **Average duration:** From the "Average duration" line in STATE.md, or compute from per-phase data
- **Total execution time:** From the "Total execution time" line in STATE.md, or sum per-phase totals

If --verbose is set, also prepare per-phase breakdown:
- Phase name, plans completed count, total time for that phase, average per plan

### Step 5: Determine next action

Apply this logic to suggest the most useful next command:

1. Find the current active phase (first incomplete phase in roadmap order)
2. Check the state of that phase:
   - **Phase has PLAN.md files but not all have SUMMARY.md:** Suggest `/vbw:build {N}` to continue execution
   - **Phase is complete (all plans have summaries) and next phase has no PLAN.md files:** Suggest `/vbw:plan {N+1}` to plan the next phase
   - **Phase is complete and next phase has PLAN.md files:** Suggest `/vbw:build {N+1}` to execute the next phase
   - **All phases are complete:** Suggest `/vbw:ship` to complete the milestone
   - **No phases have any PLAN.md files:** Suggest `/vbw:plan 1` to start planning

Format the suggestion as a copy-paste command with a brief description.

Additional milestone-aware suggestions:
- If all phases of the active milestone are complete: Suggest `/vbw:audit` before `/vbw:ship`
- If multiple milestones exist: Include `/vbw:switch {other}` as an option when showing next actions

### Step 5.5: Compute metrics (--metrics mode only)

If --metrics flag is NOT set, skip this step.

**Token breakdown:**
1. Read all SUMMARY.md files across all phases (use Glob: `.planning/phases/*/*-SUMMARY.md`)
2. For each SUMMARY.md, extract `tokens_consumed` and `compaction_count` from frontmatter
3. Group by phase and compute:
   - Per-phase token total
   - Per-phase compaction count
   - Per-phase average tokens per plan
4. Compute overall totals:
   - Total tokens consumed (all phases)
   - Total compaction events (all phases)
   - Average tokens per plan (overall)
   - Estimated cost (total_tokens / 1000 * $0.015 for Opus, approximate)

**Compaction history:**
1. For each SUMMARY.md with `compaction_count > 0`:
   - Record: phase, plan, compaction count
2. Sort by phase/plan order

**Agent type estimates:**
1. Dev tokens: sum of all SUMMARY.md tokens_consumed
2. QA tokens: count VERIFICATION.md files, estimate tokens per tier
3. Lead tokens: count PLAN.md files, estimate ~20K per plan
4. Total: Dev + QA + Lead estimates

### Step 6: Display dashboard

Render the dashboard using the Status Dashboard template from vbw-brand.md.

**Header box** (double-line):

```
╔═══════════════════════════════════════════╗
║  {project-name}                           ║
║  {milestone-name or overall progress bar} ║
╚═══════════════════════════════════════════╝
```

Use the project name from STATE.md or PROJECT.md. Show the overall progress bar (10 characters wide) with percentage in the second line.

**Multi-milestone overview (if multiple milestones exist):**

If the milestone list from Step 2.5 contains more than one milestone, display a milestone overview section before the phase details:

```
  Milestones:
    ◆ {active-slug}         {progress-bar} {percent}%  ({completed}/{total} phases)
    ○ {other-slug-1}        {progress-bar} {percent}%  ({completed}/{total} phases)
    ○ {other-slug-2}        {progress-bar} {percent}%  ({completed}/{total} phases)
```

Use ◆ for the active milestone, ○ for inactive ones. Progress bars are 10 characters wide. After the milestone overview, display the full phase breakdown for the ACTIVE milestone only (using existing Step 6 phase list logic).

If only one milestone exists: skip this section and display the regular phase list (existing behavior).
If no milestones exist (single-milestone mode): skip this section entirely (existing behavior, fully backward compatible).

**Phase list:**

```
  Phases:
    ✓ Phase 1: {name}       ██████████ 100%  (3/3 plans)
    ✓ Phase 2: {name}       ██████████ 100%  (4/4 plans)
    ◆ Phase 3: {name}       ██████░░░░  60%  (2/3 plans)
    ○ Phase 4: {name}       ░░░░░░░░░░   0%  (0/3 plans)
```

Each line includes:
- Status symbol (✓ complete, ◆ in-progress, ○ not-started/planned)
- Phase number and name
- Progress bar (10 characters wide using █ for filled, ░ for empty)
- Percentage (right-aligned)
- Plan count in parentheses (completed/total plans)

**Verbose mode per-plan detail:**

If --verbose is active, after each in-progress or complete phase line, indent and show per-plan status:

```
    ✓ Phase 1: Core Framework    ██████████ 100%  (3/3 plans)
        ✓ Plan 01: Plugin skeleton                    ~3 min
        ✓ Plan 02: Agent stubs and templates           ~4 min
        ✓ Plan 03: Foundational commands               ~3 min
    ◆ Phase 4: Visual Feedback   ███░░░░░░░  33%  (1/3 plans)
        ✓ Plan 01: Expand brand reference              ~1.5 min
        ○ Plan 02: Status dashboard command
        ○ Plan 03: Visual consistency audit
```

Use ✓ for plans with SUMMARY.md, ○ for plans without. Include duration from SUMMARY.md frontmatter if available.

**Velocity metrics block:**

```
  Velocity:
    Plans completed:  {N}
    Average duration: {time}
    Total time:       {time}
```

Use Metrics Block formatting from vbw-brand.md: labels left-aligned with colons aligned vertically, values after consistent spacing, indented 2 spaces.

**Next Up block:**

```
  ➜ Next: /vbw:{command} -- {description}
```

Use the Next Up Block template from vbw-brand.md. Show the single most relevant next command determined in Step 5.

**Metrics view (if --metrics flag is set):**

Display after the standard dashboard (standard dashboard still shows):

```
  Token Consumption:
    Total:        {total tokens} tokens
    By Agent:
      Dev:        {dev tokens} ({percentage}%)
      QA:         {qa tokens} ({percentage}%)
      Lead:       {lead tokens} ({percentage}%)
    By Phase:
      Phase 1:    {tokens} ({plans} plans, {avg}/plan)
      Phase 2:    {tokens} ({plans} plans, {avg}/plan)
      ...

  Compaction Events:
    Total:        {count} across {phases-with-compactions} phases
    History:
      Phase {N}, Plan {M}: {count} compaction(s)
      ...
    (or "None recorded" if no compactions)

  Cost Estimate:
    ~${estimated} (based on Opus pricing)
```

Use Metrics Block formatting from vbw-brand.md. Labels left-aligned with colons aligned, values indented consistently.

If no SUMMARY.md files have `tokens_consumed` data (e.g., legacy plans before Phase 8), display:
```
  Token Consumption:
    No token data available. Token tracking starts with Phase 8.
```

## Output Format

Follow @${CLAUDE_PLUGIN_ROOT}/references/vbw-brand.md for all visual formatting:
- Status Dashboard template (template 4) for overall layout
- Double-line box for header
- Progress bars: 10 characters wide, █ for filled, ░ for empty
- Semantic symbols: ✓ complete, ◆ in-progress, ○ pending/not-started
- Metrics Block formatting for velocity section
- Next Up Block (template 7) for suggested action
- No ANSI color codes
- Lines under 80 characters inside boxes
- Graceful degradation: percentages paired with progress bars ensure readability if block characters fail to render
