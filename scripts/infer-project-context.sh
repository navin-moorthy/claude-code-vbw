#!/usr/bin/env bash
set -euo pipefail

# infer-project-context.sh — Extract project context from codebase mapping files
#
# Usage: infer-project-context.sh CODEBASE_DIR [REPO_ROOT]
#   CODEBASE_DIR  Path to .vbw-planning/codebase/ mapping files
#   REPO_ROOT     Optional, defaults to current directory (for git repo name extraction)
#
# Output: Structured JSON to stdout with source attribution per field
# Exit: 0 on success, non-zero only on critical errors (missing CODEBASE_DIR)

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  echo "Usage: infer-project-context.sh CODEBASE_DIR [REPO_ROOT]"
  echo ""
  echo "Extract project context from codebase mapping files."
  echo ""
  echo "  CODEBASE_DIR  Path to .vbw-planning/codebase/ mapping files"
  echo "  REPO_ROOT     Optional, defaults to current directory"
  echo ""
  echo "Outputs structured JSON to stdout with source attribution per field."
  exit 0
fi

if [[ $# -lt 1 ]]; then
  echo "Error: CODEBASE_DIR is required" >&2
  echo "Usage: infer-project-context.sh CODEBASE_DIR [REPO_ROOT]" >&2
  exit 1
fi

CODEBASE_DIR="$1"
REPO_ROOT="${2:-$(pwd)}"

if [[ ! -d "$CODEBASE_DIR" ]]; then
  echo "Error: CODEBASE_DIR does not exist: $CODEBASE_DIR" >&2
  exit 1
fi

exit 0
