#!/usr/bin/env bash
# check-conventional-commit.sh — canonical Conventional Commits validator
# for github.com/inful/* repositories.
#
# Hosted at: github.com/inful/lefthooks (file:
# .lefthook/commit-msg/check-conventional-commit.sh). Consumer repos pick
# this up via lefthook's `remotes:` mechanism; no per-repo copy required.
#
# Invoked by lefthook's commit-msg hook with the path to the commit-message
# file as $1. Exits non-zero to block the commit.
#
# Format:
#   <type>(<scope>)!: <subject>
#
# Where:
#   - type    ∈ feat, fix, docs, style, refactor, perf, test, build, ci,
#              chore, revert
#   - scope   is optional; allowed chars: lowercase letters, digits,
#              underscore, hyphen, dot (most permissive of the prior
#              per-repo scripts)
#   - !       is optional; marks a breaking change
#   - subject is required; 1–100 chars (loosest of the prior per-repo
#              limits); must not end with a trailing period unless the
#              trailing period is part of an allowed abbreviation
#              ("etc.", "vs.", "i.e.", "e.g.", "approx.") or ellipsis
#              ("...")
#
# Bypasses (auto-generated commits):
#   - "Merge ..." / "Revert ..." subjects
#   - "fixup! ..." / "squash! ..." subjects
#   - the very first commit on a brand-new repo (no HEAD yet)
#
# Spec: https://www.conventionalcommits.org/

set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "Usage: check-conventional-commit.sh <commit-msg-file>" >&2
  exit 2
fi

msg_file="$1"

if [ ! -r "$msg_file" ]; then
  echo "check-conventional-commit: cannot read '$msg_file'" >&2
  exit 2
fi

# First non-comment, non-empty line is the subject.
subject=$(awk 'NF && !/^#/ {print; exit}' "$msg_file")

# Strip trailing whitespace so the regex match isn't tripped up.
subject="${subject%"${subject##*[![:space:]]}"}"

# Allowed types per conventionalcommits.org.
types='feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert'

# <type>(scope)?!: <description>
conventional_re="^($types)(\([a-zA-Z0-9_.-]+\))?!?: .+"

# ─── Bypass: merge / revert / fixup / squash / first commit ────────────────
if [[ "$subject" =~ ^Merge[[:space:]] ]]; then
  exit 0
fi
if [[ "$subject" =~ ^Revert[[:space:]] ]]; then
  exit 0
fi
if [[ "$subject" =~ ^(fixup|squash)![[:space:]] ]]; then
  exit 0
fi
if [ "$(git rev-list --count HEAD 2>/dev/null || echo 0)" = "0" ]; then
  # First commit on a brand-new repo: no HEAD yet, nothing to compare to.
  exit 0
fi

# ─── Validate ──────────────────────────────────────────────────────────────
if ! [[ "$subject" =~ $conventional_re ]]; then
  cat >&2 <<EOF
ERROR: commit message does not follow Conventional Commits format.

  Got:      ${subject:0:80}
  Expected: <type>(<scope>)<!>: <subject>

  Allowed types: feat, fix, docs, style, refactor, perf, test, build, ci,
                 chore, revert

  Examples:
    feat: add Jira issue deep link
    fix(teams): preserve commas in users parameter
    docs: update README with new shortcode example
    refactor(api): extract user normalization
    feat!: drop Go 1.22 support

  Bypass:  git commit --no-verify (for reverts, backports, and tooling-
           generated commits that you can't rewrite).
EOF
  exit 1
fi

# Subject length check: 1-100 chars (spec recommends ≤72, but we accept
# up to 100 so per-repo history stays uninterrupted).
subject_len=${#subject}
if [ "$subject_len" -gt 100 ]; then
  echo "ERROR: commit subject is ${subject_len} characters; max is 100." >&2
  echo "  Subject: $subject" >&2
  exit 1
fi

# Subject must not end with a period unless it's an allowed abbreviation or
# an ellipsis.
desc="${subject#*: }"
if [[ "$desc" =~ \.$ ]] && [[ ${#desc} -gt 1 ]]; then
  if ! [[ "$desc" =~ \.\.\.$ ]] && \
     ! [[ "$desc" =~ (etc|vs|i\.e|e\.g|approx)\.$ ]]; then
    echo "ERROR: commit subject should not end with a period." >&2
    echo "  Subject: $subject" >&2
    exit 1
  fi
fi

exit 0