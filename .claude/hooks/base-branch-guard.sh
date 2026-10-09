#!/usr/bin/env bash
# Guard against working from a branch that was never based on origin/main.
#
# A worktree can be handed over on a branch cut from a long-dead base — hundreds
# of commits behind, files named in the task absent from its tree — and nothing
# in the session's own state makes that visible. This hook makes it visible, and
# blocks edits until the branch is re-cut.
#
# Two modes, deliberately different in cost:
#   session  - SessionStart. Fetches (network), then reports. Never blocks; a
#              session that cannot reach the remote must still be usable.
#   guard    - PreToolUse on Edit|Write. NO network — compares against whatever
#              refs/remotes/origin/main the fetch above already left
#              behind. Runs before every single edit, so it has to be cheap.
#
# The BEHIND count is the whole check. An ancestor-of-HEAD test on known-dead
# branches was removed: the 2026-07-24 history rewrite left the old branches
# sharing content (but not SHAs) with every rewritten commit, so the ancestor
# test false-positived on every active worktree. A genuinely wrong base is
# hundreds of commits behind and the count catches it on its own.
#
# A branch off `prod` — a fix cherry-picked for a Regular patch release
# (docs/releases.md §2.5) — is measured against origin/prod instead: it is
# legitimately a whole release line behind `main`, and only `prod` moving on
# without it makes it stale.
# Escape hatch: HALO_ALLOW_STALE_BASE=1 skips the block, for the rare deliberate
# case (archaeology in a stale worktree).
set -uo pipefail

MODE="${1:-session}"
REMOTE="origin"
BASE="main"
# Generous on purpose: a long session legitimately drifts a few dozen commits
# behind a busy `main`. Hundreds is not drift. This separates "stale" from
# "wrong".
STALE_LIMIT=50

# Anything unexpected here means "not our business" — a hook must never be the
# reason a session cannot start or an edit cannot land.
ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
[ -n "$ROOT" ] || exit 0
cd "$ROOT" || exit 0
git remote get-url "$REMOTE" >/dev/null 2>&1 || exit 0

if [ "$MODE" = "session" ]; then
  # Timeout comes from the hook's own `timeout` field, not `timeout(1)` — that
  # is GNU coreutils and not present on a stock macOS.
  git fetch --quiet "$REMOTE" "$BASE" 2>/dev/null
  # Separately: one fetch naming a ref the remote lacks fails WHOLE, and `prod`
  # does not exist until the first promotion — folded into the line above, it
  # would leave origin/main unrefreshed with nothing said.
  git fetch --quiet "$REMOTE" prod 2>/dev/null
fi

git rev-parse --verify --quiet "refs/remotes/$REMOTE/$BASE" >/dev/null 2>&1 || exit 0

# On `prod`'s line when the branch tracks it, or when it carries a commit of
# `prod`'s that `main` never had (a release cut or a cherry-pick there). A
# branch off `main` shares only `main`'s commits with `prod`.
if git rev-parse --verify --quiet "refs/remotes/$REMOTE/prod" >/dev/null 2>&1; then
  UPSTREAM="$(git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || true)"
  PROD_FORK="$(git merge-base HEAD "$REMOTE/prod" 2>/dev/null || true)"
  if [ "$UPSTREAM" = "$REMOTE/prod" ] || { [ -n "$PROD_FORK" ] && ! git merge-base --is-ancestor "$PROD_FORK" "$REMOTE/$BASE" 2>/dev/null; }; then
    BASE="prod"
  fi
fi

BRANCH="$(git branch --show-current 2>/dev/null)"
[ -n "$BRANCH" ] || BRANCH="(detached)"
MERGE_BASE="$(git merge-base HEAD "$REMOTE/$BASE" 2>/dev/null)" || exit 0
# How much of its base this branch was never based on. Not "how far behind HEAD is"
# — that would count the branch's own commits and read clean work as stale.
BEHIND="$(git rev-list --count "$MERGE_BASE..$REMOTE/$BASE" 2>/dev/null)" || exit 0

json_escape() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }

FIX="git fetch $REMOTE $BASE && git checkout -b <task-name> $REMOTE/$BASE"

if [ "$BEHIND" -gt "$STALE_LIMIT" ]; then
  VERDICT="wrong"
  MSG="Branch '$BRANCH' is based $BEHIND commits behind $REMOTE/$BASE (limit $STALE_LIMIT) — it was not cut from a fresh $BASE. Re-cut the branch: $FIX"
elif [ "$BEHIND" -gt 0 ]; then
  VERDICT="ok"
  MSG="Branch '$BRANCH' is based $BEHIND commit(s) behind $REMOTE/$BASE — normal drift, no action needed."
else
  VERDICT="ok"
  MSG="Branch '$BRANCH' is current with $REMOTE/$BASE."
fi

ESCAPED="$(json_escape "$MSG")"

case "$MODE" in
  session)
    if [ "$VERDICT" = "wrong" ]; then
      printf '{"systemMessage":"Stale base branch: %s","hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"BASE BRANCH PROBLEM — resolve before editing anything. %s %s/%s is the only base."}}\n' \
        "$ESCAPED" "$ESCAPED" "$REMOTE" "$BASE"
    else
      printf '{"suppressOutput":true,"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"Base branch check: %s"}}\n' "$ESCAPED"
    fi
    ;;
  guard)
    if [ "$VERDICT" = "wrong" ] && [ "${HALO_ALLOW_STALE_BASE:-}" != "1" ]; then
      printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s (Set HALO_ALLOW_STALE_BASE=1 to override.)"}}\n' "$ESCAPED"
    else
      printf '{"suppressOutput":true}\n'
    fi
    ;;
esac
exit 0
