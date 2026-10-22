#!/bin/bash
# Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
# SPDX-License-Identifier: MPL-2.0
#
# First-run setup — everything a fresh clone or worktree needs before the app
# runs or the suite passes, in one idempotent command: `mise run setup`.
#
# Each step here is one scripts/test.sh already takes on its own first run,
# or one DEVELOPMENT.md asks for by hand. Gathered so a newcomer meets them
# once, in order, with a line that says what each is for — instead of as five
# differently shaped failures: an app with no extensions in it, a test host
# with no JS engine, a push to `main` with no guard on it.
#
# Safe to re-run; every step is a no-op once done. Assumes `mise install &&
# mise trust` has already happened — that is what puts `flutter` on the PATH
# this script is run from, and mise cannot bootstrap itself from inside a
# task it is not yet trusted to run.
set -euo pipefail

ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
cd "$ROOT_DIR"

step() { echo "▶ $*"; }

# 0. Tools. Flutter is pinned in mise.toml; Node is not pinned (CI uses 22).
command -v flutter >/dev/null 2>&1 || {
  echo "flutter not found on PATH — run 'mise install && mise trust' first; mise.toml pins the version." >&2
  exit 1
}
command -v npm >/dev/null 2>&1 || {
  echo "npm not found — the extensions are TypeScript and need Node (CI uses Node 22)." >&2
  exit 1
}

# TLS interop tests need an independent OpenSSL 3 peer, never macOS LibreSSL.
# Match the test helper's discovery order; no OpenSSL executable ships in HaLo.
find_openssl3() {
  local candidate version
  for candidate in "${HALO_TLS_TEST_OPENSSL:-}" /opt/homebrew/opt/openssl@3/bin/openssl /usr/local/opt/openssl@3/bin/openssl openssl; do
    [[ -n "$candidate" ]] || continue
    version="$("$candidate" version 2>/dev/null || true)"
    if [[ "$version" == OpenSSL\ 3.* ]]; then
      echo "$candidate"
      return 0
    fi
  done
  return 1
}

if ! TLS_OPENSSL="$(find_openssl3)"; then
  if [[ "$(uname -s)" == "Darwin" ]] && command -v brew >/dev/null 2>&1; then
    step "TLS tests: install the OpenSSL 3 test peer with Homebrew"
    brew install openssl@3
  fi
  TLS_OPENSSL="$(find_openssl3)" || {
    echo "OpenSSL 3 is required for TLS tests. macOS: brew install openssl@3; Debian/Ubuntu: sudo apt-get install openssl." >&2
    echo "For another installation, set HALO_TLS_TEST_OPENSSL to its executable and rerun setup. See DEVELOPMENT.md." >&2
    exit 1
  }
fi
step "TLS tests: $TLS_OPENSSL ($("$TLS_OPENSSL" version))"

# 1. The tracked git hooks. Per CLONE, not per worktree, so every worktree
#    inherits it: .githooks/pre-push is what refuses a push to `main` whose
#    tree is not the one the suite ran on.
step "git: hooks path → .githooks"
git config core.hooksPath .githooks

# 2. Build-time secrets. The blank template is a supported configuration —
#    every consumer degrades without its key, and the Map tab needs none.
if [[ ! -f app/lib/config/secrets.dart ]]; then
  step "app: no secrets present, using the blank template"
  cp app/lib/config/secrets.dart.example app/lib/config/secrets.dart
fi

# 3. The extension bundles. Gitignored, and the app is nothing without them:
#    POTA, SOTA and every other hook is simply absent until they exist.
step "extensions: npm ci, build bundles → app/assets/extensions/"
(cd extensions && npm ci && npm run build)

# 4. QuickJS needs an explicit host build for tests and diagnostic tools.
#    halo_tls_psk builds its native asset automatically through a Dart hook.
step "halo_quickjs: build the host JS engine library"
packages/halo_quickjs/tool/build_host.sh

# 5. Dependencies for the app and every first-party package — the same set
#    the gate walks (scripts/test.sh), so `flutter analyze` and a package's
#    own `flutter test` work from a fresh checkout without the gate first.
for pkg in app packages/halo_core packages/halo_build_tools packages/halo_i18n packages/halo_extension_host packages/halo_quickjs packages/halo_tls_psk packages/halo_widgets packages/halo_cli; do
  step "$pkg: pub get"
  (cd "$pkg" && flutter pub get >/dev/null)
done

# 6. macOS only: CocoaPods builds libserialport (the serial CAT transport)
#    from source, and `pod install` fails outright without autotools. A
#    check, not an install — Homebrew is the user's.
if [[ "$(uname -s)" == "Darwin" ]]; then
  if ! command -v automake >/dev/null 2>&1 || ! command -v libtool >/dev/null 2>&1; then
    echo "⚠️  macOS/iOS builds need autotools: brew install automake libtool" >&2
  fi
fi

echo "✅ set up. Next: cd app && flutter run -d macos   (the full gate is ./scripts/test.sh)"
