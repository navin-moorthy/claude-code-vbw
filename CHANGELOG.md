# Changelog

All notable changes to VBW will be documented in this file.

## [1.0.0] - 2026-02-07

### Added

- Complete agent system: Scout, Architect, Lead, Dev, QA, Debugger with tool permissions and effort profiles
- Full command suite: 25 commands covering lifecycle, monitoring, supporting, and advanced operations
- Codebase mapping with parallel mapper agents, synthesis (INDEX.md, PATTERNS.md), and incremental refresh
- Branded visual output: Unicode box-drawing, semantic symbols, progress bars, graceful degradation
- Skills integration: stack detection, skill discovery, auto-install suggestions, agent skill awareness
- Concurrent milestones with isolated state, switching, shipping, and phase management
- Persistent memory: CLAUDE.md generation, pattern learning, session pause/resume
- Resilience: three-tier verification pipeline, failure recovery, intra-plan resume, observability
- Version management: /vbw:whats-new changelog viewer, /vbw:update plugin updater
- Effort profiles: Thorough, Balanced, Fast, Turbo controlling agent behavior
- Deviation handling: auto-fix minor, auto-add critical, auto-resolve blocking, checkpoint architectural

### Changed

- Expanded from 3 foundational commands to 25 complete commands
- VERSION bumped from 0.1.0 to 1.0.0

## [0.1.0] - 2026-02-06

### Added

- Initial plugin structure with plugin.json and marketplace.json
- Directory layout (skills/, agents/, references/, templates/, config/)
- Foundational commands: /vbw:init, /vbw:config, /vbw:help
- Artifact templates for PLAN.md, SUMMARY.md, VERIFICATION.md, PROJECT.md, STATE.md, REQUIREMENTS.md, ROADMAP.md
- Agent definition stubs for 6 agents
