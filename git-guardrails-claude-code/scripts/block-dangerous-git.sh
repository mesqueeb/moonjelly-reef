#!/bin/bash

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command')

# Always blocked, everywhere
ALWAYS_BLOCKED=(
  "git reset --hard"
  "reset --hard"
  "git clean -fd"
  "git clean -f"
  "git checkout \."
  "git restore \."
  "push --force"
  "push -f "
)

for pattern in "${ALWAYS_BLOCKED[@]}"; do
  if echo "$COMMAND" | grep -qE "$pattern"; then
    echo "BLOCKED: '$COMMAND' matches dangerous pattern '$pattern'. The user has prevented you from doing this." >&2
    exit 2
  fi
done

# git branch -D: allow only if every target is a [gone] branch
if echo "$COMMAND" | grep -qE "git branch -D"; then
  # Safe pipe form: `... grep ...gone... | xargs git branch -D`
  if echo "$COMMAND" | grep -qE 'grep.*gone.*xargs.*git branch -D'; then
    : # allow
  else
    GONE=$(git branch -v 2>/dev/null | grep "\[gone\]" | awk '{print $1}')
    BRANCHES=$(echo "$COMMAND" | sed -E 's/.*git branch -D[[:space:]]+//')
    if [ -z "$BRANCHES" ]; then
      echo "BLOCKED: 'git branch -D' with no arguments." >&2
      exit 2
    fi
    for b in $BRANCHES; do
      if ! echo "$GONE" | grep -Fxq "$b"; then
        echo "BLOCKED: 'git branch -D $b' — branch is not [gone] on remote. Use 'git branch -d' for safe delete, or only force-delete branches whose upstream was deleted." >&2
        exit 2
      fi
    done
  fi
fi

# git push: allowed from worktrees, blocked from main checkout
if echo "$COMMAND" | grep -qE "git push"; then
  GIT_DIR=$(git rev-parse --git-dir 2>/dev/null)
  GIT_COMMON=$(git rev-parse --git-common-dir 2>/dev/null)

  if [ "$GIT_DIR" = "$GIT_COMMON" ]; then
    echo "BLOCKED: 'git push' is not allowed from the main checkout. Use a worktree." >&2
    exit 2
  fi

  if echo "$COMMAND" | grep -qE "git push.*(main|master|develop)"; then
    echo "BLOCKED: pushing to a protected branch (main/master/develop) is not allowed." >&2
    exit 2
  fi
fi

exit 0
