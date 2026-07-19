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

# 1. Build TypeScript Extensions
echo "📦 Building TypeScript extensions..."
cd "$ROOT_DIR/extensions"
npm install
npm run build

# 2. Build Flutter Web App
echo "🔨 Compiling Flutter Web app (release, edition: $EDITION)..."
cd "$ROOT_DIR/app"
flutter pub get
flutter build web --release --no-tree-shake-icons --dart-define=HALO_EDITION="$EDITION"

# 2b. Stamp the built bundle with this edition's identity (favicon, manifest, titles)
"$ROOT_DIR/scripts/apply-web-edition.sh" "$EDITION" "$ROOT_DIR/app/build/web"

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
