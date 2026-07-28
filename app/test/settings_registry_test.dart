// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Unit coverage for settings_registry.dart's pure element-visibility
// functions — elementMatchesEnvironment and elementIsCommon. The widget
// tests in settings_panels_test.dart exercise these end to end through
// actual settings panels, but only ever with a single-token string
// attribute; this file pins the documented edge cases directly: list-form
// tokens, the mixed-include/exclude fail-open rule, case-insensitivity, and
// which element types `common` applies to.

import 'package:flutter/foundation.dart' show debugDefaultTargetPlatformOverride, TargetPlatform;
import 'package:flutter_test/flutter_test.dart';

import 'package:ham2k_logger/settings/settings_registry.dart';

void main() {
  group('elementMatchesEnvironment', () {
    setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.iOS);
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('no environment attribute matches every platform', () {
      expect(elementMatchesEnvironment({'type': 'field'}), isTrue);
    });

    test('unprefixed tokens are a whitelist: current platform included', () {
      expect(elementMatchesEnvironment({'type': 'field', 'environment': 'ios,android'}), isTrue);
    });

    test('unprefixed tokens are a whitelist: current platform excluded', () {
      expect(elementMatchesEnvironment({'type': 'field', 'environment': 'macos,windows'}), isFalse);
    });

    test('-prefixed tokens are a blacklist: current platform excluded', () {
      expect(elementMatchesEnvironment({'type': 'field', 'environment': '-ios'}), isFalse);
    });

    test('-prefixed tokens are a blacklist: current platform not excluded', () {
      expect(elementMatchesEnvironment({'type': 'field', 'environment': '-web'}), isTrue);
    });

    test('list form works the same as the comma-separated string form', () {
      expect(elementMatchesEnvironment({'type': 'field', 'environment': ['ios', 'android']}), isTrue);
      expect(elementMatchesEnvironment({'type': 'field', 'environment': ['-ios']}), isFalse);
    });

    test('mixing whitelist and blacklist tokens fails open (invalid combination)', () {
      // Would be `false` under either reading alone (ios is both included
      // and excluded) — fail-open proves the mix is rejected outright, not
      // resolved by picking one side.
      expect(elementMatchesEnvironment({'type': 'field', 'environment': 'ios,-android'}), isTrue);
    });

    test('tokens are case-insensitive', () {
      expect(elementMatchesEnvironment({'type': 'field', 'environment': 'iOS'}), isTrue);
      expect(elementMatchesEnvironment({'type': 'field', 'environment': '-IOS'}), isFalse);
    });
  });

  group('elementIsCommon', () {
    test('field/link/action flagged common: true are common', () {
      expect(elementIsCommon({'type': 'field', 'common': true}), isTrue);
      expect(elementIsCommon({'type': 'link', 'common': true}), isTrue);
      expect(elementIsCommon({'type': 'action', 'common': true}), isTrue);
    });

    test('unflagged or common: false elements are not common', () {
      expect(elementIsCommon({'type': 'field'}), isFalse);
      expect(elementIsCommon({'type': 'field', 'common': false}), isFalse);
    });

    test('headers/dividers/markdown are never common, even if flagged', () {
      // Common Preferences builds its own section headers from each
      // group/panel's title rather than reusing a panel's own elements —
      // see settings_registry.dart's elementIsCommon doc comment.
      expect(elementIsCommon({'type': 'header', 'common': true}), isFalse);
      expect(elementIsCommon({'type': 'divider', 'common': true}), isFalse);
      expect(elementIsCommon({'type': 'markdown', 'common': true}), isFalse);
    });
  });
}
