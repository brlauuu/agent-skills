#!/usr/bin/env bash
# Install skills by symlinking ./skills/* into Claude and/or Codex skill directories.
#
# Usage:
#   ./scripts/install.sh              # install for both Claude and Codex (if dirs exist)
#   ./scripts/install.sh claude       # install for Claude only
#   ./scripts/install.sh codex        # install for Codex only
#   ./scripts/install.sh --user       # install to ~/.claude/skills (default)
#   ./scripts/install.sh --project    # install to ./.claude/skills in $PWD
#
# Re-running is safe: existing symlinks are refreshed, real directories are skipped with a warning.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="$REPO_ROOT/skills"

SCOPE="user"
TARGETS=()

for arg in "$@"; do
  case "$arg" in
    claude) TARGETS+=("claude") ;;
    codex)  TARGETS+=("codex") ;;
    --user) SCOPE="user" ;;
    --project) SCOPE="project" ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) echo "unknown arg: $arg" >&2; exit 1 ;;
  esac
done

if [ ${#TARGETS[@]} -eq 0 ]; then TARGETS=("claude" "codex"); fi

claude_dir() {
  if [ "$SCOPE" = "project" ]; then echo "$PWD/.claude/skills"
  else echo "$HOME/.claude/skills"; fi
}

codex_dir() {
  if [ "$SCOPE" = "project" ]; then echo "$PWD/.codex/skills"
  else echo "$HOME/.codex/skills"; fi
}

link_into() {
  local dest="$1"
  mkdir -p "$dest"
  for skill in "$SRC_DIR"/*/; do
    [ -d "$skill" ] || continue
    local name; name="$(basename "$skill")"
    local target="$dest/$name"
    if [ -L "$target" ]; then
      rm "$target"
    elif [ -e "$target" ]; then
      echo "skip: $target exists and is not a symlink" >&2
      continue
    fi
    ln -s "$skill" "$target"
    echo "linked: $target -> $skill"
  done
}

for t in "${TARGETS[@]}"; do
  case "$t" in
    claude) link_into "$(claude_dir)" ;;
    codex)  link_into "$(codex_dir)" ;;
  esac
done
