#!/bin/bash
# Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
# SPDX-License-Identifier: MPL-2.0
# Invoked by scripts/test.sh --native-iq; native SDKs are supplied by the caller.
set -euo pipefail
ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
case "${1:-}" in
  windows | ios | android) ;;
  *) echo 'usage: scripts/test.sh --native-iq <ios|android|windows>' >&2; exit 2 ;;
esac
(cd "$ROOT_DIR/packages/halo_build_tools" && dart run bin/prepare_record.dart)
TEST_TMP="$(mktemp -d)"
trap 'rm -rf "$TEST_TMP"' EXIT
case "${1:-}" in
  windows)
    "${CXX:-c++}" -std=c++17 -Wall -Wextra -Werror \
      "$ROOT_DIR/packages/record_windows_patched/windows/test/iq_pcm_portable_test.cpp" -o "$TEST_TMP/windows-iq-validation"
    "$TEST_TMP/windows-iq-validation"
    ;;
  ios)
    swiftc "$ROOT_DIR/packages/record_ios_patched/ios/record_ios/Sources/record_ios/IqCaptureValidation.swift" \
      "$ROOT_DIR/packages/record_ios_patched/test/IqCaptureValidationTest.swift" -o "$TEST_TMP/ios-iq-validation"
    "$TEST_TMP/ios-iq-validation"
    ;;
  android)
    "$ROOT_DIR/scripts/test-iq-android.sh"
    ;;
esac
