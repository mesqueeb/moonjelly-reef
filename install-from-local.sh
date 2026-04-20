#!/bin/sh
# install-from-local.sh — remove old global reef-* skills and reinstall from this clone
set -eu

echo "=== Currently installed global skills ==="
skills list -g

echo ""
echo "=== Removing existing reef-* global skills ==="
REEF_SKILLS=$(skills list -g 2>&1 | grep -oE 'reef-[a-z0-9-]+' | sort -u)
if [ -n "$REEF_SKILLS" ]; then
  echo "$REEF_SKILLS" | xargs skills remove -g -y
else
  echo "No reef-* skills found to remove."
fi

echo ""
echo "=== Installing skills from local clone ==="
skills add . -g -y --all

echo ""
echo "=== Done. Current global skills ==="
skills list -g
