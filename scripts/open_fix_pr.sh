#!/usr/bin/env bash
#
# open_fix_pr.sh — branch, commit, push, and open a PR for TCS IaC fixes.
#
# Assumes the working tree already contains the fix edits (this skill authors
# them before calling the script). It enforces the two rules that repeatedly
# bit us during development:
#   1. Commit messages carry NO "Claude Code" attribution and NO Co-Authored-By.
#   2. The expected gh account must be active, or the push 404s on private repos.
#
# Usage:
#   open_fix_pr.sh \
#     --repo <path-to-checkout> \
#     --branch <branch-name> \
#     --title "<PR title>" \
#     --body-file <path-to-pr-body.md> \
#     --commit "<conventional commit line <=70 chars>" \
#     [--base <base-branch>]        # default: repo's default branch
#     [--gh-user <expected-user>]   # default: tomabai
#     [--files "<pathspec> ..."]    # default: -A (all changes)
#
# Prints the PR URL on success.

set -euo pipefail

REPO="" BRANCH="" TITLE="" BODY_FILE="" COMMIT_MSG="" BASE=""
GH_USER="tomabai" FILES=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)     REPO="$2"; shift 2 ;;
    --branch)   BRANCH="$2"; shift 2 ;;
    --title)    TITLE="$2"; shift 2 ;;
    --body-file) BODY_FILE="$2"; shift 2 ;;
    --commit)   COMMIT_MSG="$2"; shift 2 ;;
    --base)     BASE="$2"; shift 2 ;;
    --gh-user)  GH_USER="$2"; shift 2 ;;
    --files)    FILES="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

for req in REPO BRANCH TITLE BODY_FILE COMMIT_MSG; do
  if [[ -z "${!req}" ]]; then echo "Missing --${req,,}" >&2; exit 2; fi
done
[[ -f "$BODY_FILE" ]] || { echo "Body file not found: $BODY_FILE" >&2; exit 2; }
if [[ ${#COMMIT_MSG} -gt 70 ]]; then
  echo "Commit message is ${#COMMIT_MSG} chars (>70): $COMMIT_MSG" >&2; exit 2
fi
# Guard the attribution rule.
if grep -qiE 'claude code|co-authored-by' <<<"$COMMIT_MSG"; then
  echo "Commit message must not mention Claude Code or add a co-author." >&2; exit 2
fi

cd "$REPO"

# --- gh account guard -------------------------------------------------------
# The login gh will actually act as (guards against silent account flips).
ACTIVE="$(gh api user --jq .login 2>/dev/null || true)"
if [[ -n "$GH_USER" && -n "$ACTIVE" && "$ACTIVE" != "$GH_USER" ]]; then
  echo "gh active account is '$ACTIVE', expected '$GH_USER'. Switching..." >&2
  gh auth switch -u "$GH_USER"
  gh auth setup-git -h github.com   # re-sync credential helper after switch
fi

# --- determine base branch --------------------------------------------------
if [[ -z "$BASE" ]]; then
  BASE="$(gh repo view --json defaultBranchRef --jq .defaultBranchRef.name 2>/dev/null || echo main)"
fi

# --- branch, commit, push ---------------------------------------------------
git fetch origin "$BASE" --quiet || true
git checkout -B "$BRANCH" "origin/$BASE" 2>/dev/null || git checkout -B "$BRANCH"

if [[ -n "$FILES" ]]; then
  # shellcheck disable=SC2086
  git add $FILES
else
  git add -A
fi

if git diff --cached --quiet; then
  echo "No staged changes to commit — did the fixes get written?" >&2; exit 1
fi

git commit -m "$COMMIT_MSG"

if ! git push -u origin "$BRANCH" 2>push.err; then
  if grep -qi 'repository not found' push.err; then
    echo "Push failed with 'Repository not found' — re-syncing git credentials." >&2
    gh auth setup-git -h github.com
    git push -u origin "$BRANCH"
  else
    cat push.err >&2; rm -f push.err; exit 1
  fi
fi
rm -f push.err

# --- open the PR ------------------------------------------------------------
PR_URL="$(gh pr create --base "$BASE" --head "$BRANCH" \
  --title "$TITLE" --body-file "$BODY_FILE")"

echo "$PR_URL"
