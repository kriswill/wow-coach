#!/usr/bin/env bash
# Link the wow-coach skill into a Claude Code config directory.
#
#   ./install.sh            # links into ~/.claude/skills/wow-coach
#   CLAUDE_DIR=~/elsewhere/.claude ./install.sh
#
# The skill is linked, not copied, so `git pull` (and the sim-refresh
# scripts writing into references/) update the live skill in place.
set -euo pipefail

repo="$(cd "$(dirname "$0")" && pwd)"
skills="${CLAUDE_DIR:-$HOME/.claude}/skills"
dest="$skills/wow-coach"

mkdir -p "$skills"

if [ -L "$dest" ]; then
  current="$(readlink "$dest")"
  if [ "$current" = "$repo/wow-coach" ]; then
    echo "already linked: $dest -> $current"
    exit 0
  fi
  echo "relinking $dest (was -> $current)"
  rm "$dest"
elif [ -e "$dest" ]; then
  echo "error: $dest exists and is not a symlink." >&2
  echo "Move it aside (it may hold local edits worth merging into this repo) and re-run." >&2
  exit 1
fi

ln -s "$repo/wow-coach" "$dest"
echo "linked: $dest -> $repo/wow-coach"
