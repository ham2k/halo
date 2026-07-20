#!/usr/bin/env bash
# Cut a release from the version currently in app/lib/config/version.dart:
#   1. commit ONLY that file,
#   2. create an annotated tag,
#   3. push the branch + tag to the app-halo-dist origin — but only if the
#      current branch is already tracked there.
#
# The tag ref name and the commit/tag message are both derived from version.dart
# via tool/print_release_tag.dart, e.g. ref `v26.8.1-alpha1+73`, message
# "Release 26.8.1 alpha 1 (73)". To cut the next release, bump kBuildNumber (and
# any version fields) in version.dart, then run this again.
#
# Nothing else is committed: stage whatever other work you like; only version.dart
# lands in the release commit.

set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

VERSION_FILE="app/lib/config/version.dart"
REMOTE="app-halo-dist"

# --- Derive the tag ref name + message from version.dart (grep past dart noise).
OUT="$(cd app && dart run tool/print_release_tag.dart 2>/dev/null)"
TAG_NAME="$(printf '%s\n' "$OUT" | sed -n 's/^HALO_TAG_NAME=//p')"
TAG_MSG="$(printf '%s\n' "$OUT" | sed -n 's/^HALO_TAG_MSG=//p')"
if [ -z "$TAG_NAME" ] || [ -z "$TAG_MSG" ]; then
  echo "ERROR: could not derive the release tag from $VERSION_FILE" >&2
  exit 1
fi
echo "Release: $TAG_MSG"
echo "Tag ref: $TAG_NAME"

# --- Refuse to clobber an existing tag.
if git rev-parse -q --verify "refs/tags/$TAG_NAME" >/dev/null; then
  echo "ERROR: tag '$TAG_NAME' already exists — bump kBuildNumber first." >&2
  exit 1
fi

# --- Commit ONLY version.dart (leaves any other staged work untouched).
if git diff --quiet -- "$VERSION_FILE" && git diff --cached --quiet -- "$VERSION_FILE"; then
  echo "$VERSION_FILE has no changes; tagging the current HEAD as-is."
else
  git commit --only "$VERSION_FILE" -m "$TAG_MSG"
fi

# --- Annotated tag on the (possibly new) HEAD.
git tag -a "$TAG_NAME" -m "$TAG_MSG"

# --- Push only if this branch tracks the app-halo-dist origin.
UPSTREAM="$(git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || true)"
if [ "${UPSTREAM%%/*}" = "$REMOTE" ]; then
  BRANCH="$(git rev-parse --abbrev-ref HEAD)"
  echo "Pushing $BRANCH + tag $TAG_NAME to $REMOTE ..."
  git push "$REMOTE" "$BRANCH"
  git push "$REMOTE" "refs/tags/$TAG_NAME"
  echo "Pushed."
else
  echo "Branch upstream is '${UPSTREAM:-<none>}' (not on $REMOTE) — commit + tag are local; skipping push."
fi
