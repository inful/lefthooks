#!/usr/bin/env bash
# tests/check-conventional-commit_test.sh
#
# Shell-level test for the canonical commit-msg validator hosted at
# .lefthook/commit-msg/check-conventional-commit.sh in this repo.
#
# Each case writes a candidate commit message to a temp file, invokes
# the script with that path, and asserts the expected exit code. The
# test exits non-zero on the first failure.
#
# Run from the repo root:
#   tests/check-conventional-commit_test.sh
#   make test-commit-msg

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="${REPO_ROOT}/.lefthook/commit-msg/check-conventional-commit.sh"

if [[ ! -x "${SCRIPT}" ]]; then
    echo "FAIL: ${SCRIPT} is not executable (chmod +x)" >&2
    exit 1
fi

TMPDIR="$(mktemp -d)"
trap 'rm -rf "${TMPDIR}"' EXIT

PASS=0
FAIL=0

# Helper: write $1 to a temp file, run the script, assert exit code
# equals $2, optionally assert stderr contains $3.
run_case() {
    local message="$1"
    local want_rc="$2"
    local want_stderr_contains="${3:-}"

    local msgfile="${TMPDIR}/msg.$$.$RANDOM.txt"
    printf '%s\n' "${message}" > "${msgfile}"

    set +e
    local stderr
    stderr="$("${SCRIPT}" "${msgfile}" 2>&1 1>/dev/null)"
    local got_rc=$?
    set -e

    if [[ ${got_rc} -ne ${want_rc} ]]; then
        echo "  FAIL: message=$(printf '%q' "${message}"): rc=${got_rc}, want ${want_rc}" >&2
        echo "  --- stderr ---" >&2
        echo "${stderr}" >&2
        echo "  --- end ---" >&2
        FAIL=$((FAIL + 1))
        return
    fi

    if [[ -n "${want_stderr_contains}" ]] && [[ "${stderr}" != *"${want_stderr_contains}"* ]]; then
        echo "  FAIL: message=$(printf '%q' "${message}"): stderr missing '${want_stderr_contains}'" >&2
        echo "  --- stderr ---" >&2
        echo "${stderr}" >&2
        echo "  --- end ---" >&2
        FAIL=$((FAIL + 1))
        return
    fi

    PASS=$((PASS + 1))
}

# ─── Positive cases ─────────────────────────────────────────────────────────
echo "→ Case 1: conventional commit → expect exit 0"
run_case "feat: add X" 0
[[ ${FAIL} -eq 0 ]] && echo "  PASS"

echo "→ Case 2: conventional commit with scope → expect exit 0"
run_case "feat(cli): add X" 0
[[ ${FAIL} -eq 0 ]] && echo "  PASS"

echo "→ Case 3: breaking change marker before colon → expect exit 0"
run_case "feat!: drop X" 0
[[ ${FAIL} -eq 0 ]] && echo "  PASS"

echo "→ Case 4: breaking change marker after scope → expect exit 0"
run_case "feat(api)!: drop X" 0
[[ ${FAIL} -eq 0 ]] && echo "  PASS"

echo "→ Case 5: scope with dot (preserve upper-case in upper repos) → expect exit 0"
run_case "fix(Teams.CorLib): preserve commas" 0
[[ ${FAIL} -eq 0 ]] && echo "  PASS"

# ─── Negative cases ─────────────────────────────────────────────────────────
echo "→ Case 6: bad message → expect exit 1 + 'Conventional Commits' in stderr"
run_case "add X" 1 "Conventional Commits"
[[ ${FAIL} -eq 0 ]] && echo "  PASS"

echo "→ Case 7: missing space after colon → expect exit 1"
run_case "feat:add X" 1
[[ ${FAIL} -eq 0 ]] && echo "  PASS"

echo "→ Case 8: trailing period → expect exit 1"
run_case "feat: add a thing." 1
[[ ${FAIL} -eq 0 ]] && echo "  PASS"

echo "→ Case 9: unknown type → expect exit 1"
run_case "bogus: add X" 1
[[ ${FAIL} -eq 0 ]] && echo "  PASS"

# ─── Bypasses ───────────────────────────────────────────────────────────────
echo "→ Case 10: merge message → expect exit 0"
run_case "Merge branch 'main' into feature" 0
[[ ${FAIL} -eq 0 ]] && echo "  PASS"

echo "→ Case 11: revert message → expect exit 0"
run_case 'Revert "feat: drop X"' 0
[[ ${FAIL} -eq 0 ]] && echo "  PASS"

echo "→ Case 12: fixup message → expect exit 0"
run_case "fixup! feat: drop X" 0
[[ ${FAIL} -eq 0 ]] && echo "  PASS"

echo "→ Case 13: squash message → expect exit 0"
run_case "squash! feat: drop X" 0
[[ ${FAIL} -eq 0 ]] && echo "  PASS"

# ─── Edge: first commit on a brand-new repo ─────────────────────────────────
# The script reads the current git repo's HEAD count. A brand-new repo
# with no commits has HEAD=0; the script should treat that as the
# "first commit" exception and exit 0. We exercise this by pointing
# GIT_DIR at a fresh `git init` repo so PASS / FAIL counters propagate
# correctly in the same shell.
echo "→ Case 14: first commit on brand-new repo → expect exit 0"
FRESH_REPO="${TMPDIR}/emptyrepo"
git init -q "${FRESH_REPO}"
GIT_DIR="${FRESH_REPO}/.git" run_case "feat: first commit" 0
[[ ${FAIL} -eq 0 ]] && echo "  PASS"

# ─── Trailing-period exceptions ─────────────────────────────────────────────
echo "→ Case 15: trailing 'etc.' allowed → expect exit 0"
run_case "feat: handle etc." 0
[[ ${FAIL} -eq 0 ]] && echo "  PASS"

echo "→ Case 16: trailing '...' allowed → expect exit 0"
run_case "feat: summarize..." 0
[[ ${FAIL} -eq 0 ]] && echo "  PASS"

# ─── Summary ────────────────────────────────────────────────────────────────
echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
if [[ ${FAIL} -ne 0 ]]; then
    exit 1
fi
exit 0