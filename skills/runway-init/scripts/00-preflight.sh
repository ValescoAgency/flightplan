#!/usr/bin/env bash
# 00-preflight.sh — verify host environment + repo state before any
# scaffolding writes. Exits non-zero with a clear message on the first
# failure. Run from the target repo's root.
#
# Usage: 00-preflight.sh --tier=1|2 [--allow-dirty]

set -euo pipefail

TIER=
ALLOW_DIRTY=0
for arg in "$@"; do
  case "$arg" in
    --tier=1) TIER=1 ;;
    --tier=2) TIER=2 ;;
    --allow-dirty) ALLOW_DIRTY=1 ;;
    *) echo "unknown arg: $arg" >&2; exit 2 ;;
  esac
done
if [[ -z "$TIER" ]]; then
  echo "ERROR: --tier=1 or --tier=2 required" >&2
  exit 2
fi

fail() { echo "PREFLIGHT FAIL: $*" >&2; exit 1; }
ok()   { echo "  ✓ $*"; }

echo "[runway-init] preflight (tier $TIER)"

# --- Toolchain ---
command -v git >/dev/null    || fail "git not on PATH"
ok "git"

command -v node >/dev/null   || fail "node not on PATH (need ≥ 22)"
NODE_MAJOR=$(node --version | sed -E 's/^v([0-9]+)\..*/\1/')
[[ "$NODE_MAJOR" -ge 22 ]] || fail "node ≥ 22 required, found $(node --version)"
ok "node $(node --version)"

command -v docker >/dev/null || fail "docker not on PATH (Docker Desktop or Podman)"
docker info >/dev/null 2>&1  || fail "docker daemon not running — start Docker Desktop"
ok "docker daemon up"

command -v gh >/dev/null     || fail "gh not on PATH"
gh auth status >/dev/null 2>&1 || fail "gh not authenticated — run \`gh auth login\`"
ok "gh authenticated"

if [[ "$TIER" == "2" ]]; then
  command -v varlock >/dev/null || fail "varlock not on PATH (\`brew install varlock\` or \`pnpm add -g varlock\`)"
  ok "varlock $(varlock --version 2>/dev/null || echo '?')"
  command -v op >/dev/null      || fail "1Password CLI (\`op\`) not on PATH"
  ok "op $(op --version 2>/dev/null || echo '?')"
fi

# --- Repo state ---
git rev-parse --git-dir >/dev/null 2>&1 || fail "not inside a git repo"
ok "git repo: $(git rev-parse --show-toplevel)"

if [[ "$ALLOW_DIRTY" == "0" ]] && [[ -n "$(git status --porcelain)" ]]; then
  fail "working tree is dirty — commit/stash first, or pass --allow-dirty"
fi
ok "working tree clean (or --allow-dirty)"

# A brand-new repo with no commits has no HEAD yet — that's fine, the
# caller will branch + commit later regardless.
if git rev-parse --verify HEAD >/dev/null 2>&1; then
  CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
  if [[ "$CURRENT_BRANCH" == "main" ]] || [[ "$CURRENT_BRANCH" == "master" ]]; then
    echo "  ⚠  on default branch ($CURRENT_BRANCH) — caller must create a feature branch before staging"
  fi
else
  echo "  ⚠  repo has no commits yet — caller will commit on a fresh branch"
fi

echo "[runway-init] preflight OK"
