#!/bin/bash
set -euo pipefail
# Atomic state file updater with flock-based locking
# Usage: update-state.sh <state-file> <jq-expression>
# Example: update-state.sh .vbw-planning/STATE.md '.status = "active"'
#
# For non-JSON state files (STATE.md), this script wraps read-modify-write
# operations with flock to prevent parallel agent overwrites.
#
# Usage patterns:
#   update-state.sh <file> append "<line>"     -- append line to file
#   update-state.sh <file> replace "<old>" "<new>" -- sed replacement
#   update-state.sh <file> json "<jq-expr>"    -- jq on JSON file

if [ $# -lt 3 ]; then
  echo "Usage: update-state.sh <file> <operation> <args...>" >&2
  exit 1
fi

STATE_FILE="$1"
OPERATION="$2"
shift 2

LOCK_FILE="${STATE_FILE}.lock"

# Use flock for atomic read-modify-write
(
  flock -w 10 200 || { echo "Could not acquire lock on $STATE_FILE" >&2; exit 1; }

  case "$OPERATION" in
    append)
      echo "$1" >> "$STATE_FILE"
      ;;
    replace)
      OLD="$1"
      NEW="$2"
      TMP=$(mktemp)
      sed "s|$OLD|$NEW|g" "$STATE_FILE" > "$TMP" && mv "$TMP" "$STATE_FILE"
      ;;
    json)
      JQ_EXPR="$1"
      TMP=$(mktemp)
      jq "$JQ_EXPR" "$STATE_FILE" > "$TMP" && mv "$TMP" "$STATE_FILE"
      ;;
    *)
      echo "Unknown operation: $OPERATION. Valid: append, replace, json" >&2
      exit 1
      ;;
  esac
) 200>"$LOCK_FILE"
