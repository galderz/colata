#!/usr/bin/env bash
set -euo pipefail

PREFIX="$1"
REMOTE="${2:-origin}"

echo "Local branches to delete:"
git branch --list "${PREFIX}*" | grep -v '^\*' || true

echo
echo "Remote branches to delete:"
git branch -r --list "${REMOTE}/${PREFIX}*" || true

read -p "Proceed? [y/N] " ans
[[ "$ans" == "y" || "$ans" == "Y" ]] || exit 1

# Delete local branches
git branch --list "${PREFIX}*" \
  | grep -v '^\*' \
  | xargs -r git branch -D

# Delete remote branches
git branch -r --list "${REMOTE}/${PREFIX}*" \
  | sed "s|${REMOTE}/||" \
  | xargs -r -n 1 git push "$REMOTE" --delete
