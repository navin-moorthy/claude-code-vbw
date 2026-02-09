#!/bin/bash
set -euo pipefail
# Install VBW-managed git hooks. Idempotent -- safe to run repeatedly.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Exit silently if not a git repo
if [ ! -d "$ROOT/.git" ]; then
  exit 0
fi

# Ensure hooks directory exists
mkdir -p "$ROOT/.git/hooks"

# --- pre-push hook ---
HOOK_PATH="$ROOT/.git/hooks/pre-push"
HOOK_TARGET="../../scripts/pre-push-hook.sh"

if [ -L "$HOOK_PATH" ]; then
  CURRENT_TARGET=$(readlink "$HOOK_PATH")
  if [ "$CURRENT_TARGET" = "$HOOK_TARGET" ]; then
    echo "pre-push hook already installed" >&2
  else
    echo "pre-push hook exists but is not managed by VBW -- skipping" >&2
  fi
elif [ -f "$HOOK_PATH" ]; then
  echo "pre-push hook exists but is not managed by VBW -- skipping" >&2
else
  ln -sf "$HOOK_TARGET" "$HOOK_PATH"
  echo "Installed pre-push hook" >&2
fi
