#!/bin/bash
set -u
# PostToolUse / SubagentStop hook: Validate SUMMARY.md structure
# Non-blocking feedback only (always exit 0)

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.command // ""')

# Only check SUMMARY.md files in .vbw-planning/
if ! echo "$FILE_PATH" | grep -qE '\.vbw-planning/.*SUMMARY\.md$'; then
  exit 0
fi

if [ ! -f "$FILE_PATH" ]; then
  exit 0
fi

MISSING=""

if ! grep -q "## What Was Built" "$FILE_PATH"; then
  MISSING="${MISSING}Missing '## What Was Built' section. "
fi

if ! grep -q "## Files Modified" "$FILE_PATH"; then
  MISSING="${MISSING}Missing '## Files Modified' section. "
fi

if [ -n "$MISSING" ]; then
  jq -n --arg msg "$MISSING" '{
    "hookSpecificOutput": {
      "additionalContext": ("SUMMARY.md validation: " + $msg)
    }
  }'
fi

exit 0
