#!/usr/bin/env bash
# 20-apply-varlock.sh — Tier 2 customization layer. Runs after
# 10-sandcastle-init.sh has produced .sandcastle/. Three changes:
#
#   1. Patches .sandcastle/Dockerfile to bake in `varlock` + `op` CLI
#      and shim the `claude` binary so every invocation runs through
#      `varlock run -- claude.real`.
#   2. Scaffolds .env.schema at repo root (varlock convention) with
#      op:// references for ANTHROPIC_API_KEY + GH_TOKEN. Paths are
#      filled in from --op-account / --op-vault flags.
#   3. Deletes .sandcastle/.env and .sandcastle/.env.example so no
#      secret manifest sits at rest. The repo-root .env.schema is the
#      sole source of truth.
#
# Run from the target repo root.
#
# Usage:
#   20-apply-varlock.sh \
#       --op-account=valesco \
#       --op-vault=runway \
#       --anthropic-item=anthropic-api-key \
#       --gh-token-item=gh-token \
#       [--templates-dir=/path/to/skill/templates]

set -euo pipefail

OP_ACCOUNT=
OP_VAULT=
ANTHROPIC_ITEM=
GH_TOKEN_ITEM=
TEMPLATES_DIR=

for arg in "$@"; do
  case "$arg" in
    --op-account=*)     OP_ACCOUNT="${arg#*=}" ;;
    --op-vault=*)       OP_VAULT="${arg#*=}" ;;
    --anthropic-item=*) ANTHROPIC_ITEM="${arg#*=}" ;;
    --gh-token-item=*)  GH_TOKEN_ITEM="${arg#*=}" ;;
    --templates-dir=*)  TEMPLATES_DIR="${arg#*=}" ;;
    *) echo "unknown arg: $arg" >&2; exit 2 ;;
  esac
done

[[ -n "$OP_ACCOUNT" ]]     || { echo "ERROR: --op-account required" >&2; exit 2; }
[[ -n "$OP_VAULT" ]]       || { echo "ERROR: --op-vault required" >&2; exit 2; }
[[ -n "$ANTHROPIC_ITEM" ]] || { echo "ERROR: --anthropic-item required" >&2; exit 2; }
[[ -n "$GH_TOKEN_ITEM" ]]  || { echo "ERROR: --gh-token-item required" >&2; exit 2; }

# Default templates dir is co-located with this script.
if [[ -z "$TEMPLATES_DIR" ]]; then
  TEMPLATES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/../templates && pwd)"
fi
[[ -d "$TEMPLATES_DIR" ]] || { echo "ERROR: templates dir not found: $TEMPLATES_DIR" >&2; exit 1; }

[[ -d .sandcastle ]] || { echo "ERROR: .sandcastle/ missing — run 10-sandcastle-init.sh first" >&2; exit 1; }
[[ -f .sandcastle/Dockerfile ]] || { echo "ERROR: .sandcastle/Dockerfile missing" >&2; exit 1; }

echo "[runway-init] applying Tier 2 (varlock + 1Password) layer"

# --- 1. .env.schema at repo root ---
if [[ -f .env.schema ]]; then
  echo "  ⚠  .env.schema already exists — backing up to .env.schema.bak"
  cp .env.schema .env.schema.bak
fi

# Substitute the {{...}} placeholders. Using sed because the template
# is small + the placeholders are unambiguous.
sed \
  -e "s|{{OP_ACCOUNT}}|$OP_ACCOUNT|g" \
  -e "s|{{OP_VAULT}}|$OP_VAULT|g" \
  -e "s|{{ANTHROPIC_ITEM}}|$ANTHROPIC_ITEM|g" \
  -e "s|{{GH_TOKEN_ITEM}}|$GH_TOKEN_ITEM|g" \
  "$TEMPLATES_DIR/env.schema.target-repo" \
  > .env.schema

echo "  ✓ wrote .env.schema (op://$OP_ACCOUNT/$OP_VAULT/...)"

# --- 2. Patch Dockerfile ---
DOCKERFILE=.sandcastle/Dockerfile

# Idempotency: don't double-apply.
if grep -q 'varlock run --env-file' "$DOCKERFILE"; then
  echo "  ✓ Dockerfile already patched (idempotent skip)"
else
  # Sandcastle's stock Dockerfile ends with:
  #   ENTRYPOINT ["sleep", "infinity"]
  # We splice the varlock layer in JUST before that line.
  if ! grep -q '^ENTRYPOINT \["sleep", "infinity"\]' "$DOCKERFILE"; then
    echo "ERROR: expected \`ENTRYPOINT [\"sleep\", \"infinity\"]\` line in $DOCKERFILE" >&2
    echo "  Sandcastle may have changed its template; update templates/dockerfile-varlock.snippet" >&2
    exit 1
  fi
  TMP="$(mktemp)"
  # Everything up to (but not including) the ENTRYPOINT line:
  awk '/^ENTRYPOINT \["sleep", "infinity"\]/{exit} {print}' "$DOCKERFILE" > "$TMP"
  # The varlock snippet:
  cat "$TEMPLATES_DIR/dockerfile-varlock.snippet" >> "$TMP"
  echo "" >> "$TMP"
  # The original ENTRYPOINT line (preserve exact text):
  grep '^ENTRYPOINT \["sleep", "infinity"\]' "$DOCKERFILE" >> "$TMP"
  mv "$TMP" "$DOCKERFILE"
  echo "  ✓ patched $DOCKERFILE (varlock + op CLI + claude shim)"
fi

# --- 3. Drop .sandcastle/.env (secrets at rest) ---
for f in .sandcastle/.env .sandcastle/.env.example; do
  if [[ -f "$f" ]]; then
    rm "$f"
    echo "  ✓ removed $f"
  fi
done

# --- 4. .gitignore: keep .env.schema.bak out of commits ---
if [[ -f .gitignore ]] && ! grep -q '^\.env\.schema\.bak$' .gitignore; then
  echo ".env.schema.bak" >> .gitignore
  echo "  ✓ appended .env.schema.bak to .gitignore"
fi

echo "[runway-init] Tier 2 layer applied"
