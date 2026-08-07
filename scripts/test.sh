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
# Modes:
#   test.sh                  full gate — the ONLY run that counts before a
#                            merge. Everything below is an inner-loop
#                            convenience, not a gate.
#   test.sh --quick          basic checks only — extension typecheck + Dart
#                            analyze, no tests (and therefore no bundle build,
#                            which only the tests consume). CI uses it for
#                            pull requests; the full run happens on push to
#                            the protected branches (see .github/workflows/ci.yml).
#   test.sh <group>...       subset run for fast iteration: only the named
#                            groups' tests, skipping npm ci / pub get /
#                            analyze, rebuilding the extension bundles only
#                            when extensions/ is newer than the built ones.
#   test.sh --changed        subset derived from the git diff against the
#                            merge-base with origin/main (committed +
#                            uncommitted + untracked).
#   test.sh --list [group]   list the groups, or one group's files.
#
# Subset runs trade coverage for speed on purpose: they do not run analyze,
# do not run dependent packages (a halo_core change can break app tests that
# only the full gate would catch), and skip the browser-platform step. They
# always end with a reminder that the full gate is still owed.
set -euo pipefail

ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"

# ---------------------------------------------------------------------------
# Group definitions
#
# Two kinds of groups:
#   - package groups: one Dart package (or the npm extension workspace) each.
#   - app groups: filename-prefix subsets of app/test/, where most tests live.
#     `misc` is COMPUTED as the complement of every other app group, so a new
#     test file always belongs somewhere — files can never silently fall out
#     of the subset system. A file may match more than one group; that's fine
#     (a superset run is safe, a missed file is not).
# macOS ships bash 3.2, so no associative arrays: case functions instead.
# ---------------------------------------------------------------------------

PKG_GROUP_NAMES="extensions core build-tools extension-host quickjs widgets cli app dist"
APP_GROUP_NAMES="cat settings activities spots logging operation home sync extension commands ui errors misc"

pkg_group_dir() {
  case "$1" in
    core) echo "packages/halo_core" ;;
    build-tools) echo "packages/halo_build_tools" ;;
    extension-host) echo "packages/halo_extension_host" ;;
    quickjs) echo "packages/halo_quickjs" ;;
    widgets) echo "packages/halo_widgets" ;;
    cli) echo "packages/halo_cli" ;;
    *) echo "" ;;
  esac
}

app_group_prefixes() {
  case "$1" in
    cat) echo "cat_ radio_service equipment_report web_serial" ;;
    settings) echo "settings_ core_settings density_ font_scale experiments_ theme_ language_ call_notes" ;;
    activities) echo "activities_ activity_ pota_ sota_ hunted_ scoring_ information_panel contest_" ;;
    spots) echo "spots_ spot_ zero_beat map_" ;;
    logging) echo "logging_ annotation_ qso_ call_info hardware_keyboard lookup_" ;;
    operation) echo "operation_ new_operation adif_ export_" ;;
    home) echo "home_ header_ onboarding_ edition_" ;;
    sync) echo "sync_ pusher_ oauth_ account_ switch_accounts no_keyring confirm_device staleness" ;;
    extension) echo "extension_ extensions_ hook_ report_host" ;;
    commands) echo "command_ dev_ devonboard devsplash devtester seed_ reload_ report_command exp_" ;;
    ui) echo "panel_ dialog_ layout_ spacing_ no_hover window_ windows_ about_ notice release_ tester_ update_ version_ flag_ status_bar" ;;
    errors) echo "error_ telemetry_" ;;
    *) echo "" ;;
  esac
}

is_app_group() {
  local g
  for g in $APP_GROUP_NAMES; do [[ "$1" == "$g" ]] && return 0; done
  return 1
}

is_known_group() {
  local g
  for g in $PKG_GROUP_NAMES $APP_GROUP_NAMES; do [[ "$1" == "$g" ]] && return 0; done
  return 1
}

# group -> test file basenames, one per line. Prefix lookups are hoisted out
# of the per-file loop and matching uses only builtins: a subshell per
# (file × group) turns the pre-flight of every subset run into seconds.
app_group_files() {
  local g="$1" f base p og matched prefixes
  if [[ "$g" == "misc" ]]; then
    prefixes=""
    for og in $APP_GROUP_NAMES; do
      [[ "$og" == "misc" ]] && continue
      prefixes="$prefixes $(app_group_prefixes "$og")"
    done
    for f in "$ROOT_DIR"/app/test/*_test.dart; do
      base="${f##*/}"
      matched=0
      for p in $prefixes; do
        if [[ "$base" == "$p"* ]]; then matched=1; break; fi
      done
      [[ "$matched" -eq 0 ]] && echo "$base"
    done
  else
    prefixes=$(app_group_prefixes "$g")
    for f in "$ROOT_DIR"/app/test/*_test.dart; do
      base="${f##*/}"
      for p in $prefixes; do
        if [[ "$base" == "$p"* ]]; then echo "$base"; break; fi
      done
    done
  fi
  return 0
}

list_groups() {
  local g n
  echo "Package groups (whole package each):"
  for g in $PKG_GROUP_NAMES; do
    case "$g" in
      extensions) echo "  extensions      — TS extension unit tests (npm test)" ;;
      app) echo "  app             — every app/ test (all groups below)" ;;
      dist) echo "  dist            — app_dist + halo_dist_tools" ;;
      *) echo "  $(printf '%-15s' "$g") — $(pkg_group_dir "$g")" ;;
    esac
  done
  echo
  echo "App groups (subsets of app/test/ by filename prefix):"
  for g in $APP_GROUP_NAMES; do
    n=$(app_group_files "$g" | wc -l | tr -d ' ')
    echo "  $(printf '%-15s' "$g") — $n files"
  done
  echo
  echo "Use: scripts/test.sh <group>... | --changed | --list <group>"
}

# ---------------------------------------------------------------------------
# Incremental prerequisites for subset runs
# ---------------------------------------------------------------------------

ensure_node_modules() {
  if [[ ! -d "$ROOT_DIR/extensions/node_modules" ]]; then
    echo "▶ extensions: npm ci (node_modules missing)"
    (cd "$ROOT_DIR/extensions" && npm ci)
  fi
}

# Rebuild the bundles only when something under extensions/ is newer than the
# OLDEST built bundle — the stale-bundle gap this script exists to close,
# checked incrementally. Oldest, not newest: a failed or interrupted
# `npm run build` leaves some bundles rewritten and some not, and the
# untouched ones keep the comparison stale so the next run rebuilds.
ensure_bundles() {
  # The oldest file is found by pairwise -ot comparison, not `xargs ls -t`:
  # GNU xargs runs `ls` even on empty input (listing the CWD as if it were a
  # bundle), and xargs batching would compare only the last batch.
  local oldest_bundle="" stale fpath
  while IFS= read -r fpath; do
    if [[ -z "$oldest_bundle" || "$fpath" -ot "$oldest_bundle" ]]; then
      oldest_bundle="$fpath"
    fi
  done < <(find "$ROOT_DIR/app/assets/extensions" -type f 2>/dev/null || true)
  if [[ -z "$oldest_bundle" ]]; then
    stale=1
  else
    stale=$(find "$ROOT_DIR/extensions" -path "$ROOT_DIR/extensions/node_modules" -prune -o -type f -newer "$oldest_bundle" -print 2>/dev/null | head -1 || true)
    [[ -n "$stale" ]] && stale=1 || stale=0
  fi
  if [[ "$stale" == "1" ]]; then
    ensure_node_modules
    echo "▶ extensions: build bundles (extensions/ newer than built bundles)"
    (cd "$ROOT_DIR/extensions" && npm run build)
  else
    echo "▶ extensions: bundles up to date, skipping build"
  fi
}

ensure_hostlib() {
  # build_host.sh is incremental; a no-op run costs a couple of seconds.
  echo "▶ halo_quickjs: host JS engine library (incremental)"
  "$ROOT_DIR/packages/halo_quickjs/tool/build_host.sh"
}

ensure_secrets() {
  if [[ ! -f "$ROOT_DIR/app/lib/config/secrets.dart" ]]; then
    echo "▶ app: no secrets present, using the blank template"
    cp "$ROOT_DIR/app/lib/config/secrets.dart.example" "$ROOT_DIR/app/lib/config/secrets.dart"
  fi
}

ensure_pub() {
  # `flutter test` re-resolves stale deps itself; this only covers the
  # fresh-worktree case where .dart_tool doesn't exist at all.
  if [[ ! -f "$ROOT_DIR/$1/.dart_tool/package_config.json" ]]; then
    echo "▶ $1: pub get (fresh package)"
    (cd "$ROOT_DIR/$1" && flutter pub get)
  fi
}

# ---------------------------------------------------------------------------
# Subset runner
# ---------------------------------------------------------------------------

# Totals for the summary line. flutter's progress line carries a running
# `+passed` counter — the last one is the run's test count; node's test
# runner prints an `ℹ tests N` (or TAP `# tests N`) line.
TESTS_TOTAL=0
APP_FILES_COUNT=0
EXTRA_APP_FILES=""

run_flutter_counted() { # <pkg dir> [test files...]
  local dir="$1"; shift
  local log n rc=0
  log="$(mktemp)"
  (cd "$ROOT_DIR/$dir" && flutter test "$@") | tee "$log" || rc=$?
  n=$(grep -oE '\+[0-9]+' "$log" | tail -1 | tr -d '+' || true)
  rm -f "$log"
  [[ "$rc" -ne 0 ]] && exit "$rc"
  if [[ -z "$n" ]]; then
    echo "⚠️  could not parse a test count from flutter's output for $dir" >&2
  fi
  TESTS_TOTAL=$((TESTS_TOTAL + ${n:-0}))
}

run_npm_counted() {
  local log n rc=0
  log="$(mktemp)"
  (cd "$ROOT_DIR/extensions" && npm test) | tee "$log" || rc=$?
  n=$(grep -E '(ℹ|#) tests' "$log" | grep -oE '[0-9]+' | tail -1 || true)
  rm -f "$log"
  [[ "$rc" -ne 0 ]] && exit "$rc"
  if [[ -z "$n" ]]; then
    echo "⚠️  could not parse a test count from npm's output" >&2
  fi
  TESTS_TOTAL=$((TESTS_TOTAL + ${n:-0}))
}

run_subset() {
  # $@: validated group names (deduped by the caller)
  local g run_extensions=0 run_dist=0 run_all_app=0
  local need_bundles=0 need_hostlib=0
  local pkg_dirs="" app_files="" files empty_groups=""

  for g in "$@"; do
    case "$g" in
      extensions) run_extensions=1 ;;
      # app_dist path-depends on the app package, whose pubspec declares the
      # gitignored assets/extensions/ as an asset dir — absent bundles fail
      # the dependency's asset build on a fresh worktree.
      dist) run_dist=1; need_bundles=1 ;;
      app) run_all_app=1; need_bundles=1; need_hostlib=1 ;;
      quickjs) need_hostlib=1; pkg_dirs="$pkg_dirs $(pkg_group_dir "$g")" ;;
      extension-host) need_bundles=1; need_hostlib=1; pkg_dirs="$pkg_dirs $(pkg_group_dir "$g")" ;;
      core | build-tools | widgets | cli) pkg_dirs="$pkg_dirs $(pkg_group_dir "$g")" ;;
      *)
        # A package group added to PKG_GROUP_NAMES without a case arm above
        # must not fall through here and silently run nothing.
        if ! is_app_group "$g"; then
          echo "internal error: group '$g' has no runner" >&2; exit 2
        fi
        need_bundles=1; need_hostlib=1
        files=$(app_group_files "$g")
        if [[ -z "$files" ]]; then
          echo "⚠️  group '$g' matches no test files" >&2
          empty_groups="$empty_groups $g"
        fi
        app_files="$app_files
$files"
        ;;
    esac
  done

  # --changed hands over specific files outside any named group
  if [[ -n "${EXTRA_APP_FILES// /}" ]]; then
    need_bundles=1; need_hostlib=1
    app_files="$app_files
$(echo "$EXTRA_APP_FILES" | tr ' ' '\n')"
  fi

  [[ "$need_bundles" == "1" ]] && ensure_bundles
  [[ "$need_hostlib" == "1" ]] && ensure_hostlib

  if [[ "$run_extensions" == "1" ]]; then
    ensure_node_modules
    echo "▶ extensions: unit tests (typecheck skipped in subset mode)"
    run_npm_counted
  fi

  local pkg
  for pkg in $pkg_dirs; do
    ensure_pub "$pkg"
    echo "▶ $pkg: test (analyze skipped in subset mode)"
    run_flutter_counted "$pkg"
  done

  # dedupe: a file may belong to several requested groups
  files=$(echo "$app_files" | sed '/^$/d' | sort -u)
  if [[ "$run_all_app" == "1" || -n "$files" ]]; then
    ensure_secrets
    ensure_pub app
    if [[ "$run_all_app" == "1" ]]; then
      APP_FILES_COUNT=$(ls "$ROOT_DIR"/app/test/*_test.dart | wc -l | tr -d ' ')
      echo "▶ app: all tests (analyze skipped in subset mode)"
      run_flutter_counted app
    else
      APP_FILES_COUNT=$(echo "$files" | wc -l | tr -d ' ')
      echo "▶ app: $APP_FILES_COUNT test files (analyze skipped in subset mode)"
      # shellcheck disable=SC2046
      run_flutter_counted app $(echo "$files" | sed 's|^|test/|')
    fi
  fi

  if [[ "$run_dist" == "1" ]]; then
    if [[ -d "$ROOT_DIR/app_dist" ]]; then
      ensure_secrets
      for pkg in app_dist/halo_dist_tools app_dist; do
        ensure_pub "$pkg"
        echo "▶ $pkg: test (analyze skipped in subset mode)"
        run_flutter_counted "$pkg"
      done
    else
      echo "⚠️  group 'dist' skipped: no app_dist/ in this checkout" >&2
    fi
  fi

  # A zero total means the selection resolved to nothing (or a runner's count
  # line stopped parsing) — either way, a green exit would be a lie. Likewise
  # a requested group that matched nothing: its warning has scrolled several
  # screens up by now, and a green line naming the group would contradict it.
  if [[ "$TESTS_TOTAL" -eq 0 ]]; then
    echo
    echo "❌ subset '${*:-changed files}' ran zero tests — nothing verified." >&2
    exit 1
  fi
  if [[ -n "${empty_groups// /}" ]]; then
    echo
    echo "❌ requested group(s) matched no test files:${empty_groups} — their prefixes have rotted; fix app_group_prefixes." >&2
    exit 1
  fi

  echo
  local detail=""
  if [[ "$APP_FILES_COUNT" -eq 1 ]]; then detail=" in 1 app test file"
  elif [[ "$APP_FILES_COUNT" -gt 1 ]]; then detail=" in $APP_FILES_COUNT app test files"; fi
  echo "✅ subset passed: ${*:-changed files} — $TESTS_TOTAL tests$detail"
  echo "⚠️  Subset run — no analyze, no dependent packages, no browser step."
  echo "⚠️  Run the full ./scripts/test.sh before merging."
}

# ---------------------------------------------------------------------------
# --changed: map the diff vs merge-base(origin/main) to groups / test files
# ---------------------------------------------------------------------------

changed_subset() {
  local base
  base=$(git -C "$ROOT_DIR" merge-base HEAD origin/main 2>/dev/null || true)
  if [[ -z "$base" ]]; then
    base=$(git -C "$ROOT_DIR" merge-base HEAD main 2>/dev/null || true)
    if [[ -n "$base" ]]; then
      echo "⚠️  origin/main not found — diffing against local main, which may be stale (a smaller diff selects fewer tests)." >&2
    fi
  fi
  if [[ -z "$base" ]]; then
    echo "❌ --changed needs origin/main (or a local main) to diff against." >&2
    echo "   Try: git fetch origin main — or name groups explicitly (see --list)." >&2
    exit 2
  fi

  local changed
  changed=$( (git -C "$ROOT_DIR" diff --name-only "$base"; \
              git -C "$ROOT_DIR" ls-files --others --exclude-standard) | sort -u)
  if [[ -z "$changed" ]]; then
    echo "No changes vs merge-base with origin/main — nothing to run."
    return 0
  fi

  local groups="" app_test_files="" whole_app=0 infra=0 path stem candidates
  while IFS= read -r path; do
    case "$path" in
      docs/* | *.md | .agents/* | .claude/*) ;;
      scripts/* | .github/* | mise.toml | codemagic.yaml) infra=1 ;;
      extensions/*) groups="$groups extensions extension-host extension" ;;
      packages/halo_core/*) groups="$groups core" ;;
      packages/halo_build_tools/*) groups="$groups build-tools" ;;
      packages/halo_extension_host/*) groups="$groups extension-host" ;;
      packages/halo_quickjs/*) groups="$groups quickjs" ;;
      packages/halo_widgets/*) groups="$groups widgets" ;;
      packages/halo_cli/*) groups="$groups cli" ;;
      # A package this mapping doesn't know (new or renamed) must not fall
      # into the silent catch-all and read as "docs".
      packages/*)
        echo "❌ --changed has no mapping for '$path' — add one to changed_subset, or name groups explicitly." >&2
        exit 2
        ;;
      app_dist/*) groups="$groups dist" ;;
      app/test/*_test.dart)
        # deleted test files have nothing to run
        [[ -f "$ROOT_DIR/$path" ]] && app_test_files="$app_test_files $(basename "$path")" ;;
      app/test/*) whole_app=1 ;;  # shared fakes/helpers — can't tell who uses them
      app/lib/*.dart)
        # Progressively trim `_token`s off the stem until some test file's
        # name starts with it (spots_service → spots_service_test.dart;
        # command_engine → command_*). Over-matching is safe; no match at
        # all means we can't scope it, so the whole app runs.
        stem=$(basename "$path" .dart)
        candidates=""
        while [[ -n "$stem" ]]; do
          candidates=$(cd "$ROOT_DIR/app/test" && ls "${stem}"*_test.dart 2>/dev/null || true)
          [[ -n "$candidates" ]] && break
          [[ "$stem" == *_* ]] || { stem=""; break; }
          stem="${stem%_*}"
        done
        if [[ -n "$candidates" ]]; then
          app_test_files="$app_test_files $(echo "$candidates" | tr '\n' ' ')"
        else
          whole_app=1
        fi
        ;;
      app/*) whole_app=1 ;;
      workers/* | assets/*) ;;
      *) ;;
    esac
  done <<< "$changed"

  if [[ "$infra" == "1" ]]; then
    echo "⚠️  Build/CI infrastructure changed (scripts/, .github/, mise.toml…) —"
    echo "⚠️  --changed can't scope that; run the full ./scripts/test.sh."
  fi

  [[ "$whole_app" == "1" ]] && { groups="$groups app"; app_test_files=""; }
  groups=$(echo "$groups" | tr ' ' '\n' | sed '/^$/d' | sort -u | tr '\n' ' ')
  # A whole-app run subsumes every app group.
  if echo " $groups " | grep -q " app "; then
    groups=$(echo "$groups" | tr ' ' '\n' | while IFS= read -r g; do
      is_app_group "$g" && [[ "$g" != "app" ]] || echo "$g"
    done | tr '\n' ' ')
  fi

  if [[ -z "${groups// /}" && -z "${app_test_files// /}" ]]; then
    if [[ "$infra" == "1" ]]; then
      # Never a green exit: something reading only $? would see a change to
      # the gate itself pass with zero tests run.
      echo "❌ only build/CI infrastructure changed — nothing was scoped or run; run the full ./scripts/test.sh." >&2
      exit 2
    fi
    echo "Changes found, but none map to tests (docs only). Nothing to run."
    return 0
  fi

  echo "▶ --changed selection: ${groups:-–}${app_test_files:+ + files:$app_test_files}"

  # The specific files run directly rather than as their whole groups; one
  # run_subset call keeps a single summary with one total.
  EXTRA_APP_FILES="$app_test_files"
  # shellcheck disable=SC2086
  run_subset $groups
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

QUICK=0
case "${1:-}" in
  --quick | -q)
    if [[ $# -gt 1 ]]; then
      echo "--quick takes no further arguments (groups don't combine with it)" >&2
      exit 2
    fi
    QUICK=1
    ;;
  --list | -l)
    if [[ $# -gt 2 ]]; then
      echo "usage: scripts/test.sh --list [group]" >&2; exit 2
    fi
    if [[ -n "${2:-}" ]]; then
      if ! is_known_group "$2"; then
        echo "unknown group '$2' — run scripts/test.sh --list" >&2; exit 2
      fi
      case "$2" in
        app) ls "$ROOT_DIR"/app/test/*_test.dart | sed "s|.*/||" ;;
        extensions) echo "extensions → TS extension unit tests (npm test)" ;;
        dist) echo "dist → app_dist/halo_dist_tools app_dist" ;;
        *)
          if is_app_group "$2"; then app_group_files "$2"; else
            echo "$2 → $(pkg_group_dir "$2")"
          fi
          ;;
      esac
    else
      list_groups
    fi
    exit 0
    ;;
  --changed | -c)
    if [[ $# -gt 1 ]]; then
      echo "--changed takes no further arguments" >&2; exit 2
    fi
    changed_subset
    exit 0
    ;;
  --help | -h)
    echo "usage: scripts/test.sh [--quick | --changed | --list [group] | <group>...]"
    exit 0
    ;;
  -*)
    echo "usage: scripts/test.sh [--quick | --changed | --list [group] | <group>...]" >&2
    exit 2
    ;;
  "") ;;
  *)
    # named subset run
    GROUPS_REQ=""
    for g in "$@"; do
      if ! is_known_group "$g"; then
        echo "unknown group '$g' — run scripts/test.sh --list" >&2
        exit 2
      fi
      case " $GROUPS_REQ " in *" $g "*) ;; *) GROUPS_REQ="$GROUPS_REQ $g" ;; esac
    done
    # shellcheck disable=SC2086
    run_subset $GROUPS_REQ
    exit 0
    ;;
esac

# ---------------------------------------------------------------------------
# Full gate (and --quick), exactly as CI mirrors it
# ---------------------------------------------------------------------------

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
ensure_secrets

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

# A few tests have to run in a BROWSER, not the host VM, because Dart's web
# numbers are JS doubles and its bitwise operators are 32-bit unsigned — so
# code that is arithmetically correct natively can be silently wrong on web,
# and `flutter test` cannot see it. The settings fuzzy matcher shipped exactly
# that bug: its "negative infinity" sentinel was built with `-1 << 30`, which
# is POSITIVE on web, so every settings search answered "nothing matches"
# while the whole native suite stayed green.
#
# Keep this list to genuinely platform-sensitive, dependency-free tests —
# anything touching drift or dart:io cannot run here at all.
#
# This step is part of the LOCAL gate only: .github/workflows/ci.yml shards
# `flutter test` directly rather than invoking this script, so nothing on
# `main` re-runs it. That matches the repo's "the local run before merging IS
# the gate" policy, but it does mean skipping this script skips the only web
# coverage there is.
#
# Skipped loudly, not fatally, where no browser exists: this is the only gate
# the repo has, so a machine without Chrome must still be able to complete it
# rather than being pushed to `--quick`, which runs no tests at all.
if [[ "$QUICK" -eq 0 ]]; then
  # `-x`, not just `-n`: a CHROME_EXECUTABLE left over from an uninstall
  # would otherwise read as "Chrome present" and fail the whole gate instead
  # of taking the loud-skip branch below.
  if [[ -x "${CHROME_EXECUTABLE:-}" ]] \
    || command -v google-chrome >/dev/null 2>&1 \
    || command -v chromium >/dev/null 2>&1 \
    || command -v chromium-browser >/dev/null 2>&1 \
    || [[ -x "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" ]]; then
    echo "▶ app: browser-platform tests (web number semantics)"
    cd "$ROOT_DIR/app"
    flutter test --platform chrome test/settings_fuzzy_test.dart
  else
    echo "⚠️  SKIPPED: browser-platform tests — no Chrome found."
    echo "⚠️  Web-only defects (see the comment above) are NOT covered by this run."
    echo "⚠️  Install Chrome or set CHROME_EXECUTABLE before trusting this as the merge gate."
  fi
fi

if [[ "$QUICK" -eq 1 ]]; then
  echo "✅ quick checks passed (typecheck + analyze; tests NOT run)"
else
  echo "✅ all checks passed"
fi
