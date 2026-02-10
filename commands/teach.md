---
name: teach
disable-model-invocation: true
description: View, add, or manage project conventions. Shows what VBW already knows and warns about conflicts.
argument-hint: "[\"convention text\" | remove <id> | refresh]"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# VBW Teach $ARGUMENTS

## Context

Working directory: `!`pwd``

Conventions file:
```
!`cat .vbw-planning/conventions.json 2>/dev/null || echo "No conventions found"`
```

Codebase map:
```
!`ls .vbw-planning/codebase/INDEX.md 2>/dev/null && echo "EXISTS" || echo "NONE"`
```

## Guard

Follow the Initialization Guard in `${CLAUDE_PLUGIN_ROOT}/references/shared-patterns.md` (check for `.vbw-planning/config.json` specifically).

## Convention Structure

Conventions are stored in `.vbw-planning/conventions.json`:

```json
{
  "conventions": [
    {
      "id": "CONV-001",
      "rule": "API routes go in src/routes/{resource}.ts",
      "source": "auto-detected",
      "category": "file-structure",
      "confidence": "high",
      "detected_from": "PATTERNS.md",
      "added": "2026-02-10"
    }
  ]
}
```

**Sources:**
- `auto-detected` — extracted from codebase map during `/vbw:init` or `refresh`
- `user-defined` — added manually via `/vbw:teach "convention"`

**Categories:**
- `file-structure` — where files should go
- `naming` — naming conventions (files, variables, functions, classes)
- `testing` — test framework, test file patterns, coverage requirements
- `style` — code style preferences (formatting, imports, patterns)
- `tooling` — which tools to use (linter, formatter, package manager, bundler)
- `patterns` — architectural patterns (state management, API design, error handling)
- `other` — anything else

**Confidence** (auto-detected only):
- `high` — pattern appears consistently across the codebase (80%+ of relevant files)
- `medium` — pattern is common but not universal (50-80%)
- `low` — pattern detected in some files but not dominant (<50%)

## Behavior

### No arguments: Display known conventions

**Step 1: Load conventions**

Read `.vbw-planning/conventions.json`. If it doesn't exist, display:
```
┌──────────────────────────────────────────┐
│  Project Conventions                     │
└──────────────────────────────────────────┘

  No conventions defined yet.

  VBW can auto-detect conventions from your codebase:
    /vbw:teach refresh    (requires codebase map — run /vbw:map first)

  Or add conventions manually:
    /vbw:teach "Use vitest for all tests, never jest"
    /vbw:teach "API routes go in src/routes/{resource}.ts"
```

**Step 2: Display conventions grouped by category**

```
┌──────────────────────────────────────────┐
│  Project Conventions                     │
└──────────────────────────────────────────┘

  file-structure ({count})
    CONV-001  API routes go in src/routes/{resource}.ts          [auto · high]
    CONV-005  Components in src/components/{Name}/index.tsx      [user]

  naming ({count})
    CONV-002  camelCase for variables, PascalCase for components [auto · high]

  testing ({count})
    CONV-003  Use vitest, never jest                             [user]
    CONV-004  Test files next to source: {name}.test.ts          [auto · medium]

  tooling ({count})
    CONV-006  Use pnpm, not npm or yarn                          [user]

  {count} conventions ({auto-count} auto-detected, {user-count} user-defined)
```

Tag format: `[auto · {confidence}]` for auto-detected, `[user]` for user-defined.

**Step 3: Offer actions**

Use AskUserQuestion:
- Question: "What would you like to do?"
- Options:
  - "Add a convention" — proceed to the add flow
  - "Refresh from codebase" — re-run auto-detection (only if codebase map exists)
  - "Done" — exit

### Text argument: Add a convention

If $ARGUMENTS is quoted text (a convention rule):

**Step A1: Parse the convention**

Extract the rule text. Infer the most likely category from the content:
- Mentions file paths, directories, "go in", "live in" → `file-structure`
- Mentions casing, naming, prefixes, suffixes → `naming`
- Mentions test, testing, coverage, vitest, jest, pytest → `testing`
- Mentions style, formatting, imports, semicolons → `style`
- Mentions tool names (eslint, prettier, pnpm, docker) → `tooling`
- Mentions patterns, architecture, state, API design → `patterns`
- Otherwise → `other`

**Step A2: Check for conflicts**

Compare the new convention against ALL existing conventions:

1. **Semantic conflict:** Does the new rule contradict an existing one?
   - Example: existing "Use jest for tests" conflicts with new "Use vitest for tests"
   - Example: existing "camelCase for files" conflicts with new "kebab-case for files"

2. **Redundancy:** Is the new rule essentially the same as an existing one?
   - Example: existing "Tests use vitest" is redundant with "Use vitest for all tests"

If a conflict is found:
```
  ⚠ Conflict detected:

    Existing:  CONV-003  Use jest for all tests                  [user]
    New:       Use vitest for all tests, never jest

    These conventions appear to contradict each other.
```

Use AskUserQuestion:
- Question: "How should this be resolved?"
- Options:
  - "Replace existing" — remove the old, add the new
  - "Keep both" — add anyway (user knows best)
  - "Cancel" — don't add

If redundancy found:
```
  ○ This looks similar to an existing convention:

    Existing:  CONV-003  Use vitest for tests                    [user]
    New:       Use vitest for all tests, never jest
```

Use AskUserQuestion:
- Question: "This looks like an existing convention. What should we do?"
- Options:
  - "Replace with new version" — update the existing rule text
  - "Add as separate" — add anyway
  - "Cancel" — don't add

**Step A3: Confirm category**

Display the inferred category and ask if it's correct:

Use AskUserQuestion:
- Question: "Category for this convention?"
- Options: the inferred category (marked as recommended), plus 2-3 other likely categories

**Step A4: Save**

1. Generate next ID: `CONV-{NNN}` (zero-padded, next sequential)
2. Add to conventions array in `.vbw-planning/conventions.json`
3. Display: `✓ Added CONV-{NNN}: {rule} [{category}]`

**Step A5: Update CLAUDE.md**

After adding, regenerate the Project Conventions section in CLAUDE.md. Read the current CLAUDE.md, find the `## Project Conventions` section (or add it before `## Commands` if missing), and replace it with the current conventions list.

Format for CLAUDE.md:
```markdown
## Project Conventions

These conventions are enforced during planning and verified during QA.

- {rule} [{category}]
- {rule} [{category}]
```

Keep only the rule text and category — no IDs, no source tags, no confidence levels. CLAUDE.md is for the model, not the human.

### `remove <id>`: Remove a convention

1. Parse the convention ID from $ARGUMENTS
2. Find the convention in conventions.json
3. If not found: `⚠ Convention not found: {id}`
4. Display the convention and ask for confirmation
5. Remove from conventions.json
6. Update CLAUDE.md
7. Display: `✓ Removed {id}: {rule}`

### `refresh`: Re-run auto-detection

**Step R1: Check prerequisites**

If `.vbw-planning/codebase/` does not exist:
```
  ⚠ No codebase map found. Run /vbw:map first.
```

**Step R2: Extract conventions from map**

Read the following codebase map documents (if they exist):
- `.vbw-planning/codebase/PATTERNS.md` — coding patterns, naming conventions, file structure
- `.vbw-planning/codebase/ARCHITECTURE.md` — architectural patterns, module structure
- `.vbw-planning/codebase/STACK.md` — tooling conventions (framework, test runner, linter)
- `.vbw-planning/codebase/CONCERNS.md` — existing issues that imply "don't do this" conventions

For each document, extract concrete, actionable conventions. Rules for extraction:

1. **Be specific, not generic.** "Components use PascalCase naming" is good. "Code should be clean" is not a convention.
2. **Only extract patterns that are actually present in the codebase.** The map describes what IS, not what SHOULD BE.
3. **Assign confidence based on consistency language** in the map:
   - "consistently", "always", "all files" → `high`
   - "most", "commonly", "typical" → `medium`
   - "some", "occasionally", "mixed" → `low`
4. **Skip low-confidence detections** unless they're the only pattern for that category.
5. **Maximum 15 auto-detected conventions.** Quality over quantity.

**Step R3: Reconcile with existing**

Compare auto-detected conventions against existing ones:

- **User-defined conventions always win.** Never replace or modify a user-defined convention with an auto-detected one.
- **Replace stale auto-detected:** If an existing auto-detected convention conflicts with a newly detected one, replace the old one (the codebase may have changed).
- **Add new detections:** Auto-detected conventions not conflicting with existing ones are added.
- **Remove orphaned auto-detections:** If a previously auto-detected convention is no longer detectable (pattern disappeared from codebase), remove it.

**Step R4: Save and display**

1. Write updated conventions.json
2. Display summary:
```
  ✓ Convention refresh complete

    Added:    {count} new auto-detected conventions
    Updated:  {count} existing conventions refreshed
    Removed:  {count} stale conventions removed
    Kept:     {count} user-defined conventions unchanged

    Total: {count} conventions ({auto} auto-detected, {user} user-defined)
```

3. Update CLAUDE.md with the new conventions section

## Convention Injection

Conventions are injected into agent context via CLAUDE.md's `## Project Conventions` section. Since CLAUDE.md is loaded into every session's system prompt, all agents — Lead, Dev, QA — receive conventions automatically.

The QA agent specifically checks conventions during verification:
- Each user-defined convention is treated as a verification criterion
- Auto-detected conventions with `high` confidence are also checked
- Violations appear as deviations in SUMMARY.md

## Output Format

Follow @${CLAUDE_PLUGIN_ROOT}/references/vbw-brand-essentials.md:
- Single-line box for convention display
- ✓ for successful operations
- ⚠ for conflicts and warnings
- ○ for skipped/informational items
- No ANSI color codes
