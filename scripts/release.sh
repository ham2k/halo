#!/usr/bin/env bash
# Cut a release from app/lib/config/version.dart:
#   1. work out the next build number from the release-tag ledger,
#   2. write it into version.dart (kBuildNumber),
#   3. commit ONLY version.dart,
#   4. create an annotated tag,
#   5. push the branch + tag to the app-halo-dist origin — but only if the
#      current branch is already tracked there.
#
# The build number is a single global monotonic counter, and you never bump it by
# hand: release tags are named `v<public-version>+<build>` (e.g.
# v26.8.1-alpha1+73), so the highest `+<build>` across all tags, plus one, is this
# release's number. You only edit the *version fields* (patch / pre-release) in
# version.dart, and only when they change; the tag message
# ("Release 26.8.1 alpha 1 (74)") is derived from the file too.
#
# Nothing else is committed: stage whatever other work you like; only version.dart
# lands in the release commit.
#
# Usage: scripts/release.sh [--dry-run]   (-n previews the number, tag, and
#                                          message without writing/committing/pushing)

set -euo pipefail

DRY_RUN=0
case "${1:-}" in
  --dry-run | -n) DRY_RUN=1 ;;
  "") ;;
  *) echo "usage: scripts/release.sh [--dry-run]" >&2; exit 2 ;;
esac

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

VERSION_FILE="app/lib/config/version.dart"
REMOTE="app-halo-dist"
BUILD_CAP=65535 # the 16-bit Windows/Linux FILEVERSION cap (see version.dart)

# --- Refresh tags from the origin so the sequence reflects everything shipped
#     from any machine/branch (best-effort; fall back to local tags offline).
git fetch --tags --quiet "$REMOTE" 2>/dev/null \
  || echo "warning: could not fetch tags from $REMOTE — using local tags only"

# --- Next build number = highest `+<build>` across release tags, plus one. The
#     BUILD_CAP filter ignores any stray legacy tag (e.g. a date-encoded id),
#     which would otherwise hijack the sequence with a huge number.
MAX_BUILD="$(
  git tag --list \
    | sed -n 's/.*+\([0-9][0-9]*\)$/\1/p' \
    | awk -v cap="$BUILD_CAP" '$1 >= 1 && $1 <= cap' \
    | sort -n | tail -1
)"
CUR_BUILD="$(sed -n -E 's/^const kBuildNumber = ([0-9]+);.*/\1/p' "$VERSION_FILE")"
[ -n "$CUR_BUILD" ] || { echo "ERROR: could not read kBuildNumber from $VERSION_FILE" >&2; exit 1; }

if [ -n "$MAX_BUILD" ]; then
  NEXT_BUILD=$((MAX_BUILD + 1))
else
  NEXT_BUILD="$CUR_BUILD"
  echo "No release tags found; seeding with kBuildNumber=$NEXT_BUILD from $VERSION_FILE."
fi
if [ "$NEXT_BUILD" -gt "$BUILD_CAP" ]; then
  echo "ERROR: next build number $NEXT_BUILD exceeds the $BUILD_CAP cap" >&2
  exit 1
fi

# --- Derive the tag ref name + message for this build (env override, so we can
#     preview without first writing the file).
OUT="$(cd app && HALO_BUILD_NUMBER="$NEXT_BUILD" dart run tool/print_release_tag.dart 2>/dev/null)"
TAG_NAME="$(printf '%s\n' "$OUT" | sed -n 's/^HALO_TAG_NAME=//p')"
TAG_MSG="$(printf '%s\n' "$OUT" | sed -n 's/^HALO_TAG_MSG=//p')"
if [ -z "$TAG_NAME" ] || [ -z "$TAG_MSG" ]; then
  echo "ERROR: could not derive the release tag from $VERSION_FILE" >&2
  exit 1
fi

echo "Build number: ${CUR_BUILD} -> ${NEXT_BUILD}$([ "$CUR_BUILD" = "$NEXT_BUILD" ] && echo ' (unchanged)')"
echo "Release: $TAG_MSG"
echo "Tag ref: $TAG_NAME"

if [ "$DRY_RUN" -eq 1 ]; then
  echo "(dry run — nothing written, committed, tagged, or pushed.)"
  exit 0
fi

# --- Refuse to clobber an existing tag.
if git rev-parse -q --verify "refs/tags/$TAG_NAME" >/dev/null; then
  echo "ERROR: tag '$TAG_NAME' already exists." >&2
  exit 1
fi

# --- Write the build number into version.dart so the build compiles it.
if [ "$NEXT_BUILD" != "$CUR_BUILD" ]; then
  tmp="$(mktemp)"
  sed -E "s/^const kBuildNumber = [0-9]+;/const kBuildNumber = $NEXT_BUILD;/" "$VERSION_FILE" > "$tmp"
  mv "$tmp" "$VERSION_FILE"
  grep -q "^const kBuildNumber = $NEXT_BUILD;" "$VERSION_FILE" \
    || { echo "ERROR: failed to set kBuildNumber in $VERSION_FILE" >&2; exit 1; }
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
