// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The User-Agent must always be resolvable — a missing native build number
// (headless test host, an early-boot platform channel not yet ready) is no
// reason for a network call, or the extension runtime start, to fail. These
// pin the never-throwing fallback path that guarantees that: without it,
// `ham2kUserAgent()` rethrows a package_info MissingPluginException on hosts
// where the plugin isn't registered (e.g. Linux `flutter test`), which is
// what darkened every extension.

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/config/user_agent.dart';
import 'package:ham2k_logger/config/version.dart';

void main() {
  test('ham2kUserAgentWithoutBuild omits the build number and never touches package_info', () {
    final ua = ham2kUserAgentWithoutBuild();
    expect(ua, startsWith('Ham2K Logger/$kPublicVersion ('));
    expect(ua, endsWith(' $kAppFlavor)')); // no build token trailing the flavor
    // The parenthetical is exactly platform + flavor (no build number).
    final inside = ua.substring(ua.indexOf('(') + 1, ua.length - 1);
    expect(inside.split(' '), hasLength(2));
  });

  test('ham2kUserAgentOrFallback always resolves to a valid UA, never throwing', () async {
    final ua = await ham2kUserAgentOrFallback();
    expect(ua, startsWith('Ham2K Logger/$kPublicVersion ('));
    expect(ua, contains(kAppFlavor));
  });
}
