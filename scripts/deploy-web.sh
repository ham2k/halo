#!/bin/bash
set -e

# Default Cloudflare Pages project name
PROJECT_NAME="halo-dev-ham2k-net"

# Which edition to build (dev | next | prod). Drives the Dart-side kEdition and
# the stamped web identity (favicon, PWA manifest, titles). Defaults to dev.
EDITION="dev"

# Parse arguments for custom project name
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --project) PROJECT_NAME="$2"; shift ;;
    --edition) EDITION="$2"; shift ;;
    *) echo "Unknown parameter passed: $1"; exit 1 ;;
  esac
  shift
done

# Get root directory (project root) relative to the scripts folder
ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
cd "$ROOT_DIR"

echo "🚀 Starting Ham2K Logger Web Build & Deployment..."

# Every target resolves all recorder path overrides, including web.
(cd "$ROOT_DIR/packages/halo_build_tools" && dart run bin/prepare_record.dart)

# 1. Build TypeScript Extensions
echo "📦 Building TypeScript extensions..."
cd "$ROOT_DIR/extensions"
npm install
npm run build

# 2. Build Flutter Web App
echo "🔨 Compiling Flutter Web app (release, edition: $EDITION)..."
cd "$ROOT_DIR/app"
flutter pub get
# Project the native version (docs/releases.md §2.2) so build/web/version.json —
# what package_info_plus reads on web — carries the marketing version + the
# shared monotonic build number instead of pubspec's 0.1.0+1. Extract the HALO_*
# tokens past dart run's build-hook noise.
eval "$(dart run tool/print_build_versions.dart 2>/dev/null | grep -oE 'HALO_[A-Z_]+=[^[:space:]]+')"
echo "Web version: $HALO_MARKETING (build $HALO_BUILD_ID)"

# The commit being deployed (docs/releases.md §2.3). This lands on the same
# Pages project the deploy workflow publishes to, so a build from here has to
# be as identifiable as one from CI: without it the deployed app reports no
# commit to Sentry and no `shas` notice rule can reach it. The rule is inlined
# rather than sourced — this script is public and runs in checkouts that carry
# no app_dist/ — and a lookup that cannot answer stops the deploy.
GIT_SHA=$(git rev-parse --short HEAD) || { echo "FATAL: cannot read the commit being deployed" >&2; exit 1; }
case "$GIT_SHA" in
  *[!0-9a-f]* | "") echo "FATAL: git named no usable commit: '$GIT_SHA'" >&2; exit 1 ;;
esac
echo "Deploying commit: $GIT_SHA"

flutter build web --release --no-tree-shake-icons --dart-define=HALO_EDITION="$EDITION" \
  --dart-define=HALO_GIT_SHA="$GIT_SHA" \
  --build-name="$HALO_MARKETING" --build-number="$HALO_BUILD_ID"

# 2b. Stamp the built bundle with this edition's identity (favicon, manifest, titles)
"$ROOT_DIR/scripts/apply-web-edition.sh" "$EDITION" "$ROOT_DIR/app/build/web"

# 2c. The deploy stamp BuildFreshnessService fetches, written from the same SHA
# that was just baked in. Both halves or neither: a deploy that bakes a SHA but
# leaves a stale stamp behind tells every open tab it is out of date, and the
# reload it offers cannot clear it.
printf '%s\n' "$GIT_SHA" > "$ROOT_DIR/app/build/web/build_sha.txt"

# 3. Deploy to Cloudflare Pages
echo "☁️ Deploying to Cloudflare Pages..."
if ! command -v wrangler &> /dev/null; then
  echo "⚠️ Cloudflare Wrangler CLI is not found globally."
  echo "Checking for npx wrangler..."
  if command -v npx &> /dev/null; then
    npx wrangler pages deploy "$ROOT_DIR/app/build/web" --project-name="$PROJECT_NAME"
  else
    echo "❌ Error: Neither wrangler nor npx is installed."
    echo "Please install wrangler using: npm install -g wrangler"
    exit 1
  fi
else
  wrangler pages deploy "$ROOT_DIR/app/build/web" --project-name="$PROJECT_NAME"
fi

echo "🎉 Deployment process completed successfully!"
