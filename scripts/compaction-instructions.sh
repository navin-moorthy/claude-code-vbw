#!/bin/bash
set -u
# PreCompact hook: Inject agent-specific summarization priorities
# Reads agent context and returns additionalContext for compaction

INPUT=$(cat)
AGENT_NAME=$(echo "$INPUT" | jq -r '.agent_name // .agentName // ""')

case "$AGENT_NAME" in
  *scout*)
    PRIORITIES="Preserve research findings, URLs, confidence assessments"
    ;;
  *dev*)
    PRIORITIES="Preserve commit hashes, file paths modified, deviation decisions, current task number"
    ;;
  *qa*)
    PRIORITIES="Preserve pass/fail status, gap descriptions, verification results"
    ;;
  *lead*)
    PRIORITIES="Preserve phase status, plan structure, coordination decisions"
    ;;
  *architect*)
    PRIORITIES="Preserve requirement IDs, phase structure, success criteria, key decisions"
    ;;
  *debugger*)
    PRIORITIES="Preserve reproduction steps, hypotheses, evidence gathered, diagnosis"
    ;;
  *)
    PRIORITIES="Preserve task context and key decisions"
    ;;
esac

jq -n --arg ctx "$PRIORITIES" '{
  "hookSpecificOutput": {
    "additionalContext": ("Compaction priorities: " + $ctx + ". Re-read assigned files from disk after compaction.")
  }
}'

exit 0
