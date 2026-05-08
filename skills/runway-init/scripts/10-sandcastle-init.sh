#!/usr/bin/env bash
# 10-sandcastle-init.sh — runs `npx sandcastle init` if .sandcastle/ is
# missing, otherwise exits with a notice (the SKILL.md is responsible
# for asking the user whether to overwrite). Run from the target repo
# root.
#
# Usage: 10-sandcastle-init.sh [--force]

set -euo pipefail

FORCE=0
for arg in "$@"; do
  case "$arg" in
    --force) FORCE=1 ;;
    *) echo "unknown arg: $arg" >&2; exit 2 ;;
  esac
done

if [[ -d .sandcastle ]]; then
  if [[ "$FORCE" == "0" ]]; then
    echo "[runway-init] .sandcastle/ already exists — skipping init"
    echo "  (pass --force to delete and re-init)"
    exit 0
  fi
  echo "[runway-init] --force given, removing existing .sandcastle/"
  rm -rf .sandcastle
fi

echo "[runway-init] running \`npx -y -p @ai-hero/sandcastle@latest sandcastle init\` ..."
npx -y -p @ai-hero/sandcastle@latest sandcastle init

if [[ ! -d .sandcastle ]]; then
  echo "ERROR: sandcastle init did not produce .sandcastle/" >&2
  exit 1
fi

echo "[runway-init] .sandcastle/ scaffolded:"
ls -la .sandcastle/
