#!/usr/bin/env bash
# Guard against working from a branch that was never based on halo-dist/dist.
#
# Why this exists: a session was handed a worktree whose branch had been cut from
# the local `main` — a branch that exists on NO remote, was 353 commits behind
# `dist`, and still contained the pre-#411 secrets layout. The files named in the
# task did not exist in that tree. Nothing in the session's own state made that
# visible; the branch looked perfectly ordinary.
#
# Two modes, deliberately different in cost:
#   session  - SessionStart. Fetches (network), then reports. Never blocks; a
#              session that cannot reach the remote must still be usable.
#   guard    - PreToolUse on Edit|Write. NO network — compares against whatever
#              refs/remotes/halo-dist/dist the fetch above already left
#              behind. Runs before every single edit, so it has to be cheap.
#
# This used to ALSO flag a branch whose local `main`/`main-public` was an
# ancestor of HEAD, on the theory that either dead branch could only reach a
# real base by way of being the base itself. `dist`'s 2026-07-24 history
# rewrite (mailmap: bot@ham2k.com -> sd@ham2k.com, see project memory
# halo-dist-history-rewrite-2026-07-24) broke that theory: every commit `main`
# and `dist` once shared before that date now has a DIFFERENT sha on each side,
# but `dist`'s rewritten copy is still the same tree/message/author-date as
# main's tip — so `main` reads as an ancestor of literally every branch based
# on current `dist`, including `dist` itself. Verified this false-positives on
# every active worktree in the repo (2026-08-02); removed rather than patched
# around, since a rewrite that once again made `main`'s content diverge from
# `dist`'s would silently reintroduce the same failure mode. The BEHIND count
# below already catches the original incident on its own merit (353 commits is
# nowhere near a `STALE_LIMIT` of 50) — nothing here still needs the ancestor
# check to tell stale from normal drift.
#
# Escape hatch: HALO_ALLOW_STALE_BASE=1 skips the block, for the rare deliberate
# case (a hotfix on an old release branch, archaeology in a stale worktree).
set -uo pipefail

MODE="${1:-session}"
REMOTE="halo-dist"
BASE="dist"
# Generous on purpose: a long session legitimately drifts a few dozen commits
# behind a busy `dist`. 353 is not drift. This separates "stale" from "wrong".
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
fi

git rev-parse --verify --quiet "refs/remotes/$REMOTE/$BASE" >/dev/null 2>&1 || exit 0

BRANCH="$(git branch --show-current 2>/dev/null)"
[ -n "$BRANCH" ] || BRANCH="(detached)"
MERGE_BASE="$(git merge-base HEAD "$REMOTE/$BASE" 2>/dev/null)" || exit 0
# How much of dist this branch was never based on. Not "how far behind HEAD is"
# — that would count the branch's own commits and read clean work as stale.
BEHIND="$(git rev-list --count "$MERGE_BASE..$REMOTE/$BASE" 2>/dev/null)" || exit 0

json_escape() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }

FIX="git fetch $REMOTE $BASE && git checkout -b <task-name> $REMOTE/$BASE"

if [ "$BEHIND" -gt "$STALE_LIMIT" ]; then
  VERDICT="wrong"
  MSG="Branch '$BRANCH' is based $BEHIND commits behind $REMOTE/$BASE (limit $STALE_LIMIT) — it was not cut from a fresh dist. Re-cut the branch: $FIX"
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
