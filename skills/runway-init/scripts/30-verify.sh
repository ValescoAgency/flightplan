#!/usr/bin/env bash
# 30-verify.sh — static post-install sanity checks. Runs in cwd of
# target repo. Exits non-zero if anything's wrong; output explains
# what to fix.
#
# Usage: 30-verify.sh --tier=1|2

set -euo pipefail

TIER=
for arg in "$@"; do
  case "$arg" in
    --tier=1) TIER=1 ;;
    --tier=2) TIER=2 ;;
    *) echo "unknown arg: $arg" >&2; exit 2 ;;
  esac
done
[[ -n "$TIER" ]] || { echo "ERROR: --tier=1 or --tier=2 required" >&2; exit 2; }

fail() { echo "VERIFY FAIL: $*" >&2; exit 1; }
ok()   { echo "  ✓ $*"; }

echo "[runway-init] verify (tier $TIER)"

# --- Sandcastle scaffold present ---
[[ -d .sandcastle ]]            || fail ".sandcastle/ missing"
[[ -f .sandcastle/Dockerfile ]] || fail ".sandcastle/Dockerfile missing"
ok ".sandcastle/Dockerfile present"

if [[ "$TIER" == "1" ]]; then
  # Tier 1: .sandcastle/.env.example should exist (sandcastle's normal flow)
  if [[ ! -f .sandcastle/.env.example ]]; then
    echo "  ⚠  .sandcastle/.env.example missing — sandcastle init may have failed"
  else
    ok ".sandcastle/.env.example present"
  fi
  echo "[runway-init] verify OK (tier 1)"
  exit 0
fi

# --- Tier 2 only below ---

# .env.schema at repo root ---
[[ -f .env.schema ]] || fail ".env.schema missing at repo root (Tier 2 requires it)"
ok ".env.schema present"

# Schema must reference at least the two required vars. Use grep -F to
# avoid regex pitfalls; the names are fixed.
grep -qF 'ANTHROPIC_API_KEY=' .env.schema || fail ".env.schema missing ANTHROPIC_API_KEY"
grep -qF 'GH_TOKEN='          .env.schema || fail ".env.schema missing GH_TOKEN"
ok ".env.schema declares ANTHROPIC_API_KEY + GH_TOKEN"

# No literal API key values committed (basic shape check, not exhaustive).
if grep -qE '(sk-ant-[A-Za-z0-9_-]{20,}|ghp_[A-Za-z0-9]{20,}|lin_api_[A-Za-z0-9]{20,})' .env.schema 2>/dev/null; then
  fail ".env.schema appears to contain a real secret value — refactor to use op:// references"
fi
ok ".env.schema contains no inline secrets"

# Dockerfile patched
DF=.sandcastle/Dockerfile
grep -q 'varlock run --env-file' "$DF" || fail "Dockerfile not patched with varlock shim"
grep -q '/home/agent/.local/bin/claude.real' "$DF" || fail "Dockerfile shim not in expected layout"
ok "Dockerfile patched with varlock + claude shim"

# .sandcastle/.env should be gone
if [[ -f .sandcastle/.env ]]; then
  fail ".sandcastle/.env still on disk — Tier 2 deletes it (file may have been re-created; check sandcastle init flow)"
fi
ok ".sandcastle/.env not on disk"

# No file under target repo contains a literal sk-ant- or ghp_ token.
SECRET_HITS=$(git ls-files -z 2>/dev/null \
  | xargs -0 grep -lE '(sk-ant-[A-Za-z0-9_-]{20,}|ghp_[A-Za-z0-9]{20,}|lin_api_[A-Za-z0-9]{20,})' 2>/dev/null \
  | grep -v '^.env.schema$' || true)
if [[ -n "$SECRET_HITS" ]]; then
  fail "found literal secret values in tracked files: $SECRET_HITS"
fi
ok "no literal secret values in tracked files"

echo "[runway-init] verify OK (tier 2)"
