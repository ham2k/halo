// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The macOS app menu (macos/Runner MainMenu.xib + AppDelegate) forwards its
// About / Preferences items over the `ham2k/window_chrome` channel; this
// verifies they reach the app-supplied callbacks (release overlay / Settings).

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/window_chrome_service.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const codec = StandardMethodCodec();

  Future<void> sendNativeCall(String method) async {
    final data = codec.encodeMethodCall(MethodCall(method));
    await binding.defaultBinaryMessenger.handlePlatformMessage('ham2k/window_chrome', data, (_) {});
  }

  testWidgets('macOS About/Preferences menu calls route to the app callbacks', (tester) async {
    // debugDefaultTargetPlatformOverride must be back to null before the test
    // body returns — the framework's invariant check runs ahead of any
    // tearDown — hence try/finally rather than addTearDown.
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      var aboutCount = 0;
      var prefsCount = 0;
      WindowChromeService.onShowReleaseOverlay = () => aboutCount++;
      WindowChromeService.onOpenSettings = () => prefsCount++;

      WindowChromeService.init();

      await sendNativeCall('menuAbout');
      expect(aboutCount, 1);
      expect(prefsCount, 0);

      await sendNativeCall('menuPreferences');
      expect(aboutCount, 1);
      expect(prefsCount, 1);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      WindowChromeService.onShowReleaseOverlay = null;
      WindowChromeService.onOpenSettings = null;
    }
  });
}
