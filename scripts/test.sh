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
set -euo pipefail

ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"

echo "▶ extensions: install, typecheck, unit tests"
cd "$ROOT_DIR/extensions"
npm ci
npm run typecheck
npm test

echo "▶ extensions: build bundles (must precede the Dart integration tests)"
npm run build

for pkg in packages/halo_core packages/halo_extension_host packages/halo_widgets app; do
  echo "▶ $pkg: pub get, analyze, test"
  cd "$ROOT_DIR/$pkg"
  flutter pub get
  # Fail on warnings and errors; infos (mostly framework-deprecation churn
  # in form_renderer) are surfaced but non-blocking so CI stays actionable.
  flutter analyze --no-fatal-infos
  flutter test
done

echo "✅ all checks passed"
