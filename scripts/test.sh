#!/bin/bash
# Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
# SPDX-License-Identifier: MPL-2.0
#
# The project's single verification entry point, run locally (`mise run test`)
# and in CI. It exists to close the stale-bundle gap: the built extension
# bundles under app/assets/extensions/ are gitignored and regenerate only on
# an explicit `npm run build`, and the Dart integration tests
# (halo_extension_host) load those built bundles — so anything that runs the
# Dart tests must rebuild the bundles FIRST, or it silently tests whatever
# bundles happened to be lying around. This script enforces that order.
#
# --quick runs basic checks only — extension typecheck + Dart analyze, no
# tests (and therefore no bundle build, which only the tests consume). CI
# uses it for pull requests; the full run happens on push to the protected
# branches (see .github/workflows/ci.yml).
set -euo pipefail

QUICK=0
case "${1:-}" in
  --quick | -q) QUICK=1 ;;
  "") ;;
  *) echo "usage: scripts/test.sh [--quick]" >&2; exit 2 ;;
esac

ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"

if [[ "$QUICK" -eq 1 ]]; then
  echo "▶ extensions: install, typecheck (quick mode: no tests)"
else
  echo "▶ extensions: install, typecheck, unit tests"
fi
cd "$ROOT_DIR/extensions"
npm ci
npm run typecheck
if [[ "$QUICK" -eq 0 ]]; then
  npm test
fi

# The bundles are needed even in quick mode: app/pubspec.yaml declares
# app/assets/extensions/ as an asset directory, and `flutter analyze` fails
# on a fresh checkout (like CI) if it doesn't exist.
echo "▶ extensions: build bundles (must precede the Dart integration tests)"
npm run build

if [[ "$QUICK" -eq 0 ]]; then
  # `flutter test` runs in the host VM and never performs a platform native
  # build, so there is no plugin library for the tests to load — build one for
  # the host. Incremental: only a source change pays the rebuild.
  echo "▶ halo_quickjs: build the host JS engine library (needed by its tests)"
  "$ROOT_DIR/packages/halo_quickjs/tool/build_host.sh"
fi

# secrets.dart is gitignored, so fresh checkouts (like CI) don't have it and
# the app package fails to analyze. The blank template is a supported
# configuration — every consumer degrades rather than failing, and the Map tab
# falls back to OpenStreetMap.
if [[ ! -f "$ROOT_DIR/app/lib/config/secrets.dart" ]]; then
  echo "▶ app: no secrets present, using the blank template"
  cp "$ROOT_DIR/app/lib/config/secrets.dart.example" "$ROOT_DIR/app/lib/config/secrets.dart"
fi

PACKAGES=(packages/halo_core packages/halo_build_tools packages/halo_extension_host packages/halo_quickjs packages/halo_widgets packages/halo_cli app)
# The private distribution layer, present only in the halo-dist checkout — a
# public checkout has no app_dist/ and must still pass everything above.
if [[ -d "$ROOT_DIR/app_dist" ]]; then
  PACKAGES+=(app_dist/halo_dist_tools app_dist)
fi

for pkg in "${PACKAGES[@]}"; do
  if [[ "$QUICK" -eq 1 ]]; then
    echo "▶ $pkg: pub get, analyze (quick mode: no tests)"
  else
    echo "▶ $pkg: pub get, analyze, test"
  fi
  cd "$ROOT_DIR/$pkg"
  flutter pub get
  # Fail on warnings and errors; infos (mostly framework-deprecation churn
  # in form_renderer) are surfaced but non-blocking so CI stays actionable.
  flutter analyze --no-fatal-infos
  if [[ "$QUICK" -eq 0 ]]; then
    flutter test
  fi
done

if [[ "$QUICK" -eq 1 ]]; then
  echo "✅ quick checks passed (typecheck + analyze; tests NOT run)"
else
  echo "✅ all checks passed"
fi
