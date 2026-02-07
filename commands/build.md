---
description: Execute a planned phase through Dev agents with wave grouping, parallel execution, and optional QA verification.
argument-hint: <phase-number> [--effort=thorough|balanced|fast|turbo] [--skip-qa] [--plan=NN]
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, WebFetch
---

# VBW Build: $ARGUMENTS

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
2. **Missing phase number:** If $ARGUMENTS doesn't include a phase number (integer), STOP: "Usage: /vbw:build <phase-number> [--effort=thorough|balanced|fast|turbo] [--skip-qa] [--plan=NN]"
3. **Phase not planned:** If no PLAN.md files exist in .planning/phases/{phase-dir}/, STOP: "Phase {N} has no plans. Run /vbw:plan {N} first."
4. **Phase already complete:** If ALL PLAN.md files have corresponding SUMMARY.md files, WARN: "Phase {N} already has completed plans. Re-running will create new commits. Continue?" The user can respond or cancel.

## Steps

### Step 1: Parse arguments

Extract arguments from $ARGUMENTS:

- **Phase number** (required): integer identifying which phase to build (e.g., `3` matches `.planning/phases/03-*`)
- **--effort** (optional): one of `thorough`, `balanced`, `fast`, `turbo`. Overrides the default from `.planning/config.json` for this invocation only. Does not modify the stored default.
- **--skip-qa** (optional): if present, skip the QA verification step after all plans complete
- **--plan=NN** (optional): execute only the specified plan number instead of the full phase. Ignores wave grouping -- just runs that one plan.

Map the active effort profile to agent effort levels using `${CLAUDE_PLUGIN_ROOT}/references/effort-profiles.md`:

| Profile  | Dev    | QA     |
|----------|--------|--------|
| Thorough | high   | high   |
| Balanced | medium | medium |
| Fast     | medium | low    |
| Turbo    | low    | skip   |

Store `DEV_EFFORT` and `QA_EFFORT` for use in agent spawning.

### Step 2: Load and analyze plans

Read all PLAN.md files in `.planning/phases/{phase-dir}/`:

1. Use Glob to find files matching `.planning/phases/{phase-dir}/*-PLAN.md`
2. For each PLAN.md, read the YAML frontmatter and extract:
   - `plan`: plan number
   - `title`: plan title
   - `wave`: wave number (determines execution order group)
   - `depends_on`: list of plan numbers this plan requires to complete first
   - `autonomous`: true or false (whether the plan has checkpoints)
   - `files_modified`: list of files this plan will create or modify
3. Build wave groups: group plans by their `wave` field value
4. Identify already-completed plans: check for corresponding SUMMARY.md files (e.g., `03-01-SUMMARY.md` for `03-01-PLAN.md`)
5. If `--plan=NN` was specified: filter to only that plan, ignore wave grouping

### Step 3: Validate execution order

Before executing, verify the plan dependency graph is sound:

1. **No circular dependencies:** Walk the `depends_on` chains for each plan. If a cycle is detected (plan A depends on B which depends on A), report: "Circular dependency detected: {chain}. Fix the PLAN.md depends_on fields." STOP.
2. **Valid references:** Every entry in `depends_on` must reference a plan number that exists in this phase. If a reference is invalid, report: "Plan {N} depends on plan {M} which does not exist." STOP.
3. **No file conflicts within a wave:** For each wave group, collect all `files_modified` lists. If any two plans in the same wave modify the same file, report: "File conflict in wave {W}: {file} is modified by both plan {A} and plan {B}. Move one to a different wave." STOP.

If all validation passes, proceed to execution.

### Step 4: Execute waves sequentially

Execute each wave in numeric order. Within a wave, all plans run in parallel.

**For each wave** (sorted by wave number ascending):

Display wave banner using single-line box:

```
┌──────────────────────────────────────────┐
│  Wave {N}: {count} plan(s)               │
│  {plan-01-title}, {plan-02-title}, ...   │
└──────────────────────────────────────────┘
```

**For each plan in the wave:**

1. **Resume handling (RSLC-01, RSLC-02):**

   a. **Skip if fully complete:** If a SUMMARY.md exists for this plan with `status: complete`, display "✓ Plan {NN}: {title} -- already complete (skipping)" and move to the next plan. This provides full-plan resume.

   b. **Resume if partially complete:** If a SUMMARY.md exists with `status: partial`:
      - Read the SUMMARY.md to find which tasks were completed (check the "Files Modified" table and commit hashes)
      - Run `git log --oneline -20` to identify committed tasks by their commit messages (format: `{type}({phase}-{plan}): {task-name}`)
      - Determine the first uncommitted task number
      - When spawning the Dev agent, add to the description: "Resume from Task {N}. Tasks 1-{N-1} are already committed. Skip them and start with Task {N}."
      - Display "➜ Plan {NN}: {title} -- resuming from Task {N}"

   c. **Recover from crash:** If NO SUMMARY.md exists but `git log` shows commits matching this plan's pattern (`{type}({phase}-{plan}):`):
      - Count the committed tasks from git log
      - When spawning the Dev agent, add: "Resume from Task {N}. Tasks 1-{N-1} are already committed per git history. Skip them."
      - Display "➜ Plan {NN}: {title} -- recovering, resuming from Task {N}"

   d. **Fresh start:** If no SUMMARY.md and no matching commits: proceed normally (existing behavior).

2. **Note checkpoint plans:** If the plan has `autonomous: false`, display: "⚠ Plan {NN} has checkpoints -- will pause for user input during execution."

3. **Spawn a Dev agent** using the Task tool spawning protocol:
   a. Read `${CLAUDE_PLUGIN_ROOT}/agents/vbw-dev.md` using the Read tool
   b. Extract the body content (everything after the closing `---` of the YAML frontmatter)
   c. Use the **Task tool** to spawn the subagent:
      - `prompt`: The extracted body content of vbw-dev.md (this becomes the subagent's system prompt)
      - `description`: Include the following in the task description:
        - The full path to the PLAN.md file to execute
        - Instruction: "Execute all tasks in this plan sequentially. Create one atomic commit per task. Produce a SUMMARY.md when complete."
        - The effort level for this Dev agent: "Effort level: {DEV_EFFORT}"
        - The working directory path

**Parallel execution within a wave:** Spawn ALL Dev agents for a wave's plans using multiple Task tool calls in the SAME message. This executes them in parallel. Wait for all to complete before advancing to the next wave.

**After each plan completes:**

1. Verify the Dev agent created a SUMMARY.md file for the plan
2. Read the SUMMARY.md frontmatter to check the `status` field:
   - `complete`: Display "✓ Plan {NN}: {title} -- complete"
   - `partial`: Display "⚠ Plan {NN}: {title} -- partial (some tasks incomplete)"
   - `failed`: Display "✗ Plan {NN}: {title} -- failed"
3. If status is "failed" or "partial": Report the issue to the user and ask: "Continue to next wave, or stop here?"
4. Collect metrics from SUMMARY.md: deviations count, duration
5. **Capture agent metrics (RSLC-06, RSLC-07, RSLC-08):**
   After the Task tool returns from the Dev agent spawn:
   - Extract `total_tokens` from the Task tool response (if available in the response metadata)
   - Extract `duration_ms` from the Task tool response
   - Note any compaction events that occurred during the Dev session (look for compaction markers in the response)
   - Record these metrics in the plan's SUMMARY.md frontmatter:
     - `tokens_consumed`: total tokens from Task tool response
     - `compaction_count`: number of compaction events (0 if none)
     - `duration`: formatted duration string
   - Also accumulate phase-level metrics for the completion summary:
     - Total tokens across all plans
     - Total compactions across all plans
     - Per-agent-type breakdown (Dev tokens for execution, QA tokens for verification)

### Step 4.5: Validate SUMMARY.md (VRFY-05)

After each Dev agent completes a plan, validate the produced SUMMARY.md against the template at `${CLAUDE_PLUGIN_ROOT}/templates/SUMMARY.md`:

**Required frontmatter fields:**
- `phase`: Must match the current phase
- `plan`: Must match the plan number
- `status`: Must be one of: complete, partial, failed
- `tokens_consumed`: Must be a number (from Dev agent response metrics)
- `duration`: Must be a time string
- `deviations`: Must be a list (empty list if none)
- `completed`: Must be a date string

**Validation checks:**
1. SUMMARY.md exists at the expected path
2. YAML frontmatter parses without error
3. All required fields are present and non-empty
4. `status` is a valid value (complete/partial/failed)
5. Body contains "## What Was Built" section
6. Body contains "## Files Modified" section

**If validation fails:**
- Display "⚠ Plan {NN}: SUMMARY.md is incomplete -- missing: {list of missing fields}"
- Do NOT block execution. The build continues, but the validation failure is noted in the phase completion summary.

Per VRFY-05 in `${CLAUDE_PLUGIN_ROOT}/references/verification-protocol.md`, this is a protocol-level check, not a blocking gate.

### Step 5: Post-execution QA verification (optional)

After all waves complete (or the single plan completes if `--plan=NN` was used):

**If `--skip-qa` is NOT set AND effort is NOT turbo (turbo skips QA per EFRT-04):**

1. Read `${CLAUDE_PLUGIN_ROOT}/agents/vbw-qa.md` using the Read tool
2. Extract the body content (everything after the closing `---` of the YAML frontmatter)
3. Use the **Task tool** to spawn the QA agent:
   - `prompt`: The extracted body content of vbw-qa.md
   - `description`: Include:
     - Instruction: "Verify the completed work for phase {N} against its success criteria."
     - Paths to all PLAN.md files in this phase
     - Paths to all SUMMARY.md files produced
     - The phase section from ROADMAP.md (success criteria)
     - Effort level: "QA effort: {QA_EFFORT}"
4. QA returns structured text findings. Persist these to:
   `.planning/phases/{phase-dir}/{phase}-VERIFICATION.md`
   using the Write tool.

**If `--skip-qa` IS set or effort is turbo:**
Display: "○ QA verification skipped" (with reason: --skip-qa flag or turbo mode)

### Step 5.5: Capture phase patterns (MEMO-03)

After all plans complete (or the single plan if --plan=NN was used for a full phase), capture patterns for future planning.

Follow the pattern format defined in @${CLAUDE_PLUGIN_ROOT}/references/memory-protocol.md.

1. Create .planning/patterns/ directory if it doesn't exist: `mkdir -p .planning/patterns/`

2. Read all SUMMARY.md files from this phase. For each, extract:
   - Status (complete/partial/failed)
   - Duration (from frontmatter or inferred)
   - Deviation count and types
   - Task count

3. Compute phase-level metrics:
   - Total plans and their statuses
   - Average plan duration
   - Total execution time
   - Effort profile used
   - Total deviations

4. Determine "what worked" patterns:
   - Plans that completed with 0 deviations
   - Task sizes that stayed within budget
   - Wave structures that enabled parallelism

5. Determine "what failed" patterns:
   - Plans with deviations (and deviation types)
   - Plans marked partial or failed
   - Any file conflicts or dependency issues noted in SUMMARYs

6. Append a new entry to .planning/patterns/PATTERNS.md using the format:

   ```
   ### Phase {N}: {name} ({date})

   **What worked:**
   - {pattern}

   **What failed:**
   - {pattern or "No failures"}

   **Timing:**
   - Plans: {count}, Average: {avg}, Total: {total}
   - Effort: {profile}

   **Deviations:** {count} ({summary})
   ```

   If PATTERNS.md doesn't exist yet, create it with a header:
   ```
   # VBW Learned Patterns

   Accumulated patterns from phase builds. Read by Lead agent during planning.

   ---

   {first entry}
   ```

   If PATTERNS.md already exists, append the new entry after a `---` separator.

Note: If --plan=NN was used (single plan execution, not full phase), skip pattern capture -- patterns are only meaningful at the phase level.

### Step 6: Update state and present summary

**Update .planning/STATE.md:**
- Current position: Phase {N} complete (or "partially complete" if some plans failed)
- Plan count: completed plans / total plans
- Log the effort profile used
- Update progress bar
- Agent metrics: total tokens consumed, compaction count, per-plan breakdown (append to Performance Metrics section)

**Update .planning/ROADMAP.md:**
- Check off completed plan entries in the phase's plan list (if the roadmap uses checkboxes or status markers)

**Display completion summary** using double-line box (vbw-brand.md phase-level formatting):

```
╔═══════════════════════════════════════════════╗
║  Phase {N}: {name} -- Built                   ║
║  (or "Partially Built" if some plans failed)  ║
╚═══════════════════════════════════════════════╝

  Plan Results:
    ✓ Plan 01: {title}
    ✓ Plan 02: {title}
    ✗ Plan 03: {title} (failed)

  Metrics:
    Plans:      {completed}/{total}
    Effort:     {profile}
    Deviations: {total collected from SUMMARY.md files}

  Observability:
    Tokens:       {total tokens across all plans}
    Compactions:  {total compaction events}
    Per plan:     {avg tokens per plan}

  QA Verification:
    {PASS | PARTIAL | FAIL | skipped}
    Checks: {passed}/{total}

  ➜ Next Up
    {Suggest 1-3 commands based on context:}
    /vbw:plan {N+1} -- Plan the next phase
    /vbw:qa {N} -- Verify this phase (if QA was skipped)
    /vbw:ship -- Complete the milestone (if last phase)
```

### Step 6.5: Update CLAUDE.md

If a CLAUDE.md file exists at the project root, regenerate it following @${CLAUDE_PLUGIN_ROOT}/references/memory-protocol.md:

1. Read PROJECT.md for core value
2. Read STATE.md for current position (the just-updated state)
3. Read .planning/ACTIVE for milestone context
4. Read the Decisions section from STATE.md for key decisions (5-10 most recent)
5. Read STATE.md Skills section for installed skills
6. Read .planning/patterns/PATTERNS.md for recent patterns (3-5 most relevant)
7. Write CLAUDE.md at project root, overwriting the previous version

If CLAUDE.md does not exist (e.g., legacy project initialized before Phase 7), skip this step silently.

## Output Format

Follow @${CLAUDE_PLUGIN_ROOT}/references/vbw-brand.md for all visual formatting:
- Use the **Phase Banner** template for the phase completion banner (double-line box)
- Use the **Wave Banner** template for wave group headers (single-line box)
- Use the **Execution Progress** template for per-plan status lines (◆ ✓ ✗ ○)
- Use the **Metrics Block** template for the completion summary stats
- Use the **Next Up Block** template for navigation (➜ header, indented commands with --)
- ⚠ for warnings (checkpoint plans, partial completions)
- No ANSI color codes
