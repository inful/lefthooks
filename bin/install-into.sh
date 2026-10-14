#!/usr/bin/env bash
# bin/install-into.sh — wire up the shared lefthook config in a consumer repo.
#
# Usage:
#   bin/install-into.sh <path-to-consumer-repo>
#   bin/install-into.sh --help
#
# What this does:
#   1. Verifies the consumer is a git repo.
#   2. If <consumer>/lefthook.yml is missing, copies the canonical
#      template from this repo's templates/lefthook.yml.
#   3. Warns (does not fail) if the existing lefthook.yml doesn't
#      reference github.com/inful/lefthooks.
#   4. Runs `lefthook install` in the consumer to wire up the git hooks.
#   5. Prints a summary of what was done.
#
# Exit codes:
#   0  success
#   1  consumer is not a git repo (or git repo is unreadable)
#   2  lefthook not on PATH, or invalid arguments
#   3  template missing (this repo's templates/lefthook.yml was deleted)
#
# Re-runnable. Idempotent. Safe to run after a fresh `git clone` of a consumer.

set -euo pipefail

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    sed -n '2,/^$/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit 0
fi

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <path-to-consumer-repo>" >&2
    echo "       $0 --help" >&2
    exit 2
fi

CONSUMER="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CENTRAL_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TEMPLATE="${CENTRAL_ROOT}/templates/lefthook.yml"

if [ ! -d "${CONSUMER}" ]; then
    echo "Error: ${CONSUMER} is not a directory." >&2
    exit 2
fi

if ! git -C "${CONSUMER}" rev-parse --git-dir >/dev/null 2>&1; then
    echo "Error: ${CONSUMER} is not a git repository." >&2
    exit 1
fi

if ! command -v lefthook >/dev/null 2>&1; then
    echo "Error: lefthook is not on PATH." >&2
    echo "       Install with: mise install lefthook" >&2
    echo "       Or: brew install lefthook" >&2
    exit 2
fi

CONSUMER_ABS="$(cd "${CONSUMER}" && pwd)"

# ─── Step 1: ensure lefthook.yml exists ───────────────────────────────────
if [ ! -f "${CONSUMER_ABS}/lefthook.yml" ]; then
    if [ ! -f "${TEMPLATE}" ]; then
        echo "Error: template not found at ${TEMPLATE}." >&2
        echo "       Re-clone github.com/inful/lefthooks or restore templates/lefthook.yml." >&2
        exit 3
    fi
    echo "→ ${CONSUMER_ABS}/lefthook.yml missing — copying template"
    cp "${TEMPLATE}" "${CONSUMER_ABS}/lefthook.yml"
    COPIED_TEMPLATE=1
else
    COPIED_TEMPLATE=0
    if ! grep -q 'inful/lefthooks' "${CONSUMER_ABS}/lefthook.yml"; then
        echo "Warning: ${CONSUMER_ABS}/lefthook.yml exists but does not reference" >&2
        echo "         github.com/inful/lefthooks. Continuing — fix the config" >&2
        echo "         if this isn't intentional." >&2
    fi
fi

# ─── Step 2: install git hooks ─────────────────────────────────────────────
echo "→ Running 'lefthook install' in ${CONSUMER_ABS}"
(
    cd "${CONSUMER_ABS}"
    lefthook install
)

# ─── Step 3: summary ───────────────────────────────────────────────────────
echo ""
echo "✓ Done."
if [ "${COPIED_TEMPLATE}" -eq 1 ]; then
    echo "  • Created lefthook.yml from the canonical template."
    echo "  • Review the file and commit it before pushing."
else
    echo "  • lefthook.yml was already present; left untouched."
fi
echo "  • Wired up git hooks in .git/hooks/."
echo ""
echo "Next steps:"
echo "  1. cd ${CONSUMER_ABS}"
echo "  2. lefthook run pre-commit   # smoke-test the hook chain"
echo "  3. git add lefthook.yml && git commit"