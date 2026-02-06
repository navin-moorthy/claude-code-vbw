# VBW Effort Profiles

Single source of truth for how effort levels map to agent behavior across all VBW operations.

## Overview

Effort profiles control the cost/quality tradeoff via the `effort` parameter -- an Opus 4.6 feature that adjusts reasoning depth. Higher effort means deeper analysis, more thorough verification, and more tokens consumed. Lower effort means faster execution with less exploration.

Model assignment is secondary. Thorough and Balanced profiles use Opus for maximum capability. Fast and Turbo profiles use Sonnet for cost reduction where deep reasoning is less critical.

The `effort` field in `config/defaults.json` sets the global default. Per-invocation overrides are available via the `--effort` flag.

## Profile Matrix

| Profile  | ID      | Model  | Lead | Architect | Dev    | QA     | Scout  | Debugger |
|----------|---------|--------|------|-----------|--------|--------|--------|----------|
| Thorough | EFRT-01 | Opus   | max  | max       | high   | high   | high   | high     |
| Balanced | EFRT-02 | Opus   | high | high      | medium | medium | medium | medium   |
| Fast     | EFRT-03 | Sonnet | high | medium    | medium | low    | low    | medium   |
| Turbo    | EFRT-04 | Sonnet | skip | skip      | low    | skip   | skip   | low      |

## Profile Details

### Thorough (EFRT-01)

**Model:** Opus
**Use when:** Critical features, complex architecture, production-impacting changes.

- **Lead:** max -- exhaustive research, detailed task decomposition, thorough self-review.
- **Architect:** max -- comprehensive scope analysis, detailed success criteria, full requirement mapping.
- **Dev:** high -- careful implementation, thorough inline verification, complete error handling.
- **QA:** high -- deep verification tier, full anti-pattern scan, requirement traceability check.
- **Scout:** high -- broad research, multiple sources, cross-reference findings.
- **Debugger:** high -- exhaustive hypothesis testing, full stack trace analysis.

### Balanced (EFRT-02)

**Model:** Opus
**Use when:** Standard development work, most phases. The recommended default.

- **Lead:** high -- solid research, clear decomposition, self-review.
- **Architect:** high -- complete scope, clear success criteria.
- **Dev:** medium -- focused implementation, standard verification.
- **QA:** medium -- standard verification tier.
- **Scout:** medium -- targeted research, primary sources.
- **Debugger:** medium -- focused investigation, efficient diagnosis.

### Fast (EFRT-03)

**Model:** Sonnet
**Use when:** Well-understood features, low-risk changes, iteration speed matters.

- **Lead:** high -- still needs good plans even at speed.
- **Architect:** medium -- concise scope, essential criteria only.
- **Dev:** medium -- direct implementation, minimal exploration.
- **QA:** low -- quick verification tier only.
- **Scout:** low -- single-source targeted lookups.
- **Debugger:** medium -- efficient diagnosis, no deep exploration.

### Turbo (EFRT-04)

**Model:** Sonnet
**Use when:** Quick fixes, config changes, obvious tasks, low-stakes edits.

- **Active agents:** Dev and Debugger ONLY. Lead, Architect, QA, and Scout are skipped entirely.
- **Dev:** low -- direct execution, no research phase, no planning ceremony.
- **Debugger:** low -- rapid fix-and-verify cycle.
- No planning step, no verification step. User judges output directly.

## Per-Invocation Override (EFRT-05)

Users can override the global effort setting per command invocation:

```
/vbw:build --effort=thorough
```

The `--effort` flag takes precedence over the `config/defaults.json` default for that invocation only. It does not modify the stored default.

Valid values: `thorough`, `balanced`, `fast`, `turbo`.

## Effort Logging (EFRT-06)

After each plan execution, the effort profile used is recorded in SUMMARY.md frontmatter:

```yaml
effort_used: balanced
```

This enables quality correlation: if a plan built at `fast` has verification failures, the user may want to rebuild at `balanced` or `thorough`.

## Agent Effort Parameter Mapping

Map abstract effort levels to the `effort` parameter values that Claude Code accepts:

| Level  | Behavior                                            |
|--------|-----------------------------------------------------|
| max    | No effort override (default maximum reasoning)      |
| high   | Deep reasoning with focused scope                   |
| medium | Moderate reasoning depth, standard exploration      |
| low    | Minimal reasoning, direct execution                 |
| skip   | Agent is not spawned at all                         |

When spawning a subagent, the orchestrating command sets the effort parameter based on the active profile and the agent's column value from the profile matrix above.
