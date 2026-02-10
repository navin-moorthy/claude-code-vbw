#!/bin/bash
set -u
# PostToolUse: Auto-update STATE.md + .execution-state.json on PLAN/SUMMARY writes
# Non-blocking, fail-open (always exit 0)

update_state_md() {
  local phase_dir="$1"
  local state_md=".vbw-planning/STATE.md"

  [ -f "$state_md" ] || return 0

  local plan_count summary_count pct
  plan_count=$(ls -1 "$phase_dir"/*-PLAN.md 2>/dev/null | wc -l | tr -d ' ')
  summary_count=$(ls -1 "$phase_dir"/*-SUMMARY.md 2>/dev/null | wc -l | tr -d ' ')

  if [ "$plan_count" -gt 0 ]; then
    pct=$(( (summary_count * 100) / plan_count ))
  else
    pct=0
  fi

  local tmp="${state_md}.tmp.$$"
  sed "s/^Plans: .*/Plans: ${summary_count}\/${plan_count}/" "$state_md" | \
    sed "s/^Progress: .*/Progress: ${pct}%/" > "$tmp" 2>/dev/null && \
    mv "$tmp" "$state_md" 2>/dev/null || rm -f "$tmp" 2>/dev/null
}

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null)

# PLAN.md trigger: update plan count in STATE.md
if echo "$FILE_PATH" | grep -qE 'phases/[^/]+/[0-9]+-[0-9]+-PLAN\.md$'; then
  update_state_md "$(dirname "$FILE_PATH")"
fi

# SUMMARY.md trigger: update execution state + progress
if ! echo "$FILE_PATH" | grep -qE 'phases/.*-SUMMARY\.md$'; then
  exit 0
fi

STATE_FILE=".vbw-planning/.execution-state.json"
[ -f "$STATE_FILE" ] || exit 0
[ -f "$FILE_PATH" ] || exit 0

# Parse SUMMARY.md YAML frontmatter for phase, plan, status
PHASE=""
PLAN=""
STATUS=""
IN_FRONTMATTER=0

while IFS= read -r line; do
  if [ "$line" = "---" ]; then
    if [ "$IN_FRONTMATTER" -eq 0 ]; then
      IN_FRONTMATTER=1
      continue
    else
      break
    fi
  fi
  if [ "$IN_FRONTMATTER" -eq 1 ]; then
    key=$(echo "$line" | cut -d: -f1 | tr -d ' ')
    val=$(echo "$line" | cut -d: -f2- | sed 's/^ *//')
    case "$key" in
      phase) PHASE="$val" ;;
      plan) PLAN="$val" ;;
      status) STATUS="$val" ;;
    esac
  fi
done < "$FILE_PATH"

if [ -z "$PHASE" ] || [ -z "$PLAN" ]; then
  exit 0
fi

STATUS="${STATUS:-completed}"
TEMP_FILE="${STATE_FILE}.tmp"
jq --arg phase "$PHASE" --arg plan "$PLAN" --arg status "$STATUS" '
  if .phases[$phase] and .phases[$phase][$plan] then
    .phases[$phase][$plan].status = $status
  else
    .
  end
' "$STATE_FILE" > "$TEMP_FILE" 2>/dev/null && mv "$TEMP_FILE" "$STATE_FILE" 2>/dev/null

update_state_md "$(dirname "$FILE_PATH")"

exit 0
