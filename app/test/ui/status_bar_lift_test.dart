// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// On a phone whose bar runs over the home indicator, a message lifts the bar
// off it slowly, since the whole window above moves with it.

import 'package:flutter/foundation.dart' show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/main.dart';
import '../support/halo_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // The trap: the chrome band's pieces sit in one Column, and a notice
  // arriving with a message moves the footer down a slot. Unkeyed, that
  // mounts a fresh footer whose lift off the home indicator starts at its
  // end, so the window above jumps instead of easing.
  for (final withNotice in [false, true]) {
    testWidgets('a message eases the bar off the home indicator${withNotice ? ', even with a notice arriving beside it' : ''}', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        final services = (await makeHaLoServices()).services;
        final dpr = tester.view.devicePixelRatio;
        tester.view.physicalSize = const Size(390, 844) * dpr;
        tester.view.padding = FakeViewPadding(bottom: 34 * dpr);
        tester.view.viewPadding = FakeViewPadding(bottom: 34 * dpr);
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetPadding();
          tester.view.resetViewPadding();
        });
        await tester.pumpWidget(
          TranslationProvider(
            child: MaterialApp(
              builder: (context, _) => StatusBarOverlay(
                services: services,
                child: const Scaffold(body: SizedBox.expand()),
              ),
              home: const SizedBox.shrink(),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 400));
        final rest = tester.getSize(find.byType(StatusBarFooter)).height;
        services.statusBar.setMessage(key: 'm', text: 'Spots refreshed');
        if (withNotice) services.statusBar.showNotice(key: 'n', text: 'note');
        await tester.pump();
        await tester.pump(StatusBarFooter.liftDuration ~/ 2);
        final mid = tester.getSize(find.byType(StatusBarFooter)).height;
        expect(mid, allOf(greaterThan(rest + 1), lessThan(rest + 33)), reason: 'halfway through, the bar is partway up');
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 6));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }
}
